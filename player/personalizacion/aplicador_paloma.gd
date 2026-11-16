class_name AplicadorPaloma
extends RefCounted
## Aplica un PerfilPaloma a un modelo de paloma (el GLB y su esqueleto): recolorea las zonas con el
## shader de máscara y cuelga los accesorios de BoneAttachment3D. Se puede volver a llamar con otro
## perfil: limpia lo anterior. Un perfil vacío (o null) deja el modelo tal cual viene del GLB.

const SHADER := preload("res://shaders/paloma_zonas.gdshader")
const MASCARA := preload("res://modelos/paloma/paloma_zonas.png")
const PREFIJO := "Acc_"
const SLOT_PREFIJO := "Slot_"

## Luminancia media (lineal) de cada zona en la textura original, que el shader usa para repartir
## el tinte sin aplanar el sombreado. Se calcula con la textura y la máscara (el test lo comprueba:
## si se cambia la textura o se regenera la máscara hay que actualizar estos números).
const LUZ_BASE := [0.0, 0.50251811742783, 0.33363220095634, 0.52032446861267, 0.2343718111515, 0.13425998389721, 0.41131654381752]

static var _sin_pintura: ImageTexture   ## Pintura vacía de 1x1 que comparten los materiales sin pintar


static func aplicar(glb: Node3D, skel: Skeleton3D, perfil: PerfilPaloma) -> void:
	_aplicar_colores(glb, perfil)
	_aplicar_accesorios(glb, skel, perfil)


## Material liso para los párpados (GestosPaloma) con el color que tiene la cabeza en este material:
## el gris original de la cabeza (#bcbece) pasado por el mismo tinte que hace el shader.
static func material_parpado(sm: ShaderMaterial) -> Material:
	var color := Color("bcbece")
	var activa: PackedFloat32Array = sm.get_shader_parameter("activa")
	var paleta: PackedVector3Array = sm.get_shader_parameter("paleta")
	if activa.size() > 3 and activa[3] > 0.5:
		var lin := color.srgb_to_linear()
		var l := lin.r * 0.2126 + lin.g * 0.7152 + lin.b * 0.0722
		var t := (paleta[3] * (l / float(LUZ_BASE[3]))).clampf(0.0, 1.0)
		color = Color(t.x, t.y, t.z).linear_to_srgb()
	# Misma luz cozy que el cuerpo (paloma_zonas), sin el degradado del mundo
	var m := Construir.material_cozy(1.0)
	m.set_shader_parameter("color_base", color)
	m.set_shader_parameter("usar_degradado", false)
	m.set_shader_parameter("rim_intensidad", 0.25)
	return m


## Muestra u oculta los accesorios del pico (se esconden mientras lleva comida, para no taparla).
static func pico_visible(skel: Skeleton3D, si: bool) -> void:
	var s := skel.find_child(SLOT_PREFIJO + "pico", true, false)
	if s:
		(s as Node3D).visible = si


# ---------------------------------------------------------------- Colores

static func _aplicar_colores(glb: Node3D, perfil: PerfilPaloma) -> void:
	var mallas := glb.find_children("*", "MeshInstance3D", true, false)
	var material: ShaderMaterial = null
	if perfil != null and (perfil.hay_colores() or perfil.hay_pintura()) and not mallas.is_empty():
		material = _material(mallas[0] as MeshInstance3D, perfil)
	for m in mallas:
		(m as MeshInstance3D).material_override = material


static func _material(malla: MeshInstance3D, perfil: PerfilPaloma) -> ShaderMaterial:
	var base := malla.mesh.surface_get_material(0) as BaseMaterial3D
	var paleta := PackedVector3Array()
	var activa := PackedFloat32Array()
	paleta.resize(7)
	activa.resize(7)
	for i in CatalogoPaloma.ZONAS.size():
		var zona: int = CatalogoPaloma.ZONAS[i]["zona"]
		var idx := perfil.colores[i]
		if idx != PerfilPaloma.SIN_COLOR:
			var c := CatalogoPaloma.color_paleta(idx).srgb_to_linear()
			paleta[zona] = Vector3(c.r, c.g, c.b)
			activa[zona] = 1.0
	var sm := ShaderMaterial.new()
	sm.shader = SHADER
	sm.set_shader_parameter("albedo_tex", base.albedo_texture)
	sm.set_shader_parameter("zonas", MASCARA)
	sm.set_shader_parameter("paleta", paleta)
	sm.set_shader_parameter("luz_base", PackedFloat32Array(LUZ_BASE))
	sm.set_shader_parameter("activa", activa)
	sm.set_shader_parameter("pintura", _textura_pintura(perfil))
	return sm


## Textura de la pintura de un perfil (sin pintura, una de 1x1 transparente compartida).
static func _textura_pintura(perfil: PerfilPaloma) -> Texture2D:
	if perfil.hay_pintura():
		return ImageTexture.create_from_image(perfil.pintura)
	if _sin_pintura == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_sin_pintura = ImageTexture.create_from_image(img)
	return _sin_pintura


## Pone la pintura actual del perfil en el material del modelo (mientras se arrastra el pincel):
## actualiza la textura en el lugar, sin rearmar el material. Si todavía no hay material (primera
## pincelada de un perfil sin colores) lo arma.
static func actualizar_pintura(glb: Node3D, perfil: PerfilPaloma) -> void:
	var mallas := glb.find_children("*", "MeshInstance3D", true, false)
	if mallas.is_empty():
		return
	var sm := (mallas[0] as MeshInstance3D).material_override as ShaderMaterial
	if sm == null:
		_aplicar_colores(glb, perfil)
		return
	var tex := sm.get_shader_parameter("pintura") as ImageTexture
	if perfil.hay_pintura() and tex != null and tex != _sin_pintura and Vector2i(tex.get_size()) == perfil.pintura.get_size():
		tex.update(perfil.pintura)
	else:
		sm.set_shader_parameter("pintura", _textura_pintura(perfil))


# ---------------------------------------------------------------- Accesorios

static func _aplicar_accesorios(glb: Node3D, skel: Skeleton3D, perfil: PerfilPaloma) -> void:
	# Fuera lo anterior (remove_child para que desaparezca ya, no al final del cuadro)
	for n in skel.get_children():
		if n.name.begins_with(PREFIJO):
			skel.remove_child(n)
			n.queue_free()
	if perfil == null:
		return
	var skel_en_glb := _relativo(glb, skel)
	var adjuntos := {}
	for s in mini(CatalogoPaloma.SLOTS.size(), perfil.accesorios.size()):   # Perfiles viejos: menos slots
		var pieza := AccesoriosPaloma.crear(s, perfil.accesorios[s])
		if pieza == null:
			continue
		var hueso: String = CatalogoPaloma.SLOTS[s]["hueso"]
		var id := skel.find_bone(hueso)
		if id < 0:
			pieza.free()
			continue
		var adjunto: BoneAttachment3D = adjuntos.get(hueso)
		if adjunto == null:
			adjunto = BoneAttachment3D.new()
			adjunto.name = PREFIJO + hueso
			adjunto.bone_name = hueso
			skel.add_child(adjunto)
			adjuntos[hueso] = adjunto
		# La pieza está armada en el espacio del GLB: se pasa al espacio del hueso en reposo
		var slot := Node3D.new()
		slot.name = SLOT_PREFIJO + String(CatalogoPaloma.SLOTS[s]["clave"])
		slot.transform = skel.get_bone_global_rest(id).affine_inverse() * skel_en_glb.affine_inverse()
		adjunto.add_child(slot)
		slot.add_child(pieza)


static func _relativo(ancestro: Node3D, hijo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = hijo
	while n != ancestro and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
