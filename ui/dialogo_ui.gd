class_name DialogoUI
extends CanvasLayer
## Pantalla de las conversaciones con NPC (la crea el autoload Dialogos y escucha sus señales):
## - Un aviso abajo ("E  HABLAR CON ...") cuando hay alguien cerca con quien se puede hablar.
##   También se puede tocar o clickear (para el celular).
## - La caja del diálogo en el estilo del HUD: nombre, el texto que se escribe de a poco y, si hay,
##   las opciones como botones (se eligen con click, flechas + Enter o las teclas 1 a 4).
##   E, Enter o click completan la línea y pasan a la siguiente. Esc corta la conversación.

const VELOCIDAD := 55.0         ## Letras por segundo
const ANCHO := 880.0

var _aviso: Button
var _caja: PanelContainer
var _nombre: Label
var _texto: Label
var _opciones: VBoxContainer
var _seguir: Label
var _tween: Tween
var _hay_opciones := false


func _ready() -> void:
	layer = 9       # Arriba de las barras de cinemática (8), abajo de la pausa (20)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = EstiloUI.TEMA
	add_child(raiz)
	_armar_aviso(raiz)
	_armar_caja(raiz)
	Dialogos.cercano_cambio.connect(_al_cambiar_cercano)
	Dialogos.linea_cambio.connect(_mostrar_linea)
	Dialogos.terminado.connect(func() -> void: _caja.visible = false)
	_caja.visible = false
	_aviso.visible = false


func _armar_aviso(raiz: Control) -> void:
	_aviso = Button.new()
	_aviso.focus_mode = Control.FOCUS_NONE
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 120)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.pressed.connect(Dialogos.interactuar)
	for estado in ["normal", "hover", "pressed", "focus"]:
		_aviso.add_theme_stylebox_override(estado, EstiloUI.caja(EstiloUI.C_OSCURO, 0.25, EstiloUI.C_CYAN_BORDE))
	_aviso.add_theme_font_size_override("font_size", 20)
	raiz.add_child(_aviso)


func _armar_caja(raiz: Control) -> void:
	_caja = PanelContainer.new()
	_caja.custom_minimum_size = Vector2(ANCHO, 0)
	_caja.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 60)
	_caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caja.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caja.add_theme_stylebox_override("panel", EstiloUI.caja(Color(0.0, 0.03, 0.06, 0.62), 0.12, EstiloUI.C_CYAN_BORDE))
	_caja.gui_input.connect(_al_tocar_caja)
	raiz.add_child(_caja)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_caja.add_child(v)
	_nombre = EstiloUI.texto(v, &"Seccion", 24)
	_texto = EstiloUI.texto(v, &"TextoTarjeta", 21)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(ANCHO - 90.0, 62)
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 6)
	v.add_child(_opciones)
	_seguir = EstiloUI.texto(v, &"TextoChico", 13, "E · CLICK PARA SEGUIR")
	_seguir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _al_cambiar_cercano(i: Interlocutor) -> void:
	_aviso.visible = i != null
	if i:
		var tecla := "" if Ajustes.movil else "E   "
		_aviso.text = tecla + (tr("HABLAR CON %s") % tr(i.nombre())).to_upper()


func _mostrar_linea(quien: String, texto: String, opciones: Array) -> void:
	_caja.visible = true
	_aviso.visible = false
	_nombre.text = tr(quien).to_upper()
	_texto.text = tr(texto)
	_texto.visible_ratio = 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_texto, "visible_ratio", 1.0, maxf(_texto.text.length() / VELOCIDAD, 0.05))
	for b in _opciones.get_children():
		b.queue_free()
	_hay_opciones = not opciones.is_empty()
	_seguir.visible = not _hay_opciones
	for i in opciones.size():
		var b := Button.new()
		b.text = "%d   %s" % [i + 1, tr(String(opciones[i]))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(_elegir.bind(i))
		_opciones.add_child(b)
	if _hay_opciones:
		(_opciones.get_child(0) as Button).grab_focus.call_deferred()
	AudioManager.reproducir("picoteo", -18.0)


func _elegir(i: int) -> void:
	AudioManager.reproducir("picoteo", -14.0)
	Dialogos.elegir(i)


## Primero completa el texto que se está escribiendo; si ya estaba completo, pasa a lo que sigue.
func _avanzar() -> void:
	if _texto.visible_ratio < 1.0:
		if _tween and _tween.is_valid():
			_tween.kill()
		_texto.visible_ratio = 1.0
	elif not _hay_opciones:
		Dialogos.avanzar()


func _al_tocar_caja(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_avanzar()


func _input(event: InputEvent) -> void:
	if not _caja.visible:
		return
	if event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel"):
		Dialogos.terminar()
	elif event.is_action_pressed("interactuar") or (not _hay_opciones and event.is_action_pressed("ui_accept")):
		_avanzar()
	elif event is InputEventKey and event.pressed and not event.echo and _hay_opciones \
			and event.keycode >= KEY_1 and event.keycode <= KEY_4:
		Dialogos.elegir(event.keycode - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
