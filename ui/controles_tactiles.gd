class_name ControlesTactiles
extends CanvasLayer
## Controles táctiles de la versión para teléfonos (sólo existe si Ajustes.movil; main.gd la agrega).
## - Mitad izquierda: joystick flotante (aparece donde apoyás el dedo) para caminar / volar.
## - Mitad derecha: deslizar el dedo mueve la cámara.
## - Botones abajo a la derecha, al alcance del pulgar: VOLAR (mantener = aletear), PICADA (mantener),
##   PICOTEAR y ARRULLAR. Arriba a la derecha, la pausa.
## Todo se traduce a las mismas acciones del Input Map que usa la PC (mover_*, volar, picada,
## picotear, arrullar), así la paloma no sabe si la manejan con teclado o con el dedo.

const RADIO_JOY := 115.0        ## Recorrido del joystick (unidades de pantalla, base 1280x720)
const RADIO_PERILLA := 50.0
const ZONA_MUERTA := 0.12
const ZONA_JOY := 0.42          ## Fracción izquierda de la pantalla que maneja el joystick
const TOQUE_MINIMO := 0.09      ## Un toque cortito se mantiene apretado este tiempo (lo ve la física)

const C_BORDE := Color(1, 1, 1, 0.55)
const C_TEXTO := Color("fffaf0")
const C_SOMBRA := Color(0.12, 0.1, 0.18, 0.85)

## Nodo de la pausa (ui/pausa.gd): el botón ❚❚ llama a pausar().
var pausa: Node

var _lienzo: Control
var _jugador: PalomaJugador
var _fuente: Font
var _botones: Array[Dictionary] = []
var _joy_toque := -1
var _joy_base := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _cam_toque := -1
var _fin := false   ## Ganaste: los controles no vuelven


func _ready() -> void:
	layer = 6   # arriba del HUD (5) y abajo de la pausa (20)
	_fuente = ThemeDB.fallback_font
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_dibujar)
	add_child(_lienzo)
	_botones = [
		_boton("volar", &"volar", "VOLAR", Vector2(-165, -160), 90.0, true, Color("7fd6ff")),
		_boton("picotear", &"picotear", "PICOTEAR", Vector2(-372, -112), 68.0, false, Color("ffe58a")),
		_boton("picada", &"picada", "PICADA", Vector2(-340, -305), 66.0, true, Color("ffad66")),
		_boton("arrullar", &"arrullar", "ARRULLAR", Vector2(-145, -378), 64.0, false, Color("ff9ecb")),
		_boton("pausa", &"", "II", Vector2(-62, 0), 42.0, false, Color(1, 1, 1)),
	]
	GameState.victoria.connect(func() -> void: _fin = true)
	visible = false
	_buscar_jugador.call_deferred()


func _buscar_jugador() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador") as PalomaJugador


func _boton(id: String, accion: StringName, texto: String, offset: Vector2, radio: float,
		mantener: bool, color: Color) -> Dictionary:
	return {"id": id, "accion": accion, "texto": texto, "offset": offset, "radio": radio,
		"mantener": mantener, "color": color, "toque": -1, "desde": 0.0}


## Centro de un botón en pantalla. Los de abajo se miden desde la esquina inferior derecha;
## la pausa (offset.y == 0) desde la superior derecha.
func _centro(b: Dictionary) -> Vector2:
	var t := _lienzo.size
	var o: Vector2 = b["offset"]
	if o.y == 0.0:
		return Vector2(t.x + o.x, 62.0)
	return t + o


# ---------------------------------------------------------------- Entrada

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_tocar(e.index, e.position)
		else:
			_soltar(e.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_toque:
			_joy_pos = d.position
			_aplicar_joystick()
		elif d.index == _cam_toque and _jugador:
			_jugador.camara.call("girar_tactil", d.relative)
		get_viewport().set_input_as_handled()


func _tocar(indice: int, pos: Vector2) -> void:
	# 1) ¿Cayó en un botón? (el área de toque es un poco más grande que el dibujo)
	for b in _botones:
		if int(b["toque"]) == -1 and pos.distance_to(_centro(b)) <= float(b["radio"]) * 1.25:
			_apretar_boton(b, indice)
			return
	# 2) Mitad izquierda: joystick flotante
	if _joy_toque == -1 and pos.x < _lienzo.size.x * ZONA_JOY:
		_joy_toque = indice
		var m := RADIO_JOY + 12.0
		_joy_base = Vector2(maxf(pos.x, m), clampf(pos.y, m, _lienzo.size.y - m))
		_joy_pos = pos
		_aplicar_joystick()
		return
	# 3) El resto: mover la cámara
	if _cam_toque == -1:
		_cam_toque = indice


func _soltar(indice: int) -> void:
	if indice == _joy_toque:
		_joy_toque = -1
		_aplicar_joystick()
		return
	if indice == _cam_toque:
		_cam_toque = -1
		return
	for b in _botones:
		if int(b["toque"]) == indice:
			_soltar_boton(b)
			return


func _apretar_boton(b: Dictionary, indice: int) -> void:
	if b["id"] == "pausa":
		AudioManager.reproducir("picoteo")
		_soltar_todo()
		if pausa and pausa.has_method("pausar"):
			pausa.call("pausar")
		return
	b["toque"] = indice
	b["desde"] = Time.get_ticks_msec() / 1000.0
	Input.action_press(b["accion"])


func _soltar_boton(b: Dictionary) -> void:
	b["toque"] = -1
	var accion: StringName = b["accion"]
	var dura := Time.get_ticks_msec() / 1000.0 - float(b["desde"])
	if dura < TOQUE_MINIMO:
		# Toque muy corto: que la física llegue a verlo antes de soltar
		get_tree().create_timer(TOQUE_MINIMO - dura).timeout.connect(func() -> void:
			if int(b["toque"]) == -1:
				Input.action_release(accion))
	else:
		Input.action_release(accion)


## Pasa la posición del joystick a las cuatro acciones de movimiento (con su intensidad).
func _aplicar_joystick() -> void:
	var v := Vector2.ZERO
	if _joy_toque != -1:
		v = ((_joy_pos - _joy_base) / RADIO_JOY).limit_length(1.0)
		if v.length() < ZONA_MUERTA:
			v = Vector2.ZERO
	_fijar(&"mover_derecha", maxf(v.x, 0.0))
	_fijar(&"mover_izquierda", maxf(-v.x, 0.0))
	_fijar(&"mover_atras", maxf(v.y, 0.0))
	_fijar(&"mover_adelante", maxf(-v.y, 0.0))


func _fijar(accion: StringName, fuerza: float) -> void:
	if fuerza > 0.0:
		Input.action_press(accion, fuerza)
	elif Input.is_action_pressed(accion):
		Input.action_release(accion)


## Suelta todo (al pausar, al perder el foco o al ganar), así nada queda "apretado".
func _soltar_todo() -> void:
	_joy_toque = -1
	_cam_toque = -1
	_aplicar_joystick()
	for b in _botones:
		if int(b["toque"]) != -1 or (b["accion"] != &"" and Input.is_action_pressed(b["accion"])):
			b["toque"] = -1
			Input.action_release(b["accion"])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_EXIT_TREE:
			if _lienzo:
				_soltar_todo()


# ---------------------------------------------------------------- Dibujo

func _process(_delta: float) -> void:
	# Sólo se ven jugando: no con el menú principal ni mientras la cámara vuela hasta la paloma
	var activos := not _fin and not GameState.menu_activo and _jugador != null and _jugador.controlable
	if visible != activos:
		visible = activos
		if not activos:
			_soltar_todo()
	if visible:
		_lienzo.queue_redraw()


func _dibujar() -> void:
	# Joystick: si no lo estás tocando, uno tenue en su lugar de siempre para que se sepa dónde va
	var base := _joy_base
	var perilla := _joy_pos
	var alfa := 1.0
	if _joy_toque == -1:
		base = Vector2(RADIO_JOY + 70.0, _lienzo.size.y - RADIO_JOY - 60.0)
		perilla = base
		alfa = 0.45
	else:
		perilla = base + (_joy_pos - base).limit_length(RADIO_JOY)
	_lienzo.draw_circle(base, RADIO_JOY, Color(0.1, 0.1, 0.16, 0.28 * alfa))
	_lienzo.draw_arc(base, RADIO_JOY, 0.0, TAU, 48, Color(1, 1, 1, 0.5 * alfa), 4.0, true)
	_lienzo.draw_circle(perilla, RADIO_PERILLA, Color(1, 1, 1, 0.42 * alfa))
	_lienzo.draw_arc(perilla, RADIO_PERILLA, 0.0, TAU, 32, Color(1, 1, 1, 0.8 * alfa), 3.0, true)

	var en_aire := _jugador != null and _jugador.estado == PalomaJugador.Estado.AIRE
	for b in _botones:
		var c := _centro(b)
		var r: float = b["radio"]
		var col: Color = b["color"]
		var apretado := int(b["toque"]) != -1
		var texto: String = b["texto"]
		var a := 1.0
		match b["id"]:
			"volar":
				texto = "ALETEAR" if en_aire else "DESPEGAR"
			"picada":
				a = 1.0 if en_aire else 0.4   # en el piso no hace nada
		if apretado:
			r *= 0.93
		_lienzo.draw_circle(c, r, Color(col.r, col.g, col.b, (0.55 if apretado else 0.24) * a))
		_lienzo.draw_arc(c, r, 0.0, TAU, 40, Color(C_BORDE.r, C_BORDE.g, C_BORDE.b, C_BORDE.a * a), 4.0, true)
		var tam := 34 if b["id"] == "pausa" else (29 if r > 80.0 else 24)
		var ancho := _fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var p := c + Vector2(-ancho / 2.0, tam * 0.36)
		_lienzo.draw_string_outline(_fuente, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 6,
			Color(C_SOMBRA.r, C_SOMBRA.g, C_SOMBRA.b, C_SOMBRA.a * a))
		_lienzo.draw_string(_fuente, p, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam,
			Color(C_TEXTO.r, C_TEXTO.g, C_TEXTO.b, a))
