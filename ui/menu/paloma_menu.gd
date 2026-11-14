class_name PalomaMenu
extends Node2D
## Paloma pixel-art del menú principal. Puede cruzar la pantalla volando
## o venir a posarse en un punto (el botón JUGAR), quedarse un rato y volver a irse.
## El origen del nodo son los pies de la paloma quieta.

signal se_va    ## La paloma posada ya quiere irse (el que la maneja decide hacia dónde)
signal se_fue   ## Ya salió de la pantalla

const FRAMES := preload("res://ui/menu/paloma_frames.tres")
## Dónde están los pies de la paloma quieta dentro del dibujo (todos los frames comparten lienzo).
const PIES := Vector2(75, 135)

enum Estado { CRUZANDO, LLEGANDO, POSADA, YENDOSE }

var estado := Estado.CRUZANDO

var _sprite: AnimatedSprite2D
var _t := 0.0
var _dur := 1.0
var _p0 := Vector2.ZERO
var _p1 := Vector2.ZERO
var _p2 := Vector2.ZERO
var _prev := Vector2.ZERO
# Cruce
var _vel := 220.0
var _base_y := 0.0
var _fase := 0.0
var _limite_x := 1400.0
var _planeando := 0.0
var _prox_planeo := 1.5
var _deriva := 0.0
# Posada
var _resto := 5.0
var _prox_gesto := 1.0


func _init() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.centered = false
	_sprite.offset = -PIES
	add_child(_sprite)
	_sprite.animation_finished.connect(_al_terminar_animacion)


# ---------------------------------------------------------------- Cruzar

## Cruza de izquierda a derecha a la altura `y`, hasta pasar `ancho` (coordenadas del padre).
func cruzar(y: float, velocidad: float, ancho: float) -> void:
	estado = Estado.CRUZANDO
	_vel = velocidad
	_base_y = y
	_limite_x = ancho + 160.0
	_fase = randf() * TAU
	_deriva = randf_range(-14.0, 10.0)
	_prox_planeo = randf_range(0.6, 2.4)
	position = Vector2(-160.0 * scale.x - 40.0, y)
	_sprite.play("vuelo")
	_sprite.frame = randi() % 6
	_sprite.speed_scale = randf_range(0.85, 1.2)


func _proceso_cruce(delta: float) -> void:
	_t += delta
	if _planeando > 0.0:
		_planeando -= delta
		_base_y += 16.0 * delta
		if _planeando <= 0.0:
			_sprite.play("vuelo")
			_prox_planeo = randf_range(1.2, 3.0)
	else:
		_prox_planeo -= delta
		_base_y -= 5.0 * delta
		if _prox_planeo <= 0.0:
			_planeando = randf_range(0.45, 0.9)
			_sprite.play("planeo")
	position.x += _vel * delta
	position.y = _base_y + sin(_t * 2.3 + _fase) * 7.0 + _deriva * _t
	if position.x > _limite_x:
		queue_free()


# ---------------------------------------------------------------- Posarse

## Viene volando desde `desde` y se posa en `destino` (coordenadas del padre).
func venir_a_posarse(desde: Vector2, destino: Vector2) -> void:
	estado = Estado.LLEGANDO
	_p0 = desde
	_p2 = destino
	# Entra en curva: pasa por arriba del destino y baja planeando
	_p1 = Vector2(lerpf(desde.x, destino.x, 0.75), minf(desde.y, destino.y) - 140.0)
	_dur = clampf(desde.distance_to(destino) / 420.0, 1.6, 3.2)
	_t = 0.0
	position = desde
	_prev = desde
	_sprite.play("vuelo")


## Se va volando hacia `hasta` (coordenadas del padre).
func irse(hasta: Vector2) -> void:
	if estado == Estado.YENDOSE:
		return
	estado = Estado.YENDOSE
	_p0 = position
	_p2 = hasta
	_p1 = Vector2(position.x + 60.0, position.y - 220.0)
	_dur = clampf(position.distance_to(hasta) / 520.0, 1.4, 2.8)
	_t = 0.0
	_sprite.scale = Vector2.ONE
	_sprite.play_backwards("posarse")
	AudioManager.reproducir("aleteo", -12.0)


func _proceso_llegada(delta: float) -> void:
	_t = minf(_t + delta / _dur, 1.0)
	var s := 1.0 - pow(1.0 - _t, 2.0)  # frena al llegar
	position = _bezier(s)
	if _t > 0.72 and _sprite.animation == &"vuelo":
		_sprite.play("planeo")
	if _t >= 1.0:
		position = _p2
		estado = Estado.POSADA
		_resto = randf_range(5.0, 8.0)
		_prox_gesto = randf_range(0.8, 1.6)
		_sprite.play("posarse")
		# Un rebotito al apoyar las patas
		_sprite.scale = Vector2(1.08, 0.9)
		create_tween().tween_property(_sprite, "scale", Vector2.ONE, 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _proceso_posada(delta: float) -> void:
	_resto -= delta
	_prox_gesto -= delta
	if _prox_gesto <= 0.0 and _sprite.animation == &"quieta":
		_prox_gesto = randf_range(1.2, 2.6)
		if randf() < 0.3:
			_sprite.play("mirar")
			get_tree().create_timer(randf_range(0.6, 1.1)).timeout.connect(_volver_a_quieta)
		else:
			_sprite.play("parpadeo")
	if _resto <= 0.0:
		se_va.emit()


func _proceso_salida(delta: float) -> void:
	_t = minf(_t + delta / _dur, 1.0)
	position = _bezier(_t * _t)  # arranca despacio y acelera
	if _t >= 1.0:
		se_fue.emit()
		queue_free()


func _bezier(s: float) -> Vector2:
	return _p0.lerp(_p1, s).lerp(_p1.lerp(_p2, s), s)


func _volver_a_quieta() -> void:
	if estado == Estado.POSADA and _sprite.animation == &"mirar":
		_sprite.play("quieta")


func _al_terminar_animacion() -> void:
	match _sprite.animation:
		&"posarse":
			# Hacia adelante = terminó de aterrizar; hacia atrás = ya despegó
			if estado == Estado.YENDOSE:
				_sprite.play("vuelo")
			else:
				_sprite.play("quieta")
		&"parpadeo":
			_sprite.play("quieta")


func _process(delta: float) -> void:
	match estado:
		Estado.CRUZANDO:
			_proceso_cruce(delta)
		Estado.LLEGANDO:
			_proceso_llegada(delta)
		Estado.POSADA:
			_proceso_posada(delta)
		Estado.YENDOSE:
			_proceso_salida(delta)
	# Se inclina un poco según para dónde va
	if estado != Estado.POSADA:
		var v := position - _prev
		if v.length() > 0.01:
			rotation = lerp_angle(rotation, clampf(atan2(v.y, maxf(absf(v.x), 0.01)) * 0.45, -0.4, 0.4), 0.15)
	else:
		rotation = lerp_angle(rotation, 0.0, 0.3)
	_prev = position
