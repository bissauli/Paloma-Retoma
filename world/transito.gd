class_name Transito
extends Node3D
## Tránsito de la ciudad: autos, taxis, patrulleros y colectivos por todas las calles con calzada: Bolívar y
## Paseo Colón (norte-sur, con túneles en los extremos), la avenida del sur de la plaza (H. Yrigoyen, con
## semáforos), Rivadavia al norte, la Av. de Mayo (oeste) y Reconquista (este, con túneles en los extremos).
## Mano derecha. Cada auto sigue una RUTA (una curva con esquinas redondeadas, ver _definir_rutas): unas
## cruzan todo derecho y otras doblan de una calle a otra.
## - Siguen al auto de adelante (por geometría, así sirve aunque vengan de otra ruta por el mismo carril) y
##   frenan ante cualquier auto que les cruce cerca.
## - Cruces: al armarse, se buscan solos los puntos donde dos rutas se cortan (con ángulo, no si van parejas)
##   y cada uno es un "cruce" con turno: pasa un grupo (la misma ruta, de a 4 autos como mucho) y los demás
##   esperan antes de la línea. Si un auto lleva más de 14 s parado, se destraba pasando igual.
## - En la avenida hay dos sendas peatonales con semáforos que hacen frenar a sus autos; todos frenan
##   también ante la gente que cruza.
## A las palomas no las esperan: les tocan bocina, las sueltas se espantan y si te pisan quedás chata en el
## piso como en los dibujitos (ver PalomaJugador.aplastar). Si estás posada en un auto, te lleva.

const Z_CARRIL := {1: 32.0, -1: 28.0}    ## Carriles de la avenida
const CRUCES := [-40.5, 4.5]          ## X de cada senda peatonal (sin pisar las líneas del medio)
const ANCHO_CRUCE := 3.0
const T_VERDE := 13.0
const T_AMARILLO := 2.5
const T_ROJO := 8.0
const MAX_AUTOS := 34
const MAX_AUTOS_MOVIL := 18           ## En el teléfono, menos autos (cada uno son varios dibujos)
const Z_TUNEL := 165.0                ## Los autos aparecen y desaparecen adentro de los túneles
const X_TUNEL := 203.0
const RADIO_CRUCE := 5.5              ## Mitad del largo del cruce, medida sobre cada ruta
const ESPERA_MAX := 14.0

enum Luz { VERDE, AMARILLO, ROJO }

var luz: Luz = Luz.VERDE
var _t_luz := 0.0
var _autos: Array[Auto] = []
var _timer_salida := 0.0
var _timer_palomas := 0.0
var _lamparas: Array = []     ## [MeshInstance3D rojo, amarillo, verde] por semáforo
## Rutas: {nombre, curva: Curve3D, largo, peso, lineas: Array[float] (semáforos, sólo la avenida), entradas}
var _rutas: Array[Dictionary] = []
## Cruces: {centro: Vector3, ruta: int (el grupo que pasa, -1 libre), autos: Array[Auto], usos: int}
var _cruces: Array[Dictionary] = []
var _peso_total := 0.0


func _ready() -> void:
	name = "Transito"
	_definir_rutas()
	_detectar_cruces()
	for x: float in CRUCES:
		_armar_cruce(x)
	_mostrar_luz()
	# Sendas, postes y cabezales quedan fijos: se fusionan (las lámparas no, cambian de color)
	Construir.fusionar_estaticas(self)
	# Arranca con algunos autos ya andando
	for i in _rutas.size():
		var d := randf_range(25.0, 70.0)
		while d < float(_rutas[i]["largo"]) - 30.0 and _autos.size() < int(_max_autos() * 0.8):
			_crear_auto(i, d)
			d += randf_range(45.0, 90.0)


# ---------------------------------------------------------------- Rutas

## Puntos de un arco (sin el primero) alrededor de "c" (x, z), de a0 a a1 grados.
static func _arco(c: Vector2, r: float, a0: float, a1: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in range(1, 9):
		var a := deg_to_rad(lerpf(a0, a1, k / 8.0))
		out.append(Vector3(c.x + r * cos(a), 0.0, c.y + r * sin(a)))
	return out


func _ruta(nombre: String, pts: Array[Vector3], peso: float, avenida := 0) -> void:
	var c := Curve3D.new()
	c.bake_interval = 0.25
	for p: Vector3 in pts:
		c.add_point(p)
	var lineas: Array[float] = []
	if avenida != 0:
		for cx: float in CRUCES:
			lineas.append(c.get_closest_offset(Vector3(cx - avenida * (ANCHO_CRUCE / 2.0 + 0.6), 0, Z_CARRIL[avenida])))
	_rutas.append({"nombre": nombre, "curva": c, "largo": c.get_baked_length(), "peso": peso,
		"lineas": lineas, "entradas": [], "inicio": pts[0]})
	_peso_total += peso


func _definir_rutas() -> void:
	var Z := Z_TUNEL
	var X := X_TUNEL
	# Avenida: de Bolívar al este (y sale por Paseo Colón al sur) y el camino de vuelta
	var este: Array[Vector3] = [Vector3(-71.5, 0, -Z), Vector3(-71.5, 0, 28)]
	este.append_array(_arco(Vector2(-67.5, 28), 4.0, 180, 90))
	este.append(Vector3(63.5, 0, 32))
	este.append_array(_arco(Vector2(63.5, 35), 3.0, -90, 0))
	este.append(Vector3(66.5, 0, Z))
	_ruta("avenida_este", este, 3.0, 1)
	var oeste: Array[Vector3] = [Vector3(71.5, 0, Z), Vector3(71.5, 0, 32)]
	oeste.append_array(_arco(Vector2(67.5, 32), 4.0, 0, -90))
	oeste.append(Vector3(-63.5, 0, 28))
	oeste.append_array(_arco(Vector2(-63.5, 25), 3.0, 90, 180))
	oeste.append(Vector3(-66.5, 0, -Z))
	_ruta("avenida_oeste", oeste, 3.0, -1)
	# Derecho por Bolívar y por Paseo Colón
	_ruta("bolivar_sur", [Vector3(-71.5, 0, -Z), Vector3(-71.5, 0, Z)], 1.5)
	_ruta("bolivar_norte", [Vector3(-66.5, 0, Z), Vector3(-66.5, 0, -Z)], 1.5)
	_ruta("colon_sur", [Vector3(66.5, 0, -Z), Vector3(66.5, 0, Z)], 1.5)
	_ruta("colon_norte", [Vector3(71.5, 0, Z), Vector3(71.5, 0, -Z)], 1.5)
	# Rivadavia: se entra por Bolívar hacia el este y se sale por Paseo Colón; y al revés
	var riv_e: Array[Vector3] = [Vector3(-71.5, 0, -Z), Vector3(-71.5, 0, -51.5)]
	riv_e.append_array(_arco(Vector2(-65.5, -51.5), 6.0, 180, 90))
	riv_e.append(Vector3(60.5, 0, -45.5))
	riv_e.append_array(_arco(Vector2(60.5, -39.5), 6.0, -90, 0))
	riv_e.append(Vector3(66.5, 0, Z))
	_ruta("rivadavia_este", riv_e, 1.5)
	var riv_o: Array[Vector3] = [Vector3(71.5, 0, Z), Vector3(71.5, 0, -44.5)]
	riv_o.append_array(_arco(Vector2(65.5, -44.5), 6.0, 0, -90))
	riv_o.append(Vector3(-60.5, 0, -50.5))
	riv_o.append_array(_arco(Vector2(-60.5, -56.5), 6.0, 90, 180))
	riv_o.append(Vector3(-66.5, 0, -Z))
	_ruta("rivadavia_oeste", riv_o, 1.5)
	# Av. de Mayo (oeste de Bolívar): entra por el túnel del oeste y sale hacia el sur; sale por el túnel
	# viniendo de Bolívar, de frente o doblando a la derecha
	var mayo_e: Array[Vector3] = [Vector3(-X, 0, 0.5), Vector3(-77.5, 0, 0.5)]
	mayo_e.append_array(_arco(Vector2(-77.5, 6.5), 6.0, -90, 0))
	mayo_e.append(Vector3(-71.5, 0, Z))
	_ruta("mayo_entra", mayo_e, 1.0)
	var mayo_o1: Array[Vector3] = [Vector3(-66.5, 0, Z), Vector3(-66.5, 0, 1.5)]
	mayo_o1.append_array(_arco(Vector2(-72.5, 1.5), 6.0, 0, -90))
	mayo_o1.append(Vector3(-X, 0, -4.5))
	_ruta("mayo_sale_norte", mayo_o1, 1.0)
	var mayo_o2: Array[Vector3] = [Vector3(-71.5, 0, -Z), Vector3(-71.5, 0, -10.5)]
	mayo_o2.append_array(_arco(Vector2(-77.5, -10.5), 6.0, 0, 90))
	mayo_o2.append(Vector3(-X, 0, -4.5))
	_ruta("mayo_sale_sur", mayo_o2, 1.0)
	# Reconquista (este de Paseo Colón): lo mismo espejado
	var rec_e: Array[Vector3] = [Vector3(X, 0, -8.5), Vector3(77.5, 0, -8.5)]
	rec_e.append_array(_arco(Vector2(77.5, -14.5), 6.0, 90, 180))
	rec_e.append(Vector3(71.5, 0, -Z))
	_ruta("reconquista_entra", rec_e, 1.0)
	var rec_o1: Array[Vector3] = [Vector3(66.5, 0, -Z), Vector3(66.5, 0, -9.5)]
	rec_o1.append_array(_arco(Vector2(72.5, -9.5), 6.0, 180, 90))
	rec_o1.append(Vector3(X, 0, -3.5))
	_ruta("reconquista_sale_sur", rec_o1, 1.0)
	var rec_o2: Array[Vector3] = [Vector3(71.5, 0, Z), Vector3(71.5, 0, 2.5)]
	rec_o2.append_array(_arco(Vector2(77.5, 2.5), 6.0, 180, 270))
	rec_o2.append(Vector3(X, 0, -3.5))
	_ruta("reconquista_sale_norte", rec_o2, 1.0)


## Busca solos los puntos donde dos rutas se cortan (cerca y con ángulo: las que van parejas, por el mismo
## carril, no cuentan) y arma un cruce con turno en cada uno.
func _detectar_cruces() -> void:
	var celdas := {}     # Vector2i (celda de 4 m) -> Array de [ruta, posición (x, z), tangente]
	for r in _rutas.size():
		var c: Curve3D = _rutas[r]["curva"]
		var largo: float = _rutas[r]["largo"]
		var s := 0.0
		while s <= largo:
			var p := c.sample_baked(s)
			var q := c.sample_baked(minf(s + 1.0, largo))
			var t := Vector2(q.x - p.x, q.z - p.z)
			if t.length_squared() > 0.0001:
				var k := Vector2i(floori(p.x / 4.0), floori(p.z / 4.0))
				if not celdas.has(k):
					celdas[k] = []
				(celdas[k] as Array).append([r, Vector2(p.x, p.z), t.normalized()])
			s += 1.5
	var grupos := {}     # Vector2i (celda de 12 m) -> {suma: Vector2, n: int, rutas: {ruta: true}}
	for k: Vector2i in celdas:
		for a: Array in celdas[k]:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var vecina := Vector2i(k.x + dx, k.y + dz)
					if not celdas.has(vecina):
						continue
					for b: Array in celdas[vecina]:
						if int(a[0]) >= int(b[0]):
							continue
						var pa: Vector2 = a[1]
						var pb: Vector2 = b[1]
						if pa.distance_to(pb) > 3.2 or absf((a[2] as Vector2).dot(b[2])) > 0.75:
							continue
						var medio := (pa + pb) / 2.0
						var g := Vector2i(floori(medio.x / 12.0), floori(medio.y / 12.0))
						if not grupos.has(g):
							grupos[g] = {"suma": Vector2.ZERO, "n": 0, "rutas": {}}
						grupos[g]["suma"] = (grupos[g]["suma"] as Vector2) + medio
						grupos[g]["n"] = int(grupos[g]["n"]) + 1
						grupos[g]["rutas"][int(a[0])] = true
						grupos[g]["rutas"][int(b[0])] = true
	# Los grupos que quedaron a menos de 9 m se juntan en uno
	var lista: Array[Dictionary] = []
	for g: Vector2i in grupos:
		var d: Dictionary = grupos[g]
		lista.append({"centro": (d["suma"] as Vector2) / float(d["n"]), "rutas": d["rutas"]})
	var i := 0
	while i < lista.size():
		var j := i + 1
		while j < lista.size():
			if (lista[i]["centro"] as Vector2).distance_to(lista[j]["centro"]) < 9.0:
				lista[i]["centro"] = ((lista[i]["centro"] as Vector2) + (lista[j]["centro"] as Vector2)) / 2.0
				for r: int in lista[j]["rutas"]:
					lista[i]["rutas"][r] = true
				lista.remove_at(j)
				j = i + 1
			else:
				j += 1
		i += 1
	for l in lista:
		var centro := Vector3((l["centro"] as Vector2).x, 0.0, (l["centro"] as Vector2).y)
		_cruces.append({"centro": centro, "ruta": -1, "autos": [], "usos": 0})
		var id := _cruces.size() - 1
		for r: int in l["rutas"]:
			var c: Curve3D = _rutas[r]["curva"]
			(_rutas[r]["entradas"] as Array).append({"cruce": id, "s": c.get_closest_offset(centro)})


## Pone al auto en su lugar de la ruta, mirando hacia donde va.
func _ubicar(a: Auto) -> void:
	var c: Curve3D = _rutas[a.ruta]["curva"]
	var largo: float = _rutas[a.ruta]["largo"]
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


## ¿No hay ningún auto a menos de "radio" metros de ese punto?
func _lugar_libre(pos: Vector3, radio: float) -> bool:
	for a in _autos:
		if is_instance_valid(a) and a.global_position.distance_to(pos) < radio:
			return false
	return true


func _crear_auto(ruta: int, s: float) -> Auto:
	var c: Curve3D = _rutas[ruta]["curva"]
	if not _lugar_libre(c.sample_baked(s), 10.0):
		return null
	var a := Auto.new()
	a.preparar(1.0)
	a.ruta = ruta
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
	# Sólo importa la gente que está sobre alguna calzada (casi nunca hay nadie): se filtra una vez acá
	# y no por cada auto
	var gente: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("cuerpos_humanos"):
		var h := n as Node3D
		if h == null or not h.is_visible_in_tree():
			continue
		var p := h.global_position
		if absf(p.z - 30.0) < 6.0 or absf(absf(p.x) - 69.0) < 6.5 or absf(p.z + 48.0) < 6.5 \
				or (absf(p.x) > 70.0 and p.z > -13.0 and p.z < 5.0):
			gente.append(h)
	for a in _autos:
		if not is_instance_valid(a):
			continue
		_conducir(a, delta, gente)
		if jugador:
			_revisar_jugador(a, jugador, delta)
	_timer_palomas -= delta
	if _timer_palomas <= 0.0:
		_timer_palomas = 0.2
		_espantar_palomas()
	# Los que llegaron al túnel desaparecen
	for a in _autos.duplicate():
		if a.s >= float(_rutas[a.ruta]["largo"]) - 0.5:
			_soltar_cruces(a)
			_autos.erase(a)
			a.queue_free()


func _soltar_cruces(a: Auto) -> void:
	for cr in _cruces:
		var autos: Array = cr["autos"]
		if autos.has(a):
			autos.erase(a)
			if autos.is_empty():
				cr["ruta"] = -1
				cr["usos"] = 0


func _salidas(delta: float) -> void:
	_timer_salida -= delta
	if _timer_salida > 0.0 or _autos.size() >= _max_autos():
		return
	_timer_salida = randf_range(0.9, 2.4)
	# Una ruta al azar (con más peso las de la avenida), si su entrada está libre
	var dado := randf() * _peso_total
	for i in _rutas.size():
		dado -= float(_rutas[i]["peso"])
		if dado <= 0.0:
			_crear_auto(i, 0.0)
			return


func _conducir(a: Auto, delta: float, gente: Array[Node3D]) -> void:
	var r: Dictionary = _rutas[a.ruta]
	var deseada := a.velocidad_crucero
	var frente := a.s + a.largo / 2.0
	var fw := a.adelante()
	var lado := Vector3(-fw.z, 0, fw.x)
	var destrabar := a.espera > ESPERA_MAX
	# Otros autos: al de adelante (aunque sea de otra ruta, por el mismo carril) se lo sigue; a los que cruzan
	# muy cerca se les frena
	for b in _autos:
		if b == a or not is_instance_valid(b):
			continue
		var rel := b.global_position - a.global_position
		var d := rel.dot(fw)
		if d <= 0.0 or d > 30.0:
			continue
		var lat := absf(rel.dot(lado))
		var hueco := d - (a.largo + b.largo) / 2.0
		var paralelo := fw.dot(b.adelante())
		if paralelo > 0.5:
			if lat < 1.9:
				deseada = minf(deseada, maxf((hueco - 2.0) * 1.4, 0.0))
		elif not destrabar and paralelo > -0.5 and lat < 2.4 and hueco < 4.5:
			deseada = minf(deseada, maxf(hueco - 1.0, 0.0) * 1.2)
	# Esquinas: doblan más despacio
	var c: Curve3D = r["curva"]
	var largo: float = r["largo"]
	var tramo := c.sample_baked(minf(a.s + 9.0, largo)) - c.sample_baked(minf(a.s + 3.0, largo))
	if tramo.length_squared() > 0.01 and tramo.normalized().dot(fw) < 0.9:
		deseada = minf(deseada, 5.5)
	# Semáforo (sólo los de la avenida): frena antes de la línea si está en rojo, o en amarillo si le da
	if luz != Luz.VERDE:
		for linea: float in r["lineas"]:
			var dist := linea - frente
			if dist < -0.3 or dist > 45.0:
				continue
			var frenado := a.velocidad * a.velocidad / (2.0 * 6.0)
			if luz == Luz.ROJO or dist > frenado:
				deseada = minf(deseada, maxf(dist - 0.2, 0.0) * 1.2)
	# Cruces con otras calles: se pide turno antes de la línea
	for e: Dictionary in r["entradas"]:
		var cr: Dictionary = _cruces[int(e["cruce"])]
		var autos: Array = cr["autos"]
		var s_cruce: float = e["s"]
		var atras := a.s - a.largo / 2.0
		if atras >= s_cruce + RADIO_CRUCE:
			if autos.has(a):
				autos.erase(a)
				if autos.is_empty():
					cr["ruta"] = -1
					cr["usos"] = 0
			continue
		if autos.has(a):
			continue
		var dist_linea := (s_cruce - RADIO_CRUCE) - frente
		if dist_linea <= 0.0:
			# Ya está adentro (no llegó a frenar): entra igual
			autos.append(a)
			cr["ruta"] = a.ruta
			continue
		if dist_linea < 14.0:
			var libre := autos.is_empty() or (int(cr["ruta"]) == a.ruta and int(cr["usos"]) < 4)
			if libre or destrabar:
				autos.append(a)
				cr["ruta"] = a.ruta
				cr["usos"] = int(cr["usos"]) + 1
			else:
				deseada = minf(deseada, maxf(dist_linea - 0.3, 0.0) * 1.2)
	# Gente cruzando delante
	for h: Node3D in gente:
		var rel := h.global_position - a.global_position
		var delante := rel.dot(fw) - a.largo / 2.0
		if delante > -0.5 and delante < 9.0 and absf(rel.dot(lado)) < a.ancho / 2.0 + 0.5:
			deseada = minf(deseada, maxf(delante - 1.5, 0.0))
	var acel := 3.5 if deseada > a.velocidad else 9.0
	a.velocidad = move_toward(a.velocidad, deseada, acel * delta)
	a.espera = a.espera + delta if a.velocidad < 0.3 else 0.0
	a.s += a.velocidad * delta
	_ubicar(a)
	a.bocina_enfriamiento = maxf(a.bocina_enfriamiento - delta, 0.0)


## Bocinazo si la paloma está en el carril adelante; si la toca, la manda a volar (sin perder palomas).
func _revisar_jugador(a: Auto, j: Node3D, delta: float) -> void:
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
			pj.global_position += fw * a.velocidad * delta
			if a.velocidad > 1.5:
				Logros.sumar("tiempo_auto", delta)
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
