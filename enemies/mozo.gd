class_name Mozo
extends Node3D
## El mozo: patrulla las mesas de los cafés. Si te ve cerca de las mesas, corre a espantarte
## con la bandeja. Si te alcanza, salís volando y se te cae lo que llevabas.

@export var velocidad_patrulla := 1.4
@export var velocidad_carrera := 3.6
@export var radio_vision := 6.5
@export var angulo_vision := 70.0          ## Grados a cada lado
@export var alcance := 1.3
@export var desde_x := -38.0
@export var hasta_x := 20.0

enum Estado { PATRULLA, PERSIGUE, VUELVE }

var estado: Estado = Estado.PATRULLA
var _sentido := 1.0
var _vel := Vector3.ZERO
var _rumbo := 0.0
var _z_patrulla := 0.0
var _t := 0.0

@onready var modelo: ModeloHumano = $Modelo


func _ready() -> void:
	add_to_group("enemigos")
	_z_patrulla = global_position.z


func _physics_process(delta: float) -> void:
	var j := get_tree().get_first_node_in_group("jugador") as Node3D
	_t -= delta
	match estado:
		Estado.PATRULLA:
			# Va y viene por la vereda frenando en cada mesa
			if global_position.x > hasta_x:
				_sentido = -1.0
			elif global_position.x < desde_x:
				_sentido = 1.0
			var v := Vector3(_sentido * velocidad_patrulla, 0, (_z_patrulla - global_position.z))
			if fmod(absf(global_position.x), 7.0) < 0.3 and _t <= -1.0:
				_t = 1.5  # Pausa: atiende una mesa
			if _t > 0.0:
				v = Vector3.ZERO
			_vel = _vel.lerp(v, minf(delta * 4.0, 1.0))
			if j and _ve(j):
				estado = Estado.PERSIGUE
				_t = 5.0
				AudioManager.reproducir_en("silbato", global_position, -6.0)
				GameState.mensaje.emit("¡El mozo te vio! ¡Rajá!", 1.8)
		Estado.PERSIGUE:
			if j == null or _t <= 0.0 or j.global_position.y > 3.0 or j.global_position.z < 26.0:
				estado = Estado.VUELVE
			else:
				var hacia := j.global_position - global_position
				hacia.y = 0
				_vel = _vel.lerp(hacia.normalized() * velocidad_carrera, minf(delta * 5.0, 1.0))
				if hacia.length() < alcance and j.global_position.y < 2.5:
					_espantar(j)
		Estado.VUELVE:
			var hacia := Vector3(clampf(global_position.x, desde_x, hasta_x), 0, _z_patrulla) - global_position
			hacia.y = 0
			if hacia.length() < 0.5:
				estado = Estado.PATRULLA
			else:
				_vel = _vel.lerp(hacia.normalized() * velocidad_patrulla * 1.5, minf(delta * 4.0, 1.0))
	global_position += _vel * delta
	if _vel.length() > 0.1:
		_rumbo = lerp_angle(_rumbo, atan2(-_vel.x, -_vel.z), minf(delta * 8.0, 1.0))
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), estado == Estado.PERSIGUE)


## Cono de visión: te ve si estás cerca, bajito y delante de él (o muy pegada).
func _ve(j: Node3D) -> bool:
	if GameState.invulnerable > 0.0 or GameState.partida_terminada:
		return false
	var hacia := j.global_position - global_position
	if hacia.y > 2.5:
		return false
	hacia.y = 0
	var d := hacia.length()
	if d < 2.0:
		return true
	if d > radio_vision:
		return false
	var mira := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
	return rad_to_deg(mira.angle_to(hacia)) < angulo_vision


func _espantar(j: Node3D) -> void:
	if GameState.invulnerable <= 0.0:
		GameState.invulnerable = 1.5
		if GameState.carga != "":
			GameState.set_carga("")
			GameState.mensaje.emit("¡El mozo te espantó y se te cayó la comida!", 2.5)
		else:
			GameState.mensaje.emit("¡Fuera, paloma! ¡Fuera!", 2.0)
		modelo.gesto_tirar()
		if j.has_method("empujar"):
			var lejos := j.global_position - global_position
			lejos.z -= 2.0  # Siempre la manda hacia la plaza
			j.empujar(lejos, 7.0)
	estado = Estado.VUELVE
