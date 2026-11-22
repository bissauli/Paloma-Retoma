extends Node
## Prueba larga del mundo (headless, a velocidad normal): deja la ciudad andando N minutos con la paloma
## mudándose de barrio cada tanto y anota lo que les pasa a la gente y a los autos:
## - gente trabada (empuja sin avanzar 10 s o más), caída abajo del piso, fuera del mapa, o "visitando"
##   un local demasiado tiempo;
## - autos parados mucho tiempo, autos encimados, autos caídos, y cuántos hay;
## - cuánta gente, autos y nodos hay a lo largo del tiempo (para ver si algo crece sin parar) y los FPS.
## godot --headless --path . res://tests/prueba_larga.tscn -- [minutos]

const LUGARES := [Vector3(0, 0.3, 0), Vector3(-40, 0.3, 24), Vector3(-140, 0.3, -55), Vector3(60, 0.3, 40),
	Vector3(-60, 0.3, -80), Vector3(20, 0.3, -30)]   ## Plaza, avenida, rombo, este, oeste, pasaje
const MUDANZA := 240.0       ## Cada cuántos segundos la paloma cambia de lugar
const TRABADO := 20          ## Muestras de medio segundo seguidas (10 s)
const AUTO_PARADO := 60.0    ## Segundos parado para contar como trabado
const VISITA_LARGA := 300.0  ## Segundos visitando un local

var _gente := {}     # id -> {pos: Array, seguidas, peor, t_visita, reportado: {}}
var _autos := {}     # id -> {parado, peor, reportado: {}}
var _problemas := {} # clave -> veces
var _eventos: Array[String] = []
var _t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var minutos := float(args[0]) if args.size() > 0 else 32.0
	Ajustes.ARCHIVO = "user://prueba_larga.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var paloma := main.get_node("Paloma") as Node3D
	var muestra := 0.0
	var informe := 0.0
	var mudanza := 0.0
	var lugar := 0
	var frames := 0
	var t_real := Time.get_ticks_msec()
	var peor_fps := INF
	print("PRUEBA LARGA: ", minutos, " minutos")
	while _t < minutos * 60.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		_t += dt
		muestra += dt
		informe += dt
		mudanza += dt
		frames += 1
		if mudanza >= MUDANZA:
			mudanza = 0.0
			lugar = (lugar + 1) % LUGARES.size()
			paloma.global_position = LUGARES[lugar]
			if paloma is CharacterBody3D:
				(paloma as CharacterBody3D).velocity = Vector3.ZERO
			_evento("la paloma se muda a %s" % LUGARES[lugar])
		if muestra >= 0.5:
			muestra = 0.0
			_muestrear_gente()
			_muestrear_autos()
		if informe >= 60.0:
			var ms := Time.get_ticks_msec() - t_real
			var fps := frames * 1000.0 / maxf(ms, 1.0)
			peor_fps = minf(peor_fps, fps)
			print("[%5.1f min] gente %d  autos %d  animales %d  palomas %d  nodos %d  huérfanos %d  memoria %.0f MB  fps %.0f" % [
				_t / 60.0, get_tree().get_nodes_in_group("humanos").size(), get_tree().get_nodes_in_group("autos").size(),
				get_tree().get_nodes_in_group("animales").size(), get_tree().get_nodes_in_group("palomas_npc").size(),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, fps])
			informe = 0.0
			frames = 0
			t_real = Time.get_ticks_msec()
	_resumen(peor_fps)


func _evento(texto: String) -> void:
	var linea := "  [%5.1f min] %s" % [_t / 60.0, texto]
	_eventos.append(linea)
	print(linea)


func _problema(clave: String) -> void:
	_problemas[clave] = int(_problemas.get(clave, 0)) + 1


func _muestrear_gente() -> void:
	for n in get_tree().get_nodes_in_group("humanos"):
		var h := n as Humano
		if h == null or not h.is_inside_tree():
			continue
		var id := h.get_instance_id()
		if not _gente.has(id):
			_gente[id] = {"pos": [], "seguidas": 0, "peor": 0, "t_visita": 0.0, "rep": {}}
		var d: Dictionary = _gente[id]
		var p := h.global_position
		var pos: Array = d["pos"]
		pos.append(p)
		if pos.size() > 14:
			pos.pop_front()
		var rep: Dictionary = d["rep"]
		if p.y < -2.0 and not rep.has("cayo"):
			rep["cayo"] = true
			_problema("gente caída abajo del piso|%s" % h.tipo)
			_evento("%s cayó abajo del piso en %s" % [h.tipo, p.round()])
		if (absf(p.x) > 450.0 or absf(p.z) > 450.0) and not rep.has("lejos"):
			rep["lejos"] = true
			_problema("gente fuera del mapa|%s" % h.tipo)
			_evento("%s fuera del mapa en %s" % [h.tipo, p.round()])
		if h.visita != null:
			d["t_visita"] = float(d["t_visita"]) + 0.5
			if float(d["t_visita"]) > VISITA_LARGA and not rep.has("visita"):
				rep["visita"] = true
				_problema("visita a un local de más de %d s|%s" % [int(VISITA_LARGA), h.tipo])
				_evento("%s lleva %d s en una visita a un local, en %s" % [h.tipo, int(VISITA_LARGA), p.round()])
		else:
			d["t_visita"] = 0.0
		if pos.size() >= 12:
			var camino := 0.0
			for k in range(pos.size() - 12, pos.size() - 1):
				camino += Enemigo.plano(pos[k + 1] - pos[k]).length()
			var neto := Enemigo.plano(pos[pos.size() - 1] - pos[pos.size() - 12]).length()
			var vel := Enemigo.plano(h._vel).length()
			var que := ""
			if camino > 2.0 and neto < 0.5:
				que = "va y viene"
			elif vel > 0.45 and camino < 0.5 and not h._comiendo and h._atendiendo == null:
				que = "empuja sin avanzar"
			d["seguidas"] = (int(d["seguidas"]) + 1) if que != "" else 0
			d["peor"] = maxi(int(d["peor"]), int(d["seguidas"]))
			if int(d["seguidas"]) == TRABADO:
				_problema("gente trabada 10 s (%s)|%s|%s" % [que, h.tipo, Vector3i(p.round())])
				_evento("%s trabado 10 s (%s) en %s, destino %s%s" % [h.tipo, que, p.round(), h.destino_final.round(),
					" (visitando un local)" if h.visita != null else ""])


func _muestrear_autos() -> void:
	var autos := get_tree().get_nodes_in_group("autos")
	for n in autos:
		var a := n as Auto
		if a == null or not a.is_inside_tree():
			continue
		var id := a.get_instance_id()
		if not _autos.has(id):
			_autos[id] = {"parado": 0.0, "peor": 0.0, "rep": {}}
		var d: Dictionary = _autos[id]
		var rep: Dictionary = d["rep"]
		d["parado"] = (float(d["parado"]) + 0.5) if absf(a.velocidad) < 0.3 else 0.0
		d["peor"] = maxf(float(d["peor"]), float(d["parado"]))
		if float(d["parado"]) >= AUTO_PARADO and not rep.has("parado"):
			rep["parado"] = true
			_problema("auto parado %d s|%s|%s" % [int(AUTO_PARADO), a.tipo, Vector3i(a.global_position.round())])
			_evento("%s parado %d s en %s (espera %.0f)" % [a.tipo, int(AUTO_PARADO), a.global_position.round(), a.espera])
		if a.global_position.y < -2.0 and not rep.has("cayo"):
			rep["cayo"] = true
			_problema("auto caído|%s" % a.tipo)
			_evento("%s cayó abajo del piso en %s" % [a.tipo, a.global_position.round()])
	# Encimados: dos carrocerías que se pisan (rectángulos orientados, en el plano)
	for i in autos.size():
		var a := autos[i] as Auto
		for j in range(i + 1, autos.size()):
			var b := autos[j] as Auto
			if Enemigo.plano(a.global_position - b.global_position).length() > (a.largo + b.largo) / 2.0:
				continue
			if absf(a.global_position.y - b.global_position.y) > 2.0:
				continue
			if _se_pisan(a, b):
				var clave := "%d-%d" % [mini(a.get_instance_id(), b.get_instance_id()), maxi(a.get_instance_id(), b.get_instance_id())]
				var d: Dictionary = _autos[a.get_instance_id()]
				if not (d["rep"] as Dictionary).has(clave):
					(d["rep"] as Dictionary)[clave] = true
					_problema("autos encimados|%s y %s" % [a.tipo, b.tipo])
					_evento("%s y %s encimados en %s" % [a.tipo, b.tipo, a.global_position.round()])


## Dos rectángulos orientados (achicados 15 cm por lado) que se cruzan: separación de ejes.
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


func _resumen(peor_fps: float) -> void:
	print("")
	print("=== RESUMEN (%.1f minutos de juego) ===" % (_t / 60.0))
	print("personas vistas: %d, autos vistos: %d, fps más bajo (promedio de un minuto): %.0f" % [_gente.size(), _autos.size(), peor_fps])
	var peor_gente := 0
	for id in _gente:
		peor_gente = maxi(peor_gente, int((_gente[id] as Dictionary)["peor"]))
	var peor_auto := 0.0
	for id in _autos:
		peor_auto = maxf(peor_auto, float((_autos[id] as Dictionary)["peor"]))
	print("lo más que alguien quedó trabado: %.1f s; lo más que un auto estuvo parado: %.0f s" % [peor_gente * 0.5, peor_auto])
	print("problemas (tipo|detalle: veces):")
	if _problemas.is_empty():
		print("  ninguno")
	for k in _problemas:
		print("  ", k, ": ", _problemas[k])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if _problemas.is_empty() else "%d PROBLEMAS" % _problemas.size())
	get_tree().quit(0 if _problemas.is_empty() else 1)
