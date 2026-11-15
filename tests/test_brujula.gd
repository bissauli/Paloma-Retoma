extends Node
## Prueba automática de la brújula (headless):
## godot --headless --path . res://tests/test_brujula.tscn
## 1) La geometría: 0 = norte (-Z), los ángulos crecen hacia el este (+X).
## 2) Los destinos que GameState le manda a la brújula según el objetivo.
## 3) Que los grupos a los que apuntan existan en el mundo.

var fallas := 0


func _ready() -> void:
	var b := Brujula.new()
	add_child(b)
	b._pos = Vector3.ZERO
	b._rumbo = 0.0
	_check("el norte (-Z) queda enfrente", is_zero_approx(b._relativo(Vector3(0, 0, -10))))
	_check("el este (+X) queda a la derecha (90°)", is_equal_approx(b._relativo(Vector3(10, 0, 0)), PI / 2.0))
	_check("el oeste (-X) queda a la izquierda", is_equal_approx(b._relativo(Vector3(-10, 0, 0)), -PI / 2.0))
	_check("el sur queda atrás", is_equal_approx(absf(b._relativo(Vector3(0, 0, 10))), PI))
	b._rumbo = PI / 2.0
	_check("mirando al este, el este queda enfrente", is_zero_approx(b._relativo(Vector3(10, 0, 0))))
	b._pos = Vector3(5, 3, 5)
	_check("la distancia ignora la altura", is_equal_approx(b._distancia(Vector3(5, 40, 15)), 10.0))

	# Objetivos -> destinos (con el mundo cargado)
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("al empezar apunta a Doña Rosa", _principales() == ["dona_rosa"])
	GameState.tutorial_hecho = true
	GameState.bandada = 0
	GameState.comida = 0
	GameState.actualizar_objetivo()
	_check("sin comida apunta a los cafés y al subte", _principales() == ["punto_cafes", "punto_subte"])
	GameState.comida = 3
	GameState.actualizar_objetivo()
	_check("con comida apunta a la Catedral", _principales() == ["punto_catedral"])
	GameState.bandada = 6
	GameState.actualizar_objetivo()
	_check("con 6 palomas apunta al choripán", _principales() == ["punto_choripan"])
	GameState.bandada = 20
	GameState.actualizar_objetivo()
	_check("con 20 palomas vuelve a la Catedral", _principales() == ["punto_catedral"])
	GameState.bandada = 30
	GameState.actualizar_objetivo()
	_check("con 30 palomas apunta al balcón", _principales() == ["balcon"])
	_check("el nido siempre queda marcado, más chico", _todos().has("nido") and not _principales().has("nido"))
	GameState.set_carga("medialuna")
	_check("con comida en el pico apunta al nido", _principales() == ["nido"])
	GameState.set_carga("")

	# Todos los grupos existen en el mundo
	var faltan: Array[String] = []
	for grupo in ["dona_rosa", "punto_cafes", "punto_subte", "punto_catedral", "punto_choripan", "balcon", "nido"]:
		if get_tree().get_first_node_in_group(grupo) == null:
			faltan.append(grupo)
	_check("los destinos existen en el mundo %s" % [faltan], faltan.is_empty())

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _principales() -> Array:
	return GameState.destinos.filter(func(d: Dictionary) -> bool: return d["principal"]).map(
		func(d: Dictionary) -> String: return d["grupo"])


func _todos() -> Array:
	return GameState.destinos.map(func(d: Dictionary) -> String: return d["grupo"])


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
