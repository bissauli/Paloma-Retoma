extends Node
## Benchmark simple: cámara fija en dos vistas, promedio de FPS sin vsync.
## godot --path . res://tests/bench_fps.tscn --disable-vsync

const VISTAS := {
	"suelo": [Vector3(-34, 1.2, 4), Vector3(-20, 1, -4)],
	"alta": [Vector3(0, 40, 60), Vector3(0, 0, 0)],
}


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 400.0
	add_child(cam)
	for i in 30:
		await get_tree().process_frame
	cam.current = true
	for nombre: String in VISTAS:
		var v: Array = VISTAS[nombre]
		cam.global_position = v[0]
		cam.look_at(v[1])
		for i in 60:
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		var n := 0
		var proc := 0.0
		var fis := 0.0
		while Time.get_ticks_usec() - t0 < 3000000:
			await get_tree().process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			fis += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			n += 1
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		print("BENCH %s: %.2f ms/cuadro (%d fps), draw calls %d, proceso %.2f ms, física %.2f ms" % [nombre, ms,
			roundi(1000.0 / ms), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			proc / n * 1000.0, fis / n * 1000.0])
	get_tree().quit()
