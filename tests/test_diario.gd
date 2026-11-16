extends Node
## Prueba automática del diario de misiones de la pausa (corre headless):
## godot --headless --path . res://tests/test_diario.tscn
## Sin misiones muestra el aviso; con una activa muestra su avance; lista y completada cambian lo que
## se ve; el botón MISIONES de la pausa lo abre y VOLVER devuelve la pausa.

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_diario.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	GameState.tutorial_hecho = true
	Misiones.desde_dict({})
	var pausa := main.get_node("Pausa")
	var diario: DiarioMisiones = pausa._diario

	diario.refrescar()
	await _frames(2)
	_check("sin misiones muestra el aviso", _textos(diario).any(func(t: String) -> bool: return t.contains("No tenés misiones")))

	Misiones.aceptar("migas_rosa")
	Misiones.notificar("miga", 3)
	diario.refrescar()
	await _frames(2)
	var t := _textos(diario)
	_check("la misión activa aparece con su título", t.has("MIGAS PARA DOÑA ROSA"))
	_check("muestra el avance 3 / 5", t.has("3 / 5"))
	_check("muestra la recompensa", t.any(func(x: String) -> bool: return x.contains("Recompensa")))

	Misiones.notificar("miga", 2)
	diario.refrescar()
	await _frames(2)
	t = _textos(diario)
	_check("lista: dice a quién volver", t.any(func(x: String) -> bool: return x.contains("Volvé con")))

	Misiones.entregar("migas_rosa")
	diario.refrescar()
	await _frames(2)
	t = _textos(diario)
	_check("completada: pasa a la sección de completadas", t.any(func(x: String) -> bool: return x.begins_with("✔ MIGAS"))
		and not t.has("3 / 5") and Misiones.completadas() == ["migas_rosa"])

	# Desde la pausa
	pausa.pausar()
	await _frames(2)
	pausa._diario.refrescar()
	pausa.get_node("%Misiones").emit_signal("pressed")
	await _frames(3)
	_check("MISIONES abre el diario y esconde los botones de la pausa", diario.visible and not pausa.get_node("Centro").visible)
	diario.volver.emit_signal("pressed")
	await _frames(3)
	_check("VOLVER devuelve la pausa", not diario.visible and pausa.get_node("Centro").visible)
	pausa.continuar()
	Misiones.desde_dict({})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _textos(n: Node) -> Array[String]:
	var r: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		r.append((l as Label).text)
	return r


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
