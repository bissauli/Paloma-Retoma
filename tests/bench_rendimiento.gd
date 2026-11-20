extends Node
## Benchmark de rendimiento más completo que bench_fps: varias vistas (suelo, aérea y con la
## bandada volando alrededor de la paloma), con FPS sin vsync, draw calls, objetos y primitivas;
## lo que cuesta cada sistema por paso de física y el costo de un paso de física completo.
##
##   godot --path . res://tests/bench_rendimiento.tscn --disable-vsync -- [calidad=0|1|2] [movil] [bandada=N] [comic=0|1]
##
## "movil" emula la versión para teléfonos (Ajustes.movil): sus gráficos y su física.

const SEGUNDOS := 3.0


func _ready() -> void:
	var calidad := -1
	var bandada := 40
	var movil := false
	for a in OS.get_cmdline_user_args():
		if a == "movil":
			movil = true
		elif a.begins_with("calidad="):
			calidad = int(a.get_slice("=", 1))
		elif a.begins_with("bandada="):
			bandada = int(a.get_slice("=", 1))
		elif a.begins_with("comic="):
			Ajustes.estilo_comic = a.get_slice("=", 1) != "0"
	if movil:
		Ajustes.movil = true
		Ajustes.calidad = 0
		if Ajustes.has_method("aplicar_perfil_movil"):
			Ajustes.aplicar_perfil_movil()
	if calidad >= 0:
		Ajustes.calidad = calidad
	Ajustes._aplicar_graficos()
	EstiloComic.aplicar()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameState.guardado_habilitado = false

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	for i in 30:
		await get_tree().process_frame
	print("BENCH config: calidad %d, movil %s, cómic %s, física %d Hz, escala 3D %.2f" % [Ajustes.calidad, Ajustes.movil, Ajustes.estilo_comic,
		Engine.physics_ticks_per_second, get_viewport().scaling_3d_scale])

	# 1) Vistas fijas sin bandada
	cam.current = true
	await _vista(cam, "suelo", Vector3(-34, 1.2, 4), Vector3(-20, 1, -4))
	await _vista(cam, "alta", Vector3(0, 40, 60), Vector3(0, 0, 0))

	# 2) La bandada volando alrededor de la paloma, que queda quieta en el aire sobre la plaza
	var jugador := get_tree().get_first_node_in_group("jugador") as PalomaJugador
	var b := main.get_node("Bandada") as Bandada
	b.restaurar(bandada)
	jugador.set_physics_process(false)
	jugador.global_position = Vector3(-20, 9, 2)
	jugador.estado = PalomaJugador.Estado.AIRE
	jugador.velocity = Vector3.ZERO
	jugador.camara.camara.current = true
	jugador.camara.yaw = PI * 0.5
	jugador.camara.reubicar()
	for i in 240:
		await get_tree().process_frame
	await _medir("bandada x%d (cámara de juego)" % GameState.bandada)

	# 3) Cuánto cuesta cada sistema por paso de física (llamando su código directamente)
	_micro(main, b)
	# 4) Costo real de un paso de física completo (scripts, Jolt, interpolación...): los FPS con la
	# física a su frecuencia normal contra 4 veces más pasos. El monitor TIME_PHYSICS_PROCESS
	# varía demasiado de una medición a otra para esto.
	var hz := Engine.physics_ticks_per_second
	var pasos_max := Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 16
	var f1 := await _fps()
	Engine.physics_ticks_per_second = hz * 4
	var f4 := await _fps()
	Engine.physics_ticks_per_second = hz
	Engine.max_physics_steps_per_frame = pasos_max
	var r := f4 / f1
	var costo := (1.0 - r) / (hz * 4.0 - hz * r)
	print("BENCH paso de física completo: %.2f ms (%d por segundo = %.1f ms de CPU por segundo)" % [
		costo * 1000.0, hz, costo * 1000.0 * hz])
	get_tree().quit()


func _fps() -> float:
	for i in 30:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	var n := 0
	while Time.get_ticks_usec() - t0 < SEGUNDOS * 1000000.0:
		await get_tree().process_frame
		n += 1
	return n / ((Time.get_ticks_usec() - t0) / 1000000.0)


## Tiempo de CPU de cada sistema, llamando su código N veces seguidas (ms por paso de 1/60 s).
func _micro(main: Node, b: Bandada) -> void:
	const N := 40
	const DT := 1.0 / 60.0
	var sueltas: Array[Node] = []
	var mixers: Array[AnimationMixer] = []
	for p in get_tree().get_nodes_in_group("palomas_npc"):
		if (p as PalomaNPC).modo != PalomaNPC.Modo.SIGUIENDO:
			sueltas.append(p)
	for m in main.find_children("*", "AnimationMixer", true, false):
		mixers.append(m as AnimationMixer)
	var humanos := get_tree().get_nodes_in_group("humanos")
	var chicos := get_tree().get_nodes_in_group("chicos")
	var animales := get_tree().get_nodes_in_group("animales")
	var comidas := get_tree().get_nodes_in_group("comida")
	var transito := main.get_node_or_null("Plaza/Transito")
	var casos := {
		"bandada: choques": func() -> void: b._resolver_choques(),
		"bandada: boids seguidoras": func() -> void: b._mover_seguidoras(DT),
		"palomas sueltas (%d)" % sueltas.size(): func() -> void:
			for p in sueltas: p._physics_process(DT),
		"animaciones (%d mixers)" % mixers.size(): func() -> void:
			for m in mixers: m.advance(DT),
		"humanos (%d)" % humanos.size(): func() -> void:
			for h in humanos:
				if is_instance_valid(h): h._physics_process(DT),
		"chicos (%d)" % chicos.size(): func() -> void:
			for c in chicos:
				if is_instance_valid(c): c._process(DT),
		"perros y gatos (%d)" % animales.size(): func() -> void:
			for a in animales:
				if is_instance_valid(a): a._process(DT),
		"comida (%d)" % comidas.size(): func() -> void:
			for c in comidas:
				if is_instance_valid(c): c._process(DT),
	}
	if transito:
		casos["tránsito"] = func() -> void: transito._physics_process(DT)
	var modelos: Array[Node] = []
	for p in get_tree().get_nodes_in_group("palomas_npc"):
		modelos.append((p as PalomaNPC).modelo)
	if modelos.size() > 0 and modelos[0].has_method("_avanzar_animacion"):
		casos["LOD de animación (%d palomas)" % modelos.size()] = func() -> void:
			for m in modelos: m._avanzar_animacion(DT)
	casos["rayo de choque (%d seguidoras)" % b.seguidoras.size()] = func() -> void:
		for p in b.seguidoras: p.mover_con_choques(Vector3(0.001, 0, 0))
	for nombre: String in casos:
		var f: Callable = casos[nombre]
		var t0 := Time.get_ticks_usec()
		for i in N:
			f.call()
		print("BENCH micro %s: %.3f ms/paso" % [nombre, (Time.get_ticks_usec() - t0) / 1000.0 / N])


func _vista(cam: Camera3D, nombre: String, desde: Vector3, hacia: Vector3) -> void:
	cam.global_position = desde
	cam.look_at(hacia)
	for i in 60:
		await get_tree().process_frame
	await _medir(nombre)


func _medir(nombre: String, completo := true) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var n := 0
	var fis := 0.0
	var n_fis := 0
	var peor := 0.0
	var t_prev := t0
	var dc := 0.0
	var obj := 0.0
	var prim := 0.0
	while Time.get_ticks_usec() - t0 < SEGUNDOS * 1000000.0:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		peor = maxf(peor, (ahora - t_prev) / 1000.0)
		t_prev = ahora
		var f := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		if f > 0.0:
			fis += f
			n_fis += 1
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	var r := {"ms": ms, "draw_calls": dc / n, "fisica": fis / maxi(n_fis, 1) * 1000.0}
	if completo:
		print("BENCH %s: %.2f ms/cuadro (%d fps, peor %.1f ms), draw calls %d, objetos %d, primitivas %dk, física %.2f ms/paso" % [
			nombre, ms, roundi(1000.0 / ms), peor, roundi(dc / n), roundi(obj / n), roundi(prim / n / 1000.0), r["fisica"]])
	else:
		print("BENCH %s: %.2f ms/cuadro, física %.2f ms/paso" % [nombre, ms, r["fisica"]])
	return r
