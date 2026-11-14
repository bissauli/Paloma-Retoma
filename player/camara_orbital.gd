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

## Estos los setea la paloma cada frame
var en_aire := false
var en_picada := false
var bloqueada := false     ## Durante la cinemática se maneja desde afuera

var yaw := 0.0
var pitch := -0.28
var _sacudida := 0.0
var _objetivo: Node3D

@onready var brazo: SpringArm3D = $Brazo
@onready var camara: Camera3D = $Brazo/Camara


func _ready() -> void:
	_objetivo = get_parent() as Node3D
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _objetivo is CollisionObject3D:
		brazo.add_excluded_object((_objetivo as CollisionObject3D).get_rid())
	yaw = _objetivo.global_rotation.y
	global_position = _objetivo.global_position + Vector3.UP * altura


func _unhandled_input(event: InputEvent) -> void:
	if bloqueada:
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


func _process(delta: float) -> void:
	if bloqueada or _objetivo == null:
		return
	var destino := _objetivo.get_global_transform_interpolated().origin + Vector3.UP * altura
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))
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
		global_position = _objetivo.global_position + Vector3.UP * altura
