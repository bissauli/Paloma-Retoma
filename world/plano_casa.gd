class_name PlanoCasa
extends RefCounted
## Cómo se acomodan los muebles de un ambiente de departamento (world/pasaje.gd), como en una casa de
## verdad y no tirados sobre la ruta en zigzag de la cinemática (como PlanoLocal con los locales):
## - Lo grande y alto, contra las paredes y lejos de las ventanas: roperos, bibliotecas, alacenas,
##   heladera, vajillero.
## - Lo que va junto, junto: la cama con la cabecera contra la pared y una mesita de luz a cada lado, la
##   mesa con sus sillas alrededor mirándola, el sillón con la mesa ratona y la alfombra adelante y el
##   mueble de la tele enfrente, la mesada, la cocina y la heladera en fila contra la pared.
## - Plantas en los rincones.
## La cinemática sigue igual: la paloma cruza volando a 2 m o más, así que lo bajo queda debajo de la
## ruta; cada mueble se valida contra las dos pasadas (con el mismo margen que antes, Pasaje.MARGEN) y
## si no entra prueba otro lugar sobre la misma pared, y si no, no va. Lo que cuelga del techo sobre la
## ruta (lámparas, sábanas, el móvil) lo sigue poniendo Pasaje._obstaculos.
## Todo en coordenadas de la sala (la ventana de adelante mira a +Z; los muebles miran a su +Z).

const ALTO_MAX := 2.5        ## Lo alto se achica a esto (como Pasaje.DECO_ALTO_MAX: no tapa el cuarto a la cámara)
const AIRE := 0.06           ## Separación de la pared
const LIBRE_VENTANA := 1.6   ## Hondo libre delante de cada ventana (por ahí entra y sale la paloma)
const MESAS := ["mesa_comedor", "escritorio_pc", "mesa_mate", "mesa_ratona"]

var sala: Node3D
var ce: CasaEnterable
var hx := 0.0
var hz := 0.0
var ruta: PackedVector3Array
var puestos := 0
var ultimo := Vector3.ZERO   ## Dónde quedó el último mueble puesto (para poner lo que va junto a él)


## Arma el ambiente. Devuelve cuántos muebles puso.
static func armar(sala_: Node3D, ce_: CasaEnterable, tema: String) -> int:
	var p := PlanoCasa.new()
	p.sala = sala_
	p.ce = ce_
	p.hx = ce_.ancho / 2.0 - CasaEnterable.ESPESOR
	p.hz = ce_.fondo / 2.0 - CasaEnterable.ESPESOR
	p.ruta = Pasaje._muestras(ce_)
	match tema:
		"dormitorio":
			p._dormitorio()
		"living":
			p._living()
		"comedor":
			p._comedor()
		"cocina":
			p._cocina()
		"bano":
			p._bano()
		"cuarto_chicos":
			p._cuarto_chicos()
		"estudio":
			p._estudio()
		"conventillo":
			p._conventillo()
	p._obstaculos_ruta(tema)
	p._rincones(tema)
	ce_.set_meta(&"plano_casa", true)
	ce_.set_meta(&"esquiva", p.esquiva)
	return p.puestos


# ---------------------------------------------------------------- Ambientes
# Las coordenadas: x de -hx (pared izquierda) a hx (derecha), z de -hz (pared de atrás, con la ventana de
# atrás en ce.x_fondo, del lado derecho) a hz (pared de adelante, con la ventana en ce.x_frente, del lado
# izquierdo). Así lo de la pared de atrás va a la izquierda y lo de la pared de adelante, a la derecha.

func _dormitorio() -> void:
	# La cama con la cabecera contra la pared izquierda, una mesita de luz a cada lado y la alfombra al pie
	if _en_pared("izq", 0.0, "cama"):
		var zc := ultimo.z
		var ancho: float = MueblesDatos.PIEZAS["cama"]["tam"].x
		for s in [-1.0, 1.0]:
			_en_pared("izq", zc + s * (ancho / 2.0 + 0.4), "mesita_luz", 1.0, false)
		_alfombra(Vector3(-hx + 2.1 + 1.0, 0, zc), 1.4, 1.9)
	# Ropero y cómoda: el ropero en la pared de atrás, la cómoda en la de adelante
	_en_pared("fondo", -hx * 0.45, "ropero")
	_en_pared("frente", hx * 0.45, "comoda")
	# Un rincón para leer: sillón y lámpara de pie contra la pared derecha
	if _en_pared("der", hz * 0.3, "sillon_azul"):
		_en_pared("der", ultimo.z + 1.35, "lampara_pie", 1.0, false)
	_escritorio("der", -hz * 0.4)


func _living() -> void:
	# El sillón contra la pared izquierda, la mesa ratona adelante, la alfombra y la tele enfrente
	if _en_pared("izq", 0.0, "sillon_azul"):
		var zc := ultimo.z
		var x_mesa := -hx + 0.905 + 1.0
		_poner("mesa_ratona", x_mesa, zc, PI / 2.0)
		_alfombra(Vector3(x_mesa + 0.2, 0, zc), 2.6, 3.0)
		_poner("mueble_tv", x_mesa + 2.0, zc, -PI / 2.0)   # De frente al sillón
		_poner("sillon_amarillo", x_mesa, zc + 2.0, PI)    # El otro sillón, de costado
		_en_pared("izq", zc - 1.6, "lampara_pie", 1.0, false)
	# Bibliotecas contra la pared de atrás, una al lado de la otra
	_fila("fondo", -hx * 0.75, ["biblioteca", "biblioteca", "biblioteca"])
	# Del otro lado, un rincón con sillón y lámpara
	if _en_pared("der", -hz * 0.25, "sillon_amarillo"):
		_en_pared("der", ultimo.z - 1.35, "lampara_pie", 1.0, false)
	_en_pared("frente", hx * 0.5, "comoda")
	# Living comedor: la mesa para comer del otro lado
	_mesa_con_sillas(Vector3(hx * 0.35, 0, 0), "mesa_comedor", 4)


func _comedor() -> void:
	# La mesa con sus sillas alrededor, en el medio
	_mesa_con_sillas(Vector3(-hx * 0.2, 0, 0), "mesa_comedor", 6)
	_en_pared("fondo", -hx * 0.6, "vajillero")
	_en_pared("izq", 0.0, "comoda")
	# Un sillón y una mesita en el otro lado
	if _en_pared("der", 0.0, "sillon_azul"):
		var zs := ultimo.z
		_poner("mesa_ratona", hx - 0.905 - 1.0, zs, -PI / 2.0)
		_en_pared("der", zs + 1.35, "lampara_pie", 1.0, false)
	_en_pared("frente", hx * 0.45, "vajillero")


func _cocina() -> void:
	# La fila de la cocina contra la pared de atrás: heladera, mesada, cocina, mesada y alacena
	_fila("fondo", -hx + 0.6, ["heladera_casa", "mesada", "cocina_horno", "mesada", "alacena_alta"])
	if _en_pared("izq", hz * 0.25, "lavarropas"):
		_en_pared("izq", ultimo.z + 0.65, "tacho", 1.0, false)
	# Una mesa con cuatro sillas para comer en la cocina
	_mesa_con_sillas(Vector3(hx * 0.25, 0, hz * 0.05), "mesa_comedor", 4)
	_en_pared("der", 0.0, "alacena_alta")


func _bano() -> void:
	# La bañera a lo largo de la pared izquierda; inodoro, lavatorio y armario en la de atrás
	_en_pared("izq", 0.0, "banera")
	_fila("fondo", -hx + 0.5, ["inodoro", "lavatorio", "armario_bano"], 0.25)
	if _en_pared("frente", hx * 0.5, "lavarropas"):
		_en_pared("frente", ultimo.x + 0.65, "tacho", 1.0, false)
	_en_pared("der", 0.0, "armario_bano")


func _cuarto_chicos() -> void:
	# Dos camas chicas con la cabecera contra la pared izquierda, con una mesita de luz en el medio
	var ancho: float = MueblesDatos.PIEZAS["cama_chica"]["tam"].x
	var sep := ancho / 2.0 + 0.45
	if _en_pared("izq", -sep, "cama_chica"):
		var z1 := ultimo.z
		_en_pared("izq", z1 + sep, "mesita_luz", 1.0, false)
		_en_pared("izq", z1 + sep * 2.0, "cama_chica", 1.0, false)
	_alfombra(Vector3(-hx + 1.8 + 1.4, 0, 0), 2.2, 2.6)
	_en_pared("fondo", -hx * 0.5, "cajonera_juguetes")
	# Una mesita para jugar con dos sillas, y el oso
	_mesa_con_sillas(Vector3(hx * 0.3, 0, 0), "mesa_ratona", 2)
	_poner("oso_peluche", -hx + 1.8 + 1.0, sep + 0.9, PI / 2.0)
	_en_pared("frente", hx * 0.5, "comoda")
	_escritorio("der", -hz * 0.3)   # Para hacer la tarea


func _estudio() -> void:
	# El escritorio contra la pared izquierda, con su silla; bibliotecas atrás; un rincón para leer
	_escritorio("izq", 0.0)
	_fila("fondo", -hx * 0.8, ["biblioteca", "biblioteca", "archivero"])
	if _en_pared("der", 0.0, "sillon_azul"):
		var zs := ultimo.z
		_poner("mesa_ratona", hx - 0.905 - 1.0, zs, -PI / 2.0)
		_en_pared("der", zs + 1.35, "lampara_pie", 1.0, false)
	_en_pared("frente", hx * 0.45, "biblioteca")
	_alfombra(Vector3(hx - 1.9, 0, 0), 2.2, 2.6)
	_mesa_con_sillas(Vector3(hx * 0.05, 0, 0), "mesa_comedor", 4)   # La mesa de trabajo


func _conventillo() -> void:
	# El cuarto de Doña Marta: la mesa con el mate y dos sillas, las macetas, su cama y su sillón con el gato
	_mesa_con_sillas(Vector3(-hx * 0.15, 0, 0), "mesa_mate", 2)
	_fila("izq", -hz * 0.4, ["torre_macetas", "torre_macetas"], 0.3)
	_en_pared("der", -hz * 0.2, "cama")
	_en_pared("fondo", -hx * 0.55, "ropero")
	if _en_pared("frente", hx * 0.45, "sillon_amarillo"):
		var xs := ultimo.x
		Kit.colocar(sala, "gato", Vector3(xs + 0.4, 0.47, hz - 0.905 / 2.0 - 0.05), PI + 0.4)
		_en_pared("frente", xs + 1.35, "lampara_pie", 1.0, false)
	_poner("jaula", -hx * 0.15 + 1.4, -1.2, 0.3)


# ---------------------------------------------------------------- Obstáculos de la cinemática

## Lo que la paloma esquiva al cruzar el cuarto volando, con sentido en cada ambiente:
## "costado": algo alto y suelto, en cada vuelta del zigzag (del lado de adentro de la curva), que rodea.
## "abajo": algo bajo justo debajo de la ruta entre vuelta y vuelta, que pasa por encima.
const OBSTACULOS := {
	"living": {"costado": ["biblioteca", "planta_alta", "lampara_pie"], "abajo": ["sillon_amarillo", "comoda", "mesa_ratona"]},
	"dormitorio": {"costado": ["ropero", "planta_alta", "lampara_pie"], "abajo": ["comoda", "sillon_azul", "mesita_luz"]},
	"comedor": {"costado": ["vajillero", "planta_alta", "lampara_pie"], "abajo": ["comoda", "mesa_ratona", "sillon_azul"]},
	"cocina": {"costado": ["alacena_alta", "heladera_casa", "alacena_alta"], "abajo": ["mesada", "cocina_horno", "mesada"]},
	"bano": {"costado": ["armario_bano", "lavatorio", "armario_bano"], "abajo": ["banera", "lavarropas", "tacho"]},
	"cuarto_chicos": {"costado": ["cajonera_juguetes", "planta_alta", "lampara_pie"], "abajo": ["mesa_ratona", "comoda", "oso_peluche"]},
	"estudio": {"costado": ["biblioteca", "archivero", "planta_alta"], "abajo": ["escritorio_pc", "mesa_ratona", "comoda"]},
	"conventillo": {"costado": ["torre_macetas", "planta_alta", "lampara_pie"], "abajo": ["mesa_mate", "comoda", "jaula"]},
}

var esquiva := 0   ## Cuántas cosas de costado o de abajo esquiva la paloma en la cinemática


## Pone los obstáculos de la cinemática (OBSTACULOS) sobre la ruta, después del resto de los muebles.
## Van derechos (girados de a 90°, lo más alineados que se pueda con la ruta) y con el mismo margen de
## siempre: la ruta nunca los toca.
func _obstaculos_ruta(tema: String) -> void:
	var lista: Dictionary = OBSTACULOS.get(tema, {})
	if lista.is_empty():
		return
	var r := ce.ruta
	var n := r.size() - 2
	# De costado, en cada vuelta: primero del lado de adentro de la curva y si no, del de afuera
	for i in range(1, n + 1):
		var w := r[i]
		var medio := (r[i - 1] + r[i + 1]) / 2.0
		var adentro := Vector3(medio.x - w.x, 0, medio.z - w.z)
		adentro = adentro.normalized() if adentro.length() > 0.05 else Vector3(0, 0, 1)
		var tang := Vector3(r[i + 1].x - r[i - 1].x, 0, r[i + 1].z - r[i - 1].z).normalized()
		var giro := _recto(Pasaje._giro(tang))
		var nombres: Array = lista["costado"]
		var nombre: String = nombres[(i - 1) % nombres.size()]
		var puesto := false
		for hacia: Vector3 in [adentro, -adentro]:
			for k in 6:
				var c := Vector3(w.x, 0, w.z) + hacia * (1.0 + k * 0.3)
				if _poner(nombre, c.x, c.z, giro):
					esquiva += 1
					puesto = true
					break
			if puesto:
				break
	# Por abajo, entre vuelta y vuelta (donde el escenario lo pide), si no hay ya un mueble debajo
	var curva := CasaEnterable.curva_de(r)
	var medios: Array = Pasaje.ESCENARIOS[tema]["medios"]
	for k in mini(medios.size(), n - 1):
		if not (medios[k] in ["abajo", "entre"]):
			continue
		var a := curva.get_closest_offset(r[k + 1])
		var b := curva.get_closest_offset(r[k + 2])
		var pm := curva.sample_baked((a + b) / 2.0, true)
		var p2 := curva.sample_baked((a + b) / 2.0 + 0.5, true)
		if _hay_algo_debajo(pm):
			esquiva += 1
			continue
		var giro := _recto(Pasaje._giro(Vector3(p2.x - pm.x, 0, p2.z - pm.z).normalized()))
		var nombres: Array = lista["abajo"]
		for j in nombres.size():
			if _poner(nombres[(k + j) % nombres.size()], pm.x, pm.z, giro):
				esquiva += 1
				break


## El giro de a 90° más cercano (lo que va suelto en un cuarto también va derecho).
static func _recto(giro: float) -> float:
	return roundf(giro / (PI / 2.0)) * (PI / 2.0)


## ¿Ya hay un mueble justo debajo de "p" (de la ruta)?
func _hay_algo_debajo(p: Vector3) -> bool:
	for caja: Array in ce.cajas:
		var c: Vector3 = caja[0]
		var e: Vector3 = caja[1]
		if c.y + e.y > p.y or c.y - e.y > 1.9:
			continue
		var m := PlanoLocal._medio_aabb(e, float(caja[2]))
		if absf(c.x - p.x) < m.x + 0.1 and absf(c.z - p.z) < m.y + 0.1:
			return true
	return false


## Un escritorio contra una pared de los costados, con su silla adelante mirándolo.
func _escritorio(lado: String, t: float) -> bool:
	if not _en_pared(lado, t, "escritorio_pc"):
		return false
	var hacia := 1.0 if lado == "izq" else -1.0
	return _poner("silla", ultimo.x + hacia * (0.45 + 0.6), ultimo.z, -hacia * PI / 2.0)


## Plantas en los rincones (donde tiene sentido: ni en la cocina ni en el baño) y una maceta junto a la
## ventana de adelante.
func _rincones(tema: String) -> void:
	if tema in ["cocina", "bano"]:
		return
	var esquinas := [Vector3(-hx + 0.55, 0, -hz + 0.55), Vector3(hx - 0.55, 0, -hz + 0.55),
		Vector3(-hx + 0.55, 0, hz - 0.55), Vector3(hx - 0.55, 0, hz - 0.55)]
	var k := 0
	for e: Vector3 in esquinas:
		if _poner("planta_alta" if k % 2 == 0 else "maceta", e.x, e.z, 0.0):
			k += 1
		if k >= 2:
			break


# ---------------------------------------------------------------- Ayudantes

## Pone un mueble con su colisión si entra: adentro del cuarto, sin pisar a otro, sin tapar las ventanas y
## lejos de la ruta de la cinemática. "s" lo escala (lo alto se achica a ALTO_MAX). Devuelve si lo puso.
func _poner(nombre: String, x: float, z: float, giro: float, s := 1.0) -> bool:
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	s *= minf(1.0, ALTO_MAX / float(d["y1"]))
	var tam: Vector3 = (d["tam"] as Vector3) * s
	var e := tam / 2.0
	var c := Vector3(x, 0.02 + e.y, z)
	if not Pasaje._en_cuarto(ce, c, e, giro):
		return false
	var medio := PlanoLocal._medio_aabb(e, giro)
	for caja: Array in ce.cajas:
		var c2: Vector3 = caja[0]
		var e2: Vector3 = caja[1]
		if c2.y - e2.y > 1.9:
			continue   # Lo que cuelga del techo
		if PlanoLocal._cruzan(c, e, giro, c2, e2, float(caja[2])):
			return false
	# Ni delante de las ventanas (por ahí entra y sale la paloma, y se ve el cuarto desde la calle)
	for v: Vector2 in [Vector2(ce.x_frente, hz), Vector2(ce.x_fondo, -hz)]:
		if absf(x - v.x) < CasaEnterable.VENTANA_ANCHO / 2.0 + 0.35 + medio.x and absf(z - v.y) < LIBRE_VENTANA + medio.y:
			return false
	if not Pasaje._libre(ruta, c, e, giro):
		return false
	Kit.colocar(sala, nombre, Vector3(x, 0.02 - float(d["y0"]) * s, z), giro, Vector3.ONE * s)
	if tam.y > 0.15:
		var forma := BoxShape3D.new()
		forma.size = tam
		Construir.colision(sala, c, forma, Vector3(0, giro, 0))
	ce.cajas.append([c, e, giro])
	if nombre in MESAS:   # De ahí vuelan papeles o servilletas cuando pasa la paloma (CasaEnterable)
		ce.mesas.append(Vector3(x, c.y + e.y, z))
	puestos += 1
	ultimo = Vector3(x, 0, z)
	return true


## Pone un mueble de espaldas a una pared ("izq", "der", "fondo" o "frente"), centrado en "t" a lo largo
## de ella. Si "correr", prueba también corriéndolo de a 0,5 m a cada lado hasta encontrar lugar.
func _en_pared(lado: String, t: float, nombre: String, s := 1.0, correr := true) -> bool:
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	var hondo: float = (d["tam"] as Vector3).z * s * minf(1.0, ALTO_MAX / float(d["y1"]))
	var pruebas := [0.0]
	if correr:
		for k in range(1, 9):
			pruebas.append(k * 0.5)
			pruebas.append(-k * 0.5)
	for dt: float in pruebas:
		var u := t + dt
		var p: Array = _lugar_en_pared(lado, u, hondo)
		if _poner(nombre, p[0], p[1], p[2], s):
			return true
	return false


## [x, z, giro] de algo de "hondo" metros apoyado en una pared, en "u" a lo largo de ella.
func _lugar_en_pared(lado: String, u: float, hondo: float) -> Array:
	match lado:
		"izq":
			return [-hx + hondo / 2.0 + AIRE, u, PI / 2.0]
		"der":
			return [hx - hondo / 2.0 - AIRE, u, -PI / 2.0]
		"fondo":
			return [u, -hz + hondo / 2.0 + AIRE, 0.0]
		_:
			return [u, hz - hondo / 2.0 - AIRE, PI]


## Varias cosas en fila contra una pared, desde "desde" hacia el otro lado, con "aire" entre una y otra.
## Si una no entra (una ventana, la ruta), sigue con la próxima un poco más allá.
func _fila(lado: String, desde: float, nombres: Array, aire := 0.05) -> int:
	var u := desde
	var n := 0
	var hacia := 1.0 if lado in ["fondo", "izq"] else -1.0
	var largo := hx if lado in ["fondo", "frente"] else hz
	for nombre: String in nombres:
		var d: Dictionary = MueblesDatos.PIEZAS[nombre]
		var s := minf(1.0, ALTO_MAX / float(d["y1"]))
		var ancho: float = (d["tam"] as Vector3).x * s
		var hondo: float = (d["tam"] as Vector3).z * s
		var puesto := false
		while absf(u) + ancho / 2.0 < largo - 0.1:
			var p: Array = _lugar_en_pared(lado, u + hacia * ancho / 2.0, hondo)
			if _poner(nombre, p[0], p[1], p[2]):
				u += hacia * (ancho + aire)
				n += 1
				puesto = true
				break
			u += hacia * 0.5
		if not puesto:
			break
	return n


## Una mesa con sus sillas alrededor, todas mirando la mesa: en los lados largos y, si son 6, una en
## cada punta. Si la mesa no entra en "centro", prueba un poco corrida.
func _mesa_con_sillas(centro: Vector3, mesa: String, sillas: int) -> bool:
	var tam: Vector3 = MueblesDatos.PIEZAS[mesa]["tam"]
	for dx in [0.0, 1.0, -1.0, 2.0, -2.0]:
		for dz in [0.0, 0.8, -0.8]:
			var c := centro + Vector3(dx, 0, dz)
			if not _poner(mesa, c.x, c.z, 0.0):
				continue
			var largos := 2 if sillas >= 4 else 1
			for k in largos:
				var x := c.x + ((k - (largos - 1) / 2.0) * (tam.x / largos) if largos > 1 else 0.0)
				_poner("silla", x, c.z + tam.z / 2.0 + 0.4, PI)      # Del lado de adelante, mirando hacia atrás
				_poner("silla", x, c.z - tam.z / 2.0 - 0.4, 0.0)     # Del lado de atrás, mirando hacia adelante
			if sillas >= 6:
				_poner("silla", c.x + tam.x / 2.0 + 0.4, c.z, -PI / 2.0)
				_poner("silla", c.x - tam.x / 2.0 - 0.4, c.z, PI / 2.0)
			return true
	return false


## Una alfombra (sin colisión) de "ancho" x "hondo" metros en "c", si no queda delante de una ventana.
func _alfombra(c: Vector3, ancho: float, hondo: float) -> void:
	for v: Vector2 in [Vector2(ce.x_frente, hz), Vector2(ce.x_fondo, -hz)]:
		if absf(c.x - v.x) < CasaEnterable.VENTANA_ANCHO / 2.0 + ancho / 2.0 and absf(c.z - v.y) < LIBRE_VENTANA + hondo / 2.0:
			return
	if absf(c.x) + ancho / 2.0 > hx or absf(c.z) + hondo / 2.0 > hz:
		return
	Kit.colocar(sala, "alfombra", Vector3(c.x, 0.02, c.z), PI / 2.0, Vector3(hondo / 2.4, 1.0, ancho / 1.6))

