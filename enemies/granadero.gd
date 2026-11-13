class_name Granadero
extends Node3D
## Granadero: patrulla frente a la Casa Rosada con un cono de visión (visible en el piso).
## Si te ve cerca de la Casa Rosada sin 30 palomas, silba y volvés al nido.
## Con 30 palomas o más se distrae mirando la bandada y te deja pasar.

@export var desde_z := -16.0
@export var hasta_z := 16.0
@export var velocidad := 1.2
@export var radio_vision := 13.0
@export var angulo_vision := 40.0          ## Grados a cada lado
@export var tiempo_reaccion := 0.6         ## Cuánto tiene que verte antes de silbar

var _sentido := 1.0
var _rumbo := 0.0
var _mirar_extra := 0.0
var _visto := 0.0
var _pausa := 0.0
var _cono: MeshInstance3D
var _mat_cono: StandardMaterial3D
var _signo: Label3D

@onready var modelo: ModeloHumano = $Modelo


func _ready() -> void:
	add_to_group("enemigos")
	_sentido = 1.0 if randf() < 0.5 else -1.0
	_crear_cono()
	_signo = Label3D.new()
	_signo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_signo.font_size = 120
	_signo.outline_size = 18
	_signo.pixel_size = 0.006
	_signo.position = Vector3(0, 2.7, 0)
	add_child(_signo)


func _crear_cono() -> void:
	# Abanico plano en el piso que muestra hacia dónde mira
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pasos := 12
	var ang := deg_to_rad(angulo_vision)
	for i in pasos:
		var a0 := -ang + 2.0 * ang * i / pasos
		var a1 := -ang + 2.0 * ang * (i + 1) / pasos
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(-sin(a1), 0, -cos(a1)) * radio_vision)
		st.add_vertex(Vector3(-sin(a0), 0, -cos(a0)) * radio_vision)
	_cono = MeshInstance3D.new()
	_cono.mesh = st.commit()
	_mat_cono = StandardMaterial3D.new()
	_mat_cono.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_cono.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cono.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cono.albedo_color = Color(1.0, 0.9, 0.3, 0.18)
	_cono.material_override = _mat_cono
	_cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cono.position.y = 0.05
	add_child(_cono)


func _distraido() -> bool:
	return GameState.bandada >= Config.UMBRAL_BALCON or GameState.partida_terminada


func _physics_process(delta: float) -> void:
	var j := get_tree().get_first_node_in_group("jugador") as Node3D
	var distraido := _distraido()
	# Patrulla: camina de punta a punta, frena y mira hacia la plaza
	if _pausa > 0.0:
		_pausa -= delta
		_mirar_extra = lerpf(_mirar_extra, -PI / 2.0 * _sentido, minf(delta * 3.0, 1.0))
	else:
		_mirar_extra = lerpf(_mirar_extra, 0.0, minf(delta * 3.0, 1.0))
		global_position.z += _sentido * velocidad * delta
		if (global_position.z > hasta_z and _sentido > 0.0) or (global_position.z < desde_z and _sentido < 0.0):
			_sentido = -_sentido
			_pausa = 2.5
	var base := 0.0 if _sentido < 0.0 else PI   # Mira hacia donde camina (-Z o +Z)
	_rumbo = lerp_angle(_rumbo, base + _mirar_extra, minf(delta * 4.0, 1.0))
	if distraido and j:
		# Distraído: mira embobado a la bandada
		var hacia := j.global_position - global_position
		_rumbo = lerp_angle(_rumbo, atan2(-hacia.x, -hacia.z), minf(delta * 3.0, 1.0))
	modelo.rotation.y = _rumbo
	_cono.rotation.y = _rumbo
	modelo.animar(delta, velocidad if _pausa <= 0.0 else 0.0, distraido and fmod(Time.get_ticks_msec() / 600.0, 2.0) < 1.0)

	_cono.visible = not distraido
	if distraido:
		_signo.text = "♪"
		_signo.modulate = Color(1, 0.8, 0.9)
		_visto = 0.0
		return
	_signo.text = "!" if _visto > 0.0 else ""
	_signo.modulate = Color(1, 0.3, 0.2)
	if j and _ve(j):
		_visto += delta
		_mat_cono.albedo_color = Color(1.0, 0.3, 0.2, 0.3)
		if _visto >= tiempo_reaccion:
			_atrapar()
	else:
		_visto = maxf(_visto - delta, 0.0)
		_mat_cono.albedo_color = Color(1.0, 0.9, 0.3, 0.18)


func _ve(j: Node3D) -> bool:
	if GameState.invulnerable > 0.0:
		return false
	# Sólo cuenta si estás "cerca de la Casa Rosada" (pasando las vallas o arriba del balcón)
	if j.global_position.x < 30.0:
		return false
	var hacia := j.global_position - global_position
	var plano := Vector3(hacia.x, 0, hacia.z)
	if plano.length() > radio_vision or hacia.y > 12.0:
		return false
	if plano.length() < 2.5:
		return true
	var mira := Vector3(-sin(_rumbo), 0, -cos(_rumbo))
	return rad_to_deg(mira.angle_to(plano)) < angulo_vision


func _atrapar() -> void:
	_visto = 0.0
	AudioManager.reproducir_en("silbato", global_position, 4.0)
	if GameState.atrapar("granadero", Config.PERDIDA_GRANADERO, global_position, true):
		GameState.mensaje.emit("¡PRRRIIIT! Un granadero te vio. Necesitás %d palomas para acercarte." % Config.UMBRAL_BALCON, 3.5)
