extends Node
## Prueba automática del menú principal (correr headless):
## godot --headless --path . res://tests/test_menu.tscn
## 1) El menú está encima del mundo: la paloma ya está en escena, quieta y sin control.
## 2) NUEVA PARTIDA: la paloma salta, la cámara pasa sin cortes a la del juego y vuelve el control.
## 3) CONTINUAR: con una partida guardada de prueba, vuelven la bandada y la comida.
## También revisa los buses de audio y el brillo de Opciones.
## Usa un archivo de partida aparte: no toca la partida guardada de verdad.

var fallas := 0


func _ready() -> void:
	GameState.archivo_partida = "user://prueba_test_menu.cfg"
	GameState.borrar_partida()
	await _nueva_partida()
	await _continuar()
	_buses_y_brillo()
	GameState.borrar_partida()
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _nueva_partida() -> void:
	var main := _crear_main()
	await _frames(30)
	var j: PalomaJugador = main.get_node("Paloma")
	var menu: MenuPrincipal = main.menu
	var cam: CamaraMenu = main.camara_menu
	_check("el menú está visible", menu.visible and GameState.menu_activo)
	_check("la paloma ya está en escena y sin control", j.is_inside_tree() and not j.controlable)
	_check("la cámara del menú es la actual", cam.current)
	_check("sin partida guardada no hay CONTINUAR", not menu._fila(menu.botones[0]).visible)
	_check("el HUD no se ve en el menú", not main.hud.visible)
	_check("los textos del menú están en español", menu.botones[1].text == "NUEVA PARTIDA"
		and menu.botones[2].text == "CARGAR PARTIDA" and menu.botones[3].text == "OPCIONES")
	# Que la paloma mire a la cámara cada tanto: el modificador de la cabeza existe
	_check("la paloma tiene gestos (mirada y parpadeo)", j.modelo.find_children("*", "GestosPaloma", true, false).size() == 1)

	var y0 := j.global_position.y
	var pos_cam := cam.global_position
	menu.botones[1].pressed.emit()
	await _frames(12)
	_check("la paloma salta", j.global_position.y > y0 + 0.2)
	_check("la cámara arranca desde donde estaba (sin corte)", cam.global_position.distance_to(pos_cam) < 0.5)
	# Durante la transición la cámara se mueve de a poco: nunca salta más de 0,6 m por cuadro
	var previa := cam.global_position
	var max_salto := 0.0
	var cuadros := 0
	while is_instance_valid(cam) and cam.current and cuadros < 400:
		await get_tree().process_frame
		if not is_instance_valid(cam):
			break
		max_salto = maxf(max_salto, cam.global_position.distance_to(previa))
		previa = cam.global_position
		cuadros += 1
	print("  transición: %d cuadros, mayor salto de cámara %.3f m" % [cuadros, max_salto])
	_check("la transición es continua", max_salto < 0.6)
	await _frames(5)
	var cam_juego: Camera3D = j.camara.camara
	_check("al final manda la cámara del juego", cam_juego.current)
	_check("la jugadora tiene el control", j.controlable)
	_check("hay partida en curso", GameState.en_partida and not GameState.menu_activo)
	_check("el HUD aparece", main.hud.visible)
	_check("el menú se fue", not menu.visible)
	main.queue_free()
	await _frames(5)


func _continuar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("partida", "version", GameState.VERSION_PARTIDA)
	cfg.set_value("partida", "fecha", int(Time.get_unix_time_from_system()))
	cfg.set_value("partida", "bandada", 6)
	cfg.set_value("partida", "comida", 4)
	cfg.set_value("partida", "tiempo_jugado", 120.0)
	cfg.set_value("partida", "progreso_dia", 0.2)
	cfg.set_value("partida", "tutorial_hecho", true)
	cfg.set_value("partida", "migas_comidas", 5)
	cfg.set_value("partida", "umbrales", [5])
	cfg.save(GameState.archivo_partida)

	var main := _crear_main()
	await _frames(30)
	var menu: MenuPrincipal = main.menu
	_check("con partida guardada aparece CONTINUAR", menu._fila(menu.botones[0]).visible)
	menu.botones[0].pressed.emit()
	await _frames(10)
	_check("vuelve la bandada guardada", GameState.bandada == 6)
	_check("vuelve la comida guardada", GameState.comida == 4)
	_check("el tiempo jugado sigue", GameState.tiempo_jugado >= 120.0)
	var espera := 0
	while GameState.menu_activo and espera < 400:   # Hasta que termina la transición
		await get_tree().process_frame
		espera += 1
	await _frames(5)
	_check("el tutorial no se repite", not is_instance_valid(main.get_node_or_null("Tutorial")))
	main.queue_free()
	await _frames(5)


func _buses_y_brillo() -> void:
	for bus: StringName in [&"Musica", &"Voces", &"Efectos"]:
		_check("existe el bus " + bus, AudioServer.get_bus_index(bus) != -1)
	var previo := Ajustes.volumen_voces
	Ajustes.set_volumen_bus(&"Voces", 0.5)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Voces"))
	_check("el volumen de voz llega al bus", absf(db - linear_to_db(0.5)) < 0.01)
	Ajustes.set_volumen_bus(&"Voces", previo)
	_check("el arrullo sale por el bus de voces", AudioManager.bus_de("arrullo") == &"Voces")
	_check("el aleteo sale por el bus de efectos", AudioManager.bus_de("aleteo") == &"Efectos")
	var env := Environment.new()
	var b := Ajustes.brillo
	Ajustes.brillo = 1.3
	Ajustes.aplicar_brillo(env)
	_check("el brillo se aplica al entorno", env.adjustment_enabled and is_equal_approx(env.adjustment_brightness, 1.3))
	Ajustes.brillo = b


func _crear_main() -> Node:
	var main: Node = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	return main


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
