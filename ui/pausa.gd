extends CanvasLayer
## Menú de pausa (Esc): Continuar, Reiniciar, Opciones (las mismas del menú principal) y
## Salir al menú (guarda la partida para poder continuarla).

const ESCENA_MENU := "res://main.tscn"
const TEMA := preload("res://ui/tema/tema_paloma.tres")

var _opciones: OpcionesMenu
var _diario: DiarioMisiones
var _album: PantallaAlbum
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
	_opciones.cerrada.connect(_al_cerrar_pantalla.bind(%Opciones))
	_diario = DiarioMisiones.new()
	add_child(_diario)
	_diario.cerrada.connect(_al_cerrar_pantalla.bind(%Misiones))
	%Misiones.pressed.connect(_abrir_diario)
	_album = PantallaAlbum.new()
	add_child(_album)
	_album.cerrada.connect(_al_cerrar_pantalla.bind(%Album))
	%Album.pressed.connect(_abrir_album)
	if not Ajustes.movil:
		_armar_controles()


## Las acciones que se muestran en el panel de controles: [acción(es), texto].
const CONTROLES := [
	[["mover_adelante", "mover_izquierda", "mover_atras", "mover_derecha"], "MOVERSE"],
	[["volar"], "VOLAR"],
	[["picada"], "PICADA"],
	[["picotear"], "PICOTEAR"],
	[["arrullar"], "ARRULLAR"],
	[["aletazo"], "ALETAZO"],
	[["descansar"], "DESCANSAR"],
	[["interactuar"], "INTERACTUAR"],
	[["emotes"], "BAILES"],
	[["foto"], "MODO CÁMARA"],
	[["pausa"], "PAUSA"],
]

var _controles: PanelContainer


## El panel de la izquierda con las teclas del juego, en el mismo estilo que el aviso de acciones.
func _armar_controles() -> void:
	_controles = PanelContainer.new()
	_controles.theme = TEMA
	_controles.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 0)
	_controles.grow_vertical = Control.GROW_DIRECTION_BOTH
	var estilo := EstiloUI.caja(EstiloUI.C_OSCURO, -0.12, EstiloUI.C_CYAN_BORDE)
	estilo.content_margin_top = 14
	estilo.content_margin_bottom = 14
	estilo.content_margin_left = 30
	estilo.content_margin_right = 36
	_controles.add_theme_stylebox_override("panel", estilo)
	add_child(_controles)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	_controles.add_child(v)
	var titulo := EstiloUI.texto(v, &"Seccion", 20, tr("CONTROLES"))
	titulo.add_theme_color_override("font_color", Color.WHITE)
	for c: Array in CONTROLES:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		v.add_child(fila)
		var chapa := PanelContainer.new()
		chapa.custom_minimum_size = Vector2(128, 0)
		var e := EstiloUI.caja(Color(0.88, 0.97, 1.0, 0.95), 0.25)
		e.content_margin_left = 8
		e.content_margin_right = 8
		e.content_margin_top = 0
		e.content_margin_bottom = 0
		e.shadow_size = 0
		chapa.add_theme_stylebox_override("panel", e)
		fila.add_child(chapa)
		var t := EstiloUI.texto(chapa, &"Etiqueta", 14, _teclas(c[0]))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_color_override("font_color", Color(0.02, 0.1, 0.16))
		var d := EstiloUI.texto(fila, &"Etiqueta", 14, tr(String(c[1])))
		d.add_theme_color_override("font_color", Color.WHITE)
	_controles.visible = false


## El texto de las teclas de una o varias acciones (la primera tecla o botón de mouse de cada una).
func _teclas(acciones: Array) -> String:
	var partes: PackedStringArray = []
	for a: String in acciones:
		if not InputMap.has_action(a):
			continue
		for ev in InputMap.action_get_events(a):
			var texto := ""
			if ev is InputEventKey:
				var k := ev as InputEventKey
				var kc := DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode) if k.physical_keycode != 0 else k.keycode
				texto = OS.get_keycode_string(kc).to_upper()
				if texto == "SPACE":
					texto = tr("ESPACIO")
				elif texto == "ESCAPE":
					texto = "ESC"
			elif ev is InputEventMouseButton:
				match (ev as InputEventMouseButton).button_index:
					MOUSE_BUTTON_LEFT: texto = tr("CLICK IZQ.")
					MOUSE_BUTTON_RIGHT: texto = tr("CLICK DER.")
					_: texto = tr("MOUSE")
			if texto != "":
				partes.append(texto)
				break
	return " ".join(partes)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausa") and not GameState.partida_terminada and not GameState.menu_activo:
		if visible:
			continuar()
		else:
			pausar()
		get_viewport().set_input_as_handled()


func pausar() -> void:
	AudioManager.ui("pause", -4.0)
	visible = true
	($Centro as Control).visible = true
	if _controles:
		_controles.visible = true
	get_tree().paused = true
	Ajustes.capturar_mouse(false)
	%Continuar.grab_focus()


func continuar() -> void:
	AudioManager.ui("unpause", -4.0)
	_opciones.cerrar()
	_diario.cerrar()
	_album.cerrar()
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
	AvisoAccion.limpiar()
	get_tree().change_scene_to_file(ESCENA_MENU)


func _abrir_opciones() -> void:
	_abrir_pantalla(_opciones)


func _abrir_album() -> void:
	_album.refrescar()
	_abrir_pantalla(_album)


func _abrir_diario() -> void:
	_diario.refrescar()
	_abrir_pantalla(_diario)


## Con una pantalla abierta (Opciones, Misiones) se esconden el título y los botones de la pausa y
## también el HUD (la misión y la brújula se leían encima): queda sólo el fondo oscuro y la pantalla.
func _abrir_pantalla(pantalla: PantallaMenu) -> void:
	AudioManager.ui("menu_open", -6.0)
	($Centro as Control).visible = false
	if _controles:
		_controles.visible = false
	var hud := get_parent().get_node_or_null("HUD") as CanvasLayer
	if hud and hud.visible:
		_hud = hud
		hud.visible = false
	pantalla.abrir()


func _al_cerrar_pantalla(boton: Button) -> void:
	($Centro as Control).visible = true
	if _controles:
		_controles.visible = true
	if is_instance_valid(_hud):
		_hud.visible = true     # Sólo si lo escondimos nosotros (en una cinemática ya estaba escondido)
	_hud = null
	boton.grab_focus()
