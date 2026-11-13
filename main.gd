extends Node3D
## Escena principal de juego: arranca la partida, el ambiente y detecta la victoria
## (posarse en el balcón de la Casa Rosada con 30 palomas o más).

const RADIO_BALCON := 3.4

var _jugador: PalomaJugador
var _balcon: Node3D
var _aviso_balcon := 0.0


func _ready() -> void:
	get_tree().paused = false
	GameState.reiniciar()
	AudioManager.iniciar_ambiente()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_jugador = $Paloma as PalomaJugador
	_buscar_balcon.call_deferred()


func _buscar_balcon() -> void:
	_balcon = get_tree().get_first_node_in_group("balcon") as Node3D


func _physics_process(delta: float) -> void:
	_aviso_balcon = maxf(_aviso_balcon - delta, 0.0)
	if GameState.partida_terminada or _balcon == null or _jugador == null:
		return
	if _jugador.estado != PalomaJugador.Estado.SUELO:
		return
	var d := _jugador.global_position - _balcon.global_position
	if absf(d.y) > 1.0 or Vector2(d.x, d.z).length() > RADIO_BALCON:
		return
	if GameState.bandada >= Config.UMBRAL_BALCON:
		GameState.ganar()
	elif _aviso_balcon <= 0.0:
		_aviso_balcon = 3.0
		GameState.mensaje.emit("Con %d palomas no alcanza... ¡necesitás %d para tomar el balcón!" % [
			GameState.bandada, Config.UMBRAL_BALCON], 3.0)
