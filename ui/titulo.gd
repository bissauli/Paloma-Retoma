extends Node3D
## Pantalla de título: "Palomas de Mayo" con Jugar y Salir.
## De fondo, la plaza en 3D con una cámara que gira despacio y algunas palomas picoteando.

const ESCENA_JUEGO := "res://main.tscn"
const ESC_PALOMA := preload("res://flock/paloma_npc.tscn")

var _angulo := 0.0

@onready var camara: Camera3D = $Camara


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.en_partida = false
	%Jugar.pressed.connect(_jugar)
	%Salir.pressed.connect(_salir)
	%Jugar.grab_focus()
	# Luz de media mañana para el fondo
	GameState.fase_dia_cambio.emit(0.3)
	# Unas palomas paseando alrededor de la Pirámide
	for i in 14:
		var p := ESC_PALOMA.instantiate() as PalomaNPC
		p.randomizar_colores()
		add_child(p)
		var a := randf() * TAU
		p.global_position = Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 12.0)
		p.configurar_zona(Vector3.ZERO, 12.0)
	_mover_camara()
	AudioManager.iniciar_ambiente()


func _process(delta: float) -> void:
	_angulo += delta * 0.05
	_mover_camara()


func _mover_camara() -> void:
	var r := 22.0
	camara.global_position = Vector3(cos(_angulo) * r, 6.0 + sin(_angulo * 2.0), sin(_angulo) * r)
	camara.look_at(Vector3(0, 6.5, 0))


func _jugar() -> void:
	AudioManager.reproducir("arrullo")
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _salir() -> void:
	get_tree().quit()
