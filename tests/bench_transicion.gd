extends Node
## Mide los tirones de la transición del menú principal al juego (NUEVA PARTIDA).
## Correr con ventana (no headless: lo que se mide es el dibujado):
## godot --path . res://tests/bench_transicion.tscn --disable-vsync
## Imprime el cuadro más lento y cuántos pasaron de 50 ms en el menú y durante la transición.


func _ready() -> void:
	var escena: PackedScene = load("res://main.tscn")
	var main: Node = escena.instantiate()
	main.set("forzar_menu", true)
	add_child(main)
	var menu: MenuPrincipal = main.menu
	await _medir("menú", 180)
	menu.botones[1].pressed.emit()
	await _medir("transición", 150)
	await _medir("juego", 120)
	get_tree().quit()


func _medir(nombre: String, cuadros: int) -> void:
	var peor := 0.0
	var lentos := 0
	var total := 0.0
	var t := Time.get_ticks_usec()
	for i in cuadros:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		var ms := (ahora - t) / 1000.0
		t = ahora
		total += ms
		peor = maxf(peor, ms)
		if ms > 50.0:
			lentos += 1
	print("TRANSICION %s: promedio %.1f ms, peor cuadro %.0f ms, cuadros > 50 ms: %d" % [
		nombre, total / cuadros, peor, lentos])
