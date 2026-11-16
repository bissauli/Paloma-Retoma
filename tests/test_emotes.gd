extends Node
## Prueba automática de la rueda de bailes (corre headless):
## godot --headless --path . res://tests/test_emotes.tscn
## V abre la rueda (sólo en el piso) y deja a la paloma sin control; elegir un casillero cierra, y la
## paloma baila (los huesos se mueven); moverse corta el baile y vuelve a la animación normal.

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_emotes.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	var j: PalomaJugador = main.get_node("Paloma")
	j.global_position += Vector3(0, 0.5, 0)
	await _frames(90)
	_check("hay un casillero por cada baile de los créditos", Emotes._bailes.size() == Coreografia.ORDEN.size() + 1)
	_check("todos los bailes tienen nombre traducible", Emotes._bailes.all(func(b: StringName) -> bool:
		return Coreografia.NOMBRES.has(b)))
	# Los casilleros se reparten en círculo desde arriba, hacia la derecha: la cuenta depende de cuántos bailes hay
	var n := float(Emotes._bailes.size())
	var a_la_derecha := int((90.0 + 180.0 / n) / (360.0 / n))
	var abajo := int((180.0 + 180.0 / n) / (360.0 / n))
	_check("el casillero 0 está arriba y el de la derecha le sigue", Emotes._casillero(Vector2(0, -200)) == 0
		and Emotes._casillero(Vector2(200, 0)) == a_la_derecha and Emotes._casillero(Vector2(0, 200)) == abajo
		and Emotes._casillero(Vector2(5, 5)) == -1)

	_tecla("emotes", true)
	await _frames(3)
	_check("V abre la rueda", Emotes.abierta and Emotes._raiz.visible)
	_check("con la rueda abierta la paloma no se controla", not j.controlable)
	_tecla("emotes", false)
	await _frames(3)
	_check("soltar V enseguida no cierra (se abrió con un toque)", Emotes.abierta)
	await _frames(60)
	if DisplayServer.get_name() != "headless":
		_check("se sacan las miniaturas de todos los bailes", Emotes._miniaturas.size() == Emotes._bailes.size()
			and Emotes._miniaturas[0] != null and Emotes._miniaturas[0].get_width() == Emotes.LADO_MINIATURA)
	_tecla("emotes", true)
	await _frames(3)
	_check("V de nuevo la cierra y vuelve el control", not Emotes.abierta and j.controlable)
	_tecla("emotes", false)

	# Abrir y elegir con Enter el casillero marcado
	Emotes.abrir()
	Emotes._marcado = 1
	_tecla("ui_accept", true)
	await _frames(8)
	_tecla("ui_accept", false)
	_check("elegir cierra la rueda", not Emotes.abierta)
	_check("la paloma baila el baile elegido", j.modelo.bailando() and j.modelo._baile == &"moonwalk")
	var antes := j.modelo._skel.get_bone_pose_rotation(j.modelo._skel.find_bone("head"))
	await _frames(20)
	var despues := j.modelo._skel.get_bone_pose_rotation(j.modelo._skel.find_bone("head"))
	_check("los huesos se mueven con el baile", not antes.is_equal_approx(despues) or j.modelo._t_baile > 0.2)
	_check("sigue en el piso y bailando", j.estado == PalomaJugador.Estado.SUELO and j.modelo.bailando())

	# Moverse corta el baile
	Input.action_press("mover_adelante")
	await _frames(6)
	Input.action_release("mover_adelante")
	_check("moverse corta el baile", not j.modelo.bailando())
	_check("la animación del modelo vuelve", j.modelo._anim.active and j.modelo._glb.position == Vector3.ZERO)

	# En el aire no se abre
	j.estado = PalomaJugador.Estado.AIRE
	_check("volando no se abre la rueda", not Emotes.puede_abrir())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _tecla(accion: String, apretada: bool) -> void:
	var e := InputEventAction.new()
	e.action = accion
	e.pressed = apretada
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
