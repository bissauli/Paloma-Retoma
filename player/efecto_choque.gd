class_name EfectoChoque
extends RefCounted
## Los efectos de cuando la paloma se estrella contra una pared a toda velocidad (como el choque del
## gato de Little Kitty, Big City): una columna de polvo blanco en el punto del golpe y, mientras está
## aturdida, un halo de estrellitas que giran sobre la cabeza. Ver PalomaJugador.chocar.

const POLVO_VIDA := 1.0
const ESTRELLAS := 4
const COLOR_ESTRELLA := Color("ffd84a")


## Una nube de polvo que sube pegada a la pared: "pos" es el punto del golpe y "normal" hacia donde
## mira la pared. Se borra sola.
static func polvo(mundo: Node, pos: Vector3, normal: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "PolvoChoque"
	p.one_shot = true
	p.amount = 28
	p.lifetime = POLVO_VIDA
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	p.direction = (normal + Vector3.UP * 1.2).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, 0.9, 0)     # El polvo flota hacia arriba
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.4))
	curva.add_point(Vector2(0.3, 1.0))
	curva.add_point(Vector2(1.0, 0.3))
	p.scale_amount_curve = curva
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 0.95))
	degrade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = degrade
	var malla := SphereMesh.new()
	malla.radius = 0.2
	malla.height = 0.4
	malla.radial_segments = 8
	malla.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.96, 0.97, 1.0)
	malla.material = mat
	p.mesh = malla
	mundo.add_child(p)
	p.global_position = pos + normal * 0.2
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## El halo de estrellas que gira sobre la cabeza. Devuelve el nodo (el modelo lo agrega y lo borra).
static func halo() -> Node3D:
	var h := Node3D.new()
	h.name = "HaloAturdida"
	for i in ESTRELLAS:
		var e := Label3D.new()
		e.text = "★"
		e.font_size = 72
		e.pixel_size = 0.004
		e.modulate = COLOR_ESTRELLA
		e.outline_size = 10
		e.outline_modulate = Color(0.45, 0.3, 0.0)
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		e.no_depth_test = true
		var a := TAU * i / ESTRELLAS
		e.position = Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3)
		h.add_child(e)
	return h
