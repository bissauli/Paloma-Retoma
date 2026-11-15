extends Node
## Capturas del menú principal (NO headless): menú, foco, Opciones (con un desplegable abierto),
## Cargar partida (vacía y con una partida de prueba), la transición de la cámara al juego y la pausa.
## Uso: godot --path . --resolution 1920x1080 res://tests/captura_menu.tscn -- <carpeta> <prefijo>
## Sin argumentos guarda en user://capturas/. La partida de prueba va en otro archivo
## (no toca la partida guardada de verdad).

var carpeta := "user://capturas"
var prefijo := ""
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	if args.size() > 1:
		prefijo = args[1] + "_"
	DirAccess.make_dir_recursive_absolute(carpeta)
	GameState.archivo_partida = "user://prueba_captura_partida.cfg"
	GameState.borrar_partida()

	main = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	await _esperar(150)
	_capturar("menu")
	var menu: MenuPrincipal = main.menu

	# Foco en otro botón (como con las flechas o el mando)
	menu.botones[4].grab_focus()   # Opciones (el 3 es Personalizar paloma)
	await _esperar(20)
	_capturar("menu_foco_opciones")

	# Opciones
	menu._abrir("opciones")
	await _esperar(30)
	_capturar("opciones")
	var calidad: OptionButton = menu._opciones._calidad
	calidad.grab_focus()
	calidad.show_popup()
	await _esperar(10)
	_capturar("opciones_desplegable")
	calidad.get_popup().hide()
	menu._opciones.cerrar()
	await _esperar(15)

	# Cargar partida: vacía y con una partida de prueba
	menu._abrir("cargar")
	await _esperar(30)
	_capturar("cargar_vacio")
	menu._cargar.cerrar()
	var cfg := ConfigFile.new()
	cfg.set_value("partida", "version", 1)
	cfg.set_value("partida", "fecha", int(Time.get_unix_time_from_system()))
	cfg.set_value("partida", "bandada", 12)
	cfg.set_value("partida", "comida", 7)
	cfg.set_value("partida", "tiempo_jugado", 512.0)
	cfg.set_value("partida", "progreso_dia", 0.4)
	cfg.set_value("partida", "tutorial_hecho", true)
	cfg.set_value("partida", "migas_comidas", 9)
	cfg.set_value("partida", "umbrales", [5])
	cfg.save(GameState.archivo_partida)
	menu._abrir("cargar")
	await _esperar(30)
	_capturar("cargar_partida")
	menu._cargar.cerrar()
	await _esperar(30)
	_capturar("menu_con_continuar")

	# NUEVA PARTIDA con una partida guardada: avisa que se borra y la paloma ladea la cabeza
	menu.botones[1].emit_signal("pressed")
	await _esperar_segundos(0.8)
	_capturar("confirmar_nueva_1")
	await _esperar_segundos(2.2)
	_capturar("confirmar_nueva_2")
	menu._confirmar.cerrar()
	await _esperar(30)
	_capturar("confirmar_cancelada")
	menu.botones[1].emit_signal("pressed")
	await _esperar(10)
	# Transición: confirmar (la paloma salta y la cámara pasa a seguirla sin cortes)
	menu._confirmar._empezar.emit_signal("pressed")
	var cam: CamaraMenu = main.camara_menu
	var dur := cam.duracion
	for i in 5:
		await _esperar_segundos(dur / 5.0)
		_capturar("transicion_%d" % (i + 1))
	await _esperar(60)
	_capturar("juego")
	# La pausa usa el mismo tema
	var pausa: Node = main.get_node("Pausa")
	pausa.pausar()
	await _esperar(10)
	_capturar("pausa")
	pausa.continuar()
	GameState.borrar_partida()
	print("capturas en ", ProjectSettings.globalize_path(carpeta))
	get_tree().quit()


func _esperar(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _esperar_segundos(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _capturar(nombre: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(carpeta.path_join(prefijo + nombre + ".png"))
