class_name GenteLocal
extends Node3D
## Los empleados y los clientes de un local de la planta baja (world/pasaje.gd):
## - Un EMPLEADO, parado detrás del mostrador (lo pone ahí PlanoLocal), mirando hacia la vidriera, con
##   el uniforme del rubro (delantal, guardapolvo, mameluco...) y moviéndose un poco de un lado al
##   otro, como quien atiende.
## - CLIENTES que van y vienen: llegan caminando por la vereda, entran por la vidriera, miran dos o
##   tres lugares del local (frente a los estantes, las góndolas o las mesas), a veces pasan por el
##   mostrador a pagar, y se van otra vez por la vereda. Cada uno que entra es una persona nueva (otra
##   ropa, otra altura): el local nunca tiene siempre la misma gente.
## Caminan por una grilla de puntos libres del piso (con un camino buscado a lo ancho, que esquiva los
## muebles). Usan ModeloHumano (con su cápsula: la paloma los choca, no los atraviesa). Sólo se mueven
## cuando la paloma está cerca (a menos de CERCA metros). Todo en coordenadas de la sala.

const CERCA := 45.0
const PASO_GRILLA := 0.5      ## Separación de los puntos del piso donde se puede estar
const HOLGURA := 0.45         ## Distancia mínima entre una persona y un mueble
const VELOCIDAD := 0.9        ## m/s de los clientes
const MAX_ADENTRO := 3        ## Cuántos clientes puede haber a la vez
const VEREDA := 1.7           ## A cuánto de la vidriera caminan por la vereda
const LARGO_VEREDA := 7.0     ## Desde dónde llegan (y hasta dónde se van) por la vereda

## Uniforme del empleado por rubro: [color de la ropa, color de las piernas, accesorio, color del accesorio].
const UNIFORMES := {
	"supermercado": [Color("3f9a5a"), Color("2f3540"), "gorra", Color("3f9a5a")],
	"verduleria": [Color("6b8f3a"), Color("4a3a2a"), "ninguno", Color.WHITE],
	"mecanico": [Color("2f4f7f"), Color("2f4f7f"), "gorra", Color("c8423a")],
	"panaderia": [Color("f4f1e8"), Color("e8e2d2"), "mozo", Color("f4f1e8")],
	"fiambreria": [Color("f4f1e8"), Color("3a3c40"), "gorra", Color("b8423a")],
	"libreria": [Color("8a5a35"), Color("3a3f4a"), "ninguno", Color.WHITE],
	"cafe": [Color("2a2a2e"), Color("2a2a2e"), "mozo", Color("f4f1e8")],
	"restaurante": [Color("f4f1e8"), Color("2a2a2e"), "mozo", Color("f4f1e8")],
	"consultorio": [Color("f4f8f8"), Color("8fc4d8"), "ninguno", Color.WHITE],
	"oficina": [Color("2b4a6b"), Color("2a2a2e"), "ninguno", Color.WHITE],
	"farmacia": [Color("f4f8f8"), Color("3f9a5a"), "ninguno", Color.WHITE],
	"kiosco": [Color("c8423a"), Color("2f3540"), "gorra", Color("c8423a")],
	"heladeria": [Color("e88aa8"), Color("f4f1e8"), "gorra", Color("e88aa8")],
	"ferreteria": [Color("d8a03a"), Color("3a3f4a"), "ninguno", Color.WHITE],
	"peluqueria": [Color("2a2a2e"), Color("2a2a2e"), "ninguno", Color.WHITE],
	"floreria": [Color("4f8a3a"), Color("6b5a40"), "sombrero", Color("e8d6a0")],
}
const ROPA_CLIENTES := [Color("e8665a"), Color("4f7cc4"), Color("f0c84b"), Color("9a72d0"), Color("6fbf73"),
	Color("e89a4a"), Color("78bde8"), Color("e68aa8"), Color("8a8a96"), Color("3a6b5a"), Color("c8c0a8")]
const PIERNAS := [Color("3a3f4a"), Color("2f4a7a"), Color("5a4a3a"), Color("2a2a2e"), Color("7a6a55")]
const PIELES := [Color("e0b48f"), Color("c68e62"), Color("8d5a3b"), Color("f1cfae"), Color("a87048")]

enum Paso { MIRANDO, CAMINANDO }

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
var salieron := 0                           ## Cuántos se fueron por la vereda


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
	var u: Array = UNIFORMES.get(ce.tema, [Color("4f7cc4"), Color("3a3f4a"), "ninguno", Color.WHITE])
	_empleado = _persona(u[0], u[1], u[2], u[3], PIELES[_rng.randi_range(0, PIELES.size() - 1)], 1.72)
	_base_empleado = ce.get_meta(&"puesto_empleado", _libres[0])
	_empleado.position = _base_empleado
	_empleado.rotation.y = PI   # Mira hacia +Z (la vidriera): el modelo mira hacia -Z
	# --- La puerta (adentro) y la caja: los puntos libres más cercanos
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	_puerta_adentro = _mas_cercano(Vector3(ce.x_frente, 0, hz - 0.6))
	if not ce.mesas.is_empty():
		var m: Vector3 = ce.mesas[0]
		_caja = _mas_cercano(Vector3(m.x, 0, m.z + 1.1))
	# --- Algunos clientes ya están adentro al empezar (mirando algo); los demás van llegando
	_rng.randomize()   # De acá en adelante, cada partida distinta
	var cuantos := _rng.randi_range(1, 2)
	for k in cuantos:
		var i := _destino_al_azar(_puerta_adentro)
		if i >= 0:
			var c := _nuevo_cliente(_libres[i])
			c["paradas"] = _rng.randi_range(1, 2)
			_mirar(c)
	_proximo = _rng.randf_range(2.0, 6.0)


func _persona(ropa: Color, piernas: Color, acc: String, color_acc: Color, piel: Color, alto: float) -> ModeloHumano:
	var m := ModeloHumano.new()
	m.alto = alto
	m.color_ropa = ropa
	m.color_piernas = piernas
	m.color_piel = piel
	m.accesorio = acc
	m.color_accesorio = color_acc
	add_child(m)
	return m


## Un cliente nuevo (otra ropa, otra altura) parado en "pos".
func _nuevo_cliente(pos: Vector3) -> Dictionary:
	var acc := "ninguno"
	var r := _rng.randf()
	if r < 0.2:
		acc = "gorra"
	elif r < 0.3:
		acc = "sombrero"
	var m := _persona(ROPA_CLIENTES[_rng.randi_range(0, ROPA_CLIENTES.size() - 1)],
		PIERNAS[_rng.randi_range(0, PIERNAS.size() - 1)], acc,
		ROPA_CLIENTES[_rng.randi_range(0, ROPA_CLIENTES.size() - 1)],
		PIELES[_rng.randi_range(0, PIELES.size() - 1)], _rng.randf_range(1.55, 1.88))
	m.position = pos
	m.rotation.y = _rng.randf() * TAU
	var c := {"m": m, "camino": PackedVector3Array(), "paso": Paso.MIRANDO, "espera": 0.0,
		"paradas": _rng.randi_range(1, 3), "pago": false, "saliendo": false, "mirar": Vector3.INF,
		"vel": VELOCIDAD * _rng.randf_range(0.85, 1.15)}
	_clientes.append(c)
	return c


## Cuántos clientes hay ahora (adentro o en la vereda, llegando o yéndose).
func clientes() -> int:
	return _clientes.size()


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
		var m: ModeloHumano = c["m"]
		if m.position.distance_to(p) < 0.9:
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


## Por dónde se llega o se va por la vereda: a la izquierda o a la derecha de la vidriera.
func _punta_vereda(lado: float) -> Vector3:
	return Vector3(ce.x_frente + lado * LARGO_VEREDA, _altura_vereda(), ce.fondo / 2.0 + VEREDA)


func _frente_puerta() -> Vector3:
	return Vector3(ce.x_frente, _altura_vereda(), ce.fondo / 2.0 + VEREDA)


## Llega un cliente nuevo por la vereda, entra y va a mirar algo.
func _llega_uno() -> void:
	if _puerta_adentro < 0:
		return
	var destino := _destino_al_azar(_puerta_adentro)
	var adentro := _camino(_puerta_adentro, destino)
	if adentro.is_empty():
		return
	var lado := -1.0 if _rng.randf() < 0.5 else 1.0
	var c := _nuevo_cliente(_punta_vereda(lado))
	var cam := PackedVector3Array([_frente_puerta(), Vector3(ce.x_frente, 0.04, ce.fondo / 2.0 + 0.1),
		_libres[_puerta_adentro]])
	cam.append_array(adentro)
	c["camino"] = cam
	c["paso"] = Paso.CAMINANDO
	c["mirar"] = _cosa_cercana(_libres[destino])
	entraron += 1


# ---------------------------------------------------------------- Cada cuadro

func _process(delta: float) -> void:
	var j := GameState.jugador
	if j == null or _empleado == null or global_position.distance_to(j.global_position) > CERCA:
		return
	_t += delta
	# El empleado: se mueve apenas de un lado al otro detrás del mostrador
	var ancho: float = ce.get_meta(&"ancho_mostrador", 1.4)
	var x := sin(_t * 0.4) * minf(0.35, ancho * 0.3)
	_empleado.position = _base_empleado + Vector3(x, 0, 0)
	_empleado.animar(delta, absf(cos(_t * 0.4)) * 0.14)
	# Llegan clientes nuevos de a uno
	_proximo -= delta
	if _proximo <= 0.0:
		if _clientes.size() < MAX_ADENTRO:
			_llega_uno()
		_proximo = _rng.randf_range(4.0, 10.0)
	for c in _clientes.duplicate():
		_mover_cliente(c, delta)


func _mover_cliente(c: Dictionary, delta: float) -> void:
	var m: ModeloHumano = c["m"]
	if c["paso"] == Paso.MIRANDO:
		c["espera"] = float(c["espera"]) - delta
		m.animar(delta, 0.0)
		var mirar: Vector3 = c["mirar"]
		if mirar != Vector3.INF:
			var al := mirar - m.position
			m.rotation.y = lerp_angle(m.rotation.y, atan2(-al.x, -al.z), minf(delta * 4.0, 1.0))
		if float(c["espera"]) <= 0.0:
			_siguiente(c)
		return
	var cam: PackedVector3Array = c["camino"]
	if cam.is_empty():
		_llego(c)
		return
	var destino := cam[0]
	var plano := Vector3(destino.x - m.position.x, 0, destino.z - m.position.z)
	var vel: float = c["vel"]
	if plano.length() < 0.05:
		m.position = destino
		cam.remove_at(0)
		c["camino"] = cam
		return
	var paso := minf(vel * delta, plano.length())
	var dir := plano.normalized()
	m.position += dir * paso
	m.position.y = move_toward(m.position.y, destino.y, delta * 0.8)
	m.rotation.y = lerp_angle(m.rotation.y, atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))
	m.animar(delta, vel)


## Terminó de caminar: se queda mirando, o (si se estaba yendo) desaparece al final de la vereda.
func _llego(c: Dictionary) -> void:
	if c["saliendo"]:
		(c["m"] as Node).queue_free()
		_clientes.erase(c)
		salieron += 1
		return
	_mirar(c)


func _mirar(c: Dictionary) -> void:
	c["paso"] = Paso.MIRANDO
	c["espera"] = _rng.randf_range(2.5, 6.0)
	var m: ModeloHumano = c["m"]
	if c["mirar"] == Vector3.INF:
		c["mirar"] = _cosa_cercana(m.position)


## Qué hace después de mirar: otro lugar, pagar en el mostrador o irse.
func _siguiente(c: Dictionary) -> void:
	var m: ModeloHumano = c["m"]
	var aca := _mas_cercano(m.position)
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
		# Se va: a la puerta, afuera y por la vereda
		cam = _camino(aca, _puerta_adentro)
		if aca == _puerta_adentro or cam.is_empty():
			cam = PackedVector3Array([_libres[_puerta_adentro]])
		var lado := -1.0 if _rng.randf() < 0.5 else 1.0
		cam.append_array(PackedVector3Array([Vector3(ce.x_frente, 0.04, ce.fondo / 2.0 + 0.1), _frente_puerta(),
			_punta_vereda(lado)]))
		c["saliendo"] = true
	if cam.is_empty():
		c["espera"] = 1.5   # No encontró camino (o ya está ahí): sigue mirando un rato
		c["paso"] = Paso.MIRANDO
		return
	c["camino"] = cam
	c["paso"] = Paso.CAMINANDO
