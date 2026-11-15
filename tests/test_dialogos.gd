extends Node
## Prueba automática de las conversaciones con NPC y las misiones secundarias (corre headless):
## godot --headless --path . res://tests/test_dialogos.tscn
## 1) Los catálogos son coherentes (nodos, misiones, condiciones y traducciones existen).
## 2) Misiones: aceptar, avance por eventos, entregar con recompensa, guardar y volver.
## 3) En la plaza: sólo el NPC marcado (Doña Rosa) se puede hablar, E inicia la conversación, la
##    paloma queda quieta, las opciones aceptan la misión y al terminar vuelve el control.

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_dialogos.cfg"
	GameState.guardado_habilitado = false
	_catalogos()
	_misiones()
	await _en_la_plaza()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _catalogos() -> void:
	var rotos: Array[String] = []
	for id: String in CatalogoDialogos.PERSONAJES:
		for e: Dictionary in CatalogoDialogos.personaje(id).get("dialogos", []):
			if CatalogoDialogos.dialogo(String(e["dialogo"])).is_empty():
				rotos.append("%s -> diálogo %s" % [id, e["dialogo"]])
	for did: String in CatalogoDialogos.DIALOGOS:
		var d := CatalogoDialogos.dialogo(did)
		var nodos: Dictionary = d["nodos"]
		if not nodos.has(d["inicio"]):
			rotos.append("%s sin nodo de inicio" % did)
		for nid: String in nodos:
			var n: Dictionary = nodos[nid]
			var destinos: Array = [n.get("va", "")]
			_texto_traducido(n.get("texto", ""), rotos)
			for o: Dictionary in n.get("opciones", []):
				destinos.append(o.get("va", ""))
				_texto_traducido(o.get("texto", ""), rotos)
			for v: String in destinos:
				if v != "" and not nodos.has(v):
					rotos.append("%s/%s va a '%s' que no existe" % [did, nid, v])
	for mid: String in CatalogoMisiones.MISIONES:
		var m := CatalogoMisiones.mision(mid)
		for k: String in ["dador", "entrega"]:
			if m.has(k) and not CatalogoDialogos.PERSONAJES.has(m[k]):
				rotos.append("misión %s: %s '%s' no es un personaje" % [mid, k, m[k]])
		_texto_traducido(m.get("titulo", ""), rotos)
		_texto_traducido(m.get("resumen", ""), rotos)
		for o: Dictionary in m.get("objetivos", []):
			_texto_traducido(o.get("texto", ""), rotos)
	_check("los catálogos son coherentes: " + ", ".join(rotos), rotos.is_empty())


func _texto_traducido(t: String, rotos: Array[String]) -> void:
	if t != "" and not TextosEN.MAPA.has(t):
		rotos.append("sin traducción: " + t.left(40))


func _misiones() -> void:
	GameState.reiniciar()
	GameState.tutorial_hecho = false
	_check("sin tutorial la misión de Doña Rosa no está disponible", not Misiones.disponible("migas_rosa"))
	GameState.tutorial_hecho = true
	_check("con el tutorial hecho está disponible y Rosa muestra '!'", Misiones.disponible("migas_rosa")
		and Misiones.marcador("dona_rosa") == "!")
	_check("aceptarla la deja activa (y no se acepta dos veces)", Misiones.aceptar("migas_rosa")
		and Misiones.estado("migas_rosa") == "activa" and not Misiones.aceptar("migas_rosa"))
	_check("la brújula marca el destino de la misión", GameState.destinos.any(func(d: Dictionary) -> bool:
		return d["grupo"] == &"dona_rosa" and d["nombre"] == "Migas para Doña Rosa"))
	Misiones.notificar("miga", 3)
	_check("el avance se cuenta (3 de 5)", Misiones.objetivos("migas_rosa")[0]["actual"] == 3
		and Misiones.estado("migas_rosa") == "activa")
	var guardado := Misiones.a_dict()
	Misiones.desde_dict({})
	_check("sin datos no hay misiones", Misiones.estado("migas_rosa") == "nueva")
	Misiones.desde_dict(guardado)
	_check("el guardado vuelve con el avance", Misiones.estado("migas_rosa") == "activa"
		and Misiones.objetivos("migas_rosa")[0]["actual"] == 3)
	GameState.comio_miga()
	GameState.comio_miga()
	_check("comer migas de verdad avanza la misión y la deja lista", Misiones.estado("migas_rosa") == "lista"
		and Misiones.marcador("dona_rosa") == "?")
	_check("lista apunta a quien la dio", GameState.destinos.any(func(d: Dictionary) -> bool:
		return d["grupo"] == &"npc_dona_rosa"))
	var comida := GameState.comida
	_check("entregarla cobra la recompensa", Misiones.entregar("migas_rosa")
		and Misiones.estado("migas_rosa") == "completada" and GameState.comida == comida + 2
		and Misiones.marcador("dona_rosa") == "")
	_check("no se cobra dos veces", not Misiones.entregar("migas_rosa") and GameState.comida == comida + 2)
	_check("las reglas: comparaciones y negación", ReglasDialogo.cumple(["comida>=1", "!bandera:x", "bandada<=99"]))
	Misiones.desde_dict({})


func _en_la_plaza() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	GameState.tutorial_hecho = true
	var j: PalomaJugador = main.get_node("Paloma")
	var rosa := get_tree().get_first_node_in_group("dona_rosa") as Node3D
	var interlocutor := rosa.get_node_or_null("Interlocutor") as Interlocutor
	_check("Doña Rosa está marcada para hablar", interlocutor != null and interlocutor.is_in_group("hablables"))
	_check("los demás humanos no se pueden hablar", get_tree().get_nodes_in_group("hablables").size() == 1)

	# Lejos: no hay a quién hablarle
	j.global_position = rosa.global_position + Vector3(30, 0.5, 0)
	await _frames(40)
	_check("lejos no hay interlocutor cercano", Dialogos.cercano == null)
	# Cerca y en el piso
	j.global_position = rosa.global_position + Vector3(1.4, 0.5, 0)
	j.velocity = Vector3.ZERO
	await _frames(120)
	_check("cerca se detecta a Doña Rosa", Dialogos.cercano == interlocutor)
	var e := InputEventAction.new()
	e.action = "interactuar"
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	_check("E inicia la conversación y la paloma queda sin control", Dialogos.activo and not j.controlable)
	_check("la caja de diálogo se ve", Dialogos._ui._caja.visible and Dialogos._ui._nombre.text == "DOÑA ROSA")
	# El saludo tiene dos opciones (la de la misión sí aparece porque el tutorial está hecho)
	_check("el saludo ofrece la misión", Dialogos._ui._opciones.get_child_count() == 2)
	Dialogos.elegir(0)
	Dialogos.elegir(0)   # "¡Dale!"
	_check("aceptar la misión la activa", Misiones.estado("migas_rosa") == "activa")
	Dialogos.avanzar()
	_check("al terminar vuelve el control", not Dialogos.activo and j.controlable)
	_check("el marcador de Rosa pasó a '...'", Misiones.marcador("dona_rosa") == "...")
	await _frames(40)
	_check("hablar de nuevo muestra el recordatorio", CatalogoDialogos.elegir("dona_rosa") == "rosa_recordatorio")
	# No se puede hablar en el aire
	j.estado = PalomaJugador.Estado.AIRE
	Dialogos._buscar_cercano()    # Sin esperar: en el piso aterrizaría enseguida
	_check("volando no se puede hablar", Dialogos.cercano == null)
	Misiones.desde_dict({})


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
