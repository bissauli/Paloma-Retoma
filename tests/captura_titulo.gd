extends Node
## Captura de la pantalla de título (NO headless).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var t: Node = load("res://ui/titulo.tscn").instantiate()
	add_child(t)
	for i in 90:
		await get_tree().process_frame
	if args.size() > 0:
		get_viewport().get_texture().get_image().save_png(args[0].path_join("t1_titulo.png"))
	get_tree().quit()
