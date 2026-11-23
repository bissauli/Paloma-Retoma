extends Node
## La cámara no se sale de las salas (locales y departamentos) cuando la paloma vuela pegada al techo:
## antes el punto de donde cuelga la cámara (75 cm sobre la paloma) quedaba arriba del techo y se veía
## el hueco entre pisos del edificio. Pone a la paloma contra el techo de cada sala, en el medio, y
## comprueba que el punto de la cámara y la cámara misma sigan debajo del techo.
## godot --headless --path . res://tests/test_camara_techo.tscn  (con ventana y "-- <carpeta>" guarda capturas)

var fallas := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else ""
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().physics_frame
	var paloma := main.get_node("Paloma") as CharacterBody3D
	var cam := paloma.get_node("CamaraOrbital") as CamaraOrbital
	var salas := get_tree().get_nodes_in_group("casa_enterable")
	var peor := -INF
	var vistas := 0
	for n in salas:
		var ce := n as CasaEnterable
		var centro := ce.to_global(Vector3(0, 0, 0))
		# El techo de la sala (no un rayo: en el medio suele colgar una lámpara)
		var techo := ce.to_global(Vector3(0, Pasaje.PLANTA_BAJA, 0)).y
		var pos := Vector3(centro.x, techo - 0.46, centro.z)   # La esfera de la paloma (r 0,22) tocando el techo
		# Un segundo de verdad (sin ventana los cuadros van mucho más rápido: la cámara se acomoda con el tiempo)
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 1000:
			paloma.global_position = pos
			paloma.velocity = Vector3.ZERO
			await get_tree().process_frame
		var arriba := maxf(cam.global_position.y, cam.camara.global_position.y) - techo
		peor = maxf(peor, arriba)
		vistas += 1
		if arriba > -0.15:
			print("  cerca del techo en %s (%s): %.2f m; paloma %s pivote %s camara %s" % [ce.name, ce.tema, arriba,
				ce.to_local(paloma.global_position).snapped(Vector3.ONE * 0.01), ce.to_local(cam.global_position).snapped(Vector3.ONE * 0.01),
				ce.to_local(cam.camara.global_position).snapped(Vector3.ONE * 0.01)])
		if carpeta != "" and vistas <= 4:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("techo_%s.png" % ce.tema))
	_check("se probaron las salas (%d)" % vistas, vistas >= 6)
	_check("la cámara queda debajo del techo en todas (lo más arriba: %.2f m del techo)" % peor, peor <= -0.1)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(0 if fallas == 0 else 1)


func _check(texto: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALLA ") + texto)
	if not ok:
		fallas += 1
