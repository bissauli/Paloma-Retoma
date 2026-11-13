extends Node
## Saca capturas de pantalla para revisar visualmente (NO headless):
## godot --path . res://tests/captura.tscn -- <carpeta_salida> [modo]

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var p := main.get_node("Paloma") as PalomaJugador
	await _frames(40)
	_capturar("1_suelo")
	# Vista de cerca de la paloma caminando
	Input.action_press("mover_adelante")
	await _frames(30)
	_capturar("2_caminando")
	Input.action_press("volar")
	await _frames(50)
	_capturar("3_aleteo")
	Input.action_release("volar")
	await _frames(40)
	_capturar("4_planeo")
	Input.action_press("picada")
	await _frames(30)
	_capturar("5_picada")
	Input.action_release("picada")
	Input.action_release("mover_adelante")
	print("capturas listas, estado final: ", p.estado)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(salida.path_join(nombre + ".png"))
