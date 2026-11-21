class_name PantallaAlbum
extends PantallaMenu
## Álbum de fotos (botón ÁLBUM de la pausa): las fotos del modo cámara como polaroids, de la más nueva a
## la más vieja. Click (o Enter) abre una en el visor: flechas o A / D para pasar de una a otra, BORRAR
## (hay que apretarlo dos veces) y CERRAR. Abajo, un botón que abre la carpeta de las fotos en el sistema.
## Los datos salen de AlbumFotos.

const COLUMNAS := 3
const MAX_EN_PANTALLA := 60              ## Para no tardar en abrir con cientos de fotos
const C_PAPEL := Color("f6f1e4")

var _rutas: Array[String] = []
var _visor: Control
var _foto: TextureRect
var _fecha: Label
var _cuenta: Label
var _borrar: Button
var _cerrar_visor: Button
var _indice := 0
var _borrar_t := 0.0


func _init() -> void:
	armar("Álbum")
	_derecha.anchor_left = 0.36             # Más ancho que el resto de las pantallas: es una grilla
	_izquierda.offset_right = 420.0
	_armar_visor()


## Vuelve a leer las fotos del disco y arma la grilla (llamar antes de abrir).
func refrescar() -> void:
	for c in contenido.get_children():
		c.queue_free()
		contenido.remove_child(c)
	_rutas = AlbumFotos.listar()
	seccion(tr("Fotos (%d)") % _rutas.size())
	if _rutas.is_empty():
		var vacio := Label.new()
		vacio.theme_type_variation = &"TextoChico"
		vacio.text = tr("Todavía no sacaste ninguna foto.\nApretá C en la partida para entrar al modo cámara.")
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD
		vacio.custom_minimum_size = Vector2(420, 0)
		contenido.add_child(vacio)
	else:
		var grilla := GridContainer.new()
		grilla.name = "Grilla"
		grilla.columns = COLUMNAS
		grilla.add_theme_constant_override("h_separation", 14)
		grilla.add_theme_constant_override("v_separation", 14)
		contenido.add_child(grilla)
		for i in mini(_rutas.size(), MAX_EN_PANTALLA):
			grilla.add_child(_polaroid(i))
		if _rutas.size() > MAX_EN_PANTALLA:
			var mas := Label.new()
			mas.theme_type_variation = &"TextoChico"
			mas.text = tr("Se muestran las %d más nuevas.") % MAX_EN_PANTALLA
			mas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			contenido.add_child(mas)
	if not OS.has_feature("web"):
		var abrir_carpeta := Button.new()
		abrir_carpeta.text = tr("ABRIR CARPETA DE FOTOS")
		abrir_carpeta.custom_minimum_size = Vector2(300, 44)
		abrir_carpeta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		abrir_carpeta.pressed.connect(func() -> void: OS.shell_open(AlbumFotos.carpeta_absoluta()))
		contenido.add_child(abrir_carpeta)


## Cantidad de fotos que muestra ahora (para las pruebas).
func cantidad() -> int:
	return _rutas.size()


func visor_abierto() -> bool:
	return _visor.visible


func foto_actual() -> String:
	return _rutas[_indice] if _indice < _rutas.size() else ""


# ---------------------------------------------------------------- Grilla

## Una foto de la grilla: un marco de polaroid (papel claro, la foto y la fecha abajo) que es un botón.
func _polaroid(i: int) -> Button:
	var b := Button.new()
	b.name = "Foto%d" % i
	b.custom_minimum_size = Vector2(190, 168)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var normal := StyleBoxFlat.new()
	normal.bg_color = C_PAPEL
	normal.set_corner_radius_all(3)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	var foco := normal.duplicate() as StyleBoxFlat
	foco.border_color = Color("3fb8d6")
	foco.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", foco)
	b.add_theme_stylebox_override("pressed", foco)
	b.add_theme_stylebox_override("focus", foco)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8.0
	v.offset_right = -8.0
	v.offset_top = 8.0
	v.offset_bottom = -4.0
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var img := TextureRect.new()
	img.texture = AlbumFotos.miniatura(_rutas[i])
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var l := Label.new()
	l.text = AlbumFotos.fecha_de(_rutas[i])
	l.add_theme_font_size_override("font_size", 12)
	AlbumFotos.tinta(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(abrir_visor.bind(i))
	b.mouse_entered.connect(func() -> void:
		if not b.has_focus():
			b.grab_focus())
	return b


# ---------------------------------------------------------------- Visor

func _armar_visor() -> void:
	_visor = Control.new()
	_visor.name = "Visor"
	_visor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visor.mouse_filter = Control.MOUSE_FILTER_STOP
	_visor.visible = false
	add_child(_visor)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.02, 0.04, 0.92)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visor.add_child(fondo)
	var marco := PanelContainer.new()
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	marco.offset_left = 90.0
	marco.offset_right = -90.0
	marco.offset_top = 36.0
	marco.offset_bottom = -120.0
	var papel := StyleBoxFlat.new()
	papel.bg_color = C_PAPEL
	papel.set_corner_radius_all(4)
	papel.content_margin_left = 14
	papel.content_margin_right = 14
	papel.content_margin_top = 14
	papel.content_margin_bottom = 14
	papel.shadow_size = 10
	papel.shadow_color = Color(0, 0, 0, 0.5)
	marco.add_theme_stylebox_override("panel", papel)
	_visor.add_child(marco)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	marco.add_child(col)
	_foto = TextureRect.new()
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_foto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_foto)
	_fecha = Label.new()
	_fecha.add_theme_font_size_override("font_size", 18)
	AlbumFotos.tinta(_fecha)
	_fecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fecha)
	# Botones abajo
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fila.offset_top = -100.0
	fila.offset_bottom = -40.0
	fila.add_theme_constant_override("separation", 14)
	_visor.add_child(fila)
	fila.add_child(_boton("◀", func() -> void: _mover(-1), 70))
	_cuenta = Label.new()
	_cuenta.custom_minimum_size = Vector2(90, 0)
	_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cuenta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(_cuenta)
	fila.add_child(_boton("▶", func() -> void: _mover(1), 70))
	_borrar = _boton(tr("BORRAR"), _al_borrar, 190)
	fila.add_child(_borrar)
	_cerrar_visor = _boton(tr("CERRAR"), cerrar_visor, 190)
	fila.add_child(_cerrar_visor)


func _boton(texto: String, accion: Callable, ancho: float) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 48)
	b.pressed.connect(accion)
	return b


func abrir_visor(i: int) -> void:
	if i < 0 or i >= _rutas.size():
		return
	_indice = i
	_mostrar()
	_visor.visible = true
	AudioManager.ui("menu_open", -8.0)
	_cerrar_visor.grab_focus()


func cerrar_visor() -> void:
	if not _visor.visible:
		return
	_visor.visible = false
	AudioManager.ui("menu_close", -8.0)
	var grilla := contenido.get_node_or_null("Grilla")
	if grilla and _indice < grilla.get_child_count():
		(grilla.get_child(_indice) as Control).grab_focus()
	else:
		volver.grab_focus()


func _mostrar() -> void:
	_foto.texture = AlbumFotos.textura(_rutas[_indice])
	_fecha.text = AlbumFotos.fecha_de(_rutas[_indice])
	_cuenta.text = "%d / %d" % [_indice + 1, _rutas.size()]
	_borrar_t = 0.0
	_borrar.text = tr("BORRAR")


func _mover(paso: int) -> void:
	if _rutas.size() <= 1:
		return
	_indice = wrapi(_indice + paso, 0, _rutas.size())
	_mostrar()
	AudioManager.ui("highlight", -12.0)


## Primer toque: pide confirmar. Segundo (dentro de 3 s): borra la foto y pasa a la siguiente (o cierra).
func _al_borrar() -> void:
	if _borrar_t <= 0.0:
		_borrar_t = 3.0
		_borrar.text = tr("¿SEGURO? BORRAR")
		return
	var ruta := _rutas[_indice]
	AlbumFotos.borrar(ruta)
	_rutas.remove_at(_indice)
	AudioManager.ui("failure", -8.0)
	var viejo := _indice
	if _rutas.is_empty():
		_visor.visible = false
		refrescar()
		volver.grab_focus()
		return
	_indice = mini(viejo, _rutas.size() - 1)
	var cerca := _indice
	refrescar()
	_indice = cerca
	_mostrar()


func _process(delta: float) -> void:
	if _borrar_t > 0.0:
		_borrar_t -= delta
		if _borrar_t <= 0.0:
			_borrar.text = tr("BORRAR")


# ---------------------------------------------------------------- Teclas

func _input(event: InputEvent) -> void:
	if not visible or not _visor.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa"):
		cerrar_visor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_A):
		_mover(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_D):
		_mover(1)
		get_viewport().set_input_as_handled()


## Con el álbum cerrado se cierra también el visor.
func cerrar() -> void:
	_visor.visible = false
	super.cerrar()
