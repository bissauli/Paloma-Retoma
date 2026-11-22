extends Node
## La bici y el macetón de la vereda de los edificios con locales quedan apoyados en el piso, con el mundo
## armado como en el juego: en otro hilo y fuera de la escena (ver Arranque), donde no hay física y
## Pasaje.apoyar_en_vereda mide a mano contra las formas de colisión. Acá, ya en la escena, se comprueba
## con un rayo de verdad que cada uno quedó sobre el piso.
## godot --headless --path . res://tests/test_apoyar_vereda.tscn

var fallas := 0


func _ready() -> void:
	GameState.guardado_habilitado = false
	var escena := load("res://main.tscn") as PackedScene
	var hilo := Thread.new()
	hilo.start(_armar.bind(escena))
	while hilo.is_alive():
		await get_tree().process_frame
	var juego: Node = hilo.wait_to_finish()
	var plaza := juego.get_node("Plaza") as Node3D
	var apoyados: Array = plaza.get_meta(&"apoyados", [])
	add_child(juego)
	for i in 5:
		await get_tree().physics_frame
	_check("hay bicis y macetones apoyados (%d)" % apoyados.size(), apoyados.size() >= 3)
	var esp := plaza.get_world_3d().direct_space_state
	var peor := 0.0
	var malos := 0
	for g: Vector3 in apoyados:
		var q := PhysicsRayQueryParameters3D.create(g + Vector3(0, 0.6, 0), g + Vector3(0, -0.6, 0), Construir.CAPA_MUNDO)
		var r := esp.intersect_ray(q)
		var d := INF if r.is_empty() else absf((r["position"] as Vector3).y - g.y)
		peor = maxf(peor, d)
		if d > 0.02:
			malos += 1
			print("  mal apoyado en ", g.snapped(Vector3.ONE * 0.01), ": ", d)
	var sin_piso: Array = plaza.get_meta(&"sin_piso", [])
	for g: Vector3 in sin_piso:
		var q := PhysicsRayQueryParameters3D.create(g + Vector3(0, 0.6, 0), g + Vector3(0, -0.6, 0), Construir.CAPA_MUNDO)
		var r := esp.intersect_ray(q)
		print("  sin piso cerca en ", g.snapped(Vector3.ONE * 0.01), ": la física ve ", "nada" if r.is_empty() else str((r["position"] as Vector3).y - g.y), " ", "" if r.is_empty() else str(r["collider"]))
	_check("ninguno se quedó sin piso debajo", sin_piso.is_empty())
	_check("todos sobre el piso que mide la física (peor %.3f m)" % peor, malos == 0)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(0 if fallas == 0 else 1)


func _armar(escena: PackedScene) -> Node:
	var juego := escena.instantiate()
	(juego.get_node("Plaza") as Node).call(&"construir")
	return juego


func _check(texto: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALLA ") + texto)
	if not ok:
		fallas += 1
