class_name SelectorPaloma
extends HBoxContainer
## Selector de una fila de "Personalizar paloma": flechas a los costados y en el medio, o swatches
## de colores o el nombre de la opción. Sólo muestra y avisa (elegido): no sabe de perfiles.
## Con foco responde a izquierda y derecha (teclado o cruceta del mando) y a aceptar (siguiente);
## con el mouse, a las flechas y a cada swatch. Posición 0 = "original" (colores) o "ninguno".

signal elegido(pos: int)

const ANCHO_SWATCH := 19.0

var cantidad := 0
var pos := 0

var _swatches: Array[Button] = []
var _estilos: Array[StyleBoxFlat] = []
var _texto: Label
var _nombres: Array[String] = []


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)


## Una fila de colores: "colores" son los de la paleta (la posición 0 es "original", sin color).
## Con "con_original" en false no hay posición "original": la 0 es el primer color.
func configurar_colores(colores: Array[Color], nombres: Array[String], con_original := true) -> void:
	var desde := 1 if con_original else 0
	cantidad = colores.size() + desde
	_flecha(-1)
	for i in cantidad:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(ANCHO_SWATCH, 30)
		var es_original := con_original and i == 0
		b.tooltip_text = "Original" if es_original else nombres[i - desde]
		var color := Color(0.22, 0.25, 0.3) if es_original else colores[i - desde]
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = color
		estilo.set_corner_radius_all(2)
		estilo.set_border_width_all(1)
		estilo.border_color = Color(0, 0, 0, 0.45)
		for e in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(e, estilo)
		if es_original:
			# Sin color: un cuadrito oscuro tachado
			b.draw.connect(func() -> void:
				b.draw_line(Vector2(4, b.size.y - 5), Vector2(b.size.x - 4, 5), Color(1, 1, 1, 0.8), 2.0))
		b.pressed.connect(_pedir.bind(i))
		add_child(b)
		_swatches.append(b)
		_estilos.append(estilo)
	_flecha(1)


## Una fila de texto: "nombres" son las opciones; la posición 0 es "Ninguno".
func configurar_texto(nombres: Array[String]) -> void:
	_nombres = nombres
	cantidad = nombres.size()
	_flecha(-1)
	_texto = Label.new()
	_texto.theme_type_variation = &"Valor"
	_texto.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.custom_minimum_size = Vector2(190, 30)
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto)
	_flecha(1)


## Marca la posición sin avisar (para refrescar desde el perfil).
## En una fila de colores, -1 no marca ninguno (un color que no es de la paleta).
func set_pos(p: int) -> void:
	pos = clampi(p, 0 if _texto else -1, maxi(cantidad - 1, 0))
	for i in _estilos.size():
		var sel := i == pos
		_estilos[i].border_color = Color.WHITE if sel else Color(0, 0, 0, 0.45)
		_estilos[i].set_border_width_all(3 if sel else 1)
		_swatches[i].queue_redraw()
	if _texto:
		_texto.text = _nombres[pos].to_upper()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_pedir(posmod(pos - 1, cantidad))
		accept_event()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		_pedir(posmod(pos + 1, cantidad))
		accept_event()


func _pedir(i: int) -> void:
	grab_focus()
	elegido.emit(i)


## Flecha triangular dibujada (sin depender de que la tipografía tenga ◀ ▶).
func _flecha(sentido: int) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 30)
	b.draw.connect(func() -> void:
		var c := b.size * 0.5
		var color := Color(1, 1, 1, 0.95 if b.is_hovered() else 0.75)
		var puntas := PackedVector2Array([c + Vector2(5 * sentido, 0), c + Vector2(-4 * sentido, -7), c + Vector2(-4 * sentido, 7)])
		b.draw_colored_polygon(puntas, color))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.pressed.connect(func() -> void: _pedir(posmod(pos + sentido, cantidad)))
	add_child(b)
