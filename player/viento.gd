class_name VientoVuelo
extends MultiMeshInstance3D
## Líneas de viento al volar: rayitas blancas finas que pasan al costado de la cámara.
## Va como hijo de la cámara (coordenadas locales: la cámara mira hacia -Z). Aparecen con la
## velocidad (desde ~7 m/s) y se marcan más en la picada. En el suelo no se ven.
## Todas las rayas son un solo MultiMesh (un dibujo); el alfa de cada una va en su color.

const CANTIDAD := 28
const LEJOS := -13.0
const CERCA := 0.8

var jugador: PalomaJugador
var _pos := PackedVector3Array()
var _rapidez := PackedFloat32Array()
var _intensidad := 0.0


func _ready() -> void:
	var malla := BoxMesh.new()
	malla.size = Vector3(0.018, 0.018, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	malla.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malla
	mm.instance_count = CANTIDAD
	# Caja fija alrededor de la cámara: no hace falta recalcularla cada vez que se mueven
	mm.custom_aabb = AABB(Vector3(-8, -6, LEJOS - 6.0), Vector3(16, 12, -LEJOS + 10.0))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pos.resize(CANTIDAD)
	_rapidez.resize(CANTIDAD)
	for i in CANTIDAD:
		_reubicar(i, true)
		mm.set_instance_color(i, Color(1, 1, 1, 0))
	visible = false


func _process(delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador):
		return
	var vel := jugador.velocity
	var rapidez := vel.length()
	var objetivo := 0.0
	if jugador.estado == PalomaJugador.Estado.AIRE:
		objetivo = clampf((rapidez - 7.0) / 11.0, 0.0, 1.0)
		if jugador.en_picada:
			objetivo = maxf(objetivo, 0.7)
	_intensidad = move_toward(_intensidad, objetivo, delta * 2.0)
	visible = _intensidad > 0.01
	if not visible:
		return
	# Velocidad vista desde la cámara: las rayas se mueven al revés (el aire "pasa")
	var v_local := global_basis.inverse() * vel
	if v_local.length() < 0.5:
		v_local = Vector3(0, 0, -0.5)
	var dir := v_local.normalized()
	var arriba := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var largo := clampf(rapidez * 0.09, 0.5, 2.4)
	var orient := Basis.looking_at(dir, arriba).scaled(Vector3(1, 1, largo))
	var mm := multimesh
	for i in CANTIDAD:
		var p := _pos[i] - v_local * delta * 1.25 * _rapidez[i]
		_pos[i] = p
		if p.z > CERCA or p.z < LEJOS - 2.0 or absf(p.x) > 6.0 or absf(p.y) > 4.0:
			_reubicar(i, false)
			p = _pos[i]
		mm.set_instance_transform(i, Transform3D(orient, p))
		# Se desvanecen al aparecer y al pasar junto a la cámara
		var k := clampf((p.z - LEJOS) / 3.0, 0.0, 1.0) * clampf((CERCA - p.z) / 2.0, 0.0, 1.0)
		mm.set_instance_color(i, Color(1, 1, 1, 0.32 * _intensidad * k))


## Pone una raya adelante, en un anillo alrededor del centro (así no tapa a la paloma).
func _reubicar(i: int, al_azar_en_z: bool) -> void:
	var z := randf_range(LEJOS, -3.0) if al_azar_en_z else randf_range(LEJOS, LEJOS + 2.5)
	var a := randf() * TAU
	var r := randf_range(1.3, 3.4) * clampf(-z / 7.0, 0.6, 1.6)
	_pos[i] = Vector3(cos(a) * r, sin(a) * r * 0.65, z)
	_rapidez[i] = randf_range(0.85, 1.25)
