extends Node
## Prueba del mapa V4.5, headless: godot --headless --path . res://tests/test_mapa_v45.tscn
## - Cornisas y tapas del pretil de los edificios del kit con colisión (la paloma no las atraviesa).
## - El Cabildo de Blender (con el fondo cerrado) y su colisión.
## - Sin balcones dobles, bicis atadas a un bicicletero, árboles achicados donde no entraban.
## - Cables: las bajadas a las fachadas terminan en un soporte y no pasan por adentro de nada.
## - El barrio nuevo (casas, techos), la guarida de los BadJokes, sus puntos de aparición y la banda.
## - El horizonte con paralaje.

var paloma: PalomaJugador
var fallas := 0


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(20)
	var espacio := paloma.get_world_3d().direct_space_state
	var ci := main.find_child("Ciudad", true, false) as Ciudad

	# ---- #1 Cornisas y tapas del pretil
	var edificios := NivelMedio.edificios_kit(ci)
	var tapas_ok := 0
	var tapas := 0
	var cornisas_ok := 0
	var cornisas := 0
	var cornisa_posar := Vector3.INF
	for e: Array in edificios:
		var mi: MeshInstance3D = e[0]
		var d: Dictionary = e[2]
		if d.get("tipo", "") != "medio":
			continue
		var alto := float(d["alto"])
		var t := mi.transform
		# Tapa del pretil del costado (la del frente a veces es balaustrada): arriba a alto + 1,32 m
		var costado := t * Vector3(float(d["ancho"]) / 2.0 - 0.125, alto + 3.0, -8.0)
		var y := _altura_abajo(espacio, costado, 4.0)
		tapas += 1
		if absf(y - (alto + ColisionAuto.PRETIL + ColisionAuto.TAPA)) < 0.08:
			tapas_ok += 1
		elif tapas - tapas_ok <= 3:
			print("    tapa sin colisión en %s: %.2f (esperado %.2f)" % [e[1], y, alto + 1.32])
		# Cornisa del frente (los clásicos): a 45 cm de la fachada tiene que haber algo arriba del alto
		if String(e[1]).begins_with("clas_"):
			var p := t * Vector3(0.0, alto + 2.0, 0.45)
			var yc := _altura_abajo(espacio, p, 3.0)
			cornisas += 1
			if yc > alto - 0.1:
				cornisas_ok += 1
				if cornisa_posar == Vector3.INF:
					cornisa_posar = Vector3(p.x, yc, p.z)
			else:
				print("    cornisa sin colisión en %s (%.2f)" % [e[1], yc])
	_check("tapas del pretil con colisión arriba (%d de %d)" % [tapas_ok, tapas], tapas > 20 and tapas_ok == tapas)
	_check("cornisas de los clásicos con colisión (%d de %d)" % [cornisas_ok, cornisas], cornisas > 3 and cornisas_ok == cornisas)
	_check("convexos extra de los edificios (%d piezas)" % KitColisionesExtra.PIEZAS.size(), KitColisionesExtra.PIEZAS.size() >= 30)

	# ---- #2 Cabildo
	var cabildo := main.find_child("CabildoModelo", true, false) as MeshInstance3D
	_check("el Cabildo es el modelo de Blender", cabildo != null and cabildo.mesh != null and cabildo.mesh.get_surface_count() >= 5)
	var atras := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-62, 5, 6), Vector3(-50, 5, 6)))
	_check("el fondo del Cabildo es sólido", not atras.is_empty() and absf((atras["position"] as Vector3).x + 59.0) < 0.2)
	_check("cornisa del Cabildo a 9,3 m", absf(_altura_abajo(espacio, Vector3(-51, 12, 15.3)) - 9.3) < 0.05)

	# ---- #4 Sin balcones dobles: ningún balcón del nivel medio cae sobre una losa del kit
	var dobles := 0
	for m: Array in NivelMedio.muestras:
		if m[0] != "balcon":
			continue
		var p: Vector3 = m[1]
		for e: Array in edificios:
			var q := (e[0] as MeshInstance3D).transform.affine_inverse() * p
			if absf(q.z - 0.8) > 0.05 or absf(q.x) > float((e[2] as Dictionary)["ancho"]) / 2.0:
				continue
			if NivelMedio._hay_losa(NivelMedio._losas_kit(e[2]), q.x, q.y, 0.6):
				dobles += 1
	_check("ningún balcón doble (%d)" % dobles, dobles == 0)

	# ---- #3 Cables
	var bajadas := int(NivelMedio.cuenta.get("bajada", 0))
	_check("bajadas de cable a las fachadas con soporte (%d >= 6)" % bajadas, bajadas >= 6)

	# ---- #5 Bicis y árboles
	var bicis := 0
	var atadas := 0
	var esfera := SphereShape3D.new()
	esfera.radius = 0.5
	for c: Array in ci.colocadas:
		if not String(c[0]).begins_with("bici_"):
			continue
		bicis += 1
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = esfera
		q.transform = Transform3D(Basis.IDENTITY, (c[1] as Vector3) + Vector3(0, 0.5, 0))
		if not espacio.intersect_shape(q, 4).is_empty():
			atadas += 1
	_check("cada bici está atada a un bicicletero (%d de %d)" % [atadas, bicis], bicis > 0 and atadas == bicis)
	_check("árboles achicados para no meterse en los locales (%d)" % ci.arboles_achicados, ci.arboles_achicados > 0)

	# ---- #7 Barrio
	var n := Barrio.cuenta
	print("  barrio: ", n)
	_check("casas del barrio (%d >= 30)" % n.get("casa", 0), n.get("casa", 0) >= 30)
	_check("techos de chapa y de losa", n.get("chapa", 0) >= 5 and n.get("losa", 0) >= 10)
	var piezas_viejas := 0
	for c: Array in ci.colocadas:
		if String(c[0]).begins_with("barrio_"):
			piezas_viejas += 1
	_check("ya no se usan las piezas barrio_* (%d)" % piezas_viejas, piezas_viejas == 0)

	# ---- #8 Guarida y banda
	_check("la guarida de los BadJokes", n.get("guarida", 0) == 1)
	var spawns := get_tree().get_nodes_in_group("spawn_badjokes")
	var roles := {}
	for s: Node in spawns:
		roles[String(s.get_meta("rol", ""))] = int(roles.get(String(s.get_meta("rol", "")), 0)) + 1
	print("  puntos de aparición: ", roles)
	_check("puntos de aparición con los cuatro roles", roles.get("jefe", 0) == 1 and roles.get("guardia", 0) >= 2
		and roles.get("vigia", 0) >= 2 and roles.get("patrulla", 0) >= 3)
	_check("zona de la base y punto para la brújula", get_tree().get_nodes_in_group("base_badjokes").size() == 1
		and get_tree().get_nodes_in_group("punto_badjokes").size() == 1)
	var banda := get_tree().get_nodes_in_group("banda_badjokes")
	_check("una paloma de la banda en cada punto (%d de %d)" % [banda.size(), spawns.size()], banda.size() == spawns.size())
	var paradas := 0
	for b: Node in banda:
		var p := (b as Node3D).global_position
		var y := _altura_abajo(espacio, p + Vector3(0, 0.4, 0), 1.2)
		if absf(y - p.y) < 0.2:
			paradas += 1
		else:
			print("    %s (%s) flota o está enterrada: %.2f vs %.2f" % [b.get_meta("nombre"), b.get_meta("rol"), y, p.y])
	_check("la banda está parada sobre algo (%d de %d)" % [paradas, banda.size()], paradas == banda.size())

	# ---- #6 Horizonte con paralaje
	var horizonte := main.find_child("Horizonte", true, false) as Horizonte
	_check("hay horizonte con 4 capas", horizonte != null and horizonte._capas.size() == 4)
	if horizonte:
		_teletransportar(Vector3(150, 30, -40))
		await _frames(4)
		await get_tree().process_frame
		var cam := get_viewport().get_camera_3d().global_position
		var ok := true
		for k in 4:
			var esperado := Vector2(cam.x, cam.z) * float(Horizonte.CAPAS[k]["sigue"])
			var pos := Vector2(horizonte._capas[k].position.x, horizonte._capas[k].position.z)
			ok = ok and pos.distance_to(esperado) < 1.0
		_check("cada capa sigue a la cámara en su proporción (paralaje)", ok)

	# ---- La paloma se posa en una cornisa, en una azotea del barrio y en el techo de la guarida
	if cornisa_posar != Vector3.INF:
		var y := await _posar(cornisa_posar + Vector3(0, 0.45, 0))
		_check("la paloma se posa en la cornisa (%.2f, esperado %.2f)" % [y, cornisa_posar.y],
			not is_nan(y) and absf(y - cornisa_posar.y) < 0.15)
	if not Barrio.azoteas.is_empty():
		var p: Vector3 = Barrio.azoteas[0]
		var y := await _posar(p + Vector3(0, 0.5, 0))
		_check("la paloma se posa en una azotea del barrio (%.2f, esperado %.2f)" % [y, p.y], not is_nan(y) and absf(y - p.y) < 0.2)
	var cumbrera := Vector3(Barrio.GUARIDA.x + 6.0, Barrio.GALPON.y + Barrio.CUMBRERA, Barrio.GUARIDA.z)
	var yc := await _posar(cumbrera + Vector3(0, 0.6, 0))
	_check("la paloma se posa en el techo de la guarida (%.2f)" % yc, not is_nan(yc) and yc > Barrio.GALPON.y)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _posar(pos: Vector3) -> float:
	GameState.invulnerable = 10.0
	_teletransportar(pos)
	for k in 240:
		await get_tree().physics_frame
		if k > 20 and paloma.estado == PalomaJugador.Estado.SUELO and paloma.is_on_floor():
			await _frames(10)
			return paloma.global_position.y
	return NAN


func _teletransportar(pos: Vector3) -> void:
	paloma.global_position = pos
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	paloma.camara.reubicar()


func _altura_abajo(espacio: PhysicsDirectSpaceState3D, desde: Vector3, largo := 20.0) -> float:
	var c := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * largo))
	return (c["position"] as Vector3).y if not c.is_empty() else -INF


func _frames(k: int) -> void:
	for i in k:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
