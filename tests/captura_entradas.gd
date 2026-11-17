extends Node
## Capturas de las entradas de los edificios con interiores (NO headless): la vidriera de cada local
## y la puerta del edificio, desde la vereda, a la altura de la paloma.
## godot --path . --resolution 1280x720 res://tests/captura_entradas.tscn -- <carpeta>

var paloma: PalomaJugador


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(30)
	var n := 0
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		var casa := c as CasaEnterable
		if casa.con_cinematica:
			continue
		for vista in [["vidriera", casa.x_frente, 5.0], ["puerta", casa.ancho * 0.27, 4.0], ["adentro", casa.x_frente, -1.0]]:
			paloma.global_position = casa.to_global(Vector3(float(vista[1]), 0.3, casa.fondo / 2.0 + float(vista[2])))
			paloma.reset_physics_interpolation()
			paloma.velocity = Vector3.ZERO
			paloma.estado = PalomaJugador.Estado.SUELO
			paloma.camara.yaw = casa.rotation.y
			paloma.camara.pitch = -0.05
			paloma.camara.reubicar()
			await _frames(20)
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("%d_%s_%s.png" % [n, casa.tema, vista[0]]))
		n += 1
	get_tree().quit()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
