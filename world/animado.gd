class_name Animado
extends Node3D
## Movimiento simple para piezas del kit que no se fusionan (ver world/ciudad.gd):
## - girar: la calesita da vueltas.
## - hamacar: el asiento de la hamaca se balancea sobre el eje de arriba (su origen).
## - subibaja: la tabla sube y baja sobre su eje.
## - pasear: un perro camina por "zona" (con un trotecito), se para a olfatear y espanta a las
##   palomas sueltas que se le acercan.
## - respirar: un gato echado o sentado que apenas se mueve.

@export_enum("girar", "hamacar", "subibaja", "pasear", "respirar") var tipo := "girar"
@export var velocidad := 1.0
@export var amplitud := 0.5
var zona := Rect2()

var _t := 0.0
var _y := 0.0
var _destino := Vector3.ZERO
var _pausa := 0.0
var _timer_palomas := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	_y = position.y
	_destino = position


func _process(delta: float) -> void:
	_t += delta * velocidad
	match tipo:
		"girar":
			rotation.y += delta * velocidad
		"hamacar":
			rotation.x = sin(_t) * amplitud
		"subibaja":
			rotation.z = sin(_t) * amplitud
		"respirar":
			scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.025, 1.0)
		"pasear":
			_pasear(delta)


func _pasear(delta: float) -> void:
	if _pausa > 0.0:
		_pausa -= delta
		position.y = _y
		return
	var hacia := Vector3(_destino.x - position.x, 0.0, _destino.z - position.z)
	if hacia.length() < 0.3:
		_pausa = randf_range(1.0, 4.0)
		_destino = Vector3(randf_range(zona.position.x, zona.end.x), _y, randf_range(zona.position.y, zona.end.y))
		return
	var dir := hacia.normalized()
	position += dir * velocidad * delta
	# El modelo mira hacia +Z: el rumbo sigue a la dirección (girando de a poco)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 6.0, 1.0))
	position.y = _y + absf(sin(_t * 9.0)) * 0.05
	_timer_palomas -= delta
	if _timer_palomas <= 0.0:
		_timer_palomas = 0.3
		for n in get_tree().get_nodes_in_group("palomas_npc"):
			var p := n as PalomaNPC
			if p and p.modo == PalomaNPC.Modo.SUELTA and p.global_position.distance_squared_to(global_position) < 4.0:
				p.espantar(global_position)
