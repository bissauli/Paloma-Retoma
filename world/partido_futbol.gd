class_name PartidoFutbol
extends Node3D
## Fútbol 5 contra 5 en la cancha de los BadJokes (el potrero, al este del barrio). La pelota espera en el
## centro: con 4 palomas o más en la bandada aparece "E · JUGAR FÚTBOL". La jugadora y 4 de su bandada
## juegan contra 5 palomas que llegan volando (camiseta roja; la nuestra, celeste). Las demás de la bandada y
## las palomas de la banda (patrullas y guardias) hacen de hinchada en los costados de la cancha.
## Controles de la jugadora:
## - Caminar contra la pelota: toques de conducción. SHIFT: correr (gasta AGUANTE).
## - CLICK: pase asistido a la compañera mejor ubicada (aro dorado que se achica: apretar con el aro chico =
##   PASE PERFECTO, más rápido y la compañera sale disparada). F (mantener y soltar): tiro con potencia; soltar
##   dentro de la franja verde de la barra = TIRO PERFECTO (el arquero se confunde); pasarse lo desvía.
##   F (tocar): ALETAZO-BARRIDA, aturde a las rivales de adelante y le saca la pelota al rival.
## - En el aire (SPACE vuela): CLICK = cabezazo con el pico, F = volea o, con la pelota arriba, CHILENA.
## - Q: deja una "sorpresa" en la cancha; la rival que la pisa se resbala. CLICK DERECHO con la barra de
##   ARRULLO llena: arrullo de equipo (tus compañeras corren más y el arquero rival se distrae).
## - E: abandona el partido (o alejarse mucho de la cancha). Nadie atrapa a la jugadora mientras juega.
## Las compañeras y las rivales juegan solas con posesión: la más cercana presiona, las demás se desmarcan al
## atacar o marcan al defender; con la pelota tiran al palo contrario del arquero, pasan si las presionan o
## conducen; sin ella intentan quitarla. El arquero calcula por dónde entra el tiro pero se equivoca.
## Gana el primero a 3 goles o el que va arriba a los 4 minutos; si hay empate, tanda de PENALES. Un relator
## (subtítulos) comenta, silba el árbitro y cada gol tiene su REPETICIÓN lenta.
## Lo crea Ciudad (world/ciudad.gd) en el potrero. Las paredes invisibles de la cancha están en la capa 7
## (64): sólo las ve la pelota, así que la paloma puede volar por arriba sin chocar.

enum Estado { INACTIVO, SAQUE, JUGANDO, GOL, PENALES, FIN }

const SUELO := Ciudad.Y_VEREDA + 0.02
const CENTRO := Vector3(137.0, SUELO, 68.0)
const X_MIN := 118.0
const X_MAX := 156.0
const Z_MIN := 57.0
const Z_MAX := 79.0
const ARCO_MEDIO := 2.6           ## Medio ancho del arco (el modelo mide 5,2 m)
const ALTO_ARCO := 2.0
const RADIO_BALON := 0.28
const CAPA_PAREDES := 64
const GOLES_META := 3
const DURACION := 240.0
const COMPANIEROS := 4            ## Palomas de la bandada que hacen falta para jugar
const VEL_JUGADORA := 4.4         ## Corre más rápido mientras juega (si no, no llega a ninguna pelota)
const MULT_SPRINT := 1.5
const ZONA_PERFECTA := Vector2(0.74, 0.9)   ## Franja de la barra de potencia donde el tiro es perfecto
const PEN_DIST := 8.0             ## Distancia del punto penal al arco
const GRAB_MAX := 150             ## Cuadros que se graban para la repetición (2,5 s)
const VEL_REPETICION := 0.5

const HOMES_A := [Vector3(121.5, SUELO, 68.0), Vector3(127.5, SUELO, 62.0), Vector3(127.5, SUELO, 74.0),
	Vector3(132.5, SUELO, 68.0)]
const HOMES_B := [Vector3(152.5, SUELO, 68.0), Vector3(146.5, SUELO, 61.0), Vector3(146.5, SUELO, 75.0),
	Vector3(141.5, SUELO, 64.5), Vector3(141.5, SUELO, 71.5)]
const COLOR_A := Color(0.25, 0.8, 1.0, 0.9)
const COLOR_B := Color(1.0, 0.3, 0.3, 0.9)
const ORO := Color("ffd84a")

var estado: Estado = Estado.INACTIVO
var goles := [0, 0]

var _balon: RigidBody3D
var _equipo: Array[Dictionary] = []     ## {p, eq (0 nuestro, 1 rival), rol, home, cd, vel, idx, stun, boost}
var _hinchas: Array[Dictionary] = []    ## {p (PalomaNPC), pos, llego}
var _banda: Array[Dictionary] = []      ## {p (PalomaBadJoke), pos}
var _jugadora: PalomaJugador
var _t := 0.0
var _tiempo := DURACION
var _t_inicio := 0.0
var _cd_global := 0.0
var _cd_jugadora := 0.0
var _cd_barrida := 0.0
var _cd_sorpresa := 0.0
var _cd_relato := 0.0
var _euforia_t := 0.0
var _euforia_lado := 0
var _pos_eq := -1                       ## Quién tiene la posesión (último que la tocó): 0 nuestro, 1 rival, -1 suelta
var _pos_t := 0.0
var _receptor: PalomaNPC                ## La que va a recibir un pase (corre a buscarlo)
var _receptor_t := 0.0
var _t_juego := 0.0
var _carga := 0.0                       ## Carga del tiro de la jugadora (0 a 1, mantener F)
var _f_t := 0.0                         ## Segundos que lleva apretada F
var _fase_aro := 0.0
var _aro_pase: MeshInstance3D           ## Marca a la compañera a la que iría el pase
var _aguante := 100.0
var _agotada := false
var _arrullo := 0.0                     ## Barra de arrullo de equipo (0 a 1)
var _arrullo_t := 0.0                   ## Segundos que le quedan al arrullo de equipo
var _perfecto_hasta := 0.0              ## Hasta cuándo el arquero rival sigue confundido por un tiro perfecto
var _pase_flag := false                 ## El próximo toque es un pase (para el relator)
var _ultimo_toque: Node3D
var _t_casi := 0.0
var _vel_previa := 0.0                  ## Velocidad de caminar de la jugadora antes del partido
var _sorpresas: Array[Dictionary] = []  ## {pos, t, nodo}
# Penales
var _pen := {}
var _ganador_pen := -1                  ## 0 ganó la bandada, 1 los BadJokes (-1 = no hubo penales)
# Repetición
var _grab: Array = []                   ## [{b, p: PackedVector3Array, r: PackedFloat32Array}]
var _rep_fase := 0                      ## 0 festejo, 1 repetición, 2 volver al saque
var _rep_i := 0.0
# Interfaz
var _hud: CanvasLayer
var _marcador: Label
var _estado_texto: Label
var _relator: Label
var _repeticion_texto: Label
var _barra_fondo: ColorRect
var _barra: ColorRect
var _barra_aguante: ColorRect
var _barra_arrullo: ColorRect
var _t_hud := 0.0
var _tween_relato: Tween


func _ready() -> void:
	add_to_group("partido_futbol")
	_armar_paredes()
	_armar_balon()
	_armar_hud()


# ---------------------------------------------------------------- Armado

## Paredes invisibles que sólo ve la pelota: costados, fondos y el fondo de cada arco.
func _armar_paredes() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "ParedesCancha"
	cuerpo.collision_layer = CAPA_PAREDES
	cuerpo.collision_mask = 0
	add_child(cuerpo)
	var alto := 6.0
	var y := SUELO + alto / 2.0
	_pared(cuerpo, Vector3(CENTRO.x, y, Z_MIN - 0.3), Vector3(X_MAX - X_MIN + 8.0, alto, 0.6))
	_pared(cuerpo, Vector3(CENTRO.x, y, Z_MAX + 0.3), Vector3(X_MAX - X_MIN + 8.0, alto, 0.6))
	var z_norte := (Z_MIN - 0.6 + CENTRO.z - ARCO_MEDIO - 0.1) / 2.0
	var largo_norte := (CENTRO.z - ARCO_MEDIO - 0.1) - (Z_MIN - 0.6)
	var z_sur := (Z_MAX + 0.6 + CENTRO.z + ARCO_MEDIO + 0.1) / 2.0
	for x: float in [X_MIN - 0.3, X_MAX + 0.3]:
		_pared(cuerpo, Vector3(x, y, z_norte), Vector3(0.6, alto, largo_norte))
		_pared(cuerpo, Vector3(x, y, z_sur), Vector3(0.6, alto, largo_norte))
	# El fondo de cada arco (la red): atrás y a los costados
	for lado: float in [-1.0, 1.0]:
		var borde: float = X_MIN if lado < 0.0 else X_MAX
		var fondo: float = borde + lado * 1.5
		_pared(cuerpo, Vector3(fondo, y, CENTRO.z), Vector3(0.4, alto, ARCO_MEDIO * 2.0 + 0.8))
		for s: float in [-1.0, 1.0]:
			_pared(cuerpo, Vector3(borde + lado * 0.75, y, CENTRO.z + s * (ARCO_MEDIO + 0.25)), Vector3(1.6, alto, 0.4))
	# Techo: que la pelota no se vaya por arriba
	_pared(cuerpo, Vector3(CENTRO.x, SUELO + alto + 0.3, CENTRO.z), Vector3(X_MAX - X_MIN + 8.0, 0.6, Z_MAX - Z_MIN + 3.0))


func _pared(cuerpo: StaticBody3D, pos: Vector3, tam: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var f := BoxShape3D.new()
	f.size = tam
	cs.shape = f
	cs.position = pos
	cuerpo.add_child(cs)


func _armar_balon() -> void:
	_balon = RigidBody3D.new()
	_balon.name = "Balon"
	_balon.collision_layer = 16
	_balon.collision_mask = 1 | CAPA_PAREDES
	_balon.mass = 0.45
	_balon.linear_damp = 0.45
	_balon.angular_damp = 0.8
	_balon.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.55
	mat.friction = 0.7
	_balon.physics_material_override = mat
	var cs := CollisionShape3D.new()
	var f := SphereShape3D.new()
	f.radius = RADIO_BALON
	cs.shape = f
	_balon.add_child(cs)
	var esfera := SphereMesh.new()
	esfera.radius = RADIO_BALON
	esfera.height = RADIO_BALON * 2.0
	esfera.radial_segments = 12
	esfera.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = Construir.material(Color("f6f4ee"), 0.6)
	_balon.add_child(mi)
	# Los gajos oscuros
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		Construir.esfera(_balon, d * RADIO_BALON * 0.9, 0.1, Color("2a2a30"), Vector3.ONE, 5)
	add_child(_balon)
	_balon.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	_poner_balon_en_el_centro()


func _poner_balon_en_el_centro() -> void:
	_balon.freeze = true
	_balon.linear_velocity = Vector3.ZERO
	_balon.angular_velocity = Vector3.ZERO
	_balon.global_position = CENTRO + Vector3(0, RADIO_BALON + 0.02, 0)


func _armar_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 9
	add_child(_hud)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = EstiloUI.TEMA
	_hud.add_child(raiz)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 18)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := EstiloUI.caja(EstiloUI.C_OSCURO, 0.2, EstiloUI.C_CYAN_BORDE)
	estilo.content_margin_left = 30
	estilo.content_margin_right = 30
	panel.add_theme_stylebox_override("panel", estilo)
	raiz.add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	_marcador = EstiloUI.texto(col, &"Seccion", 26)
	_marcador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marcador.add_theme_color_override("font_color", Color.WHITE)
	_estado_texto = EstiloUI.texto(col, &"TextoChico", 14)
	_estado_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estado_texto.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	# El relator: subtítulos grandes bajo el marcador
	_relator = Label.new()
	_relator.theme_type_variation = &"TextoTarjeta"
	_relator.add_theme_font_size_override("font_size", 28)
	_relator.add_theme_color_override("font_color", Color.WHITE)
	_relator.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
	_relator.add_theme_constant_override("outline_size", 10)
	_relator.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 108)
	_relator.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_relator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_relator.modulate.a = 0.0
	raiz.add_child(_relator)
	# Cartel de la repetición (arriba a la izquierda, parpadea)
	_repeticion_texto = Label.new()
	_repeticion_texto.theme_type_variation = &"TituloPantalla"
	_repeticion_texto.text = tr("REPETICIÓN")
	_repeticion_texto.add_theme_font_size_override("font_size", 44)
	_repeticion_texto.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_repeticion_texto.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
	_repeticion_texto.add_theme_constant_override("outline_size", 10)
	_repeticion_texto.position = Vector2(46, 24)
	_repeticion_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repeticion_texto.visible = false
	raiz.add_child(_repeticion_texto)
	# Barra de potencia del tiro (abajo al centro, sólo mientras se carga con F) con la franja perfecta
	_barra_fondo = ColorRect.new()
	_barra_fondo.color = Color(0.0, 0.03, 0.06, 0.7)
	_barra_fondo.custom_minimum_size = Vector2(264, 22)
	_barra_fondo.size = Vector2(264, 22)
	_barra_fondo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	_barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fondo.visible = false
	raiz.add_child(_barra_fondo)
	_barra = ColorRect.new()
	_barra.position = Vector2(4, 4)
	_barra.size = Vector2(0, 14)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fondo.add_child(_barra)
	var zona := ColorRect.new()
	zona.color = Color(0.4, 1.0, 0.5, 0.55)
	zona.position = Vector2(4.0 + 256.0 * ZONA_PERFECTA.x, 1)
	zona.size = Vector2(256.0 * (ZONA_PERFECTA.y - ZONA_PERFECTA.x), 20)
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_fondo.add_child(zona)
	# Aguante y arrullo de equipo (abajo a la izquierda)
	var izq := VBoxContainer.new()
	izq.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 26)
	izq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(izq)
	_barra_aguante = _crear_barra(izq, tr("AGUANTE"), Color("ffd84a"))
	_barra_arrullo = _crear_barra(izq, tr("ARRULLO"), Color("ff8fd0"))
	_hud.visible = false


## Una fila "ROTULO [barra]" con la barra llena de a poco (se maneja con el ancho del ColorRect devuelto).
func _crear_barra(padre: Control, rotulo: String, color: Color) -> ColorRect:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 10)
	padre.add_child(fila)
	var t := EstiloUI.texto(fila, &"TextoChico", 14, rotulo)
	t.custom_minimum_size = Vector2(88, 0)
	t.add_theme_color_override("font_color", Color.WHITE)
	var fondo := ColorRect.new()
	fondo.color = Color(0.0, 0.03, 0.06, 0.7)
	fondo.custom_minimum_size = Vector2(170, 18)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(fondo)
	var relleno := ColorRect.new()
	relleno.color = color
	relleno.position = Vector2(3, 3)
	relleno.size = Vector2(0, 12)
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.add_child(relleno)
	return relleno


func _actualizar_hud(texto: String) -> void:
	if estado == Estado.PENALES:
		var g: Array = _pen.get("goles", [0, 0])
		_marcador.text = "%s  %s %d  -  %d  BADJOKES" % [tr("PENALES"), tr("BANDADA"), g[0], g[1]]
		_estado_texto.text = texto
		return
	_marcador.text = "%s  %d  -  %d  BADJOKES" % [tr("BANDADA"), goles[0], goles[1]]
	var seg := int(maxf(_tiempo, 0.0))
	_estado_texto.text = "%s   ·   %d:%02d" % [texto, floori(seg / 60.0), seg % 60]


func _actualizar_barras() -> void:
	_barra_aguante.size.x = 164.0 * clampf(_aguante / 100.0, 0.0, 1.0)
	_barra_aguante.color = Color("ffd84a") if not _agotada else Color("e0603a")
	if _arrullo_t > 0.0:
		_barra_arrullo.size.x = 164.0 * clampf(_arrullo_t / 7.0, 0.0, 1.0)
		_barra_arrullo.color = Color("ffffff")
	else:
		_barra_arrullo.size.x = 164.0 * clampf(_arrullo, 0.0, 1.0)
		_barra_arrullo.color = Color("ff8fd0") if _arrullo < 1.0 else Color("ff5fb8")


# ---------------------------------------------------------------- Relator y efectos

## Subtítulo del relator (si no es importante, no se pisa con otro hasta pasados 1,3 s).
func _relato(texto: String, color := Color.WHITE, importante := false) -> void:
	if not importante and _cd_relato > 0.0:
		return
	_cd_relato = 1.3
	_relator.text = texto
	_relator.add_theme_color_override("font_color", color)
	if _tween_relato and _tween_relato.is_valid():
		_tween_relato.kill()
	_relator.modulate.a = 1.0
	_tween_relato = create_tween()
	_tween_relato.tween_interval(2.0 if importante else 1.6)
	_tween_relato.tween_property(_relator, "modulate:a", 0.0, 0.4)


func _nombre_de(n: Node) -> String:
	if n is PalomaNPC:
		return (n as PalomaNPC).nombre
	if n is PalomaJugador:
		return tr("la capitana")
	return tr("alguien")


## Texto 3D que sube y se desvanece (perfecto, aturdida, splat...).
func _texto_flotante(pos: Vector3, texto: String, color: Color, tam := 64) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tam
	l.modulate = color
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.005
	l.top_level = true
	add_child(l)
	l.global_position = pos + Vector3(0, 1.0, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", pos.y + 2.4, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)


func _sumar_arrullo(x: float) -> void:
	if _arrullo_t > 0.0:
		return
	var antes := _arrullo
	_arrullo = minf(_arrullo + x, 1.0)
	if antes < 1.0 and _arrullo >= 1.0:
		_relato(tr("¡ARRULLO LISTO! (CLICK DERECHO)"), Color("ff8fd0"), true)
		AudioManager.ui("unlock", -8.0)


# ---------------------------------------------------------------- Actualización

func _physics_process(delta: float) -> void:
	_cd_global = maxf(_cd_global - delta, 0.0)
	_cd_jugadora = maxf(_cd_jugadora - delta, 0.0)
	_cd_barrida = maxf(_cd_barrida - delta, 0.0)
	_cd_sorpresa = maxf(_cd_sorpresa - delta, 0.0)
	_cd_relato = maxf(_cd_relato - delta, 0.0)
	_t_casi = maxf(_t_casi - delta, 0.0)
	_euforia_t = maxf(_euforia_t - delta, 0.0)
	match estado:
		Estado.INACTIVO:
			_paso_inactivo()
			return
		Estado.SAQUE:
			_paso_saque(delta)
		Estado.JUGANDO:
			_paso_juego(delta)
		Estado.GOL:
			_paso_gol(delta)
		Estado.PENALES:
			_paso_penales(delta)
		Estado.FIN:
			_paso_fin(delta)
	if estado != Estado.INACTIVO:
		GameState.invulnerable = maxf(GameState.invulnerable, 0.5)   # Nadie la atrapa mientras juega
		_t_inicio += delta
		_animar_hinchada(delta)
		_actualizar_efectos(delta)
		_actualizar_barras()
		if _debe_abandonar():
			_limpiar()


## ¿Puede la jugadora jugar o interactuar ahora?
func _jugadora_libre() -> bool:
	var j := GameState.jugador
	return j != null and GameState.en_partida and not GameState.partida_terminada and not GameState.menu_activo \
		and j.controlable and j.estado == PalomaJugador.Estado.SUELO and not j.descansando \
		and j.montada == null and not j.deslizando


func _paso_inactivo() -> void:
	var cerca := false
	var j := GameState.jugador
	if _jugadora_libre():
		var d := Vector2(j.global_position.x - _balon.global_position.x, j.global_position.z - _balon.global_position.z).length()
		cerca = d <= 2.4 and absf(j.global_position.y - SUELO) < 1.2
	if not cerca:
		AvisoAccion.ocultar(get_tree(), "futbol")
		return
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	var tiene: int = bandada.seguidoras.size() if bandada else 0
	if tiene >= COMPANIEROS:
		AvisoAccion.mostrar(get_tree(), "futbol", "E", "JUGAR FÚTBOL 5 VS 5", 2, iniciar)
		if Input.is_action_just_pressed("interactuar") and Dialogos.cercano == null:
			iniciar()
	else:
		AvisoAccion.mostrar(get_tree(), "futbol", "", tr("FÚTBOL 5 VS 5 · TE FALTAN %d PALOMAS EN LA BANDADA") % (COMPANIEROS - tiene), 1)


func _debe_abandonar() -> bool:
	var j := GameState.jugador
	if j == null or GameState.partida_terminada or GameState.menu_activo:
		return true
	if estado != Estado.FIN and _t_inicio > 0.6 and Input.is_action_just_pressed("interactuar") and Dialogos.cercano == null:
		return true
	return Vector2(j.global_position.x - CENTRO.x, j.global_position.z - CENTRO.z).length() > 34.0


# ---------------------------------------------------------------- Empezar

func iniciar() -> void:
	if estado != Estado.INACTIVO or not _jugadora_libre():
		return
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada == null or bandada.seguidoras.size() < COMPANIEROS:
		return
	_jugadora = GameState.jugador
	AvisoAccion.ocultar(get_tree(), "futbol")
	# Las 4 más cercanas a la jugadora juegan; el resto alienta
	var sig: Array[PalomaNPC] = bandada.seguidoras.duplicate()
	var jpos := _jugadora.global_position
	sig.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(jpos) < b.global_position.distance_squared_to(jpos))
	_equipo.clear()
	_hinchas.clear()
	_banda.clear()
	_sorpresas.clear()
	for i in sig.size():
		var p := sig[i]
		p.controlada = true
		if i < COMPANIEROS:
			_vestir(p, COLOR_A, Color("39b4ff"), Color.WHITE)
			_equipo.append({"p": p, "eq": 0, "rol": "arquero" if i == 0 else "campo", "home": HOMES_A[i],
				"cd": 0.0, "vel": 3.1, "idx": i, "stun": 0.0, "boost": 0.0})
	var fans: Array[PalomaNPC] = []
	for i in range(COMPANIEROS, sig.size()):
		fans.append(sig[i])
	# Las rivales llegan volando desde afuera de la cancha
	for i in HOMES_B.size():
		var home: Vector3 = HOMES_B[i]
		var p := bandada._nueva_paloma(Vector3(home.x, SUELO + 4.0, Z_MIN - 6.0)) as PalomaNPC
		p.modo = PalomaNPC.Modo.SIGUIENDO   # Así nada la trata como suelta (no se espanta ni se recluta)
		p.controlada = true
		_vestir(p, COLOR_B, Color("e8453c"), Color("2a2a30"))
		_equipo.append({"p": p, "eq": 1, "rol": "arquero" if i == 0 else "campo", "home": home, "cd": 0.0, "vel": 3.3,
			"idx": i, "stun": 0.0, "boost": 0.0})
	_vestir(_jugadora, COLOR_A, Color("39b4ff"), Color.WHITE)
	_vel_previa = _jugadora.velocidad_caminar
	_jugadora.velocidad_caminar = VEL_JUGADORA
	_jugadora.bloquea_descanso = true      # Q es la "sorpresa" y no sentarse
	_pos_eq = -1
	_receptor = null
	_t_juego = 0.0
	_carga = 0.0
	_f_t = 0.0
	_aguante = 100.0
	_agotada = false
	_arrullo = 0.0
	_arrullo_t = 0.0
	_perfecto_hasta = 0.0
	_ganador_pen = -1
	_grab.clear()
	_rep_fase = 0
	# Hinchada: la bandada al sur de la cancha, la banda de los BadJokes al norte
	var slots_sur := _lugares_hinchada(fans.size(), 1.0)
	for i in fans.size():
		_hinchas.append({"p": fans[i], "pos": slots_sur[i], "llego": false})
	var miembros: Array[Node] = []
	for n in get_tree().get_nodes_in_group("banda_badjokes"):
		var rol := String(n.get_meta("rol", ""))
		if rol == "patrulla" or rol == "guardia":
			miembros.append(n)
	var slots_norte := _lugares_hinchada(miembros.size(), -1.0)
	for i in miembros.size():
		var bj := miembros[i] as PalomaBadJoke
		bj.hinchar(slots_norte[i], CENTRO)
		_banda.append({"p": bj, "pos": slots_norte[i]})
	goles = [0, 0]
	_tiempo = DURACION
	_t = 5.0
	_t_inicio = 0.0
	_poner_balon_en_el_centro()
	estado = Estado.SAQUE
	_hud.visible = true
	AvisoAccion.mostrar(get_tree(), "futbol_ayuda", "", "CLICK PASE · F TIRO · SHIFT CORRER · Q SORPRESA · E SALIR", 1)
	AudioManager.ui("success", -8.0)
	AudioManager.reproducir("silbato", -4.0)
	_actualizar_hud(tr("¡A formar los equipos!"))
	_relato(tr("¡Se viene el clásico del potrero!"), ORO, true)


## Lugares en el costado de la cancha para "n" hinchas: "lado" 1 = sur, -1 = norte. Filas de a poco.
func _lugares_hinchada(n: int, lado: float) -> Array[Vector3]:
	var lugares: Array[Vector3] = []
	var por_fila := 28
	for i in n:
		var fila := floori(i / float(por_fila))
		var k := i % por_fila
		var x := X_MIN + 2.0 + k * (X_MAX - X_MIN - 4.0) / float(por_fila - 1)
		var z := (Z_MAX + 1.4 + fila * 1.1) if lado > 0.0 else (Z_MIN - 1.4 - fila * 1.1)
		lugares.append(Vector3(x, SUELO, z))
	return lugares


## Aro del color del equipo en los pies, camiseta (un chaleco con franja) y vincha.
func _vestir(nodo: Node3D, aro: Color, camiseta: Color, franja: Color) -> void:
	_sacar_aro(nodo)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.34
	cm.bottom_radius = 0.34
	cm.height = 0.02
	cm.radial_segments = 16
	var mi := MeshInstance3D.new()
	mi.name = "AroEquipo"
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = aro
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.03, 0)
	nodo.add_child(mi)
	# La camiseta va en el espacio del GLB de la paloma (mira a +Z, el lomo está en y 0,3, la cola hacia -Z)
	var mp: ModeloPaloma = nodo.get("modelo")
	if mp == null or mp._glb == null:
		return
	var glb: Node3D = mp._glb
	var cam := Node3D.new()
	cam.name = "Camiseta"
	glb.add_child(cam)
	var chaleco := SphereMesh.new()
	chaleco.radius = 0.17
	chaleco.height = 0.34
	chaleco.radial_segments = 10
	chaleco.rings = 5
	var m1 := MeshInstance3D.new()
	m1.mesh = chaleco
	m1.material_override = Construir.material(camiseta, 0.8)
	m1.position = Vector3(0, 0.24, -0.04)
	m1.scale = Vector3(0.95, 0.8, 1.35)
	m1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(m1)
	var banda := BoxMesh.new()
	banda.size = Vector3(0.06, 0.012, 0.36)
	var m2 := MeshInstance3D.new()
	m2.mesh = banda
	m2.material_override = Construir.material(franja, 0.8)
	m2.position = Vector3(0, 0.395, -0.04)
	m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(m2)
	var vincha := BoxMesh.new()
	vincha.size = Vector3(0.19, 0.035, 0.19)
	var m3 := MeshInstance3D.new()
	m3.mesh = vincha
	m3.material_override = Construir.material(camiseta, 0.8)
	m3.position = Vector3(0, 0.5, 0.1)
	m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(m3)


func _sacar_aro(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	var a := nodo.get_node_or_null("AroEquipo")
	if a:
		a.queue_free()
	var mp: Variant = nodo.get("modelo")
	if mp is ModeloPaloma and (mp as ModeloPaloma)._glb != null:
		var c := (mp as ModeloPaloma)._glb.get_node_or_null("Camiseta")
		if c:
			c.queue_free()


# ---------------------------------------------------------------- Fases

func _paso_saque(delta: float) -> void:
	_t -= delta
	_mover_a_sus_lugares(delta)
	_actualizar_hud(tr("Saque en %d") % ceili(maxf(_t, 0.0)))
	if _t <= 0.0:
		_balon.freeze = false
		estado = Estado.JUGANDO
		AudioManager.reproducir("silbato", -6.0)
		_actualizar_hud(tr("¡A jugar!"))
		_relato(tr("¡Rueda la pelota!"), Color.WHITE, true)


func _mover_a_sus_lugares(delta: float) -> void:
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if is_instance_valid(p):
			var home: Vector3 = e["home"]
			var falta := p.ir_controlada(delta, home, 5.0, true)
			if falta < 0.3:
				p.mirar_punto(delta, CENTRO)    # Ya llegó: espera el saque mirando la pelota


## 0 si la pelota entró en el arco este (gol nuestro), 1 si entró en el oeste, -1 si no hay gol.
func _gol_en(b: Vector3) -> int:
	if absf(b.z - CENTRO.z) < ARCO_MEDIO and b.y < SUELO + ALTO_ARCO + 0.1:
		if b.x < X_MIN + 0.2:
			return 1
		if b.x > X_MAX - 0.2:
			return 0
	return -1


func _paso_juego(delta: float) -> void:
	_tiempo -= delta
	var b := _balon.global_position
	_grabar(b)
	var g := _gol_en(b)
	if g >= 0:
		_gol(g)
		return
	_relato_casi(b)
	if b.y < SUELO - 4.0 or b.x < X_MIN - 6.0 or b.x > X_MAX + 6.0 or b.z < Z_MIN - 5.0 or b.z > Z_MAX + 5.0:
		_poner_balon_en_el_centro()
		_balon.freeze = false
	if _tiempo <= 0.0:
		if goles[0] == goles[1]:
			_iniciar_penales()
		else:
			_fin()
		return
	_ia(delta, b)
	_jugar_jugadora(delta, b)
	_t_hud -= delta
	if _t_hud <= 0.0:
		_t_hud = 0.25
		_actualizar_hud(tr("A los %d goles gana") % GOLES_META)


## "¡Casi!" cuando la pelota pasa pegada al palo o se va por arriba del travesaño.
func _relato_casi(b: Vector3) -> void:
	if _t_casi > 0.0:
		return
	var v := _balon.linear_velocity
	if v.length() < 7.0:
		return
	var cerca_linea := b.x < X_MIN + 0.6 or b.x > X_MAX - 0.6
	if not cerca_linea:
		return
	var dz := absf(b.z - CENTRO.z)
	if dz > ARCO_MEDIO and dz < ARCO_MEDIO + 1.4:
		_t_casi = 3.0
		_relato(tr("¡Casiii! ¡Pegó en el palo!"), Color("ffb347"))
	elif dz <= ARCO_MEDIO and b.y > SUELO + ALTO_ARCO + 0.1:
		_t_casi = 3.0
		_relato(tr("¡Por arriba del travesaño!"), Color("ffb347"))


## Graba la posición de la pelota y de todos los jugadores para la repetición del gol.
func _grabar(b: Vector3) -> void:
	var ps := PackedVector3Array()
	var rs := PackedFloat32Array()
	for n in _participantes():
		if n == null:
			ps.append(Vector3.ZERO)
			rs.append(0.0)
			continue
		ps.append(n.global_position)
		var mp: Variant = n.get("modelo")
		rs.append((mp as ModeloPaloma).rotation.y if mp is ModeloPaloma else 0.0)
	_grab.append({"b": b, "p": ps, "r": rs})
	if _grab.size() > GRAB_MAX:
		_grab.pop_front()


## Los que juegan (en el mismo orden siempre): los de los dos equipos y la jugadora.
func _participantes() -> Array[Node3D]:
	var l: Array[Node3D] = []
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		l.append(p if is_instance_valid(p) else null)
	l.append(_jugadora if is_instance_valid(_jugadora) else null)
	return l


func _paso_gol(delta: float) -> void:
	if _rep_fase == 0:
		_t -= delta
		_mover_a_sus_lugares(delta)
		if _t > 0.0:
			return
		if _grab.size() > 40:
			_empezar_repeticion()
		else:
			_rep_fase = 2
	if _rep_fase == 1:
		_paso_repeticion(delta)
		return
	# Terminó el festejo (o la repetición): saque desde el centro o fin del partido
	if goles[0] >= GOLES_META or goles[1] >= GOLES_META:
		_fin()
		return
	_volver_al_saque()


func _volver_al_saque() -> void:
	_poner_balon_en_el_centro()
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if is_instance_valid(p):
			p.global_position = e["home"]
			e["stun"] = 0.0
			_quitar_estrellas(p)
	if is_instance_valid(_jugadora):
		_jugadora.global_position = Vector3(CENTRO.x - 6.0, _jugadora.global_position.y, CENTRO.z)
		_jugadora.velocity = Vector3.ZERO
		_jugadora.reset_physics_interpolation()
	_grab.clear()
	_rep_fase = 0
	estado = Estado.SAQUE
	_t = 2.5
	AudioManager.reproducir("silbato", -6.0)


func _empezar_repeticion() -> void:
	_rep_fase = 1
	_rep_i = 0.0
	_balon.freeze = true
	if is_instance_valid(_jugadora):
		_jugadora.controlable = false
		_jugadora.velocity = Vector3.ZERO
	_repeticion_texto.visible = true
	_relator.modulate.a = 0.0
	_marcar_receptor(null)
	AudioManager.ui("highlight", -4.0)


## Reproduce lo grabado en cámara lenta. CLICK la saltea.
func _paso_repeticion(delta: float) -> void:
	_rep_i += delta * 60.0 * VEL_REPETICION
	_repeticion_texto.modulate.a = 0.55 + 0.45 * sin(_t_inicio * 7.0)
	var i := int(_rep_i)
	var terminada := i >= _grab.size() - 1
	if _rep_i > 40.0 and Input.is_action_just_pressed("picotear"):
		terminada = true
	if not terminada:
		var cuadro: Dictionary = _grab[i]
		_balon.global_position = cuadro["b"]
		var ps: PackedVector3Array = cuadro["p"]
		var rs: PackedFloat32Array = cuadro["r"]
		var nodos := _participantes()
		for k in mini(nodos.size(), ps.size()):
			var n := nodos[k]
			if n == null:
				continue
			n.global_position = ps[k]
			var mp: Variant = n.get("modelo")
			if mp is ModeloPaloma:
				(mp as ModeloPaloma).rotation.y = rs[k]
		return
	_repeticion_texto.visible = false
	if is_instance_valid(_jugadora):
		_jugadora.controlable = true
	_rep_fase = 2


func _gol(quien: int) -> void:
	goles[quien] += 1
	_pos_eq = -1
	_carga = 0.0
	_f_t = 0.0
	estado = Estado.GOL
	_t = 2.8
	_rep_fase = 0
	_euforia_t = 2.8
	_euforia_lado = quien
	for h in _banda:
		var bj := h["p"] as PalomaBadJoke
		if is_instance_valid(bj):
			bj.festejar_gol(quien == 1)
	AudioManager.reproducir("arrullo", -2.0)
	AudioManager.reproducir("silbato", -8.0)
	AudioManager.ui("success" if quien == 0 else "failure", -4.0)
	var autor := _nombre_de(_ultimo_toque)
	if quien == 0:
		Logros.sumar("goles")
		_sumar_arrullo(0.35)
		_relato(tr("¡GOOOL de %s!") % autor, ORO, true)
	else:
		_relato(tr("Gol de los BadJokes: %s") % autor, Color("ff7f7f"), true)
	_actualizar_hud(tr("¡GOOOL!") if quien == 0 else tr("Gol de los BadJokes"))


func _fin() -> void:
	estado = Estado.FIN
	_t = 3.5
	_balon.freeze = true
	var por_penales := _ganador_pen != -1
	var gano: bool = (_ganador_pen == 0) if por_penales else goles[0] > goles[1]
	var empate: bool = not por_penales and goles[0] == goles[1]
	var texto := tr("EMPATE")
	if not empate:
		if por_penales:
			texto = tr("¡GANÓ LA BANDADA EN LOS PENALES!") if gano else tr("¡GANARON LOS BADJOKES EN LOS PENALES!")
		else:
			texto = tr("¡GANÓ LA BANDADA!") if gano else tr("¡GANARON LOS BADJOKES!")
	_actualizar_hud(texto)
	_relato(texto, ORO if gano else Color("ff7f7f"), true)
	AudioManager.reproducir("silbato", -4.0)
	Logros.sumar("partidos")
	if gano:
		Logros.sumar("partidos_ganados")
		GameState.sumar_comida(5)
		AudioManager.ui("unlock", -4.0)
		if por_penales:
			Logros.sumar("penales_ganados")
	for h in _banda:
		var bj := h["p"] as PalomaBadJoke
		if is_instance_valid(bj):
			bj.festejar_gol(not gano)


func _paso_fin(delta: float) -> void:
	_t -= delta
	_mover_a_sus_lugares(delta)
	if _t <= 0.0:
		_limpiar()


## Devuelve todo a como estaba: la bandada vuelve a seguirla, las rivales quedan sueltas en la zona, la
## banda vuelve a su puesto y la pelota espera en el centro.
func _limpiar() -> void:
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if not is_instance_valid(p):
			continue
		_sacar_aro(p)
		_quitar_estrellas(p)
		p.controlada = false
		if int(e["eq"]) == 0:
			p.levantar()
		else:
			p.modo = PalomaNPC.Modo.SUELTA
			p.velocidad = Vector3.ZERO
			p.configurar_zona(p.global_position, 7.0)
	for h in _hinchas:
		var p: PalomaNPC = h["p"]
		if is_instance_valid(p):
			p.controlada = false
			p.levantar()
	for h in _banda:
		var bj := h["p"] as PalomaBadJoke
		if is_instance_valid(bj):
			bj.festejar_gol(false)
			bj.volver_a_puesto()
	if is_instance_valid(_jugadora):
		_sacar_aro(_jugadora)
		if _vel_previa > 0.0:
			_jugadora.velocidad_caminar = _vel_previa
		_jugadora.bloquea_descanso = false
		_jugadora.controlable = true
	_vel_previa = 0.0
	_carga = 0.0
	_f_t = 0.0
	_actualizar_barra()
	_marcar_receptor(null)
	for s in _sorpresas:
		if is_instance_valid(s["nodo"]):
			(s["nodo"] as Node).queue_free()
	_sorpresas.clear()
	_equipo.clear()
	_hinchas.clear()
	_banda.clear()
	_grab.clear()
	_pen = {}
	_rep_fase = 0
	_repeticion_texto.visible = false
	_poner_balon_en_el_centro()
	_hud.visible = false
	AvisoAccion.ocultar(get_tree(), "futbol_ayuda")
	estado = Estado.INACTIVO


# ---------------------------------------------------------------- Efectos: aturdidas, sorpresas, arrullo

func _actualizar_efectos(delta: float) -> void:
	_arrullo_t = maxf(_arrullo_t - delta, 0.0)
	# Sorpresas en el piso: duran un rato y hacen resbalar a las rivales que las pisan
	for i in range(_sorpresas.size() - 1, -1, -1):
		var s: Dictionary = _sorpresas[i]
		s["t"] = float(s["t"]) - delta
		var quitar := float(s["t"]) <= 0.0
		var pos: Vector3 = s["pos"]
		if not quitar:
			for e in _equipo:
				var q: PalomaNPC = e["p"]
				if int(e["eq"]) == 1 and e["rol"] == "campo" and is_instance_valid(q) and float(e["stun"]) <= 0.0 \
						and _dxz(q.global_position, pos) < 0.8:
					_aturdir(e, 2.4, tr("¡SPLAT!"))
					_relato(tr("¡Resbaló %s!") % q.nombre, Color("c6ff8f"))
					AudioManager.reproducir("boing", -4.0)
					_sumar_arrullo(0.12)
					quitar = true
					break
		if quitar:
			if is_instance_valid(s["nodo"]):
				(s["nodo"] as Node).queue_free()
			_sorpresas.remove_at(i)
	# Las aturdidas se recuperan
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if not is_instance_valid(p):
			continue
		e["boost"] = maxf(float(e["boost"]) - delta, 0.0)
		if float(e["stun"]) > 0.0:
			e["stun"] = float(e["stun"]) - delta
			if float(e["stun"]) <= 0.0:
				_quitar_estrellas(p)


func _aturdir(e: Dictionary, segundos: float, texto: String) -> void:
	var p: PalomaNPC = e["p"]
	e["stun"] = segundos
	if p.get_node_or_null("Estrellas") == null:
		var l := Label3D.new()
		l.name = "Estrellas"
		l.text = "✦ ✦ ✦"
		l.font_size = 72
		l.modulate = ORO
		l.outline_size = 12
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.0045
		l.position = Vector3(0, 0.85, 0)
		p.add_child(l)
	_texto_flotante(p.global_position, texto, Color("c6ff8f"), 52)


func _quitar_estrellas(p: Node) -> void:
	var s := p.get_node_or_null("Estrellas")
	if s:
		s.queue_free()


func _poner_sorpresa(j: PalomaJugador) -> void:
	_cd_sorpresa = 8.0
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(j.global_position.x, SUELO + 0.02, j.global_position.z)
	var mancha := CylinderMesh.new()
	mancha.top_radius = 0.42
	mancha.bottom_radius = 0.42
	mancha.height = 0.025
	mancha.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mancha
	mi.material_override = Construir.material(Color("f4f2ea"), 0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var centro := CylinderMesh.new()
	centro.top_radius = 0.13
	centro.bottom_radius = 0.16
	centro.height = 0.05
	centro.radial_segments = 8
	var m2 := MeshInstance3D.new()
	m2.mesh = centro
	m2.material_override = Construir.material(Color("5a5560"), 0.6)
	m2.position = Vector3(0.05, 0.02, 0.03)
	m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(m2)
	_sorpresas.append({"pos": n.global_position, "t": 14.0, "nodo": n})
	if _sorpresas.size() > 3:
		var viejo: Dictionary = _sorpresas.pop_front()
		if is_instance_valid(viejo["nodo"]):
			(viejo["nodo"] as Node).queue_free()
	# Se agacha un momento
	var tw := create_tween()
	tw.tween_property(j.modelo, "scale", Vector3(1.15, 0.7, 1.15), 0.18)
	tw.tween_property(j.modelo, "scale", Vector3.ONE, 0.25)
	AudioManager.reproducir("aplastar", -8.0)
	_relato(tr("¡Dejó una sorpresita en la cancha!"), Color("c6ff8f"))


func _activar_arrullo_equipo() -> void:
	_arrullo = 0.0
	_arrullo_t = 7.0
	_relato(tr("¡ARRULLO DE EQUIPO!"), Color("ff8fd0"), true)
	AudioManager.ui("unlock", -4.0)
	for e in _equipo:
		if int(e["eq"]) == 0:
			var p: PalomaNPC = e["p"]
			if is_instance_valid(p):
				_texto_flotante(p.global_position, "♥", Color("ff8fd0"), 80)


# ---------------------------------------------------------------- Juego

## Distancia en el plano (X, Z) entre dos puntos.
func _dxz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Alguien tocó la pelota: ese equipo tiene la posesión (dura unos segundos si nadie más la toca).
func _registrar_toque(eq: int) -> void:
	_pos_eq = eq
	_pos_t = 0.0


## El jugador de ese equipo que está más cerca de la pelota (quien la tocó).
func _mas_cercano_a_pelota(eq: int) -> Node3D:
	var b := _balon.global_position
	var mejor: Node3D = null
	var mejor_d := INF
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if int(e["eq"]) == eq and is_instance_valid(p):
			var d := _dxz(p.global_position, b)
			if d < mejor_d:
				mejor_d = d
				mejor = p
	if eq == 0 and is_instance_valid(_jugadora) and _dxz(_jugadora.global_position, b) < mejor_d:
		mejor = _jugadora
	return mejor


## Las compañeras y las rivales: arquero que ataja, un presionador por equipo, desmarques al atacar,
## marcas al defender, pases, tiros al palo y quites. Atacar es ir al arco rival; el nuestro es el oeste.
func _ia(delta: float, b: Vector3) -> void:
	var bv := _balon.linear_velocity
	_pos_t += delta
	if _pos_t > 3.0:
		_pos_eq = -1      # Pelota suelta
	_receptor_t = maxf(_receptor_t - delta, 0.0)
	if _receptor_t <= 0.0:
		_receptor = null
	_t_juego += delta
	# Quién va a buscar la pelota en cada equipo (la más cercana de campo, sin las aturdidas; en el nuestro, si
	# la jugadora está más cerca va ella)
	var orden: Array = [[], []]
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if e["rol"] == "campo" and is_instance_valid(p) and float(e["stun"]) <= 0.0:
			orden[int(e["eq"])].append([_dxz(p.global_position, b), e])
	for eq in 2:
		(orden[eq] as Array).sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var persigue: Array = [null, null]
	var apoya: Array = [null, null]
	for eq in 2:
		var l: Array = orden[eq]
		if l.size() > 0:
			persigue[eq] = (l[0] as Array)[1]
		if l.size() > 1:
			apoya[eq] = (l[1] as Array)[1]
	if is_instance_valid(_jugadora) and persigue[0] != null:
		if _dxz(_jugadora.global_position, b) < float((orden[0] as Array)[0][0]):
			persigue[0] = apoya[0] if _pos_eq == 1 else null    # Ella va; si defendemos, una compañera la ayuda
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if not is_instance_valid(p):
			continue
		var eq: int = e["eq"]
		e["cd"] = maxf(float(e["cd"]) - delta, 0.0)
		if e["rol"] == "arquero":
			_ia_arquero(delta, e, b, bv)
			continue
		if float(e["stun"]) > 0.0:
			p.ir_controlada(delta, p.global_position, 0.0)     # Aturdida: se queda mareada en el lugar
			continue
		var dir_ataque := 1.0 if eq == 0 else -1.0
		var propio_x := X_MIN if eq == 0 else X_MAX
		var rival_x := X_MAX if eq == 0 else X_MIN
		var home: Vector3 = e["home"]
		var atacando := _pos_eq == eq
		var obj: Vector3
		var va_a_la_pelota: bool = persigue[eq] == e or _receptor == p
		if va_a_la_pelota:
			obj = Vector3(b.x + bv.x * 0.25, SUELO, b.z + bv.z * 0.25)
		elif atacando:
			# Se desmarca: sube con la jugada, se abre y cambia de lugar de a poco
			var idx: int = int(e.get("idx", 0))
			var ancho := sin(_t_juego * 0.6 + idx * 2.1) * 3.5
			obj = Vector3(home.x + (b.x - CENTRO.x) * 0.55 + dir_ataque * 6.0, SUELO, home.z + ancho)
			# La más atrasada se queda de cobertura
			if idx == 0:
				obj.x = propio_x + dir_ataque * 9.0
		else:
			# Marca al rival que le queda más cerca de su lugar (se pone del lado de su arco)
			var rival_marcado := _rival_a_marcar(eq, home)
			if rival_marcado != Vector3.INF:
				var al_arco := (Vector3(propio_x, SUELO, CENTRO.z) - rival_marcado)
				al_arco.y = 0.0
				obj = rival_marcado + al_arco.normalized() * 1.6
			else:
				obj = home
		obj.x = clampf(obj.x, X_MIN + 0.8, X_MAX - 0.8)
		obj.z = clampf(obj.z, Z_MIN + 0.8, Z_MAX - 0.8)
		var mult := 1.25 if va_a_la_pelota else 1.0
		if eq == 0 and _arrullo_t > 0.0:
			mult *= 1.45
		elif eq == 1 and _arrullo_t > 0.0:
			mult *= 0.8
		if float(e["boost"]) > 0.0:
			mult *= 1.35
		p.ir_controlada(delta, obj, float(e["vel"]) * mult)
		# Con la pelota al alcance: si la tiene el rival, intenta quitársela; si no, juega
		if _dxz(p.global_position, b) < 0.9 and b.y < SUELO + 0.9 and float(e["cd"]) <= 0.0 and _cd_global <= 0.0:
			if _pos_eq != eq and _pos_eq != -1:
				_intentar_quite(e, b, dir_ataque)
			else:
				_accion_con_pelota(e, b, dir_ataque, rival_x)


## Posición del rival (o de la jugadora, si marcamos a su equipo) a marcar según el lugar propio, o INF.
func _rival_a_marcar(eq: int, home: Vector3) -> Vector3:
	var mejor := Vector3.INF
	var mejor_d := INF
	for r in _equipo:
		var q: PalomaNPC = r["p"]
		if int(r["eq"]) == eq or not is_instance_valid(q) or r["rol"] == "arquero":
			continue
		var d := _dxz(q.global_position, home)
		if d < mejor_d:
			mejor_d = d
			mejor = q.global_position
	if eq == 1 and is_instance_valid(_jugadora):
		var dj := _dxz(_jugadora.global_position, home)
		if dj < mejor_d:
			mejor = _jugadora.global_position
	return mejor


## Quita la pelota con cierta probabilidad (las rivales son más aguerridas que las compañeras).
func _intentar_quite(e: Dictionary, b: Vector3, dir_ataque: float) -> void:
	e["cd"] = 0.45
	var prob := 0.5 if int(e["eq"]) == 1 else 0.34
	if randf() > prob:
		return
	var dir := Vector3(dir_ataque, 0.0, randf_range(-0.6, 0.6)).normalized()
	_patear(dir, 5.5, 0.0, int(e["eq"]))
	_cd_global = 0.25
	var p: PalomaNPC = e["p"]
	p.modelo.picotear()
	_relato(tr("¡Se la quitó %s!") % p.nombre, Color.WHITE)


## Tiene la pelota: tira si está cerca del arco y la ve, pasa si la presionan o hay alguien mejor
## ubicado, y si no, la lleva hacia el arco esquivando al rival que tiene cerca.
func _accion_con_pelota(e: Dictionary, b: Vector3, dir_ataque: float, rival_x: float) -> void:
	var eq: int = e["eq"]
	var p: PalomaNPC = e["p"]
	_cd_global = 0.2
	var arco := Vector3(rival_x, SUELO, CENTRO.z)
	var cerca_arco := absf(rival_x - b.x) < 15.0
	# El rival más cercano (para esquivar y saber si la presionan)
	var rival_cerca := Vector3.INF
	var rd := INF
	var pos_arquero_z := CENTRO.z
	for r in _equipo:
		var q: PalomaNPC = r["p"]
		if int(r["eq"]) == eq or not is_instance_valid(q):
			continue
		if r["rol"] == "arquero":
			pos_arquero_z = q.global_position.z
		var d := _dxz(q.global_position, p.global_position)
		if d < rd:
			rd = d
			rival_cerca = q.global_position
	if eq == 1 and is_instance_valid(_jugadora):
		var dj := _dxz(_jugadora.global_position, p.global_position)
		if dj < rd:
			rd = dj
			rival_cerca = _jugadora.global_position
	# Tiro al palo contrario al que se tira el arquero
	if cerca_arco and (rd > 1.3 or absf(rival_x - b.x) < 8.0) and randf() < 0.9:
		var lado := -signf(pos_arquero_z - CENTRO.z)
		if lado == 0.0:
			lado = 1.0 if randf() < 0.5 else -1.0
		var punto := Vector3(rival_x, SUELO, CENTRO.z + lado * (ARCO_MEDIO - randf_range(0.5, 1.0)))
		var dir := (punto - b)
		dir.y = 0.0
		dir = dir.normalized().rotated(Vector3.UP, randf_range(-0.08, 0.08))
		_patear(dir, randf_range(11.5, 15.0), 0.35, eq)
		e["cd"] = 0.8
		p.modelo.picotear()
		return
	# Pase al que esté mejor (adelante y desmarcado)
	if rd < 2.4 or randf() < 0.18:
		var mejor: Node3D = null
		var mejor_valor := -INF
		for m in _companeras(eq, p):
			var mp := m.global_position
			var avance := (mp.x - p.global_position.x) * dir_ataque
			var dist := _dxz(mp, p.global_position)
			if avance < 1.0 or dist < 3.5 or dist > 24.0:
				continue
			var libre := _libertad(mp, eq)
			var valor := avance * 0.6 + libre * 1.2
			if libre > 2.2 and valor > mejor_valor:
				mejor_valor = valor
				mejor = m
		if mejor != null:
			var mv := Vector3.ZERO
			if mejor is PalomaNPC:
				mv = (mejor as PalomaNPC).velocidad
			var objetivo := mejor.global_position + mv * 0.4
			var d := objetivo - b
			d.y = 0.0
			_pase_flag = true
			_patear(d.normalized(), clampf(d.length() * 1.9, 6.0, 14.0), 0.15, eq)
			if mejor is PalomaNPC:
				_receptor = mejor as PalomaNPC
				_receptor_t = 1.6
			e["cd"] = 0.9
			return
	# Conduce hacia el arco, abriéndose del rival que tiene cerca
	var dir_c := arco - b
	dir_c.y = 0.0
	dir_c = dir_c.normalized()
	if rd < 3.0:
		var lado_rival := dir_c.cross(Vector3(rival_cerca.x - b.x, 0.0, rival_cerca.z - b.z)).y
		dir_c = dir_c.rotated(Vector3.UP, -signf(lado_rival) * 0.7)
	_patear(dir_c, 4.8, 0.0, eq)
	e["cd"] = 0.42


## Compañeras de campo de un equipo (sin quien tiene la pelota); en el nuestro, la jugadora también.
func _companeras(eq: int, excepto: Node3D) -> Array[Node3D]:
	var l: Array[Node3D] = []
	for r in _equipo:
		var q: PalomaNPC = r["p"]
		if int(r["eq"]) == eq and is_instance_valid(q) and r["rol"] == "campo" and q != excepto:
			l.append(q)
	if eq == 0 and is_instance_valid(_jugadora):
		l.append(_jugadora)
	return l


## Qué tan libre está un punto del equipo contrario (distancia al rival más cercano).
func _libertad(punto: Vector3, eq: int) -> float:
	var d := INF
	for r in _equipo:
		var q: PalomaNPC = r["p"]
		if int(r["eq"]) != eq and is_instance_valid(q):
			d = minf(d, _dxz(q.global_position, punto))
	if eq == 1 and is_instance_valid(_jugadora):
		d = minf(d, _dxz(_jugadora.global_position, punto))
	return d


## El arquero: se mueve por la línea siguiendo la pelota; si viene un tiro calcula por dónde entra pero se
## equivoca un poco (y no llega a los palos si el tiro es bueno). Despeja lo que le llega.
func _ia_arquero(delta: float, e: Dictionary, b: Vector3, bv: Vector3) -> void:
	var p: PalomaNPC = e["p"]
	var eq: int = e["eq"]
	var distraido := eq == 1 and _arrullo_t > 0.0           # El arrullo de equipo lo distrae
	var confundido := eq == 1 and _t_juego < _perfecto_hasta   # Un tiro perfecto lo confunde
	var hacia := -1.0 if eq == 0 else 1.0           # Hacia dónde queda su arco
	var linea_x := (X_MIN if eq == 0 else X_MAX) - hacia * 1.2
	var amenaza := bv.x * hacia > 4.0 and absf(b.x - linea_x) < 22.0
	var objetivo_z := clampf(CENTRO.z + (b.z - CENTRO.z) * 0.55, CENTRO.z - 1.8, CENTRO.z + 1.8)
	var rapidez := 2.6
	if amenaza:
		if not bool(e.get("err_listo", false)):
			e["err_listo"] = true
			var rango := 1.2
			if distraido:
				rango *= 2.6
			if confundido:
				rango *= 2.4
			e["err"] = randf_range(-rango, rango)
		var t := (linea_x - b.x) / bv.x
		var z_cae := b.z + bv.z * t
		objetivo_z = clampf(z_cae + float(e["err"]), CENTRO.z - ARCO_MEDIO + 0.2, CENTRO.z + ARCO_MEDIO - 0.2)
		rapidez = 4.6
	else:
		e["err_listo"] = false
	if distraido:
		rapidez *= 0.45
	var obj := Vector3(linea_x, SUELO, objetivo_z)
	# Pelota suelta cerca del área: sale a buscarla
	var dist_arco := absf(b.x - (X_MIN if eq == 0 else X_MAX))
	if not amenaza and dist_arco < 5.0 and absf(b.z - CENTRO.z) < 4.0 and _pos_eq != 1 - eq and not distraido:
		obj = Vector3(b.x, SUELO, b.z)
		rapidez = 4.0
	p.ir_controlada(delta, obj, rapidez)
	if _dxz(p.global_position, b) < 1.05 and b.y < SUELO + 1.6 and float(e["cd"]) <= 0.0:
		e["cd"] = 0.7
		var tiro_fuerte := bv.length() > 7.0
		var dir := Vector3(-hacia, 0.0, randf_range(-0.9, 0.9)).normalized()
		_patear(dir, randf_range(8.0, 11.0), 0.5, eq)
		p.modelo.picotear()
		if tiro_fuerte:
			_relato(tr("¡Qué atajada de %s!") % p.nombre, Color("9be8ff"), true)
			AudioManager.ui("highlight", -4.0)


# ---------------------------------------------------------------- La jugadora

## La jugadora: conducción con toques, correr (SHIFT, gasta aguante), pase asistido con timing (CLICK), tiro
## con potencia (mantener F) o barrida (tocar F), juego aéreo (CLICK/F en el aire), sorpresa (Q) y arrullo.
func _jugar_jugadora(delta: float, b: Vector3) -> void:
	var j := _jugadora
	if not is_instance_valid(j) or not j.controlable:
		_carga = 0.0
		_f_t = 0.0
		_actualizar_barra()
		_marcar_receptor(null)
		return
	var mira := Vector3(-sin(j.rumbo()), 0.0, -cos(j.rumbo()))
	var en_juego := estado == Estado.JUGANDO
	if en_juego:
		if Input.is_action_just_pressed("arrullar") and _arrullo >= 1.0 and _arrullo_t <= 0.0:
			_activar_arrullo_equipo()
		if Input.is_action_just_pressed("descansar") and _cd_sorpresa <= 0.0 and j.estado == PalomaJugador.Estado.SUELO:
			_poner_sorpresa(j)
	_actualizar_aguante(j, delta)
	var d := _dxz(j.global_position, b)
	# En el aire: cabezazo (CLICK), volea o chilena (F)
	if j.estado == PalomaJugador.Estado.AIRE:
		_carga = 0.0
		_f_t = 0.0
		_actualizar_barra()
		_marcar_receptor(null)
		_golpe_aereo(j, b, mira, d)
		return
	if estado == Estado.PENALES and (int(_pen.get("turno", 1)) != 0 or String(_pen.get("fase", "")) != "tiro"):
		_carga = 0.0
		_f_t = 0.0
		_actualizar_barra()
		_marcar_receptor(null)
		return
	var cerca := d <= 1.7 and b.y < SUELO + 1.3
	# F: tocar = barrida con el aletazo; mantener = cargar el tiro (se llena en 0,9 s después de 0,2 s)
	if Input.is_action_pressed("aletazo"):
		_f_t += delta
		_carga = clampf((_f_t - 0.2) / 0.9, 0.0, 1.0)
	elif _f_t > 0.0:
		if _f_t <= 0.2:
			if en_juego:
				_barrida(j, mira, b)
		elif cerca and _cd_jugadora <= 0.0:
			_tirar(j, mira)
		_f_t = 0.0
		_carga = 0.0
	_actualizar_barra()
	# La compañera a la que iría el pase (aro dorado que se achica: el pase es perfecto con el aro chico)
	_fase_aro += delta * 3.4
	var escala_aro := 0.6 + 0.4 * (0.5 + 0.5 * cos(_fase_aro))
	var perfecto_ahora := escala_aro < 0.72
	var receptora := _mejor_receptora(j, mira)
	_marcar_receptor(receptora if (cerca and estado != Estado.PENALES) else null, escala_aro, perfecto_ahora)
	if not cerca or _cd_jugadora > 0.0:
		return
	if Input.is_action_just_pressed("picotear"):
		if receptora != null and estado != Estado.PENALES:
			_pasar(j, b, receptora, perfecto_ahora)
		else:
			_patear(mira, 8.5, 0.3, 0)     # Sin nadie a quien pasar (o en los penales): un toque para adelante
		_cd_jugadora = 0.3
		return
	# Conducción: al caminar contra la pelota le da toques cortos, así que se la pueden quitar
	if estado == Estado.PENALES:
		return
	var vel := Vector3(j.velocity.x, 0.0, j.velocity.z)
	if d < 0.8 and vel.length() > 0.8:
		_patear(vel.normalized(), maxf(vel.length() * 1.15, 3.2), 0.0, 0)
		_cd_jugadora = 0.3


## SHIFT corre con aguante: gasta 38 por segundo y se recupera 22 (si se agota, hasta 30 no vuelve a correr).
func _actualizar_aguante(j: PalomaJugador, delta: float) -> void:
	var mueve := Vector2(j.velocity.x, j.velocity.z).length() > 1.0
	var corre := Input.is_action_pressed("picada") and j.estado == PalomaJugador.Estado.SUELO and mueve \
		and _aguante > 0.0 and not _agotada
	if corre:
		_aguante = maxf(_aguante - 38.0 * delta, 0.0)
		if _aguante <= 0.0:
			_agotada = true
	else:
		_aguante = minf(_aguante + 22.0 * delta, 100.0)
		if _agotada and _aguante >= 30.0:
			_agotada = false
	var v := VEL_JUGADORA * (MULT_SPRINT if corre else 1.0)
	if _arrullo_t > 0.0:
		v *= 1.25
	j.velocidad_caminar = v


## Suelta el tiro: la potencia sale de la carga; la franja verde es el tiro perfecto y pasarse lo desvía.
func _tirar(j: PalomaJugador, mira: Vector3) -> void:
	var perfecto := _carga >= ZONA_PERFECTA.x and _carga <= ZONA_PERFECTA.y
	var fuerza := lerpf(8.0, 18.0, _carga)
	var levanta := 0.25 + _carga * 0.75
	var desvio := randf_range(-1.0, 1.0) * (0.03 + maxf(_carga - 0.9, 0.0) * 1.6)   # Pasarse de potencia la desvía
	if perfecto:
		fuerza = minf(fuerza * 1.12, 19.5)
		levanta = 0.2
		desvio = 0.0
		_perfecto_hasta = _t_juego + 1.6
		_texto_flotante(j.global_position, tr("¡TIRO PERFECTO!"), Color("7dff8a"))
		_relato(tr("¡TIRO PERFECTO!"), Color("7dff8a"), true)
		AudioManager.ui("unlock", -4.0)
		_sumar_arrullo(0.12)
		Logros.sumar("tiros_perfectos")
	_patear(mira.rotated(Vector3.UP, desvio), fuerza, levanta, 0)
	_cd_jugadora = 0.4


## Pase asistido a "receptora"; si el aro estaba chico, es perfecto: más rápido y ella sale disparada.
func _pasar(j: PalomaJugador, b: Vector3, receptora: Node3D, perfecto: bool) -> void:
	var mv := Vector3.ZERO
	if receptora is PalomaNPC:
		mv = (receptora as PalomaNPC).velocidad
	var objetivo := receptora.global_position + mv * 0.4
	var dir := objetivo - b
	dir.y = 0.0
	var fuerza := clampf(dir.length() * 1.9, 6.0, 15.0) * (1.25 if perfecto else 1.0)
	_pase_flag = true
	_patear(dir.normalized(), fuerza, 0.15, 0)
	if receptora is PalomaNPC:
		_receptor = receptora as PalomaNPC
		_receptor_t = 1.6
		if perfecto:
			for e in _equipo:
				if e["p"] == receptora:
					e["boost"] = 2.0
	if perfecto:
		_texto_flotante(j.global_position, tr("¡PASE PERFECTO!"), Color("7dff8a"))
		_relato(tr("¡Pase perfecto de la capitana!"), Color("7dff8a"), true)
		AudioManager.ui("unlock", -6.0)
		_sumar_arrullo(0.18)
		Logros.sumar("pases_perfectos")
	else:
		_sumar_arrullo(0.05)


## Barrida con el ala: aturde a las rivales de adelante y, si la pelota es del rival y está cerca, se la saca.
func _barrida(j: PalomaJugador, mira: Vector3, b: Vector3) -> void:
	if _cd_barrida > 0.0:
		return
	_cd_barrida = 0.9
	var acerto := false
	for e in _equipo:
		var q: PalomaNPC = e["p"]
		if int(e["eq"]) != 1 or e["rol"] != "campo" or not is_instance_valid(q) or float(e["stun"]) > 0.0:
			continue
		var a := q.global_position - j.global_position
		a.y = 0.0
		if a.length() < 1.9 and (a.length() < 0.5 or a.normalized().dot(mira) > 0.25):
			_aturdir(e, 2.0, tr("¡ATURDIDA!"))
			acerto = true
	if _dxz(j.global_position, b) < 1.9 and _pos_eq != 0:
		_patear(mira, 7.5, 0.2, 0)
		acerto = true
	if acerto:
		_relato(tr("¡Aletazo-barrida de la capitana!"), Color("ffe08a"), true)
		_sumar_arrullo(0.1)
		Logros.sumar("barridas")


## Juego aéreo: cabezazo con el pico (CLICK), volea (F) y, con la pelota más arriba, chilena (F, con giro).
func _golpe_aereo(j: PalomaJugador, b: Vector3, mira: Vector3, d: float) -> void:
	if _cd_jugadora > 0.0 or d > 1.6 or estado == Estado.PENALES:
		return
	var dy := b.y - j.global_position.y
	if dy < -0.5 or dy > 2.4:
		return
	if Input.is_action_just_pressed("picotear"):
		var baja := dy > 0.55
		_patear(mira, 10.5, -1.3 if baja else 0.45, 0)
		_texto_flotante(j.global_position, tr("¡CABEZAZO!"), Color("ffe08a"), 56)
		_relato(tr("¡Cabezazo!"), Color("ffe08a"))
		_cd_jugadora = 0.4
	elif Input.is_action_just_pressed("aletazo"):
		if dy > 0.6:
			_patear(mira, 19.0, 0.15, 0)
			_chilena(j)
			_texto_flotante(j.global_position, tr("¡CHILENA!"), ORO, 72)
			_relato(tr("¡¡CHILENA DE LA CAPITANA!!"), ORO, true)
			_sumar_arrullo(0.25)
			Logros.sumar("chilenas")
		else:
			_patear(mira, 16.0, 0.4, 0)
			_texto_flotante(j.global_position, tr("¡VOLEA!"), Color("ffe08a"), 56)
			_relato(tr("¡Volea!"), Color("ffe08a"))
			_sumar_arrullo(0.08)
		_cd_jugadora = 0.45


## Un giro completo en el aire (sólo visual: se gira el modelo de la paloma).
func _chilena(j: PalomaJugador) -> void:
	var mp: ModeloPaloma = j.modelo
	if mp._glb == null:
		return
	var g: Node3D = mp._glb
	var tw := create_tween()
	tw.tween_property(g, "rotation:x", TAU, 0.5).from(0.0)
	tw.tween_callback(func() -> void: g.rotation.x = 0.0)


## La compañera de campo que está más en la línea hacia donde mira la jugadora (y desmarcada), o null.
func _mejor_receptora(j: PalomaJugador, mira: Vector3) -> Node3D:
	var mejor: Node3D = null
	var mejor_valor := 0.55    # Ángulo máximo: unos 55°
	for r in _equipo:
		var q: PalomaNPC = r["p"]
		if int(r["eq"]) != 0 or r["rol"] != "campo" or not is_instance_valid(q):
			continue
		var a := q.global_position - j.global_position
		a.y = 0.0
		var dist := a.length()
		if dist < 2.5 or dist > 28.0:
			continue
		var dot := a.normalized().dot(mira)
		var valor := dot - maxf(0.0, 2.0 - _libertad(q.global_position, 0)) * 0.12
		if valor > mejor_valor:
			mejor_valor = valor
			mejor = q
	return mejor


func _marcar_receptor(q: Node3D, escala := 1.0, perfecto := false) -> void:
	if q == null or not is_instance_valid(q):
		if _aro_pase:
			_aro_pase.visible = false
		return
	if _aro_pase == null:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.02
		cm.radial_segments = 20
		_aro_pase = MeshInstance3D.new()
		_aro_pase.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_aro_pase.material_override = mat
		_aro_pase.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aro_pase.top_level = true
		add_child(_aro_pase)
	_aro_pase.visible = true
	_aro_pase.global_position = Vector3(q.global_position.x, SUELO + 0.05, q.global_position.z)
	_aro_pase.scale = Vector3(escala, 1.0, escala)
	(_aro_pase.material_override as StandardMaterial3D).albedo_color = \
		Color(0.4, 1.0, 0.5, 0.9) if perfecto else Color(1.0, 0.85, 0.2, 0.8)


func _actualizar_barra() -> void:
	if _barra_fondo == null:
		return
	_barra_fondo.visible = _carga > 0.01
	if _barra_fondo.visible:
		_barra.size.x = 256.0 * _carga
		var en_zona := _carga >= ZONA_PERFECTA.x and _carga <= ZONA_PERFECTA.y
		_barra.color = Color(0.4, 1.0, 0.5) if en_zona else Color(0.35, 0.9, 0.4).lerp(Color(1.0, 0.3, 0.2), maxf(_carga - 0.6, 0.0) / 0.4)


func _patear(dir: Vector3, fuerza: float, levanta: float, eq: int) -> void:
	if _balon.freeze and estado != Estado.PENALES:
		return
	_balon.freeze = false
	var quien := _mas_cercano_a_pelota(eq)
	_ultimo_toque = quien
	var era_pase := _pase_flag
	_pase_flag = false
	_registrar_toque(eq)
	_balon.linear_velocity = dir * fuerza + Vector3.UP * levanta
	_balon.angular_velocity = Vector3(dir.z, 0.0, -dir.x) * fuerza * 1.2
	AudioManager.reproducir("picoteo", -6.0 if fuerza < 10.0 else -2.0)
	if estado == Estado.PENALES:
		_pen["pateado"] = true
		_pen["t_tiro"] = 0.0
		return
	if estado == Estado.JUGANDO and quien != null:
		if era_pase:
			_relato(tr("¡Pasa %s!") % _nombre_de(quien), Color.WHITE)
		elif fuerza >= 11.0:
			_relato(tr("¡Dispara %s!") % _nombre_de(quien), Color("ffe08a"))


# ---------------------------------------------------------------- Penales

func _iniciar_penales() -> void:
	estado = Estado.PENALES
	_pen = {"turno": 0, "tiros": [0, 0], "goles": [0, 0], "fase": "preparar", "t": 2.5, "pateado": false, "t_tiro": 0.0}
	_balon.freeze = true
	_carga = 0.0
	_f_t = 0.0
	_actualizar_barra()
	_marcar_receptor(null)
	AudioManager.reproducir("silbato", -4.0)
	AudioManager.ui("warning", -8.0)
	_relato(tr("¡Empate! ¡Se define por penales!"), ORO, true)
	AvisoAccion.mostrar(get_tree(), "futbol_ayuda", "", "F TIRO · CLICK TOQUE · E SALIR", 1)
	_preparar_penal()


## Pone la pelota en el punto penal y a cada uno en su lugar para el tiro de este turno.
func _preparar_penal() -> void:
	var turno: int = _pen["turno"]
	var sx := (X_MAX - PEN_DIST) if turno == 0 else (X_MIN + PEN_DIST)
	_pen["fase"] = "preparar"
	_pen["t"] = 2.2
	_pen["pateado"] = false
	_pen["t_tiro"] = 0.0
	_pen["spot"] = Vector3(sx, SUELO, CENTRO.z)
	_balon.freeze = true
	_balon.linear_velocity = Vector3.ZERO
	_balon.angular_velocity = Vector3.ZERO
	_balon.global_position = Vector3(sx, SUELO + RADIO_BALON + 0.02, CENTRO.z)
	if is_instance_valid(_jugadora):
		var detras := Vector3(sx - 1.4, _jugadora.global_position.y, CENTRO.z) if turno == 0 \
			else Vector3(CENTRO.x - 3.0, _jugadora.global_position.y, CENTRO.z + 3.0)
		_jugadora.global_position = detras
		_jugadora.velocity = Vector3.ZERO
		_jugadora.reset_physics_interpolation()
	_actualizar_hud(tr("Patea la capitana") if turno == 0 else tr("Patean los BadJokes"))
	_relato(tr("Penal para la bandada") if turno == 0 else tr("Penal para los BadJokes"), Color.WHITE, true)


func _paso_penales(delta: float) -> void:
	var b := _balon.global_position
	var turno: int = _pen["turno"]
	var spot: Vector3 = _pen["spot"]
	var fase: String = _pen["fase"]
	# El resto de las jugadoras al medio y los arqueros en su línea
	for e in _equipo:
		var p: PalomaNPC = e["p"]
		if not is_instance_valid(p):
			continue
		if e["rol"] == "arquero":
			e["cd"] = maxf(float(e["cd"]) - delta, 0.0)
			_ia_arquero(delta, e, b, _balon.linear_velocity)
		elif turno == 1 and int(e["eq"]) == 1 and int(e.get("idx", 0)) == 1:
			# La rival que tira: se acomoda detrás de la pelota
			p.ir_controlada(delta, Vector3(spot.x + 1.4, SUELO, spot.z), 4.5)
			p.mirar_punto(delta, b)
		else:
			var lado := 1.0 if int(e["eq"]) == 0 else -1.0
			var k := float(int(e.get("idx", 0)))
			p.ir_controlada(delta, Vector3(CENTRO.x + lado * (2.0 + k), SUELO, CENTRO.z + (k - 2.0) * 2.0), 5.0, true)
	_jugar_jugadora(delta, b)
	match fase:
		"preparar":
			_pen["t"] = float(_pen["t"]) - delta
			if float(_pen["t"]) <= 0.0:
				_pen["fase"] = "tiro"
				_pen["t_espera"] = 1.1
				_relato(tr("¡Patea!") if turno == 0 else tr("Patea el rival..."), Color.WHITE)
		"tiro":
			if turno == 1 and not bool(_pen["pateado"]):
				_pen["t_espera"] = float(_pen["t_espera"]) - delta
				if float(_pen["t_espera"]) <= 0.0:
					_tiro_rival_penal()
			if bool(_pen["pateado"]):
				_pen["t_tiro"] = float(_pen["t_tiro"]) + delta
				var g := _gol_en(b)
				if (turno == 0 and g == 0) or (turno == 1 and g == 1):
					_resultado_penal(true)
				elif float(_pen["t_tiro"]) > 4.5 or (float(_pen["t_tiro"]) > 1.2 and _balon.linear_velocity.length() < 0.8) \
						or b.x < X_MIN - 4.0 or b.x > X_MAX + 4.0 or b.z < Z_MIN - 3.0 or b.z > Z_MAX + 3.0:
					_resultado_penal(false)
		"resultado":
			_pen["t"] = float(_pen["t"]) - delta
			if float(_pen["t"]) <= 0.0:
				_siguiente_penal()


func _tiro_rival_penal() -> void:
	var rival: PalomaNPC = null
	for e in _equipo:
		if int(e["eq"]) == 1 and e["rol"] == "campo" and int(e.get("idx", 0)) == 1:
			rival = e["p"]
	var lado := 1.0 if randf() < 0.5 else -1.0
	var punto := Vector3(X_MIN, SUELO, CENTRO.z + lado * randf_range(0.6, ARCO_MEDIO - 0.3))
	var dir := punto - _balon.global_position
	dir.y = 0.0
	_patear(dir.normalized(), randf_range(11.0, 15.0), 0.3, 1)
	if rival:
		rival.modelo.picotear()


func _resultado_penal(gol: bool) -> void:
	var turno: int = _pen["turno"]
	var tiros: Array = _pen["tiros"]
	var goles_pen: Array = _pen["goles"]
	tiros[turno] = int(tiros[turno]) + 1
	if gol:
		goles_pen[turno] = int(goles_pen[turno]) + 1
		_relato(tr("¡GOOOL!") if turno == 0 else tr("Gol de los BadJokes"), ORO if turno == 0 else Color("ff7f7f"), true)
		AudioManager.reproducir("arrullo", -2.0)
		AudioManager.ui("success" if turno == 0 else "failure", -4.0)
	else:
		_relato(tr("¡Atajó el arquero!") if turno == 0 else tr("¡Lo falló!"), Color("9be8ff"), true)
		AudioManager.ui("lock", -4.0)
	_pen["fase"] = "resultado"
	_pen["t"] = 2.0
	_actualizar_hud(tr("Penales"))


## Después de cada tiro: si ya se definió (mejor de 3, después muerte súbita) termina; si no, patea el otro.
func _siguiente_penal() -> void:
	var tiros: Array = _pen["tiros"]
	var g: Array = _pen["goles"]
	var t0 := int(tiros[0])
	var t1 := int(tiros[1])
	var definido := false
	if t0 == t1 and t0 >= 3 and int(g[0]) != int(g[1]):
		definido = true
	elif t0 <= 3 and t1 <= 3:
		# Ya no la puede alcanzar el que va abajo (con los tiros que le quedan en los primeros 3)
		var resta0 := 3 - t0
		var resta1 := 3 - t1
		if int(g[0]) > int(g[1]) + resta1 or int(g[1]) > int(g[0]) + resta0:
			definido = true
	if definido:
		_ganador_pen = 0 if int(g[0]) > int(g[1]) else 1
		goles = [int(g[0]), int(g[1])]
		_fin()
		return
	_pen["turno"] = 1 - int(_pen["turno"])
	_preparar_penal()


# ---------------------------------------------------------------- Hinchada

func _animar_hinchada(delta: float) -> void:
	for h in _hinchas:
		var p: PalomaNPC = h["p"]
		if not is_instance_valid(p):
			continue
		var pos: Vector3 = h["pos"]
		var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if bool(h["llego"]) or d < 0.2:
			h["llego"] = true
			var euf := 2.0 if (_euforia_t > 0.0 and _euforia_lado == 0) else 1.0
			p.animar_hincha(delta, pos, CENTRO, euf)
		else:
			p.ir_controlada(delta, pos, 7.0, true)
