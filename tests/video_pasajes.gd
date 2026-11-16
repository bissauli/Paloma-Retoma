extends Node
## Video de los 5 pasajes, uno detrás del otro (con el Movie Maker de Godot, NO headless):
## godot --path . --write-movie <archivo.avi> --fixed-fps 30 res://tests/video_pasajes.tscn
## Con --write-movie el tiempo del juego avanza fijo por cuadro: el video sale fluido aunque la
## máquina sea lenta. Todo se espera por cuadros (no por reloj).

var paloma: PalomaJugador


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _cuadros(20)
	var inicio := paloma.global_position   # Donde arranca la partida: en el piso, con lugar alrededor
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		await _pasada(c as CasaEnterable)
	# Al final, de vuelta en el piso, baila el Gangnam Style (el baile nuevo de la rueda)
	paloma.global_position = inicio
	paloma.reset_physics_interpolation()
	paloma.velocity = Vector3.ZERO
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.camara.pitch = -0.12
	paloma.camara.reubicar()
	await _cuadros(30)
	paloma.bailar(&"gangnam")
	await _cuadros(int(Coreografia.duracion(&"gangnam") * 30.0) + 10)
	get_tree().quit()


## La paloma arranca volando unos metros antes de la ventana de adelante, con la cámara del juego,
## se mete, pasa la cinemática y sigue un segundo volando del otro lado.
func _pasada(casa: CasaEnterable) -> void:
	paloma.global_position = casa.to_global(Vector3(casa.x_frente, CasaEnterable.Y_PASO + 0.3, casa.fondo / 2.0 + 9.0))
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa.rotation.y
	paloma.camara.pitch = -0.15
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = casa.global_transform.basis * Vector3(0, 0, -8)
	paloma.camara.reubicar()
	Input.action_press("mover_adelante")
	var n := 0
	while not casa.activa and n < 240:
		await get_tree().physics_frame
		n += 1
	Input.action_release("mover_adelante")
	while casa.activa:
		await get_tree().process_frame
	await _cuadros(35)


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame
