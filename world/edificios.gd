class_name Edificios
extends RefCounted
## Funciones que arman cada edificio y zona de la plaza con primitivas.
## Todas reciben el nodo padre y construyen hijos con colisión donde hace falta.

const C_BLANCO := Color("f4f1e8")
const C_CREMA := Color("e6dccb")
const C_TEJAS := Color("b5532f")
const C_ROSADA := Color("e8a0a0")
const C_ROSADA_OSC := Color("c98585")
const C_VENTANA := Color("3b4250")
const C_MADERA := Color("8a5a35")
const C_METAL := Color("3f4a45")
const C_PASTO := Color("6fa14f")
const C_TRONCO := Color("6b4a32")
const C_JACARANDA := Color("9b7ad8")
const C_JACARANDA_2 := Color("b296e6")


# ---------------------------------------------------------------- Genéricos

## Edificio de caja con cornisas (para posarse) y ventanas en el frente.
## base = centro de la base; frente = normal de la fachada principal (eje X o Z).
static func edificio(padre: Node3D, base: Vector3, tam: Vector3, color: Color, frente: Vector3,
		color_cornisa := C_BLANCO, pisos := -1) -> void:
	Construir.caja(padre, base + Vector3(0, tam.y / 2.0, 0), tam, color)
	# Cornisa superior: sobresale para que se pueda aterrizar en el borde
	Construir.caja(padre, base + Vector3(0, tam.y + 0.2, 0), Vector3(tam.x + 1.0, 0.4, tam.z + 1.0), color_cornisa)
	# Cornisa intermedia sólo en el frente
	var ancho_frente := tam.x if absf(frente.z) > 0.5 else tam.z
	var prof := tam.z if absf(frente.z) > 0.5 else tam.x
	var tangente := Vector3(1, 0, 0) if absf(frente.z) > 0.5 else Vector3(0, 0, 1)
	var cara := base + frente * (prof / 2.0)
	var y_cornisa := tam.y * 0.45
	var tam_corn := Vector3(ancho_frente, 0.3, 0.8)
	if absf(frente.x) > 0.5:
		tam_corn = Vector3(0.8, 0.3, ancho_frente)
	Construir.caja(padre, cara + frente * 0.35 + Vector3(0, y_cornisa, 0), tam_corn, color_cornisa)
	# Ventanas
	var n_pisos := pisos if pisos > 0 else maxi(int(tam.y / 3.2), 1)
	var n_col := maxi(int(ancho_frente / 3.0), 1)
	var tam_v := Vector3(1.1, 1.6, 0.12) if absf(frente.z) > 0.5 else Vector3(0.12, 1.6, 1.1)
	for p in n_pisos:
		var y := 1.6 + p * (tam.y - 1.0) / n_pisos
		if absf(y - y_cornisa) < 1.0:
			y += 0.9
		for c in n_col:
			var off := (c - (n_col - 1) / 2.0) * (ancho_frente / n_col)
			Construir.caja(padre, cara + tangente * off + frente * 0.03 + Vector3(0, y, 0), tam_v, C_VENTANA, false)


static func jacaranda(padre: Node3D, pos: Vector3, escala := 1.0) -> void:
	var alto := 3.2 * escala
	Construir.cilindro(padre, pos + Vector3(0, alto / 2.0, 0), 0.22 * escala, alto, C_TRONCO, true, 6, 0.15 * escala)
	# Copa: varias esferas violetas. La de arriba tiene colisión para posarse.
	var copa := [Vector3(0, 0, 0), Vector3(1.0, -0.3, 0.4), Vector3(-0.9, -0.2, -0.5), Vector3(0.2, 0.5, -0.8)]
	for i in copa.size():
		var c: Vector3 = copa[i]
		var color := C_JACARANDA if i % 2 == 0 else C_JACARANDA_2
		Construir.esfera(padre, pos + Vector3(0, alto + 0.8 * escala, 0) + c * escala, 1.5 * escala, color,
			Vector3(1, 0.75, 1), 8)
	var forma := SphereShape3D.new()
	forma.radius = 1.6 * escala
	Construir.colision(padre, pos + Vector3(0, alto + 0.7 * escala, 0), forma)


static func banco(padre: Node3D, pos: Vector3, rot_y := 0.0) -> void:
	var n := Node3D.new()
	padre.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	Construir.caja(n, Vector3(0, 0.45, 0), Vector3(2.0, 0.08, 0.6), C_MADERA)
	Construir.caja(n, Vector3(0, 0.8, 0.27), Vector3(2.0, 0.5, 0.06), C_MADERA, false)
	for x in [-0.85, 0.85]:
		Construir.caja(n, Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.5), C_METAL, false)


static func farol(padre: Node3D, pos: Vector3) -> void:
	Construir.cilindro(padre, pos + Vector3(0, 2.0, 0), 0.07, 4.0, Color("23282b"), true, 6)
	Construir.esfera(padre, pos + Vector3(0, 4.15, 0), 0.25, Color("fff6d8"), Vector3.ONE, 8)


## Valla metálica de un tramo (para la Casa Rosada).
static func valla(padre: Node3D, desde: Vector3, hasta: Vector3) -> void:
	var medio := (desde + hasta) / 2.0
	var largo := desde.distance_to(hasta)
	var ang := atan2(hasta.x - desde.x, hasta.z - desde.z)
	var n := Node3D.new()
	padre.add_child(n)
	n.position = medio
	n.rotation.y = ang
	Construir.caja(n, Vector3(0, 1.05, 0), Vector3(0.08, 0.08, largo), Color("9aa0a3"), false)
	Construir.caja(n, Vector3(0, 0.25, 0), Vector3(0.08, 0.08, largo), Color("9aa0a3"), false)
	var barrotes := int(largo / 0.35)
	for i in barrotes:
		Construir.caja(n, Vector3(0, 0.62, -largo / 2.0 + (i + 0.5) * largo / barrotes), Vector3(0.04, 0.85, 0.04), Color("9aa0a3"), false)
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.3, 1.1, largo)
	Construir.colision(padre, medio + Vector3(0, 0.55, 0), forma, Vector3(0, ang, 0))


# ---------------------------------------------------------------- Zonas

## Centro: Pirámide de Mayo (el nido).
static func piramide(padre: Node3D) -> void:
	# Escalones de la base
	Construir.caja(padre, Vector3(0, 0.15, 0), Vector3(9, 0.3, 9), C_BLANCO)
	Construir.caja(padre, Vector3(0, 0.45, 0), Vector3(7.5, 0.3, 7.5), C_BLANCO)
	# Pedestal
	Construir.caja(padre, Vector3(0, 1.85, 0), Vector3(4.2, 2.5, 4.2), Color("f7f4ec"))
	Construir.caja(padre, Vector3(0, 3.2, 0), Vector3(4.8, 0.3, 4.8), C_BLANCO)
	# Obelisco: cilindro de 4 lados que se afina
	var ob := Construir.cilindro(padre, Vector3(0, 7.8, 0), 1.6, 9.0, Color("fbf9f3"), true, 4, 0.9)
	ob.rotation.y = PI / 4.0
	_rot(Construir.cilindro(padre, Vector3(0, 12.8, 0), 0.9, 1.0, Color("fbf9f3"), true, 4, 0.2), "y", PI / 4.0)
	# Figura de la cima (abstracta: una esfera sobre un pedestal chico)
	Construir.esfera(padre, Vector3(0, 13.7, 0), 0.45, Color("e9e4d8"), Vector3(1, 1.3, 1), 8)
	# Rejita alrededor
	for i in 4:
		var ang := i * PI / 2.0
		var d := Vector3(sin(ang), 0, cos(ang))
		var t := Vector3(d.z, 0, -d.x)
		valla(padre, d * 5.2 + t * 5.2, d * 5.2 - t * 5.2)


## Oeste: el Cabildo, blanco con galería de arcos, torre y techo de tejas.
static func cabildo(padre: Node3D) -> void:
	var x_fondo := -57.0
	var x_frente := -45.0
	# Cuerpo trasero
	Construir.caja(padre, Vector3(-52.5, 4.5, 0), Vector3(9, 9, 30), C_BLANCO)
	# Piso superior sobre la galería
	Construir.caja(padre, Vector3(-46.5, 6.9, 0), Vector3(3, 4.2, 30), C_BLANCO)
	# Columnas de la galería (planta baja)
	for i in 11:
		var z := -15.0 + i * 3.0
		Construir.caja(padre, Vector3(x_frente - 0.4, 2.4, z), Vector3(0.8, 4.8, 0.8), C_BLANCO)
	# Arcos (sombra oscura dentro de la galería)
	Construir.caja(padre, Vector3(-47.9, 2.4, 0), Vector3(0.2, 4.6, 29.6), Color("cfc8b8"), false)
	# Ventanas y balconcitos del piso alto
	for i in 10:
		var z := -13.5 + i * 3.0
		Construir.caja(padre, Vector3(x_frente - 0.02, 6.6, z), Vector3(0.1, 2.0, 1.1), C_VENTANA, false)
		Construir.caja(padre, Vector3(x_frente + 0.35, 5.5, z), Vector3(0.7, 0.15, 1.5), C_MADERA)
	# Cornisa (lugar ideal para posarse)
	Construir.caja(padre, Vector3(-51.0, 9.15, 0), Vector3(13.2, 0.3, 31.0), C_BLANCO)
	# Techo de tejas (prisma con la cumbrera a lo largo de Z)
	Construir.prisma(padre, Vector3(-51.0, 10.6, 0), Vector3(12.5, 2.6, 30.0), C_TEJAS, Vector3.ZERO, true)
	# Torre central con cúpula y reloj
	Construir.caja(padre, Vector3(-46.5, 13.0, 0), Vector3(4, 7.6, 4), C_BLANCO)
	Construir.caja(padre, Vector3(-46.5, 16.95, 0), Vector3(4.6, 0.3, 4.6), C_BLANCO)
	_rot(Construir.cilindro(padre, Vector3(-44.47, 13.9, 0), 1.0, 0.1, Color("fdfbf0"), false, 16), "z", PI / 2.0)
	Construir.caja(padre, Vector3(-44.39, 14.15, 0), Vector3(0.06, 0.6, 0.08), Color("2a2a2a"), false)
	var cupula := Construir.esfera(padre, Vector3(-46.5, 17.1, 0), 1.6, C_TEJAS.lightened(0.15), Vector3(1, 0.9, 1), 10)
	cupula.scale = Vector3(1, 0.9, 1)
	var forma := SphereShape3D.new()
	forma.radius = 1.5
	Construir.colision(padre, Vector3(-46.5, 17.0, 0), forma)
	# El nombre va pintado en el frente de la torre, debajo del reloj
	_rot(Construir.cartel(padre, Vector3(-44.44, 11.2, 0), "CABILDO", Color("6b5a40"), 56), "y", PI / 2.0)
	# Fondo cerrado para que no se vea el vacío
	Construir.caja(padre, Vector3(x_fondo - 1.0, 5, 0), Vector3(2, 10, 30), C_CREMA)


## Norte: la Catedral, con columnas, frontón y escalinata.
static func catedral(padre: Node3D) -> void:
	# Cuerpo
	Construir.caja(padre, Vector3(0, 7.5, -35.5), Vector3(32, 15, 9), C_CREMA)
	Construir.caja(padre, Vector3(0, 15.2, -35.5), Vector3(33, 0.4, 10), C_BLANCO)
	# Cúpula detrás
	Construir.cilindro(padre, Vector3(0, 17.0, -36.5), 3.2, 3.6, C_CREMA, true, 12)
	Construir.esfera(padre, Vector3(0, 18.8, -36.5), 3.3, Color("8fa3a8"), Vector3(1, 0.8, 1), 12)
	var forma := SphereShape3D.new()
	forma.radius = 3.0
	Construir.colision(padre, Vector3(0, 19.0, -36.5), forma)
	# Plataforma (estilóbato) y columnas del pórtico
	Construir.caja(padre, Vector3(0, 1.0, -28.5), Vector3(32, 2.0, 5), C_BLANCO)
	for i in 12:
		var x := -13.75 + i * 2.5
		Construir.cilindro(padre, Vector3(x, 6.5, -27.0), 0.55, 9.0, Color("f2ead9"), true, 8)
	# Entablamento y frontón triangular
	Construir.caja(padre, Vector3(0, 11.8, -28.5), Vector3(32.4, 1.6, 5.2), C_BLANCO)
	Construir.prisma(padre, Vector3(0, 14.1, -28.5), Vector3(32.4, 3.0, 5.0), C_CREMA, Vector3.ZERO, true)
	# Puerta
	Construir.caja(padre, Vector3(0, 4.5, -30.95), Vector3(4, 5, 0.1), Color("5a3b26"), false)
	# Escalinata: 10 escalones macizos (apoyados en el piso, sin huecos) que llegan hasta la
	# plataforma. Para subirla caminando hay una rampa invisible que pasa por la mitad de cada
	# contrahuella; la colisión de cada escalón queda 10 cm por debajo de la rampa, así de costado
	# también es sólida pero al caminar sólo se pisa la rampa.
	const PELDANOS := 10
	const ALZADA := 0.2
	const HUELLA := 0.5
	const Z_PIE := -21.0
	for e in PELDANOS:
		var alto := ALZADA * (e + 1)
		var z := Z_PIE - HUELLA * (e + 0.5)
		Construir.caja(padre, Vector3(0, alto / 2.0, z), Vector3(30, alto, HUELLA),
			Color("ece6da").darkened((e % 2) * 0.035), false)
		var alto_col := alto if e == PELDANOS - 1 else alto - ALZADA * 0.5
		var forma_esc := BoxShape3D.new()
		forma_esc.size = Vector3(30, alto_col, HUELLA)
		Construir.colision(padre, Vector3(0, alto_col / 2.0, z), forma_esc)
	# Rampa: de (z = pie + media huella, y = 0) hasta (z = arriba, y = 2.0)
	var z0 := Z_PIE + HUELLA * 0.5
	var z1 := z0 - HUELLA * PELDANOS
	var alto_total := ALZADA * PELDANOS
	var largo := Vector2(z0 - z1, alto_total).length()
	var ang := atan2(alto_total, z0 - z1)
	var normal := Vector3(0, z0 - z1, alto_total) / largo
	var rampa := BoxShape3D.new()
	rampa.size = Vector3(30, 0.2, largo)
	Construir.colision(padre, Vector3(0, alto_total / 2.0, (z0 + z1) / 2.0) - normal * 0.1, rampa, Vector3(ang, 0, 0))
	Construir.cartel(padre, Vector3(0, 11.8, -25.85), "CATEDRAL", Color("6b5a40"), 64)


## Sur: avenida con cafés, toldos, mesas en la vereda y nombres inventados.
static func cafes(padre: Node3D) -> Array[Vector3]:
	var mesas: Array[Vector3] = []
	var negocios := [
		{"x": -30.0, "ancho": 18.0, "alto": 11.0, "color": Color("e9d5b0"), "toldo": Color("2f7d5b"), "nombre": "Café La Medialuna Feliz"},
		{"x": -8.0, "ancho": 16.0, "alto": 13.0, "color": Color("d9b48f"), "toldo": Color("b8423a"), "nombre": "Confitería El Buen Mozo"},
		{"x": 13.0, "ancho": 16.0, "alto": 10.0, "color": Color("efe3c8"), "toldo": Color("2b4f8a"), "nombre": "Bar Los Vencejos"},
		{"x": 32.0, "ancho": 14.0, "alto": 14.0, "color": Color("cfcfc7"), "toldo": Color("54585c"), "nombre": "Banco Austral Imaginario"},
	]
	for n: Dictionary in negocios:
		var x: float = n["x"]
		var ancho: float = n["ancho"]
		edificio(padre, Vector3(x, 0, 43.0), Vector3(ancho, n["alto"], 10), n["color"], Vector3(0, 0, -1))
		# Vidriera oscura en planta baja
		Construir.caja(padre, Vector3(x, 1.6, 37.95), Vector3(ancho - 2.0, 2.6, 0.1), Color("2e3640"), false)
		# Toldo inclinado (se puede aterrizar encima)
		var toldo := Construir.caja(padre, Vector3(x, 3.4, 36.6), Vector3(ancho - 1.0, 0.12, 2.8), n["toldo"])
		toldo.rotation.x = -0.25
		for f in 3:
			_rot(Construir.caja(padre, Vector3(x - (ancho - 1.0) / 2.0 + (f * 2 + 1) * (ancho - 1.0) / 6.0, 3.42, 36.6),
				Vector3((ancho - 1.0) / 6.0, 0.13, 2.82), Color.WHITE, false), "x", -0.25)
		# Letrero sobre una tabla pegada a la fachada, justo encima del toldo
		Construir.letrero(padre, Vector3(x, 4.08, 37.8), n["nombre"], Color.WHITE,
			(n["toldo"] as Color).darkened(0.35), 40, Vector2(ancho - 3.0, 0.5), PI)
		# Mesas en la vereda (no frente al banco)
		if not str(n["nombre"]).begins_with("Banco"):
			for m in 3:
				var pos := Vector3(x - ancho / 3.0 + m * ancho / 3.0, 0.16, 34.6)
				mesa(padre, pos)
				mesas.append(pos + Vector3(0, 0.78, 0))
	return mesas


static func mesa(padre: Node3D, pos: Vector3) -> void:
	Construir.cilindro(padre, pos + Vector3(0, 0.37, 0), 0.05, 0.74, C_METAL, false, 6)
	Construir.cilindro(padre, pos + Vector3(0, 0.76, 0), 0.5, 0.04, Color("f2f2ee"), true, 12)
	for lado in [-1.0, 1.0]:
		var silla := pos + Vector3(0.85 * lado, 0, 0)
		Construir.caja(padre, silla + Vector3(0, 0.45, 0), Vector3(0.45, 0.06, 0.45), C_MADERA, false)
		Construir.caja(padre, silla + Vector3(0.2 * lado, 0.75, 0), Vector3(0.05, 0.6, 0.45), C_MADERA, false)


## Noreste: boca de subte con barandas y cartel.
static func subte(padre: Node3D, pos: Vector3) -> void:
	# Agujero de la escalera (oscuro) y escalones que bajan
	Construir.caja(padre, pos + Vector3(0, 0.01, 0), Vector3(3.2, 0.02, 6), Color("1d1f24"), false)
	for e in 5:
		Construir.caja(padre, pos + Vector3(0, 0.03, -2.5 + e * 1.1), Vector3(3.0, 0.02, 0.15), Color("5a5d63"), false)
	# Barandas verdes en tres lados
	var verde := Color("2f6b4a")
	for lado in [-1.0, 1.0]:
		Construir.caja(padre, pos + Vector3(1.7 * lado, 0.55, 0), Vector3(0.12, 1.1, 6.2), verde)
	Construir.caja(padre, pos + Vector3(0, 0.55, -3.05), Vector3(3.5, 1.1, 0.12), verde)
	# Cartel en un poste
	Construir.cilindro(padre, pos + Vector3(2.3, 1.5, 3.2), 0.06, 3.0, Color("23282b"), true, 6)
	Construir.caja(padre, pos + Vector3(2.3, 3.2, 3.2), Vector3(0.1, 0.8, 1.6), verde)
	_rot(Construir.cartel(padre, pos + Vector3(2.2, 3.2, 3.2), "SUBTE\nLínea Ñ", Color.WHITE, 40), "y", -PI / 2.0)
	_rot(Construir.cartel(padre, pos + Vector3(2.4, 3.2, 3.2), "SUBTE\nLínea Ñ", Color.WHITE, 40), "y", PI / 2.0)


## Este: la Casa Rosada con vallas y el balcón (la meta). Devuelve la posición del balcón.
static func casa_rosada(padre: Node3D) -> Vector3:
	var x_frente := 44.0
	# Cuerpo principal
	Construir.caja(padre, Vector3(52.5, 6.5, 0), Vector3(17, 13, 40), C_ROSADA)
	Construir.caja(padre, Vector3(52.0, 13.2, 0), Vector3(18, 0.4, 41), C_ROSADA_OSC)
	# Cuerpo central que sobresale, más alto, con frontón
	Construir.caja(padre, Vector3(42.5, 7.5, 0), Vector3(3, 15, 12), C_ROSADA)
	Construir.caja(padre, Vector3(42.3, 15.2, 0), Vector3(3.6, 0.4, 12.6), C_ROSADA_OSC)
	Construir.prisma(padre, Vector3(42.5, 16.6, 0), Vector3(12, 2.4, 3), C_ROSADA, Vector3(0, PI / 2.0, 0), true)
	# Arco de entrada
	Construir.caja(padre, Vector3(40.95, 2.2, 0), Vector3(0.1, 4.4, 3.2), Color("5a3b2e"), false)
	# Ventanas de la fachada (dos pisos), con columnitas
	for piso in 2:
		for i in 12:
			var z := -18.0 + i * 3.27
			if absf(z) < 6.5:
				continue
			Construir.caja(padre, Vector3(x_frente - 0.02, 3.0 + piso * 5.0, z), Vector3(0.1, 2.2, 1.2), C_VENTANA, false)
			Construir.caja(padre, Vector3(x_frente - 0.1, 3.0 + piso * 5.0, z + 0.9), Vector3(0.2, 3.0, 0.25), C_ROSADA_OSC, false)
	# Cornisa intermedia
	Construir.caja(padre, Vector3(x_frente - 0.3, 5.6, 0), Vector3(0.6, 0.3, 40), C_ROSADA_OSC)
	# EL BALCÓN: losa que sobresale del cuerpo central, con baranda
	var balcon := Vector3(39.9, 7.0, 0)
	Construir.caja(padre, balcon, Vector3(2.4, 0.3, 6.0), Color("f0d2d2"))
	for i in 13:
		Construir.caja(padre, balcon + Vector3(-1.1, 0.5, -2.9 + i * 0.483), Vector3(0.06, 0.7, 0.06), Color("f7e6e6"), false)
	Construir.caja(padre, balcon + Vector3(-1.1, 0.9, 0), Vector3(0.12, 0.1, 6.0), Color("f7e6e6"), false)
	Construir.caja(padre, Vector3(40.95, 8.8, 0), Vector3(0.1, 3.0, 2.0), C_VENTANA, false)
	# Vallas frente a la Casa Rosada (con un hueco no hay: hay que volar)
	valla(padre, Vector3(37.0, 0, -19.0), Vector3(37.0, 0, 19.0))
	valla(padre, Vector3(37.0, 0, -19.0), Vector3(43.5, 0, -19.0))
	valla(padre, Vector3(37.0, 0, 19.0), Vector3(43.5, 0, 19.0))
	return balcon + Vector3(0, 0.15, 0)


## Edificios bajos alrededor (con techos y cornisas para posarse).
static func alrededores(padre: Node3D) -> void:
	# Norte, a los costados de la Catedral
	edificio(padre, Vector3(-27, 0, -36), Vector3(18, 12, 8), Color("d8c9b1"), Vector3(0, 0, 1))
	edificio(padre, Vector3(-44, 0, -35), Vector3(14, 10, 10), Color("c9b9a4"), Vector3(0, 0, 1))
	edificio(padre, Vector3(26, 0, -36), Vector3(16, 13, 8), Color("e0cdb4"), Vector3(0, 0, 1))
	edificio(padre, Vector3(46, 0, -35), Vector3(16, 11, 10), Color("bfb5a8"), Vector3(0, 0, 1))
	# Al sur de la avenida, en las dos puntas (dejan la calle libre para los autos)
	edificio(padre, Vector3(-52, 0, 43), Vector3(12, 9, 12), Color("e4d3b8"), Vector3(0, 0, -1))
	edificio(padre, Vector3(50, 0, 43), Vector3(18, 12, 10), Color("d6c7b3"), Vector3(0, 0, -1))
	# Carteles de comercios inventados, sobre una tabla pegada a la pared
	Construir.letrero(padre, Vector3(-27, 4.85, -31.8), "Librería El Palomar", Color.WHITE, Color("5b3b2a"), 48,
		Vector2(6.4, 0.6))
	Construir.letrero(padre, Vector3(26, 5.0, -31.8), "Seguros La Cornisa", Color.WHITE, Color("2b4a6b"), 48,
		Vector2(6.0, 0.6))


## Rota un nodo recién creado sobre un eje ("x", "y" o "z").
static func _rot(n: Node3D, eje: String, angulo: float) -> void:
	match eje:
		"x": n.rotation.x = angulo
		"y": n.rotation.y = angulo
		"z": n.rotation.z = angulo
