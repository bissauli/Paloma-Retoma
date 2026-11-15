extends CanvasLayer
## Victoria: la cámara gira alrededor del balcón, la plaza se llena de palomas arrullando,
## aparece "¡LA PLAZA ES NUESTRA!" arriba a la derecha (como el título del menú principal, con la
## bandada y el tiempo en barras cyan) y después los créditos con nombres de palomas en una tarjeta,
## con el botón de volver al menú abajo a la derecha. Usa el mismo tema y las mismas cajas que
## el menú y el HUD (ver EstiloUI).

const ESCENA_MENU := "res://main.tscn"
const NOMBRES_FIJOS := ["Carlos", "La Tana", "El Ruso", "Coqui"]

@export var radio_camara := 20.0
@export var altura_camara := 9.0
@export var duracion_giro := 14.0

var _camara: Camera3D
var _centro := Vector3(39.9, 7.0, 0)
var _angulo := 0.0
var _activa := false
var _t_arrullo := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	visible = false
	GameState.victoria.connect(_al_ganar)
	%VolverTitulo.pressed.connect(func() -> void: get_tree().change_scene_to_file(ESCENA_MENU))


func _al_ganar() -> void:
	_activa = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var balcon := get_tree().get_first_node_in_group("balcon") as Node3D
	if balcon:
		_centro = balcon.global_position
	var j := GameState.jugador
	if j:
		j.controlable = false
		j.camara.bloqueada = true
	# Cámara propia para la cinemática
	_camara = Camera3D.new()
	_camara.fov = 60.0
	_camara.far = 400.0
	get_tree().current_scene.add_child(_camara)
	_angulo = 0.0  # Arranca justo enfrente del balcón
	_mover_camara()
	_camara.current = true
	AudioManager.reproducir("victoria", 0.0, false)

	# Título y estadísticas: bajan y se aclaran como el título del menú principal
	_armar_estadisticas()
	var titulo: Control = %Titulo
	var y_base := titulo.offset_top
	titulo.modulate.a = 0.0
	titulo.offset_top = y_base - 24.0
	titulo.offset_bottom -= 24.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.7)
	tw.parallel().tween_property(titulo, "offset_top", y_base, 0.9)
	tw.parallel().tween_property(titulo, "offset_bottom", titulo.offset_bottom + 24.0, 0.9)
	tw.tween_interval(4.5)
	tw.tween_callback(_mostrar_creditos)


## Dos barras como las del HUD: la bandada (cyan) y el tiempo jugado (oscura).
func _armar_estadisticas() -> void:
	var fila: HBoxContainer = %Estadisticas
	for h in fila.get_children():
		h.queue_free()
	_barra_estadistica(fila, EstiloUI.C_CYAN, str(GameState.bandada), "PALOMAS", true)
	var t := int(GameState.tiempo_jugado)
	_barra_estadistica(fila, EstiloUI.C_OSCURO, "%d:%02d" % [floori(t / 60.0), t % 60], "TIEMPO", false)


func _barra_estadistica(fila: Control, color: Color, valor: String, rotulo: String, con_borde: bool) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(color, 0.42, EstiloUI.C_CYAN_BORDE if con_borde else Color.TRANSPARENT))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(panel)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)
	EstiloUI.texto(caja, &"TituloPantalla", 56, valor)
	EstiloUI.texto(caja, &"Seccion", 20, rotulo)


## La cámara va y viene en arco por el lado de la plaza, mirando al balcón y a la bandada.
func _mover_camara() -> void:
	var foco := _centro + Vector3(-7.0, -3.0, 0)
	var a := PI + sin(_angulo) * 0.75
	_camara.global_position = foco + Vector3(cos(a), 0, sin(a)) * radio_camara + Vector3.UP * altura_camara
	_camara.look_at(foco)


func _process(delta: float) -> void:
	if not _activa:
		return
	_angulo += delta * TAU / duracion_giro
	_mover_camara()
	# Arrullos por todos lados
	_t_arrullo -= delta
	if _t_arrullo <= 0.0:
		_t_arrullo = randf_range(0.25, 0.7)
		AudioManager.reproducir("arrullo", randf_range(-12.0, -4.0))


func _mostrar_creditos() -> void:
	var nombres: Array[String] = []
	nombres.assign(NOMBRES_FIJOS)
	for n in get_tree().get_nodes_in_group("palomas_npc"):
		var p := n as PalomaNPC
		if p and not nombres.has(p.nombre):
			nombres.append(p.nombre)
		if nombres.size() >= 12:
			break
	var lineas: Array[String] = []
	for i in range(0, nombres.size(), 3):
		lineas.append("   ·   ".join(nombres.slice(i, i + 3)))
	(%Creditos as Label).text = "\n".join(lineas)
	(%Pie as Label).text = tr("y la paloma flaca que empezó todo") + "\n" \
		+ tr("Hecho con Godot para una game jam\nNinguna medialuna fue desperdiciada")
	var panel: Control = %PanelCreditos
	panel.visible = true
	panel.modulate.a = 0.0
	var botones: Control = %Botones
	botones.visible = true
	botones.modulate.a = 0.0
	botones.offset_left += 160.0
	botones.offset_right += 160.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.8)
	tw.tween_property(botones, "modulate:a", 1.0, 0.35).set_delay(0.5)
	tw.tween_property(botones, "offset_left", botones.offset_left - 160.0, 0.5).set_delay(0.5)
	tw.tween_property(botones, "offset_right", botones.offset_right - 160.0, 0.5).set_delay(0.5)
	%VolverTitulo.grab_focus()
