class_name PalomaNPC
extends Node3D
## Una paloma no jugable. Puede estar suelta (paseando en su zona), siguiendo
## a la bandada (la mueve flock/bandada.gd), huyendo o festejando.
## No usa física: se mueve a mano y consulta la altura del piso con rayos de vez en cuando.
## Para no atravesar paredes, cada movimiento se chequea con un rayo contra el mundo (capa 1)
## y si choca se desliza a lo largo de la pared (ver mover_con_choques).

enum Modo { SUELTA, SIGUIENDO, HUYENDO, FESTEJANDO, LLORANDO }

const NOMBRES := ["Carlos", "La Tana", "El Ruso", "Coqui", "Pocha", "Tito", "Mirta", "El Flaco",
	"Chiche", "La Negra", "Cacho", "Beba", "Pipo", "Nené", "Lalo", "Toto", "Chola", "Fito",
	"Marta", "El Tano", "Rulo", "Pupi", "Quique", "Nilda", "Cholo", "Kuki", "Tita", "Panchi"]

const ALTURA_RAYO := 0.3    ## Altura del rayo de choque: los escalones y cordones más bajos se suben
const RADIO_CHOQUE := 0.2   ## Distancia mínima a las paredes

var modo: Modo = Modo.SUELTA
var velocidad := Vector3.ZERO
var en_suelo := true
var nombre := ""
var zona_centro := Vector3.ZERO
var zona_radio := 5.0
var desplazamiento := Vector3.ZERO   ## Lugar propio dentro de la formación de la bandada
var altura_suelo := 0.0
var modo_anim := 0                   ## Lo usa la bandada para animar

var _rumbo := 0.0
var _dir_corrida := Vector3.ZERO
var _destino := Vector3.ZERO
var _timer_paseo := 0.0
var _timer_suelo := 0.0
var _timer_huida := 0.0
var _picoteo_timer := 0.0
var _acum_fisica := 0.0    ## Tiempo acumulado de los pasos de física salteados (sueltas lejanas)
var _desfase := 0

## Un solo pedido de rayo para todas (crear uno nuevo en cada movimiento cuesta).
static var _rayo := PhysicsRayQueryParameters3D.new()
## Posición de la cámara en este paso de física (se lee una vez para todas las palomas).
static var _ref_paso := -1
static var _ref_pos := Vector3.ZERO
## Más lejos que esto de la cámara, las palomas sueltas se actualizan 1 de cada 3 pasos de física.
const LEJOS_CAMARA := 25.0

@onready var modelo: ModeloPaloma = $Modelo


func _ready() -> void:
	add_to_group("palomas_npc")
	nombre = NOMBRES[randi() % NOMBRES.size()]
	_rumbo = randf() * TAU
	_desfase = randi() % 3
	_timer_suelo = randf() * 0.5
	_timer_paseo = randf() * 3.0
	_destino = global_position
	desplazamiento = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.2, 3.8)
	desplazamiento.y = randf_range(0.2, 1.8)


## Variante de color al azar: gris, blanca, marrón, oscura, canela o manchada
## (llamar antes de agregarla al árbol).
func randomizar_colores() -> void:
	var m := get_node("Modelo") as ModeloPaloma
	m.variante = ModeloPaloma.variante_al_azar()


func configurar_zona(centro: Vector3, radio: float) -> void:
	zona_centro = centro
	zona_radio = radio
	_destino = centro


# ---------------------------------------------------------------- Cambios de modo

func reclutar() -> void:
	modo = Modo.SIGUIENDO
	GameState.registrar_seguidora(1)
	_corazon()


## Se separa de la bandada y sale volando lejos de "desde".
func soltar(desde: Vector3) -> void:
	if modo == Modo.SIGUIENDO:
		GameState.registrar_seguidora(-1)
	puesto = Vector3.INF
	caballito = null
	baila_afuera = false
	_salto_t = -1.0
	sentada = false
	modo = Modo.HUYENDO
	en_suelo = false
	var lejos := (global_position - desde)
	lejos.y = 0
	if lejos.length() < 0.1:
		lejos = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	velocidad = lejos.normalized() * 8.0 + Vector3.UP * 5.0
	_timer_huida = randf_range(2.0, 3.5)


## Vuela hasta una zona y aterriza ahí (al huir o al llegar volando desde afuera).
func ir_a_zona(centro: Vector3, radio: float) -> void:
	configurar_zona(centro, radio)
	var a := randf() * TAU
	_destino = centro + Vector3(cos(a), 0, sin(a)) * randf() * radio


func festejar() -> void:
	modo = Modo.FESTEJANDO


func _corazon() -> void:
	var l := Label3D.new()
	l.text = "♥"
	l.font_size = 96
	l.modulate = Color(1, 0.4, 0.55)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0022
	l.position = Vector3(0, 0.8, 0)
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", 1.8, 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)
	modelo.arrullar()


# ---------------------------------------------------------------- Actualización propia

func _physics_process(delta: float) -> void:
	if controlada:
		return    # La maneja otro sistema (el partido de fútbol, ver world/partido_futbol.gd)
	if modo == Modo.SUELTA:
		# Las sueltas lejos de la cámara pasean igual, pero se calculan 1 de cada 3 pasos
		_acum_fisica += delta
		if (Engine.get_physics_frames() + _desfase) % 3 != 0 and _lejos_de_camara():
			return
		delta = _acum_fisica
		_acum_fisica = 0.0
	match modo:
		Modo.SUELTA:
			_paso_suelta(delta)
		Modo.HUYENDO:
			_paso_huida(delta)
		Modo.FESTEJANDO:
			_paso_festejo(delta)
		Modo.LLORANDO:
			_paso_llanto(delta)
		Modo.SIGUIENDO:
			pass  # La mueve la bandada
	if modo != Modo.SIGUIENDO:
		modelo.animar(delta, modo_anim, Vector2(velocidad.x, velocidad.z).length())


## Pasea por su zona, picotea el piso y se queda quieta un rato.
func _paso_suelta(delta: float) -> void:
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(2.0, 6.0)
		var a := randf() * TAU
		_destino = zona_centro + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * zona_radio
		if randf() < 0.35:
			_destino = global_position  # Se queda quieta
	var hacia := _destino - global_position
	hacia.y = 0
	var v := Vector3.ZERO
	if hacia.length() > 0.3:
		v = hacia.normalized() * 0.8
	velocidad = velocidad.lerp(v, minf(delta * 4.0, 1.0))
	if velocidad.length_squared() > 0.0025:
		mover_con_choques(velocidad * delta)
	_actualizar_suelo(delta, 0.6)
	global_position.y = lerpf(global_position.y, altura_suelo, minf(delta * 10.0, 1.0))
	en_suelo = true
	modo_anim = 0
	_mirar(velocidad, delta, 6.0)
	# Picoteos ocasionales cuando está quieta
	_picoteo_timer -= delta
	if _picoteo_timer <= 0.0:
		_picoteo_timer = randf_range(0.8, 3.0)
		if velocidad.length() < 0.2:
			modelo.picotear()


func _paso_huida(delta: float) -> void:
	_timer_huida -= delta
	var objetivo_y := 9.0
	if _timer_huida <= 0.0:
		# Ya se alejó: vuela hacia su nueva zona y aterriza
		var hacia := _destino - global_position
		var plano := Vector3(hacia.x, 0, hacia.z)
		var d := plano.length()
		var deseada := plano.normalized() * minf(9.0, d * 1.5 + 1.0)
		_actualizar_suelo(delta, 0.3)
		objetivo_y = altura_suelo + clampf(d * 0.4, 0.0, 9.0)
		deseada.y = clampf((objetivo_y - global_position.y) * 1.5, -4.0, 4.0)
		velocidad = velocidad.lerp(deseada, minf(delta * 2.0, 1.0))
		if d < 0.6 and global_position.y - altura_suelo < 0.3:
			modo = Modo.SUELTA
			velocidad = Vector3.ZERO
			global_position.y = altura_suelo
	else:
		velocidad.y = lerpf(velocidad.y, clampf(objetivo_y - global_position.y, -2.0, 5.0), delta * 2.0)
	mover_con_choques(velocidad * delta)
	global_position.y = maxf(global_position.y, altura_suelo)
	modo_anim = 1 if velocidad.y > 0.3 else 2
	_mirar(velocidad, delta, 5.0)


## Festejo de la victoria: saltitos, arrullos y vuelitos en el lugar.
func _paso_festejo(delta: float) -> void:
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(0.6, 2.0)
		if randf() < 0.5:
			modelo.arrullar()
		_rumbo += randf_range(-1.5, 1.5)
		if randf() < 0.3:
			velocidad.y = 3.0
	velocidad.y -= 9.8 * delta
	global_position.y += velocidad.y * delta
	if global_position.y < altura_suelo:
		global_position.y = altura_suelo
		velocidad.y = 0.0
	modo_anim = 1 if global_position.y > altura_suelo + 0.05 else 0
	modelo.rotation.y = lerp_angle(modelo.rotation.y, _rumbo, delta * 5.0)


# ---------------------------------------------------------------- Utilidades

## Altura del piso debajo (rayo hacia abajo, con poca frecuencia).
func _actualizar_suelo(delta: float, cada: float) -> void:
	_timer_suelo -= delta
	if _timer_suelo > 0.0:
		return
	_timer_suelo = cada * randf_range(0.8, 1.2)
	altura_suelo = medir_suelo(global_position)


func medir_suelo(p: Vector3) -> float:
	var r := _rayo_mundo(p + Vector3.UP * 1.5, p + Vector3.DOWN * 40.0)
	if r.is_empty():
		return 0.0
	return (r["position"] as Vector3).y


## Rayo contra el mundo (capa 1).
func _rayo_mundo(desde: Vector3, hasta: Vector3) -> Dictionary:
	_rayo.from = desde
	_rayo.to = hasta
	_rayo.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(_rayo)


func _lejos_de_camara() -> bool:
	var paso := Engine.get_physics_frames()
	if paso != _ref_paso:
		_ref_paso = paso
		var cam := get_viewport().get_camera_3d()
		_ref_pos = cam.global_position if cam else Vector3.ZERO
	return global_position.distance_squared_to(_ref_pos) > LEJOS_CAMARA * LEJOS_CAMARA


## Mueve la paloma sin atravesar el mundo: un rayo desde el cuerpo hasta un poco más allá
## del destino. Si pega contra una pared (o el techo de algo), se queda del lado de afuera y
## se desliza a lo largo; si pega contra algo transitable (techo, rampa, cornisa) se apoya encima.
func mover_con_choques(desp: Vector3) -> void:
	var desde := global_position + Vector3.UP * ALTURA_RAYO
	var horiz := Vector3(desp.x, 0.0, desp.z)
	var largo_h := horiz.length()
	var hasta := desde + desp
	if largo_h > 0.0001:
		hasta += horiz / largo_h * RADIO_CHOQUE
	var r := _rayo_mundo(desde, hasta)
	if r.is_empty():
		global_position += desp
		return
	var n: Vector3 = r["normal"]
	var punto: Vector3 = r["position"]
	if n.y > 0.6:
		# Piso: avanza y queda arriba de la superficie
		global_position += desp
		if global_position.y < punto.y:
			global_position.y = punto.y
			velocidad.y = maxf(velocidad.y, 0.0)
		altura_suelo = maxf(altura_suelo, punto.y)
		return
	# Pared o techo: saca la parte del movimiento que va hacia adentro y se desliza
	var hacia_adentro := desp.dot(n)
	if hacia_adentro < 0.0:
		desp -= n * hacia_adentro
	var vel_adentro := velocidad.dot(n)
	if vel_adentro < 0.0:
		velocidad -= n * vel_adentro
	# El deslizamiento también se chequea (por ejemplo en una esquina)
	if _rayo_mundo(desde, desde + desp + n * 0.01).is_empty():
		global_position += desp
	# Si quedó demasiado pegada, la separa un poquito de la pared
	var hn := Vector3(n.x, 0.0, n.z)
	var dist := (desde - punto).dot(n)
	if hn.length() > 0.5 and dist < RADIO_CHOQUE:
		global_position += hn.normalized() * minf(RADIO_CHOQUE - dist, 0.05)


## Un auto que pasa la asusta: sale volando un poquito y vuelve a su zona.
func espantar(desde: Vector3) -> void:
	if modo != Modo.SUELTA:
		return
	soltar(desde)
	velocidad *= 0.7
	_timer_huida = randf_range(0.8, 1.4)
	ir_a_zona(zona_centro, zona_radio)


## Orienta el modelo hacia la dirección de movimiento.
func _mirar(v: Vector3, delta: float, rapidez: float) -> void:
	var h := Vector2(v.x, v.z)
	if h.length() > 0.15:
		_rumbo = lerp_angle(_rumbo, atan2(-h.x, -h.y), minf(rapidez * delta, 1.0))
	var cabeceo := 0.0
	if modo_anim != 0:
		cabeceo = clampf(atan2(v.y, maxf(h.length(), 1.0)) * 0.6, -0.8, 0.6)
	modelo.rotation = Vector3(cabeceo, _rumbo, 0.0)


## La jugadora la golpeó: se va de la bandada llorando, volando o corriendo (al azar).
func llorar(desde: Vector3, zona: Marker3D) -> void:
	if modo == Modo.SIGUIENDO:
		GameState.registrar_seguidora(-1)
	puesto = Vector3.INF
	sentada = false
	var l := Label3D.new()
	l.text = "T_T"
	l.font_size = 96
	l.modulate = Color(0.45, 0.7, 1.0)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0028
	l.position = Vector3(0, 0.7, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 1.3, 3.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(2.2)
	tw.tween_callback(l.queue_free)
	AudioManager.reproducir("picoteo", -2.0)
	var lejos := global_position - desde
	lejos.y = 0.0
	if lejos.length() < 0.1:
		lejos = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	if randf() < 0.5:
		modo = Modo.HUYENDO
		en_suelo = false
		velocidad = lejos.normalized() * 8.0 + Vector3.UP * 5.0
		_timer_huida = randf_range(2.5, 4.0)
		if zona:
			ir_a_zona(zona.global_position, zona.get_meta("radio", 5.0))
	else:
		modo = Modo.LLORANDO
		_dir_corrida = lejos.normalized()
		_timer_huida = randf_range(3.0, 4.5)


## Corre llorando alejándose del golpe; al rato se calma y pasea ahí cerca.
func _paso_llanto(delta: float) -> void:
	_timer_huida -= delta
	velocidad = velocidad.lerp(_dir_corrida * 4.5, minf(delta * 6.0, 1.0))
	mover_con_choques(velocidad * delta)
	_actualizar_suelo(delta, 0.3)
	global_position.y = lerpf(global_position.y, altura_suelo, minf(delta * 10.0, 1.0))
	en_suelo = true
	modo_anim = 0
	_mirar(velocidad, delta, 10.0)
	if _timer_huida <= 0.0:
		modo = Modo.SUELTA
		velocidad = Vector3.ZERO
		configurar_zona(global_position, 4.0)


## Descanso de la jugadora: lugar donde se sienta (INF = ninguno) y si ya llegó.
var puesto := Vector3.INF
var sentada := false


## Imita un emote de la jugadora (ver Bandada.imitar_baile): se queda en el lugar bailando.
var bailando_emote := false


func bailar_emote(baile: StringName, retraso := 0.0) -> void:
	if retraso > 0.0:
		await get_tree().create_timer(retraso).timeout
	if not is_inside_tree() or modo != Modo.SIGUIENDO or controlada:
		return
	modelo.permite_baile = true
	bailando_emote = true
	velocidad = Vector3.ZERO
	modelo.bailar(baile)


func parar_emote() -> void:
	if not bailando_emote:
		return
	bailando_emote = false
	modelo.dejar_de_bailar()


## Partido de fútbol (world/partido_futbol.gd): mientras "controlada" es true, ni la bandada ni sus
## propios pasos de física la mueven; el partido la maneja con ir_controlada y animar_hincha.
var controlada := false


## Camina (o vuela, si está lejos y "volando") hacia "destino" a "rapidez" m/s mirando hacia donde va.
## Devuelve la distancia horizontal que le falta.
func ir_controlada(delta: float, destino: Vector3, rapidez: float, volando := false) -> float:
	var d := destino - global_position
	var plano := Vector3(d.x, 0.0, d.z)
	var dist := plano.length()
	if dist > 0.05:
		global_position += plano / dist * minf(rapidez * delta, dist)
		_rumbo = lerp_angle(_rumbo, atan2(-plano.x, -plano.z), minf(10.0 * delta, 1.0))
	var en_vuelo := volando and dist > 1.5
	global_position.y = lerpf(global_position.y, destino.y + (1.0 if en_vuelo else 0.0), minf(8.0 * delta, 1.0))
	altura_suelo = destino.y
	sentada = true     # Para que la bandada no la empuje contra las demás
	en_suelo = not en_vuelo
	modo_anim = 1 if en_vuelo else 0
	velocidad = plano / maxf(dist, 0.001) * rapidez if dist > 0.15 else Vector3.ZERO
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)
	modelo.animar(delta, modo_anim, rapidez if (dist > 0.15 and not en_vuelo) else 0.0)
	return dist


## Gira (suave) hacia un punto del mundo, sin moverse.
func mirar_punto(delta: float, p: Vector3) -> void:
	var a := p - global_position
	if Vector2(a.x, a.z).length_squared() > 0.01:
		_rumbo = lerp_angle(_rumbo, atan2(-a.x, -a.z), minf(8.0 * delta, 1.0))
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)


## Hincha en la cancha: saltitos, aleteos y arrullos mirando hacia "mirar". "euforia" 1 = normal, 2 = gol.
func animar_hincha(delta: float, base: Vector3, mirar: Vector3, euforia: float) -> void:
	sentada = true
	en_suelo = true
	altura_suelo = base.y
	_t_baile += delta * (1.0 if euforia <= 1.0 else 1.6)
	_t_arrullo -= delta
	if _t_arrullo <= 0.0:
		_t_arrullo = randf_range(1.2, 3.5) / euforia
		if randf() < 0.6:
			modelo.arrullar()
	var salto := absf(sin(_t_baile * 4.0)) * 0.22 * euforia
	global_position = Vector3(base.x, base.y + salto, base.z)
	var a := mirar - global_position
	_rumbo = lerp_angle(_rumbo, atan2(-a.x, -a.z), minf(6.0 * delta, 1.0))
	modelo.rotation = Vector3(sin(_t_baile * 2.0) * 0.1 * euforia, _rumbo, sin(_t_baile * 4.0) * 0.18 * euforia)
	modo_anim = 1 if salto > 0.06 else 0
	modelo.animar(delta, modo_anim, 0.0)


## Calesita: el caballito (marcador que se mueve) donde va montada, o si "baila_afuera" el lugar
## fijo de afuera donde baila (puesto). Ver Bandada.subir_calesita.
var caballito: Marker3D
var baila_afuera := false
var _salto_t := -1.0              ## Progreso del salto en arco entre dos puestos (-1 = no está saltando)
var _salto_desde := Vector3.ZERO
var _llego_baile := false
var _t_baile := randf() * 10.0
var _t_arrullo := 0.0


func tiene_puesto() -> bool:
	return puesto != Vector3.INF or (caballito != null and is_instance_valid(caballito))


## Vuela hasta su puesto y se queda sentada mirando hacia "rumbo".
func paso_posada(delta: float, rumbo: float) -> void:
	var sobre_caballito := caballito != null and is_instance_valid(caballito)
	if sobre_caballito:
		puesto = caballito.global_position
		rumbo = caballito.global_rotation.y
		if _salto_t >= 0.0:
			# Salta en arco de un lado del subibaja al otro
			_salto_t += delta / 0.6
			var u := minf(_salto_t, 1.0)
			global_position = _salto_desde.lerp(puesto, u) + Vector3.UP * sin(u * PI) * 0.9
			velocidad = Vector3.ZERO
			sentada = false
			modo_anim = 1
			_mirar(puesto - _salto_desde, delta, 10.0)
			modelo.animar(delta, 1, 0.0)
			if _salto_t >= 1.0:
				_salto_t = -1.0
			return
	var d := puesto - global_position
	var dist := d.length()
	if baila_afuera:
		# Una vez que llegó se queda bailando (el saltito la despega del suelo: no se vuelve a medir)
		var plano := Vector2(d.x, d.z).length()
		if _llego_baile or plano < 0.15:
			_llego_baile = true
			_bailar_en_puesto(delta)
			return
	if dist < 0.06 or (sobre_caballito and dist < 0.35):
		global_position = puesto
		velocidad = Vector3.ZERO
		sentada = true
		en_suelo = true
		altura_suelo = puesto.y
		modo_anim = 0
		_rumbo = rumbo if sobre_caballito else lerp_angle(_rumbo, rumbo, minf(8.0 * delta, 1.0))
		modelo.rotation = Vector3(0.0, _rumbo, 0.0)
		modelo.animar(delta, 0, 0.0)
		return
	sentada = false
	var rapidez := clampf(dist * 3.0, 1.5, 10.0)
	velocidad = d / dist * rapidez
	global_position += velocidad * minf(delta, dist / rapidez)
	modo_anim = 1 if dist > 0.4 else 0
	_mirar(velocidad, delta, 8.0)
	modelo.animar(delta, modo_anim, 0.0 if dist < 0.4 else rapidez)


## Salta en arco hasta otro puesto (el otro lado del subibaja) y se queda ahí.
func saltar_a(m: Marker3D) -> void:
	caballito = m
	_salto_desde = global_position
	_salto_t = 0.0
	sentada = false


## Baila en su lugar (alrededor de la calesita): saltitos, giros y arrullos.
func _bailar_en_puesto(delta: float) -> void:
	sentada = true
	en_suelo = true
	altura_suelo = puesto.y
	_t_baile += delta
	_t_arrullo -= delta
	if _t_arrullo <= 0.0:
		_t_arrullo = randf_range(1.5, 4.0)
		if randf() < 0.5:
			modelo.arrullar()
	velocidad = Vector3.ZERO
	var salto := absf(sin(_t_baile * 5.0)) * 0.3
	global_position = puesto + Vector3(0.0, salto, 0.0)
	_rumbo += delta * 2.4 * (1.0 if get_instance_id() % 2 == 0 else -1.0)
	# Se mece de lado y mueve las alas mientras salta
	modelo.rotation = Vector3(sin(_t_baile * 2.5) * 0.15, _rumbo, sin(_t_baile * 5.0) * 0.22)
	modo_anim = 1 if salto > 0.05 else 0
	modelo.animar(delta, modo_anim, 0.0)


## Se levanta del puesto y vuelve a seguir a la bandada.
func levantar() -> void:
	caballito = null
	baila_afuera = false
	_llego_baile = false
	_salto_t = -1.0
	modelo.rotation = Vector3(0.0, _rumbo, 0.0)
	puesto = Vector3.INF
	sentada = false
	_timer_suelo = 0.0
	velocidad = Vector3(randf_range(-1.0, 1.0), 3.0, randf_range(-1.0, 1.0))


## Lo llama la bandada para mover a las seguidoras.
func mover_como_seguidora(delta: float, nueva_vel: Vector3, anim: int) -> void:
	velocidad = nueva_vel
	mover_con_choques(velocidad * delta)
	modo_anim = anim
	_actualizar_suelo(delta, 0.35)
	if global_position.y < altura_suelo:
		global_position.y = altura_suelo
		velocidad.y = maxf(velocidad.y, 0.0)
	en_suelo = global_position.y - altura_suelo < 0.05
	_mirar(velocidad, delta, 8.0)
	modelo.animar(delta, anim, Vector2(velocidad.x, velocidad.z).length())
