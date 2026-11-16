class_name Transito
extends Node3D
## Tránsito de la ciudad: autos, taxis y colectivos que entran por un túnel al norte de Bolívar,
## bajan, doblan por la avenida del sur de la plaza (H. Yrigoyen, Z = 26..34, hacia el este por el
## carril sur) y salen por Paseo Colón hacia el túnel del sur; y los que hacen el camino al revés
## (suben por Paseo Colón, cruzan la avenida hacia el oeste por el carril norte y salen por Bolívar).
## Mano derecha. Las dos rutas no se cruzan nunca, así cada auto sólo mira al de adelante de su ruta.
## En la avenida hay dos cruces peatonales con semáforos que los hacen frenar.
## Los autos frenan ante el auto de adelante, el semáforo, las esquinas y la gente que cruza. A las
## palomas no las esperan: les tocan bocina, las sueltas se espantan y si te pisan quedás chata en el piso
## como en los dibujitos (ver PalomaJugador.aplastar).

const Z_CARRIL := {1: 32.0, -1: 28.0}    ## Carriles de la avenida
const CRUCES := [-40.5, 4.5]          ## X de cada senda peatonal (sin pisar las líneas del medio)
const ANCHO_CRUCE := 3.0
const T_VERDE := 13.0
const T_AMARILLO := 2.5
const T_ROJO := 8.0
const MAX_AUTOS := 22
const MAX_AUTOS_MOVIL := 14          ## En el teléfono, menos autos (cada uno son varios dibujos)
const Z_TUNEL := 165.0                ## Los autos aparecen y desaparecen adentro de los túneles

enum Luz { VERDE, AMARILLO, ROJO }

var luz: Luz = Luz.VERDE
var _t_luz := 0.0
var _autos: Array[Auto] = []
var _timer_salida := {1: 0.0, -1: 1.5}
var _timer_palomas := 0.0
var _lamparas: Array = []     ## [MeshInstance3D rojo, amarillo, verde] por semáforo
var _rutas := {}              ## sentido -> Curve3D (en coordenadas del mundo, con las esquinas redondeadas)
var _largo := {}              ## sentido -> largo de la ruta
var _lineas := {}             ## sentido -> distancias (sobre la ruta) de las líneas de frenado


func _ready() -> void:
	name = "Transito"
	_armar_rutas()
	for x: float in CRUCES:
		_armar_cruce(x)
	_mostrar_luz()
	# Sendas, postes y cabezales quedan fijos: se fusionan (las lámparas no, cambian de color)
	Construir.fusionar_estaticas(self)
	# Arranca con algunos autos ya andando
	for dir: int in [1, -1]:
		var d := randf_range(30.0, 60.0)
		while d < float(_largo[dir]) - 30.0 and _autos.size() < _max_autos():
			_crear_auto(dir, d)
			d += randf_range(28.0, 50.0)


# ---------------------------------------------------------------- Rutas

## Puntos de un arco (sin el primero) alrededor de "c" (x, z), de a0 a a1 grados.
static func _arco(c: Vector2, r: float, a0: float, a1: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in range(1, 9):
		var a := deg_to_rad(lerpf(a0, a1, k / 8.0))
		out.append(Vector3(c.x + r * cos(a), 0.0, c.y + r * sin(a)))
	return out


func _armar_rutas() -> void:
	var este: Array[Vector3] = [Vector3(-71.5, 0, -Z_TUNEL), Vector3(-71.5, 0, 28)]
	este.append_array(_arco(Vector2(-67.5, 28), 4.0, 180, 90))     # de Bolívar a la avenida
	este.append(Vector3(63.5, 0, 32))
	este.append_array(_arco(Vector2(63.5, 35), 3.0, -90, 0))       # de la avenida a Paseo Colón
	este.append(Vector3(66.5, 0, Z_TUNEL))
	var oeste: Array[Vector3] = [Vector3(71.5, 0, Z_TUNEL), Vector3(71.5, 0, 32)]
	oeste.append_array(_arco(Vector2(67.5, 32), 4.0, 0, -90))      # de Paseo Colón a la avenida
	oeste.append(Vector3(-63.5, 0, 28))
	oeste.append_array(_arco(Vector2(-63.5, 25), 3.0, 90, 180))    # de la avenida a Bolívar
	oeste.append(Vector3(-66.5, 0, -Z_TUNEL))
	for dir: int in [1, -1]:
		var c := Curve3D.new()
		c.bake_interval = 0.25
		for p: Vector3 in (este if dir == 1 else oeste):
			c.add_point(p)
		_rutas[dir] = c
		_largo[dir] = c.get_baked_length()
		var lineas: Array[float] = []
		for cx: float in CRUCES:
			lineas.append(c.get_closest_offset(Vector3(cx - dir * (ANCHO_CRUCE / 2.0 + 0.6), 0, Z_CARRIL[dir])))
		_lineas[dir] = lineas


## Pone al auto en su lugar de la ruta, mirando hacia donde va.
func _ubicar(a: Auto) -> void:
	var c: Curve3D = _rutas[int(a.sentido)]
	var largo: float = _largo[int(a.sentido)]
	var p := c.sample_baked(clampf(a.s, 0.0, largo))
	var q := c.sample_baked(clampf(a.s + 1.2, 0.0, largo))
	var r := c.sample_baked(clampf(a.s - 1.2, 0.0, largo))
	var dir := q - r
	if dir.length_squared() > 0.0001:
		a.rotation.y = atan2(-dir.z, dir.x)
	a.global_position = p + Vector3(0, 0.005, 0)


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
	Construir.cilindro(s, Vector3(0, y_base + 1.6, 0), 0.07, 3.2, Color("a9b1b6"), true, 6)
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


func _material_luz(color: Color, prendida: bool) -> Material:
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

func _max_autos() -> int:
	return MAX_AUTOS_MOVIL if Ajustes.movil else MAX_AUTOS


func _crear_auto(dir: int, s: float) -> Auto:
	var a := Auto.new()
	a.preparar(float(dir))
	a.s = s
	add_child(a)
	_ubicar(a)
	a.reset_physics_interpolation()
	_autos.append(a)
	return a


func _physics_process(delta: float) -> void:
	_avanzar_luz(delta)
	_salidas(delta)
	var jugador := GameState.jugador
	# Sólo importa la gente que está sobre la avenida o las dos calles (casi nunca hay nadie):
	# se filtra una vez acá y no por cada auto
	var gente: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("cuerpos_humanos"):
		var h := n as Node3D
		if h == null or not h.is_visible_in_tree():
			continue
		var p := h.global_position
		if absf(p.z - 30.0) < 6.0 or absf(absf(p.x) - 69.0) < 6.5:
			gente.append(h)
	for dir: int in [1, -1]:
		var ruta: Array[Auto] = []
		for a in _autos:
			if is_instance_valid(a) and int(a.sentido) == dir:
				ruta.append(a)
		# De adelante hacia atrás
		ruta.sort_custom(func(p: Auto, q: Auto) -> bool: return p.s > q.s)
		for i in ruta.size():
			var a := ruta[i]
			var adelante: Auto = ruta[i - 1] if i > 0 else null
			_conducir(a, adelante, delta, gente)
			if jugador:
				_revisar_jugador(a, jugador, delta)
	_timer_palomas -= delta
	if _timer_palomas <= 0.0:
		_timer_palomas = 0.2
		_espantar_palomas()
	# Los que llegaron al túnel desaparecen
	for a in _autos.duplicate():
		if a.s >= float(_largo[int(a.sentido)]) - 0.5:
			_autos.erase(a)
			a.queue_free()


func _salidas(delta: float) -> void:
	for dir: int in [1, -1]:
		_timer_salida[dir] -= delta
		if _timer_salida[dir] > 0.0 or _autos.size() >= _max_autos():
			continue
		# Que no aparezca encima del último que salió
		var libre := true
		for a in _autos:
			if int(a.sentido) == dir and a.s < 14.0:
				libre = false
				break
		if libre:
			_crear_auto(dir, 0.0)
			_timer_salida[dir] = randf_range(2.5, 6.5)


func _conducir(a: Auto, adelante: Auto, delta: float, gente: Array[Node3D]) -> void:
	var dir := int(a.sentido)
	var deseada := a.velocidad_crucero
	var frente := a.s + a.largo / 2.0
	# Distancia al de adelante
	if adelante:
		var hueco := adelante.s - adelante.largo / 2.0 - frente
		deseada = minf(deseada, maxf((hueco - 2.0) * 1.4, 0.0))
	# Esquinas: doblan más despacio
	var c: Curve3D = _rutas[dir]
	var largo: float = _largo[dir]
	var tramo := c.sample_baked(minf(a.s + 9.0, largo)) - c.sample_baked(minf(a.s + 3.0, largo))
	if tramo.length_squared() > 0.01 and tramo.normalized().dot(a.adelante()) < 0.9:
		deseada = minf(deseada, 5.5)
	# Semáforo: frena antes de la línea si está en rojo, o en amarillo si le da para frenar
	if luz != Luz.VERDE:
		for linea: float in _lineas[dir]:
			var dist := linea - frente
			if dist < -0.3 or dist > 45.0:
				continue
			var frenado := a.velocidad * a.velocidad / (2.0 * 6.0)
			if luz == Luz.ROJO or dist > frenado:
				deseada = minf(deseada, maxf(dist - 0.2, 0.0) * 1.2)
	# Gente cruzando delante
	var fw := a.adelante()
	var lado := Vector3(-fw.z, 0, fw.x)
	for h: Node3D in gente:
		var rel := h.global_position - a.global_position
		var delante := rel.dot(fw) - a.largo / 2.0
		if delante > -0.5 and delante < 9.0 and absf(rel.dot(lado)) < a.ancho / 2.0 + 0.5:
			deseada = minf(deseada, maxf(delante - 1.5, 0.0))
	var acel := 3.5 if deseada > a.velocidad else 9.0
	a.velocidad = move_toward(a.velocidad, deseada, acel * delta)
	a.s += a.velocidad * delta
	_ubicar(a)
	a.bocina_enfriamiento = maxf(a.bocina_enfriamiento - delta, 0.0)


## Bocinazo si la paloma está en el carril adelante; si la toca, la manda a volar (sin perder palomas).
func _revisar_jugador(a: Auto, j: Node3D, _delta: float) -> void:   # _delta: lo usa el paseo sobre el techo
	var p := j.global_position
	if p.y > a.alto + 0.4:
		return
	var rel := p - a.global_position
	var fw := a.adelante()
	var lado := Vector3(-fw.z, 0, fw.x)
	var a_lo_largo := rel.dot(fw)
	var lateral := rel.dot(lado)
	if absf(lateral) > a.ancho / 2.0 + 0.35:
		return
	# Posada sobre el techo o el capó: el auto no la pisa y la lleva de paseo
	if rel.y > 0.6 and j is PalomaJugador and absf(a_lo_largo) <= a.largo / 2.0 + 0.2:
		var pj := j as PalomaJugador
		if pj.estado == PalomaJugador.Estado.SUELO and pj.get_platform_velocity().length() < 0.1:
			pj.global_position += fw * a.velocidad * _delta
		return
	if a_lo_largo > a.largo / 2.0 and a_lo_largo < a.largo / 2.0 + 10.0 and a.velocidad > 3.0:
		if a.bocina_enfriamiento <= 0.0:
			a.bocina_enfriamiento = 4.0
			AudioManager.reproducir_en("bocina", a.global_position, -4.0)
		return
	if absf(a_lo_largo) <= a.largo / 2.0 + 0.3 and a.velocidad > 1.5:
		if GameState.invulnerable > 0.0 or GameState.partida_terminada or not j.has_method("aplastar"):
			return
		# La deja chata en el piso (el auto le pasa por encima) y después se infla de nuevo
		GameState.invulnerable = PalomaJugador.DURACION_APLASTADA + 1.0
		j.aplastar()
		AudioManager.reproducir_en("bocina", a.global_position, 0.0)


## Las palomas sueltas que están en el camino de un auto vuelan un poquito y vuelven.
func _espantar_palomas() -> void:
	var palomas := get_tree().get_nodes_in_group("palomas_npc")
	for a in _autos:
		if a.velocidad < 1.0:
			continue
		var fw := a.adelante()
		var lado := Vector3(-fw.z, 0, fw.x)
		for n in palomas:
			var p := n as PalomaNPC
			if p == null or p.modo != PalomaNPC.Modo.SUELTA:
				continue
			var rel := p.global_position - a.global_position
			if rel.y > 1.0 or absf(rel.dot(lado)) > a.ancho / 2.0 + 0.8:
				continue
			var delante := rel.dot(fw) - a.largo / 2.0
			if delante > -a.largo and delante < 2.0 + a.velocidad * 0.35:
				p.espantar(a.global_position)
