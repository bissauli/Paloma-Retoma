class_name Golpeable
extends RigidBody3D
## Un objeto chico que la paloma puede tirar de un aletazo: tazas, vasos, floreros y azucareras en las
## mesas de los cafés, y los sombreros y gorras que se le caen a la gente (ver Humano.sombrerazo).
## Quieto no cuesta nada: está congelado como un objeto estático hasta que lo golpean. Después se
## comporta como un cuerpo físico (rueda, rebota, choca con el piso y con los demás), suena al caer y,
## pasado un rato, vuelve a su lugar (o, si es un sombrero, se desvanece). No bloquea a la paloma:
## vive en la capa "objetos" (5), que la paloma no mira.

const CAPA_OBJETOS := 16
const TIEMPO_VUELTA := 40.0     ## Segundos hasta volver a su lugar después de un golpe
const VIDA_SOMBRERO := 60.0

## Formas: alto, radio (o lado) y color. "tipo" elige uno.
const TIPOS := {
	"taza": {"color": Color("f4f1ea"), "masa": 0.12},
	"vaso": {"color": Color("9fd8e8"), "masa": 0.1},
	"azucarera": {"color": Color("e8665a"), "masa": 0.14},
	"florero": {"color": Color("4a6fd0"), "masa": 0.18},
	"sombrero": {"color": Color("f2e6c9"), "masa": 0.25},
	"gorra": {"color": Color("c43c3c"), "masa": 0.2},
}

@export var tipo := "taza"
@export var color := Color.WHITE
@export var escala := 1.0
@export var desechable := false     ## Un sombrero: se desvanece solo en vez de volver a su lugar

var golpeado := false
var _origen := Transform3D.IDENTITY
var _t_vuelta := 0.0
var _t_sonido := 0.0
var _visual: Node3D       ## Las mallas (se achica este nodo, no el cuerpo físico)


## Un objeto de mesa en "pos" (global).
static func crear(padre: Node, tipo_objeto: String, pos: Vector3, color_objeto := Color.WHITE,
		escala_objeto := 1.0, es_desechable := false) -> Golpeable:
	var g := Golpeable.new()
	g.tipo = tipo_objeto
	g.color = color_objeto
	g.escala = escala_objeto
	g.desechable = es_desechable
	padre.add_child(g)
	g.global_position = pos
	g.fijar_origen()
	return g


func _ready() -> void:
	add_to_group("golpeables")
	collision_layer = CAPA_OBJETOS
	collision_mask = 1 | CAPA_OBJETOS     # El piso y los demás objetos
	mass = float(TIPOS.get(tipo, TIPOS["taza"])["masa"])
	can_sleep = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.3
	mat.friction = 0.7
	physics_material_override = mat
	if color == Color.WHITE:
		color = TIPOS.get(tipo, TIPOS["taza"])["color"]
	_armar()


## Guarda dónde está (para volver ahí).
func fijar_origen() -> void:
	_origen = global_transform


func _process(delta: float) -> void:
	_t_sonido = maxf(_t_sonido - delta, 0.0)
	if not golpeado:
		return
	_t_vuelta -= delta
	if _t_vuelta > 0.0:
		return
	if desechable:
		golpeado = false
		var tw := create_tween()
		tw.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.4)
		tw.tween_callback(queue_free)
	else:
		_volver()


## Un aletazo: sale despedido hacia "dir" con un saltito y un giro.
func golpear(dir: Vector3, fuerza := 1.0) -> bool:
	if _origen == Transform3D.IDENTITY and not desechable:
		fijar_origen()
	freeze = false
	var d := dir.rotated(Vector3.UP, randf_range(-0.3, 0.3))
	apply_central_impulse((d * randf_range(2.4, 3.6) + Vector3.UP * randf_range(1.4, 2.2)) * mass * fuerza)
	apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * mass * 0.35)
	if not golpeado:
		golpeado = true
		contact_monitor = true
		max_contacts_reported = 3
		body_entered.connect(_al_chocar)
	_t_vuelta = VIDA_SOMBRERO if desechable else TIEMPO_VUELTA
	return true


func _al_chocar(_cuerpo: Node) -> void:
	if _t_sonido > 0.0 or linear_velocity.length() < 0.8:
		return
	_t_sonido = 0.25
	var nombre := "tintineo" if tipo in ["taza", "vaso", "azucarera", "florero"] else "picoteo"
	AudioManager.reproducir_en(nombre, global_position, -6.0 if nombre == "tintineo" else -14.0)


func _volver() -> void:
	golpeado = false
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _origen
	reset_physics_interpolation()
	_visual.scale = Vector3.ONE * 0.1
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Forma y aspecto

func _armar() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var k := escala
	var forma := CollisionShape3D.new()
	match tipo:
		"taza":
			forma.shape = _cilindro_forma(0.045 * k, 0.08 * k)
			forma.position.y = 0.04 * k
			_malla(_cilindro(0.045 * k, 0.04 * k, 0.08 * k), color, Vector3(0, 0.04 * k, 0))
			_malla(_caja(Vector3(0.025, 0.04, 0.012) * k), color, Vector3(0.055 * k, 0.045 * k, 0))   # Oreja
			_malla(_cilindro(0.04 * k, 0.04 * k, 0.005 * k), Color("5a3a24"), Vector3(0, 0.078 * k, 0))   # Café
		"vaso":
			forma.shape = _cilindro_forma(0.035 * k, 0.12 * k)
			forma.position.y = 0.06 * k
			_malla(_cilindro(0.037 * k, 0.03 * k, 0.12 * k), color, Vector3(0, 0.06 * k, 0))
		"azucarera":
			forma.shape = BoxShape3D.new()
			(forma.shape as BoxShape3D).size = Vector3(0.07, 0.07, 0.07) * k
			forma.position.y = 0.035 * k
			_malla(_caja(Vector3(0.07, 0.07, 0.07) * k), color, Vector3(0, 0.035 * k, 0))
			_malla(_caja(Vector3(0.075, 0.015, 0.075) * k), color.darkened(0.25), Vector3(0, 0.075 * k, 0))
		"florero":
			forma.shape = _cilindro_forma(0.04 * k, 0.16 * k)
			forma.position.y = 0.08 * k
			_malla(_cilindro(0.04 * k, 0.03 * k, 0.16 * k), color, Vector3(0, 0.08 * k, 0))
			for i in 3:
				var a := i * TAU / 3.0
				_malla(_caja(Vector3(0.012, 0.1, 0.012) * k), Color("4a8a3a"), Vector3(sin(a) * 0.015 * k, 0.2 * k, cos(a) * 0.015 * k))
				_malla(_esfera(0.025 * k), [Color("ff6fa5"), Color("ffd84a"), Color("ffffff")][i], Vector3(sin(a) * 0.03 * k, 0.26 * k, cos(a) * 0.03 * k))
		"sombrero":
			forma.shape = _cilindro_forma(0.28 * k, 0.1 * k)
			forma.position.y = 0.05 * k
			_malla(_cilindro(0.3 * k, 0.3 * k, 0.03), color, Vector3(0, 0.015, 0))
			_malla(_cilindro(0.13 * k, 0.15 * k, 0.16 * k), color, Vector3(0, 0.09 * k, 0))
			_malla(_cilindro(0.152 * k, 0.152 * k, 0.03 * k), color.darkened(0.45), Vector3(0, 0.04 * k, 0))   # Cinta
		"gorra":
			forma.shape = SphereShape3D.new()
			(forma.shape as SphereShape3D).radius = 0.14 * k
			forma.position.y = 0.12 * k
			var cupula := _esfera(0.15 * k)
			_malla(cupula, color, Vector3(0, 0.11 * k, 0), Vector3(1, 0.8, 1))
			_malla(_caja(Vector3(0.22, 0.03, 0.18) * k), color.darkened(0.2), Vector3(0, 0.03 * k, -0.17 * k))   # Visera
	add_child(forma)


func _cilindro_forma(r: float, alto: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = alto
	return c


func _cilindro(r_arriba: float, r_abajo: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_arriba
	c.bottom_radius = r_abajo
	c.height = alto
	c.radial_segments = 10
	c.rings = 1
	return c


func _caja(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


func _malla(m: Mesh, c: Color, pos: Vector3, esc := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Construir.material(c, 0.7)
	mi.position = pos
	mi.scale = esc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)
