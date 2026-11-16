extends Node
## Prueba automática de los carteles de misión (corre headless):
## godot --headless --path . res://tests/test_avisos_mision.tscn
## Aceptar, avanzar, dejar lista y completar una misión muestra su cartel; el avance seguido se
## junta en un solo cartel que cuenta; se apagan solos; y no se muestran fuera de la partida.

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_avisos.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	GameState.tutorial_hecho = true
	Misiones.desde_dict({})
	var av: AvisoMision = Misiones._aviso
	_check("hay partida en curso", GameState.en_partida)

	Misiones.aceptar("migas_rosa")
	_check("aceptar muestra un cartel", av.cantidad() == 1 and _textos(av).has("MISIÓN ACEPTADA"))
	await get_tree().create_timer(0.6).timeout
	Misiones.notificar("miga")
	_check("el avance muestra '1 / 5' y reemplaza al anterior", av.cantidad() == 1 and _textos(av).any(func(t: String) -> bool: return t.contains("1 / 5")))
	Misiones.notificar("miga", 2)
	_check("el avance seguido sigue en un solo cartel ('3 / 5')", av.cantidad() == 1 and _textos(av).any(func(t: String) -> bool: return t.contains("3 / 5")))
	Misiones.notificar("miga", 2)
	_check("al quedar lista el cartel dice que hay que volver", av.cantidad() == 1 and _textos(av).has("MISIÓN LISTA")
		and _textos(av).any(func(t: String) -> bool: return t.begins_with("Volvé con")))
	Misiones.entregar("migas_rosa")
	_check("completar muestra la recompensa", _textos(av).has("MISIÓN COMPLETADA")
		and _textos(av).any(func(t: String) -> bool: return t.contains("+2 de comida")))
	await get_tree().create_timer(5.5).timeout
	_check("los carteles se apagan solos", av.cantidad() == 0)

	# Sin partida no se muestra nada
	GameState.en_partida = false
	Misiones.desde_dict({})
	Misiones.aceptar("migas_rosa")
	_check("fuera de la partida no hay carteles", av.cantidad() == 0)
	GameState.en_partida = true
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
