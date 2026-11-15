class_name ConfirmarNueva
extends Control
## Aviso al elegir NUEVA PARTIDA cuando ya hay una partida guardada: se va a borrar. Es una tarjeta
## del estilo del menú, a la derecha (la paloma de la jugadora, abajo a la izquierda, queda a la
## vista: ladea la cabeza como preguntando, ver GestosPaloma.preguntar).
## Esc o CANCELAR vuelven al menú; EMPEZAR DE NUEVO avisa con "confirmada".

signal confirmada
signal cancelada

var _resumen: Label
var _cancelar: Button
var _empezar: Button


func _init() -> void:
	name = "ConfirmarNueva"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = EstiloUI.TEMA
	visible = false

	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.03, 0.06, 0.35)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)

	var centro := CenterContainer.new()
	centro.anchor_left = 0.42
	centro.anchor_right = 1.0
	centro.anchor_bottom = 1.0
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	var tarjeta := PanelContainer.new()
	tarjeta.theme_type_variation = &"Tarjeta"
	centro.add_child(tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	caja.custom_minimum_size = Vector2(430, 0)
	tarjeta.add_child(caja)

	EstiloUI.texto(caja, &"Seccion", 26, "¿EMPEZAR UNA PARTIDA NUEVA?").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var aviso := EstiloUI.texto(caja, &"TextoTarjeta", 18, "SE BORRARÁ TU PARTIDA ANTERIOR\nY NO SE PUEDE RECUPERAR.")
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resumen = EstiloUI.texto(caja, &"TextoChico", 15)
	_resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_child(fila)
	_cancelar = _boton(fila, "CANCELAR", 150)
	_empezar = _boton(fila, "EMPEZAR DE NUEVO", 230)
	_cancelar.pressed.connect(cerrar)
	_empezar.pressed.connect(func() -> void:
		visible = false
		confirmada.emit())


func _boton(padre: Node, texto: String, ancho: float) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(ancho, 44)
	b.mouse_entered.connect(b.grab_focus)
	padre.add_child(b)
	return b


## Muestra el aviso con un resumen de la partida que se va a borrar. El foco empieza en CANCELAR
## (lo seguro) para que un Enter apurado no borre nada.
func abrir(datos: Dictionary) -> void:
	var bandada := int(datos.get("bandada", 0))
	_resumen.text = tr("%d %s  ·  %d DE COMIDA") % [bandada, tr("PALOMA" if bandada == 1 else "PALOMAS"),
		int(datos.get("comida", 0))]
	modulate.a = 0.0
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	_cancelar.grab_focus()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	cancelada.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()
