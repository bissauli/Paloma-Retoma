extends Node
## Capturas del selector de idioma (NO headless): menú en español, en inglés, Opciones en inglés y
## Cargar partida en inglés. Se guardan en user://capturas/ (o en la carpeta del primer argumento).
## godot --path . --resolution 1280x720 res://tests/captura_idioma.tscn -- [carpeta]

var carpeta := "user://capturas"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	Ajustes.ARCHIVO = "user://prueba_captura_idioma.cfg"   # No toca las opciones del jugador
	GameState.archivo_partida = "user://prueba_captura_partida.cfg"
	GameState.borrar_partida()
	Ajustes.idioma = ""
	Ajustes.set_idioma("es")
	var main: Node = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	await _esperar(150)
	var menu: MenuPrincipal = main.menu
	_capturar("idioma_es")
	# Click en la bandada del Reino Unido
	menu._idiomas._botones["en"].pressed.emit()
	await _esperar(20)
	_capturar("idioma_en")
	menu._abrir("opciones")
	await _esperar(30)
	_capturar("idioma_en_opciones")
	menu._opciones.cerrar()
	await _esperar(20)
	menu._abrir("cargar")
	await _esperar(30)
	_capturar("idioma_en_cargar")
	menu._cargar.cerrar()
	Ajustes.set_idioma("es")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	get_tree().quit()


func _esperar(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(carpeta.path_join(nombre + ".png"))
