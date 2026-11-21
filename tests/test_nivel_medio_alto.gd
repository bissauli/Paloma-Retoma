extends Node
## Prueba de los niveles medio y alto del mapa (Fases 2 y 3), headless:
## godot --headless --path . res://tests/test_nivel_medio_alto.tscn
## Cuenta lo que se armó (balcones, macetas, toldos, cornisas, faroles, carteles, árboles altos, torres,
## cúpulas y tejados, terrazas, antenas, postes y cables), mira con rayos que cada cosa donde se posa
## tenga colisión arriba y suelta la paloma encima de un balcón, un toldo, una cornisa, un cable, la
## punta de una antena, la base de un farol y de un poste, una copa alta y cada mirador de las torres.

var paloma: PalomaJugador
var fallas := 0


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(20)
	var espacio := paloma.get_world_3d().direct_space_state
	var n := NivelMedio.cuenta
	print("  cuenta: ", n)
	print("  miradores: ", NivelAlto.miradores.size())

	# ---- Fase 2
	_check("balcones (%d >= 60)" % n.get("balcon", 0), n.get("balcon", 0) >= 60)
	_check("1 a 3 macetas por balcón (%d)" % n.get("maceta", 0),
		n.get("maceta", 0) >= n.get("balcon", 0) and n.get("maceta", 0) <= 3 * n.get("balcon", 0))
	_check("toldos (%d >= 40)" % n.get("toldo", 0), n.get("toldo", 0) >= 40)
	_check("cornisas (%d >= 20)" % n.get("cornisa", 0), n.get("cornisa", 0) >= 20)
	_check("columnas de farol (%d >= 8)" % n.get("columna_farol", 0), n.get("columna_farol", 0) >= 8)
	_check("carteles en las fachadas (%d >= 8)" % n.get("cartel", 0), n.get("cartel", 0) >= 8)
	_check("árboles altos (%d, 3 o 4)" % n.get("arbol_alto", 0), n.get("arbol_alto", 0) in [3, 4])
	for tipo: String in ["balcon", "toldo", "cornisa"]:
		var ok := 0
		var total := 0
		for m: Array in NivelMedio.muestras:
			if m[0] != tipo or total >= 30:
				continue
			total += 1
			var p: Vector3 = m[1]
			var y := _altura_abajo(espacio, p + Vector3(0, 0.3, 0), 1.0)
			if absf(y - p.y) < (0.3 if tipo == "toldo" else 0.08):
				ok += 1
			else:
				print("    sin colisión: %s en %s (%.2f)" % [tipo, p, y])
		_check("%s: colisión arriba (%d de %d)" % [tipo, ok, total], total > 0 and ok == total)
	for p: Vector3 in NivelMedio.FAROLES_PLAZA:
		# Al costado del fuste (que ahora también es sólido): el escalón de la base, donde se posa
		var y := _altura_abajo(espacio, p + Vector3(0.3, 3.0, 0))
		_check("farol en %s: base con colisión (%.2f m)" % [p, y], y > 0.85 and y < 1.0)
	for p: Vector3 in NivelMedio.ARBOLES_ALTOS:
		var y := _altura_abajo(espacio, p + Vector3(0, 14.0, 0))
		_check("árbol alto en %s: copa con colisión entre 6 y 10 m (%.2f)" % [p, y], y > 6.0 and y < 10.5)

	# ---- Fase 3
	_check("torres hito (%d)" % n.get("torre", 0), n.get("torre", 0) == NivelAlto.TORRES.size())
	_check("cúpulas y tejados (%d)" % (n.get("cupula", 0) + n.get("tejado", 0)),
		n.get("cupula", 0) + n.get("tejado", 0) == NivelAlto.TORRES.size())
	_check("terrazas con cosas (%d, 3 o 4)" % n.get("terraza", 0), n.get("terraza", 0) in [3, 4])
	for cosa: String in ["tanque", "pergola", "tendedero"]:
		_check("terrazas: %s (%d >= 3)" % [cosa, n.get(cosa, 0)], n.get(cosa, 0) >= 3)
	_check("antenas (%d >= 8)" % n.get("antena", 0), n.get("antena", 0) >= 8)
	_check("banderas apagadas (%d == 0)" % n.get("bandera", 0), n.get("bandera", 0) == (3 if NivelAlto.BANDERAS else 0))
	_check("postes (%d >= 15)" % n.get("poste", 0), n.get("poste", 0) >= 15)
	_check("cables (%d >= 20)" % n.get("cable", 0), n.get("cable", 0) >= 20)
	_check("miradores (%d, 4 o 5)" % NivelAlto.miradores.size(), NivelAlto.miradores.size() in [4, 5])
	var mas_alto := 0.0
	for tipo: String in ["antena", "pergola", "tanque", "poste", "cable"]:
		var ok := 0
		var total := 0
		for m: Array in NivelAlto.muestras:
			if m[0] != tipo:
				continue
			total += 1
			var p: Vector3 = m[1]
			mas_alto = maxf(mas_alto, p.y)
			var y := _altura_abajo(espacio, p + Vector3(0, 0.8, 0), 1.6)
			if absf(y - p.y) < 0.08:
				ok += 1
			elif total - ok <= 3:
				print("    sin colisión: %s en %s (%.2f)" % [tipo, p, y])
		_check("%s: colisión arriba (%d de %d)" % [tipo, ok, total], total > 0 and ok == total)
	_check("el techo invisible (%.0f m) está por encima de todo (%.1f m)" % [Ciudad.TECHO, mas_alto],
		mas_alto < Ciudad.TECHO - 1.0)
	for t: Dictionary in NivelAlto.TORRES:
		var tr := Transform3D(Basis.from_euler(Vector3(0, float(t["rot"]), 0)), t["esquina"])
		var y := _altura_abajo(espacio, tr * Vector3(13.0, Ciudad.TECHO - 0.5, -13.0), Ciudad.TECHO)
		_check("torre %s: entre 50 y 60 m (%.1f)" % [t["esquina"], y], y > 50.0 and y < 64.0)
	var paredes := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40, 30, -60), Vector3(-60, 30, -60)))
	_check("las paredes de la torre son sólidas", not paredes.is_empty())

	# ---- La paloma se posa
	var lugares := []
	for tipo: String in ["balcon", "toldo", "cornisa"]:
		for m: Array in NivelMedio.muestras:
			if m[0] == tipo:
				lugares.append([tipo, m[1]])
				break
	for tipo: String in ["cable", "antena", "pergola", "tanque", "poste"]:
		for m: Array in NivelAlto.muestras:
			if m[0] == tipo:
				lugares.append([tipo, m[1]])
				break
	lugares.append(["base de farol", NivelMedio.FAROLES_PLAZA[0] + Vector3(0, 0.9, 0)])
	var arbol: Vector3 = NivelMedio.ARBOLES_ALTOS[0]
	lugares.append(["copa alta", arbol + Vector3(0, _altura_abajo(espacio, arbol + Vector3(0, 14, 0)) - arbol.y, 0)])
	for i in NivelAlto.miradores.size():
		lugares.append(["mirador %d" % i, NivelAlto.miradores[i][0]])
	for l: Array in lugares:
		var p: Vector3 = l[1]
		var posada := await _posar(p + Vector3(0, 0.45, 0))
		_check("la paloma se posa en %s (%.2f m, esperado %.2f)" % [l[0], posada, p.y],
			not is_nan(posada) and absf(posada - p.y) < 0.6)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


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
func _altura_abajo(espacio: PhysicsDirectSpaceState3D, desde: Vector3, largo := 20.0) -> float:
	var c := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * largo))
	return (c["position"] as Vector3).y if not c.is_empty() else -INF


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
