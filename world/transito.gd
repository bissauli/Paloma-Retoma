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
##   y cada uno es un "cruce". Para cada ruta se mide qué tramo pisa el camino de otra (la zona de choque) y
##   con qué rutas se choca: las que no se tocan (las dos manos de Bolívar, las que llegan por el mismo carril
##   y se separan) pasan a la vez. Un auto entra si nadie de una ruta que lo choque está adentro, si hay lugar
##   del otro lado para no quedar parado adentro (no "tapar el cruce") y si no hay alguien de una ruta que lo
##   choque esperando desde antes (más de GRACIA_TURNO s: así pasan de a tandas y nadie espera para siempre).
##   Sólo pide turno el primero de cada carril: el de atrás no le puede ganar el cruce al de adelante (antes
##   pasaba y quedaban trabados los dos). Si un auto lleva más de 14 s parado deja de respetar la fila; a
##   los 30 s pasa igual.
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
const VENTANA_CRUCE := 14.0           ## Cuánto de cada ruta se mira alrededor del centro de un cruce
## Media carrocería (largo, ancho) con un poco de margen: auto (hasta 4,4 x 1,8 m) y colectivo (11 x 2,5 m)
const MEDIDAS := [Vector2(2.5, 1.15), Vector2(5.8, 1.4)]
const MARGEN_LINEA := 1.0             ## La línea de espera queda esto antes de la zona de choque
const TRAMO_LIBRE := 40.0             ## Lugar que hace falta del otro lado, como mucho (ver _lugar_despues)
const GRACIA_TURNO := 3.0             ## Quien espera turno frena a los que llegan después pasados estos segundos
const ESPERA_MAX := 14.0              ## Parado más que esto, deja de respetar la fila del cruce
const ESPERA_FORZAR := 30.0           ## Parado más que esto, pasa igual (último recurso)

enum Luz { VERDE, AMARILLO, ROJO }

var luz: Luz = Luz.VERDE
var _t_luz := 0.0
var _autos: Array[Auto] = []
var _timer_salida := 0.0
var _timer_palomas := 0.0
var _lamparas: Array = []     ## [MeshInstance3D rojo, amarillo, verde] por semáforo
## Rutas: {nombre, curva: Curve3D, largo, peso, lineas: Array[float] (semáforos, sólo la avenida), entradas}
var _rutas: Array[Dictionary] = []
## Cruces: {centro: Vector3, autos: Array[Auto] (los que están adentro), pedidos: {Auto: {t, listo}} (los que
## esperan turno: desde cuándo y si tienen lugar para cruzar), choques: {Vector2i(ruta, ruta): true}}.
## Cada ruta tiene sus "entradas", en orden: {cruce, tramos: [Vector2(s_in, s_out) de un auto, ídem de un
## colectivo]} (el tramo de la ruta que pisa el camino de otra, en posiciones del centro del vehículo).
var _cruces: Array[Dictionary] = []
var _peso_total := 0.0
var _tiempo := 0.0


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
	# En cada cruce: qué rutas se chocan y qué tramo de cada una pisa el camino de otra. Entran todas las
	# que pasan cerca, no sólo las que se cortan: un colectivo que dobla barre la mano de al lado.
	for l in lista:
		var centro := Vector3((l["centro"] as Vector2).x, 0.0, (l["centro"] as Vector2).y)
		var rutas := []
		var muestras := {}
		for r in _rutas.size():
			var c: Curve3D = _rutas[r]["curva"]
			if c.get_closest_point(centro).distance_to(centro) < VENTANA_CRUCE - 2.0:
				rutas.append(r)
				muestras[r] = _muestras(r, c.get_closest_offset(centro))
		var tramos := {}     # ruta -> [Vector2(s_in, s_out) de un auto, ídem de un colectivo]
		var choques := {}
		for ia in rutas.size():
			for ib in range(ia + 1, rutas.size()):
				var ra: int = rutas[ia]
				var rb: int = rutas[ib]
				var ch := _choque(ra, muestras[ra], rb, muestras[rb])
				if ch.is_empty():
					continue
				choques[_par(ra, rb)] = true
				for rr: int in ch:
					var antes: Array = tramos.get(rr, [Vector2(INF, -INF), Vector2(INF, -INF)])
					var nuevo: Array = ch[rr]
					tramos[rr] = [_unir(antes[0], nuevo[0]), _unir(antes[1], nuevo[1])]
		if choques.is_empty():
			continue
		_cruces.append({"centro": centro, "autos": [], "pedidos": {}, "choques": choques})
		var id := _cruces.size() - 1
		for r: int in tramos:
			(_rutas[r]["entradas"] as Array).append({"cruce": id, "tramos": tramos[r]})
	# Las entradas de cada ruta en el orden en que se encuentran (ver _cadena)
	for ruta in _rutas:
		(ruta["entradas"] as Array).sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
			return (x["tramos"][1] as Vector2).x < (y["tramos"][1] as Vector2).x)


static func _par(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _unir(a: Vector2, b: Vector2) -> Vector2:
	return Vector2(minf(a.x, b.x), maxf(a.y, b.y))


## 0 para los autos (taxis, patrulleros), 1 para los colectivos: qué tramo de cada entrada les toca.
static func _tipo(a: Auto) -> int:
	return 1 if a.tipo == "colectivo" else 0


## Cómo queda un vehículo con el centro en "s" de la ruta: [posición, dirección]. Lo usan _ubicar y la
## búsqueda de choques de los cruces (tiene que ser lo mismo).
func _pose(ruta: int, s: float) -> Array:
	var c: Curve3D = _rutas[ruta]["curva"]
	var largo: float = _rutas[ruta]["largo"]
	var dir := c.sample_baked(clampf(s + 1.2, 0.0, largo)) - c.sample_baked(clampf(s - 1.2, 0.0, largo))
	return [c.sample_baked(clampf(s, 0.0, largo)), dir]


## Poses de la ruta "r" alrededor de "s0", cada metro: [s, posición (x, z), dirección].
func _muestras(r: int, s0: float) -> Array:
	var largo: float = _rutas[r]["largo"]
	var out := []
	var s := maxf(s0 - VENTANA_CRUCE, 0.0)
	while s <= minf(s0 + VENTANA_CRUCE, largo):
		var pose := _pose(r, s)
		var p: Vector3 = pose[0]
		var d: Vector3 = pose[1]
		out.append([s, Vector2(p.x, p.z), Vector2(d.x, d.z).normalized()])
		s += 1.0
	return out


## Tramos de las rutas "ra" y "rb" que se chocan, para cada tipo de vehículo: {ra: [auto, colectivo],
## rb: [auto, colectivo]}, cada uno un Vector2(s_in, s_out) con posiciones del centro del vehículo (INF si
## ese tipo no la pisa), o vacío si no se tocan. Cada vehículo se mide contra un colectivo de la otra ruta
## (lo más grande que puede venir), con las carrocerías giradas como van en cada punto: en las esquinas
## barren bastante más que el ancho del carril. Ir por el mismo carril uno detrás del otro no es chocar (de
## eso se encarga seguir al de adelante), y dos rutas que llegan por el mismo carril y después se separan
## tampoco se chocan.
func _choque(ra: int, ma: Array, rb: int, mb: Array) -> Dictionary:
	if _en_ruta(ma[0], rb) and _en_ruta(mb[0], ra):
		return {}
	var chico: Vector2 = MEDIDAS[0]
	var grande: Vector2 = MEDIDAS[1]
	var lejos := 4.0 * grande.length_squared()
	var vacio := Vector2(INF, -INF)
	var ta := [vacio, vacio]
	var tb := [vacio, vacio]
	var hay := false
	for a: Array in ma:
		var sa: float = a[0]
		var pa: Vector2 = a[1]
		var fa: Vector2 = a[2]
		for b: Array in mb:
			var d: Vector2 = b[1] - pa
			if d.length_squared() > lejos:
				continue
			var fb: Vector2 = b[2]
			if fa.dot(fb) > 0.95 and absf(d.dot(fa.orthogonal())) < 1.0:
				continue   # Mismo carril, mismo sentido
			if not _se_pisan(d, fa, grande, fb, grande):
				continue
			var sb: float = b[0]
			hay = true
			ta[1] = _unir(ta[1], Vector2(sa, sa))
			tb[1] = _unir(tb[1], Vector2(sb, sb))
			if _se_pisan(d, fa, chico, fb, grande):
				ta[0] = _unir(ta[0], Vector2(sa, sa))
			if _se_pisan(d, fa, grande, fb, chico):
				tb[0] = _unir(tb[0], Vector2(sb, sb))
	return {ra: ta, rb: tb} if hay else {}


## Dos carrocerías (en planta) separadas por "d", mirando hacia "fa" y "fb", con medio largo y medio ancho
## "ma" y "mb": ¿se pisan? (ejes separadores)
static func _se_pisan(d: Vector2, fa: Vector2, ma: Vector2, fb: Vector2, mb: Vector2) -> bool:
	var la := fa.orthogonal()
	var lb := fb.orthogonal()
	for eje: Vector2 in [fa, la, fb, lb]:
		var r := ma.x * absf(fa.dot(eje)) + ma.y * absf(la.dot(eje)) + mb.x * absf(fb.dot(eje)) + mb.y * absf(lb.dot(eje))
		if absf(d.dot(eje)) > r:
			return false
	return true


## ¿El punto de muestra "m" está sobre el camino de la ruta "r", yendo para el mismo lado?
func _en_ruta(m: Array, r: int) -> bool:
	var c: Curve3D = _rutas[r]["curva"]
	var largo: float = _rutas[r]["largo"]
	var p: Vector2 = m[1]
	var s := c.get_closest_offset(Vector3(p.x, 0.0, p.y))
	var q := c.sample_baked(s)
	var d := c.sample_baked(minf(s + 0.5, largo)) - c.sample_baked(maxf(s - 0.5, 0.0))
	return Vector2(q.x, q.z).distance_to(p) < 0.6 and Vector2(d.x, d.z).normalized().dot(m[2]) > 0.95


## Pone al auto en su lugar de la ruta, mirando hacia donde va.
func _ubicar(a: Auto) -> void:
	var pose := _pose(a.ruta, a.s)
	var dir: Vector3 = pose[1]
	if dir.length_squared() > 0.0001:
		a.rotation.y = atan2(-dir.z, dir.x)
	a.global_position = (pose[0] as Vector3) + Vector3(0, 0.005, 0)


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
	# Los que arrancan ya andando no aparecen adentro de un cruce (ni pegados a la línea)
	for e: Dictionary in _rutas[ruta]["entradas"]:
		var t: Vector2 = e["tramos"][1]
		if s > t.x - 12.0 and s < t.y + 8.0:
			return null
	var a := Auto.new()
	a.preparar(1.0)
	# Lugar para su largo y el del más largo que pueda tener al lado (antes un colectivo nacía encima de otro)
	if not _lugar_libre(c.sample_baked(s), a.largo / 2.0 + (MEDIDAS[1] as Vector2).x + 1.5):
		a.free()
		return null
	a.ruta = ruta
	a.s = s
	add_child(a)
	_ubicar(a)
	a.reset_physics_interpolation()
	_autos.append(a)
	return a


func _physics_process(delta: float) -> void:
	_tiempo += delta
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
		(cr["autos"] as Array).erase(a)
		(cr["pedidos"] as Dictionary).erase(a)


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
	var forzar := a.espera > ESPERA_FORZAR
	# Otros autos: al de adelante (aunque sea de otra ruta, por el mismo carril) se lo sigue; a los que cruzan
	# muy cerca se les frena
	var lider: Auto = null      # El de adelante en el mismo carril
	var hueco_lider := INF
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
				if hueco < hueco_lider:
					lider = b
					hueco_lider = hueco
		elif not forzar and paralelo > -0.5 and lat < 2.4 and hueco < 4.5:
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
	# Cruces con otras calles: se pide turno antes de la línea (la zona de choque está medida en posiciones
	# del centro del vehículo, ver _choque)
	var zona := maxf(14.0, a.velocidad * a.velocidad / 12.0 + 4.0)   # Con lugar para frenar
	var entradas: Array = r["entradas"]
	var ti := _tipo(a)
	for k in entradas.size():
		var e: Dictionary = entradas[k]
		var t: Vector2 = e["tramos"][ti]
		if t.x == INF:
			continue   # Este tipo de vehículo no pisa a nadie en este cruce
		var cr: Dictionary = _cruces[int(e["cruce"])]
		var autos: Array = cr["autos"]
		var pedidos: Dictionary = cr["pedidos"]
		if a.s >= t.y + MARGEN_LINEA:
			autos.erase(a)
			continue
		if autos.has(a):
			continue
		var dist_linea := t.x - MARGEN_LINEA - a.s
		if dist_linea <= 0.0:
			# Ya está adentro (no llegó a frenar): entra igual
			autos.append(a)
			pedidos.erase(a)
			continue
		if dist_linea > zona:
			continue
		# El de adelante todavía no pasó la línea: primero entra él (se lo sigue, nada más)
		if lider != null and hueco_lider < dist_linea and not autos.has(lider):
			pedidos.erase(a)
			continue
		if not pedidos.has(a):
			pedidos[a] = {"t": _tiempo, "listo": false}
		var cadena := _cadena(a, k)
		var listo := forzar or _lugar_despues(a, cadena[1], cadena[2])
		pedidos[a]["listo"] = listo
		var puede := listo
		if listo and not forzar:
			for j: int in cadena[0]:
				if not _puede_entrar(_cruces[int(entradas[j]["cruce"])], a, float(pedidos[a]["t"]), destrabar):
					puede = false
					break
		if puede:
			for j: int in cadena[0]:
				var crj: Dictionary = _cruces[int(entradas[j]["cruce"])]
				if not (crj["autos"] as Array).has(a):
					(crj["autos"] as Array).append(a)
				(crj["pedidos"] as Dictionary).erase(a)
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


## Turno en el cruce: no puede haber adentro nadie de una ruta que lo choque, ni (salvo que ya esperó
## demasiado) alguien de una ruta que lo choque esperando desde antes, con lugar para cruzar y hace más de
## GRACIA_TURNO s. El que espera desde hace más tiempo nunca queda frenado por otro que espera: no hay nudo.
func _puede_entrar(cr: Dictionary, a: Auto, mio: float, destrabar: bool) -> bool:
	var choques: Dictionary = cr["choques"]
	for b: Auto in cr["autos"]:
		if b.ruta != a.ruta and choques.has(_par(a.ruta, b.ruta)):
			return false
	if destrabar:
		return true
	var pedidos: Dictionary = cr["pedidos"]
	for b: Auto in pedidos:
		var p: Dictionary = pedidos[b]
		var desde: float = p["t"]
		if b != a and p["listo"] and desde < mio and _tiempo - desde > GRACIA_TURNO \
				and b.ruta != a.ruta and choques.has(_par(a.ruta, b.ruta)):
			return false
	return true


## Las entradas que hay que pasar de un saque a partir de la "k" (si la siguiente está tan pegada que no
## se puede esperar entre las dos sin seguir adentro de la primera) y dónde puede tener que frenar después:
## [índices, dónde suelta la última, parada] (posiciones del centro del vehículo). La parada es la línea
## del cruce siguiente o la del semáforo si no está en verde; como mucho, TRAMO_LIBRE más allá.
func _cadena(a: Auto, k: int) -> Array:
	var r: Dictionary = _rutas[a.ruta]
	var entradas: Array = r["entradas"]
	var ti := _tipo(a)
	var indices: Array[int] = [k]
	var suelta: float = (entradas[k]["tramos"][ti] as Vector2).y + MARGEN_LINEA
	var parada := INF
	for j in range(k + 1, entradas.size()):
		var t: Vector2 = entradas[j]["tramos"][ti]
		if t.x == INF:
			continue
		if t.x - MARGEN_LINEA < suelta:
			indices.append(j)
			suelta = maxf(suelta, t.y + MARGEN_LINEA)
		else:
			parada = t.x - MARGEN_LINEA
			break
	if luz != Luz.VERDE:
		for linea: float in r["lineas"]:
			var c := linea - a.largo / 2.0 - 0.2
			if c >= suelta:
				parada = minf(parada, c)
	parada = minf(parada, minf(suelta + TRAMO_LIBRE, float(r["largo"])))
	return [indices, suelta, parada]


## ¿Hay lugar para cruzar sin quedar parado adentro? Los autos que tiene adelante por su camino, hasta la
## parada siguiente, en el peor caso terminan en fila ahí: tienen que dejarle lugar para soltar el cruce.
## Así nadie queda parado adentro detrás de la cola de la cuadra siguiente trabando las otras calles, y
## dos cruces cercanos (Bolívar y la Av. de Mayo, Bolívar y la avenida) no se traban entre sí.
func _lugar_despues(a: Auto, suelta: float, parada: float) -> bool:
	var r: Dictionary = _rutas[a.ruta]
	var c: Curve3D = r["curva"]
	var largo: float = r["largo"]
	var hasta := parada + a.largo / 2.0        # Trompa del primero de la fila
	var medio := c.sample_baked((a.s + hasta) / 2.0)
	var alcance := (hasta - a.s) / 2.0 + (MEDIDAS[1] as Vector2).x + 1.0
	var ocupado := 0.0
	for b in _autos:
		if b == a or not is_instance_valid(b):
			continue
		var bp := b.global_position
		if Vector2(bp.x - medio.x, bp.z - medio.z).length_squared() > alcance * alcance:
			continue
		var sb := c.get_closest_offset(bp)
		if sb <= a.s or sb - b.largo / 2.0 > hasta:
			continue
		var q := c.sample_baked(sb)
		if Vector2(q.x - bp.x, q.z - bp.z).length_squared() > 1.0:
			continue   # Va por otro carril (o está cruzando)
		var dir := c.sample_baked(minf(sb + 1.0, largo)) - c.sample_baked(maxf(sb - 1.0, 0.0))
		if dir.normalized().dot(b.adelante()) < 0.7:
			continue
		ocupado += b.largo + 2.0
	return ocupado <= parada - suelta


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
