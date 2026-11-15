## Estabilidad de cuadros: 20 s con la bandada de 60 volando en círculos a 15 m/s. Imprime p50, p99,
## p99.9 y el peor cuadro (lo que se siente como tirones; el promedio de FPS los esconde).
##   godot --path . res://tests/bench_estabilidad.tscn --disable-vsync
extends Node
func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 60: await get_tree().process_frame
	var j := get_tree().get_first_node_in_group("jugador") as PalomaJugador
	var b := main.get_node("Bandada") as Bandada
	b.restaurar(60)
	j.camara.camara.current = true
	for i in 200: await get_tree().process_frame
	var dts := PackedFloat64Array()
	var picos := []
	var t_prev := Time.get_ticks_usec()
	var t0 := t_prev
	var ang := 0.0
	while Time.get_ticks_usec() - t0 < 20000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var d := (now - t_prev) / 1000.0
		t_prev = now
		dts.append(d)
		if d > 5.0: picos.append("%.1f@%.1fs" % [d, (now - t0) / 1e6])
		ang += 0.01
		j.global_position = Vector3(cos(ang) * 30, 10, sin(ang) * 20)
		j.velocity = Vector3(-sin(ang), 0, cos(ang)) * 15
	dts.sort()
	var n := dts.size()
	print("ESTABILIDAD n=%d p50=%.2f p99=%.2f p999=%.2f max=%.2f ms" % [n, dts[n/2], dts[int(n*0.99)], dts[int(n*0.999)], dts[n-1]])
	print("ESTABILIDAD picos>5ms: ", picos.size(), " ", picos.slice(0, 25))
	get_tree().quit()
