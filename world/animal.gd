class_name Animal
extends Node3D
## Perro o gato con esqueleto y animaciones (modelos/animales/*.glb, hechos con
## tools/blender/animales.py). Mapa V3.1: antes eran piezas fijas que daban saltitos. Cada uno hace su
## vida según su "conducta":
## - pasear: un perro que camina por su zona (sin atravesar nada, ver Navegacion), se para a olfatear,
##   se sienta, se echa, se rasca, a veces sale trotando, y les ladra (y espanta) a las palomas que se
##   le acercan.
## - agility: como pasear, pero cada tanto hace el circuito de agility del parque de perros: salta las
##   vallas, sube y baja la rampa y pasa por el túnel (ver "circuito").
## - sentado / echado: un perro que se queda en su lugar (sentado, echado, durmiendo, rascándose).
## - dormilon: Bolt, que duerme al lado de su cucha y levanta la cabeza cuando la paloma se acerca.
## - gato: se queda en su lugar (sentado, echado, durmiendo, lamiéndose o estirándose); si la paloma se
##   le acerca mucho, se para y la mira de reojo.
## - gato_paseo: un gato que camina despacio por su zona.
## El modelo mira hacia +Z.

const RUTA := "res://modelos/animales/%s.glb"
const CICLOS := ["quieto", "caminar", "trotar", "olfatear", "sentado", "echado", "dormido", "rascarse", "lamerse"]
const VEL_CAMINAR := 0.86     ## Velocidad de la animación "caminar" a escala 1 (m/s)
const VEL_TROTAR := 2.05      ## Ídem "trotar"
const LEJOS := 90.0           ## Más lejos de la cámara no se anima (pero sigue con lo suyo)

var variante := "perro_marron"
var conducta := "pasear"
var zona := Rect2()           ## Por donde camina (pasear, agility, gato_paseo)
## Agility: la pista cerrada (puntos en orden) y los obstáculos sobre ella: [[tipo, punto], ...] con
## tipo "valla", "rampa" o "tunel".
var pista := PackedVector3Array()
var obstaculos: Array = []

var _anim: AnimationPlayer
var _actual := ""
var _estado := "parado"       ## parado, yendo, una_vez, circuito
var _t := 0.0
var _y := 0.0
var _destino := Vector3.ZERO
var _rapidez := 0.0
var _nav := {}
var _ruta := PackedVector3Array()
var _ruta_fin := Vector3.INF
var _timer_mirar := 0.0
var _enfriamiento_ladrido := 0.0
var _enfriamiento_circuito := 0.0
var _lejos := false
# Circuito
var _s := 0.0
var _largos := PackedFloat32Array()
var _eventos: Array = []      ## [[distancia sobre la pista, tipo], ...]
var _saltos_hechos := {}


func _ready() -> void:
	add_to_group("animales")
	_y = position.y
	var escena := load(RUTA % variante) as PackedScene
	if escena == null:
		push_error("Animal: no está el modelo '%s'" % variante)
		return
	var modelo := escena.instantiate()
	add_child(modelo)
	var mallas: Array = []
	for m: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		m.material_override = Kit.material()
		mallas.append(m)
	Ajustes.registrar_sombra_dinamica(mallas)
	_anim = modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for n: String in CICLOS:
		if _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_al_terminar)
	_enfriamiento_circuito = randf_range(8.0, 20.0)
	_timer_mirar = randf()
	# Arranca quieto en su pose: la primera decisión llega cuando la ciudad ya está armada (su zona de
	# navegación necesita las colisiones)
	var pose := {"sentado": "sentado", "echado": "echado", "dormilon": "dormido", "gato": "sentado"}
	_parar(pose.get(conducta, "quieto"), randf_range(0.5, 3.0))
	# Que no arranquen todos sincronizados
	_anim.seek(randf() * _anim.current_animation_length, true)


func _process(delta: float) -> void:
	if _anim == null:
		return
	_timer_mirar -= delta
	if _timer_mirar <= 0.0:
		_timer_mirar = 0.3
		var cam := get_viewport().get_camera_3d()
		_lejos = cam != null and cam.global_position.distance_squared_to(global_position) > LEJOS * LEJOS
		_anim.active = not _lejos
		if not _lejos:
			_mirar_alrededor()
	_enfriamiento_ladrido -= delta
	_enfriamiento_circuito -= delta
	_t -= delta
	match _estado:
		"parado":
			if _t <= 0.0:
				_decidir()
		"yendo":
			_caminar(delta)
		"circuito":
			_correr_circuito(delta)
		"una_vez":
			if _t <= -0.5:      # por si la señal no llega
				_decidir()


# ---------------------------------------------------------------- decisiones

func _decidir() -> void:
	match conducta:
		"pasear", "agility":
			if conducta == "agility" and _enfriamiento_circuito <= 0.0 and pista.size() > 2 and randf() < 0.5:
				_ir_a(pista[0], 1.0, true)
				return
			_elegir([["ir", 40], ["trotar", 10], ["olfatear", 16], ["sentado", 10], ["echado", 5], ["rascarse", 5],
				["quieto", 10], ["ladrar", 4]])
		"sentado":
			_elegir([["sentado", 55], ["echado", 18], ["rascarse", 10], ["quieto", 12], ["ladrar", 5]])
		"echado":
			_elegir([["echado", 45], ["dormido", 45], ["sentado", 10]])
		"dormilon":
			_parar("echado" if _jugador_cerca(5.0) else "dormido", 3.0)
		"gato":
			_elegir([["sentado", 30], ["echado", 22], ["dormido", 20], ["lamerse", 20], ["estirarse", 8]])
		"gato_paseo":
			_elegir([["ir", 40], ["sentado", 18], ["lamerse", 16], ["echado", 14], ["quieto", 12]])
		_:
			_parar("quieto", 3.0)


func _elegir(opciones: Array) -> void:
	var total := 0.0
	for o: Array in opciones:
		total += float(o[1])
	var dado := randf() * total
	var que := "quieto"
	for o: Array in opciones:
		dado -= float(o[1])
		if dado <= 0.0:
			que = o[0]
			break
	match que:
		"ir":
			_ir_a(_punto_zona(), VEL_CAMINAR * escala_animal() * randf_range(1.1, 1.4))
		"trotar":
			_ir_a(_punto_zona(), VEL_TROTAR * escala_animal() * randf_range(1.1, 1.35))
		"olfatear":
			_parar("olfatear", randf_range(2.5, 6.0))
		"sentado":
			_parar("sentado", randf_range(5.0, 11.0))
		"echado":
			_parar("echado", randf_range(7.0, 14.0))
		"dormido":
			_parar("dormido", randf_range(10.0, 20.0))
		"rascarse":
			_parar("rascarse", randf_range(1.2, 2.4))
		"lamerse":
			_parar("lamerse", randf_range(3.0, 7.0))
		"ladrar", "estirarse":
			_una_vez(que)
		_:
			_parar("quieto", randf_range(1.5, 3.5))


func escala_animal() -> float:
	return scale.x


func _tocar(nombre: String, mezcla := 0.35, velocidad := 1.0) -> void:
	if not _anim.has_animation(nombre):
		nombre = "quieto"
	_anim.speed_scale = velocidad
	if nombre != _actual or not _anim.is_playing():
		_anim.play(nombre, mezcla)
		_actual = nombre


func _parar(anim: String, segundos: float) -> void:
	_estado = "parado"
	_t = segundos
	_tocar(anim, 0.45)


func _una_vez(anim: String) -> void:
	if not _anim.has_animation(anim):
		_parar("quieto", 1.0)
		return
	_estado = "una_vez"
	_actual = ""
	_tocar(anim, 0.15)
	_t = _anim.get_animation(anim).length
	if anim == "ladrar":
		AudioManager.reproducir_en("ladrido", global_position, -4.0)


func _al_terminar(_nombre: StringName) -> void:
	if _estado == "una_vez":
		_parar("quieto", randf_range(0.8, 2.0))
	elif _estado == "circuito":
		_tocar("trotar", 0.12, _rapidez / (VEL_TROTAR * escala_animal()))


## Ladra a la paloma de la jugadora si anda por el piso cerca, y espanta a las palomas sueltas que se
## le acercan (el gato, si la paloma se le pone al lado, se para a mirarla).
func _mirar_alrededor() -> void:
	var es_perro := variante.begins_with("perro")
	if es_perro and conducta != "dormilon":
		var cerca := false
		for n in get_tree().get_nodes_in_group("palomas_npc"):
			var p := n as PalomaNPC
			if p and p.modo == PalomaNPC.Modo.SUELTA and p.global_position.distance_squared_to(global_position) < 4.0:
				p.espantar(global_position)
				cerca = true
		var j := GameState.jugador
		if j and j.global_position.distance_squared_to(global_position) < 9.0 and j.global_position.y - global_position.y < 1.5:
			cerca = true
		if cerca and _enfriamiento_ladrido <= 0.0 and (_estado == "parado" or _estado == "yendo"):
			_enfriamiento_ladrido = randf_range(6.0, 11.0)
			_una_vez("ladrar")
	elif conducta == "dormilon":
		# Bolt levanta la cabeza cuando la paloma anda cerca de la cucha
		if _actual == "dormido" and _jugador_cerca(5.0):
			_parar("echado", 3.0)
	elif conducta == "gato" and (_actual == "dormido" or _actual == "lamerse") and _jugador_cerca(2.0):
		_parar("quieto", randf_range(2.0, 4.0))


func _jugador_cerca(metros: float) -> bool:
	var j := GameState.jugador
	return j != null and j.global_position.distance_squared_to(global_position) < metros * metros


# ---------------------------------------------------------------- caminar por la zona

func _punto_zona() -> Vector3:
	_asegurar_nav()
	var p := Vector3(randf_range(zona.position.x, zona.end.x), _y, randf_range(zona.position.y, zona.end.y))
	return Navegacion.mas_cercano(_nav, p)


func _asegurar_nav() -> void:
	if _nav.is_empty() and zona.has_area():
		_nav = Navegacion.zona(get_world_3d(), Vector3(zona.get_center().x, _y, zona.get_center().y), zona.size + Vector2(1, 1), 0.3)


func _ir_a(destino: Vector3, rapidez: float, al_circuito := false) -> void:
	if not zona.has_area():
		_parar("quieto", 2.0)
		return
	_asegurar_nav()
	_estado = "yendo"
	_destino = Vector3(destino.x, _y, destino.z)
	_rapidez = rapidez
	_t = 15.0
	_ruta = Navegacion.ruta(_nav, position, _destino)
	_ruta_fin = _ruta[_ruta.size() - 1] if not _ruta.is_empty() else _destino
	set_meta(&"al_circuito", al_circuito)
	var trote := rapidez > VEL_CAMINAR * escala_animal() * 1.6
	_tocar("trotar" if trote else "caminar", 0.3,
		rapidez / ((VEL_TROTAR if trote else VEL_CAMINAR) * escala_animal()))


func _caminar(delta: float) -> void:
	while not _ruta.is_empty() and Vector2(_ruta[0].x - position.x, _ruta[0].z - position.z).length() < 0.25:
		_ruta.remove_at(0)
	var hacia_fin := Vector2(_ruta_fin.x - position.x, _ruta_fin.z - position.z)
	if (_ruta.is_empty() and hacia_fin.length() < 0.3) or _t <= 0.0:
		if get_meta(&"al_circuito", false):
			_empezar_circuito()
		else:
			_decidir()
		return
	var objetivo := _ruta[0] if not _ruta.is_empty() else _ruta_fin
	var dir := Vector2(objetivo.x - position.x, objetivo.z - position.z).normalized()
	position.x += dir.x * _rapidez * delta
	position.z += dir.y * _rapidez * delta
	position.y = _y
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), minf(delta * 7.0, 1.0))


# ---------------------------------------------------------------- circuito de agility

func _empezar_circuito() -> void:
	_estado = "circuito"
	_largos.clear()
	var total := 0.0
	_largos.append(0.0)
	for k in pista.size():
		total += pista[k].distance_to(pista[(k + 1) % pista.size()])
		_largos.append(total)
	_eventos.clear()
	for o: Array in obstaculos:
		_eventos.append([_distancia_sobre_pista(o[1]), o[0]])
	_saltos_hechos.clear()
	_s = 0.0
	_rapidez = 2.5 * escala_animal() / 0.85
	_tocar("trotar", 0.2, _rapidez / (VEL_TROTAR * escala_animal()))


## Distancia desde el principio de la pista hasta el punto de la pista más cercano a "p".
func _distancia_sobre_pista(p: Vector3) -> float:
	var mejor := INF
	var s := 0.0
	for k in pista.size():
		var a := pista[k]
		var b := pista[(k + 1) % pista.size()]
		var q := Geometry3D.get_closest_point_to_segment(p, a, b)
		var d := q.distance_to(p)
		if d < mejor:
			mejor = d
			s = _largos[k] + a.distance_to(q)
	return s


func _punto_en_pista(s: float) -> Array:
	for k in pista.size():
		if s <= _largos[k + 1]:
			var a := pista[k]
			var b := pista[(k + 1) % pista.size()]
			var f := (s - _largos[k]) / maxf(_largos[k + 1] - _largos[k], 0.001)
			return [a.lerp(b, f), (b - a).normalized()]
	return [pista[0], (pista[1] - pista[0]).normalized()]


func _correr_circuito(delta: float) -> void:
	var total := _largos[_largos.size() - 1]
	# En la rampa va más despacio (y la sube caminando)
	var en_rampa := false
	var alto := 0.0
	for e: Array in _eventos:
		var u: float = _s - float(e[0])
		if e[1] == "rampa" and absf(u) < 2.0:
			en_rampa = true
			if absf(u) < 1.6:
				alto = 1.3 if absf(u) <= 0.15 else 1.3 * (1.6 - absf(u)) / 1.45
		elif e[1] == "valla" and u > -0.85 and u < 0.0 and not _saltos_hechos.has(e[0]):
			_saltos_hechos[e[0]] = true
			_actual = ""
			_tocar("saltar", 0.08, 1.0)
	var rapidez := _rapidez * (0.55 if en_rampa else 1.0)
	if en_rampa and _actual == "trotar":
		_tocar("caminar", 0.25, rapidez / (VEL_CAMINAR * escala_animal()))
	elif not en_rampa and _actual == "caminar":
		_tocar("trotar", 0.25, rapidez / (VEL_TROTAR * escala_animal()))
	_s += rapidez * delta
	if _s >= total:
		rotation.x = 0.0
		position.y = _y
		_enfriamiento_circuito = randf_range(25.0, 45.0)
		_parar("sentado" if randf() < 0.5 else "quieto", randf_range(3.0, 6.0))
		return
	var pd: Array = _punto_en_pista(_s)
	var p: Vector3 = pd[0]
	var dir: Vector3 = pd[1]
	position = Vector3(p.x, _y + alto, p.z)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(delta * 10.0, 1.0))
	# Sobre la rampa el cuerpo sigue la pendiente
	var pendiente := 0.0
	if alto > 0.0 and alto < 1.3:
		for e: Array in _eventos:
			if e[1] == "rampa":
				pendiente = atan2(1.3, 1.45) * (1.0 if _s < float(e[0]) else -1.0)
	rotation.x = lerp_angle(rotation.x, -pendiente, minf(delta * 10.0, 1.0))
