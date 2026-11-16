class_name MenuPrincipal
extends CanvasLayer
## Menú principal: "PALOMA RETOMA" arriba a la derecha y las opciones abajo a la derecha, en barras
## cyan translúcidas con el texto blanco alineado a la derecha. Va encima del mundo 3D ya cargado
## (la escena principal es main.tscn); la paloma de la jugadora queda abajo a la izquierda.
## Con el mouse encima o con foco (teclado o mando) la barra se aclara, toma un borde blanco y se
## estira hacia la izquierda. No arranca la partida por su cuenta: avisa con señales a main.gd.

signal nueva_partida
signal continuar(datos: Dictionary)
## La jugadora está decidiendo si borra su partida (la paloma ladea la cabeza, ver main.gd)
signal preguntando(si: bool)

const ESTIRAR := 26.0          ## Píxeles que crece la barra hacia la izquierda con foco

var _opciones: OpcionesMenu
var _cargar: CargarMenu
var _personalizar: PersonalizarMenu
var _accesorios: AccesoriosMenu    ## TEMPORAL: equipar accesorios rápido
var _btn_accesorios: Button
var _logros: LogrosMenu
var _btn_logros: Button        ## El trofeo de arriba a la izquierda
var _txt_logros: Label         ## ...con cuántos lleva
var _confirmar: ConfirmarNueva
var _idiomas: SelectorIdioma
var _activo := false
var _tween: Tween

@onready var raiz: Control = $Raiz
@onready var titulo: Control = %Titulo
@onready var caja_botones: VBoxContainer = %Botones
@onready var botones: Array[Button] = [%Continuar, %NuevaPartida, %CargarPartida, %Personalizar, %Opciones, %Salir]


func _ready() -> void:
	visible = false
	# TEMPORAL: botón "ACCESORIOS" debajo de "PERSONALIZAR PALOMA" (una copia de esa fila), que abre la
	# pantalla para equipar los accesorios rápido (AccesoriosMenu)
	var fila_acc := _fila(%Personalizar).duplicate() as Control
	fila_acc.name = "FilaAccesorios"
	caja_botones.add_child(fila_acc)
	caja_botones.move_child(fila_acc, _fila(%Personalizar).get_index() + 1)
	_btn_accesorios = fila_acc.get_child(0).get_child(0) as Button
	_btn_accesorios.name = "Accesorios"
	_btn_accesorios.unique_name_in_owner = false
	_btn_accesorios.text = "ACCESORIOS"
	botones.insert(botones.find(%Personalizar) + 1, _btn_accesorios)
	for b in botones:
		_preparar_boton(b)
	%Continuar.pressed.connect(_continuar)
	%NuevaPartida.pressed.connect(_nueva)
	%CargarPartida.pressed.connect(_abrir.bind("cargar"))
	%Personalizar.pressed.connect(_abrir.bind("personalizar"))
	%Opciones.pressed.connect(_abrir.bind("opciones"))
	%Salir.pressed.connect(_salir)
	# En el navegador "Salir" no tiene sentido (dejaría la pestaña congelada)
	_fila(%Salir).visible = not OS.has_feature("web")

	_opciones = OpcionesMenu.new()
	add_child(_opciones)
	_opciones.cerrada.connect(_al_cerrar_pantalla.bind(%Opciones))
	_cargar = CargarMenu.new()
	add_child(_cargar)
	_cargar.cerrada.connect(_al_cerrar_pantalla.bind(%CargarPartida))
	_cargar.cargar.connect(func(datos: Dictionary) -> void: _arrancar(continuar.emit.bind(datos)))
	_accesorios = AccesoriosMenu.new()
	add_child(_accesorios)
	_accesorios.cerrada.connect(_al_cerrar_pantalla.bind(_btn_accesorios))
	_btn_accesorios.pressed.connect(_abrir.bind("accesorios"))
	_personalizar = PersonalizarMenu.new()
	add_child(_personalizar)
	_personalizar.cerrada.connect(_al_cerrar_pantalla.bind(%Personalizar))
	_logros = LogrosMenu.new()
	add_child(_logros)
	_logros.cerrada.connect(_al_cerrar_logros)
	_armar_boton_logros()
	_confirmar = ConfirmarNueva.new()
	add_child(_confirmar)
	_confirmar.confirmada.connect(_al_confirmar_nueva)
	_confirmar.cancelada.connect(_al_cancelar_nueva)

	# Banderas para cambiar de idioma, abajo a la izquierda
	# ...y debajo, chiquita, la versión con quién hizo el último commit
	var esquina := VBoxContainer.new()
	esquina.name = "Esquina"
	esquina.add_theme_constant_override("separation", 5)
	esquina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(esquina)
	_idiomas = SelectorIdioma.new()
	esquina.add_child(_idiomas)
	var version := EstiloUI.texto(esquina, &"TextoChico", 12, Version.texto())
	version.name = "Version"
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	esquina.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 26)


## Muestra el menú con una entrada suave (el título baja y los botones entran desde la derecha).
func mostrar() -> void:
	visible = true
	_activo = true
	_actualizar_continuar()
	_actualizar_logros()
	raiz.modulate.a = 1.0
	titulo.modulate.a = 0.0
	titulo.position.y = _y_base(titulo) - 24.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.7).set_delay(0.15)
	tw.tween_property(titulo, "position:y", _y_base(titulo), 0.9).set_delay(0.15)
	var i := 0
	for b in botones:
		if not _fila(b).visible:
			continue
		var desliz := b.get_parent() as Control
		desliz.modulate.a = 0.0
		desliz.position.x = 160.0
		tw.tween_property(desliz, "modulate:a", 1.0, 0.35).set_delay(0.35 + i * 0.07)
		tw.tween_property(desliz, "position:x", 0.0, 0.5).set_delay(0.35 + i * 0.07)
		i += 1
	_enfocar_primero.call_deferred()


## Saca el menú (al empezar la partida): los botones salen hacia la derecha y todo se desvanece.
func ocultar() -> void:
	_activo = false
	_idiomas.set_activo(false)
	_btn_logros.focus_mode = Control.FOCUS_NONE
	_btn_logros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in botones:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var i := 0
	for b in botones:
		tw.tween_property(b.get_parent(), "position:x", 220.0, 0.4).set_delay(i * 0.04)
		i += 1
	tw.tween_property(raiz, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(func() -> void: visible = false)


func _input(event: InputEvent) -> void:
	# Si se perdió el foco (click en un lugar vacío), las flechas o el mando lo recuperan
	if not _activo or _opciones.visible or _cargar.visible or _personalizar.visible or _accesorios.visible or _confirmar.visible or _logros.visible:
		return
	if get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_down")
			or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_accept")):
		_enfocar_primero()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Botones

func _preparar_boton(b: Button) -> void:
	b.mouse_entered.connect(func() -> void:
		if _activo and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())
	b.focus_entered.connect(_resaltar.bind(b, true))
	b.focus_exited.connect(_resaltar.bind(b, false))
	b.button_down.connect(func() -> void: _estirar(b, ESTIRAR * 0.4, 0.06))


func _resaltar(b: Button, si: bool) -> void:
	_estirar(b, ESTIRAR if si else 0.0, 0.2)
	if si and _activo:
		AudioManager.ui("highlight", -8.0)


## La barra crece hacia la izquierda (el texto queda en su lugar, alineado a la derecha).
func _estirar(b: Button, cuanto: float, t: float) -> void:
	if b.has_meta("tween"):
		var viejo: Tween = b.get_meta("tween")
		if viejo and viejo.is_valid():
			viejo.kill()
	var tw := b.create_tween()
	tw.tween_property(b, "offset_left", -cuanto, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("tween", tw)


func _actualizar_continuar() -> void:
	_fila(%Continuar).visible = GameState.hay_partida_guardada()
	# Con flechas o mando se da la vuelta de abajo hacia arriba y al revés
	var visibles: Array[Button] = []
	for b in botones:
		if _fila(b).visible:
			visibles.append(b)
	for i in visibles.size():
		var b := visibles[i]
		var arriba := visibles[(i - 1 + visibles.size()) % visibles.size()]
		var abajo := visibles[(i + 1) % visibles.size()]
		b.focus_neighbor_top = b.get_path_to(arriba)
		b.focus_neighbor_bottom = b.get_path_to(abajo)
		b.focus_neighbor_left = b.get_path_to(_btn_logros)   # Hacia la izquierda está el trofeo
		b.focus_neighbor_right = b.get_path()
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	if not visibles.is_empty():
		_btn_logros.focus_neighbor_right = _btn_logros.get_path_to(visibles[0])
		_btn_logros.focus_neighbor_bottom = _btn_logros.get_path_to(visibles[0])
	_btn_logros.focus_neighbor_left = _btn_logros.get_path()
	_btn_logros.focus_neighbor_top = _btn_logros.get_path()
	_btn_logros.focus_mode = Control.FOCUS_ALL
	_btn_logros.mouse_filter = Control.MOUSE_FILTER_STOP


func _enfocar_primero() -> void:
	for b in botones:
		if _fila(b).visible:
			b.grab_focus()
			return


## Cada botón está en Fila (lugar en la lista) > Desliz (entrada y salida) > Botón (se estira).
func _fila(b: Button) -> Control:
	return b.get_parent().get_parent() as Control


func _continuar() -> void:
	var datos := GameState.datos_guardados()
	if datos.is_empty():
		_actualizar_continuar()
		_enfocar_primero()
		return
	_arrancar(continuar.emit.bind(datos))


## Con una partida guardada, antes avisa que se va a borrar (y la paloma pregunta con la cabeza).
func _nueva() -> void:
	var datos := GameState.datos_guardados()
	if datos.is_empty():
		_arrancar(nueva_partida.emit)
		return
	AudioManager.ui("button", -6.0)
	for b in botones:
		b.focus_mode = Control.FOCUS_NONE
		_resaltar(b, false)
	_btn_logros.focus_mode = Control.FOCUS_NONE
	_desvanecer(0.0)
	preguntando.emit(true)
	_confirmar.abrir(datos)


func _al_confirmar_nueva() -> void:
	preguntando.emit(false)
	GameState.borrar_partida()
	raiz.modulate.a = 1.0
	_arrancar(nueva_partida.emit)


func _al_cancelar_nueva() -> void:
	AudioManager.ui("cancel", -6.0)
	preguntando.emit(false)
	_al_cerrar_pantalla(%NuevaPartida)


func _arrancar(aviso: Callable) -> void:
	if not _activo:
		return
	AudioManager.ui("confirm", -4.0)
	ocultar()
	aviso.call()


func _salir() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- Pantallas (Opciones, Cargar)

func _abrir(cual: String) -> void:
	AudioManager.ui("menu_open", -6.0)
	for b in botones:
		b.focus_mode = Control.FOCUS_NONE
		_resaltar(b, false)
	_btn_logros.focus_mode = Control.FOCUS_NONE
	_desvanecer(0.0)
	match cual:
		"opciones":
			_opciones.abrir()
		"personalizar":
			_personalizar.abrir()
		"accesorios":
			_accesorios.abrir()
		"logros":
			_logros.abrir()
		_:
			_cargar.abrir()


func _al_cerrar_pantalla(boton: Button) -> void:
	_actualizar_continuar()
	_desvanecer(1.0)
	if _fila(boton).visible:
		boton.grab_focus()
	else:
		_enfocar_primero()


func _al_cerrar_logros() -> void:
	_actualizar_continuar()
	_actualizar_logros()
	_desvanecer(1.0)
	_btn_logros.grab_focus()


## El botón cuadrado con el trofeo (arriba a la izquierda) y, debajo del icono, cuántos lleva.
func _armar_boton_logros() -> void:
	_btn_logros = Button.new()
	_btn_logros.name = "Logros"
	_btn_logros.custom_minimum_size = Vector2(76, 76)
	_btn_logros.tooltip_text = "Logros"
	EstiloUI.estilizar_boton(_btn_logros)
	raiz.add_child(_btn_logros)
	_btn_logros.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 26)
	var icono := IconoTrofeo.new()
	icono.set_anchors_preset(Control.PRESET_FULL_RECT)
	icono.offset_left = 12.0
	icono.offset_right = -12.0
	icono.offset_top = 6.0
	icono.offset_bottom = -20.0
	_btn_logros.add_child(icono)
	_txt_logros = EstiloUI.texto(_btn_logros, &"Valor", 13)
	_txt_logros.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_txt_logros.offset_top = -22.0
	_txt_logros.offset_bottom = -2.0
	_txt_logros.offset_left = 0.0
	_txt_logros.offset_right = 0.0
	_txt_logros.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_txt_logros.add_theme_color_override("font_color", Color.WHITE)
	_btn_logros.mouse_entered.connect(func() -> void:
		if _activo and _btn_logros.focus_mode != Control.FOCUS_NONE:
			_btn_logros.grab_focus())
	_btn_logros.focus_entered.connect(func() -> void:
		if _activo:
			AudioManager.ui("highlight", -8.0))
	_btn_logros.pressed.connect(_abrir.bind("logros"))
	_actualizar_logros()


func _actualizar_logros() -> void:
	_txt_logros.text = "%d/%d" % [Logros.cantidad(CatalogoLogros.TROFEO) + Logros.cantidad(CatalogoLogros.LOGRO),
		Logros.total(CatalogoLogros.TROFEO) + Logros.total(CatalogoLogros.LOGRO)]


func _desvanecer(a: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(raiz, "modulate:a", a, 0.18)


func _y_base(c: Control) -> float:
	return c.anchor_top * raiz.size.y + c.offset_top
