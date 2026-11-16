extends Node
## Prueba automática del cielo, el día y la noche y el clima (headless):
## godot --headless --path . res://tests/test_cielo.tscn

var fallas := 0


func _ready() -> void:
	var cielo := Cielo.new()
	add_child(cielo)
	GameState.reiniciar()
	GameState.menu_activo = false
	_check("una partida nueva arranca a la hora de inicio y despejada",
		is_equal_approx(GameState.hora_dia, Config.HORA_INICIO) and GameState.clima == Cielo.Clima.DESPEJADO)

	# El reloj avanza con la partida
	var antes := GameState.hora_dia
	for i in 30:
		await get_tree().process_frame
	_check("el reloj avanza durante la partida", GameState.hora_dia > antes)

	# El sol sale por el este, está alto al mediodía y de noche está bajo el horizonte
	_check("al mediodía el sol está alto", Cielo.dir_sol(12.5).y > 0.8)
	_check("a la mañana el sol está al este", Cielo.dir_sol(8.0).x > 0.3)
	_check("de noche el sol está bajo el horizonte", Cielo.dir_sol(1.0).y < 0.0)
	_check("de noche la luna está arriba", Cielo.dir_luna(0.5).y > 0.3)

	# De noche: luz más baja, tinte de sombra oscuro, estrellas
	GameState.hora_dia = 12.0
	cielo.forzar_clima(Cielo.Clima.DESPEJADO, true)
	var luz_dia := cielo.sol.light_energy
	var cozy_dia := cielo.cozy_actual
	GameState.hora_dia = 1.0
	cielo.forzar_clima(Cielo.Clima.DESPEJADO, true)
	var luz_noche := cielo.sol.light_energy
	var cozy_noche := cielo.cozy_actual
	_check("de noche la luz es más baja", luz_noche < luz_dia * 0.5)
	_check("de noche el tinte de sombra se oscurece", cozy_noche.get_luminance() < cozy_dia.get_luminance() * 0.7)
	_check("de noche hay estrellas", float(cielo.cielo_mat.get_shader_parameter("estrellas")) > 0.5)

	# Clima
	GameState.hora_dia = 12.0
	cielo.forzar_clima(Cielo.Clima.LLUVIA, true)
	_check("con lluvia hay nubes y gotas", cielo.nubosidad > 0.5 and cielo.lluvia > 0.9)
	_check("con lluvia el sol baja", cielo.sol.light_energy < luz_dia * 0.7)
	cielo.forzar_clima(Cielo.Clima.DESPEJADO)
	for i in 10:
		await get_tree().process_frame
	_check("el clima cambia de a poco", cielo.lluvia < 1.0 and cielo.lluvia > 0.5)

	# Hora y clima se guardan con la partida
	GameState.hora_dia = 21.5
	GameState.clima = Cielo.Clima.NUBLADO
	var datos := {"hora_dia": GameState.hora_dia, "clima": GameState.clima}
	GameState.reiniciar(datos)
	_check("la partida guardada recupera hora y clima", is_equal_approx(GameState.hora_dia, 21.5) and GameState.clima == Cielo.Clima.NUBLADO)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
