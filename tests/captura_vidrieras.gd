extends Node
## Una foto de cada rubro de vidriera (NO headless), desde la vereda y un poco de costado, para
## revisar que cada interior se parezca a lo que dice el cartel:
## godot --path . --resolution 960x540 res://tests/captura_vidrieras.tscn -- <carpeta>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://vidrieras"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 30:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	var hechos := {}
	for n in get_tree().root.find_children("Vidriera_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var r := String(mi.name).replace("Vidriera_", "").get_slice("@", 0).rstrip("0123456789")
		if hechos.has(r):
			continue
		hechos[r] = true
		var t := mi.global_transform
		cam.global_position = t * Vector3(0.9, 0.1, 3.2)
		cam.look_at(t * Vector3(0, -0.1, -1.5))
		var paloma: Node3D = main.get_node("Paloma")
		paloma.global_position = cam.global_position + Vector3(0, 30, 0)
		for k in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s.png" % r))
	get_tree().quit()
