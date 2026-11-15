extends Node
## Prueba automática de la flecha sobre el balcón (headless):
## godot --headless --path . res://tests/test_guia_balcon.tscn
## Aparece con 30 palomas o más y lejos del balcón; se esconde al estar sobre el balcón y al ganar.

var fallas := 0


func _ready() -> void:
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	var guia: GuiaBalcon
	for n in main.find_children("*", "GuiaBalcon", true, false):
		guia = n as GuiaBalcon
	_check("la plaza tiene la flecha del balcón", guia != null)
	var j := GameState.jugador
	var balcon := guia.destino.global_position
	j.global_position = Vector3(0, 0.5, 0)
	j.reset_physics_interpolation()

	GameState.bandada = 10
	await _frames(30)
	_check("con 10 palomas no se ve", not guia.visible)

	GameState.bandada = Config.UMBRAL_BALCON
	await _frames(40)
	_check("con 30 palomas y lejos se ve", guia.visible)
	_check("flota sobre el balcón", guia.global_position.distance_to(balcon) < guia.altura + 0.5)

	# Sobre el balcón, en el aire (sin física, así no aterriza y gana todavía)
	j.set_physics_process(false)
	j.global_position = balcon + Vector3(-1.0, 4.0, 0.0)
	j.reset_physics_interpolation()
	await _frames(40)
	_check("estando sobre el balcón se esconde", not guia.visible)

	j.global_position = Vector3(0, 0.5, 0)
	j.reset_physics_interpolation()
	await _frames(40)
	_check("al alejarse vuelve a verse", guia.visible)
	j.set_physics_process(true)

	GameState.partida_terminada = true
	await _frames(40)
	_check("al ganar no se ve (no molesta en los bailes)", not guia.visible)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
