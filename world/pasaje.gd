class_name Pasaje
extends RefCounted
## Arma un "pasaje": un edificio con un local en un piso al azar (del 1 al 7), con una ventana abierta
## adelante y otra atrás, y adentro un escenario con obstáculos que la paloma esquiva en la cinemática
## de world/casa_enterable.gd. Hay 11 escenarios (librería, panadería, conventillo, oficina,
## fiambrería, supermercado, verdulería, casa, café, restaurante y consultorio), cada uno con su ruta
## en zigzag, sus alturas, sus obstáculos, sus texturas y su luz. Los edificios de alrededor de la
## plaza (Edificios.ALREDEDORES) se arman así: cada partida sortea qué local va en cada uno y en qué piso.
##
## Los obstáculos se ubican SOBRE la ruta real (la misma curva que recorre la cinemática):
## - "costado": en cada vuelta del zigzag, del lado de adentro (la paloma lo rodea).
## - "arriba": colgado del techo justo encima de la ruta (pasa por abajo).
## - "abajo": una mesa o mostrador justo debajo (pasa por arriba).
## - "entre": las dos cosas a la vez (pasa por el medio): ahí va la cámara lenta.
## Cada uno se valida contra la ruta (en los dos sentidos): si queda a menos de MARGEN, se corre o se
## achica, y si no entra, no se pone. Así ninguna ruta choca nunca (lo confirma tests/test_casas.gd).
## La fachada mira a +Z local (el edificio se gira según su frente). La sala es un nodo "Sala" a la
## altura de su piso: todo lo de adentro está en sus coordenadas (el piso de la sala es y = 0).

const C_MARCO := Color("e9e2d2")
const C_BLANCO := Color("f4f1e8")
const C_VENTANA := Color("3b4250")
const C_MADERA := Color("8a5a35")
const C_METAL := Color("3f4a45")
const C_ORO := Color("d8b04a")
const PLANTA_BAJA := 6.0   ## Alto de la sala (ocupa casi dos pisos)
const ALTO_PISO := 3.2     ## Alto de cada piso del edificio (como Edificios.ventanas)
const PISO_MIN := 1        ## La sala nunca está en la planta baja...
const PISO_MAX := 7        ## ...y a lo sumo en el 7.º piso
const MARGEN := 0.45       ## Distancia mínima entre la ruta y cualquier obstáculo

## Cada escenario: alturas de las vueltas del zigzag (una por vuelta), amplitud del zigzag
## (fracción de la profundidad), qué va entre vuelta y vuelta, y los colores del cuarto.
## Además: "estilo" (la coreografía de la cinemática, ver CasaEnterable), el piso ("tablas",
## "baldosas" o "porcelanato", con sus dos colores), la pared ("lisa", "empapelado", "ladrillo" o
## "azulejo", ver TexturasInterior), el zócalo, si hay vigas en el techo, el toldo, las cortinas, el
## color de la luz, los nombres posibles del local, el color de los postigos y los textos de la cinemática.
const ESCENARIOS := {
	"libreria": {"alturas": [2.2, 2.9, 2.0, 2.8], "amp": 0.45, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("8a5a35"), "piso2": Color("6f4528"), "suelo": "tablas", "zocalo": Color("6b4a32"),
		"pared": Color("efe4c8"), "pared_tex": "empapelado", "vigas": true, "toldo": "toldo_rayas_verde",
		"cortina": "cortina_verde", "cartel": "SILENCIO, POR FAVOR", "estilo": CasaEnterable.Estilo.PERSECUCION,
		"luz": Color("ffd9a0"), "postigo": Color("5b3b2a"), "nombres": ["Librería El Palomar", "Libros El Vuelo"],
		"textos": ["¡Permiso, que pasa la paloma!", "Nadie lee, pero siempre hay migas", "Ni el librero levantó la vista"]},
	"panaderia": {"alturas": [2.9, 1.9, 2.8], "amp": 0.32, "medios": ["entre", "arriba"],
		"piso": Color("e9dcc0"), "piso2": Color("c96f4a"), "suelo": "baldosas", "zocalo": Color("c96f4a"),
		"pared": Color("f3e3c3"), "pared_tex": "azulejo", "vigas": true, "toldo": "toldo_rayas_amarillo",
		"cortina": "cortina_crema", "cartel": "PAN CALIENTE", "estilo": CasaEnterable.Estilo.TIRABUZON,
		"luz": Color("ffd59a"), "postigo": Color("2f7d5b"), "nombres": ["Panadería El Hornero", "Panadería La Miga"],
		"textos": ["¡Atajo por la panadería!", "Olor a pan recién hecho... ¡y a la calle!", "Ni el panadero la vio pasar"]},
	"conventillo": {"alturas": [2.0, 2.9, 2.1], "amp": 0.32, "medios": ["arriba", "entre"],
		"piso": Color("7c5a3e"), "piso2": Color("9a6b43"), "suelo": "tablas", "zocalo": Color("2f6b8a"),
		"pared": Color("c9e0d0"), "pared_tex": "lisa", "vigas": true, "toldo": "toldo_rayas_rojo",
		"cortina": "cortina_roja", "cartel": "CASA DE DOÑA MARTA", "estilo": CasaEnterable.Estilo.GRUA,
		"luz": Color("ffdcae"), "postigo": Color("2f6b8a"), "nombres": ["Casa de Doña Marta"],
		"textos": ["¡Permiso, Doña Marta!", "Entre sábanas y macetas", "¡Cuidado con el mate!"]},
	"oficina": {"alturas": [2.6, 1.9, 2.8, 2.0], "amp": 0.45, "medios": ["abajo", "entre", "arriba"],
		"piso": Color("8f969c"), "piso2": Color("7f868c"), "suelo": "porcelanato", "zocalo": Color("5f666b"),
		"pared": Color("e6eaee"), "pared_tex": "lisa", "vigas": false, "toldo": "toldo_rayas_azul",
		"cortina": "cortina_azul", "cartel": "ATENCIÓN AL CLIENTE", "estilo": CasaEnterable.Estilo.DE_FRENTE,
		"luz": Color("f2f5ff"), "postigo": Color("2b4a6b"), "nombres": ["Seguros La Cornisa", "Estudio Pichón & Asoc."],
		"textos": ["Como Ezio... pero con alas", "Vuelo asegurado, cobertura total", "¡Abran paso, oficinistas!"]},
	"fiambreria": {"alturas": [2.0, 2.8, 1.9, 2.7], "amp": 0.4, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("f4f1e8"), "piso2": Color("3a3c40"), "suelo": "baldosas", "zocalo": Color("b8423a"),
		"pared": Color("f1ead8"), "pared_tex": "azulejo", "vigas": false, "toldo": "toldo_rayas_rojo",
		"cortina": "cortina_crema", "cartel": "FIAMBRES Y QUESOS", "estilo": CasaEnterable.Estilo.CENITAL,
		"luz": Color("fff0d0"), "postigo": Color("b8423a"), "nombres": ["Fiambrería Los Gorriones"],
		"textos": ["Entrar, esquivar, salir: así se vive en el centro", "¡Perdón, señora, voy apurada!",
			"Salames a la izquierda, quesos a la derecha"]},
	"supermercado": {"alturas": [2.4, 2.9, 1.9, 2.7], "amp": 0.42, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("f2f2ee"), "piso2": Color("d9dcd6"), "suelo": "porcelanato", "zocalo": Color("4f9a5a"),
		"pared": Color("e8f2e4"), "pared_tex": "lisa", "vigas": false, "toldo": "toldo_rayas_verde",
		"cortina": "cortina_verde", "cartel": "OFERTAS DE LA SEMANA", "estilo": CasaEnterable.Estilo.TIRABUZON,
		"luz": Color("f4f8ff"), "postigo": Color("3f7d4a"), "nombres": ["Súper Don Pichón", "Supermercado El Gorrión"],
		"textos": ["¡Pasillo 3, sin frenar!", "Nadie pagó, pero nadie la vio", "Ofertas a toda velocidad"]},
	"verduleria": {"alturas": [2.1, 2.8, 2.2], "amp": 0.36, "medios": ["entre", "arriba"],
		"piso": Color("b7b2a8"), "piso2": Color("a29d93"), "suelo": "baldosas", "zocalo": Color("6b8f3a"),
		"pared": Color("f1e6d0"), "pared_tex": "lisa", "vigas": true, "toldo": "toldo_rayas_verde",
		"cortina": "cortina_verde", "cartel": "FRUTAS Y VERDURAS DE ESTACIÓN", "estilo": CasaEnterable.Estilo.CENITAL,
		"luz": Color("fff2cf"), "postigo": Color("6b8f3a"), "nombres": ["Verdulería Doña Rosa", "Frutas El Palomar"],
		"textos": ["¡Esas bananas casi me tapan!", "La fruta más fresca, la paloma más rápida", "¡Ni un tomate tocó!"]},
	"casa": {"alturas": [2.5, 2.0, 2.9], "amp": 0.34, "medios": ["arriba", "entre"],
		"piso": Color("b07a4a"), "piso2": Color("94603a"), "suelo": "tablas", "zocalo": Color("8a5a35"),
		"pared": Color("f4e3cf"), "pared_tex": "empapelado", "vigas": false, "toldo": "toldo_rayas_amarillo",
		"cortina": "cortina_crema", "cartel": "HOGAR, DULCE HOGAR", "estilo": CasaEnterable.Estilo.GRUA,
		"luz": Color("ffd9a8"), "postigo": Color("4f7fc0"), "nombres": ["Casa de los Pérez", "Departamento 4.º B"],
		"textos": ["¡Perdón por entrar sin tocar!", "Living, comedor... ¡y afuera!", "Nadie se despertó"]},
	"cafe": {"alturas": [2.3, 2.9, 2.0, 2.6], "amp": 0.4, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("8d9198"), "piso2": Color("7a7e85"), "suelo": "porcelanato", "zocalo": Color("8a5a35"),
		"pared": Color("f1cf9c"), "pared_tex": "lisa", "vigas": false, "toldo": "toldo_rayas_rojo",
		"cortina": "cortina_roja", "cartel": "CAFÉ Y MEDIALUNAS", "estilo": CasaEnterable.Estilo.PERSECUCION,
		"luz": Color("ffcf8f"), "postigo": Color("7a3f2a"), "nombres": ["Café La Medialuna", "Café Tortoni Chico"],
		"textos": ["¡Un cortado para llevar!", "Ni una miga en el piso", "Café al paso, bien al paso"]},
	"restaurante": {"alturas": [2.4, 2.0, 2.8, 2.1], "amp": 0.42, "medios": ["abajo", "entre", "arriba"],
		"piso": Color("8a5a35"), "piso2": Color("744a2c"), "suelo": "tablas", "zocalo": Color("6b3a2c"),
		"pared": Color("b8634e"), "pared_tex": "ladrillo", "vigas": false, "toldo": "toldo_rayas_rojo",
		"cortina": "cortina_roja", "cartel": "MENÚ DEL DÍA", "estilo": CasaEnterable.Estilo.DE_FRENTE,
		"luz": Color("ffc98a"), "postigo": Color("7a2f2a"), "nombres": ["Cantina Don Pichón", "Restaurante La Plaza"],
		"textos": ["¡Mesa para una, de pasada!", "Servilletas volando, ¡perdón!", "La especialidad: el atajo"]},
	"consultorio": {"alturas": [2.6, 2.0, 2.8], "amp": 0.38, "medios": ["abajo", "entre"],
		"piso": Color("d8e6ea"), "piso2": Color("b9cfd6"), "suelo": "porcelanato", "zocalo": Color("3f7fb0"),
		"pared": Color("eef6f6"), "pared_tex": "azulejo", "vigas": false, "toldo": "toldo_rayas_azul",
		"cortina": "cortina_azul", "cartel": "SILENCIO - CONSULTORIOS", "estilo": CasaEnterable.Estilo.PERSECUCION,
		"luz": Color("eef8ff"), "postigo": Color("3f7fb0"), "nombres": ["Consultorios Plaza", "Clínica La Pluma"],
		"textos": ["¡Que pase la siguiente!", "Turno express", "Control de vuelo: todo en orden"]},
}

## Qué edificio de Edificios.ALREDEDORES tiene qué local: índice -> [tema, piso, nombre]. Lo llena
## alrededores() y lo consulta NivelMedio (para no ponerle balcones donde está la sala).
static var interiores := {}


## ¿El edificio "k" de Edificios.ALREDEDORES tiene un local adentro (y no lleva balcones ni toldos)?
static func tiene_interior(k: int) -> bool:
	return interiores.has(k)


## Arma los edificios de alrededor de la plaza, cada uno con un local distinto en un piso al azar.
## Cada partida sortea los locales y los pisos (con la variable de entorno PALOMA_SEMILLA se puede fijar).
static func alrededores(padre: Node3D) -> Array[CasaEnterable]:
	interiores.clear()
	var rng := RandomNumberGenerator.new()
	var semilla := OS.get_environment("PALOMA_SEMILLA")
	if semilla.is_valid_int():
		rng.seed = int(semilla)
	else:
		rng.randomize()
	var temas: Array = ESCENARIOS.keys()
	# Mezcla de Fisher-Yates con el rng (así la semilla la fija)
	for i in range(temas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: String = temas[i]
		temas[i] = temas[j]
		temas[j] = t
	var out: Array[CasaEnterable] = []
	for k in Edificios.ALREDEDORES.size():
		var e: Array = Edificios.ALREDEDORES[k]
		var tema: String = temas[k % temas.size()]
		var esc: Dictionary = ESCENARIOS[tema]
		var piso := rng.randi_range(PISO_MIN, PISO_MAX)
		var nombre: String = esc["nombres"][rng.randi_range(0, esc["nombres"].size() - 1)]
		var base: Vector3 = e[0]
		var lado := 1.0 if base.x >= 0.0 else -1.0   # Al salir por atrás dobla hacia afuera de la plaza
		interiores[k] = [tema, piso, nombre]
		out.append(crear(padre, base, e[1], e[2], nombre, esc["postigo"], lado, esc["textos"], tema, e[4], piso, e[3]))
	return out


## Crea el pasaje y devuelve el nodo que dispara la cinemática.
## "lado_callejon": hacia dónde dobla la paloma al salir por atrás (+1 = +X local, -1 = -X local).
## "color_remate": el borde de color de la azotea y las cornisas (estilo del mapa V3).
## "piso": en qué piso está la sala (0 = planta baja). "frente": hacia dónde mira la fachada.
static func crear(padre: Node3D, base: Vector3, tam: Vector3, color: Color, nombre: String,
		color_postigo: Color, lado_callejon: float, textos: Array, tema: String,
		color_remate := C_BLANCO, piso := 0, frente := Vector3(0, 0, 1)) -> CasaEnterable:
	var w := tam.x if absf(frente.z) > 0.5 else tam.z
	var d := tam.z if absf(frente.z) > 0.5 else tam.x
	var y0 := piso * ALTO_PISO
	var pb := PLANTA_BAJA
	# El edificio crece lo que haga falta para que la sala entre con un piso más arriba
	var h := maxf(tam.y, y0 + pb + ALTO_PISO)
	var esp := CasaEnterable.ESPESOR
	var esc: Dictionary = ESCENARIOS[tema]
	var mat_pared := TexturasInterior.pared(esc["pared_tex"], esc["pared"])
	var casa := Node3D.new()
	casa.name = "Pasaje_" + nombre.replace(" ", "_")
	padre.add_child(casa)
	casa.position = base
	casa.rotation.y = atan2(frente.x, frente.z)
	var sala := Node3D.new()
	sala.name = "Sala"
	casa.add_child(sala)
	sala.position.y = y0

	# --- El nodo de la cinemática (con la ruta, que los obstáculos necesitan)
	var ce := CasaEnterable.new()
	ce.name = "Entrada_" + nombre.replace(" ", "_")
	ce.ancho = w
	ce.fondo = d
	ce.x_frente = -w * 0.28
	ce.x_fondo = w * 0.28
	ce.lado_callejon = lado_callejon
	ce.estilo = esc["estilo"]
	ce.nombre = nombre
	ce.tema = tema
	ce.piso = piso
	ce.ruta = ruta_zigzag(w, d, ce.x_frente, ce.x_fondo, esc["alturas"], esc["amp"])
	for t in textos:
		ce.textos.append(str(t))

	# --- El edificio: macizo abajo y arriba de la sala
	if y0 > 0.0:
		Construir.caja(casa, Vector3(0, y0 / 2.0, 0), Vector3(w, y0, d), color)
	Construir.caja(casa, Vector3(0, (y0 + pb + h) / 2.0, 0), Vector3(w, h - y0 - pb, d), color)
	# --- La sala: piso, costados, fachada y contrafachada con ventana, cielorraso
	Construir.caja(sala, Vector3(0, -0.13, 0), Vector3(w - 2 * esp, 0.3, d - 2 * esp), esc["piso"])
	for sx in [-1.0, 1.0]:
		Construir.caja(sala, Vector3(sx * (w / 2.0 - esp / 2.0), pb / 2.0, 0), Vector3(esp, pb, d - 2 * esp), color)
		Construir.caja_mat(sala, Vector3(sx * (w / 2.0 - esp - 0.01), pb / 2.0, 0), Vector3(0.02, pb, d - 2 * esp), mat_pared, false)
	_pared_con_ventana(sala, w, d / 2.0 - esp / 2.0, ce.x_frente, 1.0, color, mat_pared)
	_pared_con_ventana(sala, w, -d / 2.0 + esp / 2.0, ce.x_fondo, -1.0, color, mat_pared)
	Construir.caja(sala, Vector3(0, pb - 0.01, 0), Vector3(w - 2 * esp, 0.02, d - 2 * esp), C_BLANCO, false)

	# --- Exterior: marcos y postigos, cornisas que enmarcan la sala, ventanas de los otros pisos y carteles
	_marco_ventana(sala, ce.x_frente, d / 2.0, 1.0, color_postigo)
	_marco_ventana(sala, ce.x_fondo, -d / 2.0, -1.0, color_postigo)
	for e in [1.0, -1.0]:
		Construir.caja(casa, Vector3(0, y0 + pb + 0.15, e * (d / 2.0 + 0.2)), Vector3(w + 0.2, 0.3, 0.6), color_remate)
		if y0 > 0.0:
			Construir.caja(casa, Vector3(0, y0 - 0.12, e * (d / 2.0 + 0.15)), Vector3(w + 0.1, 0.24, 0.5), color_remate)
	_fachada(casa, ce, w, h, d, esc, y0)
	# Azotea gris con el borde de color (para posarse) y un aire acondicionado, como Edificios.edificio
	Construir.caja(casa, Vector3(0, h + 0.05, 0), Vector3(w, 0.1, d), Edificios.C_TECHO)
	const B := 0.55
	for s in [-1.0, 1.0]:
		Construir.caja(casa, Vector3(0, h + 0.35, s * (d / 2.0 + 0.5 - B / 2.0)), Vector3(w + 1.0, 0.7, B), color_remate)
		Construir.caja(casa, Vector3(s * (w / 2.0 + 0.5 - B / 2.0), h + 0.35, 0), Vector3(B, 0.7, d), color_remate)
	Construir.caja(casa, Vector3(w / 2.0 - 2.2, h + 0.5, -d / 4.0), Vector3(1.5, 0.8, 1.0), Color("e8eaea"))
	for dx in [-0.38, 0.38]:
		Construir.cilindro(casa, Vector3(w / 2.0 - 2.2 + dx, h + 0.92, -d / 4.0), 0.32, 0.04, Color("5f666b"), false, 10)
	# Cartel en la planta baja, sobre la puerta, que dice en qué piso está el local; y otro sobre el toldo
	var texto := nombre if piso == 0 else "%s · %d.º piso" % [nombre, piso]
	var y_cartel := 4.75 if piso == 0 else 3.55
	Construir.letrero(casa, Vector3(_x_puerta(w), y_cartel, d / 2.0 + 0.12), texto, Color.WHITE, color_postigo.darkened(0.4), 40,
		Vector2(minf(w * 0.44, 6.6), 0.6))
	if piso > 0:
		Construir.letrero(sala, Vector3(ce.x_frente, 5.45, d / 2.0 + 0.12), nombre, Color.WHITE, color_postigo.darkened(0.3), 36,
			Vector2(minf(w * 0.34, 4.4), 0.5))

	# --- Adentro: piso, paredes y techo del escenario; obstáculos sobre la ruta; adornos y luz
	_interior(sala, ce, w, d, esc)
	ce.obstaculos = _obstaculos(sala, ce, tema)
	ce.luz = _adornos(sala, ce, tema, esc["cartel"])
	_mas_adornos(sala, ce, tema)
	padre.add_child(ce)
	ce.transform = casa.transform * Transform3D(Basis.IDENTITY, Vector3(0, y0, 0))
	return ce



## La ruta por adentro: de la ventana de adelante a la de atrás, cruzando el cuarto de punta a punta
## en zigzag (adelante-atrás) y cambiando de altura en cada vuelta.
static func ruta_zigzag(w: float, d: float, xf: float, xb: float, alturas: Array, amp: float) -> Array[Vector3]:
	var hx := w / 2.0 - CasaEnterable.ESPESOR
	var hz := d / 2.0 - CasaEnterable.ESPESOR
	var n := alturas.size()
	var pts: Array[Vector3] = [Vector3(xf, CasaEnterable.Y_PASO, d / 2.0 - 0.5)]
	for i in n:
		var t := float(i) / float(n - 1)
		var signo := 1.0 if (n - 1 - i) % 2 == 0 else -1.0   # La última vuelta queda adelante
		pts.append(Vector3(lerpf(-0.72 * hx, 0.72 * hx, t), float(alturas[i]), signo * amp * hz))
	pts.append(Vector3(xb, CasaEnterable.Y_PASO - 0.1, -d / 2.0 + 0.5))
	return pts


# ---------------------------------------------------------------- Obstáculos

## Puntos de las dos pasadas posibles (adelante->atrás y atrás->adelante), para validar.
static func _muestras(ce: CasaEnterable) -> PackedVector3Array:
	var res := PackedVector3Array()
	var y := CasaEnterable.Y_PASO
	for desde_frente in [true, false]:
		var inicio := Vector3(ce.x_frente, y, ce.fondo / 2.0 + 2.6) if desde_frente else Vector3(ce.x_fondo, y, -ce.fondo / 2.0 - 2.6)
		var c := CasaEnterable.curva_de(ce.puntos_ruta(desde_frente, inicio))
		var largo := c.get_baked_length()
		var s := 0.0
		while s <= largo:
			res.append(c.sample_baked(s, true))
			s += 0.1
	return res


## Distancia de un punto a una caja girada (centro "c", medias medidas "e", giro en Y).
static func _dist_caja(p: Vector3, c: Vector3, e: Vector3, giro: float) -> float:
	var q := (p - c).rotated(Vector3.UP, -giro)
	var dd := Vector3(absf(q.x), absf(q.y), absf(q.z)) - e
	var fuera := Vector3(maxf(dd.x, 0.0), maxf(dd.y, 0.0), maxf(dd.z, 0.0)).length()
	return fuera + minf(maxf(dd.x, maxf(dd.y, dd.z)), 0.0)


static func _libre(m: PackedVector3Array, c: Vector3, e: Vector3, giro: float) -> bool:
	for p in m:
		if _dist_caja(p, c, e, giro) < MARGEN:
			return false
	return true


## ¿La caja entra en el cuarto (sin tocar las paredes)?
static func _en_cuarto(ce: CasaEnterable, c: Vector3, e: Vector3, giro: float) -> bool:
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR - 0.05
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR - 0.05
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := c + Vector3(e.x * sx, 0, e.z * sz).rotated(Vector3.UP, giro)
			if absf(p.x) > hx or absf(p.z) > hz:
				return false
	return c.y + e.y < PLANTA_BAJA - 0.02


static func _giro(tang: Vector3) -> float:
	return atan2(-tang.z, tang.x)   # Una caja con ese giro tiene su eje X sobre "tang"


static func _obstaculos(casa: Node3D, ce: CasaEnterable, tema: String) -> int:
	var m := _muestras(ce)
	var r := ce.ruta
	var n := r.size() - 2
	var cant := 0
	# 1) De costado, en cada vuelta del zigzag (del lado de adentro de la curva)
	for i in range(1, n + 1):
		var w := r[i]
		var medio := (r[i - 1] + r[i + 1]) / 2.0
		var adentro := Vector3(medio.x - w.x, 0, medio.z - w.z)
		adentro = adentro.normalized() if adentro.length() > 0.05 else Vector3(0, 0, 1)
		var tang := Vector3(r[i + 1].x - r[i - 1].x, 0, r[i + 1].z - r[i - 1].z).normalized()
		var giro := _giro(tang)
		var alto := 3.4 + 0.4 * float(i % 3)
		var puesto := false
		# Primero del lado de adentro de la curva; en las vueltas muy cerradas (las que vienen de una
		# ventana) ahí no entra, y va del lado de afuera: igual pasa rozándolo
		for hacia in [adentro, -adentro]:
			for intento in 5:
				var e := Vector3(0.5, alto / 2.0, 0.34) * Vector3(1.0 - intento * 0.12, 1.0, 1.0 - intento * 0.1)
				var c := Vector3(w.x, e.y, w.z) + (hacia as Vector3) * (1.15 + intento * 0.28)
				if _en_cuarto(ce, c, e, giro) and _libre(m, c, e, giro):
					_poner(casa, ce, tema, "costado", c, e, giro, i)
					cant += 1
					puesto = true
					break
			if puesto:
				break
	# 2) Entre vuelta y vuelta: por arriba, por abajo o las dos cosas. También en el tramo que viene
	# de la ventana de adelante y en el que va a la de atrás (siempre algo colgando, por arriba).
	var curva := CasaEnterable.curva_de(r)
	var medios: Array = ESCENARIOS[tema]["medios"].duplicate()
	ce.destacado = curva.sample_baked(curva.get_baked_length() / 2.0, true)
	var tramos: Array = []   # [índice del punto de partida, tipo]
	tramos.append([0, "arriba"])
	for k in mini(medios.size(), n - 1):
		tramos.append([k + 1, medios[k]])
	tramos.append([n, "arriba"])
	for tramo in tramos:
		var k: int = tramo[0] - 1
		var a := curva.get_closest_offset(r[k + 1])
		var b := curva.get_closest_offset(r[k + 2])
		var pm := curva.sample_baked((a + b) / 2.0, true)
		var p2 := curva.sample_baked((a + b) / 2.0 + 0.5, true)
		var giro := _giro(Vector3(p2.x - pm.x, 0, p2.z - pm.z).normalized())
		var tipo: String = tramo[1]
		if tipo == "entre":
			ce.destacado = pm
		if tipo == "arriba" or tipo == "entre":
			for intento in 4:
				var e := Vector3(0.5, 0.32, 0.5) * (1.0 - intento * 0.12)
				var c := pm + Vector3(0, 0.6 + intento * 0.15 + e.y, 0)
				if _en_cuarto(ce, c, e, giro) and _libre(m, c, e, giro):
					_poner(casa, ce, tema, "arriba", c, e, giro, k)
					cant += 1
					break
		if tipo == "abajo" or tipo == "entre":
			for intento in 4:
				var arriba := pm.y - 0.6 - intento * 0.15
				if arriba < 0.5:
					break
				var e := Vector3(0.7, arriba / 2.0, 0.45) * Vector3(1.0 - intento * 0.12, 1.0, 1.0 - intento * 0.1)
				var c := Vector3(pm.x, e.y, pm.z)
				if _en_cuarto(ce, c, e, giro) and _libre(m, c, e, giro):
					_poner(casa, ce, tema, "abajo", c, e, giro, k)
					cant += 1
					break
	return cant


## Arma un obstáculo: la colisión es la caja (c, e, giro) y adentro va el mueble del tema
## (modelado en Blender, ver tools/blender/generar_muebles.py), escalado para que entre en la caja.
## Lo que cuelga va en un pivote en el techo que no se fusiona: así se hamaca cuando pasa la paloma
## (o gira, el ventilador). Las mesas y los salames se anotan para los efectos de la cinemática.
static func _poner(casa: Node3D, ce: CasaEnterable, tema: String, tipo: String, c: Vector3, e: Vector3, giro: float, i: int) -> void:
	var nombre := _mueble_obstaculo(tema, tipo, i)
	if tipo != "arriba":
		var s := _mueble_en_caja(casa, nombre, c, e, giro)
		# La colisión, del tamaño del mueble de verdad (más chico o igual que la caja que validó la
		# ruta: la paloma sigue pasando con más lugar). Si no, un mueble bajo tendría una pared
		# invisible arriba que le tapa la vista a la cámara.
		var tam: Vector3 = MueblesDatos.PIEZAS[nombre]["tam"] * s
		var ev := Vector3(minf(e.x, tam.x / 2.0), minf(e.y, tam.y / 2.0), minf(e.z, tam.z / 2.0))
		var cv := Vector3(c.x, c.y - e.y + ev.y, c.z)
		var forma_v := BoxShape3D.new()
		forma_v.size = ev * 2.0
		Construir.colision(casa, cv, forma_v, Vector3(0, giro, 0))
		ce.cajas.append([cv, ev, giro])
		if tipo == "abajo":
			ce.mesas.append(Vector3(c.x, c.y + e.y, c.z))
		return
	var forma := BoxShape3D.new()
	forma.size = e * 2.0
	Construir.colision(casa, c, forma, Vector3(0, giro, 0))
	ce.cajas.append([c, e, giro])
	var pivote := Node3D.new()
	pivote.name = "Colgante_%d" % ce.colgantes.size()
	pivote.set_meta(&"no_fusionar", true)
	casa.add_child(pivote)
	pivote.position = Vector3(c.x, PLANTA_BAJA, c.z)
	if nombre == "ventilador":
		pivote.set_meta(&"gira", true)
	if nombre == "salames":
		ce.salames.append(Vector3(c.x, c.y, c.z))
	_mueble_en_caja(pivote, nombre, c, e, giro, true, pivote.position)
	# El cordón hasta el techo, desde arriba del mueble (que cuelga con su tope en c.y + e.y)
	var largo := PLANTA_BAJA - (c.y + e.y)
	if largo > 0.05:
		Construir.cilindro(pivote, Vector3(0, -largo / 2.0, 0), 0.02, largo, Color("2a2a2a"), false, 4)
	pivote.set_meta(&"largo", PLANTA_BAJA - c.y)
	ce.colgantes.append(pivote)


## Qué mueble va como obstáculo en cada escenario.
static func _mueble_obstaculo(tema: String, tipo: String, i: int) -> String:
	var tabla := {
		"libreria": {"costado": "biblioteca", "arriba": "lampara_verde", "abajo": "mesa_lectura"},
		"panaderia": {"costado": "estante_panes", "arriba": "canasto_panes", "abajo": "mostrador_torta"},
		"conventillo": {"costado": "torre_macetas", "arriba": "sabana", "abajo": "mesa_mate"},
		"oficina": {"costado": "archivero" if i % 2 == 0 else "planta_alta", "arriba": "ventilador", "abajo": "escritorio_pc"},
		"fiambreria": {"costado": "heladera_vitrina", "arriba": "salames", "abajo": "mostrador_quesos"},
		"supermercado": {"costado": "gondola" if i % 3 != 2 else "heladera_bebidas", "arriba": "cartel_oferta", "abajo": "caja_super"},
		"verduleria": {"costado": "estante_cajones", "arriba": "racimo_bananas", "abajo": "puesto_frutas"},
		"casa": {"costado": "ropero" if i % 2 == 0 else "planta_alta", "arriba": "lampara_techo", "abajo": "mesa_comedor"},
		"cafe": {"costado": "heladera_bebidas" if i % 2 == 0 else "planta_alta", "arriba": "lampara_colgante", "abajo": "vitrina_tortas"},
		"restaurante": {"costado": "jardinera_alta", "arriba": "lampara_colgante", "abajo": "mesa_mantel"},
		"consultorio": {"costado": "armario_medico" if i % 2 == 0 else "planta_alta", "arriba": "lampara_quirofano", "abajo": "camilla"},
	}
	return tabla[tema][tipo]


## Pone un mueble escalado (sin deformarlo) para que entre en la caja c ± e girada "giro".
## Va apoyado abajo de la caja, o colgado de arriba si "colgado". "origen": dónde está "destino"
## dentro de la casa (para un pivote). Devuelve la escala.
static func _mueble_en_caja(destino: Node3D, nombre: String, c: Vector3, e: Vector3, giro: float, colgado := false,
		origen := Vector3.ZERO) -> float:
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	var tam: Vector3 = d["tam"]
	var s := minf(minf(e.x * 2.0 / tam.x, e.y * 2.0 / tam.y), e.z * 2.0 / tam.z)
	var y := c.y - e.y - float(d["y0"]) * s
	if colgado:
		y = c.y + e.y - float(d["y1"]) * s
	Kit.colocar(destino, nombre, Vector3(c.x, y, c.z) - origen, giro, Vector3.ONE * s)
	return s


# ---------------------------------------------------------------- Exterior y adornos

## Pared de la planta baja con una ventana centrada en "cx" (y su lámina de pintura interior).
## "afuera" = +1 si la cara exterior mira a +Z.
static func _pared_con_ventana(casa: Node3D, w: float, z: float, cx: float, afuera: float, color: Color, pintura: Material) -> void:
	var esp := CasaEnterable.ESPESOR
	var pb := PLANTA_BAJA
	var an := CasaEnterable.VENTANA_ANCHO
	var y0 := CasaEnterable.VENTANA_Y0
	var y1 := CasaEnterable.VENTANA_Y1
	var piezas := [
		[Vector3(0, (y1 + pb) / 2.0, z), Vector3(w, pb - y1, esp)],                                           # Dintel
		[Vector3((-w / 2.0 + cx - an / 2.0) / 2.0, y1 / 2.0, z), Vector3(cx - an / 2.0 + w / 2.0, y1, esp)],  # Izquierda
		[Vector3((cx + an / 2.0 + w / 2.0) / 2.0, y1 / 2.0, z), Vector3(w / 2.0 - cx - an / 2.0, y1, esp)],   # Derecha
		[Vector3(cx, y0 / 2.0, z), Vector3(an, y0, esp)],                                                      # Antepecho
	]
	for p: Array in piezas:
		var pos: Vector3 = p[0]
		var tam: Vector3 = p[1]
		Construir.caja(casa, pos, tam, color)
		Construir.caja_mat(casa, pos - Vector3(0, 0, afuera * (esp / 2.0 + 0.01)), Vector3(tam.x, tam.y, 0.02), pintura, false)


## Marco, alféizar y dos postigos abiertos (clásico porteño) de una ventana en la cara z_cara.
static func _marco_ventana(casa: Node3D, cx: float, z_cara: float, afuera: float, color_postigo: Color) -> void:
	var an := CasaEnterable.VENTANA_ANCHO
	var y0 := CasaEnterable.VENTANA_Y0
	var y1 := CasaEnterable.VENTANA_Y1
	for lado in [-1.0, 1.0]:
		Construir.caja(casa, Vector3(cx + lado * (an / 2.0 + 0.12), (y0 + y1) / 2.0, z_cara + afuera * 0.04),
			Vector3(0.24, y1 - y0, 0.1), C_MARCO, false)
		Construir.caja(casa, Vector3(cx + lado * (an / 2.0 + 0.62), (y0 + y1) / 2.0, z_cara + afuera * 0.06),
			Vector3(0.95, y1 - y0 + 0.1, 0.08), color_postigo, false)
	Construir.caja(casa, Vector3(cx, y1 + 0.12, z_cara + afuera * 0.05), Vector3(an + 0.6, 0.24, 0.14), C_MARCO, false)
	Construir.caja(casa, Vector3(cx, y0 - 0.1, z_cara + afuera * 0.12), Vector3(an + 0.5, 0.18, 0.36), C_MARCO)


## Adornos contra las paredes (sin colisión, lejos de la ruta), un cartel del tema y la luz cálida.


## ¿Hay lugar para un adorno de radio "r" y alto "alto" en "p" (local)? No tiene que tapar la ruta
## (ni de cerca por debajo de su altura) ni meterse en un obstáculo.
static func _hay_lugar(ce: CasaEnterable, ruta: PackedVector3Array, p: Vector3, r: float, alto: float) -> bool:
	for q in ruta:
		if q.y < p.y + alto + 0.6 and Vector2(q.x - p.x, q.z - p.z).length() < r + 0.6:
			return false
	for caja: Array in ce.cajas:
		var c: Vector3 = caja[0]
		var e: Vector3 = caja[1]
		if Vector2(c.x - p.x, c.z - p.z).length() < r + maxf(e.x, e.z) + 0.15 and c.y - e.y < p.y + alto:
			return false
	return true


## Pone un adorno si hay lugar: lejos de la ruta, de los obstáculos y de los otros adornos (que se
## anotan en el meta "ocupado" de la casa: [x, z, radio]).
static func _adorno(casa: Node3D, ce: CasaEnterable, ruta: PackedVector3Array, nombre: String, p: Vector3, rot: float, s := 1.0) -> bool:
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	var tam: Vector3 = d["tam"]
	var r := maxf(tam.x, tam.z) * s / 2.0
	if not _hay_lugar(ce, ruta, p, r, float(d["y1"]) * s):
		return false
	var ocupado: Array = ce.get_meta(&"ocupado", [])
	for o: Array in ocupado:
		if Vector2(float(o[0]) - p.x, float(o[1]) - p.z).length() < r + float(o[2]) - 0.1:
			return false
	ocupado.append([p.x, p.z, r])
	ce.set_meta(&"ocupado", ocupado)
	Kit.colocar(casa, nombre, p, rot, Vector3.ONE * s)
	return true


## Lo que se pone contra las paredes de cada escenario, en orden (se repite si sobra pared).
const DECO := {
	"libreria": ["biblioteca", "silla", "lampara_pie", "biblioteca", "mesa_ratona", "maceta", "biblioteca", "cajas"],
	"panaderia": ["estante_panes", "canasto_panes", "silla", "maceta", "estante_panes", "cajas", "mesa_ratona"],
	"conventillo": ["torre_macetas", "silla", "jaula", "maceta", "mesa_mate", "lampara_pie", "torre_macetas", "cajas"],
	"oficina": ["archivero", "silla", "maceta", "dispenser", "planta_alta", "lampara_pie", "archivero", "cajas"],
	"fiambreria": ["barril", "heladera_vitrina", "cajas", "barril", "silla", "maceta", "estante_panes"],
	"supermercado": ["heladera_bebidas", "gondola", "canasto_super", "heladera_bebidas", "cajon_frutas", "gondola", "cajas"],
	"verduleria": ["cajon_frutas", "estante_cajones", "cajon_verduras", "canasto_panes", "cajon_frutas", "maceta", "cajas"],
	"casa": ["mueble_tv", "mesita_luz", "cama", "mesita_luz", "maceta", "lampara_pie", "ropero", "sillon_azul"],
	"cafe": ["mesa_cafe", "maceta", "mesa_cafe", "tacho", "heladera_bebidas", "mesa_cafe", "lampara_pie"],
	"restaurante": ["mesa_mantel", "silla", "jardinera_alta", "mesa_mantel", "silla", "maceta", "barril"],
	"consultorio": ["sillas_espera", "maceta", "balanza_medica", "silla_ruedas", "armario_medico", "sillas_espera", "dispenser"],
}
## Lo que va en el rincón de atrás a la izquierda (si no está, el sillón con el gato y la lámpara).
const RINCON := {"supermercado": "heladera_bebidas", "verduleria": "cajon_verduras", "consultorio": "sillas_espera",
	"restaurante": "mesa_mantel", "fiambreria": "barril", "panaderia": "canasto_panes", "cafe": "mesa_cafe"}
## Algo propio de cada lugar, contra la pared derecha.
const PROPIO := {"panaderia": "horno", "oficina": "dispenser", "fiambreria": "barril", "conventillo": "jaula",
	"libreria": "mesa_ratona", "supermercado": "caja_super", "verduleria": "puesto_frutas", "casa": "mesa_comedor",
	"cafe": "vitrina_tortas", "restaurante": "mesa_mantel", "consultorio": "camilla"}
const DECO_ALTO_MAX := 2.5   ## Lo alto se achica a esto: así no le tapa el cuarto a la cámara


## Más decoración: recorre las cuatro paredes y llena cada hueco libre con un mueble del tema, de
## espaldas a la pared (sin colisión, y sólo donde no tapa la ruta, las ventanas ni otros muebles).
## Arriba, cuadros entre los estantes de las paredes de adelante y de atrás.
static func _mas_adornos(casa: Node3D, ce: CasaEnterable, tema: String) -> void:
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	var ruta := _muestras(ce)
	var lista: Array = DECO[tema]
	var k := 0
	# Cada pared: [punto inicial, dirección a lo largo, hacia adentro, largo, giro, x de su ventana]
	var paredes := [
		[Vector3(-hx, 0, -hz), Vector3(0, 0, 1), Vector3(1, 0, 0), hz * 2.0, PI / 2.0, INF],
		[Vector3(hx, 0, hz), Vector3(0, 0, -1), Vector3(-1, 0, 0), hz * 2.0, -PI / 2.0, INF],
		[Vector3(-hx, 0, hz), Vector3(1, 0, 0), Vector3(0, 0, -1), hx * 2.0, PI, ce.x_frente],
		[Vector3(hx, 0, -hz), Vector3(-1, 0, 0), Vector3(0, 0, 1), hx * 2.0, 0.0, ce.x_fondo],
	]
	for pared: Array in paredes:
		var a: Vector3 = pared[0]
		var u: Vector3 = pared[1]
		var n: Vector3 = pared[2]
		var largo: float = pared[3]
		var t := 1.0   # Los rincones ya tienen lo suyo
		while t < largo - 1.0:
			var nombre: String = lista[k % lista.size()]
			var d: Dictionary = MueblesDatos.PIEZAS[nombre]
			var tam: Vector3 = d["tam"]
			var s := minf(1.0, DECO_ALTO_MAX / float(d["y1"]))
			var centro := t + tam.x * s / 2.0
			var p := a + u * centro + n * (tam.z * s / 2.0 + 0.06) + Vector3.UP * 0.02
			# Ni delante de la ventana ni de sus cortinas
			var lejos_ventana := is_inf(float(pared[5])) or absf(p.x - float(pared[5])) > CasaEnterable.VENTANA_ANCHO / 2.0 + 0.9 + tam.x * s / 2.0
			if centro + tam.x * s / 2.0 < largo - 0.6 and lejos_ventana and _adorno(casa, ce, ruta, nombre, p, float(pared[4]), s):
				k += 1
				t += tam.x * s + 0.35
			else:
				t += 0.5
	# Cuadros en las paredes de adelante y de atrás, entre los estantes y lejos de las ventanas
	for lado in [-1.0, 1.0]:
		var x_ventana := ce.x_frente if lado > 0.0 else ce.x_fondo
		var x := -hx + 2.2
		while x < hx - 1.0:
			if absf(x - x_ventana) > 2.8:
				Kit.colocar(casa, "cuadro", Vector3(x, 3.15, lado * (hz - 0.03)), PI if lado > 0.0 else 0.0, Vector3.ONE * 0.8)
			x += 2.4


## Muebles de adorno contra las paredes y en los rincones (sin colisión: la paloma no se queda
## adentro), siempre lejos de la ruta y de los obstáculos. Un cartel del tema y la luz cálida.
static func _adornos(casa: Node3D, ce: CasaEnterable, tema: String, cartel: String) -> OmniLight3D:
	var w := ce.ancho
	var d := ce.fondo
	var hx := w / 2.0 - CasaEnterable.ESPESOR
	var hz := d / 2.0 - CasaEnterable.ESPESOR
	var ruta := _muestras(ce)
	# Alfombra en el medio (abajo de todo: nunca tapa la ruta)
	Kit.colocar(casa, "alfombra", Vector3(0, 0.02, 0), 0.0, Vector3(minf(w * 0.3, 2.2), 1.0, minf(d * 0.35, 2.0)) / Vector3(2.4, 1.0, 1.6) * 1.6)
	# Rincón de atrás a la izquierda: algo del lugar, o el sillón con el gato encima y una lámpara
	if RINCON.has(tema):
		var nombre_r: String = RINCON[tema]
		var tam_r: Vector3 = MueblesDatos.PIEZAS[nombre_r]["tam"]
		_adorno(casa, ce, ruta, nombre_r, Vector3(-hx + tam_r.z / 2.0 + 0.08, 0.02, -hz + tam_r.x / 2.0 + 0.3), PI / 2.0,
			minf(1.0, DECO_ALTO_MAX / float(MueblesDatos.PIEZAS[nombre_r]["y1"])))
	else:
		var sillon := "sillon_amarillo" if tema in ["libreria", "conventillo"] else "sillon_azul"
		var ps := Vector3(-hx + 0.5, 0.02, -hz + 1.15)
		if _adorno(casa, ce, ruta, sillon, ps, PI / 2.0):
			Kit.colocar(casa, "gato", ps + Vector3(0.05, 0.45, -0.4), PI / 2.0 + 0.4)
			_adorno(casa, ce, ruta, "lampara_pie", Vector3(-hx + 0.35, 0.02, -hz + 2.6), 0.0)
	# Rincones de adelante a la derecha y de atrás a la derecha: plantas y cajas
	_adorno(casa, ce, ruta, "maceta", Vector3(hx - 0.4, 0.02, hz - 0.4), 0.0)
	_adorno(casa, ce, ruta, "maceta", Vector3(-hx + 0.4, 0.02, hz - 0.4), 1.0)
	_adorno(casa, ce, ruta, "cajas", Vector3(hx - 0.5, 0.02, -hz + 0.5), 0.3)
	# Algo propio de cada lugar, contra la pared derecha
	var propio: String = PROPIO[tema]
	var tam_p: Vector3 = MueblesDatos.PIEZAS[propio]["tam"]
	_adorno(casa, ce, ruta, propio, Vector3(hx - tam_p.z / 2.0 - 0.1, 0.02, 0.0), -PI / 2.0)
	# Estantes en las paredes de adelante y de atrás (salvo frente a las ventanas) y cuadros a los costados
	for lado in [-1.0, 1.0]:
		var z: float = lado * (hz - 0.17)
		var x_ventana := ce.x_frente if lado > 0.0 else ce.x_fondo
		var x := -hx + 1.0
		while x < hx - 0.9:
			if absf(x - x_ventana) > 2.6:
				Kit.colocar(casa, "estante_pared", Vector3(x, 4.4, z), PI if lado > 0.0 else 0.0)
			x += 2.4
		var xs: float = lado * (hx - 0.03)
		for k in 2:
			Kit.colocar(casa, "cuadro", Vector3(xs, 2.9, (k - 0.5) * d * 0.4), -lado * PI / 2.0)
	# Cartel del tema, pintado en la pared izquierda
	var l := Construir.cartel(casa, Vector3(-hx + 0.03, 4.9, 0), cartel, Color("3a2a1e"), 56)
	l.rotation.y = PI / 2.0
	l.outline_size = 0
	# Luz: una principal del color del lugar (con sombras sólo mientras la paloma pasa, ver
	# CasaEnterable) y dos de relleno más suaves cerca de las ventanas, como la luz que entra de la calle
	var color_luz: Color = ESCENARIOS[tema]["luz"]
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = color_luz
	luz.light_energy = 1.15
	luz.omni_range = maxf(w, d) * 0.85
	luz.omni_attenuation = 0.8
	luz.shadow_enabled = false
	casa.add_child(luz)
	luz.position = Vector3(0, PLANTA_BAJA - 0.9, 0)
	for ventana in [[ce.x_frente, hz - 1.2], [ce.x_fondo, -hz + 1.2]]:
		var relleno := OmniLight3D.new()
		relleno.light_color = color_luz.lerp(Color("cfe4ff"), 0.45)
		relleno.light_energy = 0.38
		relleno.omni_range = minf(w, d) * 0.8
		relleno.shadow_enabled = false
		luz.add_child(relleno)   # Se prende y se apaga con la principal
		relleno.position = Vector3(float(ventana[0]), CasaEnterable.Y_PASO, float(ventana[1])) - luz.position
	return luz


# ---------------------------------------------------------------- Fachada e interior (mejor terminados)

static func _x_puerta(w: float) -> float:
	return w * 0.27


## Fachada: una fila de ventanas con vidrio y persiana por piso (con balcones con macetas en algunos
## pisos), salvo en la planta baja y en los dos pisos de la sala; el toldo a rayas sobre la ventana
## abierta de la sala, la puerta del edificio con su farolito, y un macetón y una bici en la vereda.
## Atrás, lo mismo sin toldo. Todo sin colisión. "y0": altura del piso de la sala.
static func _fachada(casa: Node3D, ce: CasaEnterable, w: float, h: float, d: float, esc: Dictionary, y0 := 0.0) -> void:
	var pb := PLANTA_BAJA
	var n_col := maxi(int(w / 3.0), 1)
	var filas: Array[float] = []
	var k := 1
	while k * ALTO_PISO + 0.6 + 2.0 < h - 0.2:
		var yv := k * ALTO_PISO + 0.6
		if yv + 2.1 < y0 - 0.25 or yv > y0 + pb + 0.35:
			filas.append(yv)
		k += 1
	for e in [1.0, -1.0]:
		var z: float = e * d / 2.0
		var rot: float = 0.0 if e > 0.0 else PI
		for f in filas.size():
			for c in n_col:
				var off := (c - (n_col - 1) / 2.0) * (w / n_col)
				var balcon := f % 3 == 0 and c == n_col / 2
				Kit.colocar(casa, "ventana_balcon" if balcon else "ventana_vidrio",
					Vector3(off, filas[f] - (0.35 if balcon else 0.0), z), rot)
		# Puerta del edificio, del lado contrario a la ventana abierta de esa cara
		var xp: float = e * _x_puerta(w)
		Kit.colocar(casa, "puerta_local", Vector3(xp, 0.14, z), rot)
		Kit.colocar(casa, "maceton_flores", Vector3(xp + e * 1.3, 0.0, z + e * 0.6), 0.0)
		# En la planta baja, si la sala está arriba, una vidriera a cada lado de la puerta
		if y0 > 0.0:
			for lado in [-1.0, 1.0]:
				var xv: float = -e * _x_puerta(w) + lado * 1.6
				if absf(xv) < w / 2.0 - 0.9:
					Kit.colocar(casa, "ventana_vidrio", Vector3(xv, 0.6, z), rot)
	# Toldo a rayas sobre la ventana de adelante: la paloma entra por debajo
	Kit.colocar(casa, esc["toldo"], Vector3(ce.x_frente, y0 + 4.2, d / 2.0), 0.0)
	Kit.colocar(casa, "bici_azul", Vector3(_x_puerta(w) - 1.7, 0.0, d / 2.0 + 0.45), 0.0)


## Interior: piso de tablas o de baldosas, zócalo, friso y moldura en las cuatro paredes, vigas (o
## paneles) en el techo, apliques con luz y cortinas a los costados de cada ventana. Sin colisión.
static func _interior(casa: Node3D, ce: CasaEnterable, w: float, d: float, esc: Dictionary) -> void:
	var esp := CasaEnterable.ESPESOR
	var hx := w / 2.0 - esp
	var hz := d / 2.0 - esp
	var pb := PLANTA_BAJA
	# El piso: una sola lámina con textura (tablas, damero o porcelanato; ver TexturasInterior)
	Construir.caja_mat(casa, Vector3(0, 0.035, 0), Vector3(hx * 2.0, 0.01, hz * 2.0),
		TexturasInterior.piso(esc["suelo"], esc["piso"], esc["piso2"]), false)
	# Zócalo, friso (la parte de abajo de la pared, más oscura) y moldura
	var zocalo: Color = esc["zocalo"]
	var friso: Color = (esc["pared"] as Color).darkened(0.12)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hx - 0.035)
		Construir.caja(casa, Vector3(x, 0.6, 0), Vector3(0.02, 1.1, hz * 2.0), friso, false)
		Construir.caja(casa, Vector3(sx * (hx - 0.05), 0.09, 0), Vector3(0.04, 0.16, hz * 2.0), zocalo, false)
		Construir.caja(casa, Vector3(sx * (hx - 0.05), 1.15, 0), Vector3(0.05, 0.06, hz * 2.0), C_MARCO, false)
	for sz in [-1.0, 1.0]:
		var z: float = sz * (hz - 0.035)
		Construir.caja(casa, Vector3(0, 0.6, z), Vector3(hx * 2.0, 1.1, 0.02), friso, false)
		Construir.caja(casa, Vector3(0, 0.09, sz * (hz - 0.05)), Vector3(hx * 2.0, 0.16, 0.04), zocalo, false)
		Construir.caja(casa, Vector3(0, 1.15, sz * (hz - 0.05)), Vector3(hx * 2.0, 0.06, 0.05), C_MARCO, false)
	# Techo: vigas de madera, o paneles con luces en la oficina y la fiambrería
	if esc["vigas"]:
		var x := -hx + 0.9
		while x < hx - 0.5:
			Construir.caja(casa, Vector3(x, pb - 0.14, 0), Vector3(0.22, 0.26, hz * 2.0), Color("6b4a32"), false)
			x += 1.8
	else:
		var x := -hx + 1.2
		while x < hx - 0.6:
			var z := -hz + 1.2
			while z < hz - 0.6:
				Construir.caja_mat(casa, Vector3(x, pb - 0.03, z), Vector3(1.0, 0.03, 0.5),
					TexturasInterior.panel_luz(esc["luz"]), false)
				z += 2.4
			x += 2.4
	# Apliques con luz en las paredes de los costados (arriba de los cuadros)
	for sx in [-1.0, 1.0]:
		for k in 2:
			Kit.colocar(casa, "aplique", Vector3(sx * (hx - 0.01), 3.9, (k - 0.5) * hz), -sx * PI / 2.0)
	# Cortinas a los costados de las dos ventanas
	for ventana in [[ce.x_frente, hz - 0.02, PI], [ce.x_fondo, -hz + 0.02, 0.0]]:
		for lado in [-1.0, 1.0]:
			Kit.colocar(casa, esc["cortina"], Vector3(float(ventana[0]) + lado * (CasaEnterable.VENTANA_ANCHO / 2.0 + 0.45), 1.12,
				float(ventana[1])), float(ventana[2]))
