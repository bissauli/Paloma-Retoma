extends SceneTree
## Exporta cada accesorio de la paloma como un modelo .glb en modelos/accesorios/<zona>/<nombre>.glb
## (se abren en Blender o en cualquier visor 3D, y Godot los importa como escenas):
## godot --headless --path . --script res://tools/exportar_accesorios.gd
## Los accesorios se arman por código (AccesoriosPaloma); esto sólo guarda una copia de cada uno.
## Las piezas están en el espacio de la paloma: si se pone el .glb en el origen de Paloma.glb, cae
## justo en su lugar.

const CARPETA := "res://modelos/accesorios"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var total := 0
	for slot in CatalogoPaloma.SLOTS.size():
		var clave: String = CatalogoPaloma.SLOTS[slot]["clave"]
		var carpeta := CARPETA.path_join(clave)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
		for opcion in range(1, CatalogoPaloma.cantidad_opciones(slot)):
			var nombre := _archivo(CatalogoPaloma.nombre_opcion(slot, opcion))
			var pieza := AccesoriosPaloma.crear(slot, opcion)
			var raiz := Node3D.new()
			raiz.name = nombre
			raiz.add_child(pieza)
			pieza.owner = raiz
			for n in pieza.find_children("*", "", true, false):
				n.owner = raiz
			var doc := GLTFDocument.new()
			var estado := GLTFState.new()
			var err := doc.append_from_scene(raiz, estado)
			if err == OK:
				err = doc.write_to_filesystem(estado, ProjectSettings.globalize_path(carpeta.path_join(nombre + ".glb")))
			print("%s/%s.glb %s" % [clave, nombre, "ok" if err == OK else "ERROR %d" % err])
			if err == OK:
				total += 1
			raiz.free()
	print("EXPORTADOS: ", total)
	quit()


## "Gafas de sol" -> "gafas_de_sol" (sin tildes ni eñes, para que el nombre sirva en cualquier lado).
static func _archivo(texto: String) -> String:
	var t := texto.to_lower()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], [" ", "_"]]:
		t = t.replace(par[0], par[1])
	return t
