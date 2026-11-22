class_name ColisionFaltante
extends RefCounted
## Red de seguridad de colisiones: después de armar el mundo (y antes de fusionar las mallas), recorre
## todo lo que se ve dentro del mapa jugable y, a lo que no tiene ninguna colisión encima, le agrega una
## con su forma (la caja, el cilindro o la esfera de la primitiva, o la envolvente convexa de la malla
## del kit). Así nada se atraviesa: ni la paloma, ni las palomas de la bandada, ni la gente y los
## animales (sus caminos se arman con las colisiones del mundo, ver Navegacion).
##
## Antes había decenas de cosas sin colisión: autos estacionados, bicis, cestos, conos, carteles,
## pilotes, arbustos, macetas, tendederos, rejas, faroles armados con primitivas, puestos, tanques...
## Lo que se agregue de ahora en más también queda cubierto sin tener que acordarse.
##
## Se saltean (a propósito no tienen colisión):
## - Lo que anda solo o se agarra: todo lo que cuelga de un nodo con script (autos del tránsito, gente,
##   animales, comida, cielo, horizonte...), salvo las casas enterables. Los objetos golpeables (tazas,
##   macetas de los cafés) tienen su propia física en otra capa.
## - Lo plano: marcas de la calle, calcomanías, carteles y vidrieras de un plano (menos de 2 cm de
##   espesor, o de 5 cm de alto).
## - Lo que hay que poder atravesar: ventanas, puertas, cortinas y vidrios (las casas se recorren
##   volando de ventana a ventana) y las guirnaldas de luces que cruzan la calle.
## - Las mallas "sólo sombra" (las formas simples que proyectan la sombra de las piezas del kit).
## - Lo que está fuera del mapa jugable (el fondo y el horizonte).
## - Un nodo (y lo que cuelga de él) con la meta "atravesable".

const CELDA := 8.0                ## Celdas del índice de formas (en X/Z)
const CUBIERTO := 0.35            ## Fracción de la caja de la malla que ya tiene que estar dentro de colisiones
const MIN_ESPESOR := 0.02
const MIN_ALTO := 0.05
const MARGEN_MAPA := 3.0
const LOSA_ALTO := 0.3            ## Una losa de piso es así de baja...
const LOSA_LADO := 0.8            ## ...y por lo menos así de ancha de cada lado
const TAPA_TOLERANCIA := 0.015    ## Cuánto más abajo que la cara de arriba de una losa puede estar su colisión
const ATRAVESABLES := ["ventana", "puerta", "cortina", "vidrio", "vidriera", "guirnalda"]
const SCRIPTS_PERMITIDOS := ["casa_enterable.gd"]

static var _envolventes := {}     ## id de malla (o malla y escala) -> ConvexPolygonShape3D en su espacio


## Agrega las colisiones que faltan a lo que cuelga de "raiz". Devuelve cuántas agregó.
static func completar(raiz: Node3D) -> int:
	if MapaOverrides.modo_admin:
		return 0
	# Fuera del árbol (el mundo se arma en otro hilo, ver Arranque) se miran las formas de todo lo que
	# cuelga de lo más alto de esa rama
	var escena: Node = raiz.get_tree().root if raiz.is_inside_tree() else raiz
	while not raiz.is_inside_tree() and escena.get_parent():
		escena = escena.get_parent()
	var formas: Array = []          # [inversa, aabb local]
	var indice := {}
	_juntar_formas(escena, formas, indice)
	var cuerpos := {}
	var agregadas := 0
	var pendientes: Array[Node] = [raiz]
	while not pendientes.is_empty():
		var n: Node = pendientes.pop_back()
		for h in n.get_children():
			if h.has_meta(&"atravesable") or h is CollisionObject3D:
				continue
			var s: Script = h.get_script()
			if s != null and not (s.resource_path.get_file() in SCRIPTS_PERMITIDOS):
				continue
			pendientes.append(h)
			var mi := h as MeshInstance3D
			if mi == null or mi.mesh == null or not Construir.visible_de(mi):
				continue
			if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				continue
			if _es_atravesable(mi):
				continue
			var caja := Construir.global_de(mi) * mi.mesh.get_aabb()
			if caja.size.y < MIN_ALTO or minf(caja.size.x, minf(caja.size.y, caja.size.z)) < MIN_ESPESOR:
				continue
			var c := caja.get_center()
			if c.x < Ciudad.X_MIN - MARGEN_MAPA or c.x > Ciudad.X_MAX + MARGEN_MAPA \
					or c.z < Ciudad.Z_MIN - MARGEN_MAPA or c.z > Ciudad.Z_MAX + MARGEN_MAPA:
				continue
			if _cubierta(caja, formas, indice):
				continue
			var gt := Construir.global_de(mi)
			var forma_t := _forma_para(mi.mesh, gt)
			if forma_t.is_empty():
				continue
			var clave := Vector2i(floori(c.x / 48.0), floori(c.z / 48.0))
			if not cuerpos.has(clave):
				var b := StaticBody3D.new()
				b.name = "ColisionesCompletadas_%d_%d" % [clave.x, clave.y]
				b.collision_layer = Construir.CAPA_MUNDO
				b.collision_mask = 0
				raiz.add_child(b)
				b.transform = Construir.global_de(raiz).affine_inverse()
				cuerpos[clave] = b
			var cs := CollisionShape3D.new()
			cs.shape = forma_t[0]
			cs.transform = forma_t[1]
			(cuerpos[clave] as StaticBody3D).add_child(cs)
			# Lo que se acaba de cubrir cuenta para lo que sigue (la versión de lejos de la misma pieza)
			_agregar_forma(formas, indice, Transform3D.IDENTITY, caja)
			agregadas += 1
	return agregadas


static func _es_atravesable(mi: MeshInstance3D) -> bool:
	var nombre := (String(mi.name) + " " + String(mi.get_meta(&"pieza", "")) + " " + String(mi.get_meta(&"kit_pieza", ""))).to_lower()
	for a: String in ATRAVESABLES:
		if nombre.contains(a):
			return true
	return false


## Todas las formas de colisión del mundo (capa del mundo) con su caja local, indexadas por celda.
static func _juntar_formas(raiz: Node, formas: Array, indice: Dictionary) -> void:
	var pendientes: Array[Node] = [raiz]
	while not pendientes.is_empty():
		var n: Node = pendientes.pop_back()
		pendientes.append_array(n.get_children())
		var cs := n as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var dueno := cs.get_parent() as CollisionObject3D
		if dueno == null or (dueno.collision_layer & Construir.CAPA_MUNDO) == 0 or dueno is Area3D:
			continue
		var local := _caja_forma(cs.shape)
		if local.size == Vector3.ZERO:
			continue
		_agregar_forma(formas, indice, Construir.global_de(cs), local)


static func _agregar_forma(formas: Array, indice: Dictionary, t: Transform3D, local: AABB) -> void:
	var mundo := t * local
	var i := formas.size()
	formas.append([t.affine_inverse(), _engordar(local), mundo])
	for x in range(floori(mundo.position.x / CELDA), floori(mundo.end.x / CELDA) + 1):
		for z in range(floori(mundo.position.z / CELDA), floori(mundo.end.z / CELDA) + 1):
			var k := Vector2i(x, z)
			if not indice.has(k):
				indice[k] = []
			(indice[k] as Array).append(i)


static func _caja_forma(f: Shape3D) -> AABB:
	if f is BoxShape3D:
		var s := (f as BoxShape3D).size
		return AABB(-s / 2.0, s)
	if f is SphereShape3D:
		var r := (f as SphereShape3D).radius
		return AABB(-Vector3.ONE * r, Vector3.ONE * r * 2.0)
	if f is CylinderShape3D:
		var cy := f as CylinderShape3D
		return AABB(Vector3(-cy.radius, -cy.height / 2.0, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	if f is CapsuleShape3D:
		var ca := f as CapsuleShape3D
		return AABB(Vector3(-ca.radius, -ca.height / 2.0, -ca.radius), Vector3(ca.radius * 2.0, ca.height, ca.radius * 2.0))
	if f is ConvexPolygonShape3D:
		return _caja_puntos((f as ConvexPolygonShape3D).points)
	if f is ConcavePolygonShape3D:
		return _caja_puntos((f as ConcavePolygonShape3D).get_faces())
	if f is WorldBoundaryShape3D:
		return AABB()
	var dm := f.get_debug_mesh()
	return dm.get_aabb() if dm else AABB()


static func _caja_puntos(p: PackedVector3Array) -> AABB:
	if p.is_empty():
		return AABB()
	var a := AABB(p[0], Vector3.ZERO)
	for q in p:
		a = a.expand(q)
	return a


static func _engordar(a: AABB) -> AABB:
	var s := a.size.max(Vector3.ONE * 0.1)
	return AABB(a.get_center() - s / 2.0, s)


## Si la caja "caja" (de una malla, en el mundo) ya está en buena parte dentro de colisiones del mundo.
## Cada forma se mira en su propio espacio (así una pared girada no "cubre" todo lo que está cerca).
## Una losa de piso (baja y ancha: pasto, baldosas, tarimas) además tiene que tener la colisión a la altura
## de su cara de arriba: el pasto de los canteros de la plaza (tapa a 10 cm) quedaba "cubierto" por la
## colisión del borde de piedra (6 cm) y las palomas caminaban con las patas metidas en el pasto.
static func _cubierta(caja: AABB, formas: Array, indice: Dictionary) -> bool:
	if _es_losa(caja) and _tapa_colision(caja, formas, indice) < caja.end.y - TAPA_TOLERANCIA:
		return false
	var vistos := {}
	var suma := 0.0
	var piso := caja.position.y + caja.size.y * 0.4
	for x in range(floori(caja.position.x / CELDA), floori(caja.end.x / CELDA) + 1):
		for z in range(floori(caja.position.z / CELDA), floori(caja.end.z / CELDA) + 1):
			for i: int in indice.get(Vector2i(x, z), []):
				if vistos.has(i):
					continue
				vistos[i] = true
				var f: Array = formas[i]
				var mundo: AABB = f[2]
				# Lo que sólo toca la parte de abajo es el piso (las flores y los arbustos se hunden un
				# poco en él): no cuenta como colisión de la pieza
				if mundo.end.y < piso or not mundo.intersects(caja):
					continue
				var en_local := _engordar((f[0] as Transform3D) * caja)
				var inter := en_local.intersection(f[1] as AABB)
				if inter.size == Vector3.ZERO:
					continue
				suma += inter.get_volume() / en_local.get_volume()
				if suma >= CUBIERTO:
					return true
	return false


## ¿Es una losa de piso? Baja (hasta LOSA_ALTO) y ancha (LOSA_LADO o más de cada lado): ahí se camina
## por arriba.
static func _es_losa(caja: AABB) -> bool:
	return caja.size.y <= LOSA_ALTO and minf(caja.size.x, caja.size.z) >= LOSA_LADO


## Altura más alta de las colisiones que hay debajo del centro de la caja (de la base para arriba, sin
## pasar la caja). -INF si no hay ninguna.
static func _tapa_colision(caja: AABB, formas: Array, indice: Dictionary) -> float:
	var c := caja.get_center()
	var tapa := -INF
	for i: int in indice.get(Vector2i(floori(c.x / CELDA), floori(c.z / CELDA)), []):
		var f: Array = formas[i]
		var mundo: AABB = f[2]
		if mundo.end.y < caja.position.y - TAPA_TOLERANCIA or mundo.position.y > caja.end.y:
			continue
		# El centro de la losa tiene que caer adentro de la forma (mirada en su espacio)
		var local: Vector3 = (f[0] as Transform3D) * Vector3(c.x, mundo.get_center().y, c.z)
		var en_local: AABB = f[1]
		if local.x < en_local.position.x or local.x > en_local.end.x or local.z < en_local.position.z or local.z > en_local.end.z:
			continue
		tapa = maxf(tapa, minf(mundo.end.y, caja.end.y))
	return tapa


## La forma de colisión de una malla puesta con la transformación "gt": [forma, transformación].
## Las primitivas usan su forma exacta (caja, cilindro, esfera, cápsula); las mallas del kit, la
## envolvente convexa de sus vértices (una por malla, compartida por todas sus copias).
static func _forma_para(m: Mesh, gt: Transform3D) -> Array:
	var esc := gt.basis.get_scale()
	var giro := Transform3D(gt.basis.orthonormalized(), gt.origin)
	if m is BoxMesh:
		var f := BoxShape3D.new()
		f.size = (m as BoxMesh).size * esc
		return [f, giro]
	if m is CylinderMesh:
		var cm := m as CylinderMesh
		var f := CylinderShape3D.new()
		f.radius = maxf(cm.top_radius, cm.bottom_radius) * maxf(esc.x, esc.z)
		f.height = cm.height * esc.y
		return [f, giro]
	if m is SphereMesh:
		var f := SphereShape3D.new()
		f.radius = (m as SphereMesh).radius * maxf(esc.x, maxf(esc.y, esc.z))
		return [f, giro]
	if m is CapsuleMesh:
		var f := CapsuleShape3D.new()
		f.radius = (m as CapsuleMesh).radius * maxf(esc.x, esc.z)
		f.height = (m as CapsuleMesh).height * esc.y
		return [f, giro]
	var base := _envolvente(m)
	if base == null:
		return []
	if esc.is_equal_approx(Vector3.ONE):
		return [base, giro]
	# Escalada: la misma envolvente con los puntos escalados (una por malla y escala)
	var clave := "%d_%.3f_%.3f_%.3f" % [m.get_instance_id(), esc.x, esc.y, esc.z]
	if not _envolventes.has(clave):
		var pts := PackedVector3Array()
		for q in base.points:
			pts.append(q * esc)
		var f := ConvexPolygonShape3D.new()
		f.points = pts
		_envolventes[clave] = f
	return [_envolventes[clave], giro]


## Envolvente convexa de la malla (en su espacio): sus vértices redondeados a 5 cm y sin repetir.
static func _envolvente(m: Mesh) -> ConvexPolygonShape3D:
	var k := m.get_instance_id()
	if _envolventes.has(k):
		return _envolventes[k]
	var vistos := {}
	var pts := PackedVector3Array()
	for s in m.get_surface_count():
		var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			var q := p.snapped(Vector3.ONE * 0.05)
			if not vistos.has(q):
				vistos[q] = true
				pts.append(q)
	var f: ConvexPolygonShape3D = null
	if pts.size() >= 4:
		f = ConvexPolygonShape3D.new()
		f.points = pts
	_envolventes[k] = f
	return f
