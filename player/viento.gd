class_name VientoVuelo
extends Node3D
## Líneas de viento al volar: rayitas blancas finas que pasan al costado de la cámara.
## Va como hijo de la cámara (coordenadas locales: la cámara mira hacia -Z). Aparecen con la
## velocidad (desde ~7 m/s) y se marcan más en la picada. En el suelo no se ven.

const CANTIDAD := 28
const LEJOS := -13.0
const CERCA := 0.8

var jugador: PalomaJugador
var _rayas: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _rapidez: PackedFloat32Array = []
var _intensidad := 0.0


func _ready() -> void:
	var malla := BoxMesh.new()
	malla.size = Vector3(0.018, 0.018, 1.0)
	for i in CANTIDAD:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0)
		m.disable_receive_shadows = true
		var mi := MeshInstance3D.new()
		mi.mesh = malla
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_rayas.append(mi)
		_mats.append(m)
		_rapidez.append(1.0)
		_reubicar(i, true)
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
	var orient := Basis.looking_at(dir, arriba)
	var largo := clampf(rapidez * 0.09, 0.5, 2.4)
	for i in CANTIDAD:
		var mi := _rayas[i]
		mi.position -= v_local * delta * 1.25 * _rapidez[i]
		mi.basis = orient.scaled(Vector3(1, 1, largo))
		var p := mi.position
		if p.z > CERCA or p.z < LEJOS - 2.0 or absf(p.x) > 6.0 or absf(p.y) > 4.0:
			_reubicar(i, false)
			p = mi.position
		# Se desvanecen al aparecer y al pasar junto a la cámara
		var k := clampf((p.z - LEJOS) / 3.0, 0.0, 1.0) * clampf((CERCA - p.z) / 2.0, 0.0, 1.0)
		_mats[i].albedo_color.a = 0.32 * _intensidad * k


## Pone una raya adelante, en un anillo alrededor del centro (así no tapa a la paloma).
func _reubicar(i: int, al_azar_en_z: bool) -> void:
	var z := randf_range(LEJOS, -3.0) if al_azar_en_z else randf_range(LEJOS, LEJOS + 2.5)
	var a := randf() * TAU
	var r := randf_range(1.3, 3.4) * clampf(-z / 7.0, 0.6, 1.6)
	_rayas[i].position = Vector3(cos(a) * r, sin(a) * r * 0.65, z)
	_rapidez[i] = randf_range(0.85, 1.25)
