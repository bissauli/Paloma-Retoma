extends Node
## Recorrido: la paloma cruza todo el mapa en serpentina (alto y bajo) a 45 m/s y se anota cada cuadro lento
## con la posición donde pasó. Sirve para encontrar las zonas que dan tirones al cargarse / aparecer.
##   godot --path . res://tests/bench_recorrido.tscn --disable-vsync

const UMBRAL_MS := 9.0
const RAPIDEZ := 45.0


func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 120:
		await get_tree().process_frame
	var j := get_tree().get_first_node_in_group("jugador") as PalomaJugador
	j.camara.camara.current = true
	# Extensión del mapa: la caja de todo lo que se dibuja cerca del piso
	var caja := AABB()
	var primero := true
	for n in main.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.global_position.length() > 400.0:
			continue
		if primero:
			caja = AABB(m.global_position, Vector3.ZERO)
			primero = false
		else:
			caja = caja.expand(m.global_position)
	print("RECORRIDO caja del mapa: ", caja)
	var ruta: Array[Vector3] = []
	var x0 := caja.position.x + 8.0
	var x1 := caja.end.x - 8.0
	var z := caja.position.z + 8.0
	var alto := true
	var sentido := 1
	while z < caja.end.z - 8.0:
		var a := Vector3(x0 if sentido > 0 else x1, 14.0 if alto else 4.0, z)
		var b := Vector3(x1 if sentido > 0 else x0, 14.0 if alto else 4.0, z)
		ruta.append(a)
		ruta.append(b)
		z += 150.0
		sentido = -sentido
		alto = not alto
	var dts := PackedFloat64Array()
	var lentos := []
	var t_prev := Time.get_ticks_usec()
	var t_ini := t_prev
	for k in ruta.size() - 1:
		var a := ruta[k]
		var b := ruta[k + 1]
		var largo := a.distance_to(b)
		var dir := (b - a) / maxf(largo, 0.01)
		var rec := 0.0
		while rec < largo:
			await get_tree().process_frame
			var ahora := Time.get_ticks_usec()
			var d := (ahora - t_prev) / 1000.0
			t_prev = ahora
			dts.append(d)
			rec += RAPIDEZ * minf(d / 1000.0, 0.05)
			var p := a + dir * minf(rec, largo)
			j.global_position = p
			j.velocity = dir * RAPIDEZ
			if d > UMBRAL_MS:
				lentos.append("%.1fms @(%d,%d,%d) t=%.1fs" % [d, p.x, p.y, p.z, (ahora - t_ini) / 1e6])
	dts.sort()
	var n := dts.size()
	print("RECORRIDO n=%d p50=%.2f p99=%.2f p999=%.2f max=%.2f ms" % [n, dts[n / 2], dts[int(n * 0.99)], dts[int(n * 0.999)], dts[n - 1]])
	print("RECORRIDO lentos (>%.0f ms): %d" % [UMBRAL_MS, lentos.size()])
	for s in lentos.slice(0, 40):
		print("RECORRIDO   ", s)
	get_tree().quit()
