extends Node
## Prueba automática de las acciones de la paloma (headless):
## godot --headless --path . res://tests/test_animacion_paloma.tscn
## Al arrullar o picotear caminando, las patas tienen que seguir caminando (antes se quedaban
## quietas porque el arrullo reemplazaba la animación de caminar entera).

var fallas := 0


func _ready() -> void:
	var m := ModeloPaloma.new()
	m.es_jugador = true
	add_child(m)
	await _cuadros(5)
	for accion in ["arrullar", "picotear"]:
		for i in 12:
			m.animar(0.016, 0, 2.5)        # Caminando
			await get_tree().physics_frame
		m.call(accion)
		_check("%s: empieza la acción" % accion, m._accion != "")
		var distintos := 0
		var anterior := _giro_pata(m)
		var cabeza_ini := m._skel.get_bone_pose_rotation(m._skel.find_bone("head"))
		var cabeza_se_mueve := false
		for i in 30:
			m.animar(0.016, 0, 2.5)
			await get_tree().physics_frame
			var ahora := _giro_pata(m)
			if not ahora.is_equal_approx(anterior):
				distintos += 1
			anterior = ahora
			if not m._skel.get_bone_pose_rotation(m._skel.find_bone("head")).is_equal_approx(cabeza_ini):
				cabeza_se_mueve = true
		_check("%s: las patas siguen caminando (cambian en %d de 30 cuadros)" % [accion, distintos], distintos >= 20)
		_check("%s: la cabeza hace el gesto" % accion, cabeza_se_mueve)
		await _cuadros(70)
		_check("%s: termina sola y la base sigue" % accion, m._accion == "")
	# Despegar corta la acción
	m.animar(0.016, 0, 0.0)
	m.arrullar()
	m.animar(0.016, 1, 0.0)
	_check("al despegar se corta la acción", m._accion == "")
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Giro de la pata izquierda (el esqueleto lo mueve la animación).
func _giro_pata(m: ModeloPaloma) -> Quaternion:
	return m._skel.get_bone_pose_rotation(m._skel.find_bone("leg_L"))


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
