extends Node3D
## Pantalla de título "Paloma Retoma": cartel, botones y barra de controles dibujados en pixel-art
## sobre la plaza en 3D, con una cámara que gira despacio y palomas picoteando abajo.
## Por delante cruzan palomas volando y cada tanto una se posa en JUGAR (ver ui/menu/palomas_menu.gd).
## Los grupos Arriba/Abajo/ArribaIzq/AbajoDer usan las coordenadas del diseño original (1376x768)
## y se escalan a la pantalla; cada uno queda pegado a su borde si la ventana no es 16:9.

const ESCENA_JUEGO := "res://main.tscn"
const ESC_PALOMA := preload("res://flock/paloma_npc.tscn")
const TEX_SONIDO := preload("res://ui/menu/btn_sonido.png")
const TEX_MUDO := preload("res://ui/menu/btn_sonido_mudo.png")
const AGRANDAR := 1.06      ## Escala del botón con el mouse encima o con foco
const TEXTO_AYUDA := "Sos una paloma flaca en la Plaza de Mayo. Comé migas, arrullá para sumar \
palomas a tu bandada y, cuando tengas 30, aterrizá en el balcón de la Casa Rosada.\n\n\
Cuidado con el nene, el mozo, los granaderos y el halcón.\n\n\
WASD caminar · Espacio volar y aletear · Shift picada\n\
Click izquierdo picotear · Click derecho arrullar · Esc pausa"

var _angulo := 0.0
var _opciones: OpcionesMenu
var _ayuda: VentanaMenu
var _aviso: PanelContainer

@onready var camara: Camera3D = $Camara
@onready var raiz: Control = $UI/Raiz
@onready var palomas: Node = $UI/Raiz/Palomas
@onready var botones: Array[BaseButton] = [%Jugar, %Cargar, %Opciones, %Salir, %Sonido, %Ayuda]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	GameState.en_partida = false
	for b in botones:
		_preparar_boton(b)
	%Jugar.pressed.connect(_jugar)
	%Jugar.mouse_entered.connect(Callable(palomas, "asustar"))  # la paloma posada se espanta
	%Cargar.pressed.connect(_proximamente)
	%Opciones.pressed.connect(_abrir.bind("opciones"))
	%Salir.pressed.connect(_salir)
	%Sonido.pressed.connect(_alternar_sonido)
	%Ayuda.pressed.connect(_abrir.bind("ayuda"))
	Ajustes.cambio.connect(_actualizar_sonido)
	_actualizar_sonido()
	_armar_ventanas()
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


# ---------------------------------------------------------------- Botones

func _preparar_boton(b: BaseButton) -> void:
	b.pivot_offset = b.size / 2.0
	b.mouse_entered.connect(b.grab_focus)
	b.focus_entered.connect(_resaltar.bind(b, true))
	b.focus_exited.connect(_resaltar.bind(b, false))
	b.button_down.connect(_escalar.bind(b, 0.96, 0.06))
	b.button_up.connect(func() -> void: _escalar(b, AGRANDAR if b.has_focus() else 1.0, 0.1))


func _resaltar(b: BaseButton, si: bool) -> void:
	_escalar(b, AGRANDAR if si else 1.0, 0.12)
	b.modulate = Color(1.08, 1.08, 1.08) if si else Color.WHITE


func _escalar(b: BaseButton, e: float, t: float) -> void:
	if b.has_meta("tween"):
		var viejo: Tween = b.get_meta("tween")
		if viejo and viejo.is_valid():
			viejo.kill()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(e, e), t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("tween", tw)


func _jugar() -> void:
	AudioManager.reproducir("arrullo")
	get_tree().change_scene_to_file(ESCENA_JUEGO)


func _salir() -> void:
	get_tree().quit()


func _alternar_sonido() -> void:
	Ajustes.set_silencio(not Ajustes.silencio)
	if not Ajustes.silencio:
		AudioManager.reproducir("picoteo")


func _actualizar_sonido() -> void:
	%Sonido.texture_normal = TEX_MUDO if Ajustes.silencio else TEX_SONIDO


## CARGAR todavía no existe: un cartelito arriba del botón.
func _proximamente() -> void:
	AudioManager.reproducir("picoteo")
	if _aviso == null:
		_aviso = PanelContainer.new()
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.13, 0.17, 0.26)
		estilo.border_color = Color(0.93, 0.66, 0.28)
		estilo.set_border_width_all(4)
		estilo.set_corner_radius_all(10)
		estilo.content_margin_left = 22
		estilo.content_margin_right = 22
		estilo.content_margin_top = 6
		estilo.content_margin_bottom = 8
		_aviso.add_theme_stylebox_override("panel", estilo)
		var l := Label.new()
		l.text = "Próximamente"
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
		l.add_theme_constant_override("outline_size", 6)
		_aviso.add_child(l)
		_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aviso.z_index = 10
		%Cargar.get_parent().add_child(_aviso)
	var cargar: Control = %Cargar
	_aviso.reset_size()
	var arriba := Vector2(cargar.position.x + (cargar.size.x - _aviso.size.x) / 2.0, cargar.position.y - _aviso.size.y - 14.0)
	_aviso.position = arriba + Vector2(0, 14)
	_aviso.modulate.a = 0.0
	if _aviso.has_meta("tween"):
		(_aviso.get_meta("tween") as Tween).kill()
	var tw := _aviso.create_tween()
	tw.set_parallel()
	tw.tween_property(_aviso, "modulate:a", 1.0, 0.15)
	tw.tween_property(_aviso, "position", arriba, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(_aviso, "modulate:a", 0.0, 0.4)
	_aviso.set_meta("tween", tw)


# ---------------------------------------------------------------- Ventanas

func _armar_ventanas() -> void:
	_opciones = OpcionesMenu.new()
	raiz.add_child(_opciones)
	_opciones.cerrada.connect(_al_cerrar.bind(%Opciones))

	_ayuda = VentanaMenu.new()
	_ayuda.armar("Cómo jugar")
	var texto := Label.new()
	texto.text = TEXTO_AYUDA
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(620, 0)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_font_size_override("font_size", 22)
	_ayuda.contenido.add_child(texto)
	raiz.add_child(_ayuda)
	_ayuda.cerrada.connect(_al_cerrar.bind(%Ayuda))


func _abrir(cual: String) -> void:
	AudioManager.reproducir("picoteo")
	for b in botones:
		b.focus_mode = Control.FOCUS_NONE
		_resaltar(b, false)
	(_opciones if cual == "opciones" else _ayuda).abrir()


func _al_cerrar(boton: BaseButton) -> void:
	for b in botones:
		b.focus_mode = Control.FOCUS_ALL
	boton.grab_focus()
