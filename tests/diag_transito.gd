extends Node
## Diagnóstico del tránsito (headless): corre la ciudad acelerada y anota cada vez que dos vehículos se
## pisan (ruta, posición en la ruta, velocidad y espera de cada uno) y los que quedan parados mucho.
## Falla si alguno se encima. godot --headless --path . res://tests/diag_transito.tscn -- [minutos de juego]

var _vistos := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 15.0
	Ajustes.ARCHIVO = "user://diag_transito.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var tr: Node = main.find_child("Transito", true, false)
	if tr == null:
		for n in main.find_children("*", "Node", true, false):
			if n.get_script() and (n.get_script() as Script).resource_path.ends_with("transito.gd"):
				tr = n
				break
	Engine.time_scale = 3.0
	var t := 0.0
	var encimados := 0
	var peor_espera := 0.0
	var muestra := 0.0
	while t < minutos * 60.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		muestra += dt
		if muestra < 0.25:
			continue
		muestra = 0.0
		var autos := get_tree().get_nodes_in_group("autos")
		for a: Auto in autos:
			peor_espera = maxf(peor_espera, a.espera)
		for i in autos.size():
			var a := autos[i] as Auto
			for j in range(i + 1, autos.size()):
				var b := autos[j] as Auto
				if Enemigo.plano(a.global_position - b.global_position).length() > (a.largo + b.largo) / 2.0:
					continue
				if not _se_pisan(a, b):
					continue
				var clave := "%d-%d" % [a.get_instance_id(), b.get_instance_id()]
				if _vistos.has(clave):
					continue
				_vistos[clave] = true
				encimados += 1
				print("  [%.1f min] encimados en %s:" % [t / 60.0, a.global_position.round()])
				for x: Auto in [a, b]:
					print("     %s por %s, s=%.1f de %.0f, vel %.1f, espera %.1f" % [x.tipo, tr._rutas[x.ruta]["nombre"], x.s,
						tr._rutas[x.ruta]["largo"], x.velocidad, x.espera])
	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if encimados == 0 else "%d ENCIMADOS" % encimados, " (la espera más larga: %.0f s)" % peor_espera)
	get_tree().quit(0 if encimados == 0 else 1)


func _se_pisan(a: Auto, b: Auto) -> bool:
	var ra := _rect(a)
	var rb := _rect(b)
	for r: Array in [ra, rb]:
		for k in 2:
			var eje: Vector2 = (r[(k + 1) % 4] as Vector2) - (r[k] as Vector2)
			eje = Vector2(-eje.y, eje.x).normalized()
			var a0 := INF
			var a1 := -INF
			var b0 := INF
			var b1 := -INF
			for p: Vector2 in ra:
				a0 = minf(a0, p.dot(eje))
				a1 = maxf(a1, p.dot(eje))
			for p: Vector2 in rb:
				b0 = minf(b0, p.dot(eje))
				b1 = maxf(b1, p.dot(eje))
			if a1 < b0 or b1 < a0:
				return false
	return true


func _rect(a: Auto) -> Array:
	var f := a.adelante()
	var adel := Vector2(f.x, f.z).normalized() * (a.largo / 2.0 - 0.15)
	var lado := Vector2(-f.z, f.x).normalized() * (a.ancho / 2.0 - 0.15)
	var c := Vector2(a.global_position.x, a.global_position.z)
	return [c + adel + lado, c + adel - lado, c - adel - lado, c - adel + lado]
