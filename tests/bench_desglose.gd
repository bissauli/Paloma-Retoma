extends Node
## Desglose de dibujos: qué hay dibujándose en la vista (cámara de juego, calidad actual): por grupo de
## nodos y por tipo de pieza, con superficies (cada una es un draw call) y si proyectan sombra.
##   godot --path . res://tests/bench_desglose.tscn -- [calidad=N] [movil]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "movil":
			Ajustes.movil = true
			Ajustes.calidad = 0
			if Ajustes.has_method("aplicar_perfil_movil"):
				Ajustes.aplicar_perfil_movil()
		elif a.begins_with("calidad="):
			Ajustes.calidad = int(a.get_slice("=", 1))
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 90:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	for vista: Array in [["suelo", Vector3(-34, 1.2, 4), Vector3(-20, 1, -4)], ["alta", Vector3(0, 40, 60), Vector3(0, 0, 0)]]:
		cam.global_position = vista[1]
		cam.look_at(vista[2])
		for i in 30:
			await get_tree().process_frame
		var por_grupo := {}
		var por_malla := {}
		var por_cadena := {}
		var total := 0
		var con_sombra := 0
		var instancias := 0
		for n in main.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var d := cam.global_position.distance_to(g.global_position)
			if g.visibility_range_end > 0.0 and d > g.visibility_range_end:
				continue
			if g.visibility_range_begin > 0.0 and d < g.visibility_range_begin:
				continue
			if d > 400.0 or not cam.is_position_in_frustum(g.global_position) and d > 25.0:
				continue
			var sup := 1
			var nombre := String(g.name)
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				sup = maxi((g as MeshInstance3D).mesh.get_surface_count(), 1)
				nombre = (g as MeshInstance3D).mesh.resource_name if (g as MeshInstance3D).mesh.resource_name != "" else nombre
			elif g is MultiMeshInstance3D:
				sup = 1
			total += sup
			instancias += 1
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				con_sombra += sup
			var raiz := g.get_parent()
			var anc: Node = g
			while anc.get_parent() != main and anc.get_parent() != null:
				anc = anc.get_parent()
			var clave := String(anc.name)
			if anc.name == &"Plaza" or anc.name == &"Ciudad":
				clave += "/" + String(g.get_parent().name).get_slice("@", 0) + String(g.get_parent().get_parent().name).get_slice("@", 0)
			por_grupo[clave] = por_grupo.get(clave, 0) + sup
			var k2 := nombre.rstrip("0123456789_")
			por_malla[k2] = por_malla.get(k2, 0) + sup
			if k2 == "@MeshInstance3D@":
				var q: Node = g
				var cadena := ""
				for _i in 3:
					q = q.get_parent()
					var sc: Script = q.get_script()
					cadena += (sc.resource_path.get_file() if sc else q.get_class()) + "<"
				por_cadena[cadena] = por_cadena.get(cadena, 0) + sup
		print("DESGLOSE ", vista[0], ": ", instancias, " instancias, ", total, " superficies, ", con_sombra, " con sombra")
		_top("  por padre", por_grupo)
		_top("  por malla", por_malla)
		_top("  anonimas por cadena de padres", por_cadena)
	get_tree().quit()


func _top(titulo: String, d: Dictionary) -> void:
	var l := d.keys()
	l.sort_custom(func(a, b): return d[a] > d[b])
	var s := ""
	for k in l.slice(0, 14):
		s += "%s=%d  " % [k, d[k]]
	print("DESGLOSE", titulo, ": ", s)
