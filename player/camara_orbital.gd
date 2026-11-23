class_name CamaraOrbital
extends Node3D
## Cámara orbital en tercera persona controlada con el mouse.
## Sigue al padre (la paloma) de forma suave y ajusta distancia y FOV según el vuelo.

@export var sensibilidad := 0.0028
@export var invertir_y := false
@export var altura := 0.75
@export var distancia_suelo := 3.0
@export var distancia_aire := 4.6
@export var distancia_picada := 5.4
@export var fov_normal := 70.0
@export var fov_aire := 76.0
@export var fov_picada := 98.0
@export var suavizado := 14.0
@export_group("Táctil")
@export var sensibilidad_tactil := 0.0062   ## Radianes por unidad de pantalla al deslizar el dedo
@export var seguir_rumbo := 1.1             ## En el aire, qué tan rápido se acomoda detrás de la paloma

## Estos los setea la paloma cada frame
var en_aire := false
var en_picada := false
var bloqueada := false     ## Durante la cinemática se maneja desde afuera

var yaw := 0.0
var pitch := -0.28
var _sacudida := 0.0
var _objetivo: Node3D
var _t_sin_tocar := 10.0   ## Segundos desde que el dedo movió la cámara (sólo teléfono)
## El resorte del brazo (que la cámara no atraviese paredes) se calcula acá en cada cuadro y no en
## cada paso de física: en el teléfono la física va a 30 Hz y el acercamiento de la cámara al
## despegar o al hacer picada se vería a los saltos.
var _consulta_resorte := PhysicsShapeQueryParameters3D.new()
## El punto de donde cuelga el brazo (sobre la paloma) tiene que quedar del mismo lado de las paredes que
## ella: pegada al techo de una sala, 75 cm más arriba ya es el hueco entre pisos del edificio, y la cámara
## mostraba eso (paredes negras, el piso de arriba). Ver _pivote_libre.
var _consulta_pivote := PhysicsShapeQueryParameters3D.new()
const AIRE_PIVOTE := 0.06     ## Lo que queda separado el punto de la cámara de lo que lo frena
const BRAZO_CORTO := 1.5        ## Más corto que esto, el brazo prueba ir derecho (ver _resorte)
const CENTRO_PALOMA := 0.22   ## Alto del centro de la esfera de choque de la paloma (player/paloma.tscn)

@onready var brazo: SpringArm3D = $Brazo
@onready var camara: Camera3D = $Brazo/Camara


func _ready() -> void:
	_objetivo = get_parent() as Node3D
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _objetivo is CollisionObject3D:
		brazo.add_excluded_object((_objetivo as CollisionObject3D).get_rid())
		_consulta_resorte.exclude = [(_objetivo as CollisionObject3D).get_rid()]
	brazo.set_physics_process_internal(false)
	_consulta_resorte.shape = brazo.shape
	_consulta_resorte.collision_mask = brazo.collision_mask
	_consulta_pivote.shape = brazo.shape
	_consulta_pivote.collision_mask = brazo.collision_mask
	_consulta_pivote.exclude = _consulta_resorte.exclude
	yaw = _objetivo.global_rotation.y
	global_position = _objetivo.global_position + Vector3.UP * altura


func _unhandled_input(event: InputEvent) -> void:
	if bloqueada or Ajustes.movil:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		# Lo que eligió el jugador en Opciones (se lee siempre: se puede cambiar desde la pausa)
		var sens := sensibilidad * Ajustes.sensibilidad
		var invertir := invertir_y != Ajustes.invertir_y
		yaw -= m.relative.x * sens
		var dy := m.relative.y * sens * (-1.0 if invertir else 1.0)
		pitch = clampf(pitch - dy, -1.25, 0.55)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Deslizar el dedo por la mitad derecha de la pantalla (lo llama ui/controles_tactiles.gd).
func girar_tactil(relativo: Vector2) -> void:
	if bloqueada:
		return
	_t_sin_tocar = 0.0
	var sens := sensibilidad_tactil * Ajustes.sensibilidad
	var invertir := invertir_y != Ajustes.invertir_y
	yaw -= relativo.x * sens
	var dy := relativo.y * sens * (-1.0 if invertir else 1.0)
	pitch = clampf(pitch - dy, -1.25, 0.55)


func _process(delta: float) -> void:
	if bloqueada or _objetivo == null:
		return
	# Teléfono: volando, la cámara se acomoda sola detrás de la paloma (si no la estás moviendo),
	# así inclinar el joystick a un costado es "doblar" como en cualquier juego de vuelo.
	_t_sin_tocar += delta
	if Ajustes.movil and en_aire and _t_sin_tocar > 0.8 and _objetivo.has_method("rumbo"):
		var cuerpo := _objetivo as CharacterBody3D
		var rapidez := Vector2(cuerpo.velocity.x, cuerpo.velocity.z).length() if cuerpo else 0.0
		var k := clampf(rapidez / 8.0, 0.0, 1.0) * seguir_rumbo
		yaw = lerp_angle(yaw, _objetivo.call("rumbo"), 1.0 - exp(-k * delta))
	var destino := _objetivo.get_global_transform_interpolated().origin + Vector3.UP * altura
	global_position = _pivote_libre(global_position.lerp(destino, 1.0 - exp(-suavizado * delta)))
	rotation = Vector3(pitch, yaw, 0.0)

	var dist := distancia_suelo
	var fov := fov_normal
	if en_picada:
		dist = distancia_picada
		fov = fov_picada
	elif en_aire:
		dist = distancia_aire
		fov = fov_aire
	brazo.spring_length = lerpf(brazo.spring_length, dist, 1.0 - exp(-4.0 * delta))
	camara.fov = lerpf(camara.fov, fov, 1.0 - exp(-5.0 * delta))
	_resorte()

	# Sacudida de cámara (golpes, aterrizajes en picada)
	if _sacudida > 0.0:
		_sacudida = maxf(_sacudida - delta * 2.5, 0.0)
		camara.h_offset = randf_range(-1.0, 1.0) * _sacudida * 0.15
		camara.v_offset = randf_range(-1.0, 1.0) * _sacudida * 0.15
	else:
		camara.h_offset = 0.0
		camara.v_offset = 0.0


## Dirección en el plano XZ relativa a la cámara para un input 2D.
func direccion_plana(entrada: Vector2) -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	var d := b * Vector3(entrada.x, 0.0, entrada.y)
	return d.limit_length(1.0)


func sacudir(intensidad: float) -> void:
	_sacudida = maxf(_sacudida, intensidad)


## Coloca la cámara de golpe detrás del objetivo (después de un teletransporte).
func reubicar() -> void:
	if _objetivo:
		global_position = _pivote_libre(_objetivo.global_position + Vector3.UP * altura)
		_resorte()


## "p" o, si entre la paloma y "p" hay algo del mundo (el techo de una sala, una pared al entrar por una
## ventana con la cámara atrasada), el último punto libre antes de eso.
func _pivote_libre(p: Vector3) -> Vector3:
	# Desde el centro de la esfera de la paloma (su origen está en las patas: desde ahí la esfera del brazo
	# arrancaría tocando el piso y no se movería)
	var desde := _objetivo.get_global_transform_interpolated().origin + Vector3.UP * CENTRO_PALOMA
	var mov := p - desde
	if mov.length_squared() < 1e-6:
		return p
	_consulta_pivote.transform = Transform3D(Basis.IDENTITY, desde)
	_consulta_pivote.motion = mov
	var r := get_world_3d().direct_space_state.cast_motion(_consulta_pivote)
	var k: float = r[0] if r.size() > 0 else 1.0
	if k < 1.0:
		# Con un poco de aire: si la esfera queda apoyada en el techo, el brazo (que arranca de acá) ya
		# empieza tocando, mide 0 y la cámara se mete adentro de la paloma
		k = maxf(k - AIRE_PIVOTE / mov.length(), 0.0)
	return desde + mov * k


## Lo mismo que hace el SpringArm3D: estira el brazo hacia atrás hasta spring_length o hasta
## chocar con el mundo (con la esfera del brazo), y ahí pone la cámara.
func _resorte() -> void:
	var t := brazo.global_transform
	var mov := t.basis.z.normalized() * brazo.spring_length
	_consulta_resorte.transform = t
	_consulta_resorte.motion = mov
	var r := get_world_3d().direct_space_state.cast_motion(_consulta_resorte)
	var k: float = r[0] if r.size() > 0 else 1.0
	var objetivo := Vector3(0, 0, brazo.spring_length * k)
	# Mirando hacia abajo, el brazo va hacia atrás y hacia arriba: pegada al techo de una sala chocaba
	# enseguida y la cámara quedaba encima de la paloma. Si así queda corto, prueba con el brazo derecho
	# (la cámara atrás, a la misma altura) y se queda con el más largo
	if k * brazo.spring_length < BRAZO_CORTO and mov.y > 0.01:
		var plano := Vector3(mov.x, 0.0, mov.z).normalized() * brazo.spring_length
		_consulta_resorte.motion = plano
		var r2 := get_world_3d().direct_space_state.cast_motion(_consulta_resorte)
		var k2: float = r2[0] if r2.size() > 0 else 1.0
		if k2 * brazo.spring_length > k * brazo.spring_length + 0.2:
			objetivo = t.basis.inverse() * (plano * k2)
	# Acercarse a la paloma (algo tapa) es rápido; volver a alejarse es suave: si no, la cámara pegaba
	# saltos de más de 3 cm cada vez que el resorte tocaba o soltaba algo
	var dt := get_process_delta_time()
	var actual := camara.position
	var paso := 1.0 - exp(-(28.0 if objetivo.length() < actual.length() else 7.0) * dt)
	camara.position = actual.lerp(objetivo, paso)
