extends SceneTree
## Extrae las mallas de nubes y del rayo del pack "Low Poly Skies Free" a modelos/cielo/*.res: sólo posición, normal y
## color de vértice (sin las texturas ni las animaciones del pack). Se corre una vez:
##   godot --headless --path . -s res://tools/importar_cielo.gd -- <carpeta glb del pack>

const PIEZAS := ["cloud_cumulus", "cloud_cumulus_small", "cloud_bank", "cloud_storm", "lightning"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Falta la carpeta glb/ del pack")
		quit(1)
		return
	for nombre: String in PIEZAS:
		var doc := GLTFDocument.new()
		var estado := GLTFState.new()
		if doc.append_from_file(args[0].path_join(nombre + ".glb"), estado) != OK:
			printerr("No se pudo leer ", nombre)
			continue
		var escena := doc.generate_scene(estado)
		var mi := escena.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var origen := mi.mesh
		var malla := ArrayMesh.new()
		for s in origen.get_surface_count():
			var a := origen.surface_get_arrays(s)
			var limpio := []
			limpio.resize(Mesh.ARRAY_MAX)
			limpio[Mesh.ARRAY_VERTEX] = a[Mesh.ARRAY_VERTEX]
			limpio[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
			limpio[Mesh.ARRAY_COLOR] = a[Mesh.ARRAY_COLOR]
			limpio[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, limpio)
		var destino := "res://modelos/cielo/%s.res" % nombre
		ResourceSaver.save(malla, destino, ResourceSaver.FLAG_COMPRESS)
		print(nombre, ": ", malla.get_aabb(), "  vértices: ", (malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		escena.free()
	quit()
