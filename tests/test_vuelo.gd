extends Node
## Prueba automática del movimiento de la paloma (correr headless):
## godot --headless --path . res://tests/test_vuelo.tscn

var paloma: PalomaJugador
var fallas := 0


func _ready() -> void:
	# Con "-- movil" corre con el perfil del teléfono (física a 30 Hz)
	if OS.get_cmdline_user_args().has("movil"):
		Ajustes.movil = true
		Ajustes.aplicar_perfil_movil()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	# Corredor despejado al sur de la plaza para que no choque con nada
	paloma.global_position = Vector3(-24, 0.1, 18.5)
	paloma.reset_physics_interpolation()
	await _frames(20)
	_check("arranca en el suelo", paloma.estado == PalomaJugador.Estado.SUELO)

	var x0 := paloma.global_position.x
	Input.action_press("mover_adelante")
	await _frames(60)
	Input.action_release("mover_adelante")
	var avance := absf(paloma.global_position.x - x0)
	print("  camino ", snappedf(avance, 0.01), " m en 1 s")
	_check("camina lento (1.5-3 m)", avance > 1.5 and avance < 3.2)

	Input.action_press("volar")
	await _frames(2)
	_check("despega", paloma.estado == PalomaJugador.Estado.AIRE)
	Input.action_press("mover_adelante")
	await _frames(90)
	var y_alto := paloma.global_position.y
	print("  altura tras 1.5 s aleteando: ", snappedf(y_alto, 0.01), "  stamina: ", snappedf(GameState.stamina, 0.1))
	_check("gana altura aleteando", y_alto > 3.0)
	Input.action_release("volar")
	await _frames(60)
	print("  vel. vertical planeando: ", snappedf(paloma.velocity.y, 0.01))
	_check("caída lenta al planear", paloma.velocity.y > -3.0 and paloma.velocity.y < 0.0)

	Input.action_press("picada")
	await _frames(40)
	var vel_picada := paloma.velocity.length()
	print("  velocidad en picada: ", snappedf(vel_picada, 0.1))
	print("  posición: ", paloma.global_position)
	_check("la picada es rápida", vel_picada > 14.0)
	Input.action_release("picada")
	Input.action_release("mover_adelante")

	var espera := 0
	while paloma.estado != PalomaJugador.Estado.SUELO and espera < 900:
		await get_tree().physics_frame
		espera += 1
	print("  aterrizó en ", espera, " frames, y=", snappedf(paloma.global_position.y, 0.01))
	_check("aterriza sola", paloma.estado == PalomaJugador.Estado.SUELO)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Espera n pasos de física "de 60 Hz" (con la física a 30 Hz, la mitad: el mismo tiempo).
## Las esperas cortas (que la física vea una tecla) no se achican.
func _frames(n: int) -> void:
	for i in (n if n <= 4 else roundi(n * Engine.physics_ticks_per_second / 60.0)):
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
