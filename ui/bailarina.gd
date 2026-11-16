class_name Bailarina
extends Control
## Escenario de los créditos: una paloma sola baila sobre un foco de luz, con su nombre en una placa,
## y entra y sale con un fundido (sólo ella, el resto de la pantalla no cambia). Vive en su propio
## mundo 3D adentro de un SubViewport transparente, así no depende de la cámara que gira por la plaza.
## Uso: await bailarina.presentar("Carlos", "Gris", &"breakdance"). Los bailes están en Coreografia
## y se aplican girando los huesos del GLB (el AnimationPlayer del modelo queda apagado).

const ENTRADA := 0.5            ## Segundos de fundido al aparecer
const SALIDA := 0.6             ## ...y al desaparecer
const CENTRO_CUERPO := 0.25     ## Altura del centro del cuerpo: todo el modelo gira alrededor de ahí

var _vp: SubViewport
var _pivote: Node3D             ## En el centro del cuerpo: lo mueve y gira la pose
var _sombra: MeshInstance3D     ## Mancha en el piso que se achica cuando salta
var _modelo: Node3D
var _esqueleto: Skeleton3D
var _reposo: Array[Basis] = []  ## Giro global de cada hueso en reposo
var _baile: StringName = &""
var _t := 0.0
var _activa := false
var _placa: PanelContainer
var _nombre: Label


func _ready() -> void:
	theme = EstiloUI.TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_armar_foco()
	_armar_escenario()
	_armar_placa()


## Presenta a una paloma: aparece, baila "baile" entero y se va. Termina cuando ya se fue.
func presentar(nombre: String, variante: String, baile: StringName) -> void:
	_poner_modelo(variante)
	_nombre.text = nombre.to_upper()
	_baile = baile
	_t = 0.0
	_aplicar(Coreografia.pose(baile, 0.0))
	_activa = true
	var duracion := Coreografia.duracion(baile)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, ENTRADA)
	tw.tween_interval(maxf(duracion - ENTRADA - SALIDA, 0.0))
	tw.tween_property(self, "modulate:a", 0.0, SALIDA)
	await tw.finished
	_activa = false


## Muestra una paloma quieta en el instante "t" de su baile, sin fundido (para las capturas de prueba).
func ver(nombre: String, variante: String, baile: StringName, t: float) -> void:
	_poner_modelo(variante)
	_nombre.text = nombre.to_upper()
	_baile = baile
	_t = t
	_activa = false
	modulate.a = 1.0
	_aplicar(Coreografia.pose(baile, t))


## La imagen del escenario 3D (sólo la paloma y su sombra, fondo transparente).
func imagen() -> Image:
	return _vp.get_texture().get_image()


func _process(delta: float) -> void:
	if _activa:
		_t += delta
		_aplicar(Coreografia.pose(_baile, _t))


# ---------------------------------------------------------------- Armado

## Un resplandor redondo detrás de la paloma, como el foco del escenario.
func _armar_foco() -> void:
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradiente.colors = PackedColorArray([Color(0.75, 0.95, 1.0, 0.34), Color(0.25, 0.72, 0.84, 0.14), Color(0.25, 0.72, 0.84, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.55)
	textura.fill_to = Vector2(1.0, 0.55)
	textura.width = 256
	textura.height = 256
	var foco := TextureRect.new()
	foco.name = "Foco"
	foco.texture = textura
	foco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foco.stretch_mode = TextureRect.STRETCH_SCALE
	foco.set_anchors_preset(Control.PRESET_FULL_RECT)
	foco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foco)


func _armar_escenario() -> void:
	var contenedor := SubViewportContainer.new()
	contenedor.name = "Escenario"
	contenedor.stretch = true
	contenedor.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(contenedor)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	contenedor.add_child(_vp)

	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.82, 0.88, 1.0)
	entorno.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = entorno
	_vp.add_child(we)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	luz.light_energy = 1.0
	luz.light_color = Color(1.0, 0.97, 0.9)
	_vp.add_child(luz)
	var camara := Camera3D.new()
	camara.fov = 36.0
	camara.position = Vector3(0.0, 0.58, 2.5)
	_vp.add_child(camara)
	camara.look_at(Vector3(0.0, 0.40, 0.0))
	camara.current = true

	_sombra = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.2
	disco.bottom_radius = 0.2
	disco.height = 0.002
	disco.radial_segments = 20
	disco.rings = 1
	_sombra.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.03, 0.06, 0.4)
	_sombra.material_override = mat
	_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(_sombra)
	_pivote = Node3D.new()
	_pivote.position = Vector3(0.0, CENTRO_CUERPO, 0.0)
	_vp.add_child(_pivote)


## La placa con el nombre, abajo en el medio, con el corte en diagonal del menú.
func _armar_placa() -> void:
	_placa = PanelContainer.new()
	_placa.name = "Placa"
	_placa.add_theme_stylebox_override("panel", EstiloUI.caja(EstiloUI.C_CYAN, -0.42, EstiloUI.C_CYAN_BORDE))
	_placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placa.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_placa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_placa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_placa.offset_bottom = 0.0
	add_child(_placa)
	_nombre = EstiloUI.texto(_placa, &"TituloPantalla", 56)
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Cambia de paloma (el color de cada variante es un GLB distinto) y apaga su animación.
func _poner_modelo(variante: String) -> void:
	if _modelo:
		_modelo.queue_free()
	_modelo = (ModeloPaloma.VARIANTES.get(variante, ModeloPaloma.VARIANTES["Gris"]) as PackedScene).instantiate()
	_modelo.position = Vector3(0.0, -CENTRO_CUERPO, 0.0)   # El GLB mira a +Z, hacia la cámara
	_pivote.add_child(_modelo)
	var reproductor := _modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	reproductor.stop()
	reproductor.active = false
	_esqueleto = _modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	# "La paloma flaca" de los créditos es la de la jugadora: lleva sus colores y accesorios
	if variante == "Original":
		AplicadorPaloma.aplicar(_modelo, _esqueleto, PerfilPaloma.actual())
	_reposo = PoseBaile.reposo_de(_esqueleto)


# ---------------------------------------------------------------- Pose

func _aplicar(p: PoseBaile) -> void:
	_pivote.position = Vector3(p.pos.x, CENTRO_CUERPO + p.pos.y, p.pos.z)
	_pivote.basis = p.rot
	# La mancha del piso se achica y se aclara cuando salta
	var altura := maxf(p.pos.y, 0.0)
	_sombra.position = Vector3(p.pos.x, 0.003, p.pos.z)
	_sombra.scale = Vector3.ONE * clampf(1.0 - altura * 1.3, 0.3, 1.0)
	p.aplicar_a(_esqueleto, _reposo)
