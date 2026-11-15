extends Node
## Capturas del arranque nuevo (NO headless): la paloma sentada en el banco con el menú, el salto,
## la cinemática de Doña Rosa, los pasos del tutorial y la cinemática del objetivo.
## Uso: godot --path . --resolution 1280x720 res://tests/captura_inicio.tscn -- <carpeta>

var carpeta := "user://capturas_inicio"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	GameState.archivo_partida = "user://prueba_captura_inicio.cfg"
	GameState.borrar_partida()
	main = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	await _esperar(150)
	_capturar("1_menu_banco")
	main.menu.botones[1].emit_signal("pressed")
	for i in 32:
		await _esperar_segundos(0.5)
		_capturar("2_inicio_%02d" % i)
	# Cinemática del objetivo (en el juego aparece después de la picada)
	var tutorial: Node = main.get_node("Tutorial")
	print("paso del tutorial: ", tutorial.paso, " controlable: ", main.get_node("Paloma").controlable)
	tutorial._objetivo()
	for i in 30:
		await _esperar_segundos(0.6)
		_capturar("3_objetivo_%02d" % i)
	print("paso del tutorial: ", tutorial.paso if is_instance_valid(tutorial) else "terminado",
		" controlable: ", main.get_node("Paloma").controlable)
	GameState.borrar_partida()
	get_tree().quit()


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _esperar_segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _capturar(nombre: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(carpeta.path_join(nombre + ".png"))
