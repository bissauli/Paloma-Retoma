extends Node
## Diagnóstico y prueba (headless): corre la ciudad un rato y anota los humanos que se traban: hacen
## fuerza para caminar y casi no avanzan, van y vienen en el mismo lugar, o quedan metidos adentro de algo
## (sentados en un banco o una silla es normal). Falla si alguien queda trabado 10 s o más seguidos.
## godot --headless --path . res://tests/diag_humanos.tscn -- [minutos de juego] [x z de la paloma]

var _hist := {}   # id -> {"pos": [], "vel": [], "metido": int, "h": Humano}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 4.0
	Ajustes.ARCHIVO = "user://diag_humanos.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var paloma := main.get_node("Paloma") as Node3D
	if args.size() > 2:
		paloma.global_position = Vector3(float(args[1]), 0.3, float(args[2]))
	Engine.time_scale = 4.0
	var espacio := get_viewport().world_3d.direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.12
	cap.height = 1.0
	var t := 0.0
	var muestra := 0.0
	var problemas := {}
	while t < minutos * 60.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time() * Engine.time_scale
		t += dt
		muestra += dt
		if muestra < 0.5:
			continue
		muestra = 0.0
		for n in get_tree().get_nodes_in_group("humanos"):
			var h := n as Humano
			if h == null:
				continue
			var id := h.get_instance_id()
			if not _hist.has(id):
				_hist[id] = {"pos": [], "vel": [], "metido": 0, "h": h}
			var d: Dictionary = _hist[id]
			(d["pos"] as Array).append(h.global_position)
			(d["vel"] as Array).append(Enemigo.plano(h._vel).length())
			# ¿Metido adentro de algo? (un palito en el medio del cuerpo, contra el mundo)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cap
			q.transform = Transform3D(Basis.IDENTITY, h.global_position + Vector3.UP * 0.95)
			q.collision_mask = Construir.CAPA_MUNDO
			var choca := espacio.intersect_shape(q, 1)
			if not choca.is_empty():
				d["metido"] = int(d["metido"]) + 1
				if h.tipo in ["turista", "oficinista"] and not d.has("con"):
					var co: Node = choca[0]["collider"]
					var so := co as CollisionObject3D
					var forma := so.shape_owner_get_shape(so.shape_find_owner(int(choca[0]["shape"])), 0)
					var cs := so.shape_owner_get_owner(so.shape_find_owner(int(choca[0]["shape"]))) as Node3D
					d["con"] = "%s %s en %s (forma en %s, %s)" % [co.get_path(), forma, h.global_position.round(),
						cs.global_position.round() if cs else Vector3.ZERO, (forma as BoxShape3D).size if forma is BoxShape3D else ""]
			var pos: Array = d["pos"]
			if pos.size() >= 12:   # Las últimas 6 s
				var camino := 0.0
				for k in range(pos.size() - 12, pos.size() - 1):
					camino += Enemigo.plano(pos[k + 1] - pos[k]).length()
				var neto := Enemigo.plano(pos[pos.size() - 1] - pos[pos.size() - 12]).length()
				var vel := 0.0
				for k in range(pos.size() - 12, pos.size()):
					vel += float(d["vel"][k]) / 12.0
				var que := ""
				if camino > 2.0 and neto < 0.5:
					que = "va y viene"
				elif vel > 0.45 and camino < 0.5 and not h._comiendo and h._atendiendo == null:
					que = "empuja sin avanzar"
				if que == "empuja sin avanzar" and not d.has("trabado"):
					d["trabado"] = true
					print("  trabado ", h.tipo, " en ", h.global_position, " destino ", h.destino_final, " _destino ", h._destino,
						" vel ", h._vel, " sin esquive ", h._t_sin_esquive, " trabado ", h._t_trabado, " visita ", h.visita != null)
				d["seguidas"] = (int(d.get("seguidas", 0)) + 1) if que != "" else 0
				d["peor"] = maxi(int(d.get("peor", 0)), int(d["seguidas"]))
				if que != "":
					var clave := "%s|%s|%s" % [que, h.tipo, Vector3i((pos[pos.size() - 1] as Vector3).round())]
					problemas[clave] = int(problemas.get(clave, 0)) + 1
	Engine.time_scale = 1.0
	print("DIAG problemas (tipo|lugar: veces):")
	for k in problemas:
		print("  ", k, ": ", problemas[k])
	for id in _hist:
		var d: Dictionary = _hist[id]
		if int(d["metido"]) > 6 and is_instance_valid(d["h"]):
			var h: Humano = d["h"]
			if d.has("con"):
				print("    con ", d["con"])
			print("  metido ", h.tipo, " ", h.global_position.round(), " zona ", h.zona_centro.round(), " (", d["metido"], " muestras)",
				" visita " if h.visita else "")
	var peor := 0
	for id in _hist:
		peor = maxi(peor, int((_hist[id] as Dictionary).get("peor", 0)))
	# Cada muestra es medio segundo: 20 seguidas son 10 s trabado en el mismo lugar
	print("RESULTADO: ", "OK" if peor < 20 else "FALLA", " (lo más que alguien quedó trabado: %.1f s)" % (peor * 0.5))
	get_tree().quit(0 if peor < 20 else 1)
