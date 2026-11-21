class_name Cielo
extends Node3D
## Cielo, día y noche y clima. Arma el WorldEnvironment (con shaders/cielo_cozy.gdshader), el sol
## (que de noche hace de luna), las nubes low-poly, la lluvia, los rayos y el arcoíris, y los mueve
## con un reloj de 24 h (GameState.hora_dia) y un clima que cambia solo cada tantos minutos.
## Colores: una paleta por hora (PALETA) a la que el clima le saca color y luz.
## También pone la global "cozy_cielo" de los shaders del estilo cozy: de noche el tinte de sombra
## también se oscurece (si no, las sombras quedarían igual de claras que de día).
## En las versiones de prueba: F6 cambia el clima y F7 adelanta 2 horas.

enum Clima { DESPEJADO, NUBLADO, LLUVIA, TORMENTA }
const NOMBRES_CLIMA := ["despejado", "nublado", "lluvia", "tormenta"]
## Cuánto de cada cosa tiene cada clima: [nubosidad, lluvia, tormenta, cantidad de nubes]
const OBJETIVO := [
	[0.0, 0.0, 0.0, 0.55],
	[0.7, 0.0, 0.0, 0.9],
	[0.85, 1.0, 0.0, 1.0],
	[1.0, 1.0, 1.0, 1.0],
]
const PESOS := [0.5, 0.25, 0.17, 0.08]
const TRANSICION := 25.0   ## Segundos que tarda en pasar de un clima a otro

## Paleta por hora: [hora, cenit, horizonte, sol, energía del sol, ambiente, energía del ambiente,
## niebla, cozy (tinte de sombra), nube clara, nube sombra, resplandor del horizonte, cuánto]
const PALETA := [
	[0.0, "0f1a3a", "2b3b6c", "b8c8f0", 0.3, "34427a", 0.35, "253259", "6a74a8", "56669a", "29345e", "2b3b6c", 0.0],
	[4.9, "0f1a3a", "2b3b6c", "b8c8f0", 0.3, "34427a", 0.35, "253259", "6a74a8", "56669a", "29345e", "2b3b6c", 0.0],
	[5.9, "4a5c9e", "f2a894", "ffb486", 0.35, "9a8ca6", 0.3, "d8aaa4", "b4a6c8", "ffc4a8", "8a7ca4", "ffb08a", 0.8],
	[7.2, "62aef0", "cfe8f7", "fff0d8", 1.0, "b8c2d6", 0.3, "d6e9f5", "ffffff", "ffffff", "bccbe2", "ffe2c4", 0.15],
	[12.0, "4fa2ee", "c8e6f8", "fffaf0", 1.0, "b8c2d6", 0.3, "d6e9f5", "ffffff", "ffffff", "bccde6", "ffffff", 0.0],
	[16.8, "58a2e6", "d6e6f2", "fff0dc", 1.0, "bcc2d4", 0.3, "dbe6f0", "fffaf6", "fffaf4", "c2c8e0", "ffd8b0", 0.15],
	[18.3, "5a70ba", "f6b48a", "ffa565", 0.85, "c4a2a6", 0.3, "f2b892", "f2dcdc", "ffbc94", "a0739c", "ff9c6a", 0.9],
	[19.3, "2e3672", "c27c9c", "ff9474", 0.06, "6a5a8c", 0.32, "7a6292", "8a80b0", "d48ca4", "4c4274", "e08aa0", 0.7],
	[20.4, "0f1a3a", "2b3b6c", "b8c8f0", 0.3, "34427a", 0.35, "253259", "6a74a8", "56669a", "29345e", "2b3b6c", 0.0],
	[24.0, "0f1a3a", "2b3b6c", "b8c8f0", 0.3, "34427a", 0.35, "253259", "6a74a8", "56669a", "29345e", "2b3b6c", 0.0],
]
const SALE_SOL := 6.0
const SE_PONE_SOL := 19.1
## Las nubes y el arcoíris siguen a la cámara en horizontal (como un domo): las cámaras del juego
## ven hasta 400 m y un anillo fijo quedaría cortado desde los bordes de la ciudad.

const MALLAS_NUBES := {
	"cumulus": "res://modelos/cielo/cloud_cumulus.res",
	"chica": "res://modelos/cielo/cloud_cumulus_small.res",
	"banco": "res://modelos/cielo/cloud_bank.res",
	"tormenta": "res://modelos/cielo/cloud_storm.res",
}
## Cuántas nubes de cada tipo hay en el anillo (se muestran según el clima)
const CANTIDAD_NUBES := {"cumulus": 18, "chica": 18, "banco": 8, "tormenta": 10}

var entorno: Environment
var sol: DirectionalLight3D
var cielo_mat: ShaderMaterial
var cozy_actual := Color.WHITE   ## Último valor de la global cozy_cielo (para las pruebas)
var niebla_actual := Color("c9d3e6")   ## Color de la niebla del momento (lo usa el horizonte, world/horizonte.gd)
var noche_actual := 0.0                ## 0 de día, 1 de noche cerrada
var nube_mat: ShaderMaterial

## Estado del clima, de 0 a 1, que se acerca al objetivo del clima actual
var nubosidad := 0.0
var lluvia := 0.0
var tormenta := 0.0
var cantidad := 0.55

var _rng := RandomNumberGenerator.new()
var _t_clima := 0.0           ## Segundos que le quedan al clima actual
var _nubes := {}              ## tipo -> MultiMeshInstance3D
var _umbral := {}             ## tipo -> PackedFloat32Array (desde qué cantidad aparece cada nube)
var _brillo := {}             ## tipo -> PackedFloat32Array (variación de brillo de cada nube)
var _visible := {}            ## tipo -> PackedFloat32Array (fundido actual de cada nube)
var _anillo: Node3D
var _lluvia: CPUParticles3D
var _lluvia_mat: StandardMaterial3D
var _sonido_lluvia: AudioStreamPlayer
var _rayo: MeshInstance3D
var _relampago := 0.0
var _t_rayo := 8.0
var _trueno_en := -1.0
var _arcoiris: MeshInstance3D
var _arcoiris_mat: ShaderMaterial
var _arcoiris_t := 0.0        ## Segundos que le quedan al arcoíris
var _arcoiris_dir := Vector3.FORWARD   ## Hacia dónde está (del lado opuesto al sol)
var _llovia := false
var _t_nubes := 0.0
var _t_aplicar := 0.0
var _tiempo := 0.0


func _ready() -> void:
	add_to_group("cielo")
	_rng.seed = 2207
	_crear_entorno()
	_crear_nubes()
	_crear_lluvia()
	_crear_rayo()
	_crear_arcoiris()
	_t_clima = _rng.randf_range(Config.CLIMA_MIN, Config.CLIMA_MAX)
	# Arranca ya en el clima guardado, sin transición
	var o: Array = OBJETIVO[GameState.clima]
	nubosidad = o[0]
	lluvia = o[1]
	tormenta = o[2]
	cantidad = o[3]
	GameState.partida_iniciada.connect(_al_iniciar_partida)
	_aplicar(true)


func _al_iniciar_partida() -> void:
	# Partida nueva o continuada: hora y clima vienen de GameState (reiniciar() los cargó)
	var o: Array = OBJETIVO[GameState.clima]
	nubosidad = o[0]
	lluvia = o[1]
	tormenta = o[2]
	cantidad = o[3]
	_aplicar(true)


func _process(delta: float) -> void:
	_tiempo += delta
	var corre := GameState.en_partida and not GameState.partida_terminada and not get_tree().paused
	if corre:
		var h := GameState.hora_dia
		var velocidad := 24.0 / Config.DURACION_DIA
		if h >= 20.5 or h < 5.5:
			velocidad *= Config.VELOCIDAD_NOCHE
		GameState.hora_dia = fposmod(h + delta * velocidad, 24.0)
		_t_clima -= delta
		if _t_clima <= 0.0:
			_elegir_clima()
	# El clima se acerca a su objetivo de a poco
	var o: Array = OBJETIVO[GameState.clima]
	var paso := delta / TRANSICION
	nubosidad = move_toward(nubosidad, o[0], paso)
	lluvia = move_toward(lluvia, o[1], paso)
	tormenta = move_toward(tormenta, o[2], paso)
	cantidad = move_toward(cantidad, o[3], paso)
	_actualizar_rayos(delta, corre)
	_actualizar_arcoiris(delta)
	# La hora y el clima cambian muy despacio: el cálculo pesado (colores, sol, ~30 parámetros de shader)
	# se hace 10 veces por segundo, o cada cuadro mientras hay un relámpago
	_t_aplicar -= delta
	if _t_aplicar <= 0.0 or _relampago > 0.0:
		_t_aplicar = 0.1
		_aplicar(false)
	else:
		cielo_mat.set_shader_parameter("tiempo", _tiempo)
	_seguir_camara()
	_anillo.rotation.y += delta * 0.003   # Las nubes viajan muy despacio


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_F6:
		forzar_clima((GameState.clima + 1) % NOMBRES_CLIMA.size())
		print("Clima: ", NOMBRES_CLIMA[GameState.clima])
	elif k == KEY_F7:
		GameState.hora_dia = fposmod(GameState.hora_dia + 2.0, 24.0)
		print("Hora: %.1f" % GameState.hora_dia)


## Cambia al clima "c" (con transición). Lo usan las teclas de prueba y las capturas.
func forzar_clima(c: int, inmediato := false) -> void:
	GameState.clima = c
	_t_clima = _rng.randf_range(Config.CLIMA_MIN, Config.CLIMA_MAX)
	if inmediato:
		var o: Array = OBJETIVO[c]
		nubosidad = o[0]
		lluvia = o[1]
		tormenta = o[2]
		cantidad = o[3]
		_aplicar(true)


func _elegir_clima() -> void:
	_t_clima = _rng.randf_range(Config.CLIMA_MIN, Config.CLIMA_MAX)
	var r := _rng.randf()
	var acum := 0.0
	for i in PESOS.size():
		acum += PESOS[i]
		if r <= acum:
			# Una tormenta no salta directo desde un día despejado: pasa por nublado
			if i == Clima.TORMENTA and GameState.clima == Clima.DESPEJADO:
				i = Clima.NUBLADO
			GameState.clima = i
			return


## Materiales que no se ven al empezar (lluvia, rayo, arcoíris), para precompilarlos en el menú
## (ui/menu/precalentar_shaders.gd): en la web el primer chaparrón si no trababa el juego.
func materiales_ocultos() -> Array[Material]:
	return [_lluvia_mat, _rayo.material_override, _arcoiris_mat]


# ---------------------------------------------------------------- Armado

func _crear_entorno() -> void:
	cielo_mat = ShaderMaterial.new()
	cielo_mat.shader = preload("res://shaders/cielo_cozy.gdshader")
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat
	cielo.radiance_size = Sky.RADIANCE_SIZE_32   # No se usa para reflejos: que cueste poco

	entorno = Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Tonemap lineal: en Compatibility el sol con sombras se suma en otro pase y un tonemap no
	# lineal aplicado por separado lavaba los colores (ver shaders/README_estilo_cozy.md)
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	entorno.fog_enabled = true
	entorno.fog_mode = Environment.FOG_MODE_DEPTH
	entorno.fog_density = 0.75
	entorno.fog_depth_curve = 1.6
	entorno.fog_sky_affect = 0.0
	entorno.adjustment_saturation = 1.05
	entorno.adjustment_contrast = 1.03

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = entorno
	we.add_to_group("entorno")
	add_child(we)
	Ajustes.aplicar_brillo(entorno)  # Opciones > Pantalla > Brillo

	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.shadow_enabled = true
	sol.add_to_group("sol")
	add_child(sol)
	# Distancia y calidad de las sombras según el preset gráfico (Opciones > Gráficos)
	Ajustes.aplicar_sombras(sol)


func _crear_nubes() -> void:
	nube_mat = ShaderMaterial.new()
	nube_mat.shader = preload("res://shaders/nube_cozy.gdshader")
	_anillo = Node3D.new()
	_anillo.name = "Nubes"
	add_child(_anillo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for tipo: String in MALLAS_NUBES:
		var n: int = CANTIDAD_NUBES[tipo]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = load(MALLAS_NUBES[tipo])
		mm.instance_count = n
		var umbrales := PackedFloat32Array()
		var brillos := PackedFloat32Array()
		var vis := PackedFloat32Array()
		for i in n:
			var ang := rng.randf() * TAU
			# Bajas sobre el horizonte (entre 10 y 20 grados): las nubes del pack tienen la panza plana
			# y vistas desde abajo parecen un techo
			var radio := rng.randf_range(230.0, 330.0)
			var alto := radio * rng.randf_range(0.18, 0.36)
			var escala := rng.randf_range(5.0, 8.5)
			match tipo:
				"chica":
					escala = rng.randf_range(5.5, 9.0)
				"banco":
					radio = rng.randf_range(300.0, 335.0)
					alto = radio * rng.randf_range(0.12, 0.2)
					escala = rng.randf_range(2.6, 3.6)
				"tormenta":
					alto = radio * rng.randf_range(0.16, 0.3)
					escala = rng.randf_range(4.5, 6.5)
			var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(escala, escala * rng.randf_range(0.8, 1.1), escala))
			mm.set_instance_transform(i, Transform3D(b, Vector3(cos(ang) * radio, alto, sin(ang) * radio)))
			umbrales.append(rng.randf())
			brillos.append(rng.randf_range(0.93, 1.04))
			vis.append(0.0)
			mm.set_instance_custom_data(i, Color(1, 1, 1, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Nubes_" + tipo
		mmi.multimesh = mm
		mmi.material_override = nube_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 50.0
		_anillo.add_child(mmi)
		_nubes[tipo] = mmi
		_umbral[tipo] = umbrales
		_brillo[tipo] = brillos
		_visible[tipo] = vis


func _crear_lluvia() -> void:
	_lluvia = CPUParticles3D.new()
	_lluvia.name = "Lluvia"
	_lluvia.amount = 900 if not OS.has_feature("mobile") and not OS.has_feature("web") else 450
	_lluvia.lifetime = 0.9
	_lluvia.local_coords = false
	_lluvia.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_lluvia.emission_box_extents = Vector3(24, 1, 24)
	_lluvia.direction = Vector3(0.08, -1, 0.03)
	_lluvia.spread = 3.0
	_lluvia.gravity = Vector3(0, -12, 0)
	_lluvia.initial_velocity_min = 22.0
	_lluvia.initial_velocity_max = 27.0
	_lluvia.emitting = false
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.9)
	_lluvia_mat = StandardMaterial3D.new()
	_lluvia_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lluvia_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lluvia_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_lluvia_mat.billboard_keep_scale = true
	_lluvia_mat.disable_fog = true
	_lluvia_mat.albedo_color = Color(0.82, 0.87, 0.97, 0.35)
	q.material = _lluvia_mat
	_lluvia.mesh = q
	_lluvia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lluvia)
	_sonido_lluvia = AudioStreamPlayer.new()
	_sonido_lluvia.stream = AudioManager.sonido("lluvia")
	_sonido_lluvia.bus = &"Efectos"
	_sonido_lluvia.volume_db = -80.0
	add_child(_sonido_lluvia)


func _crear_rayo() -> void:
	_rayo = MeshInstance3D.new()
	_rayo.name = "Rayo"
	_rayo.mesh = load("res://modelos/cielo/lightning.res")
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.95, 1.0)
	m.disable_fog = true
	_rayo.material_override = m
	_rayo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rayo.visible = false
	add_child(_rayo)


## Arco del arcoíris: media corona en el plano XY que mira a +Z. UV.y de adentro hacia afuera.
func _crear_arcoiris() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 := 150.0
	var r1 := 166.0
	var pasos := 48
	for i in pasos:
		var a0 := PI * i / pasos
		var a1 := PI * (i + 1) / pasos
		var u0 := float(i) / pasos
		var u1 := float(i + 1) / pasos
		var p := [Vector3(cos(a0) * r0, sin(a0) * r0, 0), Vector3(cos(a0) * r1, sin(a0) * r1, 0),
			Vector3(cos(a1) * r1, sin(a1) * r1, 0), Vector3(cos(a1) * r0, sin(a1) * r0, 0)]
		var uv := [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	_arcoiris_mat = ShaderMaterial.new()
	_arcoiris_mat.shader = preload("res://shaders/arcoiris.gdshader")
	_arcoiris = MeshInstance3D.new()
	_arcoiris.name = "Arcoiris"
	_arcoiris.mesh = st.commit()
	_arcoiris.material_override = _arcoiris_mat
	_arcoiris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arcoiris.visible = false
	add_child(_arcoiris)


# ---------------------------------------------------------------- Cada cuadro

## Dirección hacia el sol a la hora "h" (y su altura en grados, negativa si está bajo el horizonte).
static func dir_sol(h: float) -> Vector3:
	var k := (h - SALE_SOL) / (SE_PONE_SOL - SALE_SOL)
	var altura := sin(k * PI) * 62.0 if k >= 0.0 and k <= 1.0 else -sin(minf(absf(k) if k < 0.0 else k - 1.0, 1.0) * PI * 0.5) * 30.0
	var azimut := lerpf(105.0, 255.0, clampf(k, 0.0, 1.0))
	return _direccion(altura, azimut)


## Dirección hacia la luna: sale cuando se pone el sol y cruza el cielo de noche.
static func dir_luna(h: float) -> Vector3:
	var desde := fposmod(h - (SE_PONE_SOL + 0.3), 24.0)
	var dur := 24.0 - (SE_PONE_SOL + 0.3) + SALE_SOL - 0.2
	var k := desde / dur
	var altura := sin(k * PI) * 48.0 if k <= 1.0 else -10.0
	return _direccion(altura, lerpf(110.0, 250.0, clampf(k, 0.0, 1.0)))


static func _direccion(altura_grados: float, azimut_grados: float) -> Vector3:
	var alt := deg_to_rad(altura_grados)
	var az := deg_to_rad(azimut_grados)
	# Azimut desde el norte (-Z) hacia el este (+X)
	return Vector3(sin(az) * cos(alt), sin(alt), -cos(az) * cos(alt)).normalized()


func _paleta(h: float) -> Array:
	var i := 0
	while i < PALETA.size() - 2 and h >= float(PALETA[i + 1][0]):
		i += 1
	var a: Array = PALETA[i]
	var b: Array = PALETA[i + 1]
	var t := smoothstep(0.0, 1.0, (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001))
	var r := []
	for k in range(1, a.size()):
		if a[k] is String:
			r.append(Color(a[k] as String).lerp(Color(b[k] as String), t))
		else:
			r.append(lerpf(float(a[k]), float(b[k]), t))
	return r


static func _gris(c: Color, k := 1.0) -> Color:
	var l := c.get_luminance()
	return Color(l, l, l).lerp(c, 0.2) * k


func _aplicar(forzado: bool) -> void:
	# En el menú siempre es de mañana y despejado; en la partida, la hora del reloj
	var h := Config.HORA_INICIO if GameState.menu_activo else GameState.hora_dia
	var p := _paleta(h)
	var cenit: Color = p[0]
	var horizonte: Color = p[1]
	var sol_color: Color = p[2]
	var sol_energia: float = p[3]
	var ambiente: Color = p[4]
	var amb_energia: float = p[5]
	var niebla: Color = p[6]
	var cozy: Color = p[7]
	var nube_luz: Color = p[8]
	var nube_sombra: Color = p[9]
	var resplandor: Color = p[10]
	var cuanto_resplandor: float = p[11]

	# El clima le saca color y luz a todo
	var n := nubosidad
	var s := tormenta
	var oscuro := 1.0 - 0.38 * s
	cenit = cenit.lerp(_gris(cenit, 1.08), n * 0.8) * oscuro
	horizonte = horizonte.lerp(_gris(horizonte, 1.0), n * 0.75) * oscuro
	niebla = niebla.lerp(_gris(niebla, 0.95), n * 0.7) * oscuro
	ambiente = ambiente.lerp(_gris(ambiente), n * 0.6)
	amb_energia += 0.12 * n
	sol_energia *= 1.0 - 0.6 * n
	cozy = cozy.lerp(_gris(cozy, 0.95), n * 0.45) * (1.0 - 0.15 * s)
	nube_luz = nube_luz.lerp(_gris(nube_luz, 0.82), n * 0.6) * (1.0 - 0.4 * s) * (1.0 - 0.2 * lluvia)
	nube_sombra = nube_sombra.lerp(_gris(nube_sombra, 0.7), n * 0.6) * (1.0 - 0.45 * s)
	cuanto_resplandor *= 1.0 - 0.7 * n

	# Sol o luna: la luz direccional sigue al que esté más alto
	var ds := dir_sol(h)
	var dl := dir_luna(h)
	var es_de_dia := ds.y > -0.03
	var luz_dir := ds if es_de_dia else dl
	# Nunca por debajo de 6 grados: si no, ilumina las caras de abajo de todo
	var luz_plana := Vector3(luz_dir.x, 0, luz_dir.z).normalized()
	if luz_dir.y < 0.105:
		luz_dir = (luz_plana * cos(0.105) + Vector3.UP * sin(0.105)).normalized()
	sol.look_at_from_position(Vector3.ZERO, -luz_dir, Vector3.UP if absf(luz_dir.y) < 0.99 else Vector3.FORWARD)
	sol.light_color = sol_color
	sol.light_energy = sol_energia + _relampago * 0.6
	# 0 de día, 1 de noche cerrada: según qué tan abajo del horizonte está el sol
	var noche := smoothstep(0.02, -0.16, ds.y)

	entorno.ambient_light_color = ambiente
	entorno.ambient_light_energy = amb_energia + _relampago * 0.5
	entorno.fog_light_color = niebla
	niebla_actual = niebla
	noche_actual = noche
	entorno.fog_depth_begin = lerpf(110.0, 35.0, lluvia)
	entorno.fog_depth_end = lerpf(520.0, 240.0, lluvia)
	cozy_actual = cozy.lerp(Color.WHITE, _relampago * 0.35)
	RenderingServer.global_shader_parameter_set(&"cozy_cielo", cozy_actual)
	# Las luces falsas (ventanas, faroles, faros) se prenden al atardecer y con tormenta
	LucesNoche.poner_noche(maxf(smoothstep(0.12, -0.08, ds.y), lluvia * 0.45), get_tree())

	cielo_mat.set_shader_parameter("cenit", cenit)
	cielo_mat.set_shader_parameter("horizonte", horizonte)
	cielo_mat.set_shader_parameter("suelo", niebla.darkened(0.15))
	cielo_mat.set_shader_parameter("sol_dir", ds)
	cielo_mat.set_shader_parameter("sol_color", sol_color)
	cielo_mat.set_shader_parameter("sol_visible", clampf((ds.y + 0.04) * 12.0, 0.0, 1.0) * (1.0 - n * 0.95))
	cielo_mat.set_shader_parameter("resplandor_color", resplandor)
	cielo_mat.set_shader_parameter("resplandor", cuanto_resplandor)
	cielo_mat.set_shader_parameter("luna_dir", dl)
	cielo_mat.set_shader_parameter("luna_visible", clampf((dl.y + 0.02) * 10.0, 0.0, 1.0) * noche * (1.0 - n * 0.8))
	# Fase de la luna: cambia un poco cada noche (los días cuentan desde que empezó la partida)
	var dias := floorf(GameState.tiempo_jugado / Config.DURACION_DIA)
	var fase := fposmod(dias * 0.27 + 0.35, 1.0)
	var lateral := dl.cross(Vector3.UP).normalized()
	cielo_mat.set_shader_parameter("luna_sombra", lateral * lerpf(-0.07, 0.07, fase))
	cielo_mat.set_shader_parameter("estrellas", noche * (1.0 - n))
	cielo_mat.set_shader_parameter("tiempo", _tiempo)
	cielo_mat.set_shader_parameter("relampago", _relampago)

	nube_mat.set_shader_parameter("nube_luz", nube_luz)
	nube_mat.set_shader_parameter("nube_sombra", nube_sombra)
	nube_mat.set_shader_parameter("sol_dir", luz_dir)
	nube_mat.set_shader_parameter("relampago", _relampago)
	_t_nubes -= get_process_delta_time()
	if forzado or _t_nubes <= 0.0:
		_t_nubes = 0.1
		_actualizar_nubes(forzado)

	# Lluvia
	_lluvia.emitting = lluvia > 0.05
	# CPUParticles3D no tiene amount_ratio: la lluvia leve es la misma lluvia, más transparente
	var gotas := Color(0.82, 0.87, 0.97, 0.35).lerp(Color(0.5, 0.55, 0.7, 0.3), noche)
	gotas.a *= clampf(lluvia, 0.0, 1.0)
	_lluvia_mat.albedo_color = gotas
	if lluvia > 0.02 and not _sonido_lluvia.playing and DisplayServer.get_name() != "headless":
		_sonido_lluvia.play()
	_sonido_lluvia.volume_db = linear_to_db(maxf(lluvia, 0.0001)) - 15.0
	if lluvia <= 0.02 and _sonido_lluvia.playing:
		_sonido_lluvia.stop()

	# Los faroles y semáforos brillan más de noche
	Kit.material().set_shader_parameter("emision_energia", lerpf(1.2, 2.4, noche))


func _actualizar_nubes(inmediato: bool) -> void:
	for tipo: String in _nubes:
		var mm: MultiMesh = (_nubes[tipo] as MultiMeshInstance3D).multimesh
		var umb: PackedFloat32Array = _umbral[tipo]
		var bri: PackedFloat32Array = _brillo[tipo]
		var vis: PackedFloat32Array = _visible[tipo]
		# Las nubes de tormenta y los bancos sólo con mal tiempo; las otras según "cantidad"
		var cuanto := cantidad
		match tipo:
			"tormenta":
				cuanto = lluvia * 0.6 + tormenta * 0.6
			"banco":
				cuanto = nubosidad
			"chica":
				cuanto = cantidad * (1.0 - tormenta * 0.5)
		for i in mm.instance_count:
			var objetivo := smoothstep(umb[i] - 0.06, umb[i] + 0.06, cuanto)
			var nuevo: float = objetivo if inmediato else move_toward(vis[i], objetivo, 0.1 / 6.0)
			# Sólo se escribe lo que cambió: cada escritura vuelve a subir todo el buffer a la GPU
			if inmediato or nuevo != vis[i]:
				vis[i] = nuevo
				mm.set_instance_custom_data(i, Color(bri[i], bri[i], bri[i], nuevo))
		_visible[tipo] = vis


func _seguir_camara() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# La lluvia cae alrededor de la cámara, un poco por delante
	var adelante := -cam.global_basis.z
	adelante.y = 0.0
	_lluvia.global_position = cam.global_position + Vector3(0, 14, 0) + adelante.normalized() * 8.0
	var piso := Vector3(cam.global_position.x, 0.0, cam.global_position.z)
	_anillo.global_position = piso
	_arcoiris.global_position = piso + _arcoiris_dir * 300.0 + Vector3(0, -45, 0)


func _actualizar_rayos(delta: float, corre: bool) -> void:
	_relampago = maxf(_relampago - delta * 3.5, 0.0)
	if _relampago < 0.3:
		_rayo.visible = false
	if _trueno_en >= 0.0:
		_trueno_en -= delta
		if _trueno_en < 0.0:
			AudioManager.reproducir("trueno", -4.0 + tormenta * 4.0)
	if not corre or tormenta < 0.5:
		return
	_t_rayo -= delta
	if _t_rayo > 0.0:
		return
	_t_rayo = _rng.randf_range(5.0, 14.0)
	_relampago = 1.0
	var cam := get_viewport().get_camera_3d()
	var desde := cam.global_position if cam else Vector3.ZERO
	var ang := _rng.randf() * TAU
	var dist := _rng.randf_range(180.0, 320.0)
	_rayo.global_position = Vector3(desde.x + cos(ang) * dist, -5.0, desde.z + sin(ang) * dist)
	_rayo.rotation = Vector3(0, _rng.randf() * TAU, 0)
	_rayo.scale = Vector3.ONE * _rng.randf_range(4.0, 6.0)
	_rayo.visible = true
	# El trueno llega después, según lo lejos que cayó
	_trueno_en = dist / 340.0 * 0.6 + 0.2


## Pone el arcoíris del lado opuesto al sol, mirando a la ciudad, y lo deja 75 segundos.
func mostrar_arcoiris() -> void:
	var ds := dir_sol(GameState.hora_dia)
	_arcoiris_t = 75.0
	_arcoiris_dir = Vector3(-ds.x, 0, -ds.z).normalized()
	# El arco mira a +Z: que mire hacia la cámara (la posición la pone _seguir_camara)
	_arcoiris.basis = Basis.looking_at(_arcoiris_dir, Vector3.UP).rotated(Vector3.UP, PI)


func _actualizar_arcoiris(delta: float) -> void:
	var llueve := lluvia > 0.5
	var ds := dir_sol(GameState.hora_dia)
	# Cuando para de llover y hay sol, a veces sale el arcoíris del lado opuesto al sol
	if _llovia and not llueve and ds.y > 0.12 and _rng.randf() < 0.7:
		mostrar_arcoiris()
	_llovia = llueve
	_arcoiris_t = maxf(_arcoiris_t - delta, 0.0)
	var de_dia := clampf((ds.y - 0.05) * 8.0, 0.0, 1.0)
	var o := clampf(minf(_arcoiris_t / 10.0, (75.0 - _arcoiris_t) / 10.0), 0.0, 1.0) * 0.55 * (1.0 - nubosidad * 0.6) * de_dia
	_arcoiris.visible = o > 0.005
	_arcoiris_mat.set_shader_parameter("opacidad", o)
