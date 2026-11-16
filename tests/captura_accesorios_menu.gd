extends Node
## Captura de la pantalla temporal "Accesorios" del menú principal (NO headless):
## godot --path . --resolution 1920x1080 res://tests/captura_accesorios_menu.tscn -- <carpeta>
## Pone algunos accesorios, saca dos fotos y deja el perfil como estaba.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	await _esperar(150)
	get_viewport().get_texture().get_image().save_png(carpeta.path_join("menu_con_accesorios.png"))
	var perfil := PerfilPaloma.actual()
	var antes: Array = perfil.accesorios.duplicate()   # Se restaura al final (la pantalla guarda el perfil)
	perfil.set_accesorio(0, 6)   # Corona
	perfil.set_accesorio(1, 2)   # Capa
	perfil.set_accesorio(4, 1)   # Gafas de sol
	perfil.set_accesorio(5, 1)   # Cadena de oro
	main.menu._abrir("accesorios")
	await _esperar(90)
	get_viewport().get_texture().get_image().save_png(carpeta.path_join("pantalla_accesorios.png"))
	for i in antes.size():
		perfil.set_accesorio(i, antes[i])
	await _esperar(5)
	get_tree().quit()


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
