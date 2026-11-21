extends SceneTree
## Aplica a modelos/cabildo/cabildo.res ya extraído lo que tools/extraer_cabildo.gd hace con el fondo
## (corre la fachada y la pared de atrás al ras de las paredes de los costados), sin necesitar el GLB.
## Uso: godot --headless --path . -s res://tools/arreglar_fondo_cabildo.gd

const Extraer := preload("res://tools/extraer_cabildo.gd")


func _init() -> void:
	var viejo: ArrayMesh = load(Extraer.SALIDA)
	var nuevo := ArrayMesh.new()
	for s in viejo.get_surface_count():
		var a := viejo.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		a[Mesh.ARRAY_VERTEX] = Extraer.arreglar_fondo(v)
		a = Extraer.quitar_sobre_cornisa(a)
		nuevo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		nuevo.surface_set_material(nuevo.get_surface_count() - 1, viejo.surface_get_material(s))
	print("superficies: ", nuevo.get_surface_count(), " aabb ", nuevo.get_aabb())
	nuevo.take_over_path(Extraer.SALIDA)
	print("guardado ", ResourceSaver.save(nuevo, Extraer.SALIDA, ResourceSaver.FLAG_COMPRESS))
	quit()
