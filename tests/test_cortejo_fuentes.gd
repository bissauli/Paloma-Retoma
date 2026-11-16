extends Node
## Prueba automática del baile de cortejo y de las fuentes y charcos (headless):
## godot --headless --path . res://tests/test_cortejo_fuentes.tscn
## Usa un archivo de logros aparte: no toca el progreso del jugador.

const ARCHIVO_LOGROS := "user://test_logros_cortejo.cfg"

var fallas := 0
var main: Node
var paloma: PalomaJugador


func _ready() -> void:
	var archivo_real := Logros.archivo
	Logros.forzar = true
	Logros.archivo = ARCHIVO_LOGROS
	Logros.borrar_todo()
	main = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma") as PalomaJugador
	await _fisica(10)
	GameState.menu_activo = false
	GameState.en_partida = true
	paloma.controlable = true

	await _cortejo()
	await _fuentes()

	GameState.en_partida = false
	Logros.borrar_todo()
	Logros.forzar = false
	Logros.archivo = archivo_real
	Logros.cargar()
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


# ---------------------------------------------------------------- Cortejo

func _cortejo() -> void:
	var bandada := main.get_node("Bandada") as Bandada
	# La Catedral tiene muchas sueltas
	paloma.global_position = Vector3(0, 0.1, -14)
	paloma.reset_physics_interpolation()
	await _fisica(5)
	GameState.comida = 0
	var antes := GameState.bandada
	var sueltas := 0
	for n in bandada.get_children():
		if n is PalomaNPC and (n as PalomaNPC).modo == PalomaNPC.Modo.SUELTA \
				and (n as PalomaNPC).global_position.distance_to(paloma.global_position) <= Config.RADIO_CORTEJO:
			sueltas += 1
	_check("cortejo: hay palomas sueltas cerca (%d)" % sueltas, sueltas >= 4)

	paloma.bailar(&"cortejo")
	_check("cortejo: la jugadora baila el cortejo", paloma.modelo.baile_actual() == &"cortejo")
	var momentos: Array[int] = [0]
	paloma.modelo.cortejo_logrado.connect(func() -> void: momentos[0] += 1)
	# Al principio todavía no enamora a nadie
	await _fisica(10)
	_check("cortejo: al arrancar nadie se enamora todavía", GameState.bandada == antes and momentos[0] == 0)
	# Se salta al instante antes del gran final y se deja correr
	paloma.modelo._t_baile = Coreografia.MOMENTO_CORTEJO - 0.05
	for i in 90:
		await get_tree().process_frame
		await get_tree().physics_frame
		if momentos[0] > 0:
			break
	_check("cortejo: el gran final avisa una vez", momentos[0] == 1)
	_check("cortejo: se suman %d palomas gratis (bandada %d)" % [Config.CORTEJO_MAX, GameState.bandada],
		GameState.bandada == antes + Config.CORTEJO_MAX)
	_check("cortejo: no gastó comida", GameState.comida == 0)
	_check("cortejo: las que se sumaron siguen a la jugadora", bandada.seguidoras.size() >= Config.CORTEJO_MAX)
	_check("cortejo: cuenta para los logros (Rompecorazones)", Logros.hecho("rompecorazones")
		and Logros.valor("cortejadas") == float(Config.CORTEJO_MAX))

	# Una vuelta más, otro gran final, otras palomas
	paloma.modelo._t_baile = Coreografia.MOMENTO_CORTEJO - 0.05
	for i in 90:
		await get_tree().process_frame
		await get_tree().physics_frame
		if momentos[0] > 1:
			break
	_check("cortejo: cada vuelta enamora a otras %d" % Config.CORTEJO_MAX, GameState.bandada == antes + 2 * Config.CORTEJO_MAX)

	# Sin palomas cerca no pasa nada (y no rompe)
	paloma.modelo.dejar_de_bailar()
	paloma.global_position = Vector3(55, 0.1, 30)
	var b0 := GameState.bandada
	GameState.cortejo.emit(paloma.global_position, 3.0)
	await _fisica(3)
	_check("cortejo: sin nadie cerca no se suma nadie", GameState.bandada == b0)
	paloma.modelo.dejar_de_bailar()


# ---------------------------------------------------------------- Fuentes y charcos

func _fuentes() -> void:
	var todas := get_tree().get_nodes_in_group("fuentes")
	var fuentes: Array[Fuente] = []
	var charcos: Array[Fuente] = []
	for n in todas:
		var f := n as Fuente
		if f.altura > 0.0:
			fuentes.append(f)
		else:
			charcos.append(f)
	_check("fuentes: hay 2 fuentes y 4 charcos", fuentes.size() == 2 and charcos.size() == 4)
	if fuentes.is_empty() or charcos.is_empty():
		return
	var fuente := fuentes[0]

	# Lejos de todo, apretar E no hace nada
	paloma.global_position = Vector3(0, 0.1, 40)
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	await _fisica(5)
	_apretar("interactuar")
	await _fisica(4)
	_check("fuentes: lejos del agua no se baña", paloma.modelo.baile_actual() != Coreografia.BANO)

	# En la fuente: aterriza sobre el agua (la fuente es maciza hasta la altura del agua)
	paloma.global_position = fuente.global_position + Vector3(1.0, 0.8, 0.5)
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	await _fisica(60)
	_check("fuentes: la paloma se para en el agua de la fuente (y=%.2f)" % paloma.global_position.y,
		absf(paloma.global_position.y - fuente.altura) < 0.06 and paloma.estado == PalomaJugador.Estado.SUELO)
	await _fisica(10)
	_check("fuentes: dentro del agua aparece el cartel", fuente._cartel.visible)

	GameState.set_stamina(20.0)
	_apretar("interactuar")
	await _fisica(5)
	_check("fuentes: con E se pone a bañarse", paloma.modelo.baile_actual() == Coreografia.BANO and fuente._banando)
	_check("fuentes: con el baño puesto ya no se ve el cartel", not fuente._cartel.visible)
	await _fisica(60)
	_check("fuentes: salpica mientras se baña", fuente._salpicadura.emitting)
	_check("fuentes: el baño recarga stamina (%.0f)" % GameState.stamina, GameState.stamina > 40.0)
	_check("fuentes: todavía no es 'fresquita' al primer segundo", not Logros.hecho("remojon"))
	await _fisica(150)
	_check("fuentes: a los 3 segundos sale fresquita: logro 'Remojón'", Logros.hecho("remojon") and is_equal_approx(GameState.stamina, Config.STAMINA_MAX))
	_check("fuentes: el baño sigue hasta que se mueva", paloma.modelo.baile_actual() == Coreografia.BANO)
	var banos := Logros.valor("banos")
	await _fisica(120)
	_check("fuentes: seguir bañándose no repite el premio", Logros.valor("banos") == banos)

	# Moverse corta el baño
	Input.action_press("mover_adelante")
	await _fisica(8)
	Input.action_release("mover_adelante")
	_check("fuentes: al moverse termina el baño y dejan de salpicar", paloma.modelo.baile_actual() == &"" and not fuente._banando
		and not fuente._salpicadura.emitting)

	# Un charco también sirve (en el piso)
	var charco := charcos[0]
	paloma.global_position = charco.global_position + Vector3(0.3, 0.1, 0.0)
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	await _fisica(30)
	_apretar("interactuar")
	await _fisica(5)
	_check("charcos: también se baña en un charco", paloma.modelo.baile_actual() == Coreografia.BANO and charco._banando)
	paloma.modelo.dejar_de_bailar()
	await _fisica(3)

	# Volando no se baña
	paloma.global_position = fuente.global_position + Vector3(0, 6.0, 0)
	paloma.estado = PalomaJugador.Estado.AIRE
	await _fisica(3)
	_apretar("interactuar")
	await _fisica(3)
	_check("fuentes: volando sobre la fuente no se baña", paloma.modelo.baile_actual() != Coreografia.BANO)
	_check("fuentes: no hay baño de polvo (sólo agua): sólo se conoce el baño de agua", Coreografia.DURACION.has(&"bano")
		and not Coreografia.DURACION.has(&"polvo"))
	paloma.global_position = Vector3(0, 0.5, 40)


func _apretar(accion: String) -> void:
	var e := InputEventAction.new()
	e.action = accion
	e.pressed = true
	Input.parse_input_event(e)
	var s := InputEventAction.new()
	s.action = accion
	s.pressed = false
	Input.parse_input_event(s)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
