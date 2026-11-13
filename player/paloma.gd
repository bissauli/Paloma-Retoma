class_name PalomaJugador
extends CharacterBody3D
## La paloma del jugador. Camina lento con cabeceo, despega, aletea, planea,
## hace picadas y aterriza sola al tocar cualquier superficie.

signal despego
signal aterrizo(fuerte: bool)

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
var _coyote := 0.0
var _timer_aleteo_sfx := 0.0
var _enfriamiento_arrullo := 0.0
var _enfriamiento_picoteo := 0.0
var _rumbo := 0.0           ## Hacia dónde mira la paloma (yaw)
var _alabeo := 0.0
var _velocidad_previa := Vector3.ZERO

@onready var modelo: ModeloPaloma = $Modelo
@onready var camara: Node3D = $CamaraOrbital


func _ready() -> void:
	add_to_group("jugador")
	_rumbo = rotation.y
	rotation = Vector3.ZERO
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(50.0)
	GameState.carga_cambio.connect(modelo.mostrar_carga)
	GameState.jugador_atrapado.connect(_al_ser_atrapada)


func _physics_process(delta: float) -> void:
	var entrada := Vector2.ZERO
	if controlable:
		entrada = Input.get_vector("mover_izquierda", "mover_derecha", "mover_adelante", "mover_atras")
	var dir: Vector3 = camara.direccion_plana(entrada)
	_velocidad_previa = velocity

	if estado == Estado.SUELO:
		_fisica_suelo(delta, dir)
	else:
		_fisica_aire(delta, dir)

	move_and_slide()
	_revisar_contacto(delta)
	_orientar(delta)
	_acciones(delta)
	_animar(delta)

	camara.en_aire = estado == Estado.AIRE
	camara.en_picada = en_picada


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
	# Recarga lenta caminando
	GameState.set_stamina(GameState.stamina + Config.STAMINA_RECARGA_SUELO * delta)
	if controlable and Input.is_action_just_pressed("volar"):
		despegar()


func despegar() -> void:
	if GameState.stamina < 2.0:
		GameState.mensaje.emit("¡Sin aire! Comé migas para recuperar stamina", 2.0)
		return
	estado = Estado.AIRE
	_tiempo_en_aire = 0.0
	floor_snap_length = 0.0
	var adelante := Vector3(sin(_rumbo), 0, cos(_rumbo)) * -1.0
	velocity.y = impulso_despegue * (0.8 if GameState.carga != "" else 1.0)
	velocity += adelante * empuje_despegue
	GameState.set_stamina(GameState.stamina - Config.STAMINA_DESPEGUE)
	AudioManager.reproducir("aleteo")
	despego.emit()


func _fisica_aire(delta: float, dir: Vector3) -> void:
	_tiempo_en_aire += delta
	var hay_stamina := GameState.stamina > 0.5
	var picada_antes := en_picada
	en_picada = controlable and Input.is_action_pressed("picada")
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
	aterrizo.emit(fuerte)


## Gira el cuerpo hacia donde se mueve, con alabeo e inclinación en el aire.
func _orientar(delta: float) -> void:
	var h := Vector2(velocity.x, velocity.z)
	var rumbo_previo := _rumbo
	if h.length() > 0.3:
		var deseado := atan2(-h.x, -h.y)
		var vel_giro := 12.0 if estado == Estado.SUELO else giro_aire
		_rumbo = lerp_angle(_rumbo, deseado, minf(vel_giro * delta, 1.0))
	var cabeceo := 0.0
	var alabeo_obj := 0.0
	if estado == Estado.AIRE:
		var giro := wrapf(_rumbo - rumbo_previo, -PI, PI) / maxf(delta, 0.001)
		alabeo_obj = clampf(giro * 0.35, -0.8, 0.8)
		cabeceo = clampf(atan2(velocity.y, maxf(h.length(), 1.0)) * 0.7, -1.0, 0.6)
	_alabeo = lerpf(_alabeo, alabeo_obj, minf(6.0 * delta, 1.0))
	modelo.rotation = Vector3(cabeceo, _rumbo, _alabeo)


func _animar(delta: float) -> void:
	var modo := 0
	if estado == Estado.AIRE:
		if en_picada:
			modo = 3
		elif aleteando or _tiempo_en_aire < 0.35:
			modo = 1
		else:
			modo = 2
	modelo.animar(delta, modo, Vector2(velocity.x, velocity.z).length())


# ---------------------------------------------------------------- Picotear y arrullar

func _acciones(delta: float) -> void:
	_enfriamiento_arrullo = maxf(_enfriamiento_arrullo - delta, 0.0)
	_enfriamiento_picoteo = maxf(_enfriamiento_picoteo - delta, 0.0)
	if not controlable or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("picotear") and _enfriamiento_picoteo <= 0.0:
		_enfriamiento_picoteo = 0.28
		modelo.picotear()
		AudioManager.reproducir("picoteo", -3.0)
		_picotear_comida()
	if Input.is_action_just_pressed("arrullar") and _enfriamiento_arrullo <= 0.0:
		_enfriamiento_arrullo = enfriamiento_arrullo
		arrullar()


## Busca comida (grupo "comida") delante del pico y le avisa que fue picoteada.
func _picotear_comida() -> void:
	var adelante := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
	var punto := global_position + adelante * 0.45
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
	volver_al_nido()


## Teletransporta la paloma al nido (penalización leve, sin game over).
func volver_al_nido() -> void:
	var destino := GameState.posicion_nido + Vector3(randf_range(-2, 2), 0.5, 4.5)
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


## ¿Hay algo encima que la cubra (árbol, techo, galería)? Lo usa el halcón.
func esta_cubierta() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6,
		Vector3(global_position.x, minf(global_position.y + 25.0, 33.0), global_position.z), 1)  # sin tocar el techo invisible
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
