extends Node
## Sonidos del juego (autoload "AudioManager").
## Si existe res://audio/<nombre>.wav (o .ogg) se usa ese archivo.
## Si no, el sonido se sintetiza por código al arrancar (placeholder).
## Nombres previstos: arrullo, aleteo, picoteo, grito_nene, silbato,
## chillido_halcon, ambiente, recoger, victoria.

const MEZCLA := 22050
const NOMBRES := ["arrullo", "aleteo", "picoteo", "grito_nene", "silbato",
	"chillido_halcon", "ambiente", "recoger", "victoria"]
const CANALES := 10

var _sonidos := {}
var _pool: Array[AudioStreamPlayer] = []
var _ambiente: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1810
	for n: String in NOMBRES:
		_sonidos[n] = _cargar_o_generar(n)
	for i in CANALES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.stream = _sonidos["ambiente"]
	_ambiente.volume_db = -16.0
	add_child(_ambiente)


func _exit_tree() -> void:
	# Cortar todo al salir evita que queden reproducciones colgadas
	_ambiente.stop()
	for p in _pool:
		p.stop()


# ---------------------------------------------------------------- API pública

## Sonido sin posición (UI, jugador).
func reproducir(nombre: String, volumen_db := 0.0, variar_tono := true) -> void:
	if not _sonidos.has(nombre):
		return
	var elegido: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			elegido = p
			break
	elegido.stream = _sonidos[nombre]
	elegido.volume_db = volumen_db
	elegido.pitch_scale = _rng.randf_range(0.92, 1.08) if variar_tono else 1.0
	elegido.play()


## Sonido 3D en una posición del mundo (enemigos, NPCs).
func reproducir_en(nombre: String, posicion: Vector3, volumen_db := 0.0) -> void:
	var escena := get_tree().current_scene
	if escena == null or not _sonidos.has(nombre) or not escena is Node3D:
		reproducir(nombre, volumen_db)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sonidos[nombre]
	p.volume_db = volumen_db
	p.unit_size = 8.0
	p.max_distance = 70.0
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	escena.add_child(p)
	p.global_position = posicion
	p.finished.connect(p.queue_free)
	p.play()


func iniciar_ambiente() -> void:
	if DisplayServer.get_name() == "headless":
		return  # En las pruebas automáticas no hace falta (y evita avisos al salir)
	if not _ambiente.playing:
		_ambiente.play()


func detener_ambiente() -> void:
	_ambiente.stop()


# ---------------------------------------------------------------- Carga / síntesis

func _cargar_o_generar(nombre: String) -> AudioStream:
	for ext: String in [".wav", ".ogg"]:
		var ruta := "res://audio/" + nombre + ext
		if ResourceLoader.exists(ruta):
			var s := load(ruta) as AudioStream
			if s:
				return s
	match nombre:
		"arrullo": return _gen_arrullo()
		"aleteo": return _gen_aleteo()
		"picoteo": return _gen_picoteo()
		"grito_nene": return _gen_grito()
		"silbato": return _gen_silbato()
		"chillido_halcon": return _gen_chillido()
		"ambiente": return _gen_ambiente()
		"recoger": return _gen_recoger()
		"victoria": return _gen_victoria()
	return _a_wav(PackedFloat32Array([0.0]))


## Convierte muestras flotantes (-1..1) en un AudioStreamWAV de 16 bits.
func _a_wav(m: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(m.size() * 2)
	for i in m.size():
		datos.encode_s16(i * 2, int(clampf(m[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MEZCLA
	w.stereo = false
	w.data = datos
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = m.size()
	return w


func _muestras(segundos: float) -> PackedFloat32Array:
	var m := PackedFloat32Array()
	m.resize(int(segundos * MEZCLA))
	return m


## Envolvente simple: ataque lineal y caída suave.
func _env(t: float, dur: float, ataque := 0.02) -> float:
	if t < ataque:
		return t / ataque
	return clampf(1.0 - (t - ataque) / (dur - ataque), 0.0, 1.0)


func _gen_arrullo() -> AudioStreamWAV:
	# "Rrruuu-uh": tono grave que sube y baja, con un trémolo rápido que lo hace gorgotear.
	var dur := 0.95
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var f := 0.0
		if t < 0.3:
			f = lerpf(300.0, 430.0, t / 0.3)
		else:
			f = lerpf(430.0, 330.0, (t - 0.3) / (dur - 0.3))
		fase += f / MEZCLA
		var lobulo := absf(sin(t / dur * PI * 2.0)) * 0.6 + 0.4
		var tremolo := 0.65 + 0.35 * sin(TAU * 26.0 * t)
		var s := sin(TAU * fase) + 0.35 * sin(TAU * fase * 2.0) + 0.15 * sin(TAU * fase * 3.0)
		m[i] = s * 0.35 * lobulo * tremolo * _env(t, dur, 0.05)
	return _a_wav(m)


func _gen_aleteo() -> AudioStreamWAV:
	# Tres golpes de ruido filtrado.
	var dur := 0.3
	var m := _muestras(dur)
	var filtrado := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var golpe := fmod(t, 0.1) / 0.1
		var env := exp(-golpe * 6.0)
		filtrado = lerpf(filtrado, _rng.randf_range(-1.0, 1.0), 0.25)
		m[i] = filtrado * env * 0.9 * _env(t, dur, 0.005)
	return _a_wav(m)


func _gen_picoteo() -> AudioStreamWAV:
	var dur := 0.07
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var env := exp(-t * 90.0)
		m[i] = (sin(TAU * 1900.0 * t) * 0.6 + _rng.randf_range(-0.4, 0.4)) * env * 0.8
	return _a_wav(m)


func _gen_grito() -> AudioStreamWAV:
	# "¡Aaaah!" de nene: sube de tono con vibrato.
	var dur := 0.85
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var f := lerpf(620.0, 1050.0, minf(t / 0.35, 1.0)) + sin(TAU * 7.0 * t) * 35.0
		fase += f / MEZCLA
		var p := fmod(fase, 1.0)
		var s := (p * 2.0 - 1.0) * 0.5 + sin(TAU * fase) * 0.5
		m[i] = s * 0.35 * _env(t, dur, 0.04)
	return _a_wav(m)


func _gen_silbato() -> AudioStreamWAV:
	# Silbato con "bolita": tono agudo con trino.
	var dur := 0.9
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var trino := 0.6 + 0.4 * sin(TAU * 38.0 * t)
		var f := 2900.0 + sin(TAU * 38.0 * t) * 120.0
		m[i] = sin(TAU * f * t) * trino * 0.28 * _env(t, dur, 0.02)
	return _a_wav(m)


func _gen_chillido() -> AudioStreamWAV:
	# "¡Kiiiaaa!" descendente.
	var dur := 1.0
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var f := lerpf(2700.0, 1600.0, t / dur) + sin(TAU * 11.0 * t) * 90.0
		fase += f / MEZCLA
		var s := sin(TAU * fase) + 0.4 * sin(TAU * fase * 1.5) + _rng.randf_range(-0.25, 0.25)
		m[i] = s * 0.25 * _env(t, dur, 0.03)
	return _a_wav(m)


func _gen_ambiente() -> AudioStreamWAV:
	# Murmullo de ciudad: ruido marrón con ondulaciones lentas. Se repite en loop.
	var dur := 4.0
	var m := _muestras(dur)
	var marron := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		marron = clampf(marron + _rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		var ola := 0.7 + 0.3 * sin(TAU * t / dur * 2.0)
		m[i] = marron * 0.8 * ola
	# Fundido en los bordes para que el loop no haga click
	var borde := 2000
	for i in borde:
		var k := float(i) / borde
		m[i] *= k
		m[m.size() - 1 - i] *= k
	return _a_wav(m, true)


func _gen_recoger() -> AudioStreamWAV:
	var dur := 0.16
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var f := 880.0 if t < 0.07 else 1320.0
		m[i] = sin(TAU * f * t) * 0.3 * _env(t, dur, 0.005)
	return _a_wav(m)


func _gen_victoria() -> AudioStreamWAV:
	# Arpegio alegre Do-Mi-Sol-Do.
	var notas := [523.25, 659.25, 783.99, 1046.5]
	var dur := 1.4
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var idx := mini(int(t / 0.18), 3)
		var tn := t - idx * 0.18
		var f: float = notas[idx]
		var env := exp(-tn * (3.0 if idx < 3 else 1.5))
		m[i] = (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * 0.3 * env
	return _a_wav(m)
