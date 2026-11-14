class_name ModeloHumano
extends Node3D
## Humano low-poly sin cara: cápsula de color + esfera de cabeza + brazos.
## Se mueve con un rebote simple. Mira hacia -Z.

@export var alto := 1.75
@export var color_ropa := Color("4f7cc4")
@export var color_piernas := Color("3a3f4a")
@export var color_piel := Color("e0b48f")
@export_enum("ninguno", "gorra", "sombrero", "morrion", "mozo") var accesorio := "ninguno"
@export var color_accesorio := Color("c43c3c")
@export var sentado := false

## Capa física de la gente: la jugadora choca contra ella (las palomas NPC no usan física y
## se apartan solas en flock/bandada.gd, que lee el grupo "cuerpos_humanos").
const CAPA_GENTE := 4

static var _mallas := {}

var cuerpo: Node3D
var brazo_izq: Node3D
var brazo_der: Node3D
var _fase := 0.0
var _brazo_levantado := 0.0


func _ready() -> void:
	_armar()
	_crear_cuerpo_fisico()
	add_to_group("cuerpos_humanos")


## Radio y altura del cuerpo para las colisiones.
func radio_colision() -> float:
	return (0.38 if sentado else 0.3) * alto / 1.75


func alto_colision() -> float:
	return alto * (0.8 if sentado else 1.0)


## Cápsula cinemática que sigue al humano: la paloma de la jugadora no lo atraviesa.
func _crear_cuerpo_fisico() -> void:
	var cuerpo_fisico := AnimatableBody3D.new()
	cuerpo_fisico.name = "CuerpoFisico"
	cuerpo_fisico.sync_to_physics = false
	cuerpo_fisico.collision_layer = CAPA_GENTE
	cuerpo_fisico.collision_mask = 0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = radio_colision()
	capsula.height = maxf(alto_colision(), capsula.radius * 2.0)
	forma.shape = capsula
	forma.position.y = capsula.height / 2.0
	cuerpo_fisico.add_child(forma)
	add_child(cuerpo_fisico)


static func _capsula(r: float, h: float) -> CapsuleMesh:
	var clave := "cap_%.2f_%.2f" % [r, h]
	if not _mallas.has(clave):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 8
		m.rings = 2
		_mallas[clave] = m
	return _mallas[clave]


func _pieza(padre: Node3D, malla: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.85)
	mi.position = pos
	padre.add_child(mi)
	return mi


func _armar() -> void:
	var k := alto / 1.75
	cuerpo = Node3D.new()
	add_child(cuerpo)
	var y_cadera := 0.85 * k
	if sentado:
		y_cadera = 0.5 * k
	# Piernas (una cápsula ancha) y torso
	if sentado:
		var piernas := _pieza(cuerpo, _capsula(0.2 * k, 0.75 * k), color_piernas, Vector3(0, y_cadera, -0.25 * k))
		piernas.rotation.x = PI / 2.0
	else:
		_pieza(cuerpo, _capsula(0.2 * k, 0.95 * k), color_piernas, Vector3(0, 0.47 * k, 0))
	_pieza(cuerpo, _capsula(0.26 * k, 0.8 * k), color_ropa, Vector3(0, y_cadera + 0.35 * k, 0))
	# Cabeza (sin cara)
	var y_cabeza := y_cadera + 0.92 * k
	var esf := SphereMesh.new()
	esf.radius = 0.16 * k
	esf.height = 0.32 * k
	esf.radial_segments = 10
	esf.rings = 6
	_pieza(cuerpo, esf, color_piel, Vector3(0, y_cabeza, 0))
	# Brazos con pivote en el hombro
	brazo_izq = _brazo(-1.0, y_cadera + 0.6 * k, k)
	brazo_der = _brazo(1.0, y_cadera + 0.6 * k, k)
	# Accesorios
	match accesorio:
		"gorra":
			_pieza(cuerpo, _capsula(0.15 * k, 0.3 * k), color_accesorio, Vector3(0, y_cabeza + 0.1 * k, 0))
			var visera := BoxMesh.new()
			visera.size = Vector3(0.22, 0.03, 0.18) * k
			_pieza(cuerpo, visera, color_accesorio, Vector3(0, y_cabeza + 0.07 * k, -0.17 * k))
		"sombrero":
			var ala := CylinderMesh.new()
			ala.top_radius = 0.3 * k
			ala.bottom_radius = 0.3 * k
			ala.height = 0.03
			ala.radial_segments = 12
			_pieza(cuerpo, ala, color_accesorio, Vector3(0, y_cabeza + 0.1 * k, 0))
			var copa := CylinderMesh.new()
			copa.top_radius = 0.13 * k
			copa.bottom_radius = 0.15 * k
			copa.height = 0.16 * k
			copa.radial_segments = 10
			_pieza(cuerpo, copa, color_accesorio, Vector3(0, y_cabeza + 0.18 * k, 0))
		"morrion":
			# Morrión alto y oscuro con penacho rojo
			var m := CylinderMesh.new()
			m.top_radius = 0.17 * k
			m.bottom_radius = 0.15 * k
			m.height = 0.4 * k
			m.radial_segments = 10
			_pieza(cuerpo, m, Color("1b1d24"), Vector3(0, y_cabeza + 0.25 * k, 0))
			var pen := SphereMesh.new()
			pen.radius = 0.07 * k
			pen.height = 0.28 * k
			_pieza(cuerpo, pen, color_accesorio, Vector3(0, y_cabeza + 0.55 * k, -0.02))
		"mozo":
			# Moño y bandeja
			var mo := BoxMesh.new()
			mo.size = Vector3(0.14, 0.06, 0.04) * k
			_pieza(cuerpo, mo, Color("111111"), Vector3(0, y_cabeza - 0.22 * k, -0.25 * k))
			var bandeja := CylinderMesh.new()
			bandeja.top_radius = 0.22 * k
			bandeja.bottom_radius = 0.22 * k
			bandeja.height = 0.02
			bandeja.radial_segments = 12
			_pieza(brazo_izq, bandeja, Color("c9ccd1"), Vector3(-0.05, -0.42 * k, -0.2 * k))


func _brazo(lado: float, y: float, k: float) -> Node3D:
	var pivote := Node3D.new()
	pivote.position = Vector3(0.31 * k * lado, y, 0)
	cuerpo.add_child(pivote)
	_pieza(pivote, _capsula(0.07 * k, 0.62 * k), color_ropa, Vector3(0, -0.27 * k, 0))
	_pieza(pivote, _capsula(0.06 * k, 0.12 * k), color_piel, Vector3(0, -0.6 * k, 0))
	return pivote


## Rebote al caminar y braceo. "agitado" levanta los brazos (gritar, espantar, festejar).
func animar(delta: float, velocidad: float, agitado := false) -> void:
	if sentado:
		_fase += delta * 2.0
		cuerpo.position.y = sin(_fase) * 0.01
	elif velocidad > 0.1:
		_fase += delta * (4.0 + velocidad * 2.5)
		cuerpo.position.y = absf(sin(_fase)) * 0.05 * minf(velocidad, 3.0)
		cuerpo.rotation.z = sin(_fase) * 0.04
	else:
		cuerpo.position.y = lerpf(cuerpo.position.y, 0.0, delta * 8.0)
		cuerpo.rotation.z = lerpf(cuerpo.rotation.z, 0.0, delta * 8.0)
	_brazo_levantado = lerpf(_brazo_levantado, 1.0 if agitado else 0.0, minf(delta * 8.0, 1.0))
	var balanceo := sin(_fase) * 0.5 * minf(velocidad, 2.0) / 2.0
	var arriba := _brazo_levantado * (2.6 + sin(_fase * 3.0) * 0.4)
	brazo_izq.rotation = Vector3(balanceo - arriba * 0.3, 0, -arriba * 0.9)
	brazo_der.rotation = Vector3(-balanceo - arriba * 0.3, 0, arriba * 0.9)


## Pasa de parado a sentado (o al revés) rearmando el cuerpo y su cápsula física.
func cambiar_postura(sentar: bool) -> void:
	if sentar == sentado:
		return
	sentado = sentar
	for n: Node in [cuerpo, get_node_or_null("CuerpoFisico")]:
		if n:
			remove_child(n)
			n.queue_free()
	_armar()
	_crear_cuerpo_fisico()


## Gesto de llevarse comida a la boca con el brazo derecho.
func gesto_comer() -> void:
	var tw := create_tween()
	tw.tween_property(brazo_der, "rotation", Vector3(-2.2, 0, 0.5), 0.25)
	tw.tween_interval(0.35)
	tw.tween_property(brazo_der, "rotation", Vector3.ZERO, 0.3)


## Gesto de tirar algo (migas) con el brazo derecho.
func gesto_tirar() -> void:
	var tw := create_tween()
	tw.tween_property(brazo_der, "rotation:x", -1.6, 0.15)
	tw.tween_property(brazo_der, "rotation:x", 0.0, 0.3)


func posicion_mano() -> Vector3:
	return brazo_der.global_position + Vector3.DOWN * 0.4
