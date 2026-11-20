extends Node
## Video de los interiores (con el Movie Maker de Godot, NO headless):
## godot --path . --write-movie <archivo.avi> --fixed-fps 30 res://tests/video_pasajes.tscn
## Con --write-movie el tiempo del juego avanza fijo por cuadro: el video sale fluido aunque la
## máquina sea lenta. Todo se espera por cuadros (no por reloj).
## 1) Entra caminando a dos locales de la planta baja (sin cinemática) y mira alrededor.
## 2) Entra volando a un departamento SIN apretar nada (entrada libre).
## 3) En cada departamento: se acerca a la ventana, aparece el aviso "E · ATRAVESAR VOLANDO", lo
##    aprieta y pasa la cinemática.
## 4) Termina bailando el Gangnam Style.

var paloma: PalomaJugador


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _cuadros(20)
	var inicio := paloma.global_position   # Donde arranca la partida: en el piso, con lugar alrededor
	# Con algunos accesorios puestos (al final se deja el perfil como estaba: el juego lo guarda)
	var perfil := PerfilPaloma.actual()
	var antes: Array = perfil.accesorios.duplicate()
	for par in [[0, 6], [1, 2], [4, 1], [5, 1]]:   # Corona, capa, gafas de sol y cadena de oro
		perfil.set_accesorio(par[0], par[1])
	var locales: Array[CasaEnterable] = []
	var deptos: Array[CasaEnterable] = []
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		if (c as CasaEnterable).con_cinematica:
			deptos.append(c)
		else:
			locales.append(c)
	for i in mini(2, locales.size()):
		await _entrar_caminando(locales[i])
	if not deptos.is_empty():
		await _entrar_libre(deptos[0])
	for casa in deptos:
		await _pasada(casa)
	# Al final, de vuelta en el piso, baila el Gangnam Style (con la cámara más cerca)
	paloma.global_position = inicio
	paloma.reset_physics_interpolation()
	paloma.velocity = Vector3.ZERO
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.camara.pitch = -0.1
	paloma.camara.reubicar()
	var largo: float = paloma.camara.distancia_suelo
	paloma.camara.distancia_suelo = largo * 0.5
	await _cuadros(30)
	paloma.bailar(&"gangnam")
	await _cuadros(int(Coreografia.duracion(&"gangnam") * 30.0) + 10)
	paloma.camara.distancia_suelo = largo
	for i in antes.size():
		perfil.set_accesorio(i, antes[i])
	await _cuadros(5)
	get_tree().quit()


## Camina desde la vereda hasta adentro del local por la vidriera abierta y gira la cámara.
func _entrar_caminando(casa: CasaEnterable) -> void:
	paloma.global_position = casa.to_global(Vector3(casa.x_frente, 0.4, casa.fondo / 2.0 + 4.0))
	paloma.reset_physics_interpolation()
	paloma.velocity = Vector3.ZERO
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.camara.yaw = casa.rotation.y
	paloma.camara.pitch = -0.12
	paloma.camara.reubicar()
	await _cuadros(15)
	Input.action_press("mover_adelante")
	await _cuadros(95)
	Input.action_release("mover_adelante")
	for i in 70:   # Mira el local
		paloma.camara.yaw += 0.025
		await get_tree().process_frame


## Vuela hacia la ventana de un departamento sin apretar el aviso: entra sola, sin cinemática.
func _entrar_libre(casa: CasaEnterable) -> void:
	paloma.global_position = casa.to_global(Vector3(casa.x_frente, CasaEnterable.Y_PASO + 0.3, casa.fondo / 2.0 + 6.0))
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa.rotation.y
	paloma.camara.pitch = -0.1
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.camara.reubicar()
	for i in 110:
		paloma.velocity = casa.global_transform.basis * Vector3(0, 0.25, -4.5)
		await get_tree().physics_frame
	for i in 60:
		paloma.camara.yaw += 0.03
		await get_tree().process_frame
	await _cuadros(20)


## Se acerca volando a la ventana, se ve el aviso un momento, lo aprieta y pasa la cinemática.
func _pasada(casa: CasaEnterable) -> void:
	paloma.global_position = casa.to_global(Vector3(casa.x_frente, CasaEnterable.Y_PASO + 0.3, casa.fondo / 2.0 + 7.0))
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa.rotation.y
	paloma.camara.pitch = -0.12
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.camara.reubicar()
	var n := 0
	while not AvisoPasaje.visible_ahora() and n < 120:
		paloma.velocity = casa.global_transform.basis * Vector3(0, 0.3, -5.0)
		await get_tree().physics_frame
		n += 1
	for i in 50:   # Se ve el aviso un rato
		paloma.velocity = casa.global_transform.basis * Vector3(0, 0.6, -0.4)
		await get_tree().physics_frame
	AvisoPasaje.apretar()
	await _cuadros(2)
	while casa.activa:
		await get_tree().process_frame
	await _cuadros(30)


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame
