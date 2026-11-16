extends Node
## Escribe modelos/ciudad/kit_colisiones_extra.gd con los convexos que les faltan a los edificios del
## kit (ver world/colision_auto.gd). Correrlo cada vez que se regenera el kit de Blender:
##   godot --headless --path . res://tools/generar_colisiones_kit.tscn

const ARCHIVO := "res://modelos/ciudad/kit_colisiones_extra.gd"


func _ready() -> void:
	var lineas: Array[String] = []
	var total := 0
	for nombre: String in KitDatos.PIEZAS:
		var d: Dictionary = KitDatos.PIEZAS[nombre]
		if d.get("carpeta", "") != "edificios" or nombre.ends_with("_lejos"):
			continue
		var convexos := ColisionAuto.convexos(nombre)
		if convexos.is_empty():
			continue
		var partes: Array[String] = []
		for g: PackedVector3Array in convexos:
			var nums: Array[String] = []
			for p in g:
				nums.append("%s, %s, %s" % [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)])
			partes.append("[" + ", ".join(nums) + "]")
		lineas.append('\t"%s": [\n\t\t%s,\n\t],' % [nombre, ",\n\t\t".join(partes)])
		total += convexos.size()
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	f.store_string("class_name KitColisionesExtra\nextends RefCounted\n" +
		"## GENERADO por tools/generar_colisiones_kit.gd (no editar a mano). Convexos que les faltan a los\n" +
		"## edificios del kit (cornisas, tapas, toldos, bandas, pasamanos), en el espacio de cada pieza:\n" +
		"## [x, y, z, x, y, z, ...] por convexo. Ver world/colision_auto.gd.\n\n" +
		"const PIEZAS := {\n" + "\n".join(lineas) + "\n}\n")
	f.close()
	print("Convexos: ", total)
	get_tree().quit()
