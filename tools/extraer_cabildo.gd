extends Node
## Saca la pieza "Cabildo" de Escenario_Cabildo.glb (el Cabildo modelado en Blender con
## tools/blender/generar_escenario_cabildo.py) y la guarda como modelos/cabildo/cabildo.res: una malla
## con el material del estilo cozy y las texturas pixel-art agrandadas (para que el filtro lineal del
## shader no las borronee). Uso: godot --headless --path . res://tools/extraer_cabildo.tscn -- <glb>

const SALIDA := "res://modelos/cabildo/cabildo.res"
const AUMENTO := 8
## Columnas de las puntas de la galería del frente: en el modelo están centradas sobre la línea de las
## paredes de los costados (z = ±15) y la mitad quedaba afuera del edificio. Se corren 0,4 m hacia
## adentro para que la cara de afuera quede al ras de la pared.
const COLUMNA_X := Vector2(-45.81, -44.99)
const COLUMNA_ALTO := 4.81
const COLUMNA_CORRIDA := 0.4
## Fondo del Cabildo: en el modelo la fachada de atrás (ventanas, pilastras) está en x = -59, sobre una
## caja lisa de 2 x 10 x 30 m (x -59..-57) que no tiene techo y asomaba 70 cm por arriba de la cornisa:
## desde la avenida se veía como un muro pegado atrás. La fachada y la cara de afuera de la caja (que es
## la pared) se corren 2 m hacia adentro, al ras del final de las paredes de los costados (x = -57), y
## la caja queda toda por debajo de la cornisa.
const FONDO_LIMITE := -58.0
const FONDO_CORRIDA := 2.0
const FONDO_TOPE := 9.3


## Corre hacia adentro los vértices de las dos columnas de las puntas (sólo las caras de la columna:
## |z| ≈ 14,6 y ≈ 15,4; lo que está justo en z = ±15 es la pared y no se toca).
static func correr_columnas_esquina(v: PackedVector3Array) -> PackedVector3Array:
	for i in v.size():
		var p := v[i]
		var az := absf(p.z)
		if p.x < COLUMNA_X.x or p.x > COLUMNA_X.y or p.y > COLUMNA_ALTO:
			continue
		if absf(az - 14.62) < 0.04 or absf(az - 15.38) < 0.04:
			v[i].z = signf(p.z) * (az - COLUMNA_CORRIDA)
	return v


## Corre la fachada de atrás al ras de las paredes (ver FONDO_CORRIDA).
static func correr_fondo(v: PackedVector3Array) -> PackedVector3Array:
	for i in v.size():
		if v[i].x < FONDO_LIMITE:
			v[i].x += FONDO_CORRIDA
			v[i].y = minf(v[i].y, FONDO_TOPE)
	return v


## La caja lisa del fondo (24 vértices, de x = -59 hasta adentro del edificio).
static func es_caja_fondo(v: PackedVector3Array) -> bool:
	if v.size() != 24:
		return false
	var x_min := INF
	for p in v:
		x_min = minf(x_min, p.x)
	return x_min < FONDO_LIMITE


## Corre la fachada de atrás; si es la caja del fondo, además la baja entera hasta la cornisa.
static func arreglar_fondo(v: PackedVector3Array) -> PackedVector3Array:
	var caja := es_caja_fondo(v)
	v = correr_fondo(v)
	if caja:
		for i in v.size():
			v[i].y = minf(v[i].y, FONDO_TOPE)
	return v


func _ready() -> void:
	var ruta := OS.get_cmdline_user_args()[0]
	var raiz: Node = (load(ruta) as PackedScene).instantiate()
	var cab := raiz.find_child("Cabildo", true, false) as Node3D
	var malla := ArrayMesh.new()
	var mats: Array[Material] = []
	var texturas := {}
	for mi: MeshInstance3D in [cab] + cab.find_children("*", "MeshInstance3D", true, false) if cab is MeshInstance3D else cab.find_children("*", "MeshInstance3D", true, false):
		# Transformación hasta la raíz del GLB (el nodo no está en el árbol: no hay global_transform)
		var t := Transform3D.IDENTITY
		var nodo: Node = mi
		while nodo != raiz and nodo is Node3D:
			t = (nodo as Node3D).transform * t
			nodo = nodo.get_parent()
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			for i in v.size():
				v[i] = t * v[i]
				n[i] = (t.basis * n[i]).normalized()
			a[Mesh.ARRAY_VERTEX] = arreglar_fondo(correr_columnas_esquina(v))
			a[Mesh.ARRAY_NORMAL] = n
			a[Mesh.ARRAY_TANGENT] = null
			var std := mi.get_active_material(s) as BaseMaterial3D
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			var m := Construir.material_cozy(0.9)
			if std:
				m.set_shader_parameter("color_base", std.albedo_color)
				if std.albedo_texture:
					var clave := std.albedo_texture.get_rid()
					if not texturas.has(clave):
						var img := std.albedo_texture.get_image()
						if img.is_compressed():
							img.decompress()
						img.convert(Image.FORMAT_RGBA8)
						img.resize(img.get_width() * AUMENTO, img.get_height() * AUMENTO, Image.INTERPOLATE_NEAREST)
						img.generate_mipmaps()
						texturas[clave] = ImageTexture.create_from_image(img)
					m.set_shader_parameter("textura_albedo", texturas[clave])
				print("superficie %d: %s %s" % [malla.get_surface_count() - 1, std.resource_name, std.albedo_texture != null])
			malla.surface_set_material(malla.get_surface_count() - 1, m)
	print("superficies: ", malla.get_surface_count(), " aabb ", malla.get_aabb())
	var err := ResourceSaver.save(malla, SALIDA, ResourceSaver.FLAG_COMPRESS)
	print("guardado ", err)
	raiz.free()
	get_tree().quit()
