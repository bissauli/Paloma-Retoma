class_name Arranque
extends Node
## Primera escena del juego. Muestra la pantalla de carga enseguida y recién después arma el juego
## (res://main.tscn: la ciudad entera, que tarda). Los recursos pesados se cargan en otro hilo mientras
## la pantalla se anima; armar la ciudad en sí no se puede repartir y deja la imagen quieta un rato.
## La pantalla se va cuando el menú principal ya está listo (señal Main.listo).

const JUEGO := "res://main.tscn"

var _carga: PantallaCarga


func _ready() -> void:
	add_to_group("arranque")
	# En la web el navegador no dibuja nada mientras el juego arma la ciudad (todo corre en un solo hilo),
	# así que la pantalla de carga es la de la página (ver html/head_include en export_presets.cfg),
	# que sigue animada sola. Acá sólo se le avisa cuándo irse.
	if not OS.has_feature("web"):
		_carga = PantallaCarga.crear(get_tree())
	# Dos cuadros para que la pantalla se vea antes de empezar el trabajo pesado
	await get_tree().process_frame
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(JUEGO)
	while ResourceLoader.load_threaded_get_status(JUEGO) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var escena := ResourceLoader.load_threaded_get(JUEGO) as PackedScene
	if escena == null:
		escena = load(JUEGO) as PackedScene
	await get_tree().process_frame
	var juego := escena.instantiate()
	# La pantalla de carga es independiente de esta escena: se va sola cuando main avisa que está listo
	if _carga:
		juego.connect(&"listo", _carga.ocultar, CONNECT_ONE_SHOT)
	else:
		juego.connect(&"listo", PantallaCarga.ocultar_web, CONNECT_ONE_SHOT)
	get_tree().root.add_child(juego)      # Acá se arma la ciudad (_ready de main)
	get_tree().current_scene = juego
	queue_free()
