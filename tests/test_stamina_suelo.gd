extends Node
## Prueba automática de la recarga de stamina en el piso (headless):
## godot --headless --path . res://tests/test_stamina_suelo.tscn
## Cuanto más tiempo seguido en el piso, más rápido se recarga; al despegar vuelve a empezar de cero.

var paloma: PalomaJugador
var fallas := 0


func _ready() -> void:
	# La curva
	_check("apenas aterriza recarga la base", is_equal_approx(Config.recarga_suelo(0.0), Config.STAMINA_RECARGA_SUELO))
	_check("después de la rampa recarga el máximo", is_equal_approx(Config.recarga_suelo(Config.STAMINA_RAMPA_SUELO), Config.STAMINA_RECARGA_SUELO_MAX))
	_check("más allá de la rampa no sigue subiendo", is_equal_approx(Config.recarga_suelo(30.0), Config.STAMINA_RECARGA_SUELO_MAX))
	var anterior := 0.0
	var crece := true
	for i in 26:
		var r := Config.recarga_suelo(i * 0.1)
		crece = crece and r >= anterior
		anterior = r
	_check("la recarga sólo crece con el tiempo", crece)

	# En el juego
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	paloma.global_position = Vector3(-24, 0.1, 18.5)
	paloma.reset_physics_interpolation()
	await _frames(20)
	_check("empieza en el suelo", paloma.estado == PalomaJugador.Estado.SUELO)

	GameState.set_stamina(0.0)
	paloma._tiempo_en_suelo = 0.0
	await _frames(60)
	var primero := GameState.stamina            # Lo que recargó en el primer segundo
	await _frames(60)
	var segundo := GameState.stamina - primero  # ...y en el segundo
	print("  primer segundo: +%.1f, segundo segundo: +%.1f" % [primero, segundo])
	_check("el segundo segundo recarga más que el primero", segundo > primero + 5.0)
	var cuadros := 120
	while GameState.stamina < Config.STAMINA_MAX - 0.1 and cuadros < 600:
		await _frames(1)
		cuadros += 1
	print("  de 0 a lleno: %.1f s" % (cuadros / 60.0))
	_check("de 0 a lleno en menos de 4 s (y no al instante)", cuadros / 60.0 > 2.5 and cuadros / 60.0 < 4.0)

	GameState.set_stamina(0.0)
	await _frames(20)
	var antes_ramp := paloma._tiempo_en_suelo
	Input.action_press("volar")
	await _frames(3)
	Input.action_release("volar")
	_check("despega", paloma.estado == PalomaJugador.Estado.AIRE)
	await _frames(4)
	_check("en el aire la cuenta del piso vuelve a cero", paloma._tiempo_en_suelo == 0.0 and antes_ramp > 0.0)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
