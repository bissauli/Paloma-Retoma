class_name Enemigo
extends Node3D
## Base de los humanos de la plaza (Humano, Mozo, Nene, Granadero): velocidad suavizada, rumbo
## del modelo y visión en cono. Lo que hacía cada uno por su cuenta vive acá una sola vez.

var _vel := Vector3.ZERO
var _rumbo := 0.0       ## Ángulo en Y hacia donde mira el modelo (0 = hacia -Z)
var _atendiendo: Node3D ## Con quién está hablando (la paloma): se queda quieto y la mira

# Caminos (ver world/navegacion.gd): la zona por donde camina y la ruta al destino actual
var nav_zona := {}                      ## Zona de navegación (vacía = camina en línea recta)
var _ruta := PackedVector3Array()
var _ruta_hacia := Vector3.INF          ## Destino para el que se calculó la ruta
var _ruta_fin := Vector3.INF            ## Último punto de la ruta (hasta donde se puede llegar)
var _ruta_timer := 0.0


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


## Hacia dónde caminar ahora para llegar a "destino" sin atravesar nada: el próximo punto de la ruta
## por la zona de navegación. La ruta se recalcula si el destino se movió más de medio metro o cada
## "refresco" segundos. Si el destino cae adentro de un obstáculo, la ruta termina en el borde y ahí se
## queda. Sin zona, mientras no está lista o si el destino (o él) está fuera de la zona, devuelve el
## destino: en línea recta.
func _proximo_punto(destino: Vector3, delta: float, refresco := 2.0) -> Vector3:
	if nav_zona.is_empty() or not Navegacion.dentro(nav_zona, destino) or not Navegacion.dentro(nav_zona, global_position):
		return destino   # fuera de su zona (persiguiendo, o lo movieron) va derecho, como antes
	_ruta_timer -= delta
	if plano(destino - _ruta_hacia).length() > 0.5 or _ruta_timer <= 0.0:
		_ruta = Navegacion.ruta(nav_zona, global_position, destino)
		_ruta_hacia = destino
		_ruta_fin = _ruta[_ruta.size() - 1] if not _ruta.is_empty() else Vector3.INF
		_ruta_timer = refresco if not _ruta.is_empty() else 0.5
	while not _ruta.is_empty() and plano(_ruta[0] - global_position).length() < 0.3:
		_ruta.remove_at(0)
	if not _ruta.is_empty():
		return Vector3(_ruta[0].x, global_position.y, _ruta[0].z)
	if _ruta_fin != Vector3.INF:
		return Vector3(_ruta_fin.x, global_position.y, _ruta_fin.z)
	return destino


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
