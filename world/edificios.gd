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
const C_TECHO := Color("9c9a92")


# ---------------------------------------------------------------- Genéricos

## Edificio de caja con cornisas (para posarse) y ventanas en el frente.
## base = centro de la base; frente = normal de la fachada principal (eje X o Z).
## Mapa V3: azotea gris con un borde de color que sobresale (como los edificios del kit) y un par de
## aires acondicionados.
static func edificio(padre: Node3D, base: Vector3, tam: Vector3, color: Color, frente: Vector3,
		color_cornisa := C_BLANCO, pisos := -1) -> void:
	Construir.caja(padre, base + Vector3(0, tam.y / 2.0, 0), tam, color)
	# Azotea gris y el borde de color: sobresale para que se pueda aterrizar en él
	Construir.caja(padre, base + Vector3(0, tam.y + 0.05, 0), Vector3(tam.x, 0.1, tam.z), C_TECHO)
	const B := 0.55
	var y_borde := tam.y + 0.35
	for s in [-1.0, 1.0]:
		Construir.caja(padre, base + Vector3(0, y_borde, s * (tam.z / 2.0 + 0.5 - B / 2.0)), Vector3(tam.x + 1.0, 0.7, B), color_cornisa)
		Construir.caja(padre, base + Vector3(s * (tam.x / 2.0 + 0.5 - B / 2.0), y_borde, 0), Vector3(B, 0.7, tam.z), color_cornisa)
	# Aires acondicionados en la azotea (caja blanca con el ventilador oscuro arriba)
	var semilla := absi(int(base.x * 7.0 + base.z * 13.0))
	for k in 1 + semilla % 2:
		var p := base + Vector3((tam.x / 2.0 - 2.2) * (1.0 if k == 0 else -0.4), tam.y + 0.1, (tam.z / 2.0 - 2.0) * (-0.5 if k == 0 else 0.4))
		Construir.caja(padre, p + Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 1.0), Color("e8eaea"))
		for dx in [-0.38, 0.38]:
			Construir.cilindro(padre, p + Vector3(dx, 0.82, 0), 0.32, 0.04, Color("5f666b"), false, 10)
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
	var tam_v := Vector3(1.1, 1.6, 0.12) if absf(frente.z) > 0.5 else Vector3(0.12, 1.6, 1.1)
	for v: Vector2 in ventanas(tam, frente, pisos):
		Construir.caja(padre, cara + tangente * v.x + frente * 0.03 + Vector3(0, v.y, 0), tam_v, C_VENTANA, false)


## Ventanas de la fachada de un edificio(): (corrimiento a lo largo de la fachada, altura del centro).
## Las ventanas miden 1,1 x 1,6 m. Las usa también NivelMedio (balcones y toldos sobre las ventanas).
static func ventanas(tam: Vector3, frente: Vector3, pisos := -1) -> Array[Vector2]:
	var ancho_frente := tam.x if absf(frente.z) > 0.5 else tam.z
	var y_cornisa := tam.y * 0.45
	var n_pisos := pisos if pisos > 0 else maxi(int(tam.y / 3.2), 1)
	var n_col := maxi(int(ancho_frente / 3.0), 1)
	var out: Array[Vector2] = []
	for p in n_pisos:
		var y := 1.6 + p * (tam.y - 1.0) / n_pisos
		if absf(y - y_cornisa) < 1.0:
			y += 0.9
		for c in n_col:
			out.append(Vector2((c - (n_col - 1) / 2.0) * (ancho_frente / n_col), y))
	return out


static func jacaranda(padre: Node3D, pos: Vector3, escala := 1.0) -> void:
	# El árbol cuelga de su propio nodo en "pos" (así el builder lo puede mover: ver MapaOverrides)
	var n := MapaOverrides.envolver(padre, "jacaranda", "jacaranda", pos)
	if n == null:
		return
	n.set_meta(&"param_escala", escala)   # el builder lo usa al duplicar el árbol
	var alto := 3.2 * escala
	Construir.cilindro(n, Vector3(0, alto / 2.0, 0), 0.22 * escala, alto, C_TRONCO, true, 6, 0.15 * escala)
	# Copa: varias esferas violetas. La de arriba tiene colisión para posarse.
	var copa := [Vector3(0, 0, 0), Vector3(1.0, -0.3, 0.4), Vector3(-0.9, -0.2, -0.5), Vector3(0.2, 0.5, -0.8)]
	for i in copa.size():
		var c: Vector3 = copa[i]
		var color := C_JACARANDA if i % 2 == 0 else C_JACARANDA_2
		Construir.esfera(n, Vector3(0, alto + 0.8 * escala, 0) + c * escala, 1.5 * escala, color,
			Vector3(1, 0.75, 1), 8)
	var forma := SphereShape3D.new()
	forma.radius = 1.6 * escala
	Construir.colision(n, Vector3(0, alto + 0.7 * escala, 0), forma)


static func banco(padre: Node3D, pos: Vector3, rot_y := 0.0) -> void:
	var n := MapaOverrides.envolver(padre, "banco", "banco", pos, rot_y)
	if n == null:
		return
	Construir.caja(n, Vector3(0, 0.45, 0), Vector3(2.0, 0.08, 0.6), C_MADERA)
	Construir.caja(n, Vector3(0, 0.8, 0.27), Vector3(2.0, 0.5, 0.06), C_MADERA, false)
	for x in [-0.85, 0.85]:
		Construir.caja(n, Vector3(x, 0.22, 0), Vector3(0.08, 0.44, 0.5), C_METAL, false)


static func farol(padre: Node3D, pos: Vector3) -> void:
	var n := MapaOverrides.envolver(padre, "farol", "farol", pos)
	if n == null:
		return
	Construir.cilindro(n, Vector3(0, 2.0, 0), 0.07, 4.0, Color("23282b"), true, 6)
	Construir.esfera(n, Vector3(0, 4.15, 0), 0.25, Color("fff6d8"), Vector3.ONE, 8)
	LucesNoche.farol_directo(n, Vector3(0, 4.15, 0), 0.0)


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


## Oeste: el Cabildo, blanco con galería de arcos, torre con reloj y techo de tejas.
## Mapa V4.5: lo que se ve es el modelo de Blender (modelos/cabildo/cabildo.res, sacado de
## Escenario_Cabildo.glb con tools/extraer_cabildo.gd; lo genera tools/blender/generar_escenario_cabildo.py):
## ventanas con persianas en los costados y el fondo, ménsulas en los arcos, dentículos en la cornisa,
## techo a cuatro aguas con hastiales y la torre con campanario, reloj y linterna. Antes el fondo era
## una caja blanca lisa de 9 x 9 x 30 m. Acá se arma sólo la colisión, con las mismas formas de siempre:
## donde la paloma camina o se posa, el modelo tiene la misma superficie.
const CABILDO_MALLA := "res://modelos/cabildo/cabildo.res"


static func cabildo(padre: Node3D) -> void:
	var x_frente := -45.0
	var modelo := MeshInstance3D.new()
	modelo.name = "CabildoModelo"
	modelo.mesh = load(CABILDO_MALLA) as Mesh
	modelo.set_meta(&"no_fusionar", true)
	padre.add_child(modelo)
	# Cuerpo trasero y piso superior sobre la galería
	_col_caja(padre, Vector3(-52.5, 4.5, 0), Vector3(9, 9, 30))
	_col_caja(padre, Vector3(-46.5, 6.9, 0), Vector3(3, 4.2, 30))
	# Columnas de la galería (planta baja). Las de las puntas van 0,4 m hacia adentro, al ras de las
	# paredes de los costados (ver tools/extraer_cabildo.gd)
	for i in 11:
		var z := -15.0 + i * 3.0
		z -= signf(z) * 0.4 if i == 0 or i == 10 else 0.0
		_col_caja(padre, Vector3(x_frente - 0.4, 2.4, z), Vector3(0.8, 4.8, 0.8))
	# Balconcitos del piso alto (para posarse)
	for i in 10:
		_col_caja(padre, Vector3(x_frente + 0.35, 5.5, -13.5 + i * 3.0), Vector3(0.7, 0.15, 1.5))
	# Cornisa (lugar ideal para posarse)
	_col_caja(padre, Vector3(-51.0, 9.15, 0), Vector3(13.2, 0.3, 31.0))
	# Techo de tejas (prisma con la cumbrera a lo largo de Z)
	var prisma := PrismMesh.new()
	prisma.size = Vector3(12.5, 2.6, 30.0)
	var forma_techo := ConvexPolygonShape3D.new()
	forma_techo.points = prisma.get_faces()
	Construir.colision(padre, Vector3(-51.0, 10.6, 0), forma_techo)
	# Torre central, su cornisa y la cúpula
	_col_caja(padre, Vector3(-46.5, 13.0, 0), Vector3(4, 7.6, 4))
	_col_caja(padre, Vector3(-46.5, 16.95, 0), Vector3(4.6, 0.3, 4.6))
	var forma := SphereShape3D.new()
	forma.radius = 1.5
	Construir.colision(padre, Vector3(-46.5, 17.0, 0), forma)
	# Lo que el modelo agrega sobre la cornisa de la torre también es sólido: los 4 pináculos de las
	# esquinas y la linterna con la aguja
	for x in [-48.55, -44.45]:
		for z in [-2.05, 2.05]:
			_col_caja(padre, Vector3(x, 17.5, z), Vector3(0.28, 0.8, 0.28))
	var linterna := CylinderShape3D.new()
	linterna.radius = 0.25
	linterna.height = 1.0
	Construir.colision(padre, Vector3(-46.5, 19.0, 0), linterna)
	# El nombre va pintado en el frente de la torre, debajo del reloj (sobre una tablita del modelo)
	_rot(Construir.cartel(padre, Vector3(-44.44, 11.2, 0), "CABILDO", Color("6b5a40"), 56), "y", PI / 2.0)
	# Fondo cerrado (en el modelo, con sus ventanas)
	_col_caja(padre, Vector3(-58.0, 5, 0), Vector3(2, 10, 30))


## Sólo colisión (caja), sin malla: la parte visual la pone un modelo de Blender.
static func _col_caja(padre: Node3D, pos: Vector3, tam: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = tam
	Construir.colision(padre, pos, forma)


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
## Los cafés frente a la plaza (fachada en z = 38, mirando al norte). Los usa también NivelMedio.
const CAFES := [
	{"x": -30.0, "ancho": 18.0, "alto": 11.0, "color": Color("f6e2b0"), "toldo": Color("2f7d5b"), "nombre": "Café La Medialuna Feliz",
		"remate": Color("4f9a64")},
	{"x": -8.0, "ancho": 16.0, "alto": 13.0, "color": Color("e8a070"), "toldo": Color("b8423a"), "nombre": "Confitería El Buen Mozo",
		"remate": Color("fbf1d8")},
	{"x": 13.0, "ancho": 16.0, "alto": 10.0, "color": Color("a6d6f4"), "toldo": Color("2b4f8a"), "nombre": "Bar Los Vencejos",
		"remate": Color("ffffff")},
	{"x": 32.0, "ancho": 14.0, "alto": 14.0, "color": Color("dddbd3"), "toldo": Color("54585c"), "nombre": "Banco Austral Imaginario",
		"remate": Color("4f7fc0")},
]


static func cafes(padre: Node3D) -> Array[Vector3]:
	var mesas: Array[Vector3] = []
	for n: Dictionary in CAFES:
		var x: float = n["x"]
		var ancho: float = n["ancho"]
		edificio(padre, Vector3(x, 0, 43.0), Vector3(ancho, n["alto"], 10), n["color"], Vector3(0, 0, -1), n["remate"])
		# Vidriera oscura en planta baja
		Construir.caja(padre, Vector3(x, 1.6, 37.95), Vector3(ancho - 2.0, 2.6, 0.1), Color("2e3640"), false)
		# Y lo que se ve adentro, según el nombre (ver world/vidrieras.gd)
		Vidrieras.poner(padre, Vector3(x, 1.6, 37.89), PI, Vector2(ancho - 2.0, 2.6), n["nombre"], 0.15)
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
				mesa(padre, pos, (m + int(x)) % 2 != 0)
				mesas.append(pos + Vector3(0, 0.78, 0))
	return mesas


## Mesa de café con dos sillas y sombrilla (la pieza nueva del kit, con su colisión).
static func mesa(padre: Node3D, pos: Vector3, verde := false) -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = Construir.CAPA_MUNDO
	cuerpo.collision_mask = 0
	padre.add_child(cuerpo)
	Kit.colocar(padre, "mesa_cafe_verde" if verde else "mesa_cafe_roja", pos, 0.0, Vector3.ONE, cuerpo)


## Boca de subte (el punto de la brújula y de donde salen los oficinistas, ver plaza.gd).
const SUBTE := Vector3(34, 0, -22)
const SUBTE_PELDANOS := 10
const SUBTE_ALZADA := 0.2
const SUBTE_HUELLA := 0.5


## Hueco de la escalera del subte en X/Z: ahí no hay piso de plaza ni base de asfalto (ver partir).
## La escalera baja hacia el norte desde el borde sur del hueco (2 m más al sur que SUBTE).
## "con_rampa": el hueco de las colisiones, media huella más largo hacia el sur. Ahí el piso es sólo
## visual y se pisa la punta de la rampa invisible, que sale a ras del piso (como al pie de la
## escalinata de la Catedral); si no, al subir quedaba un borde de 10 cm que la paloma no trepa.
static func hueco_subte(con_rampa := false) -> Rect2:
	var r := Rect2(SUBTE.x - 1.6, SUBTE.z - 4.0, 3.2, 6.0)
	if con_rampa:
		r.size.y += SUBTE_HUELLA * 0.5
	return r


## Parte "r" en hasta cuatro rectángulos que rodean "hueco" (si se tocan): norte, sur, oeste y este.
static func partir(r: Rect2, hueco: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var h := r.intersection(hueco)
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		out.append(r)
		return out
	for q: Rect2 in [Rect2(r.position.x, r.position.y, r.size.x, h.position.y - r.position.y),
			Rect2(r.position.x, h.end.y, r.size.x, r.end.y - h.end.y),
			Rect2(r.position.x, h.position.y, h.position.x - r.position.x, h.size.y),
			Rect2(h.end.x, h.position.y, r.end.x - h.end.x, h.size.y)]:
		if q.size.x > 0.0 and q.size.y > 0.0:
			out.append(q)
	return out


## Noreste: boca de subte con una escalera de verdad que baja 2 m (10 escalones de 20 cm, como la de
## la Catedral pero hacia abajo: escalones macizos más una rampa invisible que pasa por la mitad de
## cada contrahuella), un descanso abajo con la boca oscura del túnel, rejas decorativas (sin
## colisión) en tres lados y el cartel. No hay subte: abajo se termina en el descanso.
static func subte(padre: Node3D, pos: Vector3) -> void:
	var hueco := hueco_subte()
	var x0 := hueco.position.x
	var x1 := hueco.end.x
	var z_borde := hueco.end.y          # borde sur: arranca la escalera
	var z_fondo := hueco.position.y     # pared del fondo (norte)
	const FONDO := 2.2                  # Hasta dónde llegan las paredes y los escalones
	const PARED := 0.2
	var ancho := hueco.size.x - 2.0 * PARED
	var cx := (x0 + x1) / 2.0
	var azulejo := Color("f0ede4")
	var franja := Color("5a96dc")
	# Paredes de azulejos con una franja de color (con colisión) y la del fondo con el túnel
	for x in [x0 + PARED / 2.0, x1 - PARED / 2.0]:
		Construir.caja(padre, Vector3(x, -FONDO / 2.0, (z_borde + z_fondo) / 2.0), Vector3(PARED, FONDO, hueco.size.y), azulejo)
		var adentro := 1.0 if x < cx else -1.0
		Construir.caja(padre, Vector3(x + adentro * (PARED / 2.0 + 0.01), -0.9, (z_borde + z_fondo) / 2.0),
			Vector3(0.02, 0.18, hueco.size.y), franja, false)
	Construir.caja(padre, Vector3(cx, -FONDO / 2.0, z_fondo + PARED / 2.0), Vector3(ancho, FONDO, PARED), azulejo)
	Construir.caja(padre, Vector3(cx, -1.15, z_fondo + PARED + 0.01), Vector3(1.8, 1.7, 0.02), Color("15171b"), false)
	Construir.caja(padre, Vector3(cx, -0.2, z_fondo + PARED + 0.015), Vector3(2.4, 0.18, 0.02), franja, false)
	# Escalones macizos (apoyados abajo, sin huecos). La colisión de cada uno queda 10 cm por debajo de
	# la rampa (el último no: es el piso del descanso)
	for e in SUBTE_PELDANOS:
		var arriba := -SUBTE_ALZADA * (e + 1)
		var z := z_borde - SUBTE_HUELLA * (e + 0.5)
		var alto := FONDO + arriba
		Construir.caja(padre, Vector3(cx, (arriba - FONDO) / 2.0, z), Vector3(ancho, alto, SUBTE_HUELLA),
			Color("b9bab4").darkened((e % 2) * 0.05), false)
		# Borde antideslizante amarillo (decorativo)
		Construir.caja(padre, Vector3(cx, arriba + 0.012, z + SUBTE_HUELLA / 2.0 - 0.05), Vector3(ancho, 0.024, 0.08),
			Color("ffd256"), false)
		var arriba_col := arriba if e == SUBTE_PELDANOS - 1 else arriba - SUBTE_ALZADA * 0.5
		var forma := BoxShape3D.new()
		forma.size = Vector3(ancho, FONDO + arriba_col, SUBTE_HUELLA)
		Construir.colision(padre, Vector3(cx, (arriba_col - FONDO) / 2.0, z), forma)
	# Descanso de abajo (del último escalón a la pared del fondo)
	var z_descanso := z_borde - SUBTE_HUELLA * SUBTE_PELDANOS
	var prof_descanso := z_descanso - (z_fondo + PARED)
	var y_abajo := -SUBTE_ALZADA * SUBTE_PELDANOS
	Construir.caja(padre, Vector3(cx, (y_abajo - FONDO) / 2.0, z_descanso - prof_descanso / 2.0),
		Vector3(ancho, FONDO + y_abajo, prof_descanso), Color("86888a"))
	# Rampa invisible por la mitad de cada contrahuella: arriba sale a ras del piso media huella antes del
	# borde (ahí el piso no tiene colisión, ver hueco_subte) y abajo termina en la mitad del último escalón
	var za := z_borde + SUBTE_HUELLA * 0.5
	var zb := za - SUBTE_HUELLA * SUBTE_PELDANOS
	var largo := Vector2(za - zb, -y_abajo).length()
	var ang := -atan2(-y_abajo, za - zb)
	var normal := Vector3(0, cos(ang), sin(ang))
	var rampa := BoxShape3D.new()
	rampa.size = Vector3(ancho, 0.2, largo)
	Construir.colision(padre, Vector3(cx, y_abajo / 2.0, (za + zb) / 2.0) - normal * 0.1, rampa, Vector3(ang, 0, 0))
	# Rejas decorativas del kit en los dos costados y en el fondo (sin colisión)
	for x in [x0 - 0.1, x1 + 0.1]:
		for k in 2:
			Kit.colocar(padre, "reja", Vector3(x, 0, z_borde - 1.5 - 3.0 * k), PI / 2.0)
		Kit.colocar(padre, "reja_poste", Vector3(x, 0, z_borde), PI / 2.0)
		Kit.colocar(padre, "reja_poste", Vector3(x, 0, z_fondo - 0.1), PI / 2.0)
	Kit.colocar(padre, "reja", Vector3(cx, 0, z_fondo - 0.1), 0.0, Vector3((x1 - x0 + 0.2) / 3.0, 1, 1))
	# Cartel en un poste, en la esquina sudoeste
	var verde := Color("2f6b4a")
	var poste := Vector3(x0 - 0.7, 0, z_borde + 0.6)
	Construir.cilindro(padre, poste + Vector3(0, 1.5, 0), 0.06, 3.0, Color("23282b"), true, 6)
	Construir.caja(padre, poste + Vector3(0, 3.2, 0), Vector3(0.1, 0.8, 1.6), verde)
	_rot(Construir.cartel(padre, poste + Vector3(-0.1, 3.2, 0), "SUBTE\nLínea Ñ", Color.WHITE, 40), "y", -PI / 2.0)
	_rot(Construir.cartel(padre, poste + Vector3(0.1, 3.2, 0), "SUBTE\nLínea Ñ", Color.WHITE, 40), "y", PI / 2.0)
	assert(pos.is_equal_approx(SUBTE))


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


## Edificios bajos alrededor: [base, tamaño, color, frente, cornisa]. Al norte, a los costados de la
## Catedral; al sur de la avenida, en las dos puntas (dejan la calle libre para los autos).
const ALREDEDORES := [
	[Vector3(-27, 0, -36), Vector3(18, 12, 8), Color("e3b764"), Vector3(0, 0, 1), Color("a85a3c")],
	[Vector3(-44, 0, -35), Vector3(14, 10, 10), Color("9fd2ab"), Vector3(0, 0, 1), C_BLANCO],
	[Vector3(26, 0, -36), Vector3(16, 13, 8), Color("e98a74"), Vector3(0, 0, 1), C_BLANCO],
	[Vector3(46, 0, -35), Vector3(16, 11, 10), Color("92c4ea"), Vector3(0, 0, 1), Color("4f7fc0")],
	[Vector3(-52, 0, 43), Vector3(12, 9, 12), Color("f0d27a"), Vector3(0, 0, -1), Color("a85a3c")],
	[Vector3(50, 0, 43), Vector3(18, 12, 10), Color("d3bff0"), Vector3(0, 0, -1), C_BLANCO],
]


## Edificios de alrededor (con techos y cornisas para posarse). Cada uno tiene adentro un local que la
## paloma atraviesa volando (supermercado, verdulería, café...), en un piso al azar: los arma
## Pasaje.alrededores (ver world/pasaje.gd y world/casa_enterable.gd), con el cartel del local en la
## planta baja diciendo en qué piso está.
static func alrededores(padre: Node3D) -> void:
	Pasaje.alrededores(padre)


## Rota un nodo recién creado sobre un eje ("x", "y" o "z").
static func _rot(n: Node3D, eje: String, angulo: float) -> void:
	match eje:
		"x": n.rotation.x = angulo
		"y": n.rotation.y = angulo
		"z": n.rotation.z = angulo
