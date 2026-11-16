class_name ModoFoto
extends CanvasLayer
## Modo cámara (tecla C): la paloma queda quieta, el HUD se va y una cámara libre te deja encuadrar
## donde quieras (mouse para mirar, WASD para moverte, Espacio y Shift para subir y bajar, rueda
## para el zoom). Click o Enter sacan la foto: un destello y se guarda un PNG en user://fotos.
## C o Esc vuelven al juego. H esconde la ayuda. Mientras dura nadie te atrapa. Lo crea main.gd.

const CARPETA := "user://fotos"
const VELOCIDAD := 6.0
const VELOCIDAD_RAPIDA := 16.0     ## Con Ctrl
const DISTANCIA_MAX := 45.0        ## Hasta dónde se puede alejar la cámara de la paloma
const FOV_MIN := 20.0
const FOV_MAX := 100.0

var activo := false

var _cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _jugador: PalomaJugador
var _hud: CanvasLayer
var _hud_visible := false
var _controlable_previo := true
var _capturando := false
var _ayuda: PanelContainer
var _destello: ColorRect
var _aviso: PanelContainer
var _aviso_texto: Label
var _tween_aviso: Tween
var _ayuda_oculta := false


func _ready() -> void:
	layer = 15
	_cam = Camera3D.new()
	_cam.name = "CamaraFoto"
	add_child(_cam)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = EstiloUI.TEMA
	add_child(raiz)

	# La ayuda de controles, abajo
	_ayuda = PanelContainer.new()
	_ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
	_ayuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ayuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := EstiloUI.caja(EstiloUI.C_OSCURO, 0.25, EstiloUI.C_CYAN_BORDE)
	estilo.content_margin_top = 2
	estilo.content_margin_bottom = 2
	estilo.shadow_size = 5
	_ayuda.add_theme_stylebox_override("panel", estilo)
	raiz.add_child(_ayuda)
	var t := EstiloUI.texto(_ayuda, &"Etiqueta", 13,
		tr("WASD MOVER  ·  ESPACIO / SHIFT SUBIR Y BAJAR  ·  CTRL RÁPIDO  ·  RUEDA ZOOM  ·  CLICK FOTO  ·  H AYUDA  ·  C SALIR"))
	t.add_theme_color_override("font_color", Color.WHITE)

	# Aviso arriba al centro ("FOTO GUARDADA")
	_aviso = PanelContainer.new()
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 40)
	_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.C_OSCURO, 0.25, EstiloUI.C_CYAN_BORDE))
	raiz.add_child(_aviso)
	_aviso_texto = EstiloUI.texto(_aviso, &"Etiqueta", 16)
	_aviso_texto.add_theme_color_override("font_color", Color.WHITE)
	_aviso.modulate.a = 0.0

	# El destello blanco al sacar la foto
	_destello = ColorRect.new()
	_destello.color = Color(1, 1, 1, 0)
	_destello.set_anchors_preset(Control.PRESET_FULL_RECT)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_destello)
	_mostrar_interfaz(false)


func _puede_entrar() -> bool:
	var j := GameState.jugador
	return j != null and not Ajustes.movil and GameState.en_partida and not GameState.menu_activo \
		and not GameState.partida_terminada and not get_tree().paused and not Dialogos.activo \
		and not Emotes.abierta and j.controlable and not j.descansando


func _input(event: InputEvent) -> void:
	if not activo:
		if event.is_action_pressed("foto") and not event.is_echo() and _puede_entrar():
			entrar()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("foto") or event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel"):
		if not event.is_echo():
			salir()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var sens := 0.0028 * Ajustes.sensibilidad * (_cam.fov / 70.0)
		_yaw -= m.relative.x * sens
		_pitch = clampf(_pitch - m.relative.y * sens * (-1.0 if Ajustes.invertir_y else 1.0), -1.5, 1.5)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov - 4.0, FOV_MIN, FOV_MAX)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov + 4.0, FOV_MIN, FOV_MAX)
		elif b.button_index == MOUSE_BUTTON_LEFT:
			sacar_foto()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		sacar_foto()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).keycode == KEY_H:
		_ayuda_oculta = not _ayuda_oculta
		_ayuda.visible = not _ayuda_oculta
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not activo:
		return
	if _jugador == null or not is_instance_valid(_jugador):
		salir()
		return
	GameState.invulnerable = maxf(GameState.invulnerable, 2.0)   # Nadie te atrapa mientras posás
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var vertical := (1.0 if Input.is_action_pressed("volar") else 0.0) - (1.0 if Input.is_action_pressed("picada") else 0.0)
	var rapidez := VELOCIDAD_RAPIDA if Input.is_key_pressed(KEY_CTRL) else VELOCIDAD
	var mov := _cam.global_transform.basis * Vector3(entrada.x, 0.0, entrada.y) + Vector3.UP * vertical
	var pos := _cam.global_position + mov.limit_length(1.0) * rapidez * delta
	# No se aleja demasiado de la paloma ni se mete bajo el piso
	var desde := _jugador.global_position + Vector3.UP * 0.5
	pos = desde + (pos - desde).limit_length(DISTANCIA_MAX)
	pos.y = maxf(pos.y, 0.25)
	_cam.global_position = pos


# ---------------------------------------------------------------- Entrar y salir

func entrar() -> void:
	_jugador = GameState.jugador
	if _jugador == null:
		return
	activo = true
	_controlable_previo = _jugador.controlable
	_jugador.controlable = false
	_jugador.camara.bloqueada = true
	var actual := get_viewport().get_camera_3d()
	if actual:
		_cam.global_transform = actual.global_transform
		_cam.fov = actual.fov
	var e := _cam.global_transform.basis.get_euler(EULER_ORDER_YXZ)
	_pitch = e.x
	_yaw = e.y
	_cam.make_current()
	_hud = get_parent().get_node_or_null("HUD") as CanvasLayer
	_hud_visible = _hud != null and _hud.visible
	if _hud:
		_hud.visible = false
	AvisoAccion.esconder(true)
	_ayuda_oculta = false
	_mostrar_interfaz(true)
	Ajustes.capturar_mouse(true)
	AudioManager.ui("menu_open", -8.0)


func salir() -> void:
	if not activo:
		return
	activo = false
	_jugador.controlable = _controlable_previo
	_jugador.camara.bloqueada = false
	_jugador.camara.camara.make_current()
	if _hud:
		_hud.visible = _hud_visible
	AvisoAccion.esconder(false)
	_mostrar_interfaz(false)
	AudioManager.ui("menu_close", -8.0)


func _mostrar_interfaz(si: bool) -> void:
	_ayuda.visible = si and not _ayuda_oculta
	_aviso.visible = si
	_destello.visible = si


# ---------------------------------------------------------------- La foto

## Esconde la ayuda, guarda lo que se ve en un PNG y avisa. Devuelve la ruta (vacía si falló).
func sacar_foto() -> String:
	if _capturando:
		return ""
	_capturando = true
	_ayuda.visible = false
	_aviso.modulate.a = 0.0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_ayuda.visible = not _ayuda_oculta
	var ruta := ""
	if img != null:
		DirAccess.make_dir_recursive_absolute(CARPETA)
		var f := Time.get_datetime_dict_from_system()
		ruta = "%s/foto_%04d%02d%02d_%02d%02d%02d.png" % [CARPETA, f["year"], f["month"], f["day"],
			f["hour"], f["minute"], f["second"]]
		if img.save_png(ruta) != OK:
			ruta = ""
	_destello.color.a = 0.85
	create_tween().tween_property(_destello, "color:a", 0.0, 0.35)
	if ruta != "":
		AudioManager.ui("unlock", -8.0)
		Logros.sumar("fotos")
		_avisar(tr("FOTO GUARDADA") + "  ·  " + ruta.get_file())
	else:
		_avisar(tr("NO SE PUDO GUARDAR LA FOTO"))
	_capturando = false
	return ruta


func _avisar(texto: String) -> void:
	_aviso_texto.text = texto
	if _tween_aviso and _tween_aviso.is_valid():
		_tween_aviso.kill()
	_aviso.modulate.a = 1.0
	_tween_aviso = create_tween()
	_tween_aviso.tween_interval(2.2)
	_tween_aviso.tween_property(_aviso, "modulate:a", 0.0, 0.5)
