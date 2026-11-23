class_name Vecinos
extends GenteLocal
## La gente que vive en los departamentos (los ambientes de arriba de cada edificio, world/pasaje.gd y
## world/plano_casa.gd): en el living alguien mira la tele desde el sillón y otro da vueltas; en el comedor
## comen sentados a la mesa; en la cocina alguien revuelve la olla frente a la mesada; en el estudio
## tipean en el escritorio; en el dormitorio ordenan el ropero; en el cuarto de los chicos un pibe anda
## de acá para allá; en lo de Doña Marta, una abuela con el mate; en la sala de lectura, dos leyendo en los
## sillones y alguien buscando un libro en la biblioteca.
##
## Se sientan en las sillas y sillones que dejó PlanoCasa (meta "lugares" de la sala) o se paran
## frente al mueble donde hacen algo; los que pasean caminan por la grilla de puntos libres del piso de
## GenteLocal (esquivando los muebles). Nadie se pone delante de una ventana (por ahí entra y sale la
## paloma) ni debajo de la ruta de la cinemática (con el mismo margen que los muebles: la paloma pasa
## sobre sus cabezas). Son ModeloHumano con su cápsula: la paloma los choca. Si la paloma les pasa
## volando muy cerca, levantan los brazos del susto.

const SUSTO_DIST := 1.4       ## A menos de esto (y volando rápido) la paloma los asusta
const SUSTO_VEL := 2.5
const SUSTO_DURA := 1.6
const RESPALDO_CADERA := 0.07       ## De la cara del respaldo a la cadera (la pose sentada ya lleva la cadera hacia atrás)
const CADERA_SOBRE_ASIENTO := 0.08  ## La articulación de la cadera, sobre el almohadón
const MUSLO := 0.45                 ## Largo del muslo de un adulto (antes de tener el modelo: ver ModeloHumano.largo_muslo)
const RODILLA_AFUERA := 0.08        ## Cuánto pasan las rodillas del borde del almohadón (el grosor de la pierna)

## Quién vive en cada ambiente: [dónde, personajes posibles]. "dónde": "sillon", "silla_mesa",
## "silla_escritorio", "cocina", "ropero", "juguetes" o "pasea". Si no hay ese lugar, pasea.
## Sentados van sólo los que no tienen nada en las manos (o el estudiante, con su mate): el bastón del
## jubilado, el maletín del oficinista y la bolsa de la abuela quedan flotando con las manos en los
## muslos, y la mochila grande de la mochilera se mete en el respaldo. Esos andan parados o caminando.
const QUIENES := {
	"living": [["sillon", ["estudiante", "oficinista_mujer", "hincha", "turista_gringo"]], ["pasea", ["jubilado", "abuela", "bailarina", "oficinista"]]],
	"comedor": [["silla_mesa", ["artesano", "oficinista_mujer", "hincha"]], ["silla_mesa", ["bailarina", "estudiante", "turista_gringo"]]],
	"cocina": [["cocina", ["oficinista_mujer", "artesano", "bailarina", "abuela"]]],
	"dormitorio": [["ropero", ["estudiante", "bailarina", "oficinista_mujer", "mochilera"]]],
	"estudio": [["silla_escritorio", ["oficinista_mujer", "estudiante", "artesano"]]],
	"cuarto_chicos": [["pasea", ["pibe", "escolar_nena", "escolar"]], ["juguetes", ["pibe", "escolar"]]],
	"conventillo": [["silla_mesa", ["estudiante"]], ["pasea", ["abuela", "jubilado"]]],
	"lectura": [["sillon", ["estudiante", "oficinista_mujer", "turista_gringo"]], ["sillon", ["artesano", "bailarina", "hincha"]],
		["ropero", ["jubilado", "abuela"]]],
}
## Qué mueble cuenta para cada "dónde".
const MUEBLES := {"sillon": ["sillon_azul", "sillon_amarillo"], "cocina": ["mesada", "cocina_horno"],
	"ropero": ["ropero", "comoda", "biblioteca"], "juguetes": ["cajonera_juguetes"]}

var tema := ""
var _ruta: PackedVector3Array
var _vecinos: Array[Dictionary] = []   ## {m: ModeloHumano, pasea: bool, susto: float} (+ lo de GenteLocal para caminar)


## Pone a los que viven en el ambiente "ce" (todo colgando de "sala").
static func habitar(sala: Node3D, ce_: CasaEnterable, tema_: String) -> Vecinos:
	var v := Vecinos.new()
	v.name = "Vecinos"
	v.ce = ce_
	v.tema = tema_
	v.set_meta(&"no_fusionar", true)
	sala.add_child(v)
	v._armar()
	return v


## Cuántos viven acá (para las pruebas).
func cuantos() -> int:
	return _vecinos.size()


func personas() -> Array[ModeloHumano]:
	var res: Array[ModeloHumano] = []
	for d in _vecinos:
		res.append(d["m"])
	return res


func _armar() -> void:
	_rng.seed = hash(ce.nombre) + 101
	_ruta = Pasaje._muestras(ce)
	_base_empleado = Vector3(1e6, 0, 1e6)   # (GenteLocal lo usa para no mandar a nadie detrás del mostrador)
	_buscar_libres()
	var usados: Array[Dictionary] = []
	for plan: Array in QUIENES.get(tema, []):
		var personajes: Array = plan[1]
		var personaje: String = personajes[_rng.randi_range(0, personajes.size() - 1)]
		var lugar := {} if plan[0] == "pasea" else _lugar(String(plan[0]), usados)
		if not lugar.is_empty():
			usados.append(lugar)
			_poner_en_lugar(personaje, lugar, String(plan[0]))
		elif not _libres.is_empty():
			_poner_paseando(personaje)


## Un lugar libre de la sala para "donde" (ver QUIENES), o {} si no hay.
func _lugar(donde: String, usados: Array[Dictionary]) -> Dictionary:
	var lugares: Array = ce.get_meta(&"lugares", [])
	var opciones: Array[Dictionary] = []
	for l: Dictionary in lugares:
		if l in usados:
			continue
		var mueble := String(l["mueble"])
		var sirve := false
		match donde:
			"silla_mesa", "silla_escritorio":
				sirve = mueble == "silla" and _silla_de(l, donde == "silla_escritorio")
			_:
				sirve = mueble in MUEBLES.get(donde, [])
		if sirve and _cabe(_donde_queda(l), l["como"] == "sentado"):
			opciones.append(l)
	return {} if opciones.is_empty() else opciones[_rng.randi_range(0, opciones.size() - 1)]


## ¿La silla "l" es de una mesa (o, si "escritorio", de un escritorio)? Las mesas las anota PlanoCasa.
func _silla_de(l: Dictionary, escritorio: bool) -> bool:
	var p: Vector3 = l["pos"]
	for o: Dictionary in ce.get_meta(&"lugares", []):
		var m := String(o["mueble"])
		if not (m in (["escritorio_pc"] if escritorio else ["mesa_comedor", "mesa_mate"])):
			continue
		if Vector2(p.x - (o["pos"] as Vector3).x, p.z - (o["pos"] as Vector3).z).length() < 1.4:
			return true
	return false


## Dónde queda la persona en ese lugar: sentada, sobre el asiento medido del mueble (PlanoCasa.asiento_de),
## con la espalda contra el respaldo y, en el sillón, sobre el almohadón de un lado; parada, delante del mueble.
func _donde_queda(l: Dictionary, muslo := MUSLO) -> Vector3:
	var g: float = l["giro"]
	var b := Basis.from_euler(Vector3(0, g, 0))
	var p: Vector3 = l["pos"]
	if l["como"] == "sentado":
		var a := PlanoCasa.asiento_de(String(l["mueble"]))
		var esc := float(l.get("escala", 1.0))
		var lado := float(a["x"]) * (1.0 if hash(p) % 2 == 0 else -1.0)
		# La espalda contra el respaldo; pero si así las rodillas no llegan al borde del almohadón (un sillón
		# hondo), más adelante: las piernas tienen que caer por delante del asiento, no atravesarlo
		var z := maxf(float(a["respaldo"]) + RESPALDO_CADERA / esc, float(a["frente"]) + (RODILLA_AFUERA - muslo) / esc)
		return p + b * (Vector3(lado, 0, z) * esc)
	var medio: Vector3 = l["medio"]
	return p + b * Vector3(0, 0, medio.z + 0.38)


## Cuánto sube la cadera (la articulación) de la persona sentada para que apoye justo sobre el asiento
## de ese lugar, según su estatura (ver ModeloHumano.asiento_extra).
func _extra_asiento(l: Dictionary, personaje: String) -> float:
	var a := PlanoCasa.asiento_de(String(l["mueble"]))
	var asiento := float(a["alto"]) * float(l.get("escala", 1.0)) + 0.02
	var alto := float(ModeloHumano.info(personaje).get("alto", 1.75))
	return (asiento + CADERA_SOBRE_ASIENTO) * 1.75 / alto - ModeloHumano.ALTO_ASIENTO


## ¿Entra una persona ahí? Sin pisar otro mueble (salvo el suyo, si está sentada), adentro del cuarto,
## lejos de las ventanas y debajo de la ruta de la cinemática sólo con el margen de siempre.
func _cabe(p: Vector3, sentada: bool) -> bool:
	var alto := 1.45 if sentada else 1.85
	if not Pasaje._libre(_ruta, Vector3(p.x, alto / 2.0, p.z), Vector3(0.3, alto / 2.0, 0.3), 0.0):
		return false
	if _frente_a_ventana(p):
		return false
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR - 0.3
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR - 0.3
	if absf(p.x) > hx or absf(p.z) > hz:
		return false
	if sentada:
		return true
	for caja: Array in ce.cajas:
		var c: Vector3 = caja[0]
		var e: Vector3 = caja[1]
		if c.y - e.y > 1.9:
			continue
		var q := (p - c).rotated(Vector3.UP, -float(caja[2]))
		if absf(q.x) < e.x + 0.22 and absf(q.z) < e.z + 0.22:
			return false
	return true


func _frente_a_ventana(p: Vector3) -> bool:
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	for v: Vector2 in [Vector2(ce.x_frente, hz), Vector2(ce.x_fondo, -hz)]:
		if absf(p.x - v.x) < CasaEnterable.VENTANA_ANCHO / 2.0 + 0.5 and absf(p.z - v.y) < PlanoCasa.LIBRE_VENTANA + 0.3:
			return true
	return false


## La grilla de GenteLocal, sin los puntos delante de las ventanas ni debajo de la ruta.
func _punto_libre(p: Vector3, ocupado: Array) -> bool:
	if not super(p, ocupado):
		return false
	return not _frente_a_ventana(p) and Pasaje._libre(_ruta, Vector3(p.x, 0.93, p.z), Vector3(0.3, 0.93, 0.3), 0.0)


func _poner_en_lugar(personaje: String, l: Dictionary, donde: String) -> void:
	var m := ModeloHumano.new()
	m.personaje = personaje
	m.sentado = l["como"] == "sentado"
	if m.sentado:
		m.asiento_extra = _extra_asiento(l, personaje)
	add_child(m)
	m.position = _donde_queda(l, m.largo_muslo() if m.sentado else MUSLO)
	m.rotation.y = float(l["giro"]) + (PI if m.sentado else 0.0)
	match donde:
		"silla_escritorio":
			m.actividad = "teclear"
		"silla_mesa":
			m.actividad = "comer" if tema == "comedor" else ""
		_:
			m.actividad = String(l["actividad"])
	m._aplicar_pose(0.0, 0.0)   # Ya sentado (o parado) desde el principio, aunque la paloma esté lejos
	_vecinos.append({"m": m, "pasea": false, "susto": 0.0})


func _poner_paseando(personaje: String) -> void:
	var i := _rng.randi_range(0, _libres.size() - 1)
	var m := ModeloHumano.new()
	m.personaje = personaje
	add_child(m)
	m.position = _libres[i]
	m._aplicar_pose(0.0, 0.0)
	var d := {"m": m, "pasea": true, "susto": 0.0, "pos": _libres[i], "rumbo": _rng.randf() * TAU, "rapidez": 0.0,
		"camino": PackedVector3Array(), "paso": Paso.MIRANDO, "espera": _rng.randf_range(1.0, 4.0), "mirar": Vector3.INF,
		"vel": _rng.randf_range(0.6, 0.9), "saliendo": false, "fin": false, "paradas": 1000000, "pago": true}
	_vecinos.append(d)


## Después de mirar algo, otro lugar de la casa (nunca se van: viven acá).
func _siguiente(c: Dictionary) -> void:
	var aca := _mas_cercano(c["pos"])
	var i := _destino_al_azar(aca)
	var cam := _camino(aca, i)
	if cam.is_empty():
		c["espera"] = 2.0
		c["paso"] = Paso.MIRANDO
		return
	c["mirar"] = _cosa_cercana(_libres[i])
	c["camino"] = cam
	c["paso"] = Paso.CAMINANDO


func _process(delta: float) -> void:
	var j := GameState.jugador
	if j == null or _vecinos.is_empty() or global_position.distance_to(j.global_position) > CERCA:
		return
	var pj := to_local(j.global_position)
	var rapida := j.velocity.length() > SUSTO_VEL
	for d in _vecinos:
		var m: ModeloHumano = d["m"]
		if not is_instance_valid(m):
			continue
		var v := 0.0
		if d["pasea"]:
			_mover_cliente(d, delta)
			m.position = d["pos"]
			m.rotation.y = d["rumbo"]
			v = d["rapidez"]
		# Si la paloma le pasa volando muy cerca de la cabeza, se asusta (brazos arriba un ratito)
		var cabeza := m.position + Vector3.UP * (1.1 if m.sentado else 1.5)
		if rapida and pj.distance_to(cabeza) < SUSTO_DIST:
			d["susto"] = SUSTO_DURA
		d["susto"] = maxf(float(d["susto"]) - delta, 0.0)
		m.animar(delta, v, float(d["susto"]) > 0.0)
