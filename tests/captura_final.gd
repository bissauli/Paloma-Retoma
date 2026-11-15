extends Node
## Recorre la partida completa a los saltos y saca capturas (NO headless):
## godot --path . res://tests/captura_final.tscn -- <carpeta_salida>
## También sirve headless como prueba de la victoria (sin capturas).

var salida := ""
var gano := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var p := main.get_node("Paloma") as PalomaJugador
	GameState.victoria.connect(func() -> void: set("gano", true))
	await _frames(60)
	_capturar("f1_inicio_tutorial")
	# Reclutar en todas las zonas hasta tener 30+
	GameState.sumar_comida(60)
	for z in get_tree().get_nodes_in_group("zona_palomas"):
		if GameState.bandada >= 32:
			break
		p.global_position = (z as Node3D).global_position + Vector3(0, 0.1, 0)
		p.reset_physics_interpolation()
		p.camara.reubicar()
		await _frames(8)
		p.arrullar()
		await _frames(8)
		GameState.invulnerable = 5.0
	print("  bandada reclutada: ", GameState.bandada)
	p.global_position = Vector3(10, 9, 0)
	p.reset_physics_interpolation()
	p.camara.reubicar()
	p.camara.yaw = -PI / 2.0
	await _frames(120)
	_capturar("f2_bandada_grande")
	# Aterrizar en el balcón
	GameState.invulnerable = 5.0
	p.global_position = Vector3(39.8, 7.6, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await _frames(60)
	print("  ¿ganó?: ", GameState.partida_terminada)
	await _frames(120)
	_capturar("f3_victoria")
	await _frames(360)
	_capturar("f4_creditos")
	await _frames(180)
	_capturar("f5_baile_suelo")
	await _frames(240)
	_capturar("f6_baile_siguiente")
	print("RESULTADO: ", "OK" if GameState.partida_terminada and GameState.bandada >= 30 else "FALLA")
	get_tree().quit(0 if GameState.partida_terminada else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _capturar(nombre: String) -> void:
	if salida != "":
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
