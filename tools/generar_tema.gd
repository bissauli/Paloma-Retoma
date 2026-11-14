extends SceneTree
## Genera res://ui/tema/tema_paloma.tres, el tema de toda la interfaz de menús (título, opciones,
## cargar partida y pausa). Los colores y tamaños se definen acá, en un solo lugar.
## Uso: godot --headless --path . -s res://tools/generar_tema.gd
##
## Paleta: TODO el texto, los iconos, los bordes de foco, los sliders y las casillas en BLANCO.
## Los recuadros (botones, desplegables, paneles) en CYAN AZULADO semitransparente.
## Tamaños pensados para la ventana base del proyecto (1280x720); a 1920x1080 se ven x1,5.

const SALIDA := "res://ui/tema/tema_paloma.tres"

const BLANCO := Color(1, 1, 1)
const CIAN := Color(0.247, 0.722, 0.839, 0.55)          ## #3FB8D6 al 55 %: fondo de los recuadros
const CIAN_BORDE := Color(0.07, 0.65, 0.83, 0.92)       ## Más saturado y más opaco
const CIAN_CLARO := Color(0.46, 0.83, 0.92, 0.72)       ## Hover / foco: el cyan se aclara
const CIAN_APRETADO := Color(0.16, 0.58, 0.74, 0.8)
const CIAN_APAGADO := Color(0.35, 0.55, 0.62, 0.25)
const CIAN_OSCURO := Color(0.03, 0.16, 0.22, 0.92)      ## Fondo de las listas desplegables
const SOMBRA := Color(0.0, 0.03, 0.06, 0.38)
const SOMBRA_TEXTO := Color(0.0, 0.04, 0.08, 0.5)

const WGHT := 2003265652   ## Etiqueta OpenType "wght" (peso de las fuentes variables)

const BEBAS := "res://ui/tema/fuentes/BebasNeue-Regular.ttf"
const OSWALD := "res://ui/tema/fuentes/Oswald-Variable.ttf"
const MONTSERRAT := "res://ui/tema/fuentes/Montserrat-Variable.ttf"
const ICONOS := "res://ui/tema/iconos/"

var th := Theme.new()


func _init() -> void:
	_armar()
	var err := ResourceSaver.save(th, SALIDA)
	print("tema guardado en ", SALIDA, " (", error_string(err), ")")
	quit(0 if err == OK else 1)


func _armar() -> void:
	# ---------------------------------------------------------------- Fuentes
	var texto := _variacion(MONTSERRAT, 500, 1)
	var etiqueta := _variacion(MONTSERRAT, 500, 3)
	var boton := _variacion(MONTSERRAT, 500, 5)
	var fina := _variacion(MONTSERRAT, 400, 1)
	var seccion := _variacion(OSWALD, 300, 7)
	var titulo := _variacion(BEBAS, 0, 2)

	th.default_font = texto
	th.default_font_size = 19

	# ---------------------------------------------------------------- Label
	th.set_color("font_color", "Label", BLANCO)
	th.set_color("font_shadow_color", "Label", SOMBRA_TEXTO)
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 2)
	th.set_constant("shadow_outline_size", "Label", 5)

	_variante_label("TituloJuego", titulo, 128, 4, 12)
	th.set_constant("line_spacing", "TituloJuego", -34)
	_variante_label("TituloPantalla", titulo, 112, 4, 12)
	th.set_constant("line_spacing", "TituloPantalla", -30)
	_variante_label("Seccion", seccion, 25, 2, 6)
	_variante_label("Etiqueta", etiqueta, 17, 2, 5)
	_variante_label("Valor", fina, 15, 2, 4)
	th.set_color("font_color", "Valor", Color(1, 1, 1, 0.78))
	_variante_label("TextoChico", fina, 16, 2, 5)
	_variante_label("TextoTarjeta", etiqueta, 20, 2, 5)

	# ---------------------------------------------------------------- Botón base (pausa, cargar, etc.)
	var normal := _caja(CIAN, CIAN_BORDE, 2, 3)
	normal.shadow_color = SOMBRA
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 3)
	var hover := _caja(CIAN_CLARO, CIAN_BORDE, 2, 3)
	hover.shadow_color = SOMBRA
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 4)
	var apretado := _caja(CIAN_APRETADO, BLANCO, 2, 3)
	var apagado := _caja(CIAN_APAGADO, Color(1, 1, 1, 0.15), 1, 3)
	var foco := _foco(3, Vector2.ZERO)
	for tipo in ["Button", "OptionButton"]:
		th.set_stylebox("normal", tipo, normal)
		th.set_stylebox("hover", tipo, hover)
		th.set_stylebox("pressed", tipo, apretado)
		th.set_stylebox("hover_pressed", tipo, apretado)
		th.set_stylebox("disabled", tipo, apagado)
		th.set_stylebox("focus", tipo, foco)
		_colores_boton(tipo)
		th.set_font("font", tipo, boton)
		th.set_font_size("font_size", tipo, 18)
		th.set_color("font_outline_color", tipo, Color(0, 0.08, 0.12, 0.35))
		th.set_constant("outline_size", tipo, 4)
	th.set_icon("arrow", "OptionButton", _icono("flecha_abajo"))
	th.set_constant("arrow_margin", "OptionButton", 12)
	th.set_constant("h_separation", "OptionButton", 10)
	th.set_font("font", "OptionButton", etiqueta)
	th.set_font_size("font_size", "OptionButton", 16)

	# ---------------------------------------------------------------- Botones del menú principal (ref3)
	# Barras translúcidas con el borde izquierdo en diagonal y el texto a la derecha.
	# La barra sigue más allá del borde derecho de la pantalla (expand_margin_right).
	th.set_type_variation("BotonMenu", "Button")
	var sesgo := Vector2(0.42, 0.0)
	var b_normal := _barra(CIAN, CIAN_BORDE, sesgo, 0)
	var b_hover := _barra(CIAN_CLARO, BLANCO, sesgo, 0)
	b_hover.border_width_left = 2
	b_hover.border_width_top = 2
	b_hover.border_width_bottom = 2
	var b_apretado := _barra(CIAN_APRETADO, BLANCO, sesgo, 0)
	b_apretado.border_width_left = 2
	b_apretado.border_width_top = 2
	b_apretado.border_width_bottom = 2
	var b_apagado := _barra(CIAN_APAGADO, CIAN_APAGADO, sesgo, 0)
	var b_foco := _barra(Color(1, 1, 1, 0.16), BLANCO, sesgo, 0)
	b_foco.border_width_left = 2
	b_foco.border_width_top = 2
	b_foco.border_width_bottom = 2
	b_foco.shadow_size = 0
	th.set_stylebox("normal", "BotonMenu", b_normal)
	th.set_stylebox("hover", "BotonMenu", b_hover)
	th.set_stylebox("pressed", "BotonMenu", b_apretado)
	th.set_stylebox("hover_pressed", "BotonMenu", b_apretado)
	th.set_stylebox("disabled", "BotonMenu", b_apagado)
	th.set_stylebox("focus", "BotonMenu", b_foco)
	th.set_font("font", "BotonMenu", boton)
	th.set_font_size("font_size", "BotonMenu", 21)
	th.set_constant("outline_size", "BotonMenu", 5)

	# "VOLVER" de las pantallas (ref2): barra que sale del borde izquierdo, texto a la izquierda
	th.set_type_variation("BotonVolver", "Button")
	var v_normal := _barra(CIAN, CIAN_BORDE, -sesgo, 1)
	var v_hover := _barra(CIAN_CLARO, BLANCO, -sesgo, 1)
	v_hover.border_width_right = 2
	v_hover.border_width_top = 2
	v_hover.border_width_bottom = 2
	var v_foco := _barra(Color(1, 1, 1, 0.16), BLANCO, -sesgo, 1)
	v_foco.border_width_right = 2
	v_foco.border_width_top = 2
	v_foco.border_width_bottom = 2
	v_foco.shadow_size = 0
	var v_apretado := v_hover.duplicate() as StyleBoxFlat
	v_apretado.bg_color = CIAN_APRETADO
	th.set_stylebox("normal", "BotonVolver", v_normal)
	th.set_stylebox("hover", "BotonVolver", v_hover)
	th.set_stylebox("pressed", "BotonVolver", v_apretado)
	th.set_stylebox("hover_pressed", "BotonVolver", v_apretado)
	th.set_stylebox("focus", "BotonVolver", v_foco)
	th.set_font("font", "BotonVolver", boton)
	th.set_font_size("font_size", "BotonVolver", 21)
	th.set_constant("outline_size", "BotonVolver", 5)

	# ---------------------------------------------------------------- Lista desplegable
	var lista := _caja(CIAN_OSCURO, CIAN_BORDE, 2, 3)
	lista.content_margin_top = 6
	lista.content_margin_bottom = 6
	lista.content_margin_left = 6
	lista.content_margin_right = 6
	lista.shadow_color = SOMBRA
	lista.shadow_size = 12
	th.set_stylebox("panel", "PopupMenu", lista)
	var item_hover := _caja(CIAN, BLANCO, 1, 2)
	th.set_stylebox("hover", "PopupMenu", item_hover)
	th.set_stylebox("focus", "PopupMenu", item_hover)
	th.set_color("font_color", "PopupMenu", BLANCO)
	th.set_color("font_hover_color", "PopupMenu", BLANCO)
	th.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, 0.4))
	th.set_font("font", "PopupMenu", etiqueta)
	th.set_font_size("font_size", "PopupMenu", 16)
	th.set_constant("v_separation", "PopupMenu", 10)
	th.set_constant("item_start_padding", "PopupMenu", 8)
	th.set_constant("item_end_padding", "PopupMenu", 12)
	th.set_icon("radio_checked", "PopupMenu", _icono("punto_si"))
	th.set_icon("radio_unchecked", "PopupMenu", _icono("punto_no"))
	th.set_icon("checked", "PopupMenu", _icono("punto_si"))
	th.set_icon("unchecked", "PopupMenu", _icono("punto_no"))

	# ---------------------------------------------------------------- Deslizadores (blancos)
	var riel := StyleBoxFlat.new()
	riel.bg_color = Color(1, 1, 1, 0.28)
	riel.set_corner_radius_all(2)
	riel.content_margin_top = 2
	riel.content_margin_bottom = 2
	riel.shadow_color = Color(0, 0, 0, 0.25)
	riel.shadow_size = 3
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = BLANCO
	lleno.set_corner_radius_all(2)
	lleno.content_margin_top = 2
	lleno.content_margin_bottom = 2
	th.set_stylebox("slider", "HSlider", riel)
	th.set_stylebox("grabber_area", "HSlider", lleno)
	th.set_stylebox("grabber_area_highlight", "HSlider", lleno)
	th.set_icon("grabber", "HSlider", _icono("perilla"))
	th.set_icon("grabber_highlight", "HSlider", _icono("perilla_foco"))
	th.set_icon("grabber_disabled", "HSlider", _icono("perilla_off"))
	th.set_constant("center_grabber", "HSlider", 1)
	th.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())

	# ---------------------------------------------------------------- Casillas e interruptores
	var vacio := StyleBoxEmpty.new()
	for tipo in ["CheckBox", "CheckButton"]:
		for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			th.set_stylebox(estado, tipo, vacio)
		th.set_stylebox("focus", tipo, _foco(4, Vector2.ZERO))
		_colores_boton(tipo)
		th.set_font("font", tipo, etiqueta)
		th.set_font_size("font_size", tipo, 17)
		th.set_color("font_outline_color", tipo, Color(0, 0.08, 0.12, 0.35))
		th.set_constant("outline_size", tipo, 4)
		th.set_constant("h_separation", tipo, 14)
	th.set_icon("checked", "CheckBox", _icono("casilla_si"))
	th.set_icon("unchecked", "CheckBox", _icono("casilla_no"))
	th.set_icon("checked_disabled", "CheckBox", _icono("casilla_si"))
	th.set_icon("unchecked_disabled", "CheckBox", _icono("casilla_no"))
	th.set_icon("checked", "CheckButton", _icono("interruptor_si"))
	th.set_icon("unchecked", "CheckButton", _icono("interruptor_no"))
	th.set_icon("checked_disabled", "CheckButton", _icono("interruptor_si"))
	th.set_icon("unchecked_disabled", "CheckButton", _icono("interruptor_no"))

	# ---------------------------------------------------------------- Paneles
	var fila := StyleBoxFlat.new()
	fila.bg_color = Color(0, 0, 0, 0)
	fila.content_margin_left = 14
	fila.content_margin_right = 14
	fila.content_margin_top = 2
	fila.content_margin_bottom = 2
	th.set_type_variation("FilaOpcion", "PanelContainer")
	th.set_stylebox("panel", "FilaOpcion", fila)
	var fila_foco := fila.duplicate() as StyleBoxFlat
	fila_foco.bg_color = Color(CIAN.r, CIAN.g, CIAN.b, 0.26)
	fila_foco.border_color = BLANCO
	fila_foco.border_width_left = 3
	th.set_type_variation("FilaOpcionFoco", "PanelContainer")
	th.set_stylebox("panel", "FilaOpcionFoco", fila_foco)

	var tarjeta := _caja(Color(CIAN.r, CIAN.g, CIAN.b, 0.42), CIAN_BORDE, 0, 3)
	tarjeta.border_width_left = 4
	tarjeta.content_margin_left = 22
	tarjeta.content_margin_right = 22
	tarjeta.content_margin_top = 16
	tarjeta.content_margin_bottom = 18
	tarjeta.shadow_color = SOMBRA
	tarjeta.shadow_size = 12
	tarjeta.shadow_offset = Vector2(0, 4)
	th.set_type_variation("Tarjeta", "PanelContainer")
	th.set_stylebox("panel", "Tarjeta", tarjeta)

	var aviso := _caja(CIAN, CIAN_BORDE, 2, 3)
	aviso.content_margin_left = 22
	aviso.content_margin_right = 22
	aviso.content_margin_top = 8
	aviso.content_margin_bottom = 10
	aviso.shadow_color = SOMBRA
	aviso.shadow_size = 10
	th.set_type_variation("Aviso", "PanelContainer")
	th.set_stylebox("panel", "Aviso", aviso)
	th.set_stylebox("panel", "PanelContainer", aviso)

	# Línea fina blanca (separadores y la raya bajo el título)
	var linea := StyleBoxLine.new()
	linea.color = Color(1, 1, 1, 0.45)
	linea.thickness = 1
	th.set_stylebox("separator", "HSeparator", linea)
	th.set_constant("separation", "HSeparator", 6)

	# Barras de desplazamiento finas
	for tipo in ["VScrollBar", "HScrollBar"]:
		var pista := StyleBoxFlat.new()
		pista.bg_color = Color(1, 1, 1, 0.12)
		pista.set_corner_radius_all(3)
		pista.content_margin_left = 3
		pista.content_margin_right = 3
		pista.content_margin_top = 3
		pista.content_margin_bottom = 3
		var agarre := pista.duplicate() as StyleBoxFlat
		agarre.bg_color = Color(1, 1, 1, 0.6)
		var agarre_luz := pista.duplicate() as StyleBoxFlat
		agarre_luz.bg_color = Color(1, 1, 1, 0.85)
		th.set_stylebox("scroll", tipo, pista)
		th.set_stylebox("grabber", tipo, agarre)
		th.set_stylebox("grabber_highlight", tipo, agarre_luz)
		th.set_stylebox("grabber_pressed", tipo, agarre_luz)

	# Globitos de ayuda
	var globo := _caja(CIAN_OSCURO, CIAN_BORDE, 1, 3)
	globo.content_margin_left = 10
	globo.content_margin_right = 10
	globo.content_margin_top = 6
	globo.content_margin_bottom = 6
	th.set_stylebox("panel", "TooltipPanel", globo)
	th.set_color("font_color", "TooltipLabel", BLANCO)
	th.set_font("font", "TooltipLabel", fina)
	th.set_font_size("font_size", "TooltipLabel", 15)


# ---------------------------------------------------------------- Ayudantes

func _variacion(ruta: String, peso: int, espaciado: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(ruta)
	if peso > 0:
		f.variation_opentype = {WGHT: peso}
	f.spacing_glyph = espaciado
	return f


func _variante_label(nombre: String, fuente: Font, tam: int, sombra_y: int, sombra_tam: int) -> void:
	th.set_type_variation(nombre, "Label")
	th.set_font("font", nombre, fuente)
	th.set_font_size("font_size", nombre, tam)
	th.set_constant("shadow_offset_y", nombre, sombra_y)
	th.set_constant("shadow_outline_size", nombre, sombra_tam)


func _colores_boton(tipo: String) -> void:
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(c, tipo, BLANCO)
	th.set_color("font_disabled_color", tipo, Color(1, 1, 1, 0.4))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		th.set_color(c, tipo, BLANCO)


func _caja(fondo: Color, borde: Color, ancho: int, radio: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(radio)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	s.anti_aliasing = true
	return s


## Borde blanco fino que se dibuja encima del recuadro cuando el control tiene el foco.
func _foco(radio: int, sesgo: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = true
	s.bg_color = Color(1, 1, 1, 0.12)
	s.border_color = BLANCO
	s.set_border_width_all(2)
	s.set_corner_radius_all(radio)
	s.skew = sesgo
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s


## Barra en diagonal (ref3). lado = 0: sale del borde derecho de la pantalla; 1: del izquierdo.
func _barra(fondo: Color, borde: Color, sesgo: Vector2, lado: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.skew = sesgo
	s.anti_aliasing = true
	if lado == 0:
		s.border_width_left = 3
		s.expand_margin_right = 40
		s.content_margin_left = 30
		s.content_margin_right = 46
	else:
		s.border_width_right = 3
		s.expand_margin_left = 40
		s.content_margin_left = 46
		s.content_margin_right = 30
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = SOMBRA
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


func _icono(nombre: String) -> Texture2D:
	return load(ICONOS + nombre + ".svg")
