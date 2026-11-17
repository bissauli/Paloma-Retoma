class_name Calesita
extends RefCounted
## La parte que gira de la calesita (ver Animado "girar") con colisión y los lugares para sentarse:
## la columna del centro, el techo y los seis caballitos son sólidos (giran con ella); cada caballito
## tiene un marcador del grupo "caballitos" donde se sienta la paloma (ver PalomaJugador.montar).
## Las medidas salen de tools/blender/generar_ciudad.py (calesita_giro): columna de radio 0,55,
## techo cónico entre 3,3 y 4,6 m, caballitos a 2,75 m del centro.

const CABALLITOS := 6
const RADIO_CABALLITOS := 2.75
const RADIO_TECHO := 4.2
const RADIO_COLUMNA := 0.55
const ENTRADA := 5.3              ## A qué distancia del centro se paran los chicos para subir
const ALTO_SILLA := 0.22          ## Cuánto arriba del centro del caballito se apoya la paloma


## Altura del centro del caballito k (alternan alto y bajo, como en el modelo).
static func altura(k: int) -> float:
	return 1.15 + 0.2 * (k % 2)


static func armar(cal: Animado, centro_mundo: Vector3) -> void:
	var cuerpo := AnimatableBody3D.new()
	cuerpo.name = "Solidos"
	cuerpo.sync_to_physics = false
	cuerpo.collision_layer = 1
	cuerpo.collision_mask = 0
	cal.add_child(cuerpo)

	# Columna central
	var col := CylinderShape3D.new()
	col.radius = RADIO_COLUMNA
	col.height = 3.3 - 0.45
	_forma(cuerpo, col, Transform3D(Basis.IDENTITY, Vector3(0, (0.45 + 3.3) / 2.0, 0)))

	# Techo cónico
	var puntos := PackedVector3Array()
	for k in 12:
		var a := TAU * k / 12.0
		puntos.append(Vector3(cos(a) * RADIO_TECHO, 3.3, sin(a) * RADIO_TECHO))
	puntos.append(Vector3(0, 4.6, 0))
	var techo := ConvexPolygonShape3D.new()
	techo.points = puntos
	_forma(cuerpo, techo, Transform3D.IDENTITY)

	# Caballitos: una caja cada uno y el marcador donde se sienta la paloma
	for k in CABALLITOS:
		var a := TAU * k / float(CABALLITOS)
		var h := altura(k)
		var centro := Vector3(cos(a) * RADIO_CABALLITOS, h, -sin(a) * RADIO_CABALLITOS)
		# La cabeza mira en la dirección de giro (tangente): el frente (-Z) apunta a (sin a, 0, cos a)
		var giro := Basis(Vector3.UP, a + PI)
		var caja := BoxShape3D.new()
		caja.size = Vector3(0.4, 0.7, 1.15)
		_forma(cuerpo, caja, Transform3D(giro, centro + giro * Vector3(0, -0.15, -0.1)))
		var m := Marker3D.new()
		m.name = "Caballito%d" % k
		m.add_to_group("caballitos")
		m.set_meta("indice", k)
		cal.add_child(m)
		m.transform = Transform3D(giro, centro + Vector3(0, ALTO_SILLA, 0))
		# Los chicos usan los mismos caballitos: suben desde afuera de la calesita
		var radial := Vector3(cos(a), 0.0, -sin(a))
		cal.asientos.append([m.transform, centro_mundo + radial * ENTRADA])


static func _forma(cuerpo: Node3D, forma: Shape3D, t: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.transform = t
	cuerpo.add_child(cs)
