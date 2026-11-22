class_name Navegacion
extends RefCounted
## Caminos para la gente y los animales (mapa V3.1). Antes caminaban en línea recta hacia un punto al
## azar de su zona y atravesaban la fuente, los bancos, los árboles y lo que hubiera en el medio.
## Ahora cada zona donde camina alguien tiene su malla de navegación, armada la primera vez que se la
## pide: un piso plano del tamaño de la zona menos las colisiones del mundo que estén a la altura de
## los pies (entre ALTO_PIES y ALTO_CABEZA sobre el piso de la zona), agrandadas por el radio de quien
## camina. Cada zona tiene su propio mapa de navegación (así dos zonas que se pisan no se mezclan) y
## todos los que caminan por la misma zona lo comparten.
##
## Uso: var z := Navegacion.zona(mundo, centro, tam) una vez; después Navegacion.ruta(z, desde, hasta)
## y Navegacion.punto_al_azar(z). Si la zona todavía no está lista (o no se pudo armar) la ruta viene
## vacía y quien camina sigue en línea recta.

const ALTO_PIES := 0.25      ## Lo que está más abajo (cordones, losetas, canteros bajitos) no estorba
const ALTO_CABEZA := 1.6     ## Lo que está más arriba (copas, toldos, ramas) tampoco
const CELDA := 0.25          ## Tamaño de celda de la malla (el mismo que el del mapa)
const MAX_FORMAS := 1024

static var _zonas := {}      ## "clave" -> {mapa, region, centro, tam}


## La zona rectangular de "tam" (X, Z) metros con el piso a la altura de "centro". La arma (y la
## guarda) la primera vez. "radio": cuánto se agrandan los obstáculos (el radio de quien camina).
## "extra": huellas (polígonos en XZ) que también son obstáculos aunque no tengan colisión a la altura
## de los pies (el hueco de la escalera del subte, por ejemplo).
static func zona(mundo: World3D, centro: Vector3, tam: Vector2, radio := 0.35,
		extra: Array[PackedVector2Array] = []) -> Dictionary:
	var clave := "%.1f,%.2f,%.1f|%.1fx%.1f|%.2f|%d" % [centro.x, centro.y, centro.z, tam.x, tam.y, radio, extra.size()]
	if _zonas.has(clave):
		return _zonas[clave]
	PantallaCarga.refrescar()
	var nm := hornear(mundo.direct_space_state, centro, tam, radio, extra)
	var mapa := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(mapa, CELDA)
	NavigationServer3D.map_set_cell_height(mapa, CELDA)
	NavigationServer3D.map_set_use_async_iterations(mapa, false)
	NavigationServer3D.map_set_active(mapa, true)
	var region := NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(region, mapa)
	NavigationServer3D.region_set_navigation_mesh(region, nm)
	NavigationServer3D.map_force_update(mapa)
	var z := {"mapa": mapa, "region": region, "centro": centro, "tam": tam, "poligonos": nm.get_polygon_count()}
	_zonas[clave] = z
	return z


## Malla de navegación de la zona: el piso menos las huellas de los obstáculos.
static func hornear(espacio: PhysicsDirectSpaceState3D, centro: Vector3, tam: Vector2, radio: float,
		extra: Array[PackedVector2Array] = []) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = CELDA
	nm.cell_height = CELDA
	nm.agent_radius = 0.0          # los obstáculos ya vienen agrandados (ver _huella)
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.25
	nm.region_min_size = 1.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var src := NavigationMeshSourceGeometryData3D.new()
	var y := centro.y
	var a := Vector3(centro.x - tam.x / 2.0, y, centro.z - tam.y / 2.0)
	var b := Vector3(centro.x + tam.x / 2.0, y, centro.z + tam.y / 2.0)
	src.add_faces(PackedVector3Array([a, Vector3(b.x, y, a.z), b, a, b, Vector3(a.x, y, b.z)]), Transform3D.IDENTITY)
	var huellas := obstaculos(espacio, centro, tam, radio)
	for e: PackedVector2Array in extra:
		var grande := Geometry2D.offset_polygon(e, radio, Geometry2D.JOIN_MITER)
		if not grande.is_empty():
			huellas.append(Geometry2D.convex_hull(grande[0]))
	for huella: PackedVector2Array in huellas:
		var pts := PackedVector3Array()
		for p in huella:
			pts.append(Vector3(p.x, y, p.y))
		src.add_projected_obstruction(pts, y - 1.0, 3.0, true)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	return nm


## Huellas (polígonos convexos en XZ, ya agrandadas por "radio") de las colisiones del mundo que hay a
## la altura de los pies dentro de la zona.
static func obstaculos(espacio: PhysicsDirectSpaceState3D, centro: Vector3, tam: Vector2, radio: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if espacio == null:
		return out
	var caja := BoxShape3D.new()
	caja.size = Vector3(tam.x + radio * 2.0, ALTO_CABEZA - ALTO_PIES, tam.y + radio * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = caja
	q.transform = Transform3D(Basis.IDENTITY, centro + Vector3(0, (ALTO_PIES + ALTO_CABEZA) / 2.0, 0))
	q.collision_mask = Construir.CAPA_MUNDO
	var y0 := centro.y + ALTO_PIES
	var y1 := centro.y + ALTO_CABEZA
	for h: Dictionary in espacio.intersect_shape(q, MAX_FORMAS):
		var cuerpo := h["collider"] as CollisionObject3D
		if cuerpo == null:
			continue
		var dueno := cuerpo.shape_find_owner(int(h["shape"]))
		if cuerpo.shape_owner_get_shape_count(dueno) == 0:
			continue
		var t := cuerpo.global_transform * cuerpo.shape_owner_get_transform(dueno)
		var huella := _huella(cuerpo.shape_owner_get_shape(dueno, 0), t, y0, y1)
		if huella.size() < 3:
			continue
		var grande := Geometry2D.offset_polygon(huella, radio, Geometry2D.JOIN_MITER)
		if not grande.is_empty():
			out.append(Geometry2D.convex_hull(grande[0]))
	return out


## Huella en XZ de una forma (con su transformación) entre las alturas y0 e y1. Vacía si no llega a
## esa franja o si es una forma que no se sabe proyectar.
static func _huella(forma: Shape3D, t: Transform3D, y0: float, y1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if forma is BoxShape3D:
		var m := (forma as BoxShape3D).size / 2.0
		var abajo := INF
		var arriba := -INF
		for i in 8:
			var p := t * Vector3(m.x * (1 if i & 1 else -1), m.y * (1 if i & 2 else -1), m.z * (1 if i & 4 else -1))
			pts.append(Vector2(p.x, p.z))
			abajo = minf(abajo, p.y)
			arriba = maxf(arriba, p.y)
		if arriba < y0 or abajo > y1:
			return PackedVector2Array()
		return Geometry2D.convex_hull(pts)
	if forma is SphereShape3D or forma is CylinderShape3D:
		var r: float
		var c := t.origin
		if forma is SphereShape3D:
			r = (forma as SphereShape3D).radius
			var dy := 0.0 if c.y >= y0 and c.y <= y1 else minf(absf(c.y - y0), absf(c.y - y1))
			if dy >= r:
				return pts
			r = sqrt(r * r - dy * dy)
		else:
			var cil := forma as CylinderShape3D
			if c.y + cil.height / 2.0 < y0 or c.y - cil.height / 2.0 > y1:
				return pts
			r = cil.radius
		for k in 8:
			var ang := TAU * (k + 0.5) / 8.0
			pts.append(Vector2(c.x + cos(ang) * r, c.z + sin(ang) * r))
		return pts
	if forma is ConvexPolygonShape3D:
		var abajo := INF
		var arriba := -INF
		for v in (forma as ConvexPolygonShape3D).points:
			var p := t * v
			pts.append(Vector2(p.x, p.z))
			abajo = minf(abajo, p.y)
			arriba = maxf(arriba, p.y)
		if arriba < y0 or abajo > y1:
			return PackedVector2Array()
		return Geometry2D.convex_hull(pts)
	return pts


## Ruta de "desde" a "hasta" esquivando obstáculos (sin el punto de partida). Vacía si la zona no
## está lista.
static func ruta(z: Dictionary, desde: Vector3, hasta: Vector3) -> PackedVector3Array:
	if z.is_empty() or int(z.get("poligonos", 0)) == 0:
		return PackedVector3Array()
	var mapa: RID = z["mapa"]
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return PackedVector3Array()
	var y := (z["centro"] as Vector3).y
	return NavigationServer3D.map_get_path(mapa, Vector3(desde.x, y, desde.z), Vector3(hasta.x, y, hasta.z), true)


## ¿"p" cae adentro del rectángulo de la zona?
static func dentro(z: Dictionary, p: Vector3) -> bool:
	if z.is_empty():
		return false
	var c: Vector3 = z["centro"]
	var tam: Vector2 = z["tam"]
	return absf(p.x - c.x) <= tam.x / 2.0 and absf(p.z - c.z) <= tam.y / 2.0


## Un punto al azar por donde se puede caminar (o el centro si la zona no está lista).
static func punto_al_azar(z: Dictionary) -> Vector3:
	var c: Vector3 = z.get("centro", Vector3.ZERO)
	if z.is_empty() or int(z.get("poligonos", 0)) == 0 or NavigationServer3D.map_get_iteration_id(z["mapa"]) == 0:
		var tam: Vector2 = z.get("tam", Vector2.ZERO)
		return c + Vector3(randf_range(-0.5, 0.5) * tam.x, 0, randf_range(-0.5, 0.5) * tam.y)
	return NavigationServer3D.map_get_random_point(z["mapa"], 1, true)


## El punto caminable más cercano a "p" (o "p" si la zona no está lista).
static func mas_cercano(z: Dictionary, p: Vector3) -> Vector3:
	if z.is_empty() or int(z.get("poligonos", 0)) == 0 or NavigationServer3D.map_get_iteration_id(z["mapa"]) == 0:
		return p
	return NavigationServer3D.map_get_closest_point(z["mapa"], Vector3(p.x, (z["centro"] as Vector3).y, p.z))


## Libera los mapas (al salir al menú se arma todo de nuevo).
static func limpiar() -> void:
	for z: Dictionary in _zonas.values():
		NavigationServer3D.free_rid(z["region"])
		NavigationServer3D.free_rid(z["mapa"])
	_zonas.clear()
