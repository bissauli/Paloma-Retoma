extends Node3D
## Tutorial integrado (~30 s) en el Cabildo: un cartel flotante que va cambiando
## a medida que la jugadora hace cada cosa. Si se va lejos, el tutorial se da por terminado.

const PASOS := [
	"¡Hola, paloma flaca!\nCaminá con WASD y mirá con el mouse",
	"Picoteá las migas con CLICK IZQUIERDO\n(te dan stamina y comida)",
	"ESPACIO para despegar\nMantenelo apretado para subir",
	"En el aire, SHIFT para tirarte en picada\n¡Soltalo y salís disparada para arriba!",
	"CLICK DERECHO cerca de otras palomas para arrullar\nCada paloma que se suma cuesta 1 de comida",
	"¡Bien! Ahora andá a la Catedral (al norte)\na reclutar más palomas",
]

var paso := 0
var _cartel: Label3D
var _jugador: PalomaJugador
var _inicio := Vector3.ZERO
var _t := 0.0
var _t_paso := 0.0
var _terminado := false
var _espera_suelo := 0.0


func _ready() -> void:
	_cartel = Label3D.new()
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel.font_size = 56
	_cartel.pixel_size = 0.0032
	_cartel.outline_size = 14
	_cartel.modulate = Color("fffaf0")
	_cartel.outline_modulate = Color(0.3, 0.2, 0.4)
	_cartel.no_depth_test = true
	_cartel.render_priority = 5
	add_child(_cartel)
	_cartel.visible = false


## Arranca cuando ya hay partida (con el menú principal en pantalla todavía no la hay) y, después
## del saltito del menú, cuando la paloma vuelve a apoyarse (o a los 3 s).
func _intentar_empezar(delta: float) -> void:
	if not GameState.en_partida or GameState.menu_activo:
		return
	if GameState.tutorial_hecho:
		_terminado = true
		queue_free()   # Partida continuada: el tutorial ya se hizo
		return
	var j := get_tree().get_first_node_in_group("jugador") as PalomaJugador
	if j == null:
		return
	_espera_suelo += delta
	if j.estado != PalomaJugador.Estado.SUELO and _espera_suelo < 3.0:
		return
	_jugador = j
	_inicio = j.global_position
	_cartel.visible = true
	_mostrar(0)


func _mostrar(n: int) -> void:
	paso = n
	_t_paso = 0.0
	_cartel.text = PASOS[n]
	_cartel.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_cartel, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.reproducir("recoger", -10.0, false)


func _process(delta: float) -> void:
	if _terminado:
		return
	if _jugador == null:
		_intentar_empezar(delta)
		return
	_t += delta
	_t_paso += delta
	# El cartel flota un poco por delante y arriba de la paloma
	var objetivo := _jugador.global_position + Vector3(0, 1.9 + sin(_t * 2.0) * 0.05, 0)
	_cartel.global_position = _cartel.global_position.lerp(objetivo, minf(delta * 4.0, 1.0)) if _t > 0.1 else objetivo

	# Si se aleja mucho del Cabildo, terminamos el tutorial
	if _jugador.global_position.distance_to(_inicio) > 32.0 and paso < 5:
		_terminar()
		return
	match paso:
		0:
			if _jugador.global_position.distance_to(_inicio) > 2.0 or _t_paso > 8.0:
				_mostrar(1)
		1:
			if GameState.migas_comidas >= 2 or GameState.comida >= 3 or _t_paso > 15.0:
				_mostrar(2)
		2:
			if _jugador.estado == PalomaJugador.Estado.AIRE and _t_paso > 0.5:
				_mostrar(3)
		3:
			if _jugador.en_picada or _t_paso > 9.0:
				_mostrar(4)
		4:
			if GameState.bandada >= 1 or _t_paso > 14.0:
				_mostrar(5)
		5:
			if _t_paso > 6.0:
				_terminar()


func _terminar() -> void:
	_terminado = true
	GameState.tutorial_hecho = true
	GameState.actualizar_objetivo()
	var tw := create_tween()
	tw.tween_property(_cartel, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_cartel, "outline_modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
