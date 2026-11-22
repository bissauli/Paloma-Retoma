extends Node
## Captura (NO headless) de la bici y el macetón de la vereda de cada edificio con interior, para ver que
## están apoyados sobre la vereda (Pasaje.apoyar_en_vereda).
## godot --path . --resolution 1280x720 res://tests/captura_bici.tscn -- <carpeta>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas_bici"
	DirAccess.make_dir_recursive_absolute(carpeta)
	OS.set_environment("PALOMA_SEMILLA", "7")
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 30:
		await get_tree().process_frame
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	# Edificio "Libros El Vuelo" con la semilla 7: bici en (-52.7, 36.55), macetón en (-57.0, 36.25)
	for vista: Array in [["bici", Vector3(-52.7, 0.6, 36.55), Vector3(2.2, 0.9, -2.6)],
			["maceton", Vector3(-57.0, 0.6, 36.25), Vector3(2.0, 1.0, -2.8)]]:
		var obj: Vector3 = vista[1]
		cam.global_position = obj + vista[2]
		cam.look_at(obj)
		for k in 15:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s.png" % vista[0]))
	get_tree().quit()
