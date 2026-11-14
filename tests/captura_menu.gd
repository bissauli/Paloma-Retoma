extends Node
## Captura del menú principal con sus ventanas (NO headless).
## Guarda en user://capturas/: menu_aviso, menu_opciones, menu_ayuda y menu_mudo.

const CARPETA := "user://capturas"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var t: Node = load("res://ui/titulo.tscn").instantiate()
	add_child(t)
	await _esperar(150)
	t._proximamente()
	await _esperar(20)
	_capturar("menu_aviso")
	t._abrir("opciones")
	await _esperar(30)
	_capturar("menu_opciones")
	t._opciones.cerrar()
	t._abrir("ayuda")
	await _esperar(30)
	_capturar("menu_ayuda")
	t._ayuda.cerrar()
	t._alternar_sonido()
	await _esperar(5)
	_capturar("menu_mudo")
	t._alternar_sonido()  # dejarlo como estaba
	print("capturas en ", ProjectSettings.globalize_path(CARPETA))
	get_tree().quit()


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _capturar(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(CARPETA.path_join(nombre + ".png"))
