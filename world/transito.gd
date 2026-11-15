class_name Transito
extends Node3D
## Tránsito de la avenida del sur (Z = 26..34): autos, taxis y colectivos en dos carriles
## (mano derecha: hacia el este por el carril sur, hacia el oeste por el carril norte),
## y dos cruces peatonales con semáforos que los hacen frenar.
## Los autos frenan ante el auto de adelante, el semáforo y la gente que cruza. A las palomas
## no las esperan: les tocan bocina, las sueltas se espantan y si te pisan salís volando.

const Z_CARRIL := {1: 32.0, -1: 28.0}
const X_LIMITE := 84.0
const CRUCES := [-40.5, 4.5]          ## X de cada senda peatonal (sin pisar las líneas del medio)
const ANCHO_CRUCE := 3.0
const T_VERDE := 13.0
const T_AMARILLO := 2.5
const T_ROJO := 8.0
const MAX_AUTOS := 16

enum Luz { VERDE, AMARILLO, ROJO }

var luz: Luz = Luz.VERDE
var _t_luz := 0.0
var _autos: Array[Auto] = []
var _timer_salida := {1: 0.0, -1: 1.5}
var _timer_palomas := 0.0
var _lamparas: Array = []     ## [MeshInstance3D rojo, amarillo, verde] por semáforo


func _ready() -> void:
	name = "Transito"
	for x: float in CRUCES:
		_armar_cruce(x)
	_mostrar_luz()
	# Sendas, postes y cabezales quedan fijos: se fusionan (las lámparas no, cambian de color)
	Construir.fusionar_estaticas(self)
	# Arranca con algunos autos ya andando
	for dir: int in [1, -1]:
		var x := -X_LIMITE + randf_range(5.0, 25.0)
		while x < X_LIMITE - 10.0:
			_crear_auto(dir, x * dir)
			x += randf_range(28.0, 50.0)


# ---------------------------------------------------------------- Semáforos

func _armar_cruce(cx: float) -> void:
	var n := Node3D.new()
	n.name = "Cruce%d" % roundi(cx)
	add_child(n)
	# Senda peatonal: franjas blancas a lo ancho de la avenida
	for k in 8:
		var z := 26.5 + k * 1.0
		Construir.caja(n, Vector3(cx, 0.016, z), Vector3(ANCHO_CRUCE, 0.01, 0.5), Color("ecebe4"), false)
	# Líneas de frenado y semáforos (a la derecha de cada carril, antes del cruce)
	for dir: int in [1, -1]:
		var z_carril: float = Z_CARRIL[dir]
		var x_linea := cx - dir * (ANCHO_CRUCE / 2.0 + 0.6)
		Construir.caja(n, Vector3(x_linea, 0.016, z_carril), Vector3(0.35, 0.01, 3.7), Color("ecebe4"), false)
		var z_poste := 34.35 if dir == 1 else 25.65
		_semaforo(n, Vector3(cx - dir * (ANCHO_CRUCE / 2.0 + 1.6), 0.0, z_poste), dir)


## Poste con cabezal de tres luces mirando hacia los autos que vienen.
func _semaforo(padre: Node3D, pos: Vector3, dir: int) -> void:
	var s := Node3D.new()
	padre.add_child(s)
	s.position = pos
	# Los autos que van hacia +X vienen desde -X: el cabezal mira hacia -X
	s.rotation.y = -PI / 2.0 if dir == 1 else PI / 2.0
	var y_base := 0.16 if dir == 1 else 0.0   # El del sur está sobre la vereda
	Construir.cilindro(s, Vector3(0, y_base + 1.6, 0), 0.07, 3.2, Color("23282b"), true, 6)
	Construir.caja(s, Vector3(0, y_base + 3.55, 0), Vector3(0.38, 1.05, 0.3), Color("1d2a22"), false)
	# Visera de cada luz y la lámpara (mira hacia +Z local = hacia los autos)
	var lamparas: Array = []
	for i in 3:
		var y := y_base + 3.9 - i * 0.33
		var lam := Construir.cilindro(s, Vector3(0, y, 0.16), 0.11, 0.04, Color("333333"), false, 10)
		lam.rotation.x = PI / 2.0
		lam.set_meta(&"no_fusionar", true)
		lamparas.append(lam)
		Construir.caja(s, Vector3(0, y + 0.13, 0.22), Vector3(0.26, 0.03, 0.12), Color("1d2a22"), false)
	# De espaldas, un cabezal chico para los peatones (sólo decorativo)
	Construir.caja(s, Vector3(0, y_base + 2.5, -0.2), Vector3(0.3, 0.35, 0.12), Color("1d2a22"), false)
	_lamparas.append(lamparas)


func _material_luz(color: Color, prendida: bool) -> StandardMaterial3D:
	if prendida:
		return Construir.material(color, 0.9, true)
	return Construir.material(color.darkened(0.75), 0.9)


func _mostrar_luz() -> void:
	var colores := [Color("ff3b2f"), Color("ffc21a"), Color("3bdc5a")]
	var prendida := 2 if luz == Luz.VERDE else (1 if luz == Luz.AMARILLO else 0)
	for trio: Array in _lamparas:
		for i in 3:
			(trio[i] as MeshInstance3D).material_override = _material_luz(colores[i], i == prendida)


func _avanzar_luz(delta: float) -> void:
	_t_luz += delta
	var dur := T_VERDE if luz == Luz.VERDE else (T_AMARILLO if luz == Luz.AMARILLO else T_ROJO)
	if _t_luz < dur:
		return
	_t_luz = 0.0
	luz = Luz.AMARILLO if luz == Luz.VERDE else (Luz.ROJO if luz == Luz.AMARILLO else Luz.VERDE)
	_mostrar_luz()


# ---------------------------------------------------------------- Autos

func _crear_auto(dir: int, x: float) -> Auto:
	var a := Auto.new()
	a.preparar(float(dir))
	add_child(a)
	a.global_position = Vector3(x, 0.005, Z_CARRIL[dir])
	a.reset_physics_interpolation()
	_autos.append(a)
	return a


func _physics_process(delta: float) -> void:
	_avanzar_luz(delta)
	_salidas(delta)
	var jugador := GameState.jugador
	# Sólo importa la gente que está sobre la avenida (casi nunca hay nadie): se filtra una vez
	# acá y no por cada auto
	var gente: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("cuerpos_humanos"):
		var h := n as Node3D
		if h and absf(h.global_position.z - 30.0) < 6.0 and h.is_visible_in_tree():
			gente.append(h)
	for dir: int in [1, -1]:
		var carril: Array[Auto] = []
		for a in _autos:
			if is_instance_valid(a) and int(a.sentido) == dir:
				carril.append(a)
		# De adelante hacia atrás
		carril.sort_custom(func(p: Auto, q: Auto) -> bool: return p.global_position.x * dir > q.global_position.x * dir)
		for i in carril.size():
			var a := carril[i]
			var adelante: Auto = carril[i - 1] if i > 0 else null
			_conducir(a, adelante, delta, gente)
			if jugador:
				_revisar_jugador(a, jugador, delta)
	_timer_palomas -= delta
	if _timer_palomas <= 0.0:
		_timer_palomas = 0.2
		_espantar_palomas()
	# Los que salieron del mapa desaparecen
	for a in _autos.duplicate():
		if a.global_position.x * a.sentido > X_LIMITE:
			_autos.erase(a)
			a.queue_free()


func _salidas(delta: float) -> void:
	for dir: int in [1, -1]:
		_timer_salida[dir] -= delta
		if _timer_salida[dir] > 0.0 or _autos.size() >= MAX_AUTOS:
			continue
		# Que no aparezca encima del último que salió
		var libre := true
		for a in _autos:
			if int(a.sentido) == dir and (a.global_position.x * dir) < -X_LIMITE + 14.0:
				libre = false
				break
		if libre:
			_crear_auto(dir, -X_LIMITE * dir)
			_timer_salida[dir] = randf_range(2.5, 6.5)


func _conducir(a: Auto, adelante: Auto, delta: float, gente: Array[Node3D]) -> void:
	var dir := a.sentido
	var deseada := a.velocidad_crucero
	var frente := a.trompa()
	# Distancia al de adelante
	if adelante:
		var hueco := (adelante.global_position.x - adelante.sentido * adelante.largo / 2.0 - frente) * dir
		deseada = minf(deseada, maxf((hueco - 2.0) * 1.4, 0.0))
	# Semáforo: frena antes de la línea si está en rojo, o en amarillo si le da para frenar
	if luz != Luz.VERDE:
		for cx: float in CRUCES:
			var linea: float = cx - dir * (ANCHO_CRUCE / 2.0 + 0.6)
			var dist := (linea - frente) * dir
			if dist < -0.3 or dist > 45.0:
				continue
			var frenado := a.velocidad * a.velocidad / (2.0 * 6.0)
			if luz == Luz.ROJO or dist > frenado:
				deseada = minf(deseada, maxf(dist - 0.2, 0.0) * 1.2)
	# Gente cruzando delante
	for h: Node3D in gente:
		var delante := (h.global_position.x - frente) * dir
		if delante > -0.5 and delante < 9.0 and absf(h.global_position.z - a.global_position.z) < a.ancho / 2.0 + 0.5:
			deseada = minf(deseada, maxf(delante - 1.5, 0.0))
	var acel := 3.5 if deseada > a.velocidad else 9.0
	a.velocidad = move_toward(a.velocidad, deseada, acel * delta)
	a.global_position.x += dir * a.velocidad * delta
	a.bocina_enfriamiento = maxf(a.bocina_enfriamiento - delta, 0.0)


## Bocinazo si la paloma está en el carril adelante; si la toca, la manda a volar (sin perder palomas).
func _revisar_jugador(a: Auto, j: Node3D, _delta: float) -> void:
	var p := j.global_position
	if p.y > a.alto + 0.4:
		return
	var rel := p - a.global_position
	var a_lo_largo := rel.x * a.sentido
	var lateral := rel.z
	if absf(lateral) > a.ancho / 2.0 + 0.35:
		return
	if a_lo_largo > a.largo / 2.0 and a_lo_largo < a.largo / 2.0 + 10.0 and a.velocidad > 3.0:
		if a.bocina_enfriamiento <= 0.0:
			a.bocina_enfriamiento = 4.0
			AudioManager.reproducir_en("bocina", a.global_position, -4.0)
		return
	if absf(a_lo_largo) <= a.largo / 2.0 + 0.3 and a.velocidad > 1.5:
		if GameState.invulnerable > 0.0 or GameState.partida_terminada or not j.has_method("empujar"):
			return
		GameState.invulnerable = 1.2
		var costado := signf(lateral) if absf(lateral) > 0.05 else 1.0
		j.empujar(Vector3(a.sentido * 0.8, 0, costado), 6.5)
		AudioManager.reproducir_en("bocina", a.global_position, 0.0)


## Las palomas sueltas que están en el camino de un auto vuelan un poquito y vuelven.
func _espantar_palomas() -> void:
	var palomas := get_tree().get_nodes_in_group("palomas_npc")
	for a in _autos:
		if a.velocidad < 1.0:
			continue
		var frente := a.trompa()
		for n in palomas:
			var p := n as PalomaNPC
			if p == null or p.modo != PalomaNPC.Modo.SUELTA:
				continue
			var pp := p.global_position
			if pp.y > 1.0 or absf(pp.z - a.global_position.z) > a.ancho / 2.0 + 0.8:
				continue
			var delante := (pp.x - frente) * a.sentido
			if delante > -a.largo and delante < 2.0 + a.velocidad * 0.35:
				p.espantar(a.global_position)
