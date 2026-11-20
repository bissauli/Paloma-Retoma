class_name PalomaJugador
extends CharacterBody3D
## La paloma del jugador. Camina lento con cabeceo, despega, aletea, planea,
## hace picadas y aterriza sola al tocar cualquier superficie.

signal despego
signal aterrizo(fuerte: bool)
signal choco(impacto: float)    ## Se estrelló contra una pared a toda velocidad (impacto: m/s contra la pared)

enum Estado { SUELO, AIRE }

@export_group("Suelo")
@export var velocidad_caminar := 2.6
@export var aceleracion_suelo := 16.0
@export var gravedad_suelo := 25.0

@export_group("Vuelo")
@export var velocidad_vuelo := 10.0
@export var aceleracion_aire := 9.0
@export var arrastre_aire := 1.2           ## Frenado horizontal sin input
@export var impulso_despegue := 6.5
@export var empuje_despegue := 2.5         ## Empujoncito hacia adelante al despegar
@export var fuerza_aleteo := 18.0
@export var velocidad_subida := 6.0
@export var gravedad_planeo := 7.0
@export var caida_planeo := 2.2            ## Caída lenta: velocidad terminal planeando
@export var caida_cansada := 6.0           ## Sin stamina se cae más rápido
@export var giro_aire := 7.0

@export_group("Picada")
@export var velocidad_picada := 21.0
@export var bajada_picada := 15.0
@export var rebote_picada := 0.35          ## Parte de la velocidad que se convierte en subida al soltar Shift

@export_group("Carga")
@export var multiplicador_carga := 0.6     ## Velocidad al llevar comida pesada

@export_group("Acciones")
@export var radio_picoteo := 1.3
@export var enfriamiento_arrullo := 1.0

var estado: Estado = Estado.SUELO
var en_picada := false
var aleteando := false
var controlable := true

var _tiempo_en_aire := 0.0
var _tiempo_en_suelo := 0.0    ## Segundos seguidos en el piso: la stamina se recarga cada vez más rápido
var _coyote := 0.0
var _timer_aleteo_sfx := 0.0
var _enfriamiento_arrullo := 0.0
var _enfriamiento_picoteo := 0.0
var _enfriamiento_aletazo := 0.0
var _ala_izquierda := false      ## Con qué ala va el próximo aletazo (van alternando)
var _rumbo := 0.0           ## Hacia dónde mira la paloma (yaw)
var _alabeo := 0.0
var _velocidad_previa := Vector3.ZERO
var _aleteo_auto := 0.0     ## Segundos de aleteo animado sin input (el salto del menú)
var _aplastada := 0.0       ## Segundos que le quedan chata en el piso (la pisó un auto, ver aplastar)
var _aturdida := 0.0        ## Segundos que le quedan mareada (se estrelló contra una pared, ver chocar)
var _tween_aplastar: Tween
var descansando := false    ## Descansando (Q): las palomas de la bandada se sientan al lado
var _tween_descanso: Tween
var montada: Marker3D       ## El caballito de la calesita en el que está sentada (null = ninguno)
var _t_montar := 0.0
var _picada_bloqueada := false   ## Shift estaba apretado al despegar: la picada espera a que se suelte
var en_foto := false              ## Está en el modo cámara (ver ui/modo_foto.gd)
var bloquea_descanso := false     ## El partido de fútbol usa Q para otra cosa (ver world/partido_futbol.gd)
var _t_aviso_sombrero := 0.0
var _t_descanso := 0.0
var _descanso_contado := false
var _tween_rebote: Tween       ## El aplastoncito al aterrizar y el estirón al despegar (ver _rebote)
var _cabeceo := 0.0           ## Inclinación de adelante a atrás (suavizada, así no da tirones)

const DURACION_APLASTADA := 1.5
const VELOCIDAD_CHOQUE := 15.0     ## Velocidad contra la pared (m/s) desde la que el golpe la aturde: sólo la picada
const DURACION_ATURDIDA := 1.7     ## Segundos que queda mareada después de estrellarse (ver chocar)
const CAPA_GENTE := 4       ## Gente y autos (ver world/auto.gd): mientras está chata le pasan por encima

## En escena: una cinemática la mueve a mano (ver world/casa_enterable.gd). No corre la física
## (ni gravedad ni colisiones), sólo la animación.
var en_escena := false
var _escena_modo := 2       ## Animación en escena: 0 suelo, 1 aleteo, 2 planeo
var _escena_rapidez := 0.0

@onready var modelo: ModeloPaloma = $Modelo
@onready var camara: CamaraOrbital = $CamaraOrbital


func _enter_tree() -> void:
	# Antes que el _ready de cualquier hermano que la busque (bandada, enemigos)
	GameState.jugador = self
	add_to_group("jugador")


func _exit_tree() -> void:
	if GameState.jugador == self:
		GameState.jugador = null


func _ready() -> void:
	_rumbo = rotation.y
	rotation = Vector3.ZERO
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	GameState.carga_cambio.connect(modelo.mostrar_carga)
	GameState.jugador_atrapado.connect(_al_ser_atrapada)
	modelo.cortejo_logrado.connect(_al_cortejar)
	# Líneas de viento al volar rápido (van pegadas a la cámara)
	var viento := VientoVuelo.new()
	viento.name = "Viento"
	viento.jugador = self
	(camara.get_node("Brazo/Camara") as Node3D).add_child(viento)


func _physics_process(delta: float) -> void:
	if en_escena:
		velocity = Vector3.ZERO
		modelo.animar(delta, _escena_modo, _escena_rapidez)
		return
	var entrada := Vector2.ZERO
	if controlable and _aplastada <= 0.0 and _aturdida <= 0.0:
		entrada = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var dir: Vector3 = camara.direccion_plana(entrada)
	_velocidad_previa = velocity

	_t_montar = maxf(_t_montar - delta, 0.0)
	if montada == null and controlable and _t_montar <= 0.0 and Input.is_action_just_pressed("interactuar") \
			and Dialogos.cercano == null and estado == Estado.SUELO and _aplastada <= 0.0 and not descansando:
		var cab := _caballito_cercano()
		if cab:
			montar(cab)
	if montada != null:
		_paso_montada(delta)
		return
	if deslizando:
		_paso_deslizando(delta)
		return
	if controlable and _t_montar <= 0.0 and Input.is_action_just_pressed("interactuar") and Dialogos.cercano == null \
			and estado == Estado.SUELO and _aplastada <= 0.0 and not descansando and _tobogan_cercano() != null:
		deslizarse(_tobogan_cercano())
		return

	if _aplastada > 0.0:
		_aplastada -= delta
		if _aplastada <= 0.0:
			_reinflar()
	if estado == Estado.SUELO:
		_fisica_suelo(delta, dir)
	else:
		_fisica_aire(delta, dir)

	_aturdida = maxf(_aturdida - delta, 0.0)
	var v_antes := velocity      # Con la que llega a la pared (move_and_slide la frena)
	move_and_slide()
	_revisar_choque(v_antes)
	_revisar_contacto(delta)
	_revisar_baile()
	_revisar_descanso()
	_actualizar_avisos(delta)
	_orientar(delta)
	_acciones(delta)
	_animar(delta)

	camara.en_aire = estado == Estado.AIRE
	camara.en_picada = en_picada


# ---------------------------------------------------------------- Bailes (rueda de emotes)

## Baila uno de los bailes de Coreografia, mirando hacia la cámara, hasta que se mueva, vuele o picotee.
func bailar(baile: StringName) -> void:
	if estado != Estado.SUELO:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position - global_position
		_rumbo = atan2(-d.x, -d.z)
	modelo.bailar(baile)
	var b := get_tree().get_first_node_in_group("bandada") as Bandada
	if b:
		b.imitar_baile(baile)
	AudioManager.musica_baile(baile == &"gangnam")   # El caballito tiene su música (en fase: arranca con el baile)


## Se mete a bañarse (lo llama una fuente o un charco): hace el baño en el lugar, sin darse vuelta
## hacia la cámara, hasta que se mueva, vuele, picotee o arrulle (igual que cualquier baile).
func banarse() -> void:
	if estado != Estado.SUELO:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	modelo.bailar(Coreografia.BANO)


## El gran final del cortejo: lo ven las palomas sueltas de alrededor (las enamora la Bandada) y
## unos corazones suben de la jugadora.
func _al_cortejar() -> void:
	GameState.cortejo.emit(global_position, Config.RADIO_CORTEJO)
	for i in 3:
		var l := Label3D.new()
		l.text = "♥"
		l.font_size = 96
		l.modulate = Color(1, 0.4, 0.55)
		l.outline_size = 12
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.0028
		l.top_level = true
		add_child(l)
		l.global_position = global_position + Vector3((i - 1) * 0.35, 0.7, 0.0)
		var tw := l.create_tween().set_parallel(true)
		tw.tween_property(l, "global_position:y", global_position.y + 2.0 + i * 0.25, 1.2).set_delay(i * 0.12)
		tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4 + i * 0.12)
		tw.chain().tween_callback(l.queue_free)


func _revisar_baile() -> void:
	if AudioManager.sonando_baile() and modelo.baile_actual() != &"gangnam":
		AudioManager.musica_baile(false)   # Dejó de bailar (o se puso a bañarse): se corta la música
	if not modelo.bailando():
		return
	var corta := estado == Estado.AIRE or not GameState.en_partida
	if controlable and not corta:
		corta = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras").length() > 0.1 			or Input.is_action_just_pressed("volar") or Input.is_action_just_pressed("picotear") 			or Input.is_action_just_pressed("arrullar") or Input.is_action_just_pressed("aletazo")
	if corta:
		modelo.dejar_de_bailar()
		var b := get_tree().get_first_node_in_group("bandada") as Bandada
		if b:
			b.parar_baile()


# ---------------------------------------------------------------- Tobogán (E)

## La rampa del tobogán (ver tools/blender/ciudad_v3.py, "tobogan_torre"): en el espacio de la pieza
## baja hacia +X desde (0,62 ; 1,55) con una pendiente de 1,5 m cada 2,6 m, 0,62 m de ancho.
const TOB_X0 := 0.62
const TOB_X1 := 3.3
const TOB_Y0 := 1.55
const TOB_PENDIENTE := 1.5 / 2.6
const TOB_SOBRE := 0.2       ## Altura de las patas sobre el plano de la rampa
const TOB_TECHO := 3.15      ## Altura de arriba de la torre

var deslizando := false
var _tobogan: Marker3D
var _tob_x := 0.0
var _tob_vel := 0.0


## Altura de las patas sobre la rampa en la coordenada x (local) de la pieza.
func _tob_altura(x: float) -> float:
	return TOB_Y0 - (x - TOB_X0) * TOB_PENDIENTE + TOB_SOBRE


## El tobogán donde está parada (sobre la rampa o arriba de la torre), o null.
func _tobogan_cercano() -> Marker3D:
	for n in get_tree().get_nodes_in_group("toboganes"):
		var t := n as Marker3D
		if t == null:
			continue
		var l := t.global_transform.affine_inverse() * global_position
		var en_rampa := l.x >= TOB_X0 - 0.1 and l.x <= TOB_X1 and absf(l.z) <= 0.4 and absf(l.y - _tob_altura(l.x)) < 0.6
		var en_torre := absf(l.x) <= 0.8 and absf(l.z) <= 0.8 and absf(l.y - TOB_TECHO) < 0.5
		if en_rampa or en_torre:
			return t
	return null


func deslizarse(t: Marker3D) -> void:
	var l := t.global_transform.affine_inverse() * global_position
	_tobogan = t
	_tob_x = TOB_X0 if l.x < TOB_X0 + 0.1 else l.x
	_tob_vel = 1.5
	deslizando = true
	_t_montar = 0.3
	velocity = Vector3.ZERO
	en_picada = false
	aleteando = false
	if modelo.bailando():
		modelo.dejar_de_bailar()
	AudioManager.reproducir("aleteo", -10.0)
	Logros.sumar("toboganes")


func _paso_deslizando(delta: float) -> void:
	if not is_instance_valid(_tobogan) or not controlable or GameState.partida_terminada:
		deslizando = false
		return
	var dir := Vector3(_tobogan.global_basis * Vector3.RIGHT)
	dir.y = 0.0
	dir = dir.normalized()
	if _t_montar <= 0.0 and Input.is_action_just_pressed("volar"):
		_bajar_del_tobogan(dir, true)
		return
	_tob_vel = move_toward(_tob_vel, 7.0, 4.5 * delta)
	_tob_x += _tob_vel * cos(atan(TOB_PENDIENTE)) * delta
	if _tob_x >= TOB_X1:
		_bajar_del_tobogan(dir, false)
		return
	global_position = _tobogan.global_transform * Vector3(_tob_x, _tob_altura(_tob_x), 0.0)
	velocity = Vector3.ZERO
	_rumbo = atan2(-dir.x, -dir.z)
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)
	modelo.animar(delta, 0, 0.0)
	camara.en_aire = false
	camara.en_picada = false
	_acciones(delta)


## Sale de la rampa con la velocidad que llevaba (o volando si apretó volar).
func _bajar_del_tobogan(dir: Vector3, volando: bool) -> void:
	deslizando = false
	_t_montar = 0.3
	if volando:
		estado = Estado.AIRE
		_tiempo_en_aire = 0.0
		floor_snap_length = 0.0
		velocity = dir * _tob_vel * 0.8 + Vector3.UP * impulso_despegue
		despego.emit()
	else:
		velocity = dir * minf(_tob_vel, velocidad_caminar * 1.6) + Vector3.UP * 0.5


# ---------------------------------------------------------------- Caballitos de la calesita (E)

## El caballito (marcador del grupo "caballitos") al alcance, o null.
func _caballito_cercano() -> Marker3D:
	var mejor: Marker3D = null
	var mejor_d := 1.6
	for n in get_tree().get_nodes_in_group("caballitos"):
		var m := n as Marker3D
		if m == null:
			continue
		var d := m.global_position - global_position
		if absf(d.y) > 1.2:
			continue
		var cal_m := m.get_parent() as Animado
		if cal_m and (cal_m.humano_sentado(int(m.get_meta("indice", -1))) or cal_m.ocupado_por_paloma(int(m.get_meta("indice", -1)))):
			continue   # Ya hay alguien sentado ahí
		var h := Vector2(d.x, d.z).length()
		if h < mejor_d:
			mejor_d = h
			mejor = m
	return mejor


## Se sube al caballito: queda sentada, gira con la calesita y mira hacia donde ella gira.
func montar(m: Marker3D) -> void:
	montada = m
	_t_montar = 0.3
	velocity = Vector3.ZERO
	en_picada = false
	aleteando = false
	var cal := m.get_parent() as Animado
	if cal:
		cal.montadas += 1
		cal.marcar_paloma(int(m.get_meta("indice", -1)), self)
	if modelo.bailando():
		modelo.dejar_de_bailar()
	if _tween_descanso:
		_tween_descanso.kill()
	_tween_descanso = create_tween()
	_tween_descanso.tween_property(modelo, "scale", Vector3(1.1, 0.85, 1.1), 0.3).set_trans(Tween.TRANS_SINE)
	global_position = m.global_position
	reset_physics_interpolation()
	AudioManager.ui("menu_open", -10.0)
	Logros.sumar("subibaja" if cal and cal.tipo == "subibaja" else "calesita")
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada:
		bandada.subir_calesita(m)


## Mientras está montada la lleva el caballito. Se baja con E, al moverse o al volar.
func _paso_montada(delta: float) -> void:
	if not is_instance_valid(montada) or not controlable or GameState.partida_terminada:
		bajar_del_caballito()
		return
	var entrada := Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	if _t_montar <= 0.0 and (entrada.length() > 0.1 or Input.is_action_just_pressed("interactuar") \
			or Input.is_action_just_pressed("volar")):
		bajar_del_caballito(Input.is_action_just_pressed("volar"))
		return
	global_position = montada.global_position
	velocity = Vector3.ZERO
	_rumbo = montada.global_rotation.y
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)
	modelo.animar(delta, 0, 0.0)
	GameState.set_stamina(GameState.stamina + Config.recarga_suelo(3.0) * delta)
	camara.en_aire = false
	camara.en_picada = false
	_acciones(delta)


## Se baja del caballito hacia afuera de la calesita (o sale volando si apretó volar).
func bajar_del_caballito(volando := false) -> void:
	if montada == null:
		return
	var cal := montada.get_parent() as Animado
	if cal:
		cal.montadas = maxi(cal.montadas - 1, 0)
	var afuera := Vector3(montada.global_position.x - (cal.global_position.x if cal else 0.0), 0.0,
		montada.global_position.z - (cal.global_position.z if cal else 0.0))
	if afuera.length() < 0.4:
		# Un columpio: el asiento está justo debajo del eje, así que se baja hacia donde mira
		afuera = -montada.global_basis.z
		afuera.y = 0.0
	afuera = afuera.normalized()
	montada = null
	_t_montar = 0.3
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada:
		bandada.bajar_calesita()
	if _tween_descanso:
		_tween_descanso.kill()
	_tween_descanso = create_tween()
	_tween_descanso.tween_property(modelo, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	floor_snap_length = 0.0
	velocity = afuera * 2.0 + Vector3.UP * (impulso_despegue if volando else 2.5)
	if volando:
		despego.emit()


# ---------------------------------------------------------------- Descansar (Q)

## Q: se queda quieta descansando y las palomas de la bandada se sientan a su lado (en los cables,
## balcones, bordes de fuentes... ver Descanso). Se levanta al moverse, volar, dar un aletazo o con Q.
func _revisar_descanso() -> void:
	if descansando and en_foto:
		return      # Sacando fotos: sigue sentada con la bandada
	if descansando:
		# Tras unos segundos, si hay 3 o más palomas sentadas a su lado, cuenta como descanso en grupo
		_t_descanso += get_physics_process_delta_time()
		if not _descanso_contado and _t_descanso >= 3.0:
			var b := get_tree().get_first_node_in_group("bandada") as Bandada
			if b and b.cantidad_sentadas() >= 3:
				_descanso_contado = true
				Logros.sumar("descansos_grupo")
		var corta := estado == Estado.AIRE or not controlable or not GameState.en_partida \
				or GameState.partida_terminada or _aplastada > 0.0
		if not corta:
			corta = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras").length() > 0.1 \
				or Input.is_action_just_pressed("volar") or Input.is_action_just_pressed("descansar") \
				or Input.is_action_just_pressed("aletazo")
		if corta:
			levantarse()
	elif controlable and Input.is_action_just_pressed("descansar") \
			and (Ajustes.movil or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		descansar()


func descansar() -> void:
	if bloquea_descanso:
		return
	if descansando or montada != null or estado != Estado.SUELO or _aplastada > 0.0 or not GameState.en_partida \
			or GameState.partida_terminada or GameState.menu_activo:
		return
	if modelo.bailando():
		modelo.dejar_de_bailar()
	descansando = true
	_t_descanso = 0.0
	_descanso_contado = false
	velocity.x = 0.0
	velocity.z = 0.0
	if _tween_descanso:
		_tween_descanso.kill()
	_tween_descanso = create_tween()
	_tween_descanso.tween_property(modelo, "scale", Vector3(1.1, 0.82, 1.1), 0.4).set_trans(Tween.TRANS_SINE)
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada and not bandada.seguidoras.is_empty():
		var puestos: Array[Vector3] = Descanso.puestos(self, bandada.seguidoras.size())
		bandada.descansar(puestos, _rumbo)


func levantarse() -> void:
	if not descansando:
		return
	descansando = false
	if _tween_descanso:
		_tween_descanso.kill()
	if _aplastada <= 0.0:
		_tween_descanso = create_tween()
		_tween_descanso.tween_property(modelo, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada:
		bandada.levantarse()


# ---------------------------------------------------------------- Movimiento

func _mult_carga() -> float:
	return multiplicador_carga if GameState.carga != "" else 1.0


func _fisica_suelo(delta: float, dir: Vector3) -> void:
	en_picada = false
	aleteando = false
	var objetivo := dir * velocidad_caminar * _mult_carga()
	var h := Vector2(velocity.x, velocity.z).move_toward(Vector2(objetivo.x, objetivo.z), aceleracion_suelo * delta)
	velocity.x = h.x
	velocity.z = h.y
	velocity.y -= gravedad_suelo * delta
	# En el piso la stamina se recarga, y cada vez más rápido cuanto más tiempo seguido estés
	_tiempo_en_suelo += delta
	GameState.set_stamina(GameState.stamina + Config.recarga_suelo(_tiempo_en_suelo) * delta)
	if controlable and _aplastada <= 0.0 and _aturdida <= 0.0 and Input.is_action_just_pressed("volar"):
		despegar()


func despegar() -> void:
	if GameState.stamina < 2.0:
		return
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	floor_snap_length = 0.0
	var adelante := Vector3(sin(_rumbo), 0, cos(_rumbo)) * -1.0
	velocity.y = impulso_despegue * (0.8 if GameState.carga != "" else 1.0)
	velocity += adelante * empuje_despegue
	GameState.set_stamina(GameState.stamina - Config.STAMINA_DESPEGUE)
	_rebote(true, 0.7)
	AudioManager.reproducir("aleteo")
	despego.emit()


## Hacia dónde mira la paloma (yaw; 0 = hacia -Z).
func rumbo() -> float:
	return _rumbo


## Salto con aleteo del banco al piso al empezar la partida desde el menú principal (no gasta
## stamina). La cámara del menú se desengancha mientras tanto y pasa a seguirla
## (ver ui/menu/camara_menu.gd).
func saltar_inicio() -> void:
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	_coyote = 0.0
	floor_snap_length = 0.0
	_aleteo_auto = 0.55
	var adelante := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
	velocity = adelante * 2.0 + Vector3.UP * 4.4   # Cae un par de metros delante del banco
	AudioManager.reproducir("aleteo")
	despego.emit()


func _fisica_aire(delta: float, dir: Vector3) -> void:
	_tiempo_en_aire += delta
	_tiempo_en_suelo = 0.0     # Al despegar, la recarga vuelve a empezar de cero
	if _aturdida > 0.0:
		# Mareada después del choque: cae como piedra, sin controlar nada
		en_picada = false
		aleteando = false
		var frenado := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, 3.0 * delta)
		velocity.x = frenado.x
		velocity.z = frenado.y
		velocity.y = maxf(velocity.y - 22.0 * delta, -12.0)
		return
	var hay_stamina := GameState.stamina > 0.5
	var picada_antes := en_picada
	# Si Shift ya estaba apretado al despegar (o quedó "pegado"), la picada no cuenta hasta que se suelte:
	# antes la tiraba contra el piso apenas despegaba
	var shift_apretado := Input.is_action_pressed("picada")
	if _tiempo_en_aire <= delta * 1.5:
		_picada_bloqueada = shift_apretado
	elif not shift_apretado:
		_picada_bloqueada = false
	en_picada = controlable and shift_apretado and not _picada_bloqueada
	aleteando = controlable and Input.is_action_pressed("volar") and hay_stamina and not en_picada

	var h := Vector2(velocity.x, velocity.z)
	if en_picada:
		# Picada: se acelera hacia donde mira, girando con el input
		var adelante := Vector2(-sin(_rumbo), -cos(_rumbo))
		if dir.length() > 0.1:
			adelante = adelante.lerp(Vector2(dir.x, dir.z).normalized(), 0.5).normalized()
		h = h.move_toward(adelante * velocidad_picada, 28.0 * delta)
		velocity.y = move_toward(velocity.y, -bajada_picada, 30.0 * delta)
	else:
		if picada_antes:
			# Al salir de la picada parte de la velocidad se convierte en altura: ¡swoosh!
			velocity.y = maxf(velocity.y, 0.0) + h.length() * rebote_picada
			AudioManager.reproducir("aleteo", -4.0)
		var vmax := velocidad_vuelo * _mult_carga()
		if dir.length() > 0.1:
			h = h.move_toward(Vector2(dir.x, dir.z) * vmax, aceleracion_aire * delta)
		else:
			h = h.move_toward(Vector2.ZERO, arrastre_aire * delta)
		# Si venía más rápido (después de la picada), frena de a poco
		if h.length() > vmax:
			h = h.limit_length(maxf(vmax, h.length() - 6.0 * delta))

		if aleteando:
			var subida := velocidad_subida * (0.65 if GameState.carga != "" else 1.0)
			velocity.y = move_toward(velocity.y, subida, fuerza_aleteo * delta)
			GameState.set_stamina(GameState.stamina - Config.STAMINA_ALETEO * delta)
			_timer_aleteo_sfx -= delta
			if _timer_aleteo_sfx <= 0.0:
				_timer_aleteo_sfx = 0.32
				AudioManager.reproducir("aleteo", -8.0)
		else:
			var terminal := caida_planeo if hay_stamina else caida_cansada
			velocity.y = move_toward(velocity.y, -terminal, gravedad_planeo * delta)
	velocity.x = h.x
	velocity.z = h.y
	GameState.set_stamina(GameState.stamina - Config.STAMINA_PLANEO * delta)


## Aterrizaje automático y caída desde bordes.
func _revisar_contacto(delta: float) -> void:
	if estado == Estado.AIRE:
		if is_on_floor() and _tiempo_en_aire > 0.2 and velocity.y <= 0.5:
			_aterrizar()
	else:
		if is_on_floor():
			_coyote = 0.0
		else:
			_coyote += delta
			if _coyote > 0.12:
				# Se cayó de una cornisa: pasa a planear sin gastar despegue
				estado = Estado.AIRE
				_tiempo_en_aire = 0.0
				floor_snap_length = 0.0


func _aterrizar() -> void:
	var fuerte := en_picada or _velocidad_previa.y < -9.0
	estado = Estado.SUELO
	en_picada = false
	aleteando = false
	floor_snap_length = 0.25
	# Al aterrizar frena: se queda con poca velocidad horizontal
	var h := Vector2(velocity.x, velocity.z).limit_length(velocidad_caminar)
	velocity = Vector3(h.x, 0.0, h.y)
	if fuerte:
		camara.sacudir(0.6)
		AudioManager.reproducir("picoteo", -2.0)
	_rebote(false, 1.0 if fuerte else clampf(-_velocidad_previa.y / 8.0, 0.35, 0.8))
	aterrizo.emit(fuerte)


## Gira el cuerpo hacia donde se mueve, con alabeo e inclinación en el aire. En el piso, al caminar
## rápido se inclina un poquito hacia adelante y en las curvas se ladea apenas (como una paloma
## apurada). La inclinación se suaviza siempre: al cambiar de golpe la velocidad vertical (despegar,
## salir de la picada) el cuerpo no pega un tirón.
func _orientar(delta: float) -> void:
	var h := Vector2(velocity.x, velocity.z)
	var rumbo_previo := _rumbo
	if h.length() > 0.3 and _aturdida <= 0.0:    # Mareada no se da vuelta: sigue mirando la pared
		var deseado := atan2(-h.x, -h.y)
		var vel_giro := 12.0 if estado == Estado.SUELO else giro_aire
		_rumbo = lerp_angle(_rumbo, deseado, minf(vel_giro * delta, 1.0))
	var giro := wrapf(_rumbo - rumbo_previo, -PI, PI) / maxf(delta, 0.001)
	var cabeceo_obj := 0.0
	var alabeo_obj := 0.0
	if estado == Estado.AIRE:
		alabeo_obj = clampf(giro * 0.35, -0.8, 0.8)
		cabeceo_obj = clampf(atan2(velocity.y, maxf(h.length(), 1.0)) * 0.7, -1.0, 0.6)
	elif _aplastada <= 0.0:
		var rapidez := clampf(h.length() / maxf(velocidad_caminar, 0.1), 0.0, 1.2)
		cabeceo_obj = -0.1 * rapidez
		alabeo_obj = clampf(giro * 0.05, -0.14, 0.14) * rapidez
	var suave := 10.0 if estado == Estado.AIRE else 8.0
	_cabeceo = lerpf(_cabeceo, cabeceo_obj, minf(suave * delta, 1.0))
	_alabeo = lerpf(_alabeo, alabeo_obj, minf(6.0 * delta, 1.0))
	modelo.rotation = Vector3(_cabeceo, _rumbo, _alabeo)


## Un aplastoncito al aterrizar ("estirar" = false: se achata y vuelve con un rebote) o un estirón al
## despegar ("estirar" = true). "fuerza" de 0 a 1. No se mete con el aplastamiento del auto.
func _rebote(estirar: bool, fuerza: float) -> void:
	if _aplastada > 0.0 or (_tween_aplastar and _tween_aplastar.is_running()):
		return
	if _tween_rebote:
		_tween_rebote.kill()
	var k := clampf(fuerza, 0.0, 1.0)
	var forma := Vector3(1.0 - 0.12 * k, 1.0 + 0.18 * k, 1.0 - 0.12 * k) if estirar \
		else Vector3(1.0 + 0.16 * k, 1.0 - 0.24 * k, 1.0 + 0.16 * k)
	modelo.scale = Vector3.ONE
	_tween_rebote = create_tween()
	_tween_rebote.tween_property(modelo, "scale", forma, 0.06).set_ease(Tween.EASE_OUT)
	_tween_rebote.tween_property(modelo, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animar(delta: float) -> void:
	var modo := 0
	_aleteo_auto = maxf(_aleteo_auto - delta, 0.0)
	if estado == Estado.AIRE:
		if en_picada:
			modo = 3
		elif aleteando or _tiempo_en_aire < 0.35 or _aleteo_auto > 0.0:
			modo = 1
		else:
			modo = 2
	modelo.animar(delta, modo, Vector2(velocity.x, velocity.z).length())


# ---------------------------------------------------------------- Picotear y arrullar

func _acciones(delta: float) -> void:
	_enfriamiento_arrullo = maxf(_enfriamiento_arrullo - delta, 0.0)
	_enfriamiento_picoteo = maxf(_enfriamiento_picoteo - delta, 0.0)
	_enfriamiento_aletazo = maxf(_enfriamiento_aletazo - delta, 0.0)
	if not controlable or _aplastada > 0.0 or _aturdida > 0.0 \
			or (not Ajustes.movil and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	if Input.is_action_just_pressed("picotear") and _enfriamiento_picoteo <= 0.0:
		_enfriamiento_picoteo = 0.28
		modelo.picotear()
		AudioManager.reproducir("picoteo", -3.0)
		_picotear_comida()
	if Input.is_action_just_pressed("arrullar") and _enfriamiento_arrullo <= 0.0:
		_enfriamiento_arrullo = enfriamiento_arrullo
		arrullar()
	if Input.is_action_just_pressed("aletazo") and _enfriamiento_aletazo <= 0.0 and estado == Estado.SUELO:
		_enfriamiento_aletazo = 0.5
		aletazo()


# ---------------------------------------------------------------- Aletazo

## Alcance del aletazo: metros hacia adelante desde el pico, y qué tan de costado puede estar algo
## para que lo alcance el ala (se mide como cuánto se parece su dirección a la que mira la paloma).
const ALCANCE_ALETAZO := 1.5
const ANGULO_ALETAZO := 0.2

## Un golpe con el ala (como el zarpazo del gato de Little Kitty, Big City): un ala se arma, barre al
## frente y tira lo que encuentra: la comida (sale despedida de las mesas), tazas y vasos de los cafés
## (con física), los sombreros de la gente (que se queda sorprendida) y asusta a las palomas sueltas.
func aletazo() -> void:
	_ala_izquierda = not _ala_izquierda
	modelo.aletazo(_ala_izquierda)
	AudioManager.reproducir("aletazo", -3.0)
	# El golpe llega cuando el ala ya pasó por delante del pico (un ratito después de arrancar)
	await get_tree().create_timer(0.11).timeout
	if is_inside_tree():
		_golpear_adelante()


## ¿Algo en "pos" queda al alcance del ala, adelante? ("dir" es hacia donde mira la paloma.)
func _al_alcance(pos: Vector3, dir: Vector3, alcance := ALCANCE_ALETAZO) -> bool:
	var d := pos - global_position
	if absf(d.y) > 1.3:
		return false
	d.y = 0.0
	var largo := d.length()
	return largo < 0.45 or (largo <= alcance and d.normalized().dot(dir) > ANGULO_ALETAZO)


## Golpea todo lo que haya al alcance. Devuelve cuántas cosas tiró.
func _golpear_adelante() -> int:
	var dir := Vector3(-sin(_rumbo), 0.0, -cos(_rumbo))
	var tiradas := 0
	for n in get_tree().get_nodes_in_group("comida"):
		var c := n as Comida
		if c and _al_alcance(c.global_position, dir) and c.golpear(dir):
			tiradas += 1
	for n in get_tree().get_nodes_in_group("golpeables"):
		var g := n as Golpeable
		if g and _al_alcance(g.global_position, dir):
			var era_maceta := g.tipo == "maceta" and not g.golpeado
			if g.golpear(dir):
				tiradas += 1
				if era_maceta:
					Logros.sumar("macetas")
	var sombreros := 0
	for n in get_tree().get_nodes_in_group("humanos"):
		var h := n as Humano
		if h and _al_alcance(h.global_position, dir, ALCANCE_ALETAZO + 0.2) and h.sombrerazo(dir):
			tiradas += 1
			sombreros += 1
	for n in get_tree().get_nodes_in_group("palomas_npc"):
		var p := n as PalomaNPC
		if p and p.modo == PalomaNPC.Modo.SUELTA and _al_alcance(p.global_position, dir):
			p.espantar(global_position)
			tiradas += 1
	var bandada := get_tree().get_first_node_in_group("bandada") as Bandada
	if bandada:
		for p in bandada.seguidoras.duplicate():
			if not p.controlada and _al_alcance(p.global_position, dir):   # Las del partido no se golpean
				bandada.expulsar(p, global_position)
				Logros.sumar("expulsadas")
				tiradas += 1
	if tiradas > 0:
		camara.sacudir(0.15)
		AudioManager.reproducir("picoteo", -1.0)
		Logros.sumar("golpes", tiradas)
	if sombreros > 0:
		Logros.sumar("sombreros", sombreros)
	return tiradas


## Si hay un sombrero o gorra tirado (que se le cayó a alguien) delante del pico, se lo pone.
func _equipar_sombrero(punto: Vector3) -> bool:
	var g := _sombrero_cerca(punto)
	if g == null:
		return false
	modelo.poner_sombrero(g.tipo, g.color)
	Logros.registrar_sombrero(g.tipo, g.color)
	g.queue_free()
	AudioManager.ui("purchase", -12.0)
	return true


func _sombrero_cerca(punto: Vector3) -> Golpeable:
	for n in get_tree().get_nodes_in_group("golpeables"):
		var g := n as Golpeable
		if g == null or not g.desechable or not (g.tipo in ["sombrero", "gorra"]):
			continue
		if g.global_position.distance_to(punto) > radio_picoteo + 0.2 or absf(g.global_position.y - global_position.y) > 0.8:
			continue
		return g
	return null


## Avisos de acción de la jugadora (ver AvisoAccion): levantarse del descanso y ponerse un sombrero.
func _actualizar_avisos(delta: float) -> void:
	# Con 10 chequeos por segundo alcanza: recorrer los grupos (caballitos, toboganes, golpeables) y armar
	# los avisos en cada paso de física era trabajo de más
	_t_aviso_sombrero -= delta
	if _t_aviso_sombrero > 0.0:
		return
	_t_aviso_sombrero = 0.1
	var activa := controlable and GameState.en_partida and not GameState.partida_terminada and not GameState.menu_activo
	if activa and descansando:
		AvisoAccion.mostrar(get_tree(), "descanso", "Q", "LEVANTARSE", 4, levantarse)
	else:
		AvisoAccion.ocultar(get_tree(), "descanso")
	if activa and not deslizando and montada == null and not descansando and estado == Estado.SUELO \
			and Dialogos.cercano == null and _tobogan_cercano() != null:
		AvisoAccion.mostrar(get_tree(), "tobogan", "E", "DESLIZARSE", 2, func() -> void: deslizarse(_tobogan_cercano()))
	else:
		AvisoAccion.ocultar(get_tree(), "tobogan")
	if activa and montada != null:
		AvisoAccion.mostrar(get_tree(), "caballito", "E", "BAJARSE", 5, bajar_del_caballito)
	elif activa and not descansando and estado == Estado.SUELO and Dialogos.cercano == null and _caballito_cercano() != null:
		AvisoAccion.mostrar(get_tree(), "caballito", "E", "MONTARSE", 2, func() -> void: montar(_caballito_cercano()))
	else:
		AvisoAccion.ocultar(get_tree(), "caballito")
	var hay := false
	if activa and not descansando and estado == Estado.SUELO:
		var adelante := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
		hay = _sombrero_cerca(global_position + adelante * 0.45) != null
	if hay:
		AvisoAccion.mostrar(get_tree(), "sombrero", "CLICK", "PONERSE EL SOMBRERO", 3, _picotear_comida)
	else:
		AvisoAccion.ocultar(get_tree(), "sombrero")


## Busca comida (grupo "comida") delante del pico y le avisa que fue picoteada.
func _picotear_comida() -> void:
	var adelante := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
	var punto := global_position + adelante * 0.45
	if _equipar_sombrero(punto):
		return
	var mejor: Node3D = null
	var mejor_d := radio_picoteo
	for n in get_tree().get_nodes_in_group("comida"):
		var c := n as Node3D
		if c == null or not c.is_visible_in_tree():
			continue
		var d := c.global_position.distance_to(punto)
		if d < mejor_d:
			mejor_d = d
			mejor = c
	if mejor and mejor.has_method("picoteada"):
		mejor.picoteada(self)


func arrullar() -> void:
	modelo.arrullar()
	AudioManager.reproducir("arrullo")
	GameState.arrullo.emit(global_position, Config.RADIO_ARRULLO)
	_onda_arrullo()


## Efecto visual: un anillo que se expande desde la paloma.
func _onda_arrullo() -> void:
	var anillo := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	anillo.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.95, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	anillo.material_override = mat
	anillo.top_level = true
	add_child(anillo)
	anillo.global_position = global_position + Vector3.UP * 0.3
	anillo.scale = Vector3.ONE * 0.3
	var tw := anillo.create_tween().set_parallel(true)
	var r := Config.RADIO_ARRULLO
	tw.tween_property(anillo, "scale", Vector3(r, 1.0, r), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(anillo.queue_free)


# ---------------------------------------------------------------- Penalizaciones

func _al_ser_atrapada(_motivo: String) -> void:
	AudioManager.ui("failure", -4.0)
	volver_al_nido()


## Teletransporta la paloma al nido (penalización leve, sin game over).
func volver_al_nido() -> void:
	var destino := GameState.posicion_nido + Vector3(randf_range(-2, 2), 0.5, 4.5)
	if _aplastada > 0.0:
		_aplastada = 0.0
		collision_mask |= CAPA_GENTE
		_tween_aplastar.kill()
		modelo.scale = Vector3.ONE
	_aturdida = 0.0
	modelo.calmar()
	global_position = destino
	velocity = Vector3.ZERO
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	en_picada = false
	if GameState.carga != "":
		GameState.set_carga("")
	reset_physics_interpolation()
	camara.reubicar()
	GameState.jugador_volvio_al_nido.emit()


## ¿Se estrelló? Si llegó volando a VELOCIDAD_CHOQUE o más contra una pared (el mundo, no un auto ni
## un objeto que se mueve), choca: ver chocar. "v_antes" es la velocidad con la que llegó.
func _revisar_choque(v_antes: Vector3) -> void:
	if estado != Estado.AIRE or _aturdida > 0.0 or _aplastada > 0.0 or not GameState.en_partida \
			or v_antes.length() < VELOCIDAD_CHOQUE:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.5:
			continue       # Piso o techo: eso es aterrizar o rozar, no estrellarse
		var cuerpo := c.get_collider() as CollisionObject3D
		if cuerpo == null or cuerpo is RigidBody3D or (cuerpo.collision_layer & Construir.CAPA_MUNDO) == 0:
			continue
		var impacto := -v_antes.dot(n)
		if impacto >= VELOCIDAD_CHOQUE:
			chocar(c.get_position(), n, impacto)
			return


## Se estrelló de lleno contra una pared: una nube de polvo en el golpe, rebota hacia atrás y cae
## mareada (con estrellitas sobre la cabeza) sin poder controlarse hasta que se le pasa.
func chocar(punto: Vector3, normal: Vector3, impacto: float) -> void:
	var n := Vector3(normal.x, 0.0, normal.z)
	n = n.normalized() if n.length() > 0.01 else Vector3.ZERO
	if descansando:
		levantarse()
	_aturdida = DURACION_ATURDIDA
	en_picada = false
	aleteando = false
	velocity = n * clampf(impacto * 0.3, 3.0, 6.0) + Vector3.UP * 1.5
	camara.sacudir(1.0)
	AudioManager.reproducir("aplastar", -4.0)
	EfectoChoque.polvo(get_parent(), punto, normal)
	modelo.aturdir(DURACION_ATURDIDA)
	choco.emit(impacto)


# ---------------------------------------------------------------- Escenas (cinemáticas)

## Empieza una escena: la paloma deja de usar la física y se queda donde está hasta que la muevan
## con escena_mover(). El que la llama también bloquea la cámara y esconde el HUD.
func escena_empezar() -> void:
	en_escena = true
	controlable = false
	velocity = Vector3.ZERO
	en_picada = false
	aleteando = false
	_escena_modo = 1 if estado == Estado.AIRE else 0
	_escena_rapidez = 0.0


## Pone a la paloma en "pos" (global) mirando hacia "rumbo" (yaw) con la animación "modo"
## (0 suelo, 1 aleteo, 2 planeo, 3 picada). "cabeceo" inclina el pico (positivo = hacia arriba) y
## "alabeo" la inclina de costado (al doblar).
func escena_mover(pos: Vector3, rumbo_nuevo: float, modo: int, rapidez: float, cabeceo := 0.0, alabeo := 0.0) -> void:
	global_position = pos
	_rumbo = rumbo_nuevo
	_escena_modo = modo
	_escena_rapidez = rapidez
	_alabeo = alabeo
	_cabeceo = cabeceo
	modelo.rotation = Vector3(cabeceo, _rumbo, alabeo)


## Termina la escena y le devuelve la física. "en_aire": sale volando con la velocidad "vel"
## (global); si no, queda parada en el piso. El control (controlable) lo devuelve quien la llamó.
func escena_terminar(pos: Vector3, rumbo_nuevo: float, en_aire: bool, vel: Vector3) -> void:
	en_escena = false
	global_position = pos
	_rumbo = rumbo_nuevo
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)
	en_picada = false
	aleteando = false
	_tiempo_en_aire = 0.0
	_coyote = 0.0
	if en_aire:
		estado = Estado.AIRE
		floor_snap_length = 0.0
		velocity = vel
	else:
		estado = Estado.SUELO
		floor_snap_length = 0.25
		velocity = Vector3.ZERO
	reset_physics_interpolation()
	camara.reubicar()


## Un humano la espanta: sale volando de golpe en esa dirección (no gasta stamina).
func empujar(direccion: Vector3, fuerza: float) -> void:
	var d := Vector3(direccion.x, 0, direccion.z).normalized()
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	floor_snap_length = 0.0
	en_picada = false
	velocity = d * fuerza + Vector3.UP * fuerza * 0.7
	camara.sacudir(0.5)
	AudioManager.reproducir("aleteo")


## La pisó un auto: queda chata como una calcomanía en el piso (el auto le pasa por encima) y a los
## DURACION_APLASTADA segundos se infla de golpe con un "boing" y sigue como si nada. No pierde palomas.
func aplastar() -> void:
	if _aplastada > 0.0:
		return
	_aplastada = DURACION_APLASTADA
	# Si iba volando bajito, cae pegada al piso que tiene debajo
	if estado == Estado.AIRE:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3,
			global_position + Vector3.DOWN * 4.0, Construir.CAPA_MUNDO)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			global_position.y = (r["position"] as Vector3).y
		reset_physics_interpolation()
	estado = Estado.SUELO
	floor_snap_length = 0.25
	en_picada = false
	aleteando = false
	velocity = Vector3.ZERO
	collision_mask &= ~CAPA_GENTE
	camara.sacudir(0.7)
	AudioManager.reproducir("aplastar")
	# Chata en un instante, con un rebotecito, y respirando apenas mientras espera
	if _tween_aplastar:
		_tween_aplastar.kill()
	modelo.scale = Vector3.ONE
	_tween_aplastar = create_tween()
	_tween_aplastar.tween_property(modelo, "scale", Vector3(1.7, 0.05, 1.7), 0.06).set_ease(Tween.EASE_OUT)
	_tween_aplastar.tween_property(modelo, "scale", Vector3(1.5, 0.07, 1.5), 0.16).set_trans(Tween.TRANS_SINE)
	_tween_aplastar.tween_property(modelo, "scale", Vector3(1.55, 0.06, 1.55), 0.5).set_trans(Tween.TRANS_SINE)
	_tween_aplastar.tween_property(modelo, "scale", Vector3(1.5, 0.07, 1.5), 0.5).set_trans(Tween.TRANS_SINE)


## Se infla de golpe (se estira para arriba y se acomoda con un rebote elástico) y da un saltito.
func _reinflar() -> void:
	_aplastada = 0.0
	collision_mask |= CAPA_GENTE
	AudioManager.reproducir("boing")
	if _tween_aplastar:
		_tween_aplastar.kill()
	_tween_aplastar = create_tween()
	_tween_aplastar.tween_property(modelo, "scale", Vector3(0.7, 1.45, 0.7), 0.09).set_ease(Tween.EASE_OUT)
	_tween_aplastar.tween_property(modelo, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	velocity.y = 3.2


## ¿Está chata en el piso (la pisó un auto)?
func esta_aplastada() -> bool:
	return _aplastada > 0.0


## ¿Hay algo encima que la cubra (árbol, techo, galería)? Lo usa el halcón.
func esta_cubierta() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6,
		Vector3(global_position.x, minf(global_position.y + 25.0, 33.0), global_position.z), 1)  # sin tocar el techo invisible
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
