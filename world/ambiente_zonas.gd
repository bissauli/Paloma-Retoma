class_name AmbienteZonas
extends Node
## Sonido ambiente por zonas del mapa (el parque, y las que se sumen). Pensado para no cansar:
## - Suena bajito (volumen propio por zona) y por el bus "Efectos" (respeta Opciones > Audio).
## - Entra y sale con fundidos largos según la distancia al borde de la zona (nunca de golpe).
## - Entre zonas se hace un cruce: la suma de todos los ambientes nunca pasa de 1 (si dos zonas se
##   pisan, cada una baja, no se apilan).
## - Si la paloma vuela alto el ambiente se apaga de a poco (desde las alturas no se oye el parque).
## - Baja un poco mientras hay un diálogo, y se calla en el menú, la pausa y al terminar la partida.
## - Los reproductores se paran cuando su zona queda en silencio (no gastan CPU decodificando).
## Para sumar una zona: agregar una entrada a ZONAS (archivo en res://audio/, rectángulo en X/Z del
## mundo, margen de fundido en metros y volumen en dB). Se mira 10 veces por segundo.

const ZONAS := [
	{
		"id": "parque",
		"archivo": "res://audio/park.ogg",
		"rect": Ciudad.PARQUE,      # Oeste del mapa
		"margen": 28.0,             # Empieza a oírse a 28 m del borde, a pleno adentro
		"db": -15.0,
	},
]

const PERIODO := 0.1
const SUBIDA := 0.35          ## Velocidad del fundido de entrada (1.0 = un segundo)
const BAJADA := 0.5
const ALTURA_LIBRE := 6.0     ## Hasta esta altura se oye completo
const ALTURA_MUDA := 50.0     ## A esta altura ya casi no se oye
const PISO_ALTURA := 0.15
const BAJA_DIALOGO := 0.5

var _reproductores: Array[AudioStreamPlayer] = []
var _nivel: Array[float] = []        ## Volumen lineal actual de cada zona (0..1)
var _t := 0.0
var _objetivo: Array[float] = []
var _general := 0.0                  ## Fundido general (menú, pausa, diálogo, altura)
var _general_objetivo := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	for z: Dictionary in ZONAS:
		var p := AudioStreamPlayer.new()
		p.name = "Ambiente_" + String(z["id"])
		p.bus = &"Efectos"
		p.volume_db = -80.0
		# En la web el modo por defecto decodifica el archivo entero a un buffer (el ambiente del parque dura 5 minutos:
		# 237 MB, el navegador lo rechaza); como stream se va leyendo de a poco
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		if ResourceLoader.exists(z["archivo"]):
			var s := load(z["archivo"]) as AudioStream
			if s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			p.stream = s
		add_child(p)
		_reproductores.append(p)
		_nivel.append(0.0)
		_objetivo.append(0.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = PERIODO
		_calcular_objetivos()
	_general = move_toward(_general, _general_objetivo, delta * 0.8)
	var en_pausa := get_tree().paused
	for i in _reproductores.size():
		var p := _reproductores[i]
		var quiere := _objetivo[i]
		_nivel[i] = move_toward(_nivel[i], quiere, delta * (SUBIDA if quiere > _nivel[i] else BAJADA))
		var v := _nivel[i] * _general
		if v < 0.002:
			if p.playing:
				p.stop()
			continue
		if p.stream == null:
			continue
		if not p.playing:
			# Empieza en un punto al azar: cada vez que volvés al parque no suena lo mismo del principio
			p.play(randf() * maxf(p.stream.get_length() - 1.0, 0.0))
		p.stream_paused = en_pausa
		p.volume_db = linear_to_db(v) + float(ZONAS[i]["db"])


func _calcular_objetivos() -> void:
	var j := GameState.jugador
	var activo := j != null and GameState.en_partida and not GameState.partida_terminada \
		and not GameState.menu_activo and not get_tree().paused
	if not activo:
		_general_objetivo = 0.0
		return
	var pos := j.global_position
	var g := clampf(1.0 - (pos.y - ALTURA_LIBRE) / (ALTURA_MUDA - ALTURA_LIBRE), PISO_ALTURA, 1.0)
	if pos.y > ALTURA_MUDA:
		g = 0.0
	if Dialogos.activo:
		g *= BAJA_DIALOGO
	_general_objetivo = g
	var total := 0.0
	for i in ZONAS.size():
		var z: Dictionary = ZONAS[i]
		var r: Rect2 = z["rect"]
		var dx := maxf(maxf(r.position.x - pos.x, pos.x - r.end.x), 0.0)
		var dz := maxf(maxf(r.position.y - pos.z, pos.z - r.end.y), 0.0)
		var d := sqrt(dx * dx + dz * dz)
		var w := 1.0 - clampf(d / float(z["margen"]), 0.0, 1.0)
		_objetivo[i] = w * w * (3.0 - 2.0 * w)       # smoothstep
		total += _objetivo[i]
	if total > 1.0:
		for i in _objetivo.size():
			_objetivo[i] /= total
