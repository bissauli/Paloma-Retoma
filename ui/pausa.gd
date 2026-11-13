extends CanvasLayer
## Menú de pausa (Esc): Continuar, Reiniciar y Salir al título.

const ESCENA_TITULO := "res://ui/titulo.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	%Continuar.pressed.connect(continuar)
	%Reiniciar.pressed.connect(_reiniciar)
	%Salir.pressed.connect(_salir)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa") and not GameState.partida_terminada:
		if visible:
			continuar()
		else:
			pausar()
		get_viewport().set_input_as_handled()


func pausar() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%Continuar.grab_focus()


func continuar() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _salir() -> void:
	get_tree().paused = false
	GameState.en_partida = false
	get_tree().change_scene_to_file(ESCENA_TITULO)
