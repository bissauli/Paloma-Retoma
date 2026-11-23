extends Node
## Capturas de adentro de los ambientes de los departamentos (NO headless): desde arriba junto a la ventana
## de adelante y desde un rincón del fondo, para revisar cómo los acomodó PlanoCasa.
## godot --path . --resolution 1280x720 res://tests/captura_deptos.tscn -- <carpeta>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas_deptos"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 30:
		await get_tree().process_frame
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 80.0
	add_child(cam)
	cam.current = true
	var i := 0
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		var casa := c as CasaEnterable
		if not casa.con_cinematica:
			continue
		if casa.luz:
			casa.luz.visible = true
		# La paloma en la vereda de enfrente (cerca: si no, los vecinos no se mueven), fuera del cuadro
		var paloma := main.get_node_or_null("Paloma") as Node3D
		if paloma:
			var abajo := casa.to_global(Vector3(0, 0, casa.fondo / 2.0 + 8.0))
			paloma.global_position = Vector3(abajo.x, 0.5, abajo.z)
		var hx := casa.ancho / 2.0 - 0.6
		var hz := casa.fondo / 2.0 - 0.6
		for vista: Array in [["arriba", Vector3(0, 5.3, hz), Vector3(0, 0, -hz * 0.3)],
				["rincon", Vector3(hx, 3.4, -hz), Vector3(-hx * 0.3, 0.5, hz * 0.4)],
				["otro", Vector3(-hx, 3.4, hz), Vector3(hx * 0.3, 0.5, -hz * 0.4)]]:
			cam.global_position = casa.to_global(vista[1])
			cam.look_at(casa.to_global(vista[2]))
			for k in 15:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s_%d_%s.png" % [casa.tema, i, vista[0]]))
		i += 1
	get_tree().quit()
