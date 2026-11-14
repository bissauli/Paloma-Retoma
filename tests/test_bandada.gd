extends Node
## Prueba automática de comida, reclutamiento y bandada (headless):
## godot --headless --path . res://tests/test_bandada.tscn

var fallas := 0


func _ready() -> void:
	# Con "-- movil" corre con el perfil del teléfono (física a 30 Hz)
	if OS.get_cmdline_user_args().has("movil"):
		Ajustes.movil = true
		Ajustes.aplicar_perfil_movil()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var paloma := main.get_node("Paloma") as PalomaJugador
	var bandada := main.get_node("Bandada") as Bandada
	await _frames(10)
	var total := bandada.get_child_count()
	print("  palomas NPC creadas: ", total)
	_check("hay palomas sueltas suficientes (>= 40)", total >= 40)

	# Migas: comer una recupera stamina y suma comida
	GameState.set_stamina(30.0)
	var miga: Comida = null
	for c in get_tree().get_nodes_in_group("comida"):
		if c is Comida and c.tipo == "miga":
			miga = c
			break
	_check("hay migas en el mapa", miga != null)
	if miga:
		miga.picoteada(paloma)
		_check("la miga da stamina y comida", GameState.stamina > 45.0 and GameState.comida == 1)

	# Arrullo sin comida suficiente en la Catedral, después con comida
	paloma.global_position = Vector3(0, 0.1, -14)
	paloma.reset_physics_interpolation()
	await _frames(5)
	GameState.sumar_comida(9)
	paloma.arrullar()
	await _frames(2)
	print("  bandada tras arrullar con 10 de comida: ", GameState.bandada, " (comida restante ", GameState.comida, ")")
	_check("el arrullo recluta palomas gastando comida", GameState.bandada >= 5 and GameState.comida == 10 - GameState.bandada)

	# La bandada sigue a la jugadora cuando vuela
	paloma.global_position = Vector3(10, 6, -5)
	paloma.reset_physics_interpolation()
	await _frames(240)
	var cerca := 0
	for p in bandada.seguidoras:
		if p.global_position.distance_to(paloma.global_position) < 9.0:
			cerca += 1
	print("  seguidoras cerca de la jugadora después de 4 s: ", cerca, "/", bandada.seguidoras.size())
	_check("la bandada la sigue", cerca >= bandada.seguidoras.size() - 1)

	# Perder palomas
	var antes := GameState.bandada
	GameState.pedir_perdida(2, paloma.global_position)
	await _frames(2)
	_check("perder palomas descuenta la bandada", GameState.bandada == antes - 2)

	# Comida pesada al nido
	GameState.set_carga("medialuna")
	var c0 := GameState.comida
	paloma.global_position = Vector3(2, 0.7, 2)
	paloma.reset_physics_interpolation()
	await _frames(5)
	_check("entregar la medialuna en el nido suma comida", GameState.carga == "" and GameState.comida == c0 + Config.COMIDA_MEDIALUNA)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Espera n pasos de física "de 60 Hz" (con la física a 30 Hz, la mitad: el mismo tiempo).
## Las esperas cortas (que la física vea una tecla) no se achican.
func _frames(n: int) -> void:
	for i in (n if n <= 4 else roundi(n * Engine.physics_ticks_per_second / 60.0)):
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
