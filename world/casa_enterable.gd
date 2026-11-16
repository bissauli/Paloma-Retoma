class_name CasaEnterable
extends Node3D
## Pasaje: una casa porteña que la paloma atraviesa volando. Tiene una ventana abierta adelante (a la
## plaza) y otra atrás (al callejón). Si la paloma se mete volando por cualquiera de las dos, salta
## una cinemática estilo Assassin's Creed 3: cruza el cuarto a toda velocidad en zigzag esquivando
## obstáculos (de costado, por arriba y por abajo) y sale disparada por la otra ventana.
##
## La cámara es UNA SOLA toma continua, sin cortes: arranca donde estaba la del juego, se pone detrás
## de la paloma y la persigue suavizada; en el esquive más difícil (el "destacado") todo pasa a cámara
## lenta y la cámara la rodea de costado, y al final vuelve sola a la cámara del juego.
## Se saltea con cualquier tecla, click o toque.
##
## Cada escenario (cuarto, ruta y obstáculos) lo arma world/pasaje.gd. Este nodo tiene la misma
## posición y rotación que la casa: la fachada mira hacia +Z local.

signal escena_terminada(desde_frente: bool)

const ESPESOR := 0.4          ## Grosor de las paredes
const AVISO := 3.0            ## Metros antes de la ventana en que arranca la cinemática
const VEL_MIN := 0.5          ## Velocidad mínima hacia la ventana para que cuente
const ENFRIAMIENTO := 1.5     ## Segundos sin volver a disparar después de una pasada
const CALLEJON := 4.0         ## Metros libres detrás de la casa (hasta el borde del mapa)
const VENTANA_ANCHO := 3.0
const VENTANA_Y0 := 1.4
const VENTANA_Y1 := 3.8
const Y_PASO := 2.6           ## Altura al pasar por las ventanas

const V_AFUERA := 15.0        ## m/s afuera
const V_ADENTRO := 11.5       ## m/s esquivando por adentro
const V_VENTANA := 7.5        ## m/s justo al pasar una ventana
const V_LENTA := 3.0          ## m/s en la cámara lenta del esquive destacado

var ancho := 12.0             ## Ancho de la casa (eje X local)
var fondo := 8.0              ## Profundidad (eje Z local)
var x_frente := -3.0          ## Centro de la ventana de adelante
var x_fondo := 3.0            ## Centro de la ventana de atrás
var ruta: Array[Vector3] = [] ## Por adentro, de la ventana de adelante a la de atrás (local)
var destacado := Vector3.ZERO ## Dónde está el esquive en cámara lenta (local)
var obstaculos := 0           ## Cuántos obstáculos hay adentro
var luz: OmniLight3D
var textos: Array[String] = []
var lado_callejon := 1.0      ## Hacia dónde dobla al salir al callejón (+1 = +X local)
var activa := false

var _cooldown := 0.0
var _saltear := false
var _t_cine := 0.0
var _corriendo := false
var _barras: BarrasCinematica
var _camara: CamaraCinematica
var _tutorial: Node
var _hud: CanvasLayer
var _jugador: PalomaJugador

var _curva: Curve3D
var _largo := 0.0
var _s := 0.0
var _s_entra := 0.0
var _s_sale := 0.0
var _s_destacado := 0.0
var _sonidos: Array[float] = []
var _sonado := 0
var _desde_frente := true
var _pos := Vector3.ZERO
var _dir := Vector3.FORWARD
var _dir_suave := Vector3.FORWARD
var _rumbo_ant := 0.0
var _alabeo := 0.0
var _cam_pos := Vector3.ZERO
var _cam_mira := Vector3.ZERO
var _cam_fov := 70.0
var _lado_orbita := 1.0


func _ready() -> void:
	add_to_group("casa_enterable")


## Curva suave que pasa por todos los puntos (la usan la cinemática y Pasaje, para que los
## obstáculos se ubiquen sobre la misma ruta que va a recorrer la paloma).
static func curva_de(pts: Array[Vector3]) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.08
	for i in pts.size():
		var t := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			t = (pts[i + 1] - pts[i - 1]) * 0.2
		elif i == 0 and pts.size() > 1:
			t = (pts[1] - pts[0]) * 0.3
		c.add_point(pts[i], -t, t)
	return c


## Todos los puntos de una pasada (locales): desde "inicio", por una ventana, la ruta de adentro, y
## afuera por la otra. Al salir al callejón dobla y sube; a la plaza, sube y se aleja.
func puntos_ruta(desde_frente: bool, inicio: Vector3) -> Array[Vector3]:
	var d := fondo
	var interior := ruta.duplicate()
	var pts: Array[Vector3] = [inicio]
	if desde_frente:
		if inicio.z > d / 2.0 + 1.6:
			pts.append(Vector3(x_frente, Y_PASO, d / 2.0 + 1.3))
		pts.append_array(interior)
		pts.append(Vector3(x_fondo, Y_PASO + 0.1, -d / 2.0 - 1.2))
		pts.append(Vector3(x_fondo + lado_callejon * 5.0, Y_PASO + 1.8, -d / 2.0 - 2.0))
	else:
		if inicio.z < -d / 2.0 - 1.6:
			pts.append(Vector3(x_fondo, Y_PASO, -d / 2.0 - 1.3))
		interior.reverse()
		pts.append_array(interior)
		pts.append(Vector3(x_frente, Y_PASO + 0.2, d / 2.0 + 1.6))
		pts.append(Vector3(x_frente, Y_PASO + 2.0, d / 2.0 + 7.0))
	return pts


## ¿Está este punto (global) dentro de la casa (entre las paredes, en la planta baja)?
func esta_adentro(punto: Vector3) -> bool:
	var p := to_local(punto)
	return absf(p.x) < ancho / 2.0 - ESPESOR and absf(p.z) < fondo / 2.0 - ESPESOR and p.y < 6.0


## La curva que recorrería la paloma entrando desde "inicio" (global). Para las pruebas.
func ruta_de_prueba(desde_frente: bool, inicio: Vector3) -> Curve3D:
	_armar_ruta(desde_frente, to_local(inicio))
	return _curva


# ---------------------------------------------------------------- Disparo

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var j := GameState.jugador
	if j == null:
		return
	if luz:
		luz.visible = global_position.distance_to(j.global_position) < 34.0
	if _corriendo:
		_avanzar(delta)
		return
	if activa or _cooldown > 0.0 or not _puede_disparar(j):
		return
	var p := to_local(j.global_position)
	if p.y < VENTANA_Y0 - 0.1 or p.y > VENTANA_Y1 - 0.25:
		return
	var v := global_transform.basis.inverse() * j.velocity
	var mitad := VENTANA_ANCHO / 2.0 + 0.3
	if absf(p.x - x_frente) <= mitad and p.z > fondo / 2.0 - 0.1 and p.z < fondo / 2.0 + AVISO and v.z < -VEL_MIN:
		_empezar(true)
	elif absf(p.x - x_fondo) <= mitad and p.z < -fondo / 2.0 + 0.1 and p.z > -fondo / 2.0 - AVISO and v.z > VEL_MIN:
		_empezar(false)


func _puede_disparar(j: PalomaJugador) -> bool:
	return GameState.en_partida and not GameState.menu_activo and not GameState.partida_terminada \
		and j.controlable and not j.en_escena


# ---------------------------------------------------------------- Ruta y velocidad

func _armar_ruta(desde_frente: bool, inicio: Vector3) -> void:
	_curva = curva_de(puntos_ruta(desde_frente, inicio))
	_largo = _curva.get_baked_length()
	var primera := ruta[0] if desde_frente else ruta[ruta.size() - 1]
	var ultima := ruta[ruta.size() - 1] if desde_frente else ruta[0]
	_s_entra = _curva.get_closest_offset(primera)
	_s_sale = _curva.get_closest_offset(ultima)
	_s_destacado = _curva.get_closest_offset(destacado)
	_sonidos = [_s_entra, _s_destacado, _s_sale]


## Velocidad sobre la curva, siempre continua (así no hay tirones): rápida afuera, un poco menos
## adentro, frena apenas al pasar cada ventana y entra en cámara lenta en el esquive destacado.
func _velocidad(s: float) -> float:
	var adentro := smoothstep(_s_entra - 2.0, _s_entra, s) * (1.0 - smoothstep(_s_sale, _s_sale + 2.0, s))
	var v := lerpf(V_AFUERA, V_ADENTRO, adentro)
	for w in [_s_entra, _s_sale]:
		v = minf(v, lerpf(V_VENTANA, V_AFUERA, smoothstep(0.2, 1.8, absf(s - float(w)))))
	return minf(v, lerpf(V_LENTA, V_AFUERA, smoothstep(0.3, 2.6, absf(s - _s_destacado))))


## 0..1: qué tanto estamos en la cámara lenta del destacado.
func _en_destacado(s: float) -> float:
	return 1.0 - smoothstep(0.0, 2.8, absf(s - _s_destacado))


# ---------------------------------------------------------------- Cinemática

func _empezar(desde_frente: bool) -> void:
	var j := GameState.jugador
	_jugador = j
	activa = true
	_saltear = false
	_t_cine = 0.0
	_sonado = 0
	_desde_frente = desde_frente
	_armar_ruta(desde_frente, to_local(j.global_position))
	_s = 0.0
	_rumbo_ant = j.rumbo()
	_alabeo = 0.0
	_pos = j.global_position
	_dir = (to_global(_curva.sample_baked(1.0, true)) - _pos).normalized()
	_dir_suave = _dir
	_lado_orbita = 1.0 if randf() < 0.5 else -1.0
	j.escena_empezar()
	j.camara.bloqueada = true
	GameState.invulnerable = maxf(GameState.invulnerable, 60.0)
	_hud = j.get_parent().get_node_or_null("HUD") as CanvasLayer
	if _hud:
		_hud.visible = false
	# El cartel flotante del tutorial no tiene que colarse en la cinemática
	_tutorial = j.get_parent().get_node_or_null("Tutorial")
	if _tutorial and _tutorial.has_method("pausar_cartel"):
		_tutorial.pausar_cartel(true)
	_barras = BarrasCinematica.new()
	add_child(_barras)
	_camara = CamaraCinematica.new()
	_camara.top_level = true
	add_child(_camara)
	var cam_juego := j.camara.camara
	_camara.empezar(cam_juego)
	_cam_pos = cam_juego.global_position
	_cam_mira = _cam_pos - cam_juego.global_transform.basis.z * 4.0
	_cam_fov = cam_juego.fov
	_barras.mostrar()
	if not textos.is_empty():
		_barras.texto(textos.pick_random())
	AudioManager.reproducir("aleteo")
	_corriendo = true


## Un paso de física: la paloma avanza sobre la curva, mirando hacia donde va, inclinándose en las
## curvas y cabeceando al subir o bajar. Al llegar al final (o si la saltean) termina.
func _avanzar(delta: float) -> void:
	if _saltear:
		_s = _largo
	var v := _velocidad(_s)
	_s = minf(_s + v * delta, _largo)
	var p := _curva.sample_baked(_s, true)
	var adelante := _curva.sample_baked(minf(_s + 0.5, _largo), true) - p
	if adelante.length() < 0.05:
		adelante = p - _curva.sample_baked(maxf(_s - 0.5, 0.0), true)
	_pos = to_global(p)
	_dir = (global_transform.basis * adelante).normalized()
	var plano := Vector2(_dir.x, _dir.z).length()
	var rumbo := atan2(-_dir.x, -_dir.z) if plano > 0.05 else _rumbo_ant
	var giro := wrapf(rumbo - _rumbo_ant, -PI, PI) / maxf(delta, 0.001)
	_rumbo_ant = rumbo
	# Alabeo y cabeceo suavizados: en el zigzag se nota la inclinación sin sacudones
	_alabeo = lerpf(_alabeo, clampf(giro * 0.22, -1.1, 1.1), 1.0 - exp(-10.0 * delta))
	var cabeceo := clampf(atan2(_dir.y, maxf(plano, 0.2)) * 0.9, -0.9, 0.7)
	var modo := 3 if v > 12.5 else (2 if v > 5.0 else 1)   # Picada / planeo / aleteo
	_jugador.escena_mover(_pos, rumbo, modo, v, cabeceo, _alabeo)
	if _sonado < _sonidos.size() and _s >= _sonidos[_sonado] - 0.4:
		_sonado += 1
		AudioManager.reproducir("aleteo", -2.0)
	if _s >= _largo:
		_corriendo = false
		_terminar()


## La cámara: una sola toma continua. Persigue a la paloma desde atrás con suavizado (la dirección
## también se suaviza, así no latiguea en cada zigzag), se abre el FOV con la velocidad y en el
## destacado la rodea de costado y se acerca. Adentro no se sale del cuarto.
func _process(delta: float) -> void:
	if not activa:
		return
	_t_cine += delta
	if not _corriendo or _saltear or _camara == null or _camara.estado != CamaraCinematica.Estado.QUIETA:
		return
	var p := _jugador.get_global_transform_interpolated().origin
	_dir_suave = _dir_suave.slerp(_dir, 1.0 - exp(-5.0 * delta)).normalized()
	var k := _en_destacado(_s)
	var atras := -_dir_suave * lerpf(2.4, 1.6, k)
	atras = atras.rotated(Vector3.UP, 1.75 * k * _lado_orbita)
	var objetivo := p + atras + Vector3.UP * lerpf(0.65, 0.3, k)
	if esta_adentro(p):
		var lo := to_local(objetivo)
		lo.x = clampf(lo.x, -ancho / 2.0 + ESPESOR + 0.35, ancho / 2.0 - ESPESOR - 0.35)
		lo.z = clampf(lo.z, -fondo / 2.0 + ESPESOR + 0.35, fondo / 2.0 - ESPESOR - 0.35)
		lo.y = clampf(lo.y, 0.5, 5.5)
		objetivo = to_global(lo)
	# Si un mueble se mete entre la paloma y la cámara, la cámara se pone delante (y se acerca rápido):
	# la paloma siempre queda a la vista
	var rapido := false
	var q := PhysicsRayQueryParameters3D.create(p, objetivo, 1, [_jugador.get_rid()])
	var choque := get_world_3d().direct_space_state.intersect_ray(q)
	if not choque.is_empty():
		var hasta := choque["position"] as Vector3
		objetivo = hasta + (p - hasta).normalized() * 0.3
		rapido = true
	_cam_pos = _cam_pos.lerp(objetivo, 1.0 - exp(-(22.0 if rapido else 7.0) * delta))
	_cam_mira = _cam_mira.lerp(p + _dir_suave * lerpf(1.8, 0.2, k), 1.0 - exp(-12.0 * delta))
	var rapidez := clampf(inverse_lerp(V_LENTA, V_AFUERA, _velocidad(_s)), 0.0, 1.0)
	_cam_fov = lerpf(_cam_fov, lerpf(64.0, 92.0, rapidez), 1.0 - exp(-4.0 * delta))
	_camara.corte(_cam_pos, _cam_mira, _cam_fov)


## Fin: la paloma sigue volando con el envión, la cámara del juego queda detrás de ella mirando
## hacia donde va y la de cine se funde con ella.
func _terminar() -> void:
	var j := _jugador
	var fin := to_global(_curva.sample_baked(_largo, true))
	var atras := to_global(_curva.sample_baked(maxf(_largo - 0.6, 0.0), true))
	var dir := (fin - atras).normalized()
	var rumbo := atan2(-dir.x, -dir.z)
	j.escena_terminar(fin, rumbo, true, Vector3(dir.x, 0.0, dir.z).normalized() * 11.0 + Vector3.UP * 1.5)
	j.camara.yaw = rumbo
	j.camara.pitch = -0.2
	j.camara.reubicar()
	j.camara.bloqueada = false
	if _camara.estado != CamaraCinematica.Estado.TERMINADA:
		_camara.volver(0.7)
		await _camara.llego
	_camara.queue_free()
	_camara = null
	_barras.ocultar()
	j.controlable = true
	GameState.invulnerable = 1.0
	if is_instance_valid(_hud) and _hud.has_method("mostrar"):
		_hud.mostrar()
	if is_instance_valid(_tutorial) and _tutorial.has_method("pausar_cartel"):
		_tutorial.pausar_cartel(false)
	_tutorial = null
	_hud = null
	activa = false
	_cooldown = ENFRIAMIENTO
	escena_terminada.emit(_desde_frente)


## Cualquier tecla (menos la pausa), click, toque o botón del mando saltea la cinemática.
func _input(event: InputEvent) -> void:
	if not activa or not _corriendo or _saltear or _t_cine < 0.6 or _camara == null:
		return
	var apretado := false
	if event is InputEventKey:
		apretado = event.pressed and not event.echo and not event.is_action("pausa")
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		apretado = event.is_pressed()
	if not apretado:
		return
	_saltear = true
	get_viewport().set_input_as_handled()
	_jugador.camara.bloqueada = false
	_camara.volver(0.6)
