extends Node
## Saca la pieza "Cabildo" de Escenario_Cabildo.glb (el Cabildo modelado en Blender con
## tools/blender/generar_escenario_cabildo.py) y la guarda como modelos/cabildo/cabildo.res: una malla
## con el material del estilo cozy y las texturas pixel-art agrandadas (para que el filtro lineal del
## shader no las borronee). Uso: godot --headless --path . res://tools/extraer_cabildo.tscn -- <glb>

const SALIDA := "res://modelos/cabildo/cabildo.res"
const AUMENTO := 8


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
			a[Mesh.ARRAY_VERTEX] = v
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
