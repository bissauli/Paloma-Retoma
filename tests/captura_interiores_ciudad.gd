extends Node
## Capturas (NO headless) de los edificios con interiores que salieron en la ciudad (lejos de la plaza):
## la fachada desde la vereda de enfrente y, para cada uno, una vista de adentro de su primera sala.
## Además, la cámara del juego con la paloma pegada al techo de una sala (no se tiene que ver el hueco
## entre pisos). godot --path . --resolution 1280x720 res://tests/captura_interiores_ciudad.tscn -- <carpeta>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas_interiores_ciudad"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 30:
		await get_tree().process_frame
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var paloma := main.get_node("Paloma") as PalomaJugador
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.current = true
	var i := 0
	for e in Pasaje.edificios_de(main):
		var c := e.global_position
		if Vector2(c.x, c.z).length() < 75.0:
			continue
		var frente := e.global_basis.z.normalized()
		var salas: Array[CasaEnterable] = []
		for h in e.get_children():
			if h is CasaEnterable:
				salas.append(h as CasaEnterable)
		var temas := []
		for s in salas:
			temas.append("%s%s" % [s.tema, "" if s.piso == 0 else " p%d" % s.piso])
		print("edificio %d en %s: %s" % [i, c.round(), temas])
		# La fachada, desde enfrente
		var ancho := 14.0
		cam.global_position = c + frente * (8.0 + ancho * 0.5 + 10.0) + Vector3.UP * 7.0
		cam.look_at(c + frente * 8.0 + Vector3.UP * 9.0)
		paloma.global_position = cam.global_position + Vector3.UP * 40.0
		for k in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(carpeta.path_join("ciudad_%d_fachada.png" % i))
		# Adentro de la primera sala
		if not salas.is_empty():
			var s := salas[0]
			if s.luz:
				s.luz.visible = true
			paloma.global_position = s.to_global(Vector3(0, 1.0, 0))
			cam.global_position = s.to_global(Vector3(-s.ancho * 0.35, 4.6, s.fondo * 0.4))
			cam.look_at(s.to_global(Vector3(s.ancho * 0.15, 1.0, -s.fondo * 0.2)))
			for k in 20:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("ciudad_%d_adentro_%s.png" % [i, s.tema]))
		i += 1
		if i >= 4:
			break
	# La cámara del juego con la paloma contra el techo de una sala
	cam.current = false
	var camara_juego := paloma.get_node("CamaraOrbital/Brazo/Camara") as Camera3D
	camara_juego.current = true
	for n in get_tree().get_nodes_in_group("casa_enterable"):
		var ce := n as CasaEnterable
		if ce.con_cinematica:
			continue
		# Contra el techo, cerca de la vidriera, mirando hacia el fondo del local (como al entrar volando)
		for alto in [Pasaje.PLANTA_BAJA - 0.46, Pasaje.PLANTA_BAJA - 1.6]:
			var techo := ce.to_global(Vector3(0, alto, ce.fondo / 2.0 - 2.5))
			paloma.camara.yaw = ce.global_rotation.y
			paloma.camara.pitch = -0.1
			for k in 60:
				paloma.global_position = techo
				paloma.velocity = Vector3.ZERO
				await get_tree().process_frame
			print("techo %s: paloma %s, pivote %s, camara %s (locales)" % [ce.tema, ce.to_local(paloma.global_position).snapped(Vector3.ONE * 0.01),
				ce.to_local(paloma.camara.global_position).snapped(Vector3.ONE * 0.01), ce.to_local(camara_juego.global_position).snapped(Vector3.ONE * 0.01)])
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("techo_%s_%.1f.png" % [ce.tema, alto]))
		break
	get_tree().quit()
