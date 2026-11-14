class_name PantallaMenu
extends Control
## Pantalla de menú a pantalla completa con el layout de la referencia de ajustes (ref2):
## título grande y "VOLVER" abajo a la izquierda, y el contenido en una columna a la derecha.
## La usan Opciones (título y pausa) y Cargar partida.
## Uso: var p := PantallaMenu.new(); p.armar("Título"); p.contenido.add_child(...); padre.add_child(p)

signal cerrada

const TEMA := preload("res://ui/tema/tema_paloma.tres")
const ANCHO_ETIQUETA := 250.0

var contenido: VBoxContainer
var volver: Button
var _izquierda: Control
var _derecha: Control
var _tween: Tween


func armar(titulo: String) -> void:
	name = "Pantalla" + titulo.to_pascal_case()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	visible = false
	theme = TEMA

	# Velo oscuro: más denso a la derecha, donde va el texto
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.03, 0.06, 0.42)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	var degrade := TextureRect.new()
	degrade.texture = degrade_horizontal(Color(0, 0.03, 0.06, 0.0), Color(0, 0.03, 0.06, 0.5))
	degrade.set_anchors_preset(Control.PRESET_FULL_RECT)
	degrade.anchor_left = 0.3
	degrade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	degrade.stretch_mode = TextureRect.STRETCH_SCALE
	degrade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(degrade)

	# Izquierda: título y VOLVER
	# Pegada abajo: si el título ocupa dos líneas, crece hacia arriba
	var izq := VBoxContainer.new()
	izq.name = "Izquierda"
	izq.anchor_top = 1.0
	izq.anchor_bottom = 1.0
	izq.offset_left = 64.0
	izq.offset_top = -300.0
	izq.offset_right = 500.0
	izq.offset_bottom = -110.0
	izq.grow_vertical = Control.GROW_DIRECTION_BEGIN
	izq.alignment = BoxContainer.ALIGNMENT_END
	izq.add_theme_constant_override("separation", 6)
	izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(izq)
	_izquierda = izq
	var t := Label.new()
	t.name = "Titulo"
	t.text = titulo.to_upper()
	t.theme_type_variation = &"TituloPantalla"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD   # "CARGAR PARTIDA" va en dos líneas
	izq.add_child(t)
	volver = Button.new()
	volver.name = "Volver"
	volver.text = "VOLVER"
	volver.theme_type_variation = &"BotonVolver"
	volver.alignment = HORIZONTAL_ALIGNMENT_LEFT
	volver.custom_minimum_size = Vector2(250, 46)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	volver.pressed.connect(cerrar)
	volver.mouse_entered.connect(volver.grab_focus)
	izq.add_child(volver)

	# Derecha: columna con las secciones
	var der := MarginContainer.new()
	der.name = "Derecha"
	der.anchor_left = 0.45
	der.anchor_right = 1.0
	der.anchor_bottom = 1.0
	for lado in ["left", "right", "top", "bottom"]:
		der.add_theme_constant_override("margin_" + lado, 0)
	der.add_theme_constant_override("margin_right", 56)
	der.add_theme_constant_override("margin_top", 28)
	der.add_theme_constant_override("margin_bottom", 28)
	add_child(der)
	_derecha = der
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	der.add_child(scroll)
	var centro := VBoxContainer.new()
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centro)
	contenido = VBoxContainer.new()
	contenido.name = "Contenido"
	contenido.add_theme_constant_override("separation", 2)
	centro.add_child(contenido)


func abrir() -> void:
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	# Las dos columnas entran deslizándose hacia el centro
	var x_der := _x_base(_derecha)
	var x_izq := _x_base(_izquierda)
	_derecha.position.x = x_der + 40.0
	_izquierda.position.x = x_izq - 40.0
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_derecha, "position:x", x_der, 0.3)
	_tween.tween_property(_izquierda, "position:x", x_izq, 0.3)
	_enlazar_foco()
	var primero := primer_enfocable(contenido)
	(primero if primero else volver).grab_focus()


func cerrar() -> void:
	if not visible:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_derecha.position.x = _x_base(_derecha)
	_izquierda.position.x = _x_base(_izquierda)
	visible = false
	cerrada.emit()


## Posición x que le da el anclaje a un hijo directo (esta pantalla ocupa todo su padre).
func _x_base(c: Control) -> float:
	return c.anchor_left * size.x + c.offset_left


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa")):
		cerrar()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Filas

## Título de sección ("AUDIO", "PANTALLA"...), centrado sobre la columna de controles.
func seccion(texto: String) -> Label:
	var l := Label.new()
	l.text = texto.to_upper()
	l.theme_type_variation = &"Seccion"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 42)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	contenido.add_child(l)
	return l


## Fila con una etiqueta a la izquierda y el control a la derecha. Se resalta cuando el control
## tiene el foco (para manejarlo con teclado o mando).
func fila(texto: String, control: Control, valor: Label = null) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"FilaOpcion"
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	panel.add_child(caja)
	var l := Label.new()
	l.text = texto.to_upper()
	l.theme_type_variation = &"Etiqueta"
	l.custom_minimum_size = Vector2(ANCHO_ETIQUETA, 30)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caja.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(control)
	if valor:
		valor.theme_type_variation = &"Valor"
		valor.custom_minimum_size = Vector2(58, 0)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caja.add_child(valor)
	control.focus_entered.connect(func() -> void: panel.theme_type_variation = &"FilaOpcionFoco")
	control.focus_exited.connect(func() -> void: panel.theme_type_variation = &"FilaOpcion")
	panel.mouse_entered.connect(func() -> void:
		if control.focus_mode != Control.FOCUS_NONE and not control.has_focus():
			control.grab_focus())
	contenido.add_child(panel)
	return panel


func deslizador(minimo: float, maximo: float, paso: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.custom_minimum_size = Vector2(200, 24)
	return s


func desplegable() -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(220, 32)
	o.fit_to_longest_item = false
	o.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return o


## Une el último control con VOLVER (y VOLVER con el primero) para que con las flechas o el mando
## se pueda dar la vuelta. Cada control usa su propio orden vertical.
func _enlazar_foco() -> void:
	var lista: Array[Control] = []
	_juntar_enfocables(contenido, lista)
	if lista.is_empty():
		return
	var primero := lista[0]
	var ultimo := lista[lista.size() - 1]
	ultimo.focus_neighbor_bottom = ultimo.get_path_to(volver)
	primero.focus_neighbor_top = primero.get_path_to(volver)
	volver.focus_neighbor_top = volver.get_path_to(ultimo)
	volver.focus_neighbor_bottom = volver.get_path_to(primero)
	for c in lista:
		if not c is Range:
			c.focus_neighbor_left = c.get_path_to(volver)
	volver.focus_neighbor_right = volver.get_path_to(primero)


func _juntar_enfocables(n: Node, lista: Array[Control]) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).is_visible_in_tree():
			lista.append(c)
		else:
			_juntar_enfocables(c, lista)


static func primer_enfocable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and (c as Control).visible \
				and not (c is BaseButton and (c as BaseButton).disabled):
			return c
		var dentro := primer_enfocable(c)
		if dentro:
			return dentro
	return null


## Textura de degradé horizontal (de "desde" a "hasta") para velos de legibilidad.
static func degrade_horizontal(desde: Color, hasta: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, desde)
	g.set_color(1, hasta)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	return t
