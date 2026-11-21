class_name Chico
extends Enemigo
## Chico de la plaza de juegos del parque (mapa V3.1): pasea por la plaza, se sube un rato a una
## hamaca, al subibaja o a la calesita, se sienta en el arenero y vuelve a pasear. Los juegos sólo se
## mueven mientras hay alguien arriba (world/animado.gd). No le hace nada a las palomas.
## Lo crea enemies/gente.gd en cada marcador "zona_chicos" de la ciudad. Se mueve en _process (después
## de los juegos, para seguir el asiento sin temblar).

enum Estado { PASEO, YENDO, ARRIBA, ARENERO, OBSERVANDO }

var zona_centro := Vector3.ZERO
var zona_tam := Vector2(20, 12)
var arenero := Vector3.INF      ## Centro del arenero (si hay)
var velocidad := 1.3
var estado: Estado = Estado.PASEO

var modelo: ModeloHumano
var _t := 0.0
var _arriba_t := 0.0
var _destino := Vector3.ZERO
var _juego: Animado
var _lugar := -1
var _altura := 0.0
var _desde_subir := Vector3.ZERO   ## Dónde estaba al empezar a subirse (para el saltito)
var _cadera := 0.2              ## Altura de la cola del chico sentado sobre su origen


## Un chico con su modelo (alto entre 1 y 1,3 m) y ropa de colores.
static func crear() -> Chico:
	var c := Chico.new()
	c.name = "Chico"
	var m := ModeloHumano.new()
	m.name = "Modelo"
	m.personaje = ["pibe", "pibe", "escolar", "escolar_nena"].pick_random()
	m.alto = randf_range(1.0, 1.3)
	c.add_child(m)
	c.modelo = m
	return c


func _ready() -> void:
	add_to_group("chicos")
	esquivar_obstaculos = false   # camina por su malla de navegación y se sube a los juegos
	process_priority = 10
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_altura = global_position.y
	_destino = global_position
	_cadera = 0.3 * modelo.alto / 1.75
	_t = randf_range(0.5, 4.0)


func _process(delta: float) -> void:
	if nav_zona.is_empty():
		nav_zona = Navegacion.zona(get_world_3d(), Vector3(zona_centro.x, _altura, zona_centro.z), zona_tam + Vector2(2, 2), 0.3)
	_t -= delta
	match estado:
		Estado.PASEO:
			if _t <= 0.0:
				_decidir()
			_ir_a(_destino, delta)
		Estado.YENDO:
			var e := _juego.entrada(_lugar) if _juego else arenero
			if _ir_a(e, delta, 0.35):
				if _juego and _juego.ocupado_por_paloma(_lugar):
					_quedarse_mirando()   # Una paloma se le adelantó: no puede subir
				else:
					_subirse()
			elif _t <= 0.0:
				_soltar_juego()
				estado = Estado.PASEO
		Estado.OBSERVANDO:
			# Con ganas de subir pero el caballito está ocupado por una paloma: mira cómo gira
			if _juego and is_instance_valid(_juego):
				var hacia := plano(_juego.global_position - global_position)
				if hacia.length_squared() > 0.01:
					_rumbo = lerp_angle(_rumbo, atan2(-hacia.x, -hacia.z), minf(delta * 5.0, 1.0))
			_acelerar(Vector3.ZERO, 6.0, delta)
			_avanzar(delta, _altura)
			modelo.rotation.y = _rumbo
			modelo.animar(delta, 0.0, fmod(_t, 3.0) < 0.6)   # De a ratos saluda, entusiasmado
			if _t <= 0.0:
				_soltar_juego()
				estado = Estado.PASEO
				_t = randf_range(1.0, 3.0)
			return
		Estado.ARRIBA:
			_arriba_t += delta
			var asiento := _juego.asiento_global(_lugar) * Transform3D(Basis.IDENTITY, Vector3(0, -_cadera, 0))
			if _arriba_t < 0.5:
				# Trepa al caballito con un saltito (no lo atraviesa)
				var u := _arriba_t / 0.5
				var pos := _desde_subir.lerp(asiento.origin, u) + Vector3.UP * sin(u * PI) * 0.7
				global_transform = Transform3D(asiento.basis, pos)
			else:
				global_transform = asiento
			modelo.rotation.y = 0.0
			# En el subibaja, si no viene nadie a la otra punta, se cansa de esperar
			var solo := _juego.tipo == "subibaja" and _juego.ocupados() < 2 and _arriba_t > 9.0
			modelo.animar(delta, 0.0, _juego.tipo == "girar" and fmod(_arriba_t, 6.0) < 1.2)
			if _t <= 0.0 or solo:
				_bajarse()
			return
		Estado.ARENERO:
			modelo.animar(delta, 0.0, fmod(_t, 4.0) < 0.8)
			if _t <= 0.0:
				modelo.cambiar_postura(false)
				estado = Estado.PASEO
				_t = randf_range(1.0, 3.0)
			return
	_avanzar(delta, _altura)
	_girar_hacia_velocidad(delta, 6.0)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length())


func _decidir() -> void:
	var dado := randf()
	if dado < 0.7:
		var juegos := get_tree().get_nodes_in_group("juegos_plaza")
		juegos.shuffle()
		# Si alguien espera en el subibaja, va primero ahí
		juegos.sort_custom(func(a: Animado, _b: Animado) -> bool: return a.tipo == "subibaja" and a.alguien_esperando())
		for j: Animado in juegos:
			var i := j.lugar_libre()
			if i >= 0:
				_juego = j
				_lugar = i
				j.reservar(i, self)
				estado = Estado.YENDO
				_t = 25.0
				return
	if dado < 0.85 and arenero != Vector3.INF:
		_juego = null
		estado = Estado.YENDO
		_t = 25.0
		return
	_destino = Navegacion.mas_cercano(nav_zona, zona_centro + Vector3(randf_range(-0.5, 0.5) * zona_tam.x, 0,
		randf_range(-0.5, 0.5) * zona_tam.y))
	_t = randf_range(2.5, 6.0)


## Camina hacia "punto" esquivando los juegos. Devuelve true al llegar.
func _ir_a(punto: Vector3, delta: float, cerca := 0.3) -> bool:
	if plano(punto - global_position).length() < cerca:
		_acelerar(Vector3.ZERO, 6.0, delta)
		return true
	var hacia := plano(_proximo_punto(punto, delta) - global_position)
	_acelerar(Vector3.ZERO if hacia.length() < 0.05 else hacia.normalized() * velocidad, 4.0, delta)
	# Si la ruta termina antes (el punto cae al lado de un juego), con estar cerca alcanza
	return hacia.length() < 0.05 and plano(punto - global_position).length() < 1.2


## Llegó a subirse pero el lugar está ocupado por una paloma: se queda parado mirando un rato.
func _quedarse_mirando() -> void:
	_vel = Vector3.ZERO
	estado = Estado.OBSERVANDO
	_t = randf_range(4.0, 7.0)


func _subirse() -> void:
	_vel = Vector3.ZERO
	_desde_subir = global_position
	modelo.cambiar_postura(true)
	if _juego:
		_juego.subir(_lugar)
		estado = Estado.ARRIBA
		_arriba_t = 0.0
		_t = randf_range(10.0, 22.0)
	else:
		estado = Estado.ARENERO
		global_position = arenero + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
		_rumbo = randf() * TAU
		modelo.rotation.y = _rumbo
		_t = randf_range(8.0, 15.0)


func _bajarse() -> void:
	var e := _juego.entrada(_lugar)
	_soltar_juego()
	modelo.cambiar_postura(false)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(e.x, _altura, e.z))
	estado = Estado.PASEO
	_destino = global_position
	_t = randf_range(1.0, 3.0)


func _soltar_juego() -> void:
	if _juego and is_instance_valid(_juego):
		_juego.soltar(_lugar)
	_juego = null
	_lugar = -1


func _exit_tree() -> void:
	_soltar_juego()
