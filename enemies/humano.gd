class_name Humano
extends Node3D
## Humano "pasivo": turistas, escolares, señoras y oficinistas.
## - turista/escolar: pasea por su zona y tira migas; con 15+ palomas se asusta y suelta comida.
## - senora: sentada en un banco, tira migas cada tanto (zona segura).
## - oficinista: sale del subte, camina hasta el borde del mapa y a veces se le cae una factura.
## - comensal: llega por la vereda de los cafés, se sienta a una mesa, come un rato (se le caen
##   migas) y se va. Los maneja enemies/gente.gd, que reparte las sillas.

signal se_levanto

@export_enum("turista", "escolar", "senora", "oficinista", "comensal") var tipo := "turista"
@export var velocidad := 1.1
@export var intervalo_migas := 6.0

var zona_centro := Vector3.ZERO
var zona_radio := 5.0
var generador: GeneradorMigas       ## A dónde van las migas que tira (lo asigna la escena)
var destino_final := Vector3.ZERO   ## Para oficinistas: a dónde va antes de desaparecer

var _destino := Vector3.ZERO
var _timer_paseo := 0.0
var _timer_migas := 0.0
var _miedo := 0.0
var _enfriamiento_susto := 0.0
var _rumbo := 0.0
var _vel := Vector3.ZERO
var _soltar_factura_en := -1.0
var _altura := 0.0

# Comensales
var ruta: Array[Vector3] = []       ## Puntos por los que camina (el último es la silla o la salida)
var asiento := Vector3.ZERO
var lado := 1.0                     ## De qué lado de la mesa está la silla (-1 oeste, +1 este)
var salida := Vector3.ZERO
var tiempo_comida := 30.0
var _comiendo := false
var _timer_bocado := 2.0

@onready var modelo: ModeloHumano = $Modelo


func _ready() -> void:
	add_to_group("humanos")
	_timer_migas = randf() * intervalo_migas
	_destino = global_position
	_altura = global_position.y
	_rumbo = rotation.y
	rotation = Vector3.ZERO
	if tipo == "oficinista":
		_destino = destino_final
		velocidad = randf_range(1.6, 2.1)
		if randf() < 0.55:
			_soltar_factura_en = randf_range(3.0, 9.0)


## Configura el aspecto según el tipo (llamar antes de agregarlo al árbol).
func preparar_aspecto() -> void:
	var m := get_node("Modelo") as ModeloHumano
	var paleta := [Color("4f7cc4"), Color("d9643a"), Color("5aa469"), Color("e3c34b"), Color("9c5fb5"), Color("e07aa0")]
	match tipo:
		"turista":
			m.color_ropa = paleta[randi() % paleta.size()]
			m.accesorio = "sombrero" if randf() < 0.4 else "gorra"
			m.color_accesorio = Color("f2e6c9") if m.accesorio == "sombrero" else paleta[randi() % paleta.size()]
		"escolar":
			m.alto = randf_range(1.1, 1.3)
			m.color_ropa = Color("f4f4f4")  # Guardapolvo blanco
			m.color_piernas = Color("2d3a5c")
		"senora":
			m.sentado = true
			m.alto = 1.6
			m.color_ropa = [Color("7a4b6b"), Color("4b6b7a"), Color("8a7255")][randi() % 3]
			m.color_piel = Color("e8c4a6")
			m.accesorio = "sombrero" if randf() < 0.5 else "ninguno"
			m.color_accesorio = Color("5b3b52")
		"oficinista":
			m.color_ropa = [Color("2f3540"), Color("4a4f5a"), Color("596b80")][randi() % 3]
			m.color_piernas = Color("22252b")
		"comensal":
			m.alto = randf_range(1.6, 1.85)
			m.color_ropa = (paleta + [Color("7a4b6b"), Color("2f3540"), Color("c9b48a")])[randi() % 9]
			m.color_piernas = [Color("3a3f4a"), Color("2d3a5c"), Color("5a4a3a")][randi() % 3]
			if randf() < 0.25:
				m.accesorio = "sombrero"
				m.color_accesorio = Color("f2e6c9")
	m.color_piel = m.color_piel.darkened(randf_range(-0.1, 0.35))


func _physics_process(delta: float) -> void:
	_enfriamiento_susto = maxf(_enfriamiento_susto - delta, 0.0)
	match tipo:
		"senora":
			_tirar_migas(delta)
			modelo.animar(delta, 0.0)
			modelo.rotation.y = _rumbo
			return
		"oficinista":
			_paso_oficinista(delta)
		"comensal":
			if _comiendo:
				_paso_comer(delta)
				modelo.rotation.y = _rumbo
				modelo.animar(delta, 0.0)
				return
			_paso_ruta(delta)
		_:
			_revisar_susto()
			_pasear(delta)
			_tirar_migas(delta)
	global_position += _vel * delta
	global_position.y = _altura
	if Vector2(_vel.x, _vel.z).length() > 0.1:
		_rumbo = lerp_angle(_rumbo, atan2(-_vel.x, -_vel.z), minf(delta * 6.0, 1.0))
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), _miedo > 0.0)


func _pasear(delta: float) -> void:
	if _miedo > 0.0:
		_miedo -= delta
		return  # Mientras huye mantiene la velocidad
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(2.5, 7.0)
		var a := randf() * TAU
		_destino = zona_centro + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * zona_radio
		if randf() < 0.4:
			_destino = global_position
	var hacia := _destino - global_position
	hacia.y = 0
	var v := Vector3.ZERO if hacia.length() < 0.3 else hacia.normalized() * velocidad
	_vel = _vel.lerp(v, minf(delta * 3.0, 1.0))


func _tirar_migas(delta: float) -> void:
	if generador == null or _miedo > 0.0:
		return
	_timer_migas -= delta
	if _timer_migas <= 0.0:
		_timer_migas = intervalo_migas * randf_range(0.6, 1.4)
		modelo.gesto_tirar()
		generador.tirar(modelo.posicion_mano())


## Con una bandada de 15 o más, los turistas (y escolares) salen corriendo y sueltan comida.
func _revisar_susto() -> void:
	if _miedo > 0.0 or _enfriamiento_susto > 0.0 or GameState.bandada < Config.UMBRAL_TURISTAS:
		return
	var j := get_tree().get_first_node_in_group("jugador") as Node3D
	if j == null or j.global_position.distance_to(global_position) > 5.5:
		return
	asustar(j.global_position)
	# Suelta algo rico
	if randf() < 0.75:
		var c := Comida.new()
		c.tipo = "papa" if randf() < 0.5 else "factura"
		c.reaparece = false
		c.vida = 45.0
		get_parent().add_child(c)
		c.global_position = Vector3(global_position.x, 0.02, global_position.z)
	GameState.mensaje.emit("¡Los turistas huyen de tu bandada y se les cae la comida!", 2.5)


func asustar(desde: Vector3) -> void:
	_miedo = 3.0
	_enfriamiento_susto = 25.0
	var lejos := global_position - desde
	lejos.y = 0
	_vel = lejos.normalized() * velocidad * 3.5
	AudioManager.reproducir_en("grito_nene", global_position, -8.0)


func _paso_oficinista(delta: float) -> void:
	var hacia := destino_final - global_position
	hacia.y = 0
	if hacia.length() < 1.0:
		queue_free()
		return
	_vel = _vel.lerp(hacia.normalized() * velocidad, minf(delta * 3.0, 1.0))
	if _soltar_factura_en > 0.0:
		_soltar_factura_en -= delta
		if _soltar_factura_en <= 0.0:
			var c := Comida.new()
			c.tipo = "factura"
			c.reaparece = false
			c.vida = 40.0
			get_parent().add_child(c)
			c.global_position = Vector3(global_position.x, 0.02, global_position.z)


# ---------------------------------------------------------------- Comensales

## Camina por la ruta; al llegar a la silla se sienta, y al llegar a la salida desaparece.
func _paso_ruta(delta: float) -> void:
	if ruta.is_empty():
		queue_free()
		return
	var hacia := ruta[0] - global_position
	hacia.y = 0
	if hacia.length() < 0.15:
		ruta.pop_front()
		if ruta.is_empty():
			if tiempo_comida > 0.0:
				_sentarse()
			else:
				queue_free()
		return
	var v := hacia.normalized() * velocidad
	if hacia.length() < 0.6:
		v *= maxf(hacia.length() / 0.6, 0.35)
	_vel = _vel.lerp(v, minf(delta * 5.0, 1.0))


## Se sienta mirando la mesa (la silla está a "lado" de la mesa).
func comenzar_sentado() -> void:
	global_position = asiento
	_sentarse()


func _sentarse() -> void:
	_comiendo = true
	_vel = Vector3.ZERO
	global_position = asiento
	_rumbo = lado * PI / 2.0
	modelo.cambiar_postura(true)
	_timer_bocado = randf_range(1.0, 3.0)


func _paso_comer(delta: float) -> void:
	tiempo_comida -= delta
	_timer_bocado -= delta
	if _timer_bocado <= 0.0 and tiempo_comida > 1.0:
		_timer_bocado = randf_range(2.5, 5.5)
		modelo.gesto_comer()
		# A veces se le cae una miga al piso (las palomas lo saben...)
		if randf() < 0.3:
			var c := Comida.new()
			c.tipo = "miga"
			c.reaparece = false
			c.vida = 45.0
			get_parent().add_child(c)
			c.global_position = Vector3(asiento.x - lado * randf_range(0.2, 0.5), asiento.y + 0.01,
				asiento.z + randf_range(-0.45, 0.45))
	if tiempo_comida <= 0.0:
		_levantarse()


func _levantarse() -> void:
	_comiendo = false
	tiempo_comida = 0.0
	modelo.cambiar_postura(false)
	ruta = [Vector3(asiento.x, asiento.y, salida.z), salida]
	se_levanto.emit()
