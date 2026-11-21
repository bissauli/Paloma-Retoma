extends Node
## Prueba del nivel inferior del mapa (Fase 1), headless:
## godot --headless --path . res://tests/test_nivel_inferior.tscn
## La paloma camina de verdad (con la tecla de avanzar, sin volar) desde la vereda hasta cada pasaje
## y por la escalera del subte hasta el descanso de abajo (y vuelve a subir). Además: que se pueda
## posar en los toldos de los pasajes y en los puestos del mercado y que haya mobiliario en las veredas.

var paloma: PalomaJugador
var fallas := 0


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(20)
	var espacio := paloma.get_world_3d().direct_space_state

	# ---- Pasajes: de la vereda de los cafés (a 16 cm) al Pasaje Las Palomas, por debajo del toldo
	for p: Array in NivelInferior.PASAJES:
		var xc := (float(p[0]) + float(p[1])) / 2.0
		var r := await _caminar(Vector3(xc, NivelInferior.Y_VEREDA, 36.4),
			[Vector3(xc, 0, 43.0), Vector3(xc, 0, 50.5)])
		print("  pasaje x=%.1f: llegó=%s, altura en el medio %.2f, al final %.2f" % [xc, r["llego"], r["y_medio"], r["y"]])
		_check("pasaje x=%.1f: se llega caminando desde la vereda" % xc, r["llego"] and r["suelo"])
		_check("pasaje x=%.1f: se camina por el piso (no por encima de nada)" % xc,
			r["y_medio"] > 0.1 and r["y_medio"] < 0.4)
		var x_toldo := xc - (float(p[1]) - float(p[0])) / 4.0
		var y := _altura_abajo(espacio, Vector3(x_toldo, 12, 43))
		_check("pasaje x=%.1f: el toldo tiene colisión arriba (%.2f m)" % [xc, y],
			y > NivelInferior.ALERO - 0.1 and y < NivelInferior.CUMBRERA + 0.1)
		var posada := await _posar(Vector3(x_toldo, y + 0.6, 43))
		_check("pasaje x=%.1f: la paloma se posa en el toldo (%.2f m)" % [xc, posada], posada > NivelInferior.ALERO - 0.1)

	# ---- Escalera del subte: desde la vereda de Rivadavia, rodeando la reja, hasta abajo y de vuelta
	var hueco := Edificios.hueco_subte()
	var cx := hueco.get_center().x
	var z_borde := hueco.end.y
	var inicio := _lugar_libre(espacio, Vector3(36.0, NivelInferior.Y_VEREDA, -41.6))
	_check("hay un lugar libre en la vereda para arrancar", inicio != Vector3.INF)
	var r := await _caminar(inicio, [Vector3(inicio.x, 0, -39.0), Vector3(36.4, 0, z_borde + 1.2),
		Vector3(cx, 0, z_borde + 1.2), Vector3(cx, 0, z_borde - 2.5), Vector3(cx, 0, hueco.position.y + 0.6)], 50.0)
	print("  subte: llegó=%s, altura abajo %.2f" % [r["llego"], r["y"]])
	_check("subte: se baja caminando desde la vereda hasta el descanso", r["llego"] and r["suelo"])
	_check("subte: abajo está 2 m más bajo", r["y"] < -1.8 and r["y"] > -2.15)
	r = await _caminar(Vector3.INF, [Vector3(cx, 0, z_borde - 2.5), Vector3(cx, 0, z_borde + 1.0)])
	print("  subte (subida): llegó=%s, altura arriba %.2f" % [r["llego"], r["y"]])
	_check("subte: se vuelve a subir caminando", r["llego"] and r["suelo"] and absf(r["y"]) < 0.15)

	# ---- Mercado: toldos y mesas con colisión
	var con_toldo := 0
	var con_mesa := 0
	for pu: Array in NivelInferior.PUESTOS:
		var t := Transform3D(Basis.from_euler(Vector3(0, float(pu[1]), 0)), pu[0])
		if _altura_abajo(espacio, t * Vector3(0.6, 6, 0.05)) > 2.2:
			con_toldo += 1
		var c := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(t * Vector3(0.6, 1.6, 0.6), t * Vector3(0.6, 0.0, 0.6)))
		if not c.is_empty() and absf((c["position"] as Vector3).y - 0.9) < 0.05:
			con_mesa += 1
	_check("mercado: %d puestos con toldo para posarse" % con_toldo, con_toldo == NivelInferior.PUESTOS.size())
	_check("mercado: mesas para posarse (mesas: %d)" % con_mesa, con_mesa == NivelInferior.PUESTOS.size())
	var pu0: Array = NivelInferior.PUESTOS[1]
	var posada := await _posar((pu0[0] as Vector3) + Vector3(0.6, 3.0, 0.0))
	_check("mercado: la paloma se posa en un toldo (%.2f m)" % posada, posada > 2.2)

	# ---- Mobiliario de las veredas
	var ciudad := main.find_child("Ciudad", true, false) as Ciudad
	print("  mobiliario: ", ciudad.mobiliario)
	for pieza: String in ["banco_listones", "bebedero", "cesto", "farola"]:
		_check("hay %s en las veredas (>= 5)" % pieza, int(ciudad.mobiliario.get(pieza, 0)) >= 5)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Camina (sólo con la tecla de avanzar, apuntando la cámara a cada punto) desde "inicio" (INF = desde
## donde está) por los "puntos". Devuelve si llegó al último, si terminó en el suelo, su altura al
## final y la altura al pasar por el primer punto.
func _caminar(inicio: Vector3, puntos: Array, max_seg := 25.0) -> Dictionary:
	if inicio != Vector3.INF:
		_teletransportar(inicio + Vector3(0, 0.05, 0))
		await _frames(30)
	var res := {"llego": false, "suelo": false, "y": 0.0, "y_medio": NAN}
	var frames := 0
	var limite := roundi(max_seg * Engine.physics_ticks_per_second)
	# Que no la atrapen los granaderos (la escalera del subte queda cerca de la Casa Rosada)
	GameState.invulnerable = max_seg + 5.0
	var i := 0
	Input.action_press("mover_adelante")
	while i < puntos.size() and frames < limite:
		var obj: Vector3 = puntos[i]
		var d := Vector3(obj.x - paloma.global_position.x, 0, obj.z - paloma.global_position.z)
		if d.length() < 0.35:
			if i == 0:
				res["y_medio"] = paloma.global_position.y
			i += 1
			continue
		paloma.camara.yaw = atan2(-d.x, -d.z)
		await get_tree().physics_frame
		frames += 1
	Input.action_release("mover_adelante")
	await _frames(20)
	res["llego"] = i >= puntos.size()
	res["suelo"] = paloma.estado == PalomaJugador.Estado.SUELO
	res["y"] = paloma.global_position.y
	if not res["llego"]:
		print("    se quedó en ", paloma.global_position, " yendo al punto ", i)
	return res


## Suelta la paloma quieta en "pos" y devuelve la altura donde se posó (NAN si no se posó).
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


## Altura de la primera colisión hacia abajo desde "desde" (-INF si no hay).
func _altura_abajo(espacio: PhysicsDirectSpaceState3D, desde: Vector3) -> float:
	var c := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 20.0))
	return (c["position"] as Vector3).y if not c.is_empty() else -INF


## Un lugar sin nada encima cerca de "cerca" (corriéndose de a 40 cm a lo largo de X), o INF.
func _lugar_libre(espacio: PhysicsDirectSpaceState3D, cerca: Vector3) -> Vector3:
	var esfera := SphereShape3D.new()
	esfera.radius = 0.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = esfera
	for k in 12:
		var p := cerca + Vector3(int(k / 2.0) * 0.4 * (1.0 if k % 2 == 0 else -1.0), 0, 0)
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.75, 0))
		if espacio.intersect_shape(q, 1).is_empty():
			return p
	return Vector3.INF


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
