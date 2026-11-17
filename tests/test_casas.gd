extends Node
## Prueba automática de los interiores de los edificios de alrededor de la plaza (world/pasaje.gd) y de
## la cinemática para atravesar los departamentos (world/casa_enterable.gd):
## godot --headless --path . res://tests/test_casas.tscn
## - Cada edificio: un local en la planta baja (se entra caminando, sin cinemática) y un ambiente de
##   departamento en un piso del 2 al 7 (se entra libremente; cerca de la ventana aparece el aviso y la
##   cinemática arranca sólo si se aprieta).

const Y := CasaEnterable.Y_PASO

var paloma: PalomaJugador
var fallas := 0
var _terminada := false
var _ultima_desde_frente := false
var _hamaca_max := 0.0


func _ready() -> void:
	# Los locales, los ambientes y los pisos se sortean en cada partida: acá con una semilla fija
	if OS.get_environment("PALOMA_SEMILLA") == "":
		OS.set_environment("PALOMA_SEMILLA", "7")
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(20)

	var todas := get_tree().get_nodes_in_group("casa_enterable")
	var locales: Array[CasaEnterable] = []
	var deptos: Array[CasaEnterable] = []
	for c in todas:
		var casa := c as CasaEnterable
		if casa.con_cinematica:
			deptos.append(casa)
		else:
			locales.append(casa)
	var n := Edificios.ALREDEDORES.size()
	_check("hay al menos un local por edificio y un departamento por edificio (%d y %d)" % [locales.size(), deptos.size()],
		locales.size() >= n and deptos.size() == n)
	_check("los edificios anchos tienen dos locales (hay más locales que edificios: %d)" % locales.size(), locales.size() > n)
	if deptos.size() < 4:
		get_tree().quit(1)
		return
	var casa_a := deptos[0]
	var casa_b := deptos[3]
	var casa_c := deptos[1]
	# --- Locales en la planta baja; ambientes de departamento en un piso del 2 al 7
	var temas_l := {}
	var temas_d := {}
	var pisos := {}
	for casa in locales:
		temas_l[casa.tema] = true
		print("  %s: local (%s) en la planta baja" % [casa.name, casa.tema])
		_check("%s: el local es de la lista de locales" % casa.name, Pasaje.LOCALES.has(casa.tema))
		_check("%s: el local está en la planta baja" % casa.name, casa.piso == 0 and absf(casa.global_position.y) < 0.01)
		_check("%s: al local se entra caminando (la vidriera llega al piso)" % casa.name, _cruza(casa, casa.x_frente, -1.0, 0.35))
		var personas := 0
		for g in get_tree().get_nodes_in_group("cuerpos_humanos"):
			if (g as Node3D).get_parent() is GenteLocal and ((g as Node3D).get_parent() as GenteLocal).ce == casa:
				personas += 1
		_check("%s: tiene empleado y al menos un cliente (%d personas)" % [casa.name, personas], personas >= 2)
	for casa in deptos:
		temas_d[casa.tema] = true
		pisos[casa.piso] = true
		print("  %s: departamento (%s) en el piso %d" % [casa.name, casa.tema, casa.piso])
		_check("%s: es un ambiente de casa" % casa.name, Pasaje.AMBIENTES.has(casa.tema))
		var cuenta: Dictionary = casa.get_meta(&"cuenta", {})
		var de_mas := []
		for mueble in cuenta:
			if Pasaje.LIMITE.has(mueble) and int(cuenta[mueble]) > int(Pasaje.LIMITE[mueble]):
				de_mas.append("%s x%d" % [mueble, cuenta[mueble]])
		_check("%s: nada repetido de más (un lavarropas, un horno, una cama...)%s" % [casa.name, "" if de_mas.is_empty() else " " + str(de_mas)], de_mas.is_empty())
		_check("%s: está en un piso del %d al %d" % [casa.name, Pasaje.PISO_MIN, Pasaje.PISO_MAX],
			casa.piso >= Pasaje.PISO_MIN and casa.piso <= Pasaje.PISO_MAX)
		_check("%s: está a la altura de su piso" % casa.name,
			absf(casa.global_position.y - casa.piso * Pasaje.ALTO_PISO) < 0.01)
	_check("los locales son todos distintos (%d)" % temas_l.size(), temas_l.size() == locales.size())
	_check("los ambientes son todos distintos (%d)" % temas_d.size(), temas_d.size() == n)
	_check("hay al menos 7 ambientes de casa posibles (%d)" % Pasaje.AMBIENTES.size(), Pasaje.AMBIENTES.size() >= 7)
	_check("los pisos no son todos iguales (%d distintos)" % pisos.size(), pisos.size() > 1)

	# --- Huecos de verdad, ruta libre, obstáculos y lugar para salir
	for casa in locales + deptos:
		var xf := casa.x_frente
		var xb := casa.x_fondo
		print("  %s: %d obstáculos" % [casa.name, casa.obstaculos])
		_check("%s: tiene al menos 6 obstáculos" % casa.name, casa.obstaculos >= 6)
		_check("%s: cabe por la ventana de adelante" % casa.name, _cruza(casa, xf, -1.0))
		_check("%s: cabe por la ventana de atrás" % casa.name, _cruza(casa, xb, 1.0))
		_check("%s: la pared maciza la frena" % casa.name, not _cruza(casa, 0.0, -1.0))
		for desde_frente in [true, false]:
			var inicio := Vector3(xf, Y, casa.fondo / 2.0 + 2.6) if desde_frente else Vector3(xb, Y, -casa.fondo / 2.0 - 2.6)
			# En los locales (sin cinemática) sólo importa el tramo de adentro: es el pasillo
			var choque := _ruta_choca(casa, casa.ruta_de_prueba(desde_frente, casa.to_global(inicio)), not casa.con_cinematica)
			_check("%s: la ruta %s no toca ningún mueble%s" % [casa.name, "adelante->atrás" if desde_frente else "atrás->adelante",
				"" if choque == "" else " (" + choque + ")"], choque == "")
		var atras := casa.to_global(Vector3(0, 1, -casa.fondo / 2.0 - CasaEnterable.CALLEJON + 0.1))
		_check("%s: atrás hay lugar para salir (dentro de la ciudad)" % casa.name, atras.z > Ciudad.Z_MIN and atras.z < Ciudad.Z_MAX)

	# --- En un local no hay aviso ni cinemática aunque se meta volando por la vidriera
	var local := locales[0]
	paloma.global_position = local.to_global(Vector3(local.x_frente, Y, local.fondo / 2.0 + 2.0))
	paloma.reset_physics_interpolation()
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = local.global_transform.basis * Vector3(0, 0, -6)
	await _frames(40)
	_check("en un local no aparece el aviso ni arranca la cinemática", not AvisoPasaje.visible_ahora() and not local.activa)
	await _frames(40)

	# --- Sin apretar el botón: entra volando libremente, sin cinemática
	paloma.global_position = casa_b.to_global(Vector3(casa_b.x_frente, Y, casa_b.fondo / 2.0 + 2.2))
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa_b.rotation.y
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = casa_b.global_transform.basis * Vector3(0, 0.6, -6)
	await _frames(3)
	_check("frente a la ventana de un departamento aparece el aviso para atravesar", AvisoPasaje.visible_ahora())
	var entro := false
	for i in 90:
		await get_tree().physics_frame
		paloma.velocity = casa_b.global_transform.basis * Vector3(0, 0.6, -6)
		entro = entro or casa_b.esta_adentro(paloma.global_position)
	_check("sin apretarlo, entra sola al departamento", entro)
	_check("sin apretarlo, no hay cinemática", not casa_b.activa and paloma.controlable and not paloma.en_escena)
	_check("adentro, el aviso se va", not AvisoPasaje.visible_ahora())
	await _frames(60)

	# --- Apretando el botón: cada departamento, de punta a punta (adelante -> atrás)
	for casa in deptos:
		await _lanzar(casa, Vector3(casa.x_frente, Y, casa.fondo / 2.0 + 2.6), Vector3(0, 0, -7), 0.0, "mover_adelante")
		var arranco := await _esperar_activa(casa)
		var t0 := Time.get_ticks_msec()
		var cruzo := await _esperar_fin(casa)
		var seg := (Time.get_ticks_msec() - t0) / 1000.0
		print("  %s: pasada de %.1f s" % [casa.name, seg])
		_check("%s: se atraviesa de punta a punta (arranca, cruza y sale por atrás)" % casa.name,
			arranco and cruzo and _terminada and casa.to_local(paloma.global_position).z < -casa.fondo / 2.0)
		_check("%s: dura lo justo (menos de 8 s, con el plano final y la vuelta a la cámara)" % casa.name, seg < 8.0)
		# Lo que cuelga se hamaca después de que pasa (los ventiladores giran, no se hamacan)
		var hamaca := _hamaca_max
		var hay := false
		for piv in casa.colgantes:
			if not piv.has_meta(&"gira"):
				hay = true
		if hay:
			_check("%s: lo que cuelga se hamaca al pasar (%.2f rad)" % [casa.name, hamaca], hamaca > 0.02)
		if casa.estilo == CasaEnterable.Estilo.CENITAL and not casa.salames.is_empty():
			_check("%s: se roba un salame" % casa.name, casa.robo)
		if casa.estilo == CasaEnterable.Estilo.DE_FRENTE:
			_check("%s: tiene escritorios de donde vuelan papeles" % casa.name, casa.mesas.size() > 0)
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
	var pa := paloma.global_position
	# (Que siga a toda velocidad depende de qué haya detrás: con el piso al azar puede toparse con otro edificio)
	_check("al salir por atrás queda fuera de la casa y dentro de la ciudad", not casa_a.esta_adentro(pa)
		and pa.z > Ciudad.Z_MIN and pa.z < Ciudad.Z_MAX and pa.x > Ciudad.X_MIN and pa.x < Ciudad.X_MAX)
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
## "altura": a qué altura (local) va la esfera (a ras del piso, para ver si se entra caminando).
func _cruza(casa: CasaEnterable, cx: float, sentido: float, altura := Y) -> bool:
	var z0 := casa.fondo / 2.0 + 2.0 if sentido < 0.0 else -casa.fondo / 2.0 - 2.0
	return _barrido(casa.to_global(Vector3(cx, altura, z0)), casa.global_transform.basis * Vector3(0, 0, 3.5 * sentido))


func _barrido(desde: Vector3, mov: Vector3, radio := 0.22) -> bool:
	var forma := SphereShape3D.new()
	forma.radius = radio
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	q.transform = Transform3D(Basis.IDENTITY, desde)
	q.motion = mov
	var r := paloma.get_world_3d().direct_space_state.cast_motion(q)
	var ok := r.size() > 0 and float(r[0]) >= 0.999
	if not ok and r.size() > 0:   # Qué la frenó (para saber qué arreglar)
		q.transform = Transform3D(Basis.IDENTITY, desde + mov * float(r[1]))
		q.motion = Vector3.ZERO
		var info := paloma.get_world_3d().direct_space_state.get_rest_info(q)
		if not info.is_empty():
			var obj := instance_from_id(info["collider_id"]) as Node
			print("    la frena: %s en %s" % [obj.get_path() if obj else "?", info["point"]])
	return ok



## Recorre la curva (local a la casa) con una esfera un poco más gorda que la paloma.
## Devuelve "" si no toca nada, o dónde chocó.
func _ruta_choca(casa: CasaEnterable, curva: Curve3D, solo_adentro := false) -> String:
	var forma := SphereShape3D.new()
	forma.radius = 0.26
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1
	var largo := curva.get_baked_length()
	var s := 0.0
	while s <= largo:
		var pl := curva.sample_baked(s, true)
		if solo_adentro and absf(pl.z) > casa.fondo / 2.0 - CasaEnterable.ESPESOR:
			s += 0.1
			continue
		var p := casa.to_global(pl)
		q.transform = Transform3D(Basis.IDENTITY, p)
		if not paloma.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return "en %.1f de %.1f m, local %s" % [s, largo, str(casa.to_local(p).snapped(Vector3.ONE * 0.01))]
		s += 0.1
	return ""


## Pone a la paloma volando en "pos_local" (de la casa) con velocidad "vel" (local), frente a la
## ventana: cuando aparece el aviso, lo aprieta (como la tecla E) para que arranque la cinemática.
func _lanzar(casa: CasaEnterable, pos_local: Vector3, vel: Vector3, yaw: float, tecla: String) -> void:
	paloma.global_position = casa.to_global(pos_local)
	paloma.reset_physics_interpolation()
	paloma.camara.yaw = casa.rotation.y + yaw
	paloma.estado = PalomaJugador.Estado.SUELO
	paloma.despegar()
	paloma.velocity = casa.global_transform.basis * vel
	_terminada = false
	_hamaca_max = 0.0
	casa.escena_terminada.connect(_al_terminar, CONNECT_ONE_SHOT)
	Input.action_press(tecla)
	for i in 30:
		await get_tree().physics_frame
		if AvisoPasaje.visible_ahora():
			var e := InputEventAction.new()
			e.action = &"interactuar"
			e.pressed = true
			Input.parse_input_event(e)
			break


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
		# Cuánto se hamacó lo que cuelga (lo máximo en toda la pasada: al final ya casi se frenó)
		for piv in casa.colgantes:
			if not piv.has_meta(&"gira"):
				_hamaca_max = maxf(_hamaca_max, maxf(absf(piv.rotation.x), absf(piv.rotation.z)))
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
