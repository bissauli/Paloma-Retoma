extends Node
## Mide qué tan fluida es la cinemática de los pasajes (headless, con tiempo fijo):
## godot --headless --path . --fixed-fps 60 res://tests/medir_fluidez.tscn
## Registra la cámara que se ve en cada cuadro durante las 5 pasadas y calcula sus tirones: la
## aceleración de la posición y la velocidad angular de hacia dónde mira. Menos es más fluido.

var paloma: PalomaJugador
var posiciones: Array[Vector3] = []
var miradas: Array[Vector3] = []
var distancias: Array[float] = []
var camaras: Array[String] = []
var midiendo := false


func _ready() -> void:
	_ready_medicion()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	for i in 20:
		await get_tree().process_frame
	var resultados := []
	for c in get_tree().get_nodes_in_group("casa_enterable"):
		var casa := c as CasaEnterable
		posiciones.clear()
		miradas.clear()
		distancias.clear()
		camaras.clear()
		paloma.global_position = casa.to_global(Vector3(casa.x_frente, CasaEnterable.Y_PASO + 0.3, casa.fondo / 2.0 + 9.0))
		paloma.reset_physics_interpolation()
		paloma.camara.yaw = casa.rotation.y
		paloma.estado = PalomaJugador.Estado.SUELO
		paloma.despegar()
		paloma.velocity = casa.global_transform.basis * Vector3(0, 0, -8)
		paloma.camara.reubicar()
		Input.action_press("mover_adelante")
		while not casa.activa:
			await get_tree().physics_frame
		Input.action_release("mover_adelante")
		midiendo = true
		while casa.activa:
			await get_tree().process_frame
		for i in 20:   # Un poco después: la vuelta a la cámara del juego también cuenta
			await get_tree().process_frame
		midiendo = false
		resultados.append(_analizar(String(casa.name).replace("Entrada_", "")))
		for i in 60:
			await get_tree().process_frame
	var peor := 0.0
	var suma := 0.0
	for r: Array in resultados:
		peor = maxf(peor, r[1])
		suma += r[0]
	print("FLUIDEZ total: aceleración media %.1f m/s², pico peor %.1f m/s²" % [suma / resultados.size(), peor])
	get_tree().quit()


func _ready_medicion() -> void:
	# Se mide al final de cada cuadro (lo que se ve): si no, según en qué orden corren los scripts,
	# a veces se juntan dos movimientos de la cámara en un solo cuadro
	process_priority = 100000   # Corre último en cada cuadro: después de cualquier movimiento de la cámara


func _process(_delta: float) -> void:
	if not midiendo:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		posiciones.append(cam.global_position)
		miradas.append(-cam.global_transform.basis.z)
		distancias.append(cam.global_position.distance_to(paloma.get_global_transform_interpolated().origin))
		camaras.append(cam.get_class() + ("(cine)" if cam is CamaraCinematica else "(juego)"))


## [aceleración media, pico de aceleración, pico de giro] de la cámara en esta pasada.
func _analizar(nombre: String) -> Array:
	var dt := 1.0 / 60.0
	var acel: Array[float] = []
	var giro_max := 0.0
	var giro_en := 0
	for i in range(2, posiciones.size()):
		var v1 := (posiciones[i - 1] - posiciones[i - 2]) / dt
		var v2 := (posiciones[i] - posiciones[i - 1]) / dt
		acel.append((v2 - v1).length() / dt)
		var g := rad_to_deg(miradas[i].angle_to(miradas[i - 1])) / dt
		if g > giro_max:
			giro_max = g
			giro_en = i
	if OS.get_cmdline_user_args().has("detalle"):
		print("  giro máx en el cuadro %d de %d (distancia cámara-paloma ahí: %.2f m, cámara %s -> %s)" % [giro_en, posiciones.size(), distancias[giro_en] if giro_en < distancias.size() else -1.0, camaras[giro_en - 1], camaras[giro_en]])
		var picos := []
		for i in acel.size():
			picos.append([acel[i], i + 2])
		picos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for k in mini(6, picos.size()):
			var i: int = picos[k][1]
			print("  pico %.0f m/s² en el cuadro %d de %d (salto %.2f m)" % [picos[k][0], i, posiciones.size(),
				posiciones[i].distance_to(posiciones[i - 1])])
	acel.sort()
	var media := 0.0
	for a in acel:
		media += a
	media /= maxf(acel.size(), 1)
	var p99: float = acel[int(acel.size() * 0.99)] if not acel.is_empty() else 0.0
	print("FLUIDEZ %s: %d cuadros, aceleración media %.1f m/s², pico (p99) %.1f m/s², giro máx %.0f°/s" %
		[nombre, posiciones.size(), media, p99, giro_max])
	return [media, p99, giro_max]
