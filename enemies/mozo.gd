class_name Mozo
extends Enemigo
## El mozo: patrulla las mesas de los cafés. Si te ve cerca de las mesas, corre a espantarte
## con la bandeja. Si te alcanza, salís volando y se te cae lo que llevabas.

@export var velocidad_patrulla := 1.4
@export var velocidad_carrera := 3.6
@export var radio_vision := 6.5
@export var angulo_vision := 70.0          ## Grados a cada lado
@export var alcance := 1.3
@export var desde_x := -38.0
@export var hasta_x := 20.0
@export var enfriamiento := 3.0            ## Después de perseguirte tarda esto en volver a verte

enum Estado { PATRULLA, PERSIGUE, VUELVE }

var estado: Estado = Estado.PATRULLA
var _sentido := 1.0
var _z_patrulla := 0.0
var _t := 0.0
var _enfriamiento := 0.0
var _iniciado := false

@onready var modelo: ModeloHumano = $Modelo


func _ready() -> void:
	add_to_group("enemigos")


func _physics_process(delta: float) -> void:
	# La línea de patrulla se toma en el primer cuadro: la escena lo ubica DESPUÉS de add_child,
	# así que en _ready todavía está en el origen (y patrullaba en el medio de la plaza).
	if not _iniciado:
		_iniciado = true
		_z_patrulla = global_position.z
	var j := GameState.jugador
	_t -= delta
	_enfriamiento = maxf(_enfriamiento - delta, 0.0)
	match estado:
		Estado.PATRULLA:
			# Va y viene por la vereda frenando en cada mesa
			if global_position.x > hasta_x:
				_sentido = -1.0
			elif global_position.x < desde_x:
				_sentido = 1.0
			var v := Vector3(_sentido * velocidad_patrulla, 0, clampf(_z_patrulla - global_position.z, -1.0, 1.0))
			if fmod(absf(global_position.x), 7.0) < 0.3 and _t <= -1.0:
				_t = 1.5  # Pausa: atiende una mesa
			if _t > 0.0:
				v = Vector3.ZERO
			_acelerar(v, 4.0, delta)
			if j and _enfriamiento <= 0.0 and _ve(j):
				estado = Estado.PERSIGUE
				_t = 5.0
				AudioManager.reproducir_en("silbato", global_position, -6.0)
		Estado.PERSIGUE:
			if j == null or _t <= 0.0 or j.global_position.y > 3.0 or j.global_position.z < 26.0:
				_volver()
			else:
				var hacia := plano(j.global_position - global_position)
				_ir_hacia(j.global_position, velocidad_carrera, 5.0, delta)
				if hacia.length() < alcance and j.global_position.y < 2.5:
					_espantar(j)
		Estado.VUELVE:
			var base := Vector3(clampf(global_position.x, desde_x, hasta_x), 0, _z_patrulla)
			if plano(base - global_position).length() < 0.5:
				estado = Estado.PATRULLA
			else:
				_ir_hacia(base, velocidad_patrulla * 1.5, 4.0, delta)
	global_position += _paso_libre(delta)
	_girar_hacia_velocidad(delta, 8.0)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), estado == Estado.PERSIGUE)


## Cono de visión: te ve si estás cerca, bajito y delante de él (o muy pegada).
func _ve(j: Node3D) -> bool:
	if GameState.invulnerable > 0.0 or GameState.partida_terminada:
		return false
	var hacia := j.global_position - global_position
	if hacia.y > 2.5:
		return false
	hacia = plano(hacia)
	var d := hacia.length()
	if d < 2.0:
		return true
	if d > radio_vision:
		return false
	return _en_cono(hacia, angulo_vision)


func _espantar(j: Node3D) -> void:
	if GameState.invulnerable <= 0.0:
		GameState.invulnerable = 1.5
		if GameState.carga != "":
			GameState.set_carga("")
		modelo.gesto_tirar()
		if j.has_method("empujar"):
			var lejos := j.global_position - global_position
			lejos.z -= 2.0  # Siempre la manda hacia la plaza
			j.empujar(lejos, 7.0)
	_volver()


## Deja de perseguir y vuelve a la vereda. No te puede volver a ver enseguida:
## así no silba y arranca de nuevo en cada cuadro.
func _volver() -> void:
	estado = Estado.VUELVE
	_enfriamiento = enfriamiento
	_t = 0.0  # Que no se quede parado con lo que le sobraba de la persecución
