extends Node
## Prueba de los arreglos del mapa V3.1 (headless):
## godot --headless --path . res://tests/test_mapa_v31.tscn
## Autos estacionados, corazones de manzana, juegos que sólo se mueven con chicos, gente que no
## atraviesa la fuente, perros y gatos con animaciones, el circuito de agility y la paloma aplastada.

const FUENTE := Vector3(-140, 0, -61)   ## La fuente grande del rombo (cilindro de 1,6 m x 2,1)
const RADIO_FUENTE := 1.6 * 2.1

var fallas := 0


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var paloma := main.get_node("Paloma") as PalomaJugador
	await _frames(10)
	var ciudad := main.find_child("Ciudad", true, false) as Ciudad

	# Autos estacionados: pocos y de un solo lado (antes eran unos 80)
	print("  autos estacionados: ", ciudad.autos_estacionados)
	_check("pocos autos estacionados (8 a 25)", ciudad.autos_estacionados >= 8 and ciudad.autos_estacionados <= 25)
	# Corazones de manzana: lotes con casas, patios y galpones
	print("  lotes en los corazones de manzana: ", ciudad.lotes)
	_check("los corazones de manzana tienen lotes (> 60)", ciudad.lotes > 60)

	# Juegos: sin chicos, quietos; con alguien arriba, se mueven
	var chicos := get_tree().get_nodes_in_group("chicos")
	print("  chicos en la plaza de juegos: ", chicos.size())
	_check("hay chicos en la plaza de juegos", chicos.size() >= 3)
	Engine.time_scale = 4.0
	var algun_uso := false
	var t := 0.0
	while t < 70.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for j: Animado in get_tree().get_nodes_in_group("juegos_plaza"):
			if j.ocupados() > 0:
				algun_uso = true
	_check("los chicos se suben a los juegos", algun_uso)
	for c: Node in chicos:
		c.queue_free()
	await _segundos(14.0)
	var hamacas: Array = get_tree().get_nodes_in_group("juegos_plaza").filter(func(j: Animado) -> bool: return j.tipo == "hamacar")
	var calesita: Animado = get_tree().get_nodes_in_group("juegos_plaza").filter(func(j: Animado) -> bool: return j.tipo == "girar")[0]
	var quietas := true
	var giro0 := calesita.rotation.y
	t = 0.0
	while t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		for h: Animado in hamacas:
			quietas = quietas and absf(h.rotation.x) < 0.01
	_check("sin nadie arriba, las hamacas están quietas", quietas)
	_check("sin nadie arriba, la calesita no gira", absf(calesita.rotation.y - giro0) < 0.01)
	var h0: Animado = hamacas[0]
	h0.reservar(0, self)
	h0.subir(0)
	var maximo := 0.0
	t = 0.0
	while t < 14.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		maximo = maxf(maximo, absf(h0.rotation.x))
	h0.soltar(0)
	print("  envión de la hamaca con alguien arriba: ", snappedf(maximo, 0.01))
	_check("con alguien arriba, la hamaca se hamaca", maximo > 0.2)

	# La gente que pasea por el rombo no atraviesa la fuente
	var paseantes: Array = get_tree().get_nodes_in_group("humanos").filter(func(n: Node) -> bool:
		return n is Humano and (n as Humano).zona_tam != Vector2.ZERO and Enemigo.plano((n as Humano).zona_centro - FUENTE).length() < 1.0)
	print("  paseantes en el rombo: ", paseantes.size())
	for h: Humano in paseantes:
		h.va_a_locales = false   # Que ningún local se los lleve en medio de la prueba
		if h.visita != null:
			h.terminar_visita()   # (y si uno ya se lo llevó, que vuelva)
	_check("hay gente paseando alrededor de la fuente", paseantes.size() >= 3)
	var minima := INF
	# Uno arranca del otro lado de la fuente y tiene que cruzar
	if not paseantes.is_empty():
		var h := paseantes[0] as Humano
		h.global_position = FUENTE + Vector3(-5.5, h.global_position.y, 0)
		h.set("_destino", FUENTE + Vector3(5.5, 0, 0.2))
		h.set("_timer_paseo", 30.0)
	var cruzo := INF
	for k in 700:
		await get_tree().physics_frame
		for h: Humano in paseantes:
			minima = minf(minima, Enemigo.plano(h.global_position - FUENTE).length())
		if not paseantes.is_empty():
			cruzo = minf(cruzo, Enemigo.plano((paseantes[0] as Humano).global_position - (FUENTE + Vector3(5.5, 0, 0.2))).length())
	print("  lo más cerca que pasaron del centro de la fuente: ", snappedf(minima, 0.01), " m (radio ", RADIO_FUENTE, ")")
	_check("nadie atraviesa la fuente", minima > RADIO_FUENTE)
	if not paseantes.is_empty():
		var nav: Dictionary = (paseantes[0] as Humano).nav_zona
		_check("la zona del rombo tiene malla de navegación", int(nav.get("poligonos", 0)) > 0)
		print("  distancia al otro lado de la fuente: ", snappedf(cruzo, 0.1))
		_check("rodea la fuente y llega al otro lado", cruzo < 1.5)

	# Animales: con esqueleto y animaciones
	var animales := get_tree().get_nodes_in_group("animales")
	print("  animales: ", animales.size())
	_check("hay perros y gatos (>= 12)", animales.size() >= 12)
	var con_anim := 0
	for a: Animal in animales:
		var ap := a.find_children("*", "AnimationPlayer", true, false)
		if not ap.is_empty() and (ap[0] as AnimationPlayer).has_animation("caminar") and (ap[0] as AnimationPlayer).has_animation("sentado"):
			con_anim += 1
	_check("todos tienen animaciones (caminar, sentado...)", con_anim == animales.size())
	var paseadores: Array = animales.filter(func(a: Animal) -> bool: return a.conducta == "pasear")
	var antes: Array = paseadores.map(func(a: Animal) -> Vector3: return a.position)
	await _segundos(40.0)
	var se_movio := false
	for i in paseadores.size():
		se_movio = se_movio or (paseadores[i] as Animal).position.distance_to(antes[i]) > 1.0
	_check("los perros pasean", se_movio)

	# El perro de agility hace todo el circuito: salta las 5 vallas y sube la rampa
	var ag: Animal = animales.filter(func(a: Animal) -> bool: return a.conducta == "agility")[0]
	ag.call("_empezar_circuito")
	var alto_max := 0.0
	var y0 := ag.position.y
	var espera := 0
	while ag.get("_estado") == "circuito" and espera < 3000:
		await get_tree().process_frame
		alto_max = maxf(alto_max, ag.position.y - y0)
		espera += 1
	var saltos: Dictionary = ag.get("_saltos_hechos")
	print("  circuito: ", saltos.size(), " saltos, altura máxima en la rampa ", snappedf(alto_max, 0.01))
	_check("el perro hace el circuito de agility (5 vallas)", saltos.size() == 5)
	_check("sube la rampa", alto_max > 1.0)

	# Atropellada: queda chata y después se infla
	Engine.time_scale = 1.0
	paloma.aplastar()
	await _segundos(0.4)
	var chata := paloma.modelo.scale.y
	_check("la paloma queda chata (como en los dibujitos)", chata < 0.15 and paloma.esta_aplastada())
	await _segundos(PalomaJugador.DURACION_APLASTADA + 1.0)
	print("  escala aplastada / después: ", snappedf(chata, 0.01), " / ", snappedf(paloma.modelo.scale.y, 0.01))
	_check("después se infla de nuevo", not paloma.esta_aplastada() and absf(paloma.modelo.scale.y - 1.0) < 0.1)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
