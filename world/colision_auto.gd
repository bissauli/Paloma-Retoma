class_name ColisionAuto
extends RefCounted
## Colisiones que le faltan a los edificios del kit (mapa V4.5). Las colisiones de KitDatos las arma
## tools/blender/generar_ciudad.py y dejan afuera partes que sobresalen de la fachada: la cornisa de
## arriba, la tapa de color del pretil (que queda más alta que la caja del pretil: la paloma se hundía
## en ella), los toldos de la planta baja, las bandas y los pasamanos. La paloma las atravesaba.
## Las cajas del pretil se agrandan (ver caja()) y el resto se busca en la malla: los triángulos que
## quedan afuera de toda colisión se juntan en piezas (triángulos que comparten un vértice) y cada
## pieza que sobresale lo suficiente y no es un detalle chico pasa a ser un convexo con sus vértices
## (si la pieza no es convexa, una lámina por triángulo). Se calcula una vez por pieza del kit.

const MARGEN := 0.05          ## Un triángulo cuyo centro está a menos de esto de una caja ya está cubierto
const SALIDA_MIN := 0.15      ## Lo que sobresale menos que esto de la colisión no hace falta cubrirlo
const LARGO_MIN := 1.5        ## Las piezas más chicas (macetas, aires, dentículos, manijas) se ignoran
const GROSOR_MIN := 0.12      ## ...y las finitas (barrotes, caños, marcos): ahí no se nota atravesarlas
const Y_MIN := 1.6            ## Lo de la planta baja a la altura de la paloma caminando queda libre
const MAX_PUNTOS := 48        ## Puntos por convexo (los de más se descartan sin cambiar la forma)
const RELLENO_MIN := 0.45     ## Superficie de la pieza / la de su caja envolvente: menos que esto, no es convexa
const PRETIL := 1.0           ## Alto del pretil de la azotea (tools/blender/generar_ciudad.py)
const TAPA := 0.32            ## Alto de la tapa de color del pretil
const SALE_TAPA := 0.14       ## Lo que sobresale la tapa de la fachada
const ESPESOR_LAMINA := 0.14  ## Espesor de las láminas (hacia adentro de la pieza)

static var _cache := {}
static var _formas := {}


## Formas de colisión de la pieza (como _cajas) más las cajas envolventes de sus convexos extra
## (KitColisionesExtra): para saber si algo se mete en un edificio. Cacheadas por pieza.
static func formas(nombre: String) -> Array:
	if _formas.has(nombre):
		return _formas[nombre]
	var out := _cajas(Kit.datos(nombre))
	for pts: Array in KitColisionesExtra.PIEZAS.get(nombre, []):
		var env := AABB(Vector3(pts[0], pts[1], pts[2]), Vector3.ZERO)
		for k in range(3, pts.size(), 3):
			env = env.expand(Vector3(pts[k], pts[k + 1], pts[k + 2]))
		out.append([Transform3D(Basis.IDENTITY, env.get_center()).affine_inverse(), env.size / 2.0])
	_formas[nombre] = out
	return out


## Caja de colisión "c" de KitDatos (centro, tamaño y base) como [base, centro, tamaño]. Las cajas
## del pretil de la azotea se agrandan para que cubran la tapa de color: 32 cm más altas y 14 cm más
## gruesas de cada lado (la tapa sobresale de la fachada).
static func caja(d: Dictionary, c: Array) -> Array:
	var b := Basis.IDENTITY
	if c.size() >= 15:
		b = Basis(Vector3(c[6], c[7], c[8]), Vector3(c[9], c[10], c[11]), Vector3(c[12], c[13], c[14]))
	var centro := Vector3(c[0], c[1], c[2])
	var tam := Vector3(c[3], c[4], c[5])
	if d.has("alto") and d.get("carpeta", "") == "edificios":
		var vertical := 0
		for k in 3:
			if absf(b[k].y) > absf(b[vertical].y):
				vertical = k
		var alto := float(d["alto"])
		if absf(tam[vertical] - PRETIL) < 0.02 and absf(centro.y - (alto + PRETIL / 2.0)) < 0.06:
			var fino := (vertical + 1) % 3
			var otro := (vertical + 2) % 3
			if tam[otro] < tam[fino]:
				fino = otro
			tam[vertical] += TAPA
			centro.y += TAPA / 2.0
			tam[fino] += 2.0 * SALE_TAPA
	return [b, centro, tam]


## Convexos que faltan en la pieza "nombre", en su espacio local: Array de PackedVector3Array.
static func convexos(nombre: String) -> Array:
	if _cache.has(nombre):
		return _cache[nombre]
	var out: Array = []
	_cache[nombre] = out
	var d := Kit.datos(nombre)
	var m := Kit.malla(nombre)
	if m == null:
		return out
	var cajas := _cajas(d)
	# Triángulos sin cubrir y sus vértices, con los vértices soldados por posición (1 mm)
	var claves := {}          # posición soldada -> índice
	var puntos: Array[Vector3] = []
	var tris: Array[PackedInt32Array] = []
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(v.size()))
		for i in range(0, idx.size() - 2, 3):
			var p0 := v[idx[i]]
			var p1 := v[idx[i + 1]]
			var p2 := v[idx[i + 2]]
			var c := (p0 + p1 + p2) / 3.0
			if c.y < Y_MIN or _salida(c, cajas) <= MARGEN:
				continue
			var t := PackedInt32Array()
			for p in [p0, p1, p2]:
				var k := Vector3i((p * 1000.0).round())
				if not claves.has(k):
					claves[k] = puntos.size()
					puntos.append(p)
				t.append(claves[k])
			tris.append(t)
	if tris.is_empty():
		return out
	# Piezas: unión de los triángulos que comparten vértices
	var padre := PackedInt32Array()
	padre.resize(puntos.size())
	for i in puntos.size():
		padre[i] = i
	for t in tris:
		_unir(padre, t[0], t[1])
		_unir(padre, t[0], t[2])
	var grupos := {}
	for t in tris:
		var r := _raiz(padre, t[0])
		if not grupos.has(r):
			grupos[r] = []
		(grupos[r] as Array).append(t)
	for lista: Array in grupos.values():
		var usados := {}
		var g := PackedVector3Array()
		var area := 0.0
		for t: PackedInt32Array in lista:
			area += (puntos[t[1]] - puntos[t[0]]).cross(puntos[t[2]] - puntos[t[0]]).length() / 2.0
			for i in t:
				if not usados.has(i):
					usados[i] = true
					g.append(puntos[i])
		if g.size() < 4 or not _sirve(g, cajas):
			continue
		var caja_g := _envolvente(g)
		var sup := 2.0 * (caja_g.size.x * caja_g.size.y + caja_g.size.y * caja_g.size.z + caja_g.size.z * caja_g.size.x)
		if area >= RELLENO_MIN * sup:
			out.append(_recortar(_con_espesor(g, caja_g)))
			continue
		# La pieza no es convexa (una L o un anillo de cosas que se tocan): su envolvente taparía lo de
		# adentro. Va cada cara plana como una lámina hacia adentro (o cada triángulo, si la cara es una L).
		var caras := {}
		for t: PackedInt32Array in lista:
			var n := (puntos[t[1]] - puntos[t[0]]).cross(puntos[t[2]] - puntos[t[0]])
			if n.length() < 0.0001:
				continue
			n = n.normalized()
			var k := [Vector3i((n * 50.0).round()), roundi(n.dot(puntos[t[0]]) * 50.0)]
			if not caras.has(k):
				caras[k] = []
			(caras[k] as Array).append(t)
		var centro_pieza := caja_g.get_center()
		for cara: Array in caras.values():
			var t0: PackedInt32Array = cara[0]
			var n := (puntos[t0[1]] - puntos[t0[0]]).cross(puntos[t0[2]] - puntos[t0[0]]).normalized()
			# La normal hacia afuera de la pieza (el orden de los vértices no lo dice): la lámina crece hacia adentro
			if n.dot(puntos[t0[0]] - centro_pieza) < 0.0:
				n = -n
			var partes: Array = [cara]
			if not _cara_llena(cara, puntos, n):
				partes = []
				for t: PackedInt32Array in cara:
					partes.append([t])
			for parte: Array in partes:
				var lam := PackedVector3Array()
				var vistos := {}
				for t: PackedInt32Array in parte:
					for i in t:
						if not vistos.has(i):
							vistos[i] = true
							lam.append(puntos[i])
				if not _sirve(lam, cajas):
					continue
				var nl := lam.size()
				for i in nl:
					lam.append(lam[i] - n * ESPESOR_LAMINA)
				out.append(_recortar(lam))
	return out


## Si los triángulos de una cara plana llenan su rectángulo (entonces su envolvente es la cara).
static func _cara_llena(cara: Array, puntos: Array[Vector3], n: Vector3) -> bool:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var w := n.cross(u)
	var r := Rect2(Vector2(puntos[(cara[0] as PackedInt32Array)[0]].dot(u), puntos[(cara[0] as PackedInt32Array)[0]].dot(w)), Vector2.ZERO)
	var area := 0.0
	for t: PackedInt32Array in cara:
		area += (puntos[t[1]] - puntos[t[0]]).cross(puntos[t[2]] - puntos[t[0]]).length() / 2.0
		for i in t:
			r = r.expand(Vector2(puntos[i].dot(u), puntos[i].dot(w)))
	return area >= 0.8 * r.get_area()


## Si vale la pena cubrir los puntos "g": sobresalen bastante de la colisión y no son un detalle chico.
static func _sirve(g: PackedVector3Array, cajas: Array) -> bool:
	var salida := 0.0
	for p in g:
		salida = maxf(salida, _salida(p, cajas))
	var c := _envolvente(g)
	var lados := [c.size.x, c.size.y, c.size.z]
	lados.sort()
	return salida >= SALIDA_MIN and lados[2] >= LARGO_MIN and lados[1] >= GROSOR_MIN


static func _envolvente(g: PackedVector3Array) -> AABB:
	var c := AABB(g[0], Vector3.ZERO)
	for p in g:
		c = c.expand(p)
	return c


## Una pieza plana (una cara suelta) no sirve de convexo: se le da un poco de espesor.
static func _con_espesor(g: PackedVector3Array, c: AABB) -> PackedVector3Array:
	if c.get_shortest_axis_size() >= 0.02:
		return g
	var out := PackedVector3Array(g)
	var eje := c.get_shortest_axis_index()
	for p in g:
		var q := p
		q[eje] -= 0.04
		out.append(q)
	return out


## Formas de colisión de la pieza: [transformación inversa, medio tamaño] para las cajas y
## [planta, Vector2(y desde, y hasta)] para los prismas.
static func _cajas(d: Dictionary) -> Array:
	var out: Array = []
	for c: Array in d.get("cajas", []):
		var cj := caja(d, c)
		out.append([Transform3D(cj[0], cj[1]).affine_inverse(), (cj[2] as Vector3) / 2.0])
	# Los convexos: si son un prisma vertical (las esquinas con ochava) se guarda su planta; si no, su
	# caja envolvente (alcanza para saber qué ya está cubierto)
	for pts: Array in d.get("convexos", []):
		var caja := AABB(Vector3(pts[0], pts[1], pts[2]), Vector3.ZERO)
		var planta := PackedVector2Array()
		var prisma := true
		for k in range(0, pts.size(), 3):
			var p := Vector3(pts[k], pts[k + 1], pts[k + 2])
			caja = caja.expand(p)
			if absf(p.y - pts[1]) < 0.001:
				planta.append(Vector2(p.x, p.z))
		for k in range(0, pts.size(), 3):
			if absf(float(pts[k + 1]) - caja.position.y) > 0.001 and absf(float(pts[k + 1]) - caja.end.y) > 0.001:
				prisma = false
		if prisma and planta.size() >= 3 and absf(float(pts[1]) - caja.position.y) < 0.001:
			out.append([planta, Vector2(caja.position.y, caja.end.y)])
		else:
			out.append([Transform3D(Basis.IDENTITY, caja.get_center()).affine_inverse(), caja.size / 2.0])
	for e: Array in d.get("esferas", []):
		out.append([Transform3D(Basis.IDENTITY, -Vector3(e[0], e[1], e[2])), Vector3.ONE * float(e[3])])
	return out


## Cuánto queda "p" afuera de la forma más cercana (0 si está adentro de alguna).
static func _salida(p: Vector3, cajas: Array) -> float:
	var mejor := INF
	for c: Array in cajas:
		var e: float
		if c[0] is PackedVector2Array:
			var planta: PackedVector2Array = c[0]
			var ys: Vector2 = c[1]
			var q := Vector2(p.x, p.z)
			var ey := maxf(ys.x - p.y, p.y - ys.y)
			var exz := 0.0
			if not Geometry2D.is_point_in_polygon(q, planta):
				exz = INF
				for i in planta.size():
					var a := planta[i]
					var b := planta[(i + 1) % planta.size()]
					exz = minf(exz, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
			e = maxf(ey, exz)
		else:
			var q: Vector3 = (c[0] as Transform3D) * p
			var h: Vector3 = c[1]
			e = maxf(maxf(absf(q.x) - h.x, absf(q.y) - h.y), absf(q.z) - h.z)
		if e <= 0.0:
			return 0.0
		mejor = minf(mejor, e)
	return mejor


static func _raiz(padre: PackedInt32Array, i: int) -> int:
	while padre[i] != i:
		padre[i] = padre[padre[i]]
		i = padre[i]
	return i


static func _unir(padre: PackedInt32Array, a: int, b: int) -> void:
	var ra := _raiz(padre, a)
	var rb := _raiz(padre, b)
	if ra != rb:
		padre[ra] = rb


## Si hay demasiados puntos, se quedan los extremos en varias direcciones (los del casco convexo
## suelen ser pocos: las piezas son cajas).
static func _recortar(g: PackedVector3Array) -> PackedVector3Array:
	if g.size() <= MAX_PUNTOS:
		return g
	var dirs: Array[Vector3] = []
	for x in [-1.0, 0.0, 1.0]:
		for y in [-1.0, 0.0, 1.0]:
			for z in [-1.0, 0.0, 1.0]:
				if x != 0.0 or y != 0.0 or z != 0.0:
					dirs.append(Vector3(x, y, z).normalized())
	var elegidos := {}
	for dir in dirs:
		var mejor := 0
		for i in g.size():
			if g[i].dot(dir) > g[mejor].dot(dir):
				mejor = i
		elegidos[mejor] = true
	var out := PackedVector3Array()
	for i: int in elegidos:
		out.append(g[i])
	return out
