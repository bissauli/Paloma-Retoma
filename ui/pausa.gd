extends CanvasLayer
## Menú de pausa (Esc): Continuar, Reiniciar, Opciones (las mismas del título) y Salir al título.

const ESCENA_TITULO := "res://ui/titulo.tscn"

var _opciones: OpcionesMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	%Continuar.pressed.connect(continuar)
	%Reiniciar.pressed.connect(_reiniciar)
	%Salir.pressed.connect(_salir)
	%Opciones.pressed.connect(_abrir_opciones)
	_opciones = OpcionesMenu.new()
	add_child(_opciones)
	_opciones.cerrada.connect(func() -> void: %Opciones.grab_focus())


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
	_opciones.cerrar()
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


func _abrir_opciones() -> void:
	AudioManager.reproducir("picoteo")
	_opciones.abrir()
