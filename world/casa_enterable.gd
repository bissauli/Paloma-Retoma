class_name CasaEnterable
extends Node3D
## Una sala de un edificio (un local de la planta baja o un ambiente de un departamento), con una
## ventana abierta adelante y otra atrás. Se puede entrar libremente. En los departamentos, si la
## paloma está afuera frente a una ventana aparece un aviso (AvisoPasaje: "E · ATRAVESAR VOLANDO") y,
## si lo aprieta, salta una cinemática estilo Assassin's Creed 3: cruza el cuarto a toda velocidad en
## zigzag esquivando obstáculos (de costado, por arriba y por abajo) y sale por la otra ventana. En
## los locales (con_cinematica = false) no hay aviso ni cinemática.
##
## La cámara es UNA SOLA toma continua, sin cortes: arranca donde estaba la del juego y vuelve sola a
## ella al final. En el esquive más difícil (el "destacado") todo pasa a cámara lenta. Cada escenario
## tiene su coreografía ("estilo"), y adentro las cosas reaccionan al paso de la paloma:
## - PERSECUCION (librería): detrás de la paloma; en el destacado la rodea de costado (bullet time).
## - TIRABUZON (panadería): travelling lateral, y en el destacado la paloma da un giro de 360°.
## - GRUA (Doña Marta): la cámara barre desde los rincones altos del cuarto, como una grúa.
## - DE_FRENTE (oficina): la cámara va adelante, mirándola venir; de los escritorios vuelan papeles.
## - CENITAL (fiambrería): desde arriba; al pasar por los salames se roba uno y se lo lleva.
## Lo que cuelga del techo (lámparas, canastos, sábanas, salames) se hamaca cuando pasa cerca, y los
## ventiladores giran. Se saltea con cualquier tecla, click o toque.
##
## Cada escenario (cuarto, ruta y obstáculos) lo arma world/pasaje.gd. Este nodo tiene la misma
## posición y rotación que la casa: la fachada mira hacia +Z local.

signal escena_terminada(desde_frente: bool)

enum Estilo { PERSECUCION, TIRABUZON, GRUA, DE_FRENTE, CENITAL }

const ESPESOR := 0.4          ## Grosor de las paredes
const AVISO := 3.0            ## Metros antes de la ventana en que arranca la cinemática
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
const DIST_MIN := 1.6         ## De frente, la cámara de cine nunca se acerca más que esto a la paloma

var ancho := 12.0             ## Ancho de la casa (eje X local)
var fondo := 8.0              ## Profundidad (eje Z local)
var x_frente := -3.0          ## Centro de la ventana de adelante
var x_fondo := 3.0            ## Centro de la ventana de atrás
var ruta: Array[Vector3] = [] ## Por adentro, de la ventana de adelante a la de atrás (local)
var destacado := Vector3.ZERO ## Dónde está el esquive en cámara lenta (local)
var obstaculos := 0           ## Cuántos obstáculos hay adentro
var cajas: Array = []         ## Las cajas de los obstáculos: [centro, medias medidas, giro] (locales)
var luz: OmniLight3D
var sala_nodo: Node3D                   ## El nodo con todo lo de la sala (ver _mostrar_interior)
var _interior: Array[VisualInstance3D] = []
var _interior_listo := false
var _interior_visible := true
var textos: Array[String] = []
var lado_callejon := 1.0      ## Hacia dónde dobla al salir al callejón (+1 = +X local)
var activa := false
var estilo := Estilo.PERSECUCION       ## La coreografía de la cinemática
var nombre := ""                       ## El nombre del local (la placa de título)
var tema := ""                         ## Qué escenario es (ver Pasaje.ESCENARIOS)
var piso := 0                          ## En qué piso del edificio está la sala
var con_cinematica := true             ## Los locales de la planta baja no tienen (se recorren a pie)
var colgantes: Array[Node3D] = []      ## Pivotes de lo que cuelga del techo (se hamacan)
var mesas: Array[Vector3] = []         ## Tapas de las mesas (locales): de ahí vuelan los papeles
var salames: Array[Vector3] = []       ## Dónde cuelgan los salames (locales)
var robo := false                      ## ¿Se llevó un salame en la última pasada?

var _pendulos := {}            ## Pivote -> [ángulo x, velocidad x, ángulo z, velocidad z]
var _efectos_hechos := {}      ## Qué mesas ya soltaron papeles en esta pasada
var _salame: MeshInstance3D    ## El salame robado (en el pico)
var _esquina := Vector3.ZERO   ## Rincón actual de la cámara grúa (local)
var _lado_lat := 1.0           ## De qué lado va el travelling lateral
var _giro_extra := 0.0         ## El tirabuzón: vuelta entera sumada al alabeo
var _mezcla := 0.0             ## 0..1: de la persecución a la coreografía del escenario
var _vista := Vector3.ZERO     ## Hacia dónde mira la cámara (con su inercia de giro)
var _vista_vel := 0.0         ## Velocidad de giro de la mirada (rad/s)
var _quieta := Vector3.INF    ## El plano final: dónde se queda la cámara viendo cómo se aleja
var _salida := Vector3.INF    ## De frente: dónde espera la cámara a que salga (libre; ver _punto_salida)

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
var _cabeceo := 0.0
var _cam_pos := Vector3.ZERO
var _cam_vel := Vector3.ZERO      ## Velocidad del resorte de la posición de la cámara
var _cam_mira := Vector3.ZERO
var _mira_vel := Vector3.ZERO     ## Velocidad del resorte del punto al que mira
var _ocl := 1.0                   ## 0..1: cuánto se acerca la cámara si un mueble tapa a la paloma
var _subir := 0.0                 ## Metros que sube la cámara de frente para ver por encima de un mueble
var _da_orbita := INF             ## De frente: el giro de la órbita del cuadro anterior (para no saltar de lado)
var _cam_fov := 70.0
var _lado_orbita := 1.0


func _ready() -> void:
	add_to_group("casa_enterable")


## Curva suave que pasa por todos los puntos (la usan la cinemática y Pasaje, para que los
## obstáculos se ubiquen sobre la misma ruta que va a recorrer la paloma).
## Los manejadores de cada punto van en la dirección de la curva y miden un tercio del tramo de
## cada lado: así un tramo corto al lado de uno largo no hace un nudo ni un tirón.
static func curva_de(pts: Array[Vector3]) -> Curve3D:
	var c := Curve3D.new()
	c.bake_interval = 0.06
	var n := pts.size()
	for i in n:
		var h_in := Vector3.ZERO
		var h_out := Vector3.ZERO
		if i > 0 and i < n - 1:
			var dir := (pts[i + 1] - pts[i - 1]).normalized()
			h_in = -dir * pts[i].distance_to(pts[i - 1]) * 0.34
			h_out = dir * pts[i].distance_to(pts[i + 1]) * 0.34
		elif i == 0 and n > 1:
			h_out = (pts[1] - pts[0]) * 0.34
		elif i == n - 1 and n > 1:
			h_in = (pts[n - 2] - pts[n - 1]) * 0.34
		c.add_point(pts[i], h_in, h_out)
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
		pts.append(Vector3(x_fondo + lado_callejon * 11.0, Y_PASO + 3.6, -d / 2.0 - 2.4))   # Se aleja (plano final)
	else:
		if inicio.z < -d / 2.0 - 1.6:
			pts.append(Vector3(x_fondo, Y_PASO, -d / 2.0 - 1.3))
		interior.reverse()
		pts.append_array(interior)
		pts.append(Vector3(x_frente, Y_PASO + 0.2, d / 2.0 + 1.6))
		pts.append(Vector3(x_frente, Y_PASO + 2.0, d / 2.0 + 7.0))
		pts.append(Vector3(x_frente, Y_PASO + 3.0, d / 2.0 + 9.5))   # Se aleja (plano final; más lejos, el Cabildo)
	return pts


## ¿Está este punto (global) dentro de la casa (entre las paredes, en la planta baja)?
## El nombre de la placa de título en el idioma actual. Los departamentos son "Nombre · 3.º B"
## (ver Pasaje.alrededores): se traducen el nombre y el piso por separado.
func _titulo_traducido() -> String:
	var i := nombre.find(" · ")
	if i < 0:
		return tr(nombre)
	var piso_letra := nombre.substr(i + 3).split(".º ")
	var resto := nombre.substr(i + 3)
	if piso_letra.size() == 2 and piso_letra[0].is_valid_int():
		resto = tr("%d.º %s") % [int(piso_letra[0]), piso_letra[1]]
	return "%s · %s" % [tr(nombre.left(i)), resto]


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
	var cerca := global_position.distance_to(j.global_position) < 34.0
	_mostrar_interior(cerca or activa or _corriendo)
	if luz:
		luz.visible = cerca
		luz.shadow_enabled = activa   # Sombras de los muebles sólo mientras pasa la paloma (cuestan)
	if cerca or activa:
		_animar_colgantes(delta)
	if _corriendo:
		_avanzar(delta)
		return
	# La cinemática ya no arranca sola: se puede entrar libremente. Cerca de una ventana (por afuera)
	# aparece el aviso "E · ATRAVESAR VOLANDO" (AvisoPasaje) y sólo si lo aprieta arranca.
	if activa or _cooldown > 0.0 or not con_cinematica or not _puede_disparar(j):
		AvisoPasaje.soltar(self)
		return
	var lado := _ventana_cerca(j)
	if lado == 0:
		AvisoPasaje.soltar(self)
	else:
		AvisoPasaje.ofrecer(self, lado > 0, global_position.distance_to(j.global_position))


## Lo que hay adentro del cuarto (muebles, adornos, gente: lo que no se fusionó con el edificio) sólo se
## dibuja cuando la paloma está cerca o pasando por la sala. Desde lejos el cuarto no se ve (las
## ventanas son chicas), y dibujarlo costaba más de 200 llamadas de dibujo en toda la ciudad.
## Lo de afuera (toldo, cartel, marcos de las ventanas) se queda siempre.
func _mostrar_interior(ver: bool) -> void:
	if sala_nodo == null or not is_instance_valid(sala_nodo):
		return
	if not _interior_listo:
		_interior_listo = true      # Se arma recién en el primer paso de física, cuando la fusión ya terminó
		var hx := ancho / 2.0 - ESPESOR
		var hz := fondo / 2.0 - ESPESOR
		for n in sala_nodo.find_children("*", "VisualInstance3D", true, false):
			var vi := n as VisualInstance3D
			if vi is Light3D or not vi.is_visible_in_tree():
				continue
			var p := sala_nodo.to_local(vi.global_position)
			if absf(p.x) < hx - 0.05 and absf(p.z) < hz - 0.05 and p.y > -0.05 and p.y < 3.6:
				_interior.append(vi)
		_interior_visible = true
	if ver == _interior_visible:
		return
	_interior_visible = ver
	for vi in _interior:
		if is_instance_valid(vi):
			vi.visible = ver


## ¿La paloma está afuera, frente a una de las ventanas (a menos de AVISO metros y a su altura)?
## +1 = la de adelante, -1 = la de atrás, 0 = ninguna.
func _ventana_cerca(j: PalomaJugador) -> int:
	var p := to_local(j.global_position)
	if p.y < VENTANA_Y0 - 1.2 or p.y > VENTANA_Y1 + 0.4:
		return 0
	var mitad := VENTANA_ANCHO / 2.0 + 0.6
	if absf(p.x - x_frente) <= mitad and p.z > fondo / 2.0 + 0.05 and p.z < fondo / 2.0 + AVISO:
		return 1
	if absf(p.x - x_fondo) <= mitad and p.z < -fondo / 2.0 - 0.05 and p.z > -fondo / 2.0 - AVISO:
		return -1
	return 0


## Arranca la cinemática (la llama AvisoPasaje cuando la jugadora aprieta el botón).
func empezar_por_boton(desde_frente: bool) -> void:
	if activa or _cooldown > 0.0 or not con_cinematica:
		return
	var j := GameState.jugador
	if j == null or not _puede_disparar(j):
		return
	AvisoPasaje.soltar(self)
	_empezar(desde_frente)


## Lo que cuelga del techo: péndulos amortiguados. Cuando la paloma pasa cerca (por debajo) les da
## un empujón en la dirección en que vuela; los ventiladores giran siempre.
func _animar_colgantes(delta: float) -> void:
	var lp := to_local(_pos) if _corriendo else Vector3(INF, INF, INF)
	var lv := global_transform.basis.inverse() * (_dir * _velocidad(_s)) if _corriendo else Vector3.ZERO
	for piv in colgantes:
		if piv.has_meta(&"gira"):
			piv.rotation.y += delta * 7.0
			continue
		var st: Array = _pendulos.get(piv, [0.0, 0.0, 0.0, 0.0])
		if _corriendo and Vector2(lp.x - piv.position.x, lp.z - piv.position.z).length() < 1.4 \
				and not piv.has_meta(&"empujado"):
			piv.set_meta(&"empujado", true)
			# Un objeto que cuelga hacia abajo: girar en +Z lo lleva a +X; girar en +X lo lleva a -Z
			st[3] += clampf(lv.x, -12.0, 12.0) * 0.12
			st[1] -= clampf(lv.z, -12.0, 12.0) * 0.12
		var w2 := 9.8 / maxf(float(piv.get_meta(&"largo", 1.5)), 0.5)
		for k in [0, 2]:
			st[k + 1] += (-w2 * float(st[k]) - 1.3 * float(st[k + 1])) * delta
			st[k] = clampf(float(st[k]) + float(st[k + 1]) * delta, -0.7, 0.7)
		_pendulos[piv] = st
		piv.rotation = Vector3(st[0], piv.rotation.y, st[2])


## Papeles que vuelan de una mesa (la oficina): un estallido de hojas que caen planeando.
func _papeles(en: Vector3) -> void:
	var p := CPUParticles3D.new()
	var hoja := QuadMesh.new()
	hoja.size = Vector2(0.16, 0.21)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("fbfbf6")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hoja.material = mat
	p.mesh = hoja
	p.amount = 22
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 2.6
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.angular_velocity_min = -280.0
	p.angular_velocity_max = 280.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.particle_flag_rotate_y = true
	p.local_coords = false
	add_child(p)
	p.position = en + Vector3.UP * 0.1
	p.emitting = true
	get_tree().create_timer(3.2).timeout.connect(p.queue_free)


## Se roba un salame (la fiambrería): le aparece en el pico y lo lleva hasta un rato después de salir.
func _robar_salame() -> void:
	robo = true
	var pico := _jugador.modelo.find_child("Pico", true, false) as Node3D
	_salame = MeshInstance3D.new()
	_salame.mesh = Kit.malla("salame_suelto")
	_salame.material_override = Kit.material()
	(pico if pico else _jugador.modelo).add_child(_salame)
	_salame.position = Vector3(0, -0.02, 0.05)
	_salame.rotation = Vector3(PI / 2.0, 0, 0)
	_salame.scale = Vector3.ONE * 0.6
	if _barras:
		_barras.texto("¡Se robó un salame!")
	AudioManager.reproducir("recoger", -2.0, false)


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


## Curvatura horizontal de la ruta en "s" (radianes por metro, con signo: positiva doblando a la
## izquierda), medida en un tramo de 1,2 m para que sea suave.
func _curvatura(s: float) -> float:
	var a := _curva.sample_baked(maxf(s - 0.6, 0.0), true)
	var b := _curva.sample_baked(s, true)
	var c := _curva.sample_baked(minf(s + 0.6, _largo), true)
	var d1 := Vector2(b.x - a.x, b.z - a.z)
	var d2 := Vector2(c.x - b.x, c.z - b.z)
	if d1.length() < 0.05 or d2.length() < 0.05:
		return 0.0
	# Con el eje Z hacia el sur, un giro positivo de rumbo (atan2(-x, -z)) es doblar a la izquierda
	return -d1.angle_to(d2) / ((d1.length() + d2.length()) * 0.5)


## Resorte con amortiguación crítica (como SmoothDamp): sigue al objetivo sin pasarse ni tironear,
## aunque el objetivo pegue un salto. Devuelve [posición, velocidad].
static func _resorte(actual: Vector3, objetivo: Vector3, vel: Vector3, tiempo: float, delta: float) -> Array:
	var omega := 2.0 / maxf(tiempo, 0.0001)
	var x := omega * delta
	var ex := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var cambio := actual - objetivo
	var temp := (vel + cambio * omega) * delta
	return [objetivo + (cambio + temp) * ex, (vel - temp * omega) * ex]


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
	_lado_lat = 1.0
	_esquina = Vector3.ZERO
	_giro_extra = 0.0
	_mezcla = 0.0
	_vista_vel = 0.0
	_quieta = Vector3.INF
	_salida = Vector3.INF
	_efectos_hechos.clear()
	robo = false
	if is_instance_valid(_salame):
		_salame.queue_free()
	for piv in colgantes:
		piv.remove_meta(&"empujado")
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
	_cam_vel = j.velocity   # La cámara arranca con el envión que traía, sin frenar de golpe
	_mira_vel = j.velocity
	_ocl = 1.0
	_subir = 0.0
	_da_orbita = INF
	_cabeceo = 0.0
	_barras.mostrar()
	if nombre != "":
		_barras.titulo(_titulo_traducido())
	_vista = -cam_juego.global_transform.basis.z
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
	_rumbo_ant = rumbo
	# Alabeo como un ave de verdad: sale de la curvatura de la ruta y de la velocidad (aceleración
	# lateral v²·k), no de la diferencia de rumbo entre cuadros (que es ruidosa). Suavizado.
	var k := _curvatura(_s)
	var objetivo_alabeo := clampf(atan(v * v * k / 9.8) * 0.85, -1.05, 1.05)
	_alabeo = lerpf(_alabeo, objetivo_alabeo, 1.0 - exp(-7.0 * delta))
	_cabeceo = lerpf(_cabeceo, clampf(atan2(_dir.y, maxf(plano, 0.2)) * 0.9, -0.9, 0.7), 1.0 - exp(-8.0 * delta))
	var cabeceo := _cabeceo
	var modo := 3 if v > 12.5 else (2 if v > 5.0 else 1)   # Picada / planeo / aleteo
	# Tirabuzón (panadería): una vuelta entera de costado alrededor del esquive destacado
	if estilo == Estilo.TIRABUZON:
		var t := clampf((_s - (_s_destacado - 1.6)) / 3.2, 0.0, 1.0)
		# En ±180° (se ve igual): así al soltarla no queda una vuelta guardada que se "desenrosque"
		_giro_extra = wrapf(TAU * smoothstep(0.0, 1.0, t) * _lado_orbita, -PI, PI)
		if t > 0.0 and t < 1.0:
			modo = 3
	_jugador.escena_mover(_pos, rumbo, modo, v, cabeceo, _alabeo + _giro_extra)
	# Efectos al pasar: papeles que vuelan de las mesas (oficina) y el salame robado (fiambrería)
	var lp := p
	if estilo == Estilo.DE_FRENTE:
		for i in mesas.size():
			if not _efectos_hechos.has(i) and Vector2(lp.x - mesas[i].x, lp.z - mesas[i].z).length() < 1.5:
				_efectos_hechos[i] = true
				_papeles(mesas[i])
	if estilo == Estilo.CENITAL and not robo:
		for s in salames:
			if Vector2(lp.x - s.x, lp.z - s.z).length() < 1.4:
				_robar_salame()
				break
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
	# La dirección de la cámara mira un poco hacia adelante en la ruta: anticipa cada vuelta del
	# zigzag en vez de correr detrás de ella
	var aqui := _curva.sample_baked(_s, true)
	var adelante := _curva.sample_baked(minf(_s + 2.5, _largo), true) - aqui
	var dir_obj := (global_transform.basis * adelante).normalized() if adelante.length() > 0.2 else _dir
	_dir_suave = _dir_suave.slerp(dir_obj, 1.0 - exp(-3.5 * delta)).normalized()
	var k := _en_destacado(_s)
	var adentro := esta_adentro(p)
	# Afuera (llegando y saliendo) persigue; adentro, cada escenario con su coreografía. No cambia de
	# golpe: la mezcla entre las dos se arma en 0,8 s al entrar y se desarma al salir (o, de frente,
	# antes de llegar a la pared), así la cámara viaja sin pasar a través de la paloma
	var hacia_estilo := adentro and estilo != Estilo.PERSECUCION
	if estilo == Estilo.DE_FRENTE and _s > _s_sale:
		hacia_estilo = true   # De frente termina afuera, en la ventana de salida, mirándola salir
	_mezcla = move_toward(_mezcla, 1.0 if hacia_estilo else 0.0, delta / 1.5)
	var w := smoothstep(0.0, 1.0, _mezcla)
	var plan := _plano(p, k, Estilo.PERSECUCION)
	if w > 0.0:
		var otro := _plano(p, k, estilo, w)
		if estilo == Estilo.DE_FRENTE:
			plan = otro   # Ya viene mezclado: es una órbita alrededor de la paloma
		else:
			plan = [(plan[0] as Vector3).lerp(otro[0], w), (plan[1] as Vector3).lerp(otro[1], w), lerpf(plan[2], otro[2], w)]
	var objetivo: Vector3 = plan[0]
	var mira_obj: Vector3 = plan[1]
	var tiempo: float = plan[2]
	if adentro:
		var lo := to_local(objetivo)
		# De frente la cámara sale por la ventana antes que la paloma: no se la traba contra la pared
		# del fondo (si no, la paloma se le viene encima y queda pegada a la lente)
		var por_ventana := estilo == Estilo.DE_FRENTE \
			and absf(lo.x - _x_ventana_salida()) < VENTANA_ANCHO / 2.0 + 1.6 \
			and signf(lo.z) == (-1.0 if _desde_frente else 1.0)
		lo.x = clampf(lo.x, -ancho / 2.0 + ESPESOR + 0.35, ancho / 2.0 - ESPESOR - 0.35)
		if not por_ventana:
			lo.z = clampf(lo.z, -fondo / 2.0 + ESPESOR + 0.35, fondo / 2.0 - ESPESOR - 0.35)
		lo.y = clampf(lo.y, 0.5, 5.5)
		objetivo = to_global(lo)
	# Si un mueble se mete entre la paloma y la cámara, la cámara se acerca (rápido al taparse, despacio
	# al destaparse, como el resorte de la cámara del juego): la paloma siempre queda a la vista
	var ocl_obj := 1.0
	var q := PhysicsRayQueryParameters3D.create(p, objetivo, 1, [_jugador.get_rid()])
	var choque := get_world_3d().direct_space_state.intersect_ray(q)
	# De frente, si un mueble alto (archivero, planta) tapa, la cámara sube por encima en vez de
	# acercarse: la paloma se sigue viendo entera. La altura extra también va con resorte
	var subir_obj := 0.0
	if estilo == Estilo.DE_FRENTE and adentro and not choque.is_empty():
		for extra: float in [0.5, 1.0, 1.5]:
			var alto := objetivo + Vector3.UP * extra
			if to_local(alto).y > 5.4:
				break
			q = PhysicsRayQueryParameters3D.create(p, alto, 1, [_jugador.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				subir_obj = extra
				choque = {}
				break
	_subir = lerpf(_subir, subir_obj, 1.0 - exp(-(6.0 if subir_obj > _subir else 1.5) * delta))
	objetivo += Vector3.UP * _subir
	if not choque.is_empty():
		var largo := p.distance_to(objetivo)
		# Nunca a menos de 1 m de la paloma: más cerca, cualquier movimiento suyo sería un giro brusco.
		# De frente, 2,4 m: ahí un mueble que la tapa un instante es parte del plano, y pegarse a ella no
		var minimo := 2.4 if estilo == Estilo.DE_FRENTE else 1.0
		ocl_obj = clampf((p.distance_to(choque["position"] as Vector3) - 0.3) / maxf(largo, 0.01), minf(minimo / maxf(largo, 0.01), 1.0), 1.0)
	# (De frente se acerca más despacio: la tapa un mueble que pasa, no hace falta saltar hacia ella)
	var de_frente := estilo == Estilo.DE_FRENTE
	_ocl = lerpf(_ocl, ocl_obj, 1.0 - exp(-((5.0 if de_frente else 25.0) if ocl_obj < _ocl else (2.5 if de_frente else 3.0)) * delta))
	objetivo = p + (objetivo - p) * _ocl
	# Plano final: ya afuera, la cámara se queda (frenando suave) y la ve alejarse
	# (De frente ya tiene su lugar fijo afuera, al costado de la ventana de salida)
	if _s > _s_sale + 1.2 and estilo != Estilo.DE_FRENTE:
		if _quieta == Vector3.INF:
			_quieta = _cam_pos + _cam_vel * 0.3
		objetivo = _quieta
		mira_obj = p
		tiempo = 0.35
	# Un resorte que persigue algo que se mueve siempre queda atrás (velocidad × tiempo: a 11 m/s,
	# más de 3 m). Detrás de la paloma no importa, pero de frente ese atraso hacía que la paloma
	# alcanzara a la cámara y quedara pegada a la lente. Por eso de frente el resorte trabaja "viajando
	# con la paloma": sólo suaviza dónde está la cámara alrededor de ella, sin quedar atrás. Cuando
	# la cámara se va a su lugar fijo de afuera, vuelve de a poco al resorte común
	var v_ref := Vector3.ZERO
	if estilo == Estilo.DE_FRENTE:
		v_ref = _dir_suave * _velocidad(_s) * w * (1.0 - _saliendo())
	# Resortes con amortiguación crítica: la cámara acelera y frena suave, nunca de golpe. La
	# posición, un poco más blanda (como una cámara en mano con estabilizador)
	var r := _resorte(_cam_pos, objetivo, _cam_vel - v_ref, tiempo * 1.4, delta)
	_cam_pos = (r[0] as Vector3) + v_ref * delta
	_cam_vel = (r[1] as Vector3) + v_ref
	if estilo == Estilo.DE_FRENTE:
		_mantener_distancia(p)
	if adentro:
		_no_salir_del_cuarto()
	var cerca := clampf(inverse_lerp(1.6, 0.7, _cam_pos.distance_to(p)), 0.0, 1.0)
	var m := _resorte(_cam_mira, mira_obj, _mira_vel, lerpf(0.1, 0.22, cerca), delta)
	_cam_mira = m[0]
	_mira_vel = m[1]
	var rapidez := clampf(inverse_lerp(V_LENTA, V_AFUERA, _velocidad(_s)), 0.0, 1.0)
	_cam_fov = lerpf(_cam_fov, lerpf(64.0, 88.0, rapidez), 1.0 - exp(-2.5 * delta))
	# De frente la cámara da vueltas alrededor de la paloma y al final la ve pasar al costado: ahí la
	# mirada gira más rápido para no perderla de cuadro
	var giro_max := lerpf(210.0, 260.0, _saliendo()) if estilo == Estilo.DE_FRENTE else 150.0
	_girar_vista(_cam_mira - _cam_pos, deg_to_rad(giro_max), delta)
	_camara.corte(_cam_pos, _cam_pos + _vista * 4.0, _cam_fov)


## Mientras la paloma está adentro, la cámara no sale del cuarto (ni la saca el resorte ni el empuje
## que la aleja de la paloma): si se pasa de una pared vuelve al borde y pierde la velocidad hacia
## afuera. La única excepción: salir por la ventana de salida en el estilo de frente.
func _no_salir_del_cuarto() -> void:
	var lo := to_local(_cam_pos)
	var vl := global_transform.basis.inverse() * _cam_vel
	var mx := ancho / 2.0 - ESPESOR - 0.3
	var mz := fondo / 2.0 - ESPESOR - 0.3
	var por_ventana := estilo == Estilo.DE_FRENTE and absf(lo.x - _x_ventana_salida()) < VENTANA_ANCHO / 2.0 - 0.2 \
		and signf(lo.z) == (-1.0 if _desde_frente else 1.0) and lo.y > VENTANA_Y0 and lo.y < VENTANA_Y1
	if absf(lo.x) > mx:
		lo.x = clampf(lo.x, -mx, mx)
		vl.x = 0.0
	if absf(lo.z) > mz and not por_ventana:
		lo.z = clampf(lo.z, -mz, mz)
		vl.z = 0.0
	if lo.y < 0.4 or lo.y > Pasaje.PLANTA_BAJA - 0.4:
		lo.y = clampf(lo.y, 0.4, Pasaje.PLANTA_BAJA - 0.4)
		vl.y = 0.0
	_cam_pos = to_global(lo)
	_cam_vel = global_transform.basis * vl


## De frente la cámara nunca se pega a la paloma: si el resorte la trae a menos de DIST_MIN (al dar
## la vuelta alrededor de ella, o cuando un mueble la tapa), se la corre hacia afuera. Así la órbita
## es un arco y no una cuerda que pasa rozándola.
func _mantener_distancia(p: Vector3) -> void:
	var rel := _cam_pos - p
	var dist := rel.length()
	if dist >= DIST_MIN:
		return
	var afuera := rel / dist if dist > 0.01 else -_dir_suave
	_cam_pos = p + afuera * DIST_MIN
	# Se le saca la velocidad que la acercaba a la paloma (relativa a la paloma, que también se
	# mueve): así se desliza alrededor de ella en vez de chocar y rebotar contra el límite
	var v_paloma := _dir * _velocidad(_s)
	var hacia := (_cam_vel - v_paloma).dot(-afuera)
	if hacia > 0.0:
		_cam_vel += afuera * hacia


## La mirada de la cámara gira con inercia, como la de un camarógrafo: acelera y frena suave y no
## pasa de "maximo" rad/s. Así un cambio de dirección nunca es un latigazo.
func _girar_vista(deseada: Vector3, maximo: float, delta: float) -> void:
	if deseada.length() < 0.001:
		return
	deseada = deseada.normalized()
	if _vista.length() < 0.5:
		_vista = deseada
	var ang := _vista.angle_to(deseada)
	_vista_vel = move_toward(_vista_vel, minf(ang * 5.0, maximo), maximo * 4.0 * delta)
	var paso := minf(_vista_vel * delta, ang)
	if ang > 0.0001:
		_vista = _vista.slerp(deseada, paso / ang).normalized()


## Dónde quiere estar la cámara según la coreografía: [posición, punto al que mira, tiempo del
## resorte]. "p" es la paloma (global) y "k" cuánto estamos en el destacado (0..1).
func _plano(p: Vector3, k: float, cual: Estilo, w := 1.0) -> Array:
	var d := _dir_suave
	match cual:
		Estilo.TIRABUZON:
			# Travelling lateral: de costado, del lado con más lugar (cambia sólo si el otro es mucho mejor)
			var der := d.cross(Vector3.UP).normalized()
			var lados := [_lugar(p + der * 3.0), _lugar(p - der * 3.0)]
			var actual: float = lados[0] if _lado_lat > 0.0 else lados[1]
			var otro: float = lados[1] if _lado_lat > 0.0 else lados[0]
			if otro > actual + 0.8:
				_lado_lat = -_lado_lat
			return [p + der * _lado_lat * lerpf(3.0, 2.2, k) + Vector3.UP * 0.35 - d * 0.5, p + d * 0.6, 0.18]
		Estilo.GRUA:
			# Desde un rincón alto: el que mejor ve hacia donde va la paloma (cambia de rincón con
			# un barrido lento, como una grúa)
			var hacia := to_local(p + d * 3.5)
			var lp := to_local(p)
			var mejor := _esquina
			var mejor_d := INF if _esquina == Vector3.ZERO else _esquina.distance_to(hacia) - 1.2
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var e := Vector3(sx * (ancho / 2.0 - ESPESOR - 0.6), 5.0, sz * (fondo / 2.0 - ESPESOR - 0.6))
					var dist := e.distance_to(hacia)
					if Vector2(e.x - lp.x, e.z - lp.z).length() > 2.2 and dist < mejor_d:
						mejor = e
						mejor_d = dist
			_esquina = mejor
			return [to_global(_esquina), p + d * 0.4, 0.42]
		Estilo.DE_FRENTE:
			# Adelante, mirándola venir: la cámara va ~4 m más adelante SOBRE LA RUTA (que siempre está
			# adentro del cuarto, y al final sale por la ventana antes que ella), 1,5 m más alta: la ve
			# entera, un poco desde arriba, y la vista pasa por encima de los muebles que esquiva.
			# Se promedian varios puntos de la ruta: así no copia cada vuelta del zigzag.
			# Para pasar de atrás a adelante da la vuelta en órbita alrededor de la paloma: nunca la atraviesa
			var adelante := Vector3.ZERO
			for paso in [3.4, 4.0, 4.6]:
				adelante += to_global(_curva.sample_baked(minf(_s + paso, _largo), true)) / 3.0
			var v0 := -d * 2.4
			var v1 := adelante - p
			var a0 := atan2(v0.x, v0.z)
			var da := wrapf(atan2(v1.x, v1.z) - a0, -PI, PI)
			# Cuánto hay que girar alrededor de ella, sin saltos: entre ir por un lado o por el otro se
			# queda con el más parecido al del cuadro anterior (si no, cuando adelante y atrás quedan
			# justo opuestos la vuelta cambia de lado de golpe)
			var otro_lado := da - TAU * signf(da)
			if is_inf(_da_orbita):
				# La primera vez: si hay que dar media vuelta, por el lado con más lugar en el cuarto
				var medio := a0 + da / 2.0
				var medio_otro := a0 + otro_lado / 2.0
				if absf(da) > PI * 0.5 and _lugar(p + Vector3(sin(medio_otro), 0, cos(medio_otro)) * 3.0) \
						> _lugar(p + Vector3(sin(medio), 0, cos(medio)) * 3.0):
					da = otro_lado
			elif absf(otro_lado - _da_orbita) < absf(da - _da_orbita):
				da = otro_lado
			_da_orbita = da
			var ang := a0 + da * w
			# A mitad de la vuelta la órbita se abre un metro más: así la rodea con aire, sin rozarla
			var largo := lerpf(Vector2(v0.x, v0.z).length(), maxf(Vector2(v1.x, v1.z).length(), 3.2), w) + sin(PI * w) * 1.2
			var pos := p + Vector3(sin(ang) * largo, lerpf(0.6, v1.y + 1.5, w), cos(ang) * largo)
			# Llegando a la ventana de salida la cámara se va a su lugar de afuera, y desde ahí la ve
			# salir y alejarse
			var salir := _saliendo() * w
			pos = pos.lerp(_punto_salida(), salir)
			# Mientras da la vuelta mira a la paloma (no adelante de ella: de costado la dejaría afuera)
			return [pos, p + d * lerpf(1.6, 0.0, sqrt(w)) + Vector3.UP * 0.05, lerpf(0.22, 0.32, salir)]
		Estilo.CENITAL:
			# Desde arriba, un poco atrás, sin pasarse del techo
			var alto := clampf(5.4 - p.y, 1.4, 3.0)
			return [p + Vector3.UP * alto - d * lerpf(0.8, 0.3, k), p + d * 0.9, 0.16]
	# PERSECUCION: detrás; en el destacado la rodea de costado y se acerca (bullet time)
	var atras := (-d * lerpf(2.4, 1.6, k)).rotated(Vector3.UP, 1.75 * k * _lado_orbita)
	return [p + atras + Vector3.UP * lerpf(0.65, 0.3, k), p + d * lerpf(1.8, 0.2, k), 0.14]


## 0..1: de frente, cuánto se fue ya la cámara a su lugar de afuera de la ventana de salida.
func _saliendo() -> float:
	return smoothstep(_s_sale - 7.0, _s_sale - 1.5, _s)


## Centro (X local) de la ventana por la que sale la paloma en esta pasada.
func _x_ventana_salida() -> float:
	return x_fondo if _desde_frente else x_frente


## Dónde espera la cámara de frente (global) a que la paloma salga: afuera de la ventana de salida,
## a un costado. La ve salir y alejarse, y queda detrás de ella para devolverle el mando a la cámara
## del juego sin dar vueltas. Al callejón, contra el fondo y del lado contrario al que dobla; a la
## plaza, a un costado de la ventana.
## Como las salas están en un piso al azar, detrás puede haber otro edificio: se toma el primero de
## varios lugares (de lejos a cerca, y si no, adentro del cuarto junto a la ventana) que esté libre y
## desde el que se vea la ventana. Se calcula una vez por pasada.
func _punto_salida() -> Vector3:
	if _salida != Vector3.INF:
		return _salida
	var z := -1.0 if _desde_frente else 1.0
	var xv := x_fondo if _desde_frente else x_frente
	var costado := -lado_callejon if _desde_frente else _lado_orbita
	var candidatos := [
		Vector3(xv + costado * 2.3, Y_PASO + 1.2, z * (fondo / 2.0 + CALLEJON - 0.5)),
		Vector3(xv + costado * 1.8, Y_PASO + 1.0, z * (fondo / 2.0 + 2.0)),
		Vector3(xv + costado * 1.4, Y_PASO + 0.8, z * (fondo / 2.0 + 1.0)),
		Vector3(xv + costado * 1.6, Y_PASO + 1.3, z * (fondo / 2.0 - ESPESOR - 1.2)),   # Adentro, junto a la ventana
	]
	# En un piso alto, afuera puede haber cosas sin colisión (copas de árboles, adornos de otros
	# edificios) que la física no ve: ahí la cámara espera adentro, junto a la ventana, y la ve salir
	if piso > 0:
		candidatos.push_front(candidatos.pop_back())
	var espacio := get_world_3d().direct_space_state
	var ventana := to_global(Vector3(xv, Y_PASO, z * fondo / 2.0))
	_salida = to_global(candidatos[candidatos.size() - 1])
	for c: Vector3 in candidatos:
		var g := to_global(c)
		var punto := PhysicsPointQueryParameters3D.new()
		punto.position = g
		punto.collision_mask = 1
		if not espacio.intersect_point(punto, 1).is_empty():
			continue   # Adentro de algo (otro edificio, un árbol...)
		var rayo := PhysicsRayQueryParameters3D.create(g, ventana + (g - ventana).normalized() * 0.6, 1)
		if not espacio.intersect_ray(rayo).is_empty():
			continue   # No se ve la ventana
		_salida = g
		break
	return _salida


## Cuánto lugar hay en un punto (global) dentro del cuarto: distancia a la pared más cercana.
func _lugar(punto: Vector3) -> float:
	var l := to_local(punto)
	return minf(ancho / 2.0 - ESPESOR - absf(l.x), fondo / 2.0 - ESPESOR - absf(l.z))


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
	# La cámara del juego no se movió durante la escena: se la pone ya con su orientación final
	# (si no, gira de golpe en el primer cuadro y el fundido salta)
	j.camara.rotation = Vector3(j.camara.pitch, j.camara.yaw, 0.0)
	j.camara.reubicar()
	j.camara.bloqueada = false
	if _saltear:
		if _camara.estado != CamaraCinematica.Estado.TERMINADA:
			await _camara.llego
	else:
		# Durante el traspaso la cámara del juego sigue a la paloma más despacio (si no, arranca de
		# golpe detrás de ella); después vuelve de a poco a su suavizado normal
		var suave := j.camara.suavizado
		j.camara.suavizado = 4.0
		await _fundir(j.camara.camara)
		create_tween().tween_property(j.camara, "suavizado", suave, 1.2).set_trans(Tween.TRANS_SINE)
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
	if is_instance_valid(_salame):
		# El salame robado lo lleva un rato más y después se lo come
		get_tree().create_timer(2.5).timeout.connect(_salame.queue_free)
	escena_terminada.emit(_desde_frente)


## La cámara de cine se funde con la del juego sin frenar ni saltar. La del juego se mueve con la
## paloma, y un resorte que la persigue siempre queda atrás; por eso se mide la DIFERENCIA con ella
## (que se mueve junto con ella) y esa diferencia se achica con un resorte hasta cero. Arranca con la
## velocidad que traía la cámara de cine y termina exactamente en la del juego.
func _fundir(cam_juego: Camera3D) -> void:
	# Recién reubicada, la cámara del juego arranca casi quieta y acelera de a poco (persigue a la
	# paloma con su propio suavizado): la diferencia arranca con toda la velocidad de la de cine
	var vel_juego := Vector3.ZERO
	var off := _cam_pos - cam_juego.global_position
	var off_mira := _cam_mira - (cam_juego.global_position - cam_juego.global_transform.basis.z * 4.0)
	var off_vel := _cam_vel - vel_juego
	var off_mira_vel := _mira_vel - vel_juego
	var t := 0.0
	var antes := cam_juego.global_position
	while t < 3.0:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		t += dt
		# Arranca blando (sale del plano final sin tirón) y se va endureciendo para alcanzarla
		var r := _resorte(off, Vector3.ZERO, off_vel, lerpf(0.6, 0.22, smoothstep(0.0, 1.4, t)), dt)
		off = r[0]
		off_vel = r[1]
		var m := _resorte(off_mira, Vector3.ZERO, off_mira_vel, 0.2, dt)
		off_mira = m[0]
		off_mira_vel = m[1]
		# Esto corre antes de que la cámara del juego se mueva en este cuadro: se predice dónde va a
		# estar (si no, al pasarle el mando, la imagen saltaría un cuadro)
		var obj := cam_juego.global_position * 2.0 - antes
		antes = cam_juego.global_position
		_cam_pos = obj + off
		_cam_mira = obj - cam_juego.global_transform.basis.z * 4.0 + off_mira
		_cam_fov = lerpf(_cam_fov, cam_juego.fov, 1.0 - exp(-6.0 * dt))
		_girar_vista(_cam_mira - _cam_pos, deg_to_rad(170.0), dt)
		_camara.corte(_cam_pos, _cam_pos + _vista * 4.0, _cam_fov)
		var dir_juego := -cam_juego.global_transform.basis.z
		if off.length() < 0.01 and off_mira.length() < 0.02 and _vista.angle_to(dir_juego) < 0.005:
			break
	cam_juego.make_current()
	_camara.current = false


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
