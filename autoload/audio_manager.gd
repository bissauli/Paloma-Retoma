extends Node
## Sonidos del juego (autoload "AudioManager").
## Si existe res://audio/<nombre>.wav (o .ogg) se usa ese archivo.
## Si no, el sonido se sintetiza por código al arrancar (placeholder).
## Nombres previstos: arrullo, aleteo, picoteo, grito_nene, silbato,
## chillido_halcon, ambiente, recoger, victoria, bocina, aplastar, boing, ladrido, trueno, lluvia.
## Cada sonido sale por un bus (ver default_bus_layout.tres): las voces (arrullo, grito, chillido)
## por "Voces", el ambiente y la música por "Musica" y el resto por "Efectos".
## Si existe res://audio/musica.ogg (o .wav) suena en bucle por el bus "Musica".

const MEZCLA := 22050
const NOMBRES := ["arrullo", "aleteo", "picoteo", "grito_nene", "silbato",
	"chillido_halcon", "ambiente", "recoger", "victoria", "bocina", "salpicadura", "aletazo", "tintineo",
	"aplastar", "boing", "ladrido", "trueno", "lluvia", "crashWall", "crashMetal", "landing"]
const CANALES := 10
const BUS_VOCES := ["arrullo", "grito_nene", "chillido_halcon"]

## Sonidos de interfaz y de avisos (res://audio/ui/<archivo>.wav, de F:/TESTS/soundsForGames, pasados
## a 16 bits, recortados y parejos de volumen). Se tocan con ui(): ui("highlight", -8.0). Salen por el
## bus "Efectos". Si falta un archivo, ese sonido simplemente no suena.
const UI := {
	"button": "Button_Pressed",              ## Apretar un botón
	"cancel": "Cancel",                      ## Cancelar, volver atrás, borrar
	"click_in": "Clicked_In",                ## Activar una casilla
	"click_out": "Clicked_Out",              ## Desactivar una casilla
	"confirm": "Confirm",                    ## Confirmar: empezar a jugar, aceptar una misión
	"currency": "Currency",                  ## Comida que se suma (entregar en el nido, el choripán)
	"dialogue_blip": "Dialogue_Blip",        ## Pasar por una opción de un diálogo
	"dialogue_expression": "Dialogue_Expression",   ## Una línea nueva de diálogo
	"failure": "Failure",                    ## Te atraparon
	"highlight": "Highlight",                ## Pasar el foco o el mouse por un botón
	"lock": "Lock",                          ## Algo bloqueado (el choripán sin bandada)
	"menu_close": "Menu_Close",
	"menu_open": "Menu_Open",
	"pause": "Pause",
	"unpause": "Unpause",
	"purchase": "Purchase",                  ## Gastar comida: reclutar palomas
	"sell": "Sell",
	"success": "Success",                    ## Victoria, trofeo, misión completada
	"unlock": "Unlock",                      ## Logro, misión lista, baño completo
	"warning": "Warning",                    ## Peligro: el halcón
}

var _sonidos := {}
var _ui := {}
var _pool: Array[AudioStreamPlayer] = []
var _ambiente: AudioStreamPlayer
var _musica: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1810
	for n: String in NOMBRES:
		_sonidos[n] = _cargar_o_generar(n)
	for k: String in UI:
		var ruta := "res://audio/ui/%s.wav" % UI[k]
		if ResourceLoader.exists(ruta):
			_ui[k] = load(ruta)
	for i in CANALES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_ambiente = AudioStreamPlayer.new()
	_ambiente.stream = _sonidos["ambiente"]
	_ambiente.volume_db = -16.0
	_ambiente.bus = &"Musica"
	add_child(_ambiente)
	_musica = AudioStreamPlayer.new()
	_musica.bus = &"Musica"
	_musica.volume_db = -6.0
	for ext: String in [".ogg", ".wav"]:
		if ResourceLoader.exists("res://audio/musica" + ext):
			_musica.stream = load("res://audio/musica" + ext) as AudioStream
			break
	add_child(_musica)


func _exit_tree() -> void:
	# Cortar todo al salir evita que queden reproducciones colgadas
	_ambiente.stop()
	_musica.stop()
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
	elegido.bus = bus_de(nombre)
	elegido.volume_db = volumen_db
	elegido.pitch_scale = _rng.randf_range(0.92, 1.08) if variar_tono else 1.0
	elegido.play()


## Sonido de interfaz o de aviso (ver UI), sin variar el tono.
func ui(nombre: String, volumen_db := 0.0) -> void:
	if not _ui.has(nombre):
		return
	var elegido: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			elegido = p
			break
	elegido.stream = _ui[nombre]
	elegido.bus = &"Efectos"
	elegido.volume_db = volumen_db
	elegido.pitch_scale = 1.0
	elegido.play()


## Sonido 3D en una posición del mundo (enemigos, NPCs).
func reproducir_en(nombre: String, posicion: Vector3, volumen_db := 0.0) -> void:
	var escena := get_tree().current_scene
	if escena == null or not _sonidos.has(nombre) or not escena is Node3D:
		reproducir(nombre, volumen_db)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _sonidos[nombre]
	p.bus = bus_de(nombre)
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
	if _musica.stream and not _musica.playing:
		_musica.play()


## El stream de un sonido, para reproducirlo con un player propio (la lluvia en loop de world/cielo.gd).
func sonido(nombre: String) -> AudioStream:
	return _sonidos.get(nombre)


func detener_ambiente() -> void:
	_ambiente.stop()
	_musica.stop()


## Bus de audio por el que sale cada sonido (lo regula Opciones > Audio).
func bus_de(nombre: String) -> StringName:
	if nombre == "ambiente":
		return &"Musica"
	return &"Voces" if nombre in BUS_VOCES else &"Efectos"


# ---------------------------------------------------------------- Carga / síntesis

## Sonidos cuyo archivo se llama distinto (res://audio/bark.mp3 es el "ladrido").
const ARCHIVOS := {"ladrido": "bark"}


func _cargar_o_generar(nombre: String) -> AudioStream:
	for ext: String in [".wav", ".ogg", ".mp3"]:
		var ruta := "res://audio/" + String(ARCHIVOS.get(nombre, nombre)) + ext
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
		"bocina": return _gen_bocina()
		"salpicadura": return _gen_salpicadura()
		"aletazo": return _gen_aletazo()
		"tintineo": return _gen_tintineo()
		"aplastar": return _gen_aplastar()
		"boing": return _gen_boing()
		"ladrido": return _gen_ladrido()
		"trueno": return _gen_trueno()
		"lluvia": return _gen_lluvia()
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


func _gen_salpicadura() -> AudioStreamWAV:
	# "Plaf": ruido que se va apagando, con unos burbujeos (tonos cortitos que suben).
	var dur := 0.4
	var m := _muestras(dur)
	var filtrado := 0.0
	var burbujas: Array[float] = [0.02, 0.09, 0.17]
	for i in m.size():
		var t := float(i) / MEZCLA
		filtrado = lerpf(filtrado, _rng.randf_range(-1.0, 1.0), lerpf(0.5, 0.12, minf(t / 0.3, 1.0)))
		var s := filtrado * exp(-t * 9.0) * 0.8
		for b: float in burbujas:
			var u := t - b
			if u >= 0.0 and u < 0.06:
				s += sin(TAU * (500.0 + 6000.0 * u) * u) * exp(-u * 45.0) * 0.35
		m[i] = s * 0.8 * _env(t, dur, 0.003)
	return _a_wav(m)


func _gen_aletazo() -> AudioStreamWAV:
	# "Fuch": una ráfaga de aire (ruido que se abre y se cierra) con un golpecito seco de plumas al final.
	var dur := 0.26
	var m := _muestras(dur)
	var filtrado := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var u := t / dur
		filtrado = lerpf(filtrado, _rng.randf_range(-1.0, 1.0), lerpf(0.12, 0.55, minf(u * 1.6, 1.0)))
		var viento := sin(u * PI) * pow(u, 0.6)
		var golpe := exp(-maxf(t - 0.14, 0.0) * 55.0) * (1.0 if t > 0.14 else 0.0)
		m[i] = (filtrado * viento * 0.7 + filtrado * golpe * 0.6) * _env(t, dur, 0.004)
	return _a_wav(m)


func _gen_tintineo() -> AudioStreamWAV:
	# "Tin": vidrio o loza que cae, dos tonos agudos que se apagan.
	var dur := 0.5
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var s := sin(TAU * 2350.0 * t) * exp(-t * 14.0) + 0.6 * sin(TAU * 3480.0 * t) * exp(-t * 18.0) \
			+ 0.3 * sin(TAU * 5100.0 * t) * exp(-t * 26.0)
		s += _rng.randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.5
		m[i] = s * 0.32 * _env(t, dur, 0.001)
	return _a_wav(m)


func _gen_bocina() -> AudioStreamWAV:
	# Bocina de auto: dos tonos medios con armónicos (onda casi cuadrada), corta.
	var dur := 0.45
	var m := _muestras(dur)
	for i in m.size():
		var t := float(i) / MEZCLA
		var v := 0.0
		for f: float in [392.0, 494.0]:
			var x := sin(TAU * f * t)
			v += clampf(x * 3.0, -1.0, 1.0)
		var env := minf(minf(t / 0.015, 1.0), clampf((dur - t) / 0.08, 0.0, 1.0))
		m[i] = v * 0.16 * env
	return _a_wav(m)


func _gen_aplastar() -> AudioStreamWAV:
	# "¡Plaf!" de dibujito: un golpe grave que cae de tono y un chasquido de ruido encima.
	var dur := 0.32
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		fase += lerpf(170.0, 55.0, minf(t / 0.12, 1.0)) / MEZCLA
		var golpe := sin(TAU * fase) * exp(-t * 14.0)
		var chasquido := _rng.randf_range(-1.0, 1.0) * exp(-t * 55.0)
		m[i] = (golpe * 0.75 + chasquido * 0.45) * minf(t / 0.003, 1.0)
	return _a_wav(m)


func _gen_boing() -> AudioStreamWAV:
	# "¡Boing!": un resorte que sube de tono y vibra mientras se apaga.
	var dur := 0.55
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var f := lerpf(140.0, 420.0, minf(t / 0.09, 1.0)) * (1.0 + 0.09 * sin(TAU * 17.0 * t) * exp(-t * 3.0))
		fase += f / MEZCLA
		var s := sin(TAU * fase) + 0.3 * sin(TAU * fase * 2.0)
		m[i] = s * 0.33 * minf(t / 0.01, 1.0) * exp(-t * 5.5)
	return _a_wav(m)


func _gen_ladrido() -> AudioStreamWAV:
	# "¡Guau, guau!": dos golpes de voz que bajan de tono, con algo de ruido (ronquera).
	var dur := 0.62
	var m := _muestras(dur)
	var fase := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		var v := 0.0
		for c: float in [0.0, 0.3]:
			var u := t - c
			if u >= 0.0 and u < 0.2:
				var f := lerpf(520.0, 290.0, u / 0.2)
				fase += f / MEZCLA
				var onda := sin(TAU * fase) + 0.5 * sin(TAU * fase * 2.0) + 0.25 * sin(TAU * fase * 3.0)
				v += (onda * 0.8 + _rng.randf_range(-0.35, 0.35)) * minf(u / 0.012, 1.0) * exp(-u * 13.0)
		m[i] = v * 0.32
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


func _gen_trueno() -> AudioStreamWAV:
	# Un chasquido corto y un retumbo grave que se va apagando con ondas lentas.
	var dur := 3.2
	var m := _muestras(dur)
	var marron := 0.0
	var crujido := 0.0
	for i in m.size():
		var t := float(i) / MEZCLA
		marron = clampf(marron + _rng.randf_range(-0.035, 0.035), -1.0, 1.0) * 0.997
		crujido = lerpf(crujido, _rng.randf_range(-1.0, 1.0), 0.35)
		var golpe := crujido * exp(-t * 9.0) * 0.6
		var retumbo := marron * 1.6 * exp(-t * 1.1) * (0.75 + 0.25 * sin(TAU * t * 2.3))
		m[i] = (golpe + retumbo) * minf(t / 0.01, 1.0)
	return _a_wav(m)


func _gen_lluvia() -> AudioStreamWAV:
	# Lluvia pareja: ruido filtrado (sin graves ni agudos filosos) con rachas lentas de volumen y muchas
	# gotitas cortas que suenan a "tic". Dura 12 s y el final se funde con el principio (equal-power) para
	# que el loop no se note; las rachas dan ciclos enteros, así que tampoco saltan.
	var n := int(12.0 * MEZCLA)
	var fundido := int(2.0 * MEZCLA)
	var total := n + fundido
	var a := PackedFloat32Array()
	a.resize(total)
	var lp1 := 0.0
	var lp2 := 0.0
	var graves := 0.0
	var gota := 0.0
	var gota_f := 0.0
	var gota_fase := 0.0
	for i in total:
		var blanco := _rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, blanco, 0.30)
		lp2 = lerpf(lp2, lp1, 0.55)
		graves = lerpf(graves, blanco, 0.02)
		var siseo := (lp2 - graves * 1.6) * 0.9
		if _rng.randf() < 0.006:
			gota = _rng.randf_range(0.15, 0.45)
			gota_f = _rng.randf_range(1800.0, 4200.0)
		gota *= 0.9
		gota_fase += TAU * gota_f / MEZCLA
		var racha := 0.85 + 0.15 * sin(TAU * float(i) * 3.0 / n) * sin(TAU * float(i) * 5.0 / n + 1.3)
		a[i] = (siseo * 0.55 + sin(gota_fase) * gota * 0.35) * racha
	var m := _muestras(n / float(MEZCLA))
	for i in n:
		m[i] = a[i]
	for i in fundido:
		var w := float(i) / fundido
		m[i] = a[i] * sin(w * PI * 0.5) + a[n + i] * cos(w * PI * 0.5)
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
