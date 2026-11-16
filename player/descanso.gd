class_name Descanso
extends RefCounted
## Calcula los lugares donde se sientan las palomas de la bandada cuando la jugadora descansa (Q).
## - En una fuente: en fila alrededor del borde, a los dos lados de la jugadora.
## - En un balcón: sobre el piso del balcón y, si no entran, en los balcones colindantes.
## - En cualquier otra superficie (cables, cornisas, barandas, el piso): se expande desde la
##   jugadora por todo lo que sea transitable y esté a una altura parecida (izquierda y derecha en un cable).

const SEPARACION := 0.45          ## Distancia mínima entre dos palomas sentadas
const PASO := 0.25                ## Paso de la grilla de búsqueda de superficies
const RADIO_DISCO := 0.12
const SALTO_MAX := 0.25           ## Desnivel máximo entre dos celdas vecinas
const ALCANCE_BALCONES := 16.0
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


## Hasta "cantidad" puestos (posiciones globales de las patas), los más cercanos a la jugadora primero.
static func puestos(jugador: PalomaJugador, cantidad: int) -> Array[Vector3]:
	var fuente := _fuente_bajo(jugador)
	if fuente:
		return _en_fuente(jugador, fuente, cantidad)
	var balcones := _balcones_cerca(jugador)
	if not balcones.is_empty():
		return _en_balcones(jugador, balcones, cantidad)
	return _por_superficie(jugador, cantidad)


# ---------------------------------------------------------------- Fuentes

static func _fuente_bajo(jugador: PalomaJugador) -> Fuente:
	var pj := jugador.global_position
	for n in jugador.get_tree().get_nodes_in_group("fuentes"):
		var f := n as Fuente
		if f == null or f.altura <= 0.0:
			continue
		var d := pj - f.global_position
		if Vector2(d.x, d.z).length() <= f.radio + 0.5 and absf(pj.y - (f.global_position.y + f.altura)) < 0.6:
			return f
	return null


static func _en_fuente(jugador: PalomaJugador, f: Fuente, cantidad: int) -> Array[Vector3]:
	var res: Array[Vector3] = []
	var pj := jugador.global_position
	var c := f.global_position
	var r := f.radio + 0.2
	var y := c.y + f.altura
	var d := pj - c
	var a0 := atan2(d.z, d.x) if Vector2(d.x, d.z).length() > 0.3 else jugador.rumbo()
	var paso := SEPARACION / r
	var total := int(TAU / paso)
	for k in total:
		if res.size() >= cantidad:
			break
		# 0, +1, -1, +2, -2...: a los dos lados de la jugadora
		var salto: int = (k + 1) / 2 if k % 2 == 1 else -(k / 2)   # @warning_ignore("integer_division")
		var a := a0 + salto * paso
		var p := Vector3(c.x + cos(a) * r, y, c.z + sin(a) * r)
		if _lejos_de(p, pj):
			res.append(p)
	return res


# ---------------------------------------------------------------- Balcones

## Los balcones (marcadores del grupo "balcones_percha", ver NivelMedio.balcon) a la misma altura
## y cerca. Vacío si la jugadora no está parada en uno.
static func _balcones_cerca(jugador: PalomaJugador) -> Array[Marker3D]:
	var pj := jugador.global_position
	var propio: Marker3D = null
	for n in jugador.get_tree().get_nodes_in_group("balcones_percha"):
		var m := n as Marker3D
		if m == null:
			continue
		var l := m.global_transform.affine_inverse() * pj
		var ancho: float = m.get_meta("ancho", 2.3)
		var salida: float = m.get_meta("salida", 1.1)
		if absf(l.x) <= ancho / 2.0 + 0.15 and l.z >= -0.1 and l.z <= salida + 0.15 and absf(l.y) < 0.5:
			propio = m
			break
	var lista: Array[Marker3D] = []
	if propio == null:
		return lista
	for n in jugador.get_tree().get_nodes_in_group("balcones_percha"):
		var m := n as Marker3D
		if m and absf(m.global_position.y - propio.global_position.y) < 0.6 \
				and m.global_position.distance_to(pj) <= ALCANCE_BALCONES:
			lista.append(m)
	return lista


static func _en_balcones(jugador: PalomaJugador, balcones: Array[Marker3D], cantidad: int) -> Array[Vector3]:
	var pj := jugador.global_position
	var todos: Array[Vector3] = []
	for m in balcones:
		var ancho: float = m.get_meta("ancho", 2.3)
		var salida: float = m.get_meta("salida", 1.1)
		var filas: Array[float] = [salida - 0.3]
		if salida >= 0.9:
			filas.append(salida - 0.75)
		var n := maxi(int((ancho - 0.5) / SEPARACION) + 1, 1)
		for fz in filas:
			for i in n:
				var lx := (i - (n - 1) / 2.0) * SEPARACION
				var p := m.global_transform * Vector3(lx, 0.0, fz - salida / 2.0)
				if _lejos_de(p, pj):
					todos.append(p)
	todos.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(pj) < b.distance_squared_to(pj))
	var res: Array[Vector3] = []
	for p in todos:
		if res.size() >= cantidad:
			break
		res.append(p)
	return res


# ---------------------------------------------------------------- Cualquier superficie

static func _por_superficie(jugador: PalomaJugador, cantidad: int) -> Array[Vector3]:
	var pj := jugador.global_position
	var espacio := jugador.get_world_3d().direct_space_state
	var forma := CylinderShape3D.new()
	forma.radius = RADIO_DISCO
	forma.height = 0.02
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = Construir.CAPA_MUNDO
	q.motion = Vector3(0, -0.7, 0)

	var alturas := {Vector2i.ZERO: pj.y}
	var cola: Array[Vector2i] = [Vector2i.ZERO]
	var visitadas := {Vector2i.ZERO: true}
	var tope := maxi(cantidad * 12, 60)
	var i := 0
	while i < cola.size() and alturas.size() < tope:
		var c := cola[i]
		i += 1
		var y_ref: float = alturas[c]
		for d in DIRS:
			var v := c + d
			if visitadas.has(v):
				continue
			visitadas[v] = true
			var x := pj.x + v.x * PASO
			var z := pj.z + v.y * PASO
			var y := _altura(espacio, q, x, y_ref + 0.4, z)
			if is_nan(y) or absf(y - y_ref) > SALTO_MAX:
				continue
			alturas[v] = y
			cola.append(v)

	var candidatas: Array[Vector3] = []
	for c: Vector2i in alturas:
		var p := Vector3(pj.x + c.x * PASO, alturas[c], pj.z + c.y * PASO)
		if _lejos_de(p, pj):
			candidatas.append(p)
	candidatas.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(pj) < b.distance_squared_to(pj))
	var res: Array[Vector3] = []
	for p in candidatas:
		if res.size() >= cantidad:
			break
		var libre := true
		for o in res:
			if absf(o.y - p.y) < 0.5 and Vector2(o.x - p.x, o.z - p.z).length() < SEPARACION:
				libre = false
				break
		if libre:
			res.append(p)
	return res


## Altura de la superficie transitable bajo (x, z): un disco finito que cae desde "y_inicio".
## NAN si no hay nada (o si arranca adentro de algo).
static func _altura(espacio: PhysicsDirectSpaceState3D, q: PhysicsShapeQueryParameters3D, x: float,
		y_inicio: float, z: float) -> float:
	q.transform = Transform3D(Basis.IDENTITY, Vector3(x, y_inicio, z))
	var r := espacio.cast_motion(q)
	if r.size() < 2 or r[0] <= 0.0 or r[0] >= 1.0:
		return NAN
	return y_inicio - r[0] * 0.7 - 0.01


static func _lejos_de(p: Vector3, pj: Vector3) -> bool:
	return Vector2(p.x - pj.x, p.z - pj.z).length() >= SEPARACION + 0.05 or absf(p.y - pj.y) > 0.5
