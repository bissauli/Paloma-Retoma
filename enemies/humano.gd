class_name Humano
extends Enemigo
## Humano "pasivo": turistas, escolares, señoras, oficinistas, comensales, agentes y barrenderos.
## - turista/escolar: pasea por su zona y tira migas; con 15+ palomas se asusta y suelta comida.
## - senora: sentada en un banco, tira migas cada tanto (zona segura).
## - oficinista: sale del subte, camina hasta el borde del mapa y a veces se le cae una factura.
## - agente: parado en su esquina (guardia, y de a ratos ordena el tránsito). Un aletazo le vuela la gorra.
## - barrendero: barre despacio su zona con la escoba.
## - comensal: llega por la vereda de los cafés, se sienta a una mesa, come un rato (se le caen
##   migas) y se va. Los maneja enemies/gente.gd, que reparte las sillas.

signal se_levanto

@export_enum("turista", "escolar", "senora", "oficinista", "comensal", "agente", "barrendero") var tipo := "turista"
@export var velocidad := 1.1
@export var intervalo_migas := 6.0

var zona_centro := Vector3.ZERO
var zona_radio := 5.0
var zona_tam := Vector2.ZERO        ## Si no es cero, la zona es un rectángulo de este tamaño (peatonal, parque)
var generador: GeneradorMigas       ## A dónde van las migas que tira (lo asigna la escena)
var destino_final := Vector3.ZERO   ## Para oficinistas: a dónde va antes de desaparecer

var _destino := Vector3.ZERO
var _timer_paseo := 0.0
var _timer_migas := 0.0
var _miedo := 0.0
var _enfriamiento_susto := 0.0
var _soltar_factura_en := -1.0
var _altura := 0.0
var _por_sorpresa := false          ## Un aletazo le tiró el sombrero: se frena un rato con los brazos arriba
var _sorpresa := 0.0
var _rumbo_puesto := 0.0            ## Hacia dónde mira cuando está en su puesto (agente) o en su silla (comensal)

# Comensales
var ruta: Array[Vector3] = []       ## Puntos por los que camina (el último es la silla o la salida)
var asiento := Vector3.ZERO
var lado := 1.0                     ## De qué lado de la mesa está la silla (-1 oeste, +1 este)
var salida := Vector3.ZERO
var tiempo_comida := 30.0
var _comiendo := false
var _timer_bocado := 2.0

## Los paseantes de la ciudad entran a los locales de la planta baja (world/gente_local.gd): mientras
## dura la visita, el local lo guía (de su zona a la vidriera, por adentro y otra vez afuera).
var visita: GenteLocal = null
var va_a_locales := true            ## false: no lo llama ningún local (las pruebas que lo manejan a mano)
var _t_seguir_piso := 0.0           ## Segundos en que, de vuelta de un local, sigue la altura del piso
var _t_medir_piso := 0.0
# Oficinistas: cuánto les faltaba hace un rato para llegar a su salida (para darse cuenta si se trabaron)
var _t_progreso := 0.0
var _falta_antes := INF
var _intentos_salida := 0


## ¿Lo está viendo la cámara? (en el cuadro y sin una pared en el medio)
func _a_la_vista() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var cabeza := global_position + Vector3.UP * 1.2
	if cam.global_position.distance_to(cabeza) < 10.0:
		return true
	if not cam.is_position_in_frustum(cabeza):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cabeza, Construir.CAPA_MUNDO)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

@onready var modelo: ModeloHumano = $Modelo


func _ready() -> void:
	add_to_group("humanos")
	esquivar_obstaculos = tipo != "comensal"   # los comensales siguen su ruta hasta la silla, pegados a la mesa
	_timer_migas = randf() * intervalo_migas
	_destino = global_position
	_altura = global_position.y
	_rumbo = rotation.y
	rotation = Vector3.ZERO
	_rumbo_puesto = _rumbo
	if tipo == "agente":
		esquivar_obstaculos = false
	if tipo == "barrendero":
		velocidad = randf_range(0.35, 0.5)   # barre andando despacito
	if tipo == "oficinista":
		_destino = destino_final
		velocidad = randf_range(1.6, 2.1)
		if randf() < 0.55:
			_soltar_factura_en = randf_range(3.0, 9.0)


## Configura el aspecto según el tipo (llamar antes de agregarlo al árbol).
func preparar_aspecto() -> void:
	var m := get_node("Modelo") as ModeloHumano
	m.personaje = personaje_para(tipo)
	match tipo:
		"escolar":
			m.alto = randf_range(1.1, 1.3)
		"senora":
			m.sentado = true
			m.asiento_extra = ModeloHumano.EXTRA_BANCO   # las señoras se sientan en bancos
	# Un poco de variedad de altura entre los que se repiten
	if tipo != "escolar":
		m.alto = float(ModeloHumano.info(m.personaje).get("alto", 1.75)) * randf_range(0.96, 1.04)


## Qué personaje (modelos/personas) le toca a cada tipo de persona de la plaza.
static func personaje_para(t: String) -> String:
	match t:
		"turista":
			# Paseantes: más turistas y gente con sombrero o gorra (para los aletazos)
			return ["turista_gringo", "turista_gringo", "mochilera", "mochilera", "hincha", "hincha", "jubilado",
				"estudiante", "artesano", "bailarina"].pick_random()
		"escolar":
			return ["escolar", "escolar_nena"].pick_random()
		"senora":
			return ["abuela", "abuela", "jubilado"].pick_random()
		"oficinista":
			return ["oficinista", "oficinista_mujer"].pick_random()
		"agente":
			return "agente"
		"barrendero":
			return "barrendero"
		"comensal":
			return ["turista_gringo", "mochilera", "oficinista", "oficinista_mujer", "jubilado", "abuela", "estudiante",
				"artesano", "hincha", "bailarina"].pick_random()
	return ""


func _physics_process(delta: float) -> void:
	_enfriamiento_susto = maxf(_enfriamiento_susto - delta, 0.0)
	modelo.actividad = _actividad()
	if _atendiendo != null:
		_paso_conversando(delta)
		return
	if visita != null:
		if is_instance_valid(visita) and visita.guiar(self, delta):
			return
		terminar_visita()
	match tipo:
		"agente":
			# En su esquina: no se mueve; si lo sacaron de la mirada (sorpresa) vuelve a mirar hacia su puesto
			_rumbo = lerp_angle(_rumbo, _rumbo_puesto, minf(delta * 3.0, 1.0))
			modelo.rotation.y = _rumbo
			modelo.animar(delta, 0.0)
			return
		"barrendero":
			_pasear(delta)
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
				_rumbo = lerp_angle(_rumbo, _rumbo_puesto, minf(delta * 3.0, 1.0))
				modelo.rotation.y = _rumbo
				modelo.animar(delta, 0.0)
				return
			_paso_ruta(delta)
		_:
			_revisar_susto()
			_pasear(delta)
			_tirar_migas(delta)
	if _t_seguir_piso > 0.0:
		_t_seguir_piso -= delta
		_seguir_piso(delta)
	_avanzar(delta, _altura)
	_girar_hacia_velocidad(delta, 6.0)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), _miedo > 0.0)


## Lo que está haciendo ahora, para la animación del modelo ("" mientras habla, se asusta o se sorprende).
func _actividad() -> String:
	if _atendiendo != null or _miedo > 0.0:
		return ""
	match tipo:
		"agente":
			return "guardia"
		"barrendero":
			return "barrer"
		"comensal":
			return "comer" if _comiendo else ""
	return ""


## Hablando con la paloma (o sorprendido por un aletazo): se frena, la mira y deja de tirar migas
## hasta que termine. Si es una sorpresa levanta los brazos un rato y después sigue con lo suyo.
func _paso_conversando(delta: float) -> void:
	_mirar_al_atendido(delta)
	_miedo = 0.0
	if _por_sorpresa:
		_sorpresa -= delta
		if _sorpresa <= 0.0:
			_por_sorpresa = false
			_atendiendo = null
	if tipo != "senora" and not _comiendo:
		_acelerar(Vector3.ZERO, 6.0, delta)
		_avanzar(delta, _altura)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length(), _por_sorpresa)


func atender(con_quien: Node3D) -> void:
	_por_sorpresa = false
	super(con_quien)


## Un aletazo de la paloma le tira el sombrero o la gorra: sale volando (un objeto con física que
## después se desvanece) y la persona se queda sorprendida con los brazos arriba un par de segundos.
## Devuelve false si no llevaba nada en la cabeza.
func sombrerazo(dir: Vector3) -> bool:
	var color := modelo.color_accesorio
	var pos := modelo.posicion_sombrero()
	var malla := modelo.malla_sombrero()
	var tenia := modelo.quitar_sombrero()
	if tenia == "":
		return false
	sobresaltar()
	# Sale volando el mismo sombrero que tenía puesto (su malla), con la física de un sombrero o una gorra
	var s := Golpeable.crear(get_parent(), "gorra" if tenia == "gorra" else "sombrero", pos, color, 1.0, true, malla)
	s.golpear(dir, 1.6)
	return true


## Un aletazo lo sorprende (con o sin sombrero): deja lo que estaba haciendo (barrer, comer, dirigir el
## tránsito), levanta los brazos un par de segundos y después sigue. Al que está comiendo se le cae una miga.
func sobresaltar() -> void:
	if (_atendiendo != null and not _por_sorpresa) or Dialogos.activo:
		return
	_por_sorpresa = true
	_sorpresa = 2.2
	_atendiendo = GameState.jugador
	if _comiendo:
		Comida.soltar(get_parent(), "miga", Vector3(asiento.x - lado * randf_range(0.2, 0.5),
			asiento.y + 0.01, asiento.z + randf_range(-0.45, 0.45)), 45.0)


func _pasear(delta: float) -> void:
	if _miedo > 0.0:
		_miedo -= delta
		return  # Mientras huye mantiene la velocidad
	if nav_zona.is_empty():
		# Su zona de navegación: el rectángulo (o el cuadrado del círculo) por donde pasea, con un margen
		var tam := zona_tam if zona_tam != Vector2.ZERO else Vector2.ONE * zona_radio * 2.0
		nav_zona = Navegacion.zona(get_world_3d(), Vector3(zona_centro.x, _altura, zona_centro.z), tam + Vector2(2, 2))
	_timer_paseo -= delta
	if _timer_paseo <= 0.0:
		_timer_paseo = randf_range(2.5, 7.0)
		var a := randf() * TAU
		_destino = zona_centro + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * zona_radio
		if zona_tam != Vector2.ZERO:
			_destino = zona_centro + Vector3(randf_range(-0.5, 0.5) * zona_tam.x, 0, randf_range(-0.5, 0.5) * zona_tam.y)
		_destino = Navegacion.mas_cercano(nav_zona, _destino)   # nunca adentro de la fuente o de un banco
		if randf() < 0.4:
			_destino = global_position
	var hacia := plano(_proximo_punto(_destino, delta) - global_position)
	_acelerar(Vector3.ZERO if hacia.length() < 0.3 else hacia.normalized() * velocidad, 3.0, delta)


# ---------------------------------------------------------------- Visitas a los locales

## ¿Puede ir a un local ahora? Sólo los paseantes sueltos: no los que tienen algo que hacer (comensales,
## oficinistas, agentes, señoras en su banco, escolares con la maestra), ni los que hablan con la
## paloma, se asustaron o ya están en otro local.
func puede_visitar() -> bool:
	return va_a_locales and tipo == "turista" and visita == null and _atendiendo == null and _miedo <= 0.0 \
		and get_node_or_null("Interlocutor") == null and is_inside_tree()


## Camina hacia "destino" (global) por su cuenta, esquivando lo que tenga adelante y siguiendo la altura
## del piso. Devuelve la distancia que le falta (en el plano).
func caminar_hacia(destino: Vector3, delta: float) -> float:
	var falta := plano(destino - global_position).length()
	_ir_hacia(destino, velocidad if falta > 0.6 else velocidad * maxf(falta / 0.6, 0.3), 4.0, delta)
	_seguir_piso(delta)
	_avanzar(delta, _altura)
	_girar_hacia_velocidad(delta, 6.0)
	modelo.rotation.y = _rumbo
	modelo.animar(delta, _vel.length())
	return falta


## Lo ubica a mano (adentro del local lo mueve el local, por una grilla que esquiva los muebles).
func poner_en(pos: Vector3, rumbo: float, rapidez: float, delta: float) -> void:
	global_position = pos
	_altura = pos.y
	_vel = Vector3.ZERO
	_rumbo = rumbo
	modelo.rotation.y = _rumbo
	modelo.animar(delta, rapidez)


## Se terminó la visita (o el local dejó de existir): vuelve a pasear por su zona desde donde está.
func terminar_visita() -> void:
	if visita != null and is_instance_valid(visita):
		visita.soltar(self)   # Que el local no lo siga contando como cliente
	visita = null
	_vel = Vector3.ZERO
	_altura = global_position.y
	_destino = zona_centro
	_timer_paseo = 0.0
	_t_seguir_piso = 25.0   # Hasta volver a su zona puede pasar por veredas y escalones


## La altura del piso que tiene debajo (un rayo cada tanto, contra el mundo), para cuando camina fuera
## de su zona: la vereda de un local está más alta que la plaza.
func _seguir_piso(delta: float) -> void:
	_t_medir_piso -= delta
	if _t_medir_piso > 0.0:
		return
	_t_medir_piso = 0.25
	var desde := global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 1.6, Construir.CAPA_MUNDO)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_altura = move_toward(_altura, (r["position"] as Vector3).y, 0.3)


func _tirar_migas(delta: float) -> void:
	if generador == null or _miedo > 0.0:
		return
	_timer_migas -= delta
	if _timer_migas <= 0.0:
		tirar_migas_ya()


## Tira un puñado ahora mismo (el tutorial lo usa para que se vea en la cinemática).
func tirar_migas_ya() -> void:
	if generador == null:
		return
	_timer_migas = intervalo_migas * randf_range(0.6, 1.4)
	modelo.gesto_tirar()
	generador.tirar(modelo.posicion_mano())


## Con una bandada de 15 o más, los turistas (y escolares) salen corriendo y sueltan comida.
func _revisar_susto() -> void:
	if _miedo > 0.0 or _enfriamiento_susto > 0.0 or GameState.bandada < Config.UMBRAL_TURISTAS:
		return
	var j := GameState.jugador
	if j == null or j.global_position.distance_to(global_position) > 5.5:
		return
	asustar(j.global_position)
	# Suelta algo rico
	if randf() < 0.75:
		Comida.soltar(get_parent(), "papa" if randf() < 0.5 else "factura",
			Vector3(global_position.x, 0.02, global_position.z), 45.0)


func asustar(desde: Vector3) -> void:
	_miedo = 3.0
	_enfriamiento_susto = 25.0
	var lejos := global_position - desde
	lejos.y = 0
	_vel = lejos.normalized() * velocidad * 3.5
	AudioManager.reproducir_en("grito_nene", global_position, -8.0)


func _paso_oficinista(delta: float) -> void:
	var falta := plano(destino_final - global_position).length()
	if falta < 1.0:
		queue_free()
		return
	# Si en un rato no se acercó a su salida (se trabó contra algo: iba y venía o empujaba sin avanzar),
	# prueba otra; y si ya probó y nadie lo ve, se va (antes quedaban trabados para siempre)
	_t_progreso += delta
	if _t_progreso > 5.0:
		if falta > _falta_antes - 1.0:
			_intentos_salida += 1
			if _intentos_salida >= 2 and not _a_la_vista():
				queue_free()
				return
			var gente := get_parent()
			if gente and gente.has_method("salida_libre"):
				destino_final = gente.salida_libre(global_position)
		_t_progreso = 0.0
		_falta_antes = plano(destino_final - global_position).length()
	_ir_hacia(destino_final, velocidad, 3.0, delta)
	if _soltar_factura_en > 0.0:
		_soltar_factura_en -= delta
		if _soltar_factura_en <= 0.0:
			Comida.soltar(get_parent(), "factura", Vector3(global_position.x, 0.02, global_position.z), 40.0)


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
	_rumbo_puesto = _rumbo
	modelo.cambiar_postura(true)
	_timer_bocado = randf_range(1.0, 3.0)


func _paso_comer(delta: float) -> void:
	tiempo_comida -= delta
	_timer_bocado -= delta
	if _timer_bocado <= 0.0 and tiempo_comida > 1.0:
		_timer_bocado = randf_range(2.5, 5.5)
		# A veces se le cae una miga al piso (las palomas lo saben...)
		if randf() < 0.3:
			Comida.soltar(get_parent(), "miga", Vector3(asiento.x - lado * randf_range(0.2, 0.5),
				asiento.y + 0.01, asiento.z + randf_range(-0.45, 0.45)), 45.0)
	if tiempo_comida <= 0.0:
		_levantarse()


func _levantarse() -> void:
	_comiendo = false
	tiempo_comida = 0.0
	modelo.cambiar_postura(false)
	ruta = [Vector3(asiento.x, asiento.y, salida.z), salida]
	se_levanto.emit()
