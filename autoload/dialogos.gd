extends Node
## Conversaciones con NPC (autoload "Dialogos"). Busca a qué NPC marcado (Interlocutor) tiene cerca
## la paloma, deja apretar E para hablar y recorre el diálogo nodo por nodo (datos en
## dialogos/catalogo_dialogos.gd, reglas en dialogos/reglas_dialogo.gd). No dibuja nada: la pantalla
## es ui/dialogo_ui.gd, que escucha las señales de acá. Mientras se habla la paloma queda quieta y
## nada la atrapa. Sólo se puede hablar parado en el piso y con el control de la paloma activo.

signal cercano_cambio(interlocutor: Interlocutor)      ## null = no hay nadie a quien hablarle
signal linea_cambio(quien: String, texto: String, opciones: Array)   ## opciones: textos de las visibles
signal terminado

const PERIODO_BUSQUEDA := 0.15

var activo := false
var cercano: Interlocutor
var _interlocutor: Interlocutor
var _dialogo: Dictionary = {}
var _nodo: Dictionary = {}
var _opciones: Array = []        ## Las opciones visibles del nodo actual (diccionarios del catálogo)
var _t_busqueda := 0.0
var _ui: DialogoUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ui = DialogoUI.new()
	add_child(_ui)


func _process(delta: float) -> void:
	if activo:
		GameState.invulnerable = maxf(GameState.invulnerable, 0.5)   # Nadie atrapa a quien está charlando
		return
	_t_busqueda -= delta
	if _t_busqueda <= 0.0:
		_t_busqueda = PERIODO_BUSQUEDA
		_buscar_cercano()


func _unhandled_input(event: InputEvent) -> void:
	if not activo and cercano != null and event.is_action_pressed("interactuar"):
		interactuar()
		get_viewport().set_input_as_handled()


## ¿Puede la jugadora iniciar una conversación ahora?
func puede_hablar() -> bool:
	var j := GameState.jugador
	return j != null and j.controlable and j.estado == PalomaJugador.Estado.SUELO \
		and GameState.en_partida and not GameState.partida_terminada and not GameState.menu_activo \
		and not get_tree().paused


func _buscar_cercano() -> void:
	var mejor: Interlocutor = null
	if puede_hablar():
		var pos := GameState.jugador.global_position
		var mejor_d := INF
		for n in get_tree().get_nodes_in_group("hablables"):
			var i := n as Interlocutor
			if i == null or not i.is_visible_in_tree() or CatalogoDialogos.elegir(i.personaje) == "":
				continue
			var d := Vector2(i.global_position.x - pos.x, i.global_position.z - pos.z).length()
			if d <= i.radio and absf(i.global_position.y - i.altura_marcador - pos.y) < 2.0 and d < mejor_d:
				mejor = i
				mejor_d = d
	if mejor != cercano:
		cercano = mejor
		cercano_cambio.emit(cercano)


## Empieza a hablar con el NPC que está cerca (lo llama la tecla E o tocar el aviso en pantalla).
func interactuar() -> void:
	if not activo and cercano != null:
		iniciar(cercano)


func iniciar(interlocutor: Interlocutor, id_dialogo := "") -> bool:
	if activo or not puede_hablar():
		return false
	if id_dialogo == "":
		id_dialogo = CatalogoDialogos.elegir(interlocutor.personaje)
	_dialogo = CatalogoDialogos.dialogo(id_dialogo)
	if _dialogo.is_empty():
		push_warning("Dialogos: no existe el diálogo '%s'" % id_dialogo)
		return false
	activo = true
	_interlocutor = interlocutor
	GameState.jugador.controlable = false
	Ajustes.capturar_mouse(false)
	cercano_cambio.emit(null)
	interlocutor.conversacion_iniciada.emit(GameState.jugador)
	_ir_a(String(_dialogo.get("inicio", "inicio")))
	return true


## Sigue con el nodo que viene después (cuando el nodo actual no tiene opciones).
func avanzar() -> void:
	if activo and _opciones.is_empty():
		_ir_a(String(_nodo.get("va", "")))


## Elige una de las opciones visibles (0 = la primera que se ve).
func elegir(indice: int) -> void:
	if not activo or indice < 0 or indice >= _opciones.size():
		return
	var opcion: Dictionary = _opciones[indice]
	ReglasDialogo.hacer(opcion.get("hace", []))
	_ir_a(String(opcion.get("va", "")))


func terminar() -> void:
	if not activo:
		return
	activo = false
	var i := _interlocutor
	_interlocutor = null
	_nodo = {}
	_opciones = []
	if GameState.jugador != null:
		GameState.jugador.controlable = true
	Ajustes.capturar_mouse(true)
	terminado.emit()
	if is_instance_valid(i):
		i.conversacion_terminada.emit()
		Misiones.notificar("hablar:" + i.personaje)   # Hablar con alguien también puede ser un objetivo
	_t_busqueda = 0.0


func _ir_a(id_nodo: String) -> void:
	var nodos: Dictionary = _dialogo.get("nodos", {})
	if id_nodo == "" or not nodos.has(id_nodo):
		terminar()
		return
	_nodo = nodos[id_nodo]
	ReglasDialogo.hacer(_nodo.get("hace", []))
	_opciones = []
	var textos: Array = []
	for o: Dictionary in _nodo.get("opciones", []):
		if ReglasDialogo.cumple(o.get("si", [])):
			_opciones.append(o)
			textos.append(String(o.get("texto", "")))
	var quien := String(_nodo.get("quien", _interlocutor.nombre() if _interlocutor else ""))
	linea_cambio.emit(quien, String(_nodo.get("texto", "")), textos)
