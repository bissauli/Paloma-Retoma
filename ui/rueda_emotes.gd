extends CanvasLayer
## Rueda de bailes (autoload "Emotes"), como la de emotes de Fortnite. V la abre, el mouse (o el
## stick) marca un baile, click o Enter lo elige (también se elige soltando V si se la mantuvo
## apretada) y Esc o V de nuevo la cierran. La paloma baila el mismo baile de los créditos
## (world/coreografia.gd) hasta que se mueva, vuele o picotee. Cada casillero muestra una
## miniatura de la paloma de la jugadora en plena pose, sacada con la Bailarina de los créditos
## la primera vez que se abre. Sólo se abre con la paloma en el piso y sin conversación.

const R_FUERA := 270.0
const R_DENTRO := 125.0
const HUECO := 0.035            ## Radianes que se achica cada casillero para dejar la separación
const TIEMPO_SOLTAR := 0.3      ## Mantener V más que esto y soltarla elige el baile marcado
const LADO_MINIATURA := 384
const RECORTE := Rect2(96.0, 96.0, 192.0, 192.0)    ## La parte de la miniatura donde está la paloma
const INSTANTE := 0.45          ## En qué momento (fracción de la duración) se saca la miniatura

var abierta := false
var _bailes: Array[StringName] = []
var _miniaturas: Array[Texture2D] = []
var _generando := false
var _marcado := -1
var _t_abierta := 0.0
var _mouse_previo := Vector2.ZERO
var _raiz: Control
var _dibujo: Control
var _titulo: Label
var _nombre: Label
var _ayuda: Label
var _tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_bailes = Coreografia.ORDEN.duplicate()
	_bailes.append(Coreografia.FINAL)
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = EstiloUI.TEMA
	_raiz.visible = false
	add_child(_raiz)
	_dibujo = Control.new()
	_dibujo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dibujo.draw.connect(_dibujar)
	_raiz.add_child(_dibujo)
	_titulo = _etiqueta(&"TituloPantalla", 44, "BAILES", -R_FUERA - 62.0)
	_nombre = _etiqueta(&"TituloPantalla", 40, "", R_FUERA + 12.0)
	_ayuda = _etiqueta(&"TextoChico", 14, "CLICK O ENTER PARA ELEGIR  ·  V PARA CERRAR", R_FUERA + 62.0)


## Una etiqueta centrada, "dy" píxeles más abajo (o arriba, si es negativo) del centro de la pantalla.
func _etiqueta(variacion: StringName, tam: int, texto: String, dy: float) -> Label:
	var l := EstiloUI.texto(_raiz, variacion, tam, texto)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(700, 0)
	l.offset_left = -350.0
	l.offset_right = 350.0
	l.offset_top = dy
	l.offset_bottom = dy + tam + 14.0
	return l


# ---------------------------------------------------------------- Abrir y cerrar

func puede_abrir() -> bool:
	return not Dialogos.activo and Dialogos.puede_hablar()


func abrir() -> void:
	if abierta or not puede_abrir():
		return
	abierta = true
	_marcado = -1
	_t_abierta = 0.0
	_mouse_previo = get_viewport().get_mouse_position()
	GameState.jugador.controlable = false
	Ajustes.capturar_mouse(false)
	_actualizar_textos()
	_raiz.visible = true
	_raiz.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	_raiz.modulate.a = 0.0
	_raiz.scale = Vector2.ONE * 0.88
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_raiz, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_raiz, "scale", Vector2.ONE, 0.22)
	AudioManager.reproducir("picoteo", -16.0)
	_dibujo.queue_redraw()
	if _miniaturas.is_empty() and not _generando:
		_generar_miniaturas()


## Cierra la rueda. Con un baile elegido (índice) la paloma lo baila.
func cerrar(elegido := -1) -> void:
	if not abierta:
		return
	abierta = false
	_raiz.visible = false
	if GameState.jugador != null:
		GameState.jugador.controlable = true
	Ajustes.capturar_mouse(true)
	if elegido >= 0 and elegido < _bailes.size() and GameState.jugador != null:
		AudioManager.reproducir("picoteo", -12.0)
		# El click que eligió no debe contar como picotazo (que corta el baile)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if GameState.jugador != null and not abierta:
			GameState.jugador.bailar(_bailes[elegido])


func _process(delta: float) -> void:
	if not abierta:
		return
	GameState.invulnerable = maxf(GameState.invulnerable, 0.5)    # Nadie atrapa a quien está eligiendo
	if GameState.partida_terminada or GameState.menu_activo:
		cerrar()
		return
	_t_abierta += delta
	var nuevo := _marcado
	var mouse := get_viewport().get_mouse_position()
	var palanca := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	if mouse != _mouse_previo:
		_mouse_previo = mouse
		nuevo = _casillero(mouse - get_viewport().get_visible_rect().size * 0.5)
	elif palanca.length() > 0.5:
		nuevo = _casillero(palanca * 100.0)
	if nuevo != _marcado:
		_marcado = nuevo
		_actualizar_textos()
		_dibujo.queue_redraw()
		if nuevo >= 0:
			AudioManager.reproducir("picoteo", -24.0)


func _input(event: InputEvent) -> void:
	if not abierta:
		if event.is_action_pressed("emotes") and not event.is_echo() and puede_abrir():
			abrir()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel"):
		cerrar()
	elif event.is_action_pressed("emotes"):
		if not event.is_echo():
			cerrar()
	elif event.is_action_released("emotes"):
		if _t_abierta > TIEMPO_SOLTAR:
			cerrar(_marcado)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _casillero(event.position - get_viewport().get_visible_rect().size * 0.5)
		if i >= 0:
			cerrar(i)
		else:
			return
	elif event.is_action_pressed("ui_accept"):
		if _marcado >= 0:
			cerrar(_marcado)
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


## A qué casillero apunta un vector desde el centro de la rueda (-1 = al medio, no apunta a ninguno).
func _casillero(desde_centro: Vector2) -> int:
	if desde_centro.length() < 40.0:
		return -1
	var paso := TAU / _bailes.size()
	var angulo := fposmod(desde_centro.angle() + PI * 0.5 + paso * 0.5, TAU)
	return int(angulo / paso) % _bailes.size()


func _actualizar_textos() -> void:
	_nombre.text = tr(Coreografia.nombre(_bailes[_marcado])).to_upper() if _marcado >= 0 else ""


# ---------------------------------------------------------------- Dibujo

func _dibujar() -> void:
	var tam := _dibujo.size
	var c := tam * 0.5
	_dibujo.draw_rect(Rect2(Vector2.ZERO, tam), Color(0.0, 0.03, 0.06, 0.45))
	var paso := TAU / _bailes.size()
	for i in _bailes.size():
		var medio := -PI * 0.5 + i * paso
		var activo := i == _marcado
		var relleno := Color(0.07, 0.62, 0.8, 0.96) if activo else Color(0.09, 0.11, 0.14, 0.86)
		_dibujo.draw_colored_polygon(_sector(c, medio - paso * 0.5 + HUECO, medio + paso * 0.5 - HUECO, R_DENTRO, R_FUERA), relleno)
		var centro_icono := c + Vector2.from_angle(medio) * (R_DENTRO + R_FUERA) * 0.5
		var lado := 124.0 if activo else 110.0
		var rect := Rect2(centro_icono - Vector2.ONE * lado * 0.5, Vector2.ONE * lado)
		if i < _miniaturas.size() and _miniaturas[i] != null:
			_dibujo.draw_texture_rect_region(_miniaturas[i], rect, RECORTE, Color.WHITE if activo else Color(1, 1, 1, 0.82))
		else:
			_dibujo.draw_string(ThemeDB.fallback_font, centro_icono + Vector2(-8, 10), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(1, 1, 1, 0.4))
	_dibujo.draw_arc(c, R_FUERA + 4.0, 0.0, TAU, 96, EstiloUI.C_CYAN_BORDE, 2.0, true)
	_dibujo.draw_circle(c, R_DENTRO - 8.0, Color(0.0, 0.03, 0.06, 0.62))
	_dibujo.draw_arc(c, R_DENTRO - 8.0, 0.0, TAU, 72, EstiloUI.C_CYAN_BORDE, 2.0, true)
	if _marcado >= 0 and _marcado < _miniaturas.size() and _miniaturas[_marcado] != null:
		var g := (R_DENTRO - 14.0) * 2.0
		_dibujo.draw_texture_rect_region(_miniaturas[_marcado], Rect2(c - Vector2.ONE * g * 0.5, Vector2.ONE * g), RECORTE)


## Un casillero de anillo como polígono (de un ángulo a otro, entre dos radios).
func _sector(c: Vector2, desde: float, hasta: float, r_dentro: float, r_fuera: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	var pasos := 10
	for k in pasos + 1:
		puntos.append(c + Vector2.from_angle(lerpf(desde, hasta, float(k) / pasos)) * r_fuera)
	for k in pasos + 1:
		puntos.append(c + Vector2.from_angle(lerpf(hasta, desde, float(k) / pasos)) * r_dentro)
	return puntos


# ---------------------------------------------------------------- Miniaturas

## Saca una foto de la paloma de la jugadora en cada baile, con la Bailarina de los créditos puesta
## en un viewport aparte (no se ve). Tarda unos cuadros; mientras tanto los casilleros muestran el número.
func _generar_miniaturas() -> void:
	if DisplayServer.get_name() == "headless":
		return      # Sin pantalla no hay nada que fotografiar
	_generando = true
	var vp := SubViewport.new()
	vp.size = Vector2i(LADO_MINIATURA, LADO_MINIATURA)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var b := Bailarina.new()
	b.size = Vector2(LADO_MINIATURA, LADO_MINIATURA)
	vp.add_child(b)
	await get_tree().process_frame
	var fotos: Array[Texture2D] = []
	for baile in _bailes:
		b.ver("", "Original", baile, Coreografia.duracion(baile) * INSTANTE)
		for k in 4:
			await get_tree().process_frame
		var foto := b.imagen()    # Sin pantalla real (headless) no hay imagen: queda el número
		fotos.append(ImageTexture.create_from_image(foto) if foto != null and not foto.is_empty() else null)
		_miniaturas = fotos
		if abierta:
			_dibujo.queue_redraw()
	vp.queue_free()
	_generando = false
