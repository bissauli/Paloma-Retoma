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
	"maceta": {"color": Color("b86a4a"), "masa": 0.6},
	# Lo de los locales de la planta baja (ver PlanoLocal.objetos): mercadería sobre mostradores y mesas
	"lata": {"color": Color("c8423a"), "masa": 0.15},
	"botella": {"color": Color("3f8a4a"), "masa": 0.25},
	"caja": {"color": Color("f2c23a"), "masa": 0.12},
	"fruta": {"color": Color("d8402e"), "masa": 0.12},
	"libro": {"color": Color("2f5a8a"), "masa": 0.2},
	"pan": {"color": Color("c98a4a"), "masa": 0.1},
	"frasco": {"color": Color("f4f4f4"), "masa": 0.12},
	"queso": {"color": Color("f2d070"), "masa": 0.2},
}
## Los que suenan a vidrio o loza al caer (los demás, un golpe sordo).
const DE_VIDRIO := ["taza", "vaso", "azucarera", "florero", "maceta", "botella", "frasco"]

## Sólo para la "maceta": color de las hojas y de las flores ("" = sin flores).
var color_hojas := Color("4a8a3a")
var color_flor := Color.TRANSPARENT

@export var tipo := "taza"
@export var color := Color.WHITE
@export var escala := 1.0
@export var desechable := false     ## Un sombrero: se desvanece solo en vez de volver a su lugar

## Si está, se dibuja esta malla (con color en los vértices y el origen en el centro de su base) en vez de la
## forma del tipo: los sombreros que se le vuelan a la gente son el mismo que tenían puesto.
var malla_propia: Mesh = null
var golpeado := false
var _origen := Transform3D.IDENTITY
var _t_vuelta := 0.0
var _t_sonido := 0.0
var _visual: Node3D       ## Las mallas (se achica este nodo, no el cuerpo físico)
var _piezas: Array = []   ## [malla, transformación, color] de cada pieza: se funden en una sola malla (_fusionar)

## Desde esta distancia (m) no se dibuja: son cosas de unos centímetros y hay cientos en los cafés y locales
const RANGO_VISIBLE := 45.0
## Hasta dónde se dibuja este (adentro de un local, desde la calle casi no se ve: más cerca)
var rango_visible := RANGO_VISIBLE


## Un objeto de mesa en "pos" (global).
static func crear(padre: Node, tipo_objeto: String, pos: Vector3, color_objeto := Color.WHITE,
		escala_objeto := 1.0, es_desechable := false, malla: Mesh = null, rango := RANGO_VISIBLE) -> Golpeable:
	var g := Golpeable.new()
	g.rango_visible = rango
	g.malla_propia = malla
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
	continuous_cd = true      # Chico y rápido: sin esto atraviesa paredes finas
	if tipo in ["sombrero", "gorra"]:
		linear_damp = 3.0      # Se frenan enseguida, fáciles de alcanzar
		angular_damp = 6.0
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.1 if tipo in ["sombrero", "gorra"] else 0.3
	mat.friction = 1.2 if tipo in ["sombrero", "gorra"] else 0.7
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
	# Si hay una pared justo en esa dirección, sale despedido hacia arriba y no contra ella
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1,
		global_position + Vector3.UP * 0.1 + d * 0.6, 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		d *= 0.15
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
	var nombre := "tintineo" if tipo in DE_VIDRIO else "picoteo"
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
	if malla_propia:
		var aabb := malla_propia.get_aabb()
		var r := maxf(aabb.size.x, aabb.size.z) * 0.45
		forma.shape = _cilindro_forma(r, maxf(aabb.size.y * 0.6, 0.04))
		forma.position.y = (forma.shape as CylinderShape3D).height / 2.0
		add_child(forma)
		var mi := MeshInstance3D.new()
		mi.mesh = malla_propia
		mi.material_override = Construir.material_vertices(0.85)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mi)
		return
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
		"maceta":
			var r := 0.15 * k
			var alto := 0.27 * k
			forma.shape = _cilindro_forma(r, alto)
			forma.position.y = alto / 2.0
			_malla(_cilindro(r, r * 0.8, alto), color, Vector3(0, alto / 2.0, 0))
			var rp := r * 1.4
			_malla(_esfera(rp), color_hojas, Vector3(0, alto + rp * 0.6, 0), Vector3(1, 0.85, 1))
			if color_flor.a > 0.0:
				for i in 3:
					var a := TAU * i / 3.0 + 0.4
					_malla(_esfera(0.06 * k), color_flor, Vector3(cos(a) * rp * 0.6, alto + rp * 1.05, sin(a) * rp * 0.6))
		"sombrero":
			forma.shape = _cilindro_forma(0.28 * k, 0.1 * k)
			forma.position.y = 0.05 * k
			_malla(_cilindro(0.3 * k, 0.3 * k, 0.03), color, Vector3(0, 0.015, 0))
			_malla(_cilindro(0.13 * k, 0.15 * k, 0.16 * k), color, Vector3(0, 0.09 * k, 0))
			_malla(_cilindro(0.152 * k, 0.152 * k, 0.03 * k), color.darkened(0.45), Vector3(0, 0.04 * k, 0))   # Cinta
		"gorra":
			forma.shape = _cilindro_forma(0.15 * k, 0.1 * k)   # Plana: no rueda como una esfera
			forma.position.y = 0.05 * k
			var cupula := _esfera(0.15 * k)
			_malla(cupula, color, Vector3(0, 0.11 * k, 0), Vector3(1, 0.8, 1))
			_malla(_caja(Vector3(0.22, 0.03, 0.18) * k), color.darkened(0.2), Vector3(0, 0.03 * k, -0.17 * k))   # Visera
		"lata":
			forma.shape = _cilindro_forma(0.035 * k, 0.11 * k)
			forma.position.y = 0.055 * k
			_malla(_cilindro(0.035 * k, 0.035 * k, 0.11 * k), color, Vector3(0, 0.055 * k, 0))
			_malla(_cilindro(0.03 * k, 0.03 * k, 0.012 * k), Color("c8ccd0"), Vector3(0, 0.112 * k, 0))   # Tapa
			_malla(_cilindro(0.036 * k, 0.036 * k, 0.03 * k), Color.WHITE, Vector3(0, 0.06 * k, 0))   # Etiqueta
		"botella":
			forma.shape = _cilindro_forma(0.035 * k, 0.26 * k)
			forma.position.y = 0.13 * k
			_malla(_cilindro(0.035 * k, 0.035 * k, 0.18 * k), color, Vector3(0, 0.09 * k, 0))
			_malla(_cilindro(0.014 * k, 0.034 * k, 0.06 * k), color, Vector3(0, 0.21 * k, 0))   # Cuello
			_malla(_cilindro(0.016 * k, 0.016 * k, 0.025 * k), Color("e8c040"), Vector3(0, 0.25 * k, 0))   # Tapita
			_malla(_cilindro(0.036 * k, 0.036 * k, 0.06 * k), Color("f4f1e8"), Vector3(0, 0.08 * k, 0))   # Etiqueta
		"caja":
			forma.shape = BoxShape3D.new()
			(forma.shape as BoxShape3D).size = Vector3(0.12, 0.16, 0.06) * k
			forma.position.y = 0.08 * k
			_malla(_caja(Vector3(0.12, 0.16, 0.06) * k), color, Vector3(0, 0.08 * k, 0))
			_malla(_caja(Vector3(0.08, 0.05, 0.062) * k), Color.WHITE, Vector3(0, 0.1 * k, 0))   # Etiqueta
		"fruta":
			forma.shape = SphereShape3D.new()
			(forma.shape as SphereShape3D).radius = 0.045 * k
			forma.position.y = 0.045 * k
			_malla(_esfera(0.045 * k), color, Vector3(0, 0.045 * k, 0))
			_malla(_caja(Vector3(0.008, 0.025, 0.008) * k), Color("5a3a24"), Vector3(0, 0.095 * k, 0))   # Cabito
		"libro":
			forma.shape = BoxShape3D.new()
			(forma.shape as BoxShape3D).size = Vector3(0.15, 0.04, 0.21) * k
			forma.position.y = 0.02 * k
			_malla(_caja(Vector3(0.15, 0.04, 0.21) * k), color, Vector3(0, 0.02 * k, 0))
			_malla(_caja(Vector3(0.14, 0.03, 0.005) * k), Color("f4f1e8"), Vector3(0.004 * k, 0.02 * k, 0.104 * k))   # Hojas
		"pan":
			forma.shape = _cilindro_forma(0.05 * k, 0.07 * k)
			forma.position.y = 0.035 * k
			_malla(_esfera(0.06 * k), color, Vector3(0, 0.035 * k, 0), Vector3(1.8, 0.65, 1.0))
			for i in 3:   # Cortes de arriba
				_malla(_caja(Vector3(0.012, 0.01, 0.07) * k), color.lightened(0.35), Vector3((i - 1) * 0.04 * k, 0.07 * k, 0))
		"frasco":
			forma.shape = _cilindro_forma(0.03 * k, 0.1 * k)
			forma.position.y = 0.05 * k
			_malla(_cilindro(0.03 * k, 0.03 * k, 0.08 * k), color, Vector3(0, 0.04 * k, 0))
			_malla(_cilindro(0.022 * k, 0.022 * k, 0.025 * k), Color("3f9a5a"), Vector3(0, 0.09 * k, 0))   # Tapa
		"queso":
			forma.shape = BoxShape3D.new()
			(forma.shape as BoxShape3D).size = Vector3(0.14, 0.08, 0.1) * k
			forma.position.y = 0.04 * k
			_malla(_caja(Vector3(0.14, 0.08, 0.1) * k), color, Vector3(0, 0.04 * k, 0))
			for i in 2:   # Agujeros
				_malla(_esfera(0.012 * k), color.darkened(0.25), Vector3((i - 0.5) * 0.06 * k, 0.05 * k, 0.05 * k))
	add_child(forma)
	_fusionar()


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
	_piezas.append([m, Transform3D(Basis.from_scale(esc), pos), c])


## Todas las piezas en una sola malla con el color en los vértices: un dibujo por objeto en vez de hasta 7.
func _fusionar() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Construir.combinar(_piezas, true)
	mi.material_override = Construir.material_vertices(0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = rango_visible * (0.7 if Ajustes.movil else 1.0)
	mi.visibility_range_end_margin = 3.0
	_visual.add_child(mi)
	_piezas.clear()
