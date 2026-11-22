class_name Fuente
extends Node3D
## Una fuente (con surtidor y un borde de piedra: la paloma aterriza y camina en el agua) o un charco
## (un disco de agua en el piso). Con la paloma en el agua aparece "E · BAÑARSE" (en el teléfono
## se baña sola si se queda quieta un segundo) y hace el baño de verdad (Coreografia.BANO): se agacha,
## zambulle la cabeza, aletea y se sacude, con salpicaduras, ondas y sonido. Se corta como cualquier
## baile (moverse, volar, picotear, arrullar). Mientras se baña recarga la stamina, y al llegar a 3 s
## sale "fresquita": stamina llena y el logro. Los crea world/plaza.gd; sólo hay baño de agua.

const TIEMPO_PREMIO := 3.0
const RECARGA := 30.0          ## Stamina por segundo mientras se baña
const RETARDO_AUTO := 1.0      ## En el teléfono: segundos quieta en el agua antes de bañarse

@export var radio := 2.2        ## Radio del agua
@export var altura := 0.0       ## Altura a la que se apoya la paloma (0 = charco en el piso)
@export var surtidor := false
var solo_bano := false          ## Sólo la zona de baño: la fuente (modelo y colisión) ya la puso otro (ver crear_bano)

var _y_agua := 0.0
var _chorro: CPUParticles3D
var _salpicadura: CPUParticles3D
var _rafaga: CPUParticles3D
var _aviso_puesto := false
var _banando := false
var _t_bano := 0.0
var _t_onda := 0.0
var _t_sonido := 0.0
var _t_quieta := 0.0
var _premiada := false


## Crea una fuente (altura > 0) o un charco (altura 0) en "pos".
static func crear(padre: Node3D, pos: Vector3, radio_agua: float, altura_agua := 0.0, con_surtidor := false) -> Fuente:
	# El builder de administrador puede moverla, girarla o borrarla (ver MapaOverrides)
	var r := MapaOverrides.resolver("fuente", "fuente", pos, 0.0, Vector3.ONE)
	if r["borrado"] and not MapaOverrides.modo_admin:
		return null
	var f := Fuente.new()
	f.radio = radio_agua
	f.altura = altura_agua
	f.surtidor = con_surtidor
	padre.add_child(f)
	f.position = r["pos"]
	f.rotation.y = r["rot"]
	if MapaOverrides.modo_admin:
		MapaOverrides.registrar(f, r)
		f.set_meta(&"sin_escala", true)
	return f


## Zona de baño sobre una fuente del kit que ya está puesta en "pos" con esa "escala" (la grande del rombo
## de la ciudad): no agrega modelo ni colisión, sólo el "E · BAÑARSE" y el baño.
static func crear_bano(padre: Node3D, pos: Vector3, escala: float) -> Fuente:
	var f := Fuente.new()
	f.solo_bano = true
	f.altura = 0.65 * escala
	f.radio = 1.3 * escala
	padre.add_child(f)
	f.position = pos
	return f


func _ready() -> void:
	add_to_group("fuentes")
	_armar()


# ---------------------------------------------------------------- Armado

func _armar() -> void:
	_y_agua = altura + 0.02 if altura > 0.0 else 0.014
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(0.4, 0.78, 0.93, 0.62) if altura > 0.0 else Color(0.45, 0.64, 0.74, 0.55)
	agua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	agua.roughness = 0.05
	agua.metallic_specular = 1.0
	agua.emission_enabled = true
	agua.emission = Color(0.1, 0.25, 0.35)
	agua.emission_energy_multiplier = 0.4

	if solo_bano:
		_y_agua = altura + 0.02
		_salpicadura = _particulas(34, 0.7, false)
		_rafaga = _particulas(40, 0.8, true)
		return

	if altura > 0.0:
		# La fuente de tres pisos del kit (misma que la de las plazas de la ciudad): pileta de r 1,6 y
		# borde a 0,65 m a escala 1. La escala sale del radio pedido (el borde queda donde estaba el de
		# antes) y la paloma camina "en" el agua a la altura del borde, sobre la colisión del kit.
		var escala := (radio + 0.4) / 1.6
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = Construir.CAPA_MUNDO
		cuerpo.collision_mask = 0
		add_child(cuerpo)
		Kit.colocar(self, "fuente", Vector3.ZERO, 0.0, Vector3.ONE * escala, cuerpo)
		altura = 0.65 * escala
		radio = 1.3 * escala
		_y_agua = altura + 0.02
		if surtidor:
			_armar_onda_continua(agua)

	# El agua (un disco finito; en el charco, dos discos juntos para que no sea un círculo perfecto)
	_disco(agua, radio, Vector3(0, _y_agua - 0.01, 0))
	if altura <= 0.0:
		_disco(agua, radio * 0.6, Vector3(radio * 0.55, _y_agua - 0.01, radio * 0.25))

	_salpicadura = _particulas(34, 0.7, false)
	_rafaga = _particulas(40, 0.8, true)


func _disco(mat: Material, r: float, pos: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	cm.radial_segments = 28
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)


## Gotas: una esfera chica translúcida (unshaded: no pide luz).
func _gota(r: float, alfa: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.6, 0.86, 1.0, alfa)   # Celeste: sobre las baldosas claras no se vería blanco
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = mat
	return sm


func _particulas(cantidad: int, vida: float, de_golpe: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = cantidad
	p.lifetime = vida
	p.emitting = false
	p.one_shot = de_golpe
	p.explosiveness = 1.0 if de_golpe else 0.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = 1.3
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -9.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.mesh = _gota(0.04, 0.9)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sólo importan de cerca (la paloma bañándose): de lejos no se dibujan
	p.visibility_range_end = 45.0
	add_child(p)
	return p


## El chorro de la fuente: gotas que suben y caen en arco.
func _armar_chorro(pos: Vector3) -> void:
	_chorro = CPUParticles3D.new()
	_chorro.amount = 18
	_chorro.lifetime = 1.15
	_chorro.direction = Vector3.UP
	_chorro.spread = 13.0
	_chorro.initial_velocity_min = 2.8
	_chorro.initial_velocity_max = 3.5
	_chorro.gravity = Vector3(0, -6.5, 0)
	_chorro.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	_chorro.mesh = _gota(0.055, 0.9)
	_chorro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chorro.visibility_range_end = 50.0
	_chorro.position = pos
	add_child(_chorro)


## Un anillo que sale del chorro hacia el borde, una y otra vez (donde caen las gotas).
func _armar_onda_continua(_agua: Material) -> void:
	var anillo := _anillo(0.55)
	anillo.position = Vector3(0, _y_agua + 0.012, 0)
	add_child(anillo)
	var mat := anillo.material_override as StandardMaterial3D
	var tw := anillo.create_tween().set_loops()
	tw.tween_property(anillo, "scale", Vector3(radio * 0.95, 1.0, radio * 0.95), 1.9).from(Vector3(0.3, 1.0, 0.3))
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.9).from(0.55)


## Anillo fino y plano (un toro) de radio 1, para ondas en el agua.
func _anillo(alfa: float) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.94
	tm.outer_radius = 1.0
	tm.rings = 28
	tm.ring_segments = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, alfa)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- El baño

func _physics_process(delta: float) -> void:
	var j := GameState.jugador
	var en_juego := j != null and GameState.en_partida and not GameState.partida_terminada \
		and not GameState.menu_activo and not get_tree().paused
	var dentro := false
	if en_juego and j.estado == PalomaJugador.Estado.SUELO and j.controlable:
		var d := Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length()
		dentro = d < radio * 0.95 and absf(j.global_position.y - (global_position.y + altura)) < 0.45
	var en_bano := dentro and j.modelo.baile_actual() == Coreografia.BANO
	if not dentro:
		_t_quieta = 0.0
	elif j.velocity.length() < 0.3:
		_t_quieta += delta
	else:
		_t_quieta = 0.0

	var pide := dentro and not en_bano
	if pide != _aviso_puesto:
		_aviso_puesto = pide
		if pide:
			AvisoAccion.mostrar(get_tree(), _id_aviso(), "E", "BAÑARSE", 2, func() -> void: j.banarse())
		else:
			AvisoAccion.ocultar(get_tree(), _id_aviso())

	if dentro and not en_bano:
		if Input.is_action_just_pressed("interactuar") or (Ajustes.movil and _t_quieta >= RETARDO_AUTO):
			j.banarse()
			en_bano = j.modelo.baile_actual() == Coreografia.BANO
	if en_bano and not _banando:
		_empezar_bano(j)
	elif not en_bano and _banando:
		_terminar_bano()
	if _banando:
		_pasar_bano(j, delta)


## ¿Se está pidiendo el aviso "E · BAÑARSE" de esta fuente? (lo miran las pruebas)
func aviso_visible() -> bool:
	return _aviso_puesto and AvisoAccion.visible_de(_id_aviso())


func _id_aviso() -> String:
	return "fuente_%d" % get_instance_id()


func _exit_tree() -> void:
	if _aviso_puesto:
		_aviso_puesto = false
		AvisoAccion.ocultar(get_tree(), _id_aviso())


func _empezar_bano(j: PalomaJugador) -> void:
	_banando = true
	_t_bano = 0.0
	_t_onda = 0.0
	_t_sonido = 0.0
	_premiada = false
	_rafaga.global_position = Vector3(j.global_position.x, _y_agua + global_position.y, j.global_position.z)
	_rafaga.restart()
	AudioManager.reproducir("salpicadura", -6.0)


func _terminar_bano() -> void:
	_banando = false
	_salpicadura.emitting = false


func _pasar_bano(j: PalomaJugador, delta: float) -> void:
	_t_bano += delta
	_salpicadura.global_position = Vector3(j.global_position.x, global_position.y + _y_agua, j.global_position.z)
	_salpicadura.emitting = true
	GameState.set_stamina(GameState.stamina + RECARGA * delta)
	_t_sonido -= delta
	if _t_sonido <= 0.0:
		_t_sonido = 0.6
		AudioManager.reproducir("salpicadura", -12.0)
	_t_onda -= delta
	if _t_onda <= 0.0:
		_t_onda = 0.45
		_ondita(_salpicadura.global_position)
	if not _premiada and _t_bano >= TIEMPO_PREMIO:
		_premiada = true
		GameState.set_stamina(Config.STAMINA_MAX)
		_rafaga.global_position = _salpicadura.global_position
		_rafaga.restart()
		AudioManager.ui("unlock", -8.0)
		Logros.sumar("banos")


## Una onda que se abre alrededor de la paloma y se desvanece.
func _ondita(pos: Vector3) -> void:
	var anillo := _anillo(0.6)
	anillo.top_level = true
	add_child(anillo)
	anillo.global_position = pos + Vector3(0, 0.012, 0)
	anillo.scale = Vector3(0.2, 1.0, 0.2)
	var mat := anillo.material_override as StandardMaterial3D
	var tw := anillo.create_tween().set_parallel(true)
	tw.tween_property(anillo, "scale", Vector3(0.9, 1.0, 0.9), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(anillo.queue_free)
