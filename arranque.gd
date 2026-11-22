class_name Arranque
extends Node
## Primera escena del juego. Muestra la pantalla de carga enseguida y arma el juego por detrás
## (res://main.tscn: la ciudad entera, que tarda): los recursos se cargan en otro hilo y el mundo se arma
## en otro hilo también, fuera de la escena, así la pantalla de carga sigue fluida todo el tiempo.
## Recién cuando está todo listo el juego entra a la escena; la pantalla se va cuando el menú principal
## ya está listo (señal Main.listo).

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
	var avance := []
	while ResourceLoader.load_threaded_get_status(JUEGO, avance) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _carga and not avance.is_empty():
			_carga.informar_recursos(avance[0])
		await get_tree().process_frame
	if _carga:
		_carga.empezar_armado()     # Desde acá la barra sigue al armado del mundo (ver PantallaCarga.informar_armado)
	var escena := ResourceLoader.load_threaded_get(JUEGO) as PackedScene
	if escena == null:
		escena = load(JUEGO) as PackedScene
	# El mundo (la plaza y la ciudad entera, lo que más tarda) se arma en otro hilo, fuera de la escena:
	# mientras tanto el hilo principal sólo dibuja la pantalla de carga, que sigue fluida.
	# En la web sin hilos se arma acá mismo (la pantalla de la página se anima sola igual).
	var juego: Node
	if OS.has_feature("web") and not OS.has_feature("threads"):
		juego = _armar(escena)
	else:
		var hilo := Thread.new()
		hilo.start(_armar.bind(escena), Thread.PRIORITY_NORMAL)
		while hilo.is_alive():
			await get_tree().process_frame
		juego = hilo.wait_to_finish()
	# Lo que sigue (entrar a la escena, compilar shaders) corre en el hilo principal: sin cambios de escena
	if _carga:
		_carga.fijar_escena()
	# La pantalla de carga es independiente de esta escena: se va sola cuando main avisa que está listo
	if _carga:
		juego.connect(&"listo", _carga.ocultar, CONNECT_ONE_SHOT)
	else:
		juego.connect(&"listo", PantallaCarga.ocultar_web, CONNECT_ONE_SHOT)
	get_tree().root.add_child(juego)      # El mundo ya está armado: acá entra a la escena (_ready de main)
	get_tree().current_scene = juego
	queue_free()


## Instancia el juego y arma la plaza con la ciudad, sin que nada entre todavía a la escena.
## Corre en otro hilo: no toca nada que ya esté en el árbol.
func _armar(escena: PackedScene) -> Node:
	var juego := escena.instantiate()
	var plaza := juego.get_node_or_null("Plaza")
	if plaza and plaza.has_method("construir"):
		plaza.construir()
	return juego
