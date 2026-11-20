extends Node3D
## Escena principal (es la que abre el juego). El mundo y la paloma de la jugadora ya están
## cargados detrás del menú principal: la cámara del menú muestra a la paloma en primer plano,
## sentada en un banco del Cabildo.
## Al elegir NUEVA PARTIDA o CONTINUAR, la paloma salta del banco al piso, el menú se va y la cámara
## se desengancha y vuela sin cortes hasta quedar detrás de la paloma (ver ui/menu/camara_menu.gd).
## Sin cambio de escena ni fundido a negro. En una partida nueva sigue el tutorial, que arranca con
## una cinemática (world/tutorial.gd): el control y el HUD vuelven cuando termina.
## También detecta la victoria (posarse en el balcón de la Casa Rosada con 30 palomas o más).

## Muestra el menú aunque la escena esté adentro de otra (lo usa tests/captura_menu.tscn).
@export var forzar_menu := false

const BUILDER_MAPA := "res://admin/builder_mapa.tscn"

var _jugador: PalomaJugador
var _balcon: Node3D
var _gestos: GestosPaloma
var _tutorial: Node

@onready var menu: MenuPrincipal = $MenuPrincipal
@onready var camara_menu: CamaraMenu = $CamaraMenu
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	get_tree().paused = false
	_jugador = $Paloma as PalomaJugador
	_tutorial = get_node_or_null("Tutorial")
	AudioManager.iniciar_ambiente()
	# Versión para teléfonos: joystick, botones y deslizar para mirar (se ocultan con el menú)
	if Ajustes.movil:
		var tactiles := ControlesTactiles.new()
		tactiles.name = "ControlesTactiles"
		tactiles.pausa = $Pausa
		add_child(tactiles)
	if not Ajustes.movil:
		var foto := ModoFoto.new()
		foto.name = "ModoFoto"
		add_child(foto)
	_buscar_balcon.call_deferred()
	# El menú sólo aparece cuando esta es la escena que se está jugando: las pruebas automáticas
	# instancian main.tscn adentro de otra escena y arrancan directo a jugar.
	var es_el_juego := get_tree().current_scene == self
	GameState.guardado_habilitado = es_el_juego
	# Las cinemáticas del tutorial, sólo en el juego de verdad (las pruebas manejan la cámara)
	if _tutorial:
		_tutorial.con_cinematicas = es_el_juego or forzar_menu
	if (es_el_juego or forzar_menu) and not GameState.saltar_menu:
		_abrir_menu()
	else:
		GameState.saltar_menu = false
		menu.queue_free()
		camara_menu.queue_free()
		_jugar_ya()


func _buscar_balcon() -> void:
	_balcon = get_tree().get_first_node_in_group("balcon") as Node3D


## Partida nueva sin menú (Reiniciar de la pausa y pruebas automáticas).
func _jugar_ya() -> void:
	GameState.menu_activo = false
	GameState.reiniciar()
	Ajustes.capturar_mouse(true)


# ---------------------------------------------------------------- Menú principal

func _abrir_menu() -> void:
	AvisoAccion.limpiar()
	GameState.menu_activo = true
	GameState.en_partida = false
	GameState.partida_terminada = false
	GameState.invulnerable = 1.0e9   # Mientras está el menú nadie molesta a la paloma
	GameState.fase_dia_cambio.emit(0.0)
	Ajustes.capturar_mouse(false)
	_jugador.controlable = false
	_jugador.camara.bloqueada = true
	hud.visible = false
	camara_menu.encuadrar(_jugador, _jugador.rumbo())
	_gestos = _jugador.modelo.agregar_gestos(camara_menu)
	# Que ninguna paloma suelta se cruce entre la cámara y la jugadora ni se le pegue al lado
	var frente := camara_menu.global_position - _jugador.global_position
	frente.y = 0.0
	($Bandada as Bandada).zona_libre = [_jugador.global_position,
		camara_menu.global_position + frente.normalized() * 0.6, 1.4]
	menu.preguntando.connect(func(si: bool) -> void:
		if is_instance_valid(_gestos):
			_gestos.preguntar(si))
	menu.nueva_partida.connect(_empezar.bind({}))
	menu.continuar.connect(_empezar)
	# Antes de mostrar el menú se compilan los shaders de toda la plaza (unos pocos cuadros), así
	# la transición al juego no se traba cuando la cámara se aleja y aparece el mundo entero
	var precalentar := PrecalentarShaders.new()
	add_child(precalentar)
	_jugador.camara.reubicar()
	precalentar.precalentar(_jugador, _jugador.camara.camara)
	await precalentar.terminado
	menu.mostrar()


## La paloma salta y la cámara pasa del menú al juego sin cortes.
## "datos" no vacío = continuar una partida guardada.
func _empezar(datos: Dictionary) -> void:
	_gestos.soltar_cabeza()
	($Bandada as Bandada).zona_libre = []
	GameState.reiniciar(datos)
	GameState.invulnerable = camara_menu.duracion   # Que nada la atrape durante la transición
	if not datos.is_empty():
		_restaurar(datos)
	# Con cinemática de entrada, el control y el HUD los devuelve el tutorial cuando termina
	var con_intro: bool = _tutorial != null and _tutorial.va_a_haber_intro()
	_jugador.saltar_inicio()
	_jugador.camara.bloqueada = false
	# La cámara del juego arranca un poco más alta: desde atrás del banco, el respaldo tapaba a la paloma
	_jugador.camara.pitch = -0.45
	_jugador.camara.reubicar()
	Ajustes.capturar_mouse(true)
	camara_menu.transicionar_a(_jugador.camara.camara)
	# El control vuelve un poco antes de que la cámara termine de acomodarse
	if not con_intro:
		get_tree().create_timer(camara_menu.duracion * 0.7).timeout.connect(func() -> void:
			_jugador.controlable = true)
	await camara_menu.transicion_terminada
	GameState.menu_activo = false
	if not con_intro:
		hud.mostrar()
	camara_menu.queue_free()


## Continuar: la bandada guardada vuelve volando y el día avanza hasta donde estaba.
func _restaurar(datos: Dictionary) -> void:
	($Bandada as Bandada).restaurar(int(datos.get("bandada", 0)))
	var fase := float(datos.get("progreso_dia", 0.0))
	if fase > 0.0:
		var tw := create_tween()
		tw.tween_method(func(t: float) -> void: GameState.fase_dia_cambio.emit(t), 0.0, fase,
			camara_menu.duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- Victoria

func _physics_process(delta: float) -> void:
	if GameState.partida_terminada or _balcon == null or _jugador == null:
		return
	if _jugador.estado != PalomaJugador.Estado.SUELO:
		return
	var d := _jugador.global_position - _balcon.global_position
	if absf(d.y) > 1.0 or Vector2(d.x, d.z).length() > Config.RADIO_BALCON:
		return
	if GameState.bandada >= Config.UMBRAL_BALCON:
		GameState.ganar()


## F2 abre el builder de mapa (admin/builder_mapa.tscn) mientras Config.BUILDER_ACTIVO sea true: arranca mirando
## donde estaba la jugadora. En el mapa final (Mapa v1.0) esa constante queda en false.
func _unhandled_key_input(event: InputEvent) -> void:
	if not Config.BUILDER_ACTIVO or not event.is_pressed() or event.is_echo():
		return
	if (event as InputEventKey).keycode == KEY_F2 and ResourceLoader.exists(BUILDER_MAPA):
		if is_instance_valid(_jugador) and _jugador.is_inside_tree():
			MapaOverrides.camara_inicial = _jugador.global_position
		get_tree().paused = false
		get_tree().change_scene_to_file(BUILDER_MAPA)
