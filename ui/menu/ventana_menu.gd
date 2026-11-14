class_name VentanaMenu
extends Control
## Ventanita modal del menú con el estilo de los carteles: pergamino con borde bordó.
## Uso: var v := VentanaMenu.new(); v.armar("Título"); v.contenido.add_child(...); padre.add_child(v)

signal cerrada

const BORDO := Color(0.40, 0.07, 0.04)
const PERGAMINO := Color(0.99, 0.80, 0.47)
const NARANJA := Color(0.96, 0.62, 0.27)
const DORADO := Color(0.98, 0.74, 0.30)

var contenido: VBoxContainer
var _panel: PanelContainer
var _volver: Button


func armar(titulo: String) -> void:
	name = "Ventana" + titulo.replace(" ", "")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	visible = false
	theme = crear_tema()

	var fondo := ColorRect.new()
	fondo.color = Color(0.08, 0.05, 0.12, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(_click_afuera)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	centro.add_child(_panel)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	_panel.add_child(caja)

	var t := Label.new()
	t.text = titulo
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", BORDO)
	t.add_theme_color_override("font_outline_color", DORADO)
	t.add_theme_constant_override("outline_size", 6)
	caja.add_child(t)

	contenido = VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 12)
	caja.add_child(contenido)

	_volver = Button.new()
	_volver.text = "Volver"
	_volver.custom_minimum_size = Vector2(200, 48)
	_volver.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_volver.pressed.connect(cerrar)
	caja.add_child(_volver)


func abrir() -> void:
	visible = true
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	# Foco en el primer control que lo acepte (para manejarlo con teclado)
	var primero := _primer_enfocable(contenido)
	(primero if primero else _volver).grab_focus()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	cerrada.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pausa")):
		cerrar()
		get_viewport().set_input_as_handled()


func _click_afuera(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cerrar()


func _primer_enfocable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and not c is Label:
			return c
		var dentro := _primer_enfocable(c)
		if dentro:
			return dentro
	return null


## Tema con los colores del cartel para paneles, botones, deslizadores y casillas.
static func crear_tema() -> Theme:
	var th := Theme.new()
	th.default_font_size = 24

	var panel := StyleBoxFlat.new()
	panel.bg_color = PERGAMINO
	panel.border_color = BORDO
	panel.set_border_width_all(6)
	panel.set_corner_radius_all(10)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 6)
	panel.content_margin_left = 34
	panel.content_margin_right = 34
	panel.content_margin_top = 22
	panel.content_margin_bottom = 26
	th.set_stylebox("panel", "PanelContainer", panel)

	var normal := _caja(NARANJA, BORDO, 4)
	var hover := _caja(NARANJA.lightened(0.18), BORDO, 4)
	var apretado := _caja(NARANJA.darkened(0.15), BORDO, 4)
	var foco := _caja(Color(0, 0, 0, 0), DORADO.lightened(0.3), 3)
	foco.draw_center = false
	foco.expand_margin_left = 3
	foco.expand_margin_right = 3
	foco.expand_margin_top = 3
	foco.expand_margin_bottom = 3
	for tipo in ["Button", "CheckButton"]:
		th.set_color("font_color", tipo, BORDO)
		th.set_color("font_hover_color", tipo, BORDO)
		th.set_color("font_pressed_color", tipo, BORDO)
		th.set_color("font_focus_color", tipo, BORDO)
		th.set_color("font_hover_pressed_color", tipo, BORDO)
		th.set_stylebox("focus", tipo, foco)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", apretado)
	th.set_stylebox("hover_pressed", "Button", apretado)
	# Las casillas sin fondo: sólo texto + interruptor
	var vacio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "hover_pressed"]:
		th.set_stylebox(estado, "CheckButton", vacio)

	th.set_color("font_color", "Label", BORDO)

	var riel := _caja(BORDO.darkened(0.2), BORDO, 0)
	riel.content_margin_top = 4
	riel.content_margin_bottom = 4
	var lleno := _caja(NARANJA.darkened(0.05), BORDO, 0)
	lleno.content_margin_top = 4
	lleno.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", riel)
	th.set_stylebox("grabber_area", "HSlider", lleno)
	th.set_stylebox("grabber_area_highlight", "HSlider", lleno)
	return th


static func _caja(fondo: Color, borde: Color, ancho: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.set_corner_radius_all(6)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
