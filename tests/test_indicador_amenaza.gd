extends Node
## Prueba automática del indicador de peligro del halcón (corre headless):
## godot --headless --path . res://tests/test_indicador_amenaza.tscn

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_amenaza.cfg"
	GameState.guardado_habilitado = false
	# Ángulos relativos a la cámara (cámara mirando a -Z)
	var b := Basis.IDENTITY
	_check("al frente = 0", is_equal_approx(IndicadorAmenaza.angulo_en_pantalla(b, Vector3(0, 5, -10)), 0.0))
	_check("a la derecha = PI/2", is_equal_approx(IndicadorAmenaza.angulo_en_pantalla(b, Vector3(10, 0, 0)), PI / 2.0))
	_check("a la izquierda = -PI/2", is_equal_approx(IndicadorAmenaza.angulo_en_pantalla(b, Vector3(-10, 0, 0)), -PI / 2.0))
	_check("atrás = PI", is_equal_approx(absf(IndicadorAmenaza.angulo_en_pantalla(b, Vector3(0, 0, 10))), PI))
	_check("justo arriba no revienta", IndicadorAmenaza.angulo_en_pantalla(b, Vector3(0, 20, 0)) == 0.0)
	# Con la cámara girada 90° a la izquierda, lo que estaba a la derecha del mundo (+X) queda al frente
	var giro := Basis(Vector3.UP, PI / 2.0)       # mira hacia -X
	_check("la rotación de la cámara se tiene en cuenta", is_equal_approx(IndicadorAmenaza.angulo_en_pantalla(giro, Vector3(-10, 0, 0)), 0.0))

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 15:
		await get_tree().physics_frame
	var ind := _buscar(main.get_node("HUD"))
	_check("el HUD tiene el indicador", ind != null)
	var halcon: Node = null
	for n in get_tree().get_nodes_in_group("amenazas"):
		halcon = n
	_check("el halcón está en el grupo de amenazas", halcon != null)
	if ind == null or halcon == null:
		_terminar()
		return
	_check("sin alerta no se ve", not ind.esta_visible() and halcon.nivel_amenaza() == 0.0)

	# El halcón en alerta, al este de la paloma: el arco aparece
	var j: PalomaJugador = main.get_node("Paloma")
	halcon.set_physics_process(false)      # Que no cambie solo de estado: el jugador no es blanco
	halcon.estado = Halcon.Estado.ALERTA
	halcon.global_position = j.global_position + Vector3(25, 20, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_check("en alerta se ve el aviso", ind.esta_visible())
	_check("nivel de alerta", is_equal_approx(halcon.nivel_amenaza(), 0.6))
	var cam := get_viewport().get_camera_3d()
	var esperado := IndicadorAmenaza.angulo_en_pantalla(cam.global_basis, halcon.global_position - j.global_position)
	_check("apunta hacia el halcón", is_equal_approx(ind.angulo_actual(), esperado))

	# Al otro lado, el arco gira
	halcon.global_position = j.global_position + Vector3(-25, 20, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	var esperado2 := IndicadorAmenaza.angulo_en_pantalla(cam.global_basis, halcon.global_position - j.global_position)
	_check("sigue al halcón cuando cambia de lado", is_equal_approx(ind.angulo_actual(), esperado2)
		and not is_equal_approx(esperado, esperado2))

	halcon.estado = Halcon.Estado.ATACANDO
	_check("atacando es el nivel máximo", is_equal_approx(halcon.nivel_amenaza(), 1.0))

	# Se va: se apaga
	halcon.estado = Halcon.Estado.CIRCULANDO
	await get_tree().create_timer(0.8).timeout
	_check("sin amenaza se apaga", not ind.esta_visible())
	_terminar()


func _buscar(n: Node) -> IndicadorAmenaza:
	for c in n.find_children("*", "Control", true, false):
		if c is IndicadorAmenaza:
			return c
	return null


func _terminar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
