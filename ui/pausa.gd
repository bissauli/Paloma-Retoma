extends CanvasLayer
## Menú de pausa (Esc): Continuar, Reiniciar, Opciones (las mismas del menú principal) y
## Salir al menú (guarda la partida para poder continuarla).

const ESCENA_MENU := "res://main.tscn"
const TEMA := preload("res://ui/tema/tema_paloma.tres")

var _opciones: OpcionesMenu
var _hud: CanvasLayer             ## El HUD, escondido mientras están las Opciones (null = no se escondió)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false
	($Centro as Control).theme = TEMA
	%Continuar.pressed.connect(continuar)
	%Reiniciar.pressed.connect(_reiniciar)
	%Salir.pressed.connect(_salir)
	%Opciones.pressed.connect(_abrir_opciones)
	_opciones = OpcionesMenu.new()
	add_child(_opciones)
	_opciones.cerrada.connect(_al_cerrar_opciones)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa") and not GameState.partida_terminada and not GameState.menu_activo:
		if visible:
			continuar()
		else:
			pausar()
		get_viewport().set_input_as_handled()


func pausar() -> void:
	visible = true
	($Centro as Control).visible = true
	get_tree().paused = true
	Ajustes.capturar_mouse(false)
	%Continuar.grab_focus()


func continuar() -> void:
	_opciones.cerrar()
	visible = false
	get_tree().paused = false
	Ajustes.capturar_mouse(true)


func _reiniciar() -> void:
	get_tree().paused = false
	GameState.saltar_menu = true   # Reiniciar arranca directo a jugar, sin el menú principal
	get_tree().reload_current_scene()


func _salir() -> void:
	GameState.guardar_partida()
	get_tree().paused = false
	GameState.en_partida = false
	get_tree().change_scene_to_file(ESCENA_MENU)


## Con las Opciones abiertas se esconden el título y los botones de la pausa y también el HUD (la
## misión y la brújula se leían encima de las opciones): queda sólo el fondo oscuro y las Opciones.
func _abrir_opciones() -> void:
	AudioManager.reproducir("picoteo")
	($Centro as Control).visible = false
	var hud := get_parent().get_node_or_null("HUD") as CanvasLayer
	if hud and hud.visible:
		_hud = hud
		hud.visible = false
	_opciones.abrir()


func _al_cerrar_opciones() -> void:
	($Centro as Control).visible = true
	if is_instance_valid(_hud):
		_hud.visible = true     # Sólo si lo escondimos nosotros (en una cinemática ya estaba escondido)
	_hud = null
	%Opciones.grab_focus()
