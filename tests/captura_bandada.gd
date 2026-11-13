extends Node
## Capturas de la bandada (NO headless):
## godot --path . res://tests/captura_bandada.tscn -- <carpeta_salida>

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var p := main.get_node("Paloma") as PalomaJugador
	await _frames(10)
	p.global_position = Vector3(0, 0.1, -10)
	p.reset_physics_interpolation()
	p.camara.reubicar()
	p.camara.yaw = PI
	await _frames(20)
	_capturar("b1_catedral_sueltas")
	GameState.sumar_comida(20)
	p.arrullar()
	await _frames(40)
	_capturar("b2_arrullo")
	Input.action_press("volar")
	Input.action_press("mover_atras")
	await _frames(70)
	Input.action_release("volar")
	await _frames(50)
	_capturar("b3_bandada_volando")
	Input.action_release("mover_atras")
	await _frames(200)
	_capturar("b4_bandada_aterrizada")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
