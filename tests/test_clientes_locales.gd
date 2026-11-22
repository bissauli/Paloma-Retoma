extends Node
## Prueba automática de los clientes de los locales (corre headless):
## godot --headless --path . res://tests/test_clientes_locales.tscn
## Los clientes no aparecen en la puerta: son paseantes de la ciudad (Humano) que se desvían, caminan
## hasta el local, entran, miran, salen y vuelven a pasear. Nunca quedan metidos en una pared: llegando
## no atraviesan ningún edificio con locales y adentro no salen de la sala.

var fallas := 0
var paloma: PalomaJugador
const SEGUNDOS_POR_EDIFICIO := 40.0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_clientes.cfg"
	GameState.guardado_habilitado = false
	if OS.get_environment("PALOMA_SEMILLA") == "":
		OS.set_environment("PALOMA_SEMILLA", "7")
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	for i in 20:
		await get_tree().process_frame
	var locales: Array[GenteLocal] = []
	for g in main.find_children("Gente", "GenteLocal", true, false):
		locales.append(g)
	_check("hay gente en los locales (%d)" % locales.size(), locales.size() >= 8)
	# Nadie se inventa en la puerta: cada local tiene sólo a su empleado
	var solo_empleado := true
	for g in locales:
		var modelos := 0
		for h in g.get_children():
			if h is ModeloHumano:
				modelos += 1
		if modelos != 1:
			solo_empleado = false
	_check("cada local tiene sólo a su empleado (los clientes son paseantes de la ciudad)", solo_empleado)
	var edificios := get_tree().get_nodes_in_group(Pasaje.GRUPO_EDIFICIOS)
	await get_tree().create_timer(2.0).timeout
	if OS.has_environment("DEPURAR"):
		for g in locales:
			var puerta := g.to_global(g._frente_puerta())
			var cerca := [0, 0, 0]
			for n in get_tree().get_nodes_in_group("humanos"):
				var h := n as Humano
				if h == null or not h.puede_visitar():
					continue
				var d := h.global_position.distance_to(puerta)
				if d < 40.0: cerca[0] += 1
				if d < 70.0: cerca[1] += 1
				var q := PhysicsRayQueryParameters3D.create(h.global_position + Vector3.UP * 1.5, puerta + Vector3.UP * 1.5, 1)
				if d < 40.0 and get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty(): cerca[2] += 1
			print("    candidatos %s: <40 %d, <70 %d, <40 a la vista %d" % [g.ce.tema, cerca[0], cerca[1], cerca[2]])
	Engine.time_scale = 4.0
	var en_pared := 0
	var fuera_de_sala := 0
	var visitantes := {}
	for e: Node3D in edificios:
		# La paloma quieta frente al edificio (los locales llaman clientes sólo con ella cerca)
		paloma.global_position = e.to_global(Vector3(0, 0.3, 12.0))
		paloma.reset_physics_interpolation()
		paloma.velocity = Vector3.ZERO
		var t := 0.0
		while t < SEGUNDOS_POR_EDIFICIO:
			await get_tree().physics_frame
			t += get_physics_process_delta_time() * Engine.time_scale
			for n in get_tree().get_nodes_in_group("humanos"):
				var h := n as Humano
				if h == null or h.visita == null:
					continue
				visitantes[h.get_instance_id()] = true
				var c := h.visita._cliente_de(h)
				if c.is_empty():
					continue
				if c["fase"] == GenteLocal.Fase.ADENTRO and not c["saliendo"]:
					var p := h.visita.to_local(h.global_position)
					var hx := h.visita.ce.ancho / 2.0 - CasaEnterable.ESPESOR + 0.05
					var hz := h.visita.ce.fondo / 2.0 + GenteLocal.VEREDA + 0.6   # (al entrar todavía está en la vereda)
					if absf(p.x) > hx or absf(p.z) > hz:
						fuera_de_sala += 1
						print("    afuera: ", h.visita.ce.tema, " ", p, " camino ", c["camino"], " paso ", c["paso"])
				elif c["fase"] != GenteLocal.Fase.ADENTRO and _en_un_edificio(edificios, h.global_position):
					en_pared += 1
					print("    en un edificio: ", h.visita.ce.tema, " fase ", c["fase"], " ", h.global_position)
	# Un rato más, para que lleguen los que iban caminando al último edificio
	var extra := 0.0
	while extra < 30.0:
		await get_tree().physics_frame
		extra += get_physics_process_delta_time() * Engine.time_scale
	Engine.time_scale = 1.0
	var llamados := 0
	var entraron := 0
	var salieron := 0
	var con_clientes := 0
	for g in locales:
		llamados += g.llamados
		entraron += g.entraron
		salieron += g.salieron
		if g.entraron > 0:
			con_clientes += 1
		print("  %s (%s): %d llamados (%d de lejos), %d entraron, %d salieron" % [g.ce.nombre, g.ce.tema, g.llamados,
			g.prestados, g.entraron, g.salieron])
	_check("se desvían paseantes hacia los locales (%d)" % llamados, llamados >= 8)
	_check("entran a casi todos los locales (%d, en %d de %d)" % [entraron, con_clientes, locales.size()],
		entraron >= 8 and con_clientes >= locales.size() - 2)
	_check("salen y vuelven a pasear (%d)" % salieron, salieron >= 2)
	_check("son paseantes distintos (%d)" % visitantes.size(), visitantes.size() >= 4)
	var nadie_nuevo := true
	for g in locales:
		for h in g.get_children():
			if h is ModeloHumano and h != g._empleado:
				nadie_nuevo = false
	_check("los locales no crean gente (sólo el empleado)", nadie_nuevo)
	_check("llegando nunca atraviesan un edificio con locales (%d cuadros)" % en_pared, en_pared == 0)
	_check("adentro nunca salen del local (%d cuadros)" % fuera_de_sala, fuera_de_sala == 0)
	await _prestado_a_la_vista(locales)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Un prestado que se va hacia una punta de la vereda donde está la paloma (a la vista) no se queda ahí
## yendo y viniendo: busca otra punta o deja de ser cliente (la prueba larga encontró uno 4 minutos así).
func _prestado_a_la_vista(locales: Array[GenteLocal]) -> void:
	var g := locales[0]
	var h: Humano = null
	for intento in 600:   # (puede que justo estén todos de visita o asustados: espera uno libre)
		for n in get_tree().get_nodes_in_group("humanos"):
			if n is Humano and (n as Humano).puede_visitar():
				h = n
				break
		if h:
			break
		await get_tree().physics_frame
	if h == null:
		_check("hay un paseante para prestar", false)
		return
	var salida := g.to_global(Vector3(g.ce.x_frente + 14.0, 0.0, g.ce.fondo / 2.0 + GenteLocal.VEREDA))
	salida.y = h.global_position.y
	h.global_position = salida + Vector3(0.3, 0, 0)
	h.reset_physics_interpolation()
	h.visita = g
	g._clientes.append({"h": h, "fase": GenteLocal.Fase.YENDOSE, "prestado": true, "salida": salida, "t": 0.0})
	paloma.global_position = salida + Vector3(2.0, 0.3, 0)
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	Engine.time_scale = 4.0
	var t := 0.0
	while t < 90.0 and h.visita == g and Enemigo.plano(h.global_position - salida).length() < 3.0:
		await get_tree().physics_frame
		paloma.global_position = salida + Vector3(2.0, 0.3, 0)
		t += get_physics_process_delta_time()   # (ya viene multiplicado por time_scale)
	Engine.time_scale = 1.0
	print("  prestado a la vista: %.0f s, %s" % [t, "sigue de visita" if h.visita == g else "ya no es cliente"])
	_check("un prestado a la vista de la paloma no se queda en la punta (se fue a los %.0f s)" % t, t < 60.0)
	if h.visita != null:
		h.terminar_visita()


## ¿"p" cae adentro del bloque de algún edificio con locales (con 15 cm de margen de las paredes)?
func _en_un_edificio(edificios: Array, p: Vector3) -> bool:
	for e: Node3D in edificios:
		var l := e.to_local(p)
		var w := 0.0
		var d := 0.0
		for ce in e.find_children("*", "CasaEnterable", true, false):
			w = maxf(w, absf((ce as CasaEnterable).position.x) * 2.0 + (ce as CasaEnterable).ancho)
			d = maxf(d, (ce as CasaEnterable).fondo)
		if absf(l.x) < w / 2.0 - 0.15 and absf(l.z) < d / 2.0 - 0.15 and l.y < 3.0:
			return true
	return false


func _check(nombre: String, ok: bool) -> void:
	print(("  OK   " if ok else "  FALLA ") + nombre)
	if not ok:
		fallas += 1
