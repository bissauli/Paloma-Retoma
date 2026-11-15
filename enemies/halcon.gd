class_name Halcon
extends Node3D
## El halcón: aparece cuando la bandada llega a 15. Da vueltas alto sobre la plaza
## y, si volás alto y sin nada que te cubra, chilla y se tira en picada.
## Para zafar: bajá (aterrizá o volá bajito) o metete bajo un árbol, un techo o la galería.
## Si te atrapa, perdés algunas palomas y volvés al nido.

enum Estado { INACTIVO, CIRCULANDO, ALERTA, ATACANDO, SUBIENDO }

@export var altura_vuelo := 27.0
@export var radio_vuelta := 30.0
@export var velocidad_vuelta := 0.28       ## rad/s
@export var velocidad_ataque := 21.0
@export var altura_peligro := 7.0          ## Volando por encima de esto sos un blanco
@export var tiempo_alerta := 1.4           ## Aviso antes de tirarse
@export var enfriamiento := 12.0

var estado: Estado = Estado.INACTIVO
var _angulo := 0.0
var _vel := Vector3.ZERO
var _t := 0.0
var _enfriamiento := 0.0
var _modelo: Node3D
var _ala_izq: Node3D
var _ala_der: Node3D
var _fase := 0.0


func _ready() -> void:
	add_to_group("enemigos")
	_armar_modelo()
	visible = false
	GameState.halcon_activado.connect(activar)
	if GameState.halcon_activo:
		activar()


func activar() -> void:
	if estado != Estado.INACTIVO:
		return
	estado = Estado.CIRCULANDO
	visible = true
	_angulo = randf() * TAU
	global_position = Vector3(cos(_angulo) * radio_vuelta, altura_vuelo + 10.0, sin(_angulo) * radio_vuelta)
	AudioManager.reproducir("chillido_halcon", -2.0)


func _physics_process(delta: float) -> void:
	if estado == Estado.INACTIVO or GameState.partida_terminada:
		if estado != Estado.INACTIVO:
			_circular(delta)
		return
	_enfriamiento = maxf(_enfriamiento - delta, 0.0)
	var j := GameState.jugador
	match estado:
		Estado.CIRCULANDO:
			_circular(delta)
			if j and _enfriamiento <= 0.0 and _es_blanco(j):
				estado = Estado.ALERTA
				_t = tiempo_alerta
				AudioManager.reproducir("chillido_halcon", 2.0)
		Estado.ALERTA:
			_circular(delta)
			_t -= delta
			if j == null or not _es_blanco(j):
				estado = Estado.CIRCULANDO
				_enfriamiento = 3.0
			elif _t <= 0.0:
				estado = Estado.ATACANDO
				_t = 5.0
		Estado.ATACANDO:
			_t -= delta
			if j == null or _t <= 0.0 or not _es_blanco(j, true):
				_abortar(4.0)
			else:
				var objetivo := j.global_position + j.velocity * 0.25 + Vector3.UP * 0.3
				var hacia := objetivo - global_position
				_vel = _vel.lerp(hacia.normalized() * velocidad_ataque, minf(delta * 3.5, 1.0))
				global_position += _vel * delta
				_orientar(_vel, delta)
				if global_position.distance_to(j.global_position + Vector3.UP * 0.3) < 1.3:
					_atrapar(j)
		Estado.SUBIENDO:
			var punto := Vector3(cos(_angulo) * radio_vuelta, altura_vuelo, sin(_angulo) * radio_vuelta)
			var hacia := punto - global_position
			_vel = _vel.lerp(hacia.normalized() * 12.0, minf(delta * 2.0, 1.0))
			global_position += _vel * delta
			_orientar(_vel, delta)
			if hacia.length() < 2.0:
				estado = Estado.CIRCULANDO
	_animar_alas(delta)


## Sos un blanco si volás alto y nada te cubre desde arriba.
## Durante el ataque hay un poquito de tolerancia en la altura.
func _es_blanco(j: PalomaJugador, atacando := false) -> bool:
	if GameState.invulnerable > 0.0:
		return false
	if j.estado != PalomaJugador.Estado.AIRE:
		return false
	var limite := altura_peligro - (2.5 if atacando else 0.0)
	if j.global_position.y < limite or j.global_position.y > 32.0:
		return false
	return not j.esta_cubierta()


func _circular(delta: float) -> void:
	_angulo += velocidad_vuelta * delta
	var punto := Vector3(cos(_angulo) * radio_vuelta, altura_vuelo + sin(_angulo * 2.0) * 2.0,
		sin(_angulo) * radio_vuelta)
	var hacia := punto - global_position
	_vel = _vel.lerp(hacia * 1.5, minf(delta * 2.0, 1.0)).limit_length(14.0)
	global_position += _vel * delta
	_orientar(Vector3(-sin(_angulo), 0, cos(_angulo)), delta)


func _abortar(cd: float) -> void:
	estado = Estado.SUBIENDO
	_enfriamiento = cd


func _atrapar(j: PalomaJugador) -> void:
	AudioManager.reproducir("chillido_halcon", 4.0)
	GameState.atrapar("halcon", Config.PERDIDA_HALCON, j.global_position, true)
	_abortar(enfriamiento + 4.0)


func _orientar(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.1:
		return
	var rumbo := atan2(-dir.x, -dir.z)
	var cabeceo := clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.2, 0.8)
	_modelo.rotation.y = lerp_angle(_modelo.rotation.y, rumbo, minf(delta * 5.0, 1.0))
	_modelo.rotation.x = lerpf(_modelo.rotation.x, cabeceo, minf(delta * 5.0, 1.0))
	_modelo.rotation.z = lerpf(_modelo.rotation.z, 0.35 if estado == Estado.CIRCULANDO else 0.0, delta * 2.0)


func _animar_alas(delta: float) -> void:
	var z := 0.05
	if estado == Estado.ATACANDO:
		z = -0.9   # Alas recogidas en la picada
	elif estado == Estado.SUBIENDO:
		_fase += delta * 9.0
		z = sin(_fase) * 0.7
	else:
		_fase += delta * 1.5
		z = 0.08 + sin(_fase) * 0.08
	_ala_der.rotation.z = lerp_angle(_ala_der.rotation.z, z, minf(delta * 10.0, 1.0))
	_ala_izq.rotation.z = -_ala_der.rotation.z


func _armar_modelo() -> void:
	_modelo = Node3D.new()
	add_child(_modelo)
	var marron := Color("6b4a2f")
	var crema := Color("e6d6b8")
	Construir.esfera(_modelo, Vector3(0, 0, 0), 0.35, marron, Vector3(0.9, 0.8, 1.7), 8)
	Construir.esfera(_modelo, Vector3(0, -0.05, -0.15), 0.28, crema, Vector3(0.8, 0.7, 1.2), 8)
	Construir.esfera(_modelo, Vector3(0, 0.12, -0.6), 0.2, marron, Vector3.ONE, 8)
	var pico := Construir.prisma(_modelo, Vector3(0, 0.08, -0.82), Vector3(0.1, 0.18, 0.08), Color("f2c230"))
	pico.rotation.x = -PI / 2.0
	for lado in [-1.0, 1.0]:
		Construir.esfera(_modelo, Vector3(0.11 * lado, 0.17, -0.7), 0.045, Color("f2c230"), Vector3.ONE, 6)
	var cola := Construir.caja(_modelo, Vector3(0, 0, 0.7), Vector3(0.4, 0.05, 0.5), marron.darkened(0.2), false)
	cola.rotation.x = 0.1
	_ala_izq = _ala(-1.0, marron)
	_ala_der = _ala(1.0, marron)
	_modelo.scale = Vector3.ONE * 1.3


func _ala(lado: float, color: Color) -> Node3D:
	var p := Node3D.new()
	p.position = Vector3(0.25 * lado, 0.08, -0.05)
	_modelo.add_child(p)
	Construir.caja(p, Vector3(0.7 * lado, 0, 0.05), Vector3(1.4, 0.05, 0.55), color, false)
	Construir.caja(p, Vector3(1.3 * lado, 0, 0.18), Vector3(0.4, 0.04, 0.4), color.darkened(0.3), false)
	return p
