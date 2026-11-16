extends Node
## Prueba automática de los pasajes (casas que la paloma atraviesa volando) y su cinemática:
## godot --headless --path . res://tests/test_casas.tscn

const Y := CasaEnterable.Y_PASO

var paloma: PalomaJugador
var fallas := 0
var _terminada := false
var _ultima_desde_frente := false


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(20)

	var casas := get_tree().get_nodes_in_group("casa_enterable")
	_check("hay 5 pasajes (5 escenarios)", casas.size() == 5)
	var casa_a := _casa_en(Vector3(-27, 0, -32))   # Librería El Palomar
	var casa_b := _casa_en(Vector3(26, 0, -32))    # Seguros La Cornisa
	var casa_c := _casa_en(Vector3(-42, 0, -31))   # Panadería El Hornero
	_check("encuentra los pasajes", casa_a != null and casa_b != null and casa_c != null)
	if casa_a == null or casa_b == null or casa_c == null:
		get_tree().quit(1)
		return

	# --- Huecos de verdad, ruta libre, obstáculos y lugar para salir
	for c in casas:
		var casa := c as CasaEnterable
		var xf := casa.x_frente
		var xb := casa.x_fondo
		print("  %s: %d obstáculos" % [casa.name, casa.obstaculos])
		_check("%s: tiene al menos 6 obstáculos" % casa.name, casa.obstaculos >= 6)
		_check("%s: cabe por la ventana de adelante" % casa.name, _cruza(casa, xf, -1.0))
		_check("%s: cabe por la ventana de atrás" % casa.name, _cruza(casa, xb, 1.0))
		_check("%s: la pared maciza la frena" % casa.name, not _cruza(casa, 0.0, -1.0))
		for desde_frente in [true, false]:
			var inicio := Vector3(xf, Y, casa.fondo / 2.0 + 2.6) if desde_frente else Vector3(xb, Y, -casa.fondo / 2.0 - 2.6)
			var choque := _ruta_choca(casa, casa.ruta_de_prueba(desde_frente, casa.to_global(inicio)))
			_check("%s: la ruta %s no toca ningún mueble%s" % [casa.name, "adelante->atrás" if desde_frente else "atrás->adelante",
				"" if choque == "" else " (" + choque + ")"], choque == "")
		var atras := casa.to_global(Vector3(0, 1, -casa.fondo / 2.0 - CasaEnterable.CALLEJON + 0.1))
		_check("%s: el callejón de atrás queda dentro del mapa" % casa.name, atras.z > -40.0)

	# --- Los 5 escenarios, de punta a punta (adelante -> atrás)
	for c in casas:
		var casa := c as CasaEnterable
		await _lanzar(casa, Vector3(casa.x_frente, Y, casa.fondo / 2.0 + 2.6), Vector3(0, 0, -7), 0.0, "mover_adelante")
		var arranco := await _esperar_activa(casa)
		var t0 := Time.get_ticks_msec()
		var cruzo := await _esperar_fin(casa)
		var seg := (Time.get_ticks_msec() - t0) / 1000.0
		print("  %s: pasada de %.1f s" % [casa.name, seg])
		_check("%s: se atraviesa de punta a punta (arranca, cruza y sale por atrás)" % casa.name,
			arranco and cruzo and _terminada and casa.to_local(paloma.global_position).z < -casa.fondo / 2.0)
		_check("%s: es rápida (menos de 6 s)" % casa.name, seg < 6.0)
		await _frames(100)

	# --- Adelante -> atrás: entra por la ventana de la plaza y sale al callejón
	var xf_a := casa_a.x_frente
	await _lanzar(casa_a, Vector3(xf_a, Y, casa_a.fondo / 2.0 + 2.6), Vector3(0, 0, -7), 0.0, "mover_adelante")
	_check("al meterse por la ventana arranca la cinemática", await _esperar_activa(casa_a))
	_check("durante la cinemática la paloma no tiene el control", not paloma.controlable and paloma.en_escena)
	_check("manda la cámara de cine", get_viewport().get_camera_3d() is CamaraCinematica)
	var paso_por_adentro := await _esperar_fin(casa_a)
	_check("la paloma cruzó por adentro de la casa", paso_por_adentro)
	_check("terminó la pasada adelante->atrás", _terminada and _ultima_desde_frente)
	var p_a := casa_a.to_local(paloma.global_position)
	_check("sale por atrás, al callejón (z local %.1f)" % p_a.z, p_a.z < -casa_a.fondo / 2.0)
	_check("sigue volando con envión", paloma.estado == PalomaJugador.Estado.AIRE and paloma.velocity.length() > 4.0)
	_check("recupera el control", paloma.controlable and not paloma.en_escena)
	_check("vuelve la cámara del juego", not (get_viewport().get_camera_3d() is CamaraCinematica))
	await _frames(60)
	_check("en el callejón no queda trabada ni sale del mapa", paloma.global_position.z > -40.0 and not casa_a.esta_adentro(paloma.global_position))
	await _frames(60)

	# --- Atrás -> adelante: del callejón a la plaza, en otra casa
	var xb_c := casa_c.x_fondo
	await _lanzar(casa_c, Vector3(xb_c, Y, -casa_c.fondo / 2.0 - 2.6), Vector3(0, 0, 7), PI, "mover_adelante")
	_check("desde el callejón también arranca", await _esperar_activa(casa_c))
	await _esperar_fin(casa_c)
	_check("terminó la pasada atrás->adelante", _terminada and not _ultima_desde_frente)
	var p_c := casa_c.to_local(paloma.global_position)
	_check("sale por adelante, a la plaza (z local %.1f)" % p_c.z, p_c.z > casa_c.fondo / 2.0)
	_check("recupera el control al salir a la plaza", paloma.controlable and not paloma.en_escena)
	await _frames(100)

	# --- Saltear con una tecla
	var xf_b := casa_b.x_frente
	await _lanzar(casa_b, Vector3(xf_b, Y, casa_b.fondo / 2.0 + 2.6), Vector3(0, 0, -7), 0.0, "mover_adelante")
	_check("arranca la cinemática de la tercera casa", await _esperar_activa(casa_b))
	await _frames(50)
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_X
	tecla.pressed = true
	Input.parse_input_event(tecla)
	var antes := Time.get_ticks_msec()
	await _esperar_fin(casa_b, 400)
	var seg := (Time.get_ticks_msec() - antes) / 1000.0
	print("  saltear tardó ", snappedf(seg, 0.1), " s")
	_check("saltear termina enseguida (< 2,5 s)", _terminada and seg < 2.5)
	_check("al saltear sale igual por atrás", casa_b.to_local(paloma.global_position).z < -casa_b.fondo / 2.0)
	_check("al saltear recupera el control", paloma.controlable and not paloma.en_escena)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _casa_en(base: Vector3) -> CasaEnterable:
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		if (c as Node3D).global_position.distance_to(base) < 0.1:
			return c as CasaEnterable
	return null


## ¿Una esfera del tamaño de la paloma cruza la pared en x = cx (adelante si sentido < 0)?
func _cruza(casa: CasaEnterable, cx: float, sentido: float) -> bool:
	var z0 := casa.fondo / 2.0 + 2.0 if sentido < 0.0 else -casa.fondo / 2.0 - 2.0
	return _barrido(casa.to_global(Vector3(cx, Y, z0)), casa.global_transform.basis * Vector3(0, 0, 3.5 * sentido))


func _barrido(desde: Vector3, mov: Vector3, radio := 0.22) -> bool:
	var forma := SphereShape3D.new()
	forma.radius = radio
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, desde)
	q.motion = mov
	var r := paloma.get_world_3d().direct_space_state.cast_motion(q)
	return r.size() > 0 and float(r[0]) >= 0.999


## Recorre la curva (local a la casa) con una esfera un poco más gorda que la paloma.
## Devuelve "" si no toca nada, o dónde chocó.
func _ruta_choca(casa: CasaEnterable, curva: Curve3D) -> String:
	var forma := SphereShape3D.new()
	forma.radius = 0.26
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	var largo := curva.get_baked_length()
	var s := 0.0
	while s <= largo:
		var p := casa.to_global(curva.sample_baked(s, true))
		q.transform = Transform3D(Basis.IDENTITY, p)
		if not paloma.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return "en %.1f de %.1f m, local %s" % [s, largo, str(casa.to_local(p).snapped(Vector3.ONE * 0.01))]
		s += 0.1
	return ""


## Pone a la paloma volando en "pos_local" (de la casa) con velocidad "vel" (local) y aprieta avanzar.
func _lanzar(casa: CasaEnterable, pos_local: Vector3, vel: Vector3, yaw: float, tecla: String) -> void:
	paloma.global_position = casa.to_global(pos_local)
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa.rotation.y + yaw
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = casa.global_transform.basis * vel
	_terminada = false
	casa.escena_terminada.connect(_al_terminar, CONNECT_ONE_SHOT)
	Input.action_press(tecla)
	await get_tree().physics_frame


func _al_terminar(desde_frente: bool) -> void:
	_terminada = true
	_ultima_desde_frente = desde_frente


func _esperar_activa(casa: CasaEnterable, max_frames := 240) -> bool:
	var n := 0
	while not casa.activa and not _terminada and n < max_frames:
		await get_tree().physics_frame
		n += 1
	Input.action_release("mover_adelante")
	return casa.activa or _terminada


## Espera a que termine; devuelve si en algún momento la paloma estuvo adentro de la casa.
func _esperar_fin(casa: CasaEnterable, max_frames := 1500) -> bool:
	var n := 0
	var adentro := false
	while not _terminada and n < max_frames:
		await get_tree().physics_frame
		adentro = adentro or casa.esta_adentro(paloma.global_position)
		n += 1
	await _frames(4)
	return adentro


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
