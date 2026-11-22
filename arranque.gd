class_name Arranque
extends Node
## Primera escena del juego. Muestra la pantalla de carga enseguida y arma el juego por detrás
## (res://main.tscn: la ciudad entera, que tarda): los recursos se cargan en otro hilo y el mundo se arma
## en otro hilo también, fuera de la escena, así la pantalla de carga sigue fluida todo el tiempo.
## Recién cuando está todo listo el juego entra a la escena; la pantalla se va cuando el menú principal
## ya está listo (señal Main.listo).

const JUEGO := "res://main.tscn"

var _carga: PantallaCarga
var _hilo: Thread       ## El que arma el mundo (se espera siempre, aun si el juego se cierra a mitad de carga)


func _ready() -> void:
	add_to_group("arranque")
	# En la web el navegador no dibuja nada mientras el juego arma la ciudad (todo corre en un solo hilo),
	# así que la pantalla de carga es la de la página (ver html/head_include en export_presets.cfg),
	# que sigue animada sola. Acá sólo se le avisa cuándo irse.
	# Si el host no usó nuestra página (por ejemplo un portal que re-exporta con su propia plantilla),
	# no existe window.ocultarCarga y se usa la pantalla del propio juego.
	if not OS.has_feature("web") or not PantallaCarga.hay_pantalla_web():
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
	var juego: Node = null
	if _usar_hilos():
		_hilo = Thread.new()
		if _hilo.start(_armar.bind(escena), Thread.PRIORITY_NORMAL) == OK:
			while _hilo.is_alive():
				await get_tree().process_frame
			juego = _hilo.wait_to_finish()
		_hilo = null
	if juego == null:
		# Sin hilos (modo seguro) o el hilo no arrancó / falló: se arma acá mismo, como antes
		juego = _armar(escena)
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


## Si se cierra el juego (o se detiene desde el editor) mientras el hilo arma el mundo, hay que esperarlo:
## destruir un Thread en marcha cuelga o tumba el proceso.
func _exit_tree() -> void:
	if _hilo != null and _hilo.is_started():
		_hilo.wait_to_finish()
		_hilo = null


## ¿Se arma el mundo en otro hilo? Herramientas que manejan el juego desde afuera (como el agente Ziva del
## editor: capturas, árbol de escena en vivo, depuración) esperan un arranque determinista en un solo hilo.
## Se fuerza el modo sin hilos con cualquiera de estas opciones:
##   - argumento de línea de comandos:  --sin-hilos  (también vale después de "--")
##   - variable de entorno:             PALOMAS_SIN_HILOS=1
##   - ajuste del proyecto:             palomas/carga/sin_hilos = true
## En la web sin hilos (GitHub Pages) tampoco hay hilos.
func _usar_hilos() -> bool:
	if OS.has_feature("web") and not OS.has_feature("threads"):
		return false
	if "--sin-hilos" in OS.get_cmdline_args() or "--sin-hilos" in OS.get_cmdline_user_args():
		return false
	if OS.get_environment("PALOMAS_SIN_HILOS") in ["1", "true"]:
		return false
	return not bool(ProjectSettings.get_setting("palomas/carga/sin_hilos", false))


## Instancia el juego y arma la plaza con la ciudad, sin que nada entre todavía a la escena.
## Corre en otro hilo: no toca nada que ya esté en el árbol.
func _armar(escena: PackedScene) -> Node:
	var juego := escena.instantiate()
	var plaza := juego.get_node_or_null("Plaza")
	if plaza and plaza.has_method("construir"):
		plaza.construir()
	return juego
