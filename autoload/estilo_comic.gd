extends Node
## Modo cómic (autoload "EstiloComic"): cel duro + semitono + contorno de tinta.
## - El cel y el semitono están en shaders/estilo_cozy_luz.gdshaderinc y se prenden con la global
##   "comic_activo" (no cuestan dibujos extra).
## - El contorno (shaders/contorno_tinta.gdshader, Inverted Hull) va en el material_overlay de cada
##   malla opaca e iluminada: es un dibujo más por malla, así que en el teléfono no va.
##   Ver Ajustes.contorno_comic().
## Lo que se agrega después (gente, autos, palomas, accesorios) se revisa al entrar al árbol.
## Una malla con la meta "sin_contorno" no lleva contorno.

const CONTORNO := preload("res://shaders/contorno_tinta.gdshader")
const SHADERS_CON_CONTORNO := ["res://shaders/estilo_cozy.gdshader", "res://shaders/paloma_zonas.gdshader"]
## Algo más finito que ALTO_MINIMO (metros) y más ancho que ANCHO_PLANO es un plano: marcas de la
## calle, pasto, carteles pegados. Las piezas chicas (perlas, bandas de un accesorio) sí llevan.
const ALTO_MINIMO := 0.12
const ANCHO_PLANO := 1.0
## Una malla cuyo punto más alto (en el mundo) queda por debajo de esto (m) y es más ancha que
## ANCHO_PLANO es una losa de piso: sin contorno.
const ALTURA_PISO := 0.3
## Mallas importadas de hasta tantos vértices reciben normales suavizadas (ver _suavizar()).
const VERTICES_MAX_SUAVIZAR := 6000

var _contorno: ShaderMaterial
var _con_contorno := false
var _suavizadas := {}   ## ArrayMesh -> true: ya revisada por _suavizar()


func _ready() -> void:
	_contorno = ShaderMaterial.new()
	_contorno.shader = CONTORNO
	get_tree().node_added.connect(_al_agregar)
	Ajustes.cambio.connect(aplicar)
	aplicar()


## Aplica lo que diga Ajustes (se llama sola cuando cambia algún ajuste).
func aplicar() -> void:
	RenderingServer.global_shader_parameter_set(&"comic_activo", 1.0 if Ajustes.estilo_comic else 0.0)
	var con: bool = Ajustes.contorno_comic()
	if con == _con_contorno:
		return
	_con_contorno = con
	_recorrer(get_tree().root)


## Cuántas mallas tienen el contorno puesto ahora (para las pruebas).
func mallas_con_contorno() -> int:
	return _contar(get_tree().root)


func _contar(n: Node) -> int:
	var c := 1 if n is GeometryInstance3D and (n as GeometryInstance3D).material_overlay == _contorno else 0
	for h in n.get_children():
		c += _contar(h)
	return c


func _recorrer(n: Node) -> void:
	if n is GeometryInstance3D:
		_revisar(n as GeometryInstance3D)
	for h in n.get_children():
		_recorrer(h)


func _al_agregar(n: Node) -> void:
	# Diferido: muchas veces la malla y el material se asignan después del add_child
	if _con_contorno and (n is MeshInstance3D or n is MultiMeshInstance3D):
		_revisar_diferido.call_deferred(n)


func _revisar_diferido(n: Object) -> void:
	if is_instance_valid(n) and (n as Node).is_inside_tree():
		_revisar(n as GeometryInstance3D)


func _revisar(g: GeometryInstance3D) -> void:
	if _con_contorno:
		if g.material_overlay == null and lleva_contorno(g):
			if g is MeshInstance3D:
				_suavizar(g as MeshInstance3D)
			g.material_overlay = _contorno
	elif g.material_overlay == _contorno:
		g.material_overlay = null


## Le agrega normales suavizadas (CUSTOM0, ver Construir.normales_suaves) a una malla importada
## chica (palomas, accesorios, animales): son de cajas con aristas duras y sin esto el contorno se
## corta en los bordes. Una vez por malla; en memoria, no toca el archivo. Las mallas fusionadas ya
## las traen. No se tocan las grandes (perderían los LOD) ni las que tienen blend shapes.
func _suavizar(mi: MeshInstance3D) -> void:
	var am := mi.mesh as ArrayMesh
	if am == null or _suavizadas.has(am):
		return
	_suavizadas[am] = true
	if am.get_blend_shape_count() > 0:
		return
	var vertices := 0
	for i in am.get_surface_count():
		if am.surface_get_format(i) & Mesh.ARRAY_FORMAT_CUSTOM0 \
				or am.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			return
		vertices += am.surface_get_array_len(i)
	if vertices > VERTICES_MAX_SUAVIZAR:
		return
	var superficies := []
	for i in am.get_surface_count():
		superficies.append([am.surface_get_arrays(i), am.surface_get_material(i), am.surface_get_name(i),
			am.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS])
	# Centro de la instancia ya posada (el espacio de la malla puede venir rotado respecto del esqueleto)
	var centro_malla := mi.get_aabb().get_center()
	am.clear_surfaces()
	for s: Array in superficies:
		var arr: Array = s[0]
		var formato := Mesh.ARRAY_CUSTOM_RGB_FLOAT
		if arr[Mesh.ARRAY_BONES] != null:
			# Con esqueleto (palomas): el motor mueve NORMAL con los huesos pero no CUSTOM0, así que
			# una dirección guardada ahí no sigue la pose. En cambio CUSTOM0 lleva el centro de la
			# malla y w = 2: contorno_tinta.gdshader infla cada vértice desde ese centro (en figuras de
			# cajas alcanza y las esquinas quedan cerradas).
			var centro := centro_malla
			var c := PackedFloat32Array()
			c.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 4)
			for k in range(0, c.size(), 4):
				c[k] = centro.x
				c[k + 1] = centro.y
				c[k + 2] = centro.z
				c[k + 3] = 2.0
			arr[Mesh.ARRAY_CUSTOM0] = c
			formato = Mesh.ARRAY_CUSTOM_RGBA_FLOAT
		else:
			arr[Mesh.ARRAY_CUSTOM0] = Construir.normales_suaves(arr).to_byte_array().to_float32_array()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			int(s[3]) | (formato << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT))
		var i := am.get_surface_count() - 1
		am.surface_set_material(i, s[1])
		am.surface_set_name(i, s[2])


## ¿Esta malla lleva contorno? Opaca, iluminada, con volumen y que no sea un piso.
func lleva_contorno(g: GeometryInstance3D) -> bool:
	if g.has_meta(&"sin_contorno") or g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	if mesh == null:
		return false
	var tam := g.get_aabb().size * g.global_basis.get_scale()
	if tam.y < ALTO_MINIMO and maxf(tam.x, tam.z) > ANCHO_PLANO:
		return false
	# Losas a ras del suelo (calzadas, veredas, cordones, el piso de la plaza): son pisos aunque tengan
	# grosor. Su contorno asoma sobre el asfalto como una raya negra en el borde (en ángulo bajo, y se
	# ve de más cerca todavía), así que no llevan.
	if g is MeshInstance3D and (g.global_transform * g.get_aabb()).end.y < ALTURA_PISO \
			and maxf(tam.x, tam.z) > ANCHO_PLANO:
		return false
	if g.material_override:
		return _material_con_contorno(g.material_override)
	for i in mesh.get_surface_count():
		var m: Material = null
		if g is MeshInstance3D:
			m = (g as MeshInstance3D).get_active_material(i)
		else:
			m = mesh.surface_get_material(i)
		if _material_con_contorno(m):
			return true
	return false


func _material_con_contorno(m: Material) -> bool:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		# Las baldosas y lajas (textura proyectada en el mundo) son pisos
		return sm.shader != null and SHADERS_CON_CONTORNO.has(sm.shader.resource_path) \
			and not sm.get_shader_parameter("usar_uv_mundo")
	if m is BaseMaterial3D:
		var bm := m as BaseMaterial3D
		return bm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and bm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
	return false
