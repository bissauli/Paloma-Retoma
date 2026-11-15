class_name GeneradorMigas
extends Node3D
## Va dejando migas en el piso dentro de un radio (turistas, señoras, oficinistas).
## Los humanos también pueden llamar a tirar() para lanzar migas con un arco.

@export var radio := 4.0
@export var maximo := 6
@export var intervalo := 3.0
@export var activo := true
@export var vida_miga := 70.0

var _timer := 0.0


func _ready() -> void:
	_timer = randf() * intervalo
	# Arranca con algunas migas ya en el piso
	for i in maximo >> 1:
		_crear_miga(_punto_al_azar())


func _process(delta: float) -> void:
	if not activo:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = intervalo * randf_range(0.7, 1.3)
		if _cantidad() < maximo:
			_crear_miga(_punto_al_azar())


func _cantidad() -> int:
	return get_child_count()


func _punto_al_azar() -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * radio
	return global_position + Vector3(cos(a) * r, 0, sin(a) * r)


func _crear_miga(pos: Vector3) -> Comida:
	return Comida.soltar(self, "miga", Vector3(pos.x, global_position.y, pos.z), vida_miga)


## Tira una miga desde un punto (la mano de un humano) con una parábola hasta el piso.
func tirar(desde: Vector3) -> void:
	if _cantidad() >= maximo + 3:
		return
	var destino := _punto_al_azar()
	var m := _crear_miga(destino)
	var final := m.global_position
	m.global_position = desde
	m.create_tween().tween_method(_mover_miga.bind(m, desde, final), 0.0, 1.0, 0.7)


func _mover_miga(k: float, m: Node3D, desde: Vector3, final: Vector3) -> void:
	if is_instance_valid(m):
		m.global_position = desde.lerp(final, k) + Vector3.UP * sin(k * PI) * 1.2
