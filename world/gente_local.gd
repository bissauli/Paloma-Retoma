class_name GenteLocal
extends Node3D
## Los empleados y los clientes de un local de la planta baja (world/pasaje.gd):
## - Un EMPLEADO, parado detrás del mostrador (lo pone ahí PlanoLocal), mirando hacia la vidriera, con
##   el uniforme del rubro (delantal, guardapolvo, mameluco...) y moviéndose un poco de un lado al
##   otro, como quien atiende.
## - CLIENTES: no se inventan en la puerta. Son los paseantes de la ciudad (Humano de tipo "turista",
##   repartidos por todo el mapa en sus zonas de paseo): de vez en cuando uno que anda cerca y tiene la
##   vidriera a la vista se desvía, camina hasta el local, entra, mira dos o tres lugares (frente a los
##   estantes, las góndolas o las mesas), a veces pasa por el mostrador a pagar, sale y vuelve a pasear
##   por su zona (Humano.visita). Antes cada cliente aparecía y desaparecía en la vereda, a 7 m de la
##   vidriera, y pasaba por encima del macetón o por adentro de la pared.
## Adentro caminan por una grilla de puntos libres del piso (con un camino buscado a lo ancho, que esquiva
## los muebles). El empleado usa ModeloHumano y los clientes son Humano (los dos con su cápsula: la
## paloma los choca, no los atraviesa). Los clientes se llaman sólo con la paloma cerca (a menos de CERCA
## metros). Todo en coordenadas de la sala.

const CERCA := 45.0
const PASO_GRILLA := 0.5      ## Separación de los puntos del piso donde se puede estar
const HOLGURA := 0.45         ## Distancia mínima entre una persona y un mueble
const MAX_ADENTRO := 3        ## Cuántos clientes puede haber a la vez (llegando o adentro)
const VEREDA := 1.7           ## A cuánto de la vidriera se paran antes de entrar (y al salir)
const RADIO_LLAMADO := 40.0   ## De cuán lejos puede venir un paseante (con la vidriera a la vista)
const MAX_LLEGANDO := 50.0    ## Si en estos segundos no llegó a la vidriera (se trabó), sigue paseando
## Si no hay paseantes cerca, se "presta" uno de cualquier parte del mapa: aparece en una punta de la
## vereda, a esta distancia de la vidriera y siempre fuera de la vista, y al irse vuelve a su zona igual.
const PUNTA_VEREDA := Vector2(11.0, 24.0)
const LEJOS_DE_LA_PALOMA := 9.0   ## Ni de donde sale ni adonde llega puede estar más cerca de la paloma
const ESPERA_SALIDA := 15.0   ## Un prestado que en estos segundos no pudo irse busca otra punta de la vereda

## Quién atiende cada rubro (uno de los personajes de modelos/personas; si hay varios, uno al azar).
const EMPLEADOS := {
	"supermercado": ["almacenero"], "verduleria": ["almacenero"], "mecanico": ["barrendero"],
	"panaderia": ["cocinero"], "fiambreria": ["cocinero"], "libreria": ["almacenero", "oficinista_mujer"],
	"cafe": ["mozo"], "restaurante": ["mozo", "cocinero"], "consultorio": ["farmaceutica"], "oficina": ["oficinista", "oficinista_mujer"],
	"farmacia": ["farmaceutica"], "kiosco": ["almacenero"], "heladeria": ["estudiante"], "ferreteria": ["almacenero"],
	"peluqueria": ["oficinista_mujer", "bailarina"], "floreria": ["artesano", "abuela"],
}

enum Paso { MIRANDO, CAMINANDO }
## Caminando por la ciudad hasta la vidriera, adentro (y saliendo a la vereda), o yéndose por la vereda
## hasta perderse de vista (los prestados, que después vuelven a su zona)
enum Fase { LLEGANDO, ADENTRO, YENDOSE }

var ce: CasaEnterable
var _libres: PackedVector3Array = []        ## Puntos del piso donde se puede estar (sala)
var _indice := {}                           ## Vector2i de la grilla -> índice en _libres
var _clave := {}                            ## Índice en _libres -> Vector2i de la grilla
var _empleado: ModeloHumano
var _base_empleado := Vector3.ZERO
var _clientes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _proximo := 0.0                         ## Segundos hasta que llega el próximo cliente
var _puerta_adentro := -1                   ## Punto libre de la grilla junto a la vidriera
var _caja := -1                             ## Punto libre delante del mostrador (para pagar)
var _y_vereda := NAN                        ## Altura de la vereda (local), medida la primera vez
var entraron := 0                           ## Cuántos clientes entraron desde la vereda (para los tests)
var salieron := 0                           ## Cuántos salieron otra vez a la vereda
var llamados := 0                           ## Cuántos paseantes se desviaron hacia el local
var prestados := 0                          ## De esos, cuántos vinieron de lejos (ver _punta_oculta)


## Crea la gente del local "ce" (todo colgando de "sala").
static func poblar(sala: Node3D, ce_: CasaEnterable) -> GenteLocal:
	var g := GenteLocal.new()
	g.name = "Gente"
	g.ce = ce_
	g.set_meta(&"no_fusionar", true)
	sala.add_child(g)
	g._armar()
	return g


func _armar() -> void:
	_rng.seed = hash(ce.nombre)
	_buscar_libres()
	if _libres.is_empty():
		return
	# --- El empleado: donde lo dejó PlanoLocal (detrás del mostrador), mirando a la vidriera
	var quienes: Array = EMPLEADOS.get(ce.tema, ["almacenero"])
	_empleado = _persona(quienes[_rng.randi_range(0, quienes.size() - 1)], 0.0)
	_base_empleado = ce.get_meta(&"puesto_empleado", _libres[0])
	_empleado.position = _base_empleado
	_empleado.rotation.y = PI   # Mira hacia +Z (la vidriera): el modelo mira hacia -Z
	_empleado.actividad = _empleado.actividad_propia()   # Trabaja: ordena, revuelve, escribe, tipea...
	# --- La puerta (adentro) y la caja: los puntos libres más cercanos
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	_puerta_adentro = _mas_cercano(Vector3(ce.x_frente, 0, hz - 0.6))
	if not ce.mesas.is_empty():
		var m: Vector3 = ce.mesas[0]
		_caja = _mas_cercano(Vector3(m.x, 0, m.z + 1.1))
	# --- Los clientes son paseantes de la ciudad que se desvían hacia acá (ver _llamar_uno)
	_rng.randomize()   # De acá en adelante, cada partida distinta
	_proximo = _rng.randf_range(1.0, 4.0)


func _persona(personaje: String, alto: float) -> ModeloHumano:
	var m := ModeloHumano.new()
	m.personaje = personaje
	m.alto = alto
	add_child(m)
	return m


## Cuántos clientes hay ahora (llegando por la ciudad, adentro o saliendo).
func clientes() -> int:
	return _clientes.size()


## Cuántos clientes están adentro del local ahora.
func adentro() -> int:
	var n := 0
	for c in _clientes:
		if c["fase"] == Fase.ADENTRO:
			n += 1
	return n


## Llama a un paseante de la ciudad: uno de los que andan a menos de RADIO_LLAMADO de la vidriera y la
## tienen a la vista (así camina derecho, esquivando, sin meterse en un edificio), elegido al azar.
func _llamar_uno() -> void:
	if _puerta_adentro < 0:
		return
	var puerta := to_global(_frente_puerta())
	var candidatos: Array[Humano] = []
	for n in get_tree().get_nodes_in_group("humanos"):
		var h := n as Humano
		if h == null or not h.puede_visitar():
			continue
		var d := h.global_position.distance_to(puerta)
		if d > RADIO_LLAMADO or d < 1.0:
			continue
		# Con el camino libre para todo el cuerpo (antes era un rayo a la altura del pecho, que pasaba por
		# encima de lo bajo, y la prueba larga encontró gente empujando 50 s contra algo frente al café)
		if not _camino_libre(h.global_position, puerta):
			continue
		candidatos.append(h)
	var destino := _destino_al_azar(_puerta_adentro)
	var por_adentro := _camino(_puerta_adentro, destino)
	if por_adentro.is_empty():
		return
	var h: Humano = null
	var prestado := false
	var entrada := Vector3.ZERO
	if not candidatos.is_empty():
		h = candidatos[_rng.randi_range(0, candidatos.size() - 1)]
	else:
		# Nadie cerca: uno de cualquier parte del mapa, que entra por una punta de la vereda
		var punta := _punta_oculta()
		if is_nan(punta.x):
			return
		h = _paseante_oculto()
		if h == null:
			return
		h.global_position = punta
		h.reset_physics_interpolation()
		entrada = punta
		prestado = true
		prestados += 1
	h.visita = self
	var cam := PackedVector3Array([Vector3(ce.x_frente, 0.04, ce.fondo / 2.0 + 0.1), _libres[_puerta_adentro]])
	cam.append_array(por_adentro)
	_clientes.append({"h": h, "fase": Fase.LLEGANDO, "t": 0.0, "pos": Vector3.ZERO, "rumbo": 0.0, "rapidez": 0.0,
		"camino": cam, "paso": Paso.CAMINANDO, "espera": 0.0, "paradas": _rng.randi_range(1, 3), "pago": false,
		"saliendo": false, "fin": false, "mirar": _cosa_cercana(_libres[destino]),
		"vel": clampf(h.velocidad, 0.7, 1.2), "prestado": prestado, "salida": entrada})
	llamados += 1


## ¿Se ve "p" desde la cámara (o está muy cerca de la paloma)? Ahí no puede aparecer ni desaparecer nadie.
## Algo en el cuadro pero tapado por una pared o un edificio no se ve.
func _a_la_vista(p: Vector3) -> bool:
	var j := GameState.jugador
	if j and j.global_position.distance_to(p) < LEJOS_DE_LA_PALOMA:
		return true
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var cabeza := p + Vector3.UP * 1.2
	if not cam.is_position_in_frustum(cabeza):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cabeza, Construir.CAPA_MUNDO)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Una punta de la vereda (a un lado o al otro de la vidriera) fuera de la vista, con piso y sin nada
## encima, desde donde se ve la vidriera (así camina derecho hasta ella). NAN si no hay.
func _punta_oculta(solo_vereda := false) -> Vector3:
	var espacio := get_world_3d().direct_space_state
	var puerta := to_global(_frente_puerta())
	for intento in 10:
		var local: Vector3
		if intento % 3 == 2 and not solo_vereda:   # De enfrente (cruzando la calle o desde la plaza)
			local = Vector3(ce.x_frente + _rng.randf_range(-8.0, 8.0), 2.5, ce.fondo / 2.0 + _rng.randf_range(12.0, 24.0))
		else:                  # Por la vereda, desde una punta o la otra
			var lado := -1.0 if _rng.randf() < 0.5 else 1.0
			local = Vector3(ce.x_frente + lado * _rng.randf_range(PUNTA_VEREDA.x, PUNTA_VEREDA.y), 2.5, ce.fondo / 2.0 + VEREDA)
		var arriba := to_global(local)
		var r := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(arriba, arriba + Vector3.DOWN * 5.0, Construir.CAPA_MUNDO))
		if r.is_empty():
			continue
		var p: Vector3 = r["position"]
		if absf(p.y - puerta.y) > 0.6 or _a_la_vista(p):
			continue
		# Parado ahí no tiene que estar adentro de nada (un banco, un cantero, un auto estacionado)
		var cuerpo := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.6
		cuerpo.shape = cap
		cuerpo.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
		cuerpo.collision_mask = Construir.CAPA_MUNDO
		if not espacio.intersect_shape(cuerpo, 1).is_empty():
			continue
		if not _camino_libre(p, puerta):
			continue
		return p
	return Vector3(NAN, NAN, NAN)


## Otra punta de la vereda fuera de la vista a la que "h" llegue caminando derecho (ver _camino_libre).
## NAN si no hay.
func _otra_salida(h: Humano) -> Vector3:
	for intento in 6:
		var p := _punta_oculta(true)   # Por la misma vereda (no baja a la calle)
		if is_nan(p.x) or Enemigo.plano(p - h.global_position).length() < 3.0:
			continue
		if _camino_libre(h.global_position, p):
			return p
	return Vector3(NAN, NAN, NAN)


## ¿Puede caminar derecho de "desde" a "hasta" (en el piso)? Barre una cápsula del ancho de una persona,
## de los tobillos a la cabeza, hasta un poco antes de "hasta" (ahí está la vidriera o la vereda).
func _camino_libre(desde: Vector3, hasta: Vector3) -> bool:
	var tramo := Enemigo.plano(hasta - desde)
	var largo := tramo.length() - 0.6
	if largo <= 0.0:
		return true
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
	cap.height = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, desde + Vector3.UP * 1.0)   # De 0,25 a 1,75 m
	q.motion = tramo.normalized() * largo
	q.collision_mask = Construir.CAPA_MUNDO
	var r := get_world_3d().direct_space_state.cast_motion(q)
	return r.size() == 2 and r[0] >= 1.0


## Un paseante suelto de cualquier parte del mapa que no se esté viendo ahora (al azar).
func _paseante_oculto() -> Humano:
	var lista: Array[Humano] = []
	for n in get_tree().get_nodes_in_group("humanos"):
		var h := n as Humano
		if h and h.puede_visitar() and not _a_la_vista(h.global_position):
			lista.append(h)
	return null if lista.is_empty() else lista[_rng.randi_range(0, lista.size() - 1)]


## Deja de guiar a "h" (se cortó la visita desde afuera: Humano.terminar_visita).
func soltar(h: Humano) -> void:
	var c := _cliente_de(h)
	if not c.is_empty():
		_clientes.erase(c)


func _cliente_de(h: Humano) -> Dictionary:
	for c in _clientes:
		if c["h"] == h:
			return c
	return {}


## Mueve a un cliente (lo llama Humano mientras está de visita). Devuelve false cuando la visita terminó
## (salió a la vereda, o no llegó nunca): ahí el Humano vuelve a pasear por su zona.
func guiar(h: Humano, delta: float) -> bool:
	var c := _cliente_de(h)
	if c.is_empty():
		return false
	if c["fase"] == Fase.LLEGANDO:
		c["t"] = float(c["t"]) + delta
		if float(c["t"]) > MAX_LLEGANDO:
			if c["prestado"]:   # Lejos de su zona: espera a que nadie lo vea y vuelve
				c["fase"] = Fase.YENDOSE
				c["salida"] = h.global_position
				return true
			_clientes.erase(c)
			return false
		if h.caminar_hacia(to_global(_frente_puerta()), delta) < 0.35:
			c["fase"] = Fase.ADENTRO
			c["pos"] = to_local(h.global_position)
			c["rumbo"] = 0.0
			entraron += 1
		return true
	if c["fase"] == Fase.YENDOSE:
		# Un prestado se va por la vereda; cuando nadie lo ve, vuelve a su zona (de donde vino)
		var llego := h.caminar_hacia(c["salida"], delta) < 0.5
		# Si no puede terminar de irse (la están mirando ahí, o algo le tapa el paso) no se queda yendo y
		# viniendo: la prueba larga encontró uno 4 minutos así. Sigue hasta otra punta que no se vea
		c["t_salida"] = float(c.get("t_salida", 0.0)) + delta
		if float(c["t_salida"]) > ESPERA_SALIDA:
			c["t_salida"] = 0.0
			var otra := _otra_salida(h)
			if not is_nan(otra.x):
				c["salida"] = otra
			else:
				# Sin otra punta posible varias veces seguidas: deja de ser cliente y sigue paseando desde acá
				c["sin_salida"] = int(c.get("sin_salida", 0)) + 1
				if int(c["sin_salida"]) >= 3:
					_clientes.erase(c)
					return false
			return true
		if llego and not _a_la_vista(h.global_position):
			var zona := h.zona_centro
			if h.zona_tam != Vector2.ZERO:
				zona += Vector3(_rng.randf_range(-0.4, 0.4) * h.zona_tam.x, 0, _rng.randf_range(-0.4, 0.4) * h.zona_tam.y)
			if not h.nav_zona.is_empty():
				zona = Navegacion.mas_cercano(h.nav_zona, zona)
			if not _a_la_vista(zona):
				h.global_position = Vector3(zona.x, h.global_position.y, zona.z)
				h.reset_physics_interpolation()
				_clientes.erase(c)
				return false
		return true
	# Adentro (y saliendo hasta la vereda): lo lleva el local por la grilla, que esquiva los muebles
	_mover_cliente(c, delta)
	if c["fin"]:
		salieron += 1
		if c["prestado"]:   # Se va por donde vino (un camino que se sabe libre) y de ahí vuelve a su zona
			c["fase"] = Fase.YENDOSE
			return true
		_clientes.erase(c)
		return false
	h.poner_en(to_global(c["pos"]), global_rotation.y + float(c["rumbo"]), float(c["rapidez"]), delta)
	return true


# ---------------------------------------------------------------- La grilla

## Los puntos del piso (grilla) que no están dentro de ningún mueble ni pegados a las paredes.
func _buscar_libres() -> void:
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR - 0.5
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR - 0.5
	var ocupado: Array = ce.get_meta(&"ocupado", [])
	var ix := 0
	var x := -hx
	while x <= hx + 0.001:
		var iz := 0
		var z := -hz
		while z <= hz + 0.001:
			var p := Vector3(x, 0.04, z)
			if _punto_libre(p, ocupado):
				_indice[Vector2i(ix, iz)] = _libres.size()
				_clave[_libres.size()] = Vector2i(ix, iz)
				_libres.append(p)
			z += PASO_GRILLA
			iz += 1
		x += PASO_GRILLA
		ix += 1


func _punto_libre(p: Vector3, ocupado: Array) -> bool:
	for caja: Array in ce.cajas:
		var c: Vector3 = caja[0]
		var e: Vector3 = caja[1]
		if c.y - e.y > 1.9:
			continue   # Lo que cuelga del techo no molesta para caminar
		var q := (p - c).rotated(Vector3.UP, -float(caja[2]))
		if absf(q.x) < e.x + HOLGURA and absf(q.z) < e.z + HOLGURA:
			return false
	for o: Array in ocupado:
		if Vector2(float(o[0]) - p.x, float(o[1]) - p.z).length() < float(o[2]) + HOLGURA:
			return false
	return true


## ¿Se puede caminar en línea recta de "a" a "b" sin pasar por un mueble?
func _tramo_libre(a: Vector3, b: Vector3) -> bool:
	var ocupado: Array = ce.get_meta(&"ocupado", [])
	var n := int(ceil(a.distance_to(b) / 0.25))
	for i in range(1, n):
		if not _punto_libre(a.lerp(b, float(i) / n), ocupado):
			return false
	return true


func _mas_cercano(p: Vector3) -> int:
	var mejor := -1
	var mejor_d := INF
	for i in _libres.size():
		var d := Vector2(_libres[i].x - p.x, _libres[i].z - p.z).length()
		if d < mejor_d:
			mejor_d = d
			mejor = i
	return mejor


## El camino por la grilla (a lo ancho, con diagonales) de "a" a "b", ya enderezado: sólo quedan los
## puntos donde hace falta doblar (sin el de partida). Vacío si no hay camino.
func _camino(a: int, b: int) -> PackedVector3Array:
	var res := PackedVector3Array()
	if a < 0 or b < 0:
		return res
	var previo := {a: -1}
	var cola: Array[int] = [a]
	var cabeza := 0
	while cabeza < cola.size():
		var i := cola[cabeza]
		cabeza += 1
		if i == b:
			break
		var k: Vector2i = _clave[i]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var j: int = _indice.get(k + d, -1)
			if j < 0 or previo.has(j):
				continue
			if d.x != 0 and d.y != 0 and (not _indice.has(k + Vector2i(d.x, 0)) or not _indice.has(k + Vector2i(0, d.y))):
				continue   # En diagonal sólo si no corta una esquina
			previo[j] = i
			cola.append(j)
	if not previo.has(b):
		return res
	var lista: Array[Vector3] = []
	var i := b
	while i != -1:
		lista.push_front(_libres[i])
		i = previo[i]
	# Enderezar: de cada punto, al más lejano al que se llega derecho
	var k := 0
	while k < lista.size() - 1:
		var lejos := k + 1
		for j in range(lista.size() - 1, k + 1, -1):
			if _tramo_libre(lista[k], lista[j]):
				lejos = j
				break
		res.append(lista[lejos])
		k = lejos
	return res


## Un lugar para mirar algo: un punto libre pegado a un mueble (y no en la entrada ni en la caja).
func _destino_al_azar(desde: int) -> int:
	for intento in 30:
		var i := _rng.randi_range(0, _libres.size() - 1)
		var p := _libres[i]
		if i == desde or p.distance_to(_base_empleado) < 1.2 or (_caja >= 0 and i == _caja):
			continue
		if _cosa_cercana(p) == Vector3.INF or _ocupado_por_otro(p):
			continue
		return i
	return _rng.randi_range(0, _libres.size() - 1)


## El centro del mueble más cercano a "p" (si hay uno a menos de 1,1 m), para mirarlo.
func _cosa_cercana(p: Vector3) -> Vector3:
	var mejor := Vector3.INF
	var mejor_d := 1.1
	for caja: Array in ce.cajas:
		var c: Vector3 = caja[0]
		var e: Vector3 = caja[1]
		if c.y - e.y > 1.9:
			continue
		var q := (p - c).rotated(Vector3.UP, -float(caja[2]))
		var d := Vector2(maxf(absf(q.x) - e.x, 0.0), maxf(absf(q.z) - e.z, 0.0)).length()
		if d < mejor_d:
			mejor_d = d
			mejor = c
	return mejor


func _ocupado_por_otro(p: Vector3) -> bool:
	for c in _clientes:
		if c["fase"] != Fase.ADENTRO:
			continue
		if (c["pos"] as Vector3).distance_to(p) < 0.9:
			return true
		var cam: PackedVector3Array = c["camino"]
		if not cam.is_empty() and cam[cam.size() - 1].distance_to(p) < 0.9:
			return true
	return false


# ---------------------------------------------------------------- La vereda

## La altura de la vereda frente al local (local a la sala): se mide una vez con un rayo.
func _altura_vereda() -> float:
	if not is_nan(_y_vereda):
		return _y_vereda
	_y_vereda = 0.04
	var mundo := get_world_3d()
	if mundo == null:
		return _y_vereda
	var p := to_global(Vector3(ce.x_frente, 2.5, ce.fondo / 2.0 + VEREDA))
	var q := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 5.0, 1)
	var r := mundo.direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_y_vereda = to_local(r["position"]).y + 0.02
	return _y_vereda


## Dónde se para un cliente en la vereda antes de entrar (y adonde sale antes de volver a pasear).
func _frente_puerta() -> Vector3:
	return Vector3(ce.x_frente, _altura_vereda(), ce.fondo / 2.0 + VEREDA)


# ---------------------------------------------------------------- Cada cuadro

func _process(delta: float) -> void:
	# Los que dejaron de existir (un paseante que se fue del mapa) dejan su lugar
	for c in _clientes.duplicate():
		if not is_instance_valid(c["h"]):
			_clientes.erase(c)
	var j := GameState.jugador
	if j == null or _empleado == null or global_position.distance_to(j.global_position) > CERCA:
		return
	_t += delta
	# El empleado: se mueve apenas de un lado al otro detrás del mostrador
	var ancho: float = ce.get_meta(&"ancho_mostrador", 1.4)
	var quieto := _empleado.actividad in ["revolver", "escribir", "teclear"]   # Esos trabajan sin moverse del lugar
	var x := 0.0 if quieto else sin(_t * 0.4) * minf(0.35, ancho * 0.3)
	_empleado.position = _base_empleado + Vector3(x, 0, 0)
	_empleado.animar(delta, 0.0 if quieto else absf(cos(_t * 0.4)) * 0.14)
	# De vez en cuando se desvía hacia acá un paseante de la ciudad (los mueve guiar(), que llama el Humano)
	_proximo -= delta
	if _proximo <= 0.0:
		if _clientes.size() < MAX_ADENTRO:
			_llamar_uno()
		_proximo = _rng.randf_range(4.0, 10.0)


## Un paso de un cliente adentro del local (en coordenadas de la sala: "pos", "rumbo" y "rapidez", que
## guiar() le pasa al Humano).
func _mover_cliente(c: Dictionary, delta: float) -> void:
	var pos: Vector3 = c["pos"]
	if c["paso"] == Paso.MIRANDO:
		c["espera"] = float(c["espera"]) - delta
		c["rapidez"] = 0.0
		var mirar: Vector3 = c["mirar"]
		if mirar != Vector3.INF:
			var al := mirar - pos
			c["rumbo"] = lerp_angle(float(c["rumbo"]), atan2(-al.x, -al.z), minf(delta * 4.0, 1.0))
		if float(c["espera"]) <= 0.0:
			_siguiente(c)
		return
	var cam: PackedVector3Array = c["camino"]
	if cam.is_empty():
		_llego(c)
		return
	var destino := cam[0]
	var plano := Vector3(destino.x - pos.x, 0, destino.z - pos.z)
	var vel: float = c["vel"]
	if plano.length() < 0.05:
		c["pos"] = destino
		cam.remove_at(0)
		c["camino"] = cam
		return
	var paso := minf(vel * delta, plano.length())
	var dir := plano.normalized()
	pos += dir * paso
	pos.y = move_toward(pos.y, destino.y, delta * 0.8)
	c["pos"] = pos
	c["rumbo"] = lerp_angle(float(c["rumbo"]), atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))
	c["rapidez"] = vel


## Terminó de caminar: se queda mirando, o (si se estaba yendo) ya está en la vereda y sigue paseando.
func _llego(c: Dictionary) -> void:
	if c["saliendo"]:
		c["fin"] = true
		return
	_mirar(c)


func _mirar(c: Dictionary) -> void:
	c["paso"] = Paso.MIRANDO
	c["espera"] = _rng.randf_range(2.5, 6.0)
	if c["mirar"] == Vector3.INF:
		c["mirar"] = _cosa_cercana(c["pos"])


## Qué hace después de mirar: otro lugar, pagar en el mostrador o irse.
func _siguiente(c: Dictionary) -> void:
	var aca := _mas_cercano(c["pos"])
	c["paradas"] = int(c["paradas"]) - 1
	var cam := PackedVector3Array()
	if int(c["paradas"]) > 0:
		var i := _destino_al_azar(aca)
		cam = _camino(aca, i)
		c["mirar"] = _cosa_cercana(_libres[i])
	elif not c["pago"] and _caja >= 0 and _rng.randf() < 0.7 and not _ocupado_por_otro(_libres[_caja]):
		c["pago"] = true
		cam = _camino(aca, _caja)
		c["mirar"] = Vector3(_base_empleado.x, 1.0, _base_empleado.z)
	else:
		# Se va: a la puerta y afuera, a la vereda (de ahí vuelve a pasear por su zona)
		cam = _camino(aca, _puerta_adentro)
		if aca == _puerta_adentro or cam.is_empty():
			cam = PackedVector3Array([_libres[_puerta_adentro]])
		cam.append_array(PackedVector3Array([Vector3(ce.x_frente, 0.04, ce.fondo / 2.0 + 0.1), _frente_puerta()]))
		c["saliendo"] = true
	if cam.is_empty():
		c["espera"] = 1.5   # No encontró camino (o ya está ahí): sigue mirando un rato
		c["paso"] = Paso.MIRANDO
		return
	c["camino"] = cam
	c["paso"] = Paso.CAMINANDO
