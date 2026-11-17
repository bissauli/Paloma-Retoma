extends Node3D
## El NIDO en la Pirámide de Mayo: muestra el tamaño de la bandada
## y recibe la comida pesada que trae la paloma.

var _cartel: Label3D
var _cartel_comida: Label3D
var _pulso := 0.0


func _ready() -> void:
	add_to_group("nido")
	GameState.posicion_nido = global_position
	_cartel = Label3D.new()
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel.font_size = 160
	_cartel.pixel_size = 0.01
	_cartel.outline_size = 28
	_cartel.modulate = Color.WHITE
	_cartel.outline_modulate = Color(0.35, 0.25, 0.45)
	_cartel.position = Vector3(0, 16.0, 0)
	add_child(_cartel)
	_cartel_comida = Label3D.new()
	_cartel_comida.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel_comida.font_size = 72
	_cartel_comida.pixel_size = 0.01
	_cartel_comida.outline_size = 16
	_cartel_comida.position = Vector3(0, 14.6, 0)
	add_child(_cartel_comida)
	GameState.bandada_cambio.connect(_al_cambiar_bandada)
	GameState.comida_cambio.connect(_al_cambiar_comida)
	GameState.partida_iniciada.connect(_al_iniciar)
	# En la pantalla de título no se muestran los carteles
	_cartel.visible = GameState.en_partida
	_cartel_comida.visible = GameState.en_partida
	_al_cambiar_bandada(GameState.bandada)
	_al_cambiar_comida(GameState.comida)


func _al_iniciar() -> void:
	GameState.posicion_nido = global_position
	_cartel.visible = true
	_cartel_comida.visible = true


func _al_cambiar_bandada(n: int) -> void:
	_cartel.text = "🕊 x %d" % n
	_pulso = 1.0


func _al_cambiar_comida(n: int) -> void:
	_cartel_comida.text = tr("NIDO · comida %d") % n


func _process(delta: float) -> void:
	if _pulso > 0.0:
		_pulso = maxf(_pulso - delta * 2.0, 0.0)
		_cartel.scale = Vector3.ONE * (1.0 + 0.3 * sin(_pulso * PI))


func _physics_process(_delta: float) -> void:
	if GameState.carga == "" or GameState.carga == "asado":   # El asado es de Tío Ruffus, no del nido
		return
	var j := GameState.jugador
	if j == null:
		return
	var d := Vector2(j.global_position.x - global_position.x, j.global_position.z - global_position.z).length()
	if d < Config.RADIO_NIDO and j.global_position.y < global_position.y + 6.0:
		var tipo := GameState.carga
		var valor: int = Comida.VALORES.get(tipo, 2)
		GameState.set_carga("")
		GameState.sumar_comida(valor)
		Logros.sumar("entregas")
		AudioManager.ui("currency", -4.0)
