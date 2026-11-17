class_name GenteLocal
extends Node3D
## Los empleados y los clientes de un local de la planta baja (world/pasaje.gd):
## - Un EMPLEADO, parado detrás del mostrador (el mueble "abajo" sobre la ruta, o lo propio del
##   lugar), mirando hacia la vidriera, con el uniforme del rubro (delantal, guardapolvo, mameluco...)
##   y moviéndose un poco de un lado al otro, como quien atiende.
## - De 1 a 3 CLIENTES, con ropa de colores, que caminan por el local de un lugar libre a otro (sólo
##   por tramos rectos que no cruzan ningún mueble) y se quedan un rato mirando los estantes.
## Usan ModeloHumano (con su cápsula: la paloma los choca, no los atraviesa). Sólo se mueven cuando la
## paloma está cerca (a menos de CERCA metros). Todo en coordenadas de la sala.

const CERCA := 45.0
const PASO_GRILLA := 0.5      ## Separación de los puntos del piso donde se puede estar
const HOLGURA := 0.45         ## Distancia mínima entre una persona y un mueble
const VELOCIDAD := 0.8        ## m/s de los clientes

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
	Color("e89a4a"), Color("78bde8"), Color("e68aa8"), Color("8a8a96")]
const PIELES := [Color("e0b48f"), Color("c68e62"), Color("8d5a3b"), Color("f1cfae"), Color("a87048")]

var ce: CasaEnterable
var _libres: PackedVector3Array = []        ## Puntos del piso donde se puede estar (sala)
var _empleado: ModeloHumano
var _base_empleado := Vector3.ZERO
var _clientes: Array = []                   ## [ModeloHumano, destino, espera]
var _rng := RandomNumberGenerator.new()
var _t := 0.0


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
	# --- El empleado: detrás del mostrador (lo más cerca de él del lado del fondo), mirando a la vidriera
	var mostrador := Vector3.INF
	if not ce.mesas.is_empty():
		mostrador = ce.mesas[0]
	var mejor := _libres[0]
	var mejor_d := INF
	for p in _libres:
		var d := p.distance_to(Vector3(mostrador.x, 0, mostrador.z - 0.9)) if mostrador != Vector3.INF else p.distance_to(Vector3(0, 0, -ce.fondo * 0.3))
		if d < mejor_d:
			mejor_d = d
			mejor = p
	var u: Array = UNIFORMES.get(ce.tema, [Color("4f7cc4"), Color("3a3f4a"), "ninguno", Color.WHITE])
	_empleado = _persona(u[0], u[1], u[2], u[3], PIELES[_rng.randi_range(0, PIELES.size() - 1)], 1.72)
	_base_empleado = mejor
	_empleado.position = mejor
	_empleado.rotation.y = PI   # Mira hacia +Z (la vidriera): el modelo mira hacia -Z
	# --- Los clientes, lejos del empleado
	var cuantos := _rng.randi_range(1, 3)
	var intentos := 0
	while _clientes.size() < cuantos and intentos < 40:   # Lejos del empleado y de los otros clientes
		intentos += 1
		var p := _libres[_rng.randi_range(0, _libres.size() - 1)]
		var cerca_de_otro := p.distance_to(mejor) < 1.3
		for otro: Array in _clientes:
			cerca_de_otro = cerca_de_otro or p.distance_to(otro[1]) < 0.9
		if cerca_de_otro:
			continue
		var c := _persona(ROPA_CLIENTES[_rng.randi_range(0, ROPA_CLIENTES.size() - 1)], Color("3a3f4a"),
			"gorra" if _rng.randf() < 0.25 else "ninguno", ROPA_CLIENTES[_rng.randi_range(0, ROPA_CLIENTES.size() - 1)],
			PIELES[_rng.randi_range(0, PIELES.size() - 1)], _rng.randf_range(1.55, 1.85))
		c.position = p
		c.rotation.y = _rng.randf() * TAU
		_clientes.append([c, p, _rng.randf_range(0.5, 3.0)])


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


## Los puntos del piso (grilla) que no están dentro de ningún mueble ni pegados a las paredes.
func _buscar_libres() -> void:
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR - 0.5
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR - 0.5
	var ocupado: Array = ce.get_meta(&"ocupado", [])
	var x := -hx
	while x <= hx:
		var z := -hz
		while z <= hz:
			var p := Vector3(x, 0.04, z)
			if _punto_libre(p, ocupado):
				_libres.append(p)
			z += PASO_GRILLA
		x += PASO_GRILLA


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


func _process(delta: float) -> void:
	var j := GameState.jugador
	if j == null or _empleado == null or global_position.distance_to(j.global_position) > CERCA:
		return
	_t += delta
	# El empleado: se mueve apenas de un lado al otro detrás del mostrador
	var x := sin(_t * 0.4) * 0.35
	_empleado.position = _base_empleado + Vector3(x, 0, 0)
	_empleado.animar(delta, absf(cos(_t * 0.4)) * 0.14)
	for c: Array in _clientes:
		_mover_cliente(c, delta)


func _mover_cliente(c: Array, delta: float) -> void:
	var m: ModeloHumano = c[0]
	var destino: Vector3 = c[1]
	var al := destino - m.position
	al.y = 0.0
	if al.length() < 0.05:
		# Mirando un estante: espera y elige otro lugar al que se pueda ir derecho
		c[2] = float(c[2]) - delta
		m.animar(delta, 0.0)
		if float(c[2]) <= 0.0:
			for intento in 8:
				var p := _libres[_rng.randi_range(0, _libres.size() - 1)]
				if p.distance_to(m.position) > 1.0 and p.distance_to(_empleado.position) > 1.2 and _tramo_libre(m.position, p):
					c[1] = p
					break
			c[2] = _rng.randf_range(2.0, 5.0)
		return
	var paso := minf(VELOCIDAD * delta, al.length())
	var dir := al.normalized()
	m.position += dir * paso
	m.rotation.y = lerp_angle(m.rotation.y, atan2(-dir.x, -dir.z), minf(delta * 8.0, 1.0))
	m.animar(delta, VELOCIDAD)
