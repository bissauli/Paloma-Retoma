class_name PalomaNPC
extends Node3D
## Una paloma no jugable. Puede estar suelta (paseando en su zona), siguiendo
## a la bandada (la mueve flock/bandada.gd), huyendo o festejando.
## No usa física: se mueve a mano y consulta la altura del piso con rayos de vez en cuando.
## Para no atravesar paredes, cada movimiento se chequea con un rayo contra el mundo (capa 1)
## y si choca se desliza a lo largo de la pared (ver mover_con_choques).

enum Modo { SUELTA, SIGUIENDO, HUYENDO, FESTEJANDO }

const NOMBRES := ["Carlos", "La Tana", "El Ruso", "Coqui", "Pocha", "Tito", "Mirta", "El Flaco",
	"Chiche", "La Negra", "Cacho", "Beba", "Pipo", "Nené", "Lalo", "Toto", "Chola", "Fito",
	"Marta", "El Tano", "Rulo", "Pupi", "Quique", "Nilda", "Cholo", "Kuki", "Tita", "Panchi"]

const ALTURA_RAYO := 0.3    ## Altura del rayo de choque: los escalones y cordones más bajos se suben
const RADIO_CHOQUE := 0.2   ## Distancia mínima a las paredes

var modo: Modo = Modo.SUELTA
var velocidad := Vector3.ZERO
var en_suelo := true
var nombre := ""
var zona_centro := Vector3.ZERO
var zona_radio := 5.0
var desplazamiento := Vector3.ZERO   ## Lugar propio dentro de la formación de la bandada
var altura_suelo := 0.0
var modo_anim := 0                   ## Lo usa la bandada para animar

var _rumbo := 0.0
var _destino := Vector3.ZERO
var _timer_paseo := 0.0
var _timer_suelo := 0.0
var _timer_huida := 0.0
var _picoteo_timer := 0.0
var _acum_fisica := 0.0    ## Tiempo acumulado de los pasos de física salteados (sueltas lejanas)
var _desfase := 0

## Un solo pedido de rayo para todas (crear uno nuevo en cada movimiento cuesta).
static var _rayo := PhysicsRayQueryParameters3D.new()
## Posición de la cámara en este paso de física (se lee una vez para todas las palomas).
static var _ref_paso := -1
static var _ref_pos := Vector3.ZERO
## Más lejos que esto de la cámara, las palomas sueltas se actualizan 1 de cada 3 pasos de física.
const LEJOS_CAMARA := 25.0

@onready var modelo: ModeloPaloma = $Modelo


func _ready() -> void:
	add_to_group("palomas_npc")
	nombre = NOMBRES[randi() % NOMBRES.size()]
	_rumbo = randf() * TAU
	_desfase = randi() % 3
	_timer_suelo = randf() * 0.5
	_timer_paseo = randf() * 3.0
	_destino = global_position
	desplazamiento = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.2, 3.8)
	desplazamiento.y = randf_range(0.2, 1.8)


## Variante de color al azar: gris, blanca, marrón, oscura, canela o manchada
## (llamar antes de agregarla al árbol).
func randomizar_colores() -> void:
	var m := get_node("Modelo") as ModeloPaloma
	m.variante = ModeloPaloma.variante_al_azar()


func configurar_zona(centro: Vector3, radio: float) -> void:
	zona_centro = centro
	zona_radio = radio
	_destino = centro


# ---------------------------------------------------------------- Cambios de modo

func reclutar() -> void:
	modo = Modo.SIGUIENDO
	GameState.registrar_seguidora(1)
	_corazon()


## Se separa de la bandada y sale volando lejos de "desde".
func soltar(desde: Vector3) -> void:
	if modo == Modo.SIGUIENDO:
		GameState.registrar_seguidora(-1)
	modo = Modo.HUYENDO
	en_suelo = false
	var lejos := (global_position - desde)
	lejos.y = 0
	if lejos.length() < 0.1:
		lejos = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	velocidad = lejos.normalized() * 8.0 + Vector3.UP * 5.0
	_timer_huida = randf_range(2.0, 3.5)


## Vuela hasta una zona y aterriza ahí (al huir o al llegar volando desde afuera).
func ir_a_zona(centro: Vector3, radio: float) -> void:
	configurar_zona(centro, radio)
	var a := randf() * TAU
	_destino = centro + Vector3(cos(a), 0, sin(a)) * randf() * radio


func festejar() -> void:
	modo = Modo.FESTEJANDO


func _corazon() -> void:
	var l := Label3D.new()
	l.text = "♥"
	l.font_size = 96
	l.modulate = Color(1, 0.4, 0.55)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0022
	l.position = Vector3(0, 0.8, 0)
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", 1.8, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)
	modelo.arrullar()


# ---------------------------------------------------------------- Actualización propia

func _physics_process(delta: float) -> void:
	if modo == Modo.SUELTA:
		# Las sueltas lejos de la cámara pasean igual, pero se calculan 1 de cada 3 pasos
		_acum_fisica += delta
		if (Engine.get_physics_frames() + _desfase) % 3 != 0 and _lejos_de_camara():
			return
		delta = _acum_fisica
		_acum_fisica = 0.0
	match modo:
		Modo.SUELTA:
			_paso_suelta(delta)
		Modo.HUYENDO:
			_paso_huida(delta)
		Modo.FESTEJANDO:
			_paso_festejo(delta)
		Modo.SIGUIENDO:
			pass  # La mueve la bandada
	if modo != Modo.SIGUIENDO:
		modelo.animar(delta, modo_anim, Vector2(velocidad.x, velocidad.z).length())


## Pasea por su zona, picotea el piso y se queda quieta un rato.
func _paso_suelta(delta: float) -> void:
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(2.0, 6.0)
		var a := randf() * TAU
		_destino = zona_centro + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * zona_radio
		if randf() < 0.35:
			_destino = global_position  # Se queda quieta
	var hacia := _destino - global_position
	hacia.y = 0
	var v := Vector3.ZERO
	if hacia.length() > 0.3:
		v = hacia.normalized() * 0.8
	velocidad = velocidad.lerp(v, minf(delta * 4.0, 1.0))
	if velocidad.length_squared() > 0.0025:
		mover_con_choques(velocidad * delta)
	_actualizar_suelo(delta, 0.6)
	global_position.y = lerpf(global_position.y, altura_suelo, minf(delta * 10.0, 1.0))
	en_suelo = true
	modo_anim = 0
	_mirar(velocidad, delta, 6.0)
	# Picoteos ocasionales cuando está quieta
	_picoteo_timer -= delta
	if _picoteo_timer <= 0.0:
		_picoteo_timer = randf_range(0.8, 3.0)
		if velocidad.length() < 0.2:
			modelo.picotear()


func _paso_huida(delta: float) -> void:
	_timer_huida -= delta
	var objetivo_y := 9.0
	if _timer_huida <= 0.0:
		# Ya se alejó: vuela hacia su nueva zona y aterriza
		var hacia := _destino - global_position
		var plano := Vector3(hacia.x, 0, hacia.z)
		var d := plano.length()
		var deseada := plano.normalized() * minf(9.0, d * 1.5 + 1.0)
		_actualizar_suelo(delta, 0.3)
		objetivo_y = altura_suelo + clampf(d * 0.4, 0.0, 9.0)
		deseada.y = clampf((objetivo_y - global_position.y) * 1.5, -4.0, 4.0)
		velocidad = velocidad.lerp(deseada, minf(delta * 2.0, 1.0))
		if d < 0.6 and global_position.y - altura_suelo < 0.3:
			modo = Modo.SUELTA
			velocidad = Vector3.ZERO
			global_position.y = altura_suelo
	else:
		velocidad.y = lerpf(velocidad.y, clampf(objetivo_y - global_position.y, -2.0, 5.0), delta * 2.0)
	mover_con_choques(velocidad * delta)
	global_position.y = maxf(global_position.y, altura_suelo)
	modo_anim = 1 if velocidad.y > 0.3 else 2
	_mirar(velocidad, delta, 5.0)


## Festejo de la victoria: saltitos, arrullos y vuelitos en el lugar.
func _paso_festejo(delta: float) -> void:
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(0.6, 2.0)
		if randf() < 0.5:
			modelo.arrullar()
		_rumbo += randf_range(-1.5, 1.5)
		if randf() < 0.3:
			velocidad.y = 3.0
	velocidad.y -= 9.8 * delta
	global_position.y += velocidad.y * delta
	if global_position.y < altura_suelo:
		global_position.y = altura_suelo
		velocidad.y = 0.0
	modo_anim = 1 if global_position.y > altura_suelo + 0.05 else 0
	modelo.rotation.y = lerp_angle(modelo.rotation.y, _rumbo, delta * 5.0)


# ---------------------------------------------------------------- Utilidades

## Altura del piso debajo (rayo hacia abajo, con poca frecuencia).
func _actualizar_suelo(delta: float, cada: float) -> void:
	_timer_suelo -= delta
	if _timer_suelo > 0.0:
		return
	_timer_suelo = cada * randf_range(0.8, 1.2)
	altura_suelo = medir_suelo(global_position)


func medir_suelo(p: Vector3) -> float:
	var r := _rayo_mundo(p + Vector3.UP * 1.5, p + Vector3.DOWN * 40.0)
	if r.is_empty():
		return 0.0
	return (r["position"] as Vector3).y


## Rayo contra el mundo (capa 1).
func _rayo_mundo(desde: Vector3, hasta: Vector3) -> Dictionary:
	_rayo.from = desde
	_rayo.to = hasta
	_rayo.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(_rayo)


func _lejos_de_camara() -> bool:
	var paso := Engine.get_physics_frames()
	if paso != _ref_paso:
		_ref_paso = paso
		var cam := get_viewport().get_camera_3d()
		_ref_pos = cam.global_position if cam else Vector3.ZERO
	return global_position.distance_squared_to(_ref_pos) > LEJOS_CAMARA * LEJOS_CAMARA


## Mueve la paloma sin atravesar el mundo: un rayo desde el cuerpo hasta un poco más allá
## del destino. Si pega contra una pared (o el techo de algo), se queda del lado de afuera y
## se desliza a lo largo; si pega contra algo transitable (techo, rampa, cornisa) se apoya encima.
func mover_con_choques(desp: Vector3) -> void:
	var desde := global_position + Vector3.UP * ALTURA_RAYO
	var horiz := Vector3(desp.x, 0.0, desp.z)
	var largo_h := horiz.length()
	var hasta := desde + desp
	if largo_h > 0.0001:
		hasta += horiz / largo_h * RADIO_CHOQUE
	var r := _rayo_mundo(desde, hasta)
	if r.is_empty():
		global_position += desp
		return
	var n: Vector3 = r["normal"]
	var punto: Vector3 = r["position"]
	if n.y > 0.6:
		# Piso: avanza y queda arriba de la superficie
		global_position += desp
		if global_position.y < punto.y:
			global_position.y = punto.y
			velocidad.y = maxf(velocidad.y, 0.0)
		altura_suelo = maxf(altura_suelo, punto.y)
		return
	# Pared o techo: saca la parte del movimiento que va hacia adentro y se desliza
	var hacia_adentro := desp.dot(n)
	if hacia_adentro < 0.0:
		desp -= n * hacia_adentro
	var vel_adentro := velocidad.dot(n)
	if vel_adentro < 0.0:
		velocidad -= n * vel_adentro
	# El deslizamiento también se chequea (por ejemplo en una esquina)
	if _rayo_mundo(desde, desde + desp + n * 0.01).is_empty():
		global_position += desp
	# Si quedó demasiado pegada, la separa un poquito de la pared
	var hn := Vector3(n.x, 0.0, n.z)
	var dist := (desde - punto).dot(n)
	if hn.length() > 0.5 and dist < RADIO_CHOQUE:
		global_position += hn.normalized() * minf(RADIO_CHOQUE - dist, 0.05)


## Un auto que pasa la asusta: sale volando un poquito y vuelve a su zona.
func espantar(desde: Vector3) -> void:
	if modo != Modo.SUELTA:
		return
	soltar(desde)
	velocidad *= 0.7
	_timer_huida = randf_range(0.8, 1.4)
	ir_a_zona(zona_centro, zona_radio)


## Orienta el modelo hacia la dirección de movimiento.
func _mirar(v: Vector3, delta: float, rapidez: float) -> void:
	var h := Vector2(v.x, v.z)
	if h.length() > 0.15:
		_rumbo = lerp_angle(_rumbo, atan2(-h.x, -h.y), minf(rapidez * delta, 1.0))
	var cabeceo := 0.0
	if modo_anim != 0:
		cabeceo = clampf(atan2(v.y, maxf(h.length(), 1.0)) * 0.6, -0.8, 0.6)
	modelo.rotation = Vector3(cabeceo, _rumbo, 0.0)


## Lo llama la bandada para mover a las seguidoras.
func mover_como_seguidora(delta: float, nueva_vel: Vector3, anim: int) -> void:
	velocidad = nueva_vel
	mover_con_choques(velocidad * delta)
	modo_anim = anim
	_actualizar_suelo(delta, 0.35)
	if global_position.y < altura_suelo:
		global_position.y = altura_suelo
		velocidad.y = maxf(velocidad.y, 0.0)
	en_suelo = global_position.y - altura_suelo < 0.05
	_mirar(velocidad, delta, 8.0)
	modelo.animar(delta, anim, Vector2(velocidad.x, velocidad.z).length())
