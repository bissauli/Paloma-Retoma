extends Node
## Capturas de adentro de los locales de la planta baja (NO headless): dos vistas por local, desde
## arriba de la vidriera y desde un rincón del fondo, para revisar cómo están puestos los muebles y la
## gente. Con "seg" se sacan varias fotos espaciadas (para ver a los clientes entrar y salir).
## godot --path . --resolution 1280x720 res://tests/captura_locales.tscn -- <carpeta> [seg]

var paloma: PalomaJugador


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas"
	var seg := float(args[1]) if args.size() > 1 else 0.0
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(30)
	var cam := Camera3D.new()
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	var n := 0
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		var casa := c as CasaEnterable
		if casa.con_cinematica:
			continue
		var hx := casa.ancho / 2.0 - 0.6
		var hz := casa.fondo / 2.0 - 0.6
		# La paloma cerca (la gente sólo se mueve con la paloma a menos de GenteLocal.CERCA)
		paloma.global_position = casa.to_global(Vector3(casa.x_frente, 0.3, casa.fondo / 2.0 + 6.0))
		paloma.reset_physics_interpolation()
		paloma.velocity = Vector3.ZERO
		var vistas := [["frente", Vector3(0, 4.6, hz - 0.1), Vector3(0, 0, -hz * 0.4)],
			["fondo", Vector3(hx, 3.2, -hz), Vector3(-hx * 0.4, 0.6, hz * 0.5)]]
		if seg > 0.0:
			vistas = [["puerta", Vector3(casa.x_frente + 3.0, 3.4, casa.fondo / 2.0 + 5.0), Vector3(casa.x_frente, 0.8, 0)]]
		for vista: Array in vistas:
			var veces := 6 if seg > 0.0 else 1
			for k in veces:
				cam.global_position = casa.to_global(vista[1])
				cam.look_at(casa.to_global(vista[2]))
				await _frames(20 if seg <= 0.0 else int(seg * 60.0))
				get_viewport().get_texture().get_image().save_png(carpeta.path_join("%d_%s_%s_%d.png" % [n, casa.tema, vista[0], k]))
		n += 1
	get_tree().quit()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
