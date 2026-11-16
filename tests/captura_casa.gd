extends Node
## Capturas de la cinemática de los 5 pasajes (NO headless):
## godot --path . res://tests/captura_casa.tscn -- <carpeta_salida>
## Por cada pasaje, varios fotogramas de la pasada adelante->atrás.

const TIEMPOS := [0.4, 1.0, 1.6, 2.2, 2.8, 3.4, 4.2, 5.0]

var salida := "user://"
var paloma: PalomaJugador


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(30)
	var casas := get_tree().get_nodes_in_group("casa_enterable")
	for i in casas.size():
		var casa := casas[i] as CasaEnterable
		await _pasada(casa, i)
		await _frames(100)
	get_tree().quit()


func _pasada(casa: CasaEnterable, n: int) -> void:
	# La fachada, desde la plaza
	paloma.global_position = casa.to_global(Vector3(0, 3.0, casa.fondo / 2.0 + 14.0))
	paloma.reset_physics_interpolation()
	paloma.estado = PalomaJugador.Estado.AIRE
	paloma.velocity = Vector3.ZERO
	paloma.camara.yaw = 0.0
	paloma.camara.pitch = -0.02
	paloma.camara.reubicar()
	await _frames(25)
	_foto("%d_%s_fachada" % [n, String(casa.name).replace("Entrada_", "")])
	paloma.global_position = casa.to_global(Vector3(casa.x_frente, CasaEnterable.Y_PASO, casa.fondo / 2.0 + 2.8))
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = 0.0
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = Vector3(0, 0, -7)
	Input.action_press("mover_adelante")
	while not casa.activa:
		await get_tree().physics_frame
	Input.action_release("mover_adelante")
	var t0 := Time.get_ticks_msec()
	for k in TIEMPOS.size():
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(TIEMPOS[k]):
			await get_tree().process_frame
		_foto("%d_%s_%d" % [n, String(casa.name).replace("Entrada_", ""), k])
	while casa.activa:
		await get_tree().process_frame


func _foto(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
