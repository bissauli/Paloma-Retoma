extends Node
## Prueba automática de volver al menú principal (con ventana: el contorno del modo cómic no va
## headless si la calidad no lo deja, y lo que se mide es el juego de verdad):
## godot --path . res://tests/test_volver_menu.tscn
## Arranca como el juego (arranque.tscn: pantalla de carga y mundo armado en otro hilo), entra a una
## partida, sale al menú desde la pausa 5 veces seguidas y después gana y vuelve desde la victoria.
## Falla si sale cualquier error del motor o de un script, si una vuelta tarda de más o si las mallas
## que se agregan en partida se quedan sin el contorno de tinta.

const VUELTAS := 5
const SEGUNDOS_MAX := 60.0

var fallas := 0
var _errores := Contador.new()


class Contador extends Logger:
	var mutex := Mutex.new()
	var lista: PackedStringArray = []

	func _log_error(funcion: String, archivo: String, linea: int, codigo: String, explicacion: String,
			_editor_notify: bool, tipo: int, _trazas: Array[ScriptBacktrace]) -> void:
		if tipo == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		lista.append("%s %s:%d %s %s" % [funcion, archivo, linea, codigo, explicacion])
		mutex.unlock()

	func cantidad() -> int:
		mutex.lock()
		var c := lista.size()
		mutex.unlock()
		return c


func _ready() -> void:
	OS.add_logger(_errores)
	GameState.archivo_partida = "user://prueba_volver_menu.cfg"   # No toca la partida del jugador
	_arrancar.call_deferred()
	var main := await _esperar_menu("arranque")
	if main == null:
		return _terminar()
	_check("el arranque no tira errores", _errores.cantidad() == 0)
	for v in VUELTAS:
		main = await _vuelta_desde_pausa(main, v + 1)
		if main == null:
			return _terminar()
	await _entrar_a_partida(main)
	var victoria: Node = main.get_node("Victoria")
	GameState.ganar()
	for i in 30:
		await get_tree().process_frame
	var antes := _errores.cantidad()
	var t := Time.get_ticks_msec()
	(victoria.get_node("%VolverTitulo") as Button).pressed.emit()
	main = await _esperar_menu("victoria", main)
	if main:
		print("  vuelta desde la victoria: %.1f s" % ((Time.get_ticks_msec() - t) / 1000.0))
		_check("volver desde la victoria no tira errores", _errores.cantidad() == antes)
	_terminar()


## Como al abrir el juego: arranque.tscn pasa a ser la escena actual (main.gd lo mira para abrir el menú).
func _arrancar() -> void:
	var arranque: Node = (load("res://arranque.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(arranque)
	get_tree().current_scene = arranque


func _vuelta_desde_pausa(main: Node, n: int) -> Node:
	await _entrar_a_partida(main)
	_check("vuelta %d: el contorno se pone en las mallas que se agregan en partida" % n,
		await _contorno_en_malla_nueva(main))
	var pausa: Node = main.get_node("Pausa")
	pausa.pausar()
	await get_tree().process_frame
	var antes := _errores.cantidad()
	var t := Time.get_ticks_msec()
	pausa._salir()
	var nuevo := await _esperar_menu("vuelta %d" % n, main)
	if nuevo:
		print("  vuelta %d: %.1f s" % [n, (Time.get_ticks_msec() - t) / 1000.0])
		_check("vuelta %d: volver al menú no tira errores" % n, _errores.cantidad() == antes)
	return nuevo


func _entrar_a_partida(main: Node) -> void:
	var menu := main.menu as MenuPrincipal
	menu.botones[1].pressed.emit()   # NUEVA PARTIDA
	await get_tree().process_frame
	if menu._confirmar.visible:      # Con partida guardada pregunta antes de pisarla: se confirma
		menu._confirmar.confirmada.emit()
	for i in 240:
		await get_tree().process_frame
	_check("en partida", GameState.en_partida)


## Agrega una malla como las de la gente o los accesorios (material propio, con volumen) y mira que
## le pongan el contorno; también que una agregada y liberada en el mismo cuadro no rompa nada.
func _contorno_en_malla_nueva(main: Node) -> bool:
	if not Ajustes.contorno_comic():
		print("  (contorno apagado en estas opciones: no se revisa)")
		return true
	var mi := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.material = StandardMaterial3D.new()
	main.add_child(mi)
	mi.mesh = caja      # Después del add_child, como hacen muchos armados
	mi.position = Vector3(0, 2, 0)
	for i in 50:
		var efimera := MeshInstance3D.new()
		main.add_child(efimera)
		efimera.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := mi.material_overlay != null
	# Y las de la escena: las palomas y la gente que andan sueltas también lo tienen
	var con := EstiloComic.mallas_con_contorno()
	print("  mallas con contorno en la escena: %d" % con)
	mi.queue_free()
	return ok and con > 0


## Espera a que haya un main nuevo (distinto de "viejo") con el menú abierto y su señal "listo".
func _esperar_menu(nombre: String, viejo: Node = null) -> Node:
	var limite := Time.get_ticks_msec() + int(SEGUNDOS_MAX * 1000.0)
	var id_viejo := viejo.get_instance_id() if viejo else 0
	while Time.get_ticks_msec() < limite:
		await get_tree().process_frame
		var actual := get_tree().current_scene
		if actual == null or actual.get_instance_id() == id_viejo or actual.name != "Main" or not GameState.menu_activo:
			continue
		var menu := actual.get_node_or_null("MenuPrincipal")
		if menu and menu.visible:
			for i in 30:
				await get_tree().process_frame
			return actual
	_check("%s: el menú aparece en menos de %d s" % [nombre, SEGUNDOS_MAX], false)
	return null


func _terminar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.archivo_partida))
	for e in _errores.lista.slice(0, 20):
		print("  ERROR: ", e)
	print("Errores en total: %d" % _errores.cantidad())
	_check("ningún error del motor ni de scripts en toda la prueba", _errores.cantidad() == 0)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
