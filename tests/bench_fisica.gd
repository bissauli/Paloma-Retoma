extends Node
## ¿Quién gasta el tiempo de física? Mide el tiempo de _physics_process (Performance.TIME_PHYSICS_PROCESS)
## y de la física 3D, y repite apagando de a un grupo de nodos del mundo (process_mode DISABLED) para ver cuánto aporta.
##   godot --path . --disable-vsync res://tests/bench_fisica.tscn -- [calidad=N]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("calidad="):
			Ajustes.calidad = int(a.get_slice("=", 1))
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 120:
		await get_tree().process_frame
	print("FISICA nodos ", get_tree().get_node_count(), " objetos 3D activos ", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var base := await _medir()
	print("FISICA base: mediana %.2f ms" % base)
	var nombres := ["Bandada", "Gente", "Transito", "Comida", "Paloma", "Fuentes", "Cielo", "HUD", "Edificios", "Ciudad"]
	var candidatos: Array[Node] = []
	for nom in nombres:
		var n := main.find_child(nom, true, false)
		if n:
			candidatos.append(n)
	for n in candidatos:
		var antes := n.process_mode
		n.process_mode = Node.PROCESS_MODE_DISABLED
		var r := await _medir()
		n.process_mode = antes
		print("FISICA sin %-12s mediana %.2f ms  (%+.2f)" % [n.name, r, r - base])
	print("FISICA base otra vez: %.2f ms" % await _medir())
	get_tree().quit()


func _medir() -> float:
	for i in 30:
		await get_tree().physics_frame
	var v: Array[float] = []
	for i in 200:
		await get_tree().physics_frame
		v.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	v.sort()
	return v[v.size() / 2]
