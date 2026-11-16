class_name Enemigo
extends Node3D
## Base de los humanos de la plaza (Humano, Mozo, Nene, Granadero): velocidad suavizada, rumbo
## del modelo y visión en cono. Lo que hacía cada uno por su cuenta vive acá una sola vez.

var _vel := Vector3.ZERO
var _rumbo := 0.0       ## Ángulo en Y hacia donde mira el modelo (0 = hacia -Z)
var _atendiendo: Node3D ## Con quién está hablando (la paloma): se queda quieto y la mira


## Acerca la velocidad actual a "objetivo". k = qué tan rápido responde (más alto, más brusco).
func _acelerar(objetivo: Vector3, k: float, delta: float) -> void:
	_vel = _vel.lerp(objetivo, minf(delta * k, 1.0))


## Acelera hacia "destino" (en el plano XZ) a "rapidez" m/s.
func _ir_hacia(destino: Vector3, rapidez: float, k: float, delta: float) -> void:
	_acelerar(plano(destino - global_position).normalized() * rapidez, k, delta)


## Empieza una conversación: se detiene y mira a "con_quien" (lo llama el Interlocutor).
func atender(con_quien: Node3D) -> void:
	_atendiendo = con_quien


## Terminó la conversación: retoma lo que hacía.
func dejar_de_atender() -> void:
	_atendiendo = null


## Gira el rumbo hacia quien lo está atendiendo (suave).
func _mirar_al_atendido(delta: float) -> void:
	if not is_instance_valid(_atendiendo):
		_atendiendo = null
		return
	var hacia := plano(_atendiendo.global_position - global_position)
	if hacia.length_squared() > 0.01:
		_rumbo = lerp_angle(_rumbo, atan2(-hacia.x, -hacia.z), minf(delta * 5.0, 1.0))


## Gira el rumbo hacia donde se mueve (si se mueve lo suficiente).
func _girar_hacia_velocidad(delta: float, k: float) -> void:
	if _vel.x * _vel.x + _vel.z * _vel.z > 0.01:
		_rumbo = lerp_angle(_rumbo, atan2(-_vel.x, -_vel.z), minf(delta * k, 1.0))


## Suma la velocidad a la posición dejándolo a la altura "y".
func _avanzar(delta: float, y: float) -> void:
	global_position += _vel * delta
	global_position.y = y


## ¿"hacia" (vector en el plano) cae dentro del cono de visión de "angulo" grados a cada lado?
func _en_cono(hacia: Vector3, angulo: float) -> bool:
	return rad_to_deg(Vector3(-sin(_rumbo), 0.0, -cos(_rumbo)).angle_to(hacia)) < angulo


static func plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
