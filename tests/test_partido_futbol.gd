extends Node
## Prueba automática del partido de fútbol 5 contra 5 (corre headless):
## godot --headless --path . res://tests/test_partido_futbol.tscn
## Arma una bandada de 6, se para en la pelota, empieza el partido, lo deja jugar solo (IA), fuerza el
## final por tiempo (con empate: penales) y comprueba que todo se limpia.

var fallas := 0
var _main: Node
var _j: PalomaJugador
var _partido: PartidoFutbol
var _bandada: Bandada


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_futbol.cfg"
	GameState.guardado_habilitado = false
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _frames(15)
	_j = _main.get_node("Paloma")
	_bandada = _main.get_node("Bandada")
	_partido = get_tree().get_first_node_in_group("partido_futbol") as PartidoFutbol
	_check("el partido existe en la ciudad", _partido != null)
	if _partido == null:
		_terminar()
		return
	_check("empieza inactivo", _partido.estado == PartidoFutbol.Estado.INACTIVO)

	# Con menos de 4 en la bandada no se puede jugar
	_ir_a_la_pelota()
	await _frames(5)
	_partido.iniciar()
	_check("sin bandada no empieza", _partido.estado == PartidoFutbol.Estado.INACTIVO)

	# Bandada de 6: recluta sueltas
	var n := 0
	for p in _bandada.get_children():
		var npc := p as PalomaNPC
		if npc and npc.modo == PalomaNPC.Modo.SUELTA:
			npc.global_position = _j.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			npc.reclutar()
			_bandada.seguidoras.append(npc)
			n += 1
			if n >= 6:
				break
	_check("hay 6 seguidoras", _bandada.seguidoras.size() >= 6)
	_ir_a_la_pelota()
	await _frames(60)
	print("  libre=", _partido._jugadora_libre(), " estado_j=", _j.estado, " y=", _j.global_position.y, " segu=", _bandada.seguidoras.size(), " menu=", GameState.menu_activo)
	_partido.iniciar()
	_check("con 6 seguidoras empieza (saque)", _partido.estado == PartidoFutbol.Estado.SAQUE)
	_check("10 jugadoras en cancha (5 vs 5 menos la jugadora)", _partido._equipo.size() == 9)
	_check("hay hinchada", _partido._hinchas.size() == 2)

	# Pasa el saque y juegan solas un rato
	await _frames(400)
	_check("pasó el saque y se juega", _partido.estado == PartidoFutbol.Estado.JUGANDO or _partido.estado == PartidoFutbol.Estado.GOL)
	var b0 := _partido._balon.global_position
	var movio := false
	for i in 20:
		await _frames(30)
		if _partido._balon.global_position.distance_to(b0) > 3.0:
			movio = true
			break
	_check("la pelota se mueve sola (IA)", movio)
	_check("la pelota no se fue de la cancha", _partido._balon.global_position.y > PartidoFutbol.SUELO - 4.0)

	# La jugadora toca la pelota: correr, pase, tiro (F mantenido) sin romper nada
	Input.action_press("mover_adelante")
	Input.action_press("picada")
	await _frames(60)
	Input.action_release("mover_adelante")
	Input.action_release("picada")
	Input.action_press("aletazo")
	await _frames(30)
	Input.action_release("aletazo")
	Input.action_press("picotear")
	await _frames(5)
	Input.action_release("picotear")
	Input.action_press("descansar")
	await _frames(5)
	Input.action_release("descansar")
	_check("sigue en marcha tras usar los controles", _partido.estado != PartidoFutbol.Estado.INACTIVO)

	# Goles: fuerza una racha para ver el festejo, la repetición y que vuelve al saque
	_partido._gol(0)
	_check("gol suma", _partido.goles[0] == 1)
	await _frames(60 * 9)
	_check("tras el gol vuelve a jugarse", _partido.estado == PartidoFutbol.Estado.JUGANDO or _partido.estado == PartidoFutbol.Estado.SAQUE)

	# Fin por tiempo con empate: penales
	for i in 600:
		if _partido.estado == PartidoFutbol.Estado.JUGANDO:
			break
		await get_tree().physics_frame
	_partido.goles = [1, 1]
	_partido._tiempo = 0.01
	await _frames(10)
	_check("empate al final: tanda de penales", _partido.estado == PartidoFutbol.Estado.PENALES)
	for i in 60 * 40:
		if _partido.estado != PartidoFutbol.Estado.PENALES:
			break
		await get_tree().physics_frame
	_check("los penales terminan (o siguen sin errores)", _partido.estado == PartidoFutbol.Estado.FIN or _partido.estado == PartidoFutbol.Estado.PENALES)

	# Fin directo
	if _partido.estado != PartidoFutbol.Estado.FIN:
		_partido._fin()
	_check("estado FIN", _partido.estado == PartidoFutbol.Estado.FIN)
	await _frames(60 * 5)
	_check("se limpia y vuelve a inactivo", _partido.estado == PartidoFutbol.Estado.INACTIVO)
	_check("la jugadora recupera velocidad y Q", not _j.bloquea_descanso)
	for e in _partido._equipo:
		if is_instance_valid(e["p"]) and (e["p"] as PalomaNPC).controlada:
			_check("sin NPC controlada colgada", false)
			break
	_terminar()


func _ir_a_la_pelota() -> void:
	_j.estado = PalomaJugador.Estado.SUELO
	_j.global_position = _partido._balon.global_position + Vector3(-1.5, 0.1, 0)
	_j.velocity = Vector3.ZERO
	_j.reset_physics_interpolation()


func _terminar() -> void:
	for a in ["mover_adelante", "correr", "aletazo", "picotear", "descansar", "picada"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
