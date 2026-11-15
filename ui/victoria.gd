extends CanvasLayer
## Victoria: la cámara gira alrededor del balcón, la plaza se llena de palomas arrullando,
## aparece "¡LA PLAZA ES NUESTRA!" y después los créditos con nombres de palomas.

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

	# Texto grande
	var titulo: Label = %Titulo
	titulo.modulate.a = 0.0
	titulo.scale = Vector2.ONE * 0.3
	titulo.pivot_offset = titulo.size / 2.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(titulo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_callback(_mostrar_creditos)


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
		if nombres.size() >= 18:
			break
	var texto := "LA BANDADA\n\n"
	for i in nombres.size():
		texto += nombres[i] + ("\n" if i % 3 == 2 else "   ·   ")
	texto += "\n\ny la paloma flaca que empezó todo\n\n"
	texto += "Hecho con Godot para una game jam\nNinguna medialuna fue desperdiciada"
	var creditos: Label = %Creditos
	creditos.text = texto
	var titulo: Label = %Titulo
	create_tween().tween_property(titulo, "scale", Vector2.ONE * 0.6, 0.8)
	var panel: Control = %PanelCreditos
	panel.visible = true
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 1.0)
	%VolverTitulo.grab_focus()
