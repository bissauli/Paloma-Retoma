class_name Nene
extends Enemigo
## El nene: pasea por la plaza y, si te ve en el piso o volando bajito, te corre gritando.
## Si te alcanza, espanta parte de la bandada (no te manda al nido).

@export var velocidad_paseo := 1.3
@export var velocidad_carrera := 4.3        ## Más rápido que caminar, más lento que volar
@export var radio_vision := 10.0
@export var altura_maxima := 2.2            ## Por encima de esto no te puede alcanzar
@export var tiempo_carrera := 6.0           ## Después se cansa
@export var descanso := 5.0

enum Estado { PASEO, CORRIENDO, CANSADO }

var zona_centro := Vector3.ZERO
var zona_radio := 12.0
var estado: Estado = Estado.PASEO

var _t := 0.0
var _destino := Vector3.ZERO
var _timer_grito := 0.0

@onready var modelo: ModeloHumano = $Modelo


var _iniciado := false


func _ready() -> void:
	add_to_group("enemigos")


func _physics_process(delta: float) -> void:
	# La escena lo ubica después de add_child: la zona se toma en el primer cuadro, no en _ready
	if not _iniciado:
		_iniciado = true
		zona_centro = global_position
		_destino = global_position
		# Corre por un cuadrado más grande que su zona de paseo (cuando persigue se aleja un poco)
		nav_zona = Navegacion.zona(get_world_3d(), Vector3(zona_centro.x, 0.0, zona_centro.z),
			Vector2.ONE * (zona_radio * 2.0 + radio_vision * 2.0))
	var j := GameState.jugador
	_t -= delta
	_timer_grito -= delta
	match estado:
		Estado.PASEO:
			_pasear(delta)
			if j and _puede_perseguir(j):
				estado = Estado.CORRIENDO
				_t = tiempo_carrera
				_gritar()
		Estado.CORRIENDO:
			if j == null or _t <= 0.0 or j.global_position.y - global_position.y > altura_maxima + 1.5 \
					or j.global_position.distance_to(global_position) > radio_vision * 1.8:
				estado = Estado.CANSADO
				_t = descanso
			else:
				var hacia := plano(j.global_position - global_position)
				_ir_hacia(_proximo_punto(j.global_position, delta, 0.4), velocidad_carrera, 5.0, delta)
				if _timer_grito <= 0.0:
					_gritar()
				# ¿La alcanzó?
				var dy := j.global_position.y - global_position.y
				if hacia.length() < 0.9 and dy < altura_maxima:
					_atrapar(j)
		Estado.CANSADO:
			_acelerar(Vector3.ZERO, 3.0, delta)
			if _t <= 0.0:
				estado = Estado.PASEO
	global_position += _paso_libre(delta)
	global_position.y = 0.0
	_girar_hacia_velocidad(delta, 8.0)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), estado == Estado.CORRIENDO)


func _puede_perseguir(j: Node3D) -> bool:
	if GameState.invulnerable > 0.0 or GameState.partida_terminada:
		return false
	var d := j.global_position.distance_to(global_position)
	return d < radio_vision and j.global_position.y - global_position.y < altura_maxima


func _pasear(delta: float) -> void:
	if _t <= 0.0:
		_t = randf_range(2.0, 5.0)
		var a := randf() * TAU
		_destino = Navegacion.mas_cercano(nav_zona, zona_centro + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * zona_radio)
	var hacia := plano(_proximo_punto(_destino, delta) - global_position)
	_acelerar(Vector3.ZERO if hacia.length() < 0.4 else hacia.normalized() * velocidad_paseo, 3.0, delta)


func _gritar() -> void:
	_timer_grito = 2.2
	AudioManager.reproducir_en("grito_nene", global_position, 2.0)


func _atrapar(j: Node3D) -> void:
	var perdidas := maxi(int(ceil(GameState.bandada * Config.PERDIDA_NENE)), 0)
	if GameState.atrapar("nene", perdidas, global_position, false):
		if j.has_method("empujar"):
			j.empujar(j.global_position - global_position, 6.0)
	estado = Estado.CANSADO
	_t = descanso + 3.0
