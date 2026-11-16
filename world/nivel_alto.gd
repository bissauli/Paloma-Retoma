class_name NivelAlto
extends RefCounted
## Nivel alto del mapa (Fase 3): el cielo de la ciudad, para que se vea completa desde arriba.
## - Tres torres hito de 52 a 60 m en esquinas (en vez de la pieza de esquina del kit), con ventanas y
##   franjas horizontales en la textura (sin geometría extra), terrazas amplias para mirar la ciudad,
##   cúpula o tejado, antena y bandera.
## - Terrazas en el techo de cuatro edificios altos: tanque de agua, antena, tendedero y pérgola.
## - Antenas en los edificios altos (con colisión en la punta).
## - Postes de luz a lo largo de cuatro calles (colisión en la base) y cables tendidos entre poste y
##   poste y de los postes a las fachadas, con una colisión finita a lo largo para posarse.
## Para que se pueda llegar arriba de las torres, el techo invisible del mapa (Ciudad.TECHO) subió a 70 m.
## Como en la Fase 2, todo se arma con cajas, esferas y cilindros (Construir) con los colores del kit.

## Torres hito en esquinas de manzana: la esquina y el giro son los de la pieza de esquina del kit que
## reemplazan (16 x 16 m: X local de 0 a 16, Z local de 0 a -16). "retiro": altura de la terraza donde
## la torre se angosta (0 = sin retiro); arriba queda un bloque de LADO_ALTO hacia el fondo de la manzana.
const TORRES := [
	{"esquina": Vector3(-61, 0, -56), "rot": 0.0, "alto": 52.0, "retiro": 36.0, "remate": "cupula",
		"pared": "f2ede2", "vidrio": "6f97b6", "franja": "b25a3e", "acento": "cupula"},
	{"esquina": Vector3(77, 0, -14), "rot": 0.0, "alto": 56.0, "retiro": 40.0, "remate": "tejado",
		"pared": "dcd2c4", "vidrio": "5d86a8", "franja": "4f7fc0", "acento": "pizarra"},
	{"esquina": Vector3(-77, 0, 6), "rot": PI, "alto": 60.0, "retiro": 0.0, "remate": "cupula",
		"pared": "e9e4d8", "vidrio": "7aa3c0", "franja": "4f9a64", "acento": "remate_verde"},
]
const LADO := 16.0
const LADO_ALTO := 10.0
const PODIO := 5.0
const PRETIL := 1.0
const TECHO := 70.0          ## Ciudad.TECHO (el techo invisible): por encima de la antena más alta

## Calles con postes: [desde, hasta, adentro (de la vereda hacia las fachadas detrás del poste)].
## Los postes van a 45 cm del cordón; el cruce va hacia el otro lado (-adentro).
const TENDIDOS := [
	[Vector3(-190, 0, -7.45), Vector3(-82, 0, -7.45), Vector3.FORWARD],    # Av. de Mayo, del lado del parque
	[Vector3(84, 0, -0.55), Vector3(190, 0, -0.55), Vector3.BACK],         # Reconquista, del lado del barrio
	[Vector3(74.45, 0, -104), Vector3(74.45, 0, -20), Vector3.RIGHT],      # Paseo Colón, frente al hospital
	[Vector3(-74.45, 0, -104), Vector3(-74.45, 0, -12), Vector3.LEFT],     # Bolívar, del lado del parque
	[Vector3(-74.45, 0, 10), Vector3(-74.45, 0, 50), Vector3.LEFT],        # Bolívar, frente a las comerciales
	[Vector3(-74.45, 0, 66), Vector3(-74.45, 0, 104), Vector3.LEFT],
]
const PASO_POSTES := 24.0
const ALTO_POSTE := 8.8
const Y_CRUCETA := 8.2
const GROSOR_CABLE := 0.045
const GROSOR_COLISION := 0.12
const Y_AGARRE := 7.35       ## Altura del soporte en la pared: entre el dintel del primer piso y el alféizar del segundo

## Terrazas altas para mirar la ciudad (las llena _torre): [centro, tamaño en X/Z] del piso, en el mundo.
static var miradores: Array = []
## Puntas de antena, cables y bases de poste con colisión (para las pruebas): [tipo, punto de arriba].
static var muestras: Array = []

static var _mat_torres := {}


## Al empezar a armar la ciudad (la llama Ciudad._ready).
static func reiniciar() -> void:
	miradores.clear()
	muestras.clear()
	NivelMedio.cuenta.clear()
	NivelMedio.muestras.clear()
	NivelMedio.salientes.clear()


static func c(nombre: String) -> Color:
	return NivelInferior.c(nombre)


static func contar(tipo: String, k := 1) -> void:
	NivelMedio.contar(tipo, k)


static func caja(n: Node3D, centro: Vector3, tam: Vector3, color: Color, col := false, rot := Vector3.ZERO,
		detalle := false) -> MeshInstance3D:
	return NivelMedio.caja(n, centro, tam, color, col, rot, detalle)


# ---------------------------------------------------------------- Torres hito

## Si en esta esquina va una torre la arma (en vez de la pieza de esquina del kit) y devuelve true.
static func torre_en(ci: Ciudad, esquina: Vector3) -> bool:
	for t: Dictionary in TORRES:
		if (t["esquina"] as Vector3).is_equal_approx(esquina):
			_torre(ci, t)
			return true
	return false


## Material de las paredes de una torre: ventanas por piso (cada 3 m) y franjas horizontales en una
## textura que se proyecta con la posición en el mundo (un mosaico de 3 m de ancho por 12 m de alto:
## cuatro pisos, el de abajo con una franja de color). No es geometría: son cuatro cajas por torre.
static func material_torre(t: Dictionary) -> ShaderMaterial:
	var clave: String = t["pared"] + t["vidrio"] + t["franja"]
	if _mat_torres.has(clave):
		return _mat_torres[clave]
	const PX := 16   # píxeles por metro
	var ancho := 3 * PX
	var alto := 12 * PX
	var pared := Color(t["pared"] as String)
	var vidrio := Color(t["vidrio"] as String)
	var franja := Color(t["franja"] as String)
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGB8)
	for r in alto:
		# La V crece con la altura: la fila r es la altura y (en metros, dentro del mosaico)
		var y := (r + 0.5) / PX
		var fy := fmod(y, 3.0)
		for col in ancho:
			var x := (col + 0.5) / PX
			var color := pared
			if y < 0.55:
				color = franja                                # franja cada cuatro pisos
			elif fy < 0.28:
				color = pared.darkened(0.12)                  # losa de cada piso
			elif fy > 0.85 and fy < 2.55 and x > 0.45 and x < 2.55:
				color = vidrio.lightened(0.18 * (fy - 0.85) / 1.7)   # reflejo: más claro arriba
				if absf(x - 1.5) < 0.05 or absf(fy - 1.95) < 0.04:
					color = pared.darkened(0.05)              # parante y travesaño
			elif fy >= 0.75 and fy <= 0.85 and x > 0.35 and x < 2.65:
				color = pared.lightened(0.25)                 # alféizar
			img.set_pixel(col, r, color)
	img.generate_mipmaps()
	var m := Construir.material_cozy(0.8)
	m.set_shader_parameter("textura_albedo", ImageTexture.create_from_image(img))
	m.set_shader_parameter("usar_uv_mundo", true)
	m.set_shader_parameter("escala_uv_mundo", Vector2(1.0 / 3.0, 1.0 / 12.0))
	m.set_shader_parameter("degradado_altura_max", 60.0)
	_mat_torres[clave] = m
	return m


## Bloque de la torre: caja con el material de ventanas (con colisión). "x0, z0, x1, z1" en el marco.
static func _bloque(n: Node3D, x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, mat: Material) -> void:
	var centro := Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	var tam := Vector3(x1 - x0, y1 - y0, z1 - z0)
	Construir.caja_mat(n, centro, tam, mat, false)
	var forma := BoxShape3D.new()
	forma.size = tam
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, centro))


## Piso de terraza (con colisión) sobre el rectángulo y pretil con colisión en los bordes "bordes"
## (N = z0, S = z1, O = x0, E = x1 del marco). "libre": superficie libre para pararse (m²); si hay, se
## anota como mirador con un punto libre "punto" (en X/Z del marco) para las pruebas.
static func _terraza(n: Node3D, r: Rect2, y: float, bordes: String, color_pretil: Color, libre := 0.0,
		punto := Vector2.ZERO) -> void:
	caja(n, Vector3(r.get_center().x, y + 0.08, r.get_center().y), Vector3(r.size.x, 0.16, r.size.y), c("azotea"), true)
	const G := 0.3
	var yp := y + 0.16 + PRETIL / 2.0
	for b in bordes:
		match b:
			"N": caja(n, Vector3(r.get_center().x, yp, r.position.y + G / 2.0), Vector3(r.size.x, PRETIL, G), color_pretil, true)
			"S": caja(n, Vector3(r.get_center().x, yp, r.end.y - G / 2.0), Vector3(r.size.x, PRETIL, G), color_pretil, true)
			"O": caja(n, Vector3(r.position.x + G / 2.0, yp, r.get_center().y), Vector3(G, PRETIL, r.size.y), color_pretil, true)
			"E": caja(n, Vector3(r.end.x - G / 2.0, yp, r.get_center().y), Vector3(G, PRETIL, r.size.y), color_pretil, true)
	if libre > 0.0:
		miradores.append([n.transform * Vector3(punto.x, y + 0.16, punto.y), libre])


static func _torre(ci: Ciudad, t: Dictionary) -> void:
	var n := NivelMedio.marco(ci, Transform3D(Basis.from_euler(Vector3(0, float(t["rot"]), 0)), t["esquina"]))
	var mat := material_torre(t)
	var alto: float = t["alto"]
	var retiro: float = t["retiro"]
	var acento := c(t["acento"])
	var franja := Color(t["franja"] as String)
	# Podio de piedra con vidrieras en los dos frentes (X local = 0 y Z local = 0) y una marquesina
	caja(n, Vector3(LADO / 2.0, PODIO / 2.0, -LADO / 2.0), Vector3(LADO, PODIO, LADO), c("piedra_osc"), true)
	caja(n, Vector3(LADO / 2.0 + 1.0, 1.9, 0.03), Vector3(LADO - 4.0, 2.8, 0.06), c("vidrio_osc"))
	caja(n, Vector3(-0.03, 1.9, -LADO / 2.0 - 1.0), Vector3(0.06, 2.8, LADO - 4.0), c("vidrio_osc"))
	caja(n, Vector3(LADO / 2.0, PODIO - 0.15, 0.4), Vector3(LADO, 0.3, 0.8), franja, true)
	caja(n, Vector3(-0.4, PODIO - 0.15, -LADO / 2.0), Vector3(0.8, 0.3, LADO), franja, true)
	# Fuste (con o sin retiro)
	var y_bajo := retiro if retiro > 0.0 else alto
	_bloque(n, 0, -LADO, LADO, 0, PODIO, y_bajo, mat)
	var arriba := Rect2(0, -LADO, LADO, LADO)
	if retiro > 0.0:
		# Terraza en L sobre el bloque bajo (mirando a las dos calles) y el bloque alto hacia el fondo
		arriba = Rect2(LADO - LADO_ALTO, -LADO, LADO_ALTO, LADO_ALTO)
		_terraza(n, Rect2(0, -LADO, LADO, LADO), y_bajo, "NSOE", acento, LADO * LADO - LADO_ALTO * LADO_ALTO,
			Vector2(2.5, -2.5))
		_bloque(n, arriba.position.x, arriba.position.y, arriba.end.x, arriba.end.y, y_bajo + 0.16, alto, mat)
		_mobiliario_mirador(n, Rect2(0.8, -5.2, 4.4, 4.4), y_bajo + 0.16)
	# Terraza de arriba con pretil, el remate en el medio y la bandera en una punta
	_terraza(n, arriba, alto, "NSOE", acento, arriba.get_area() - 30.0, arriba.position + Vector2(1.6, 1.6))
	var centro := Vector3(arriba.get_center().x, alto + 0.16, arriba.get_center().y)
	var tope: float
	if t["remate"] == "tejado":
		tope = _tejado(n, centro, 4.6, acento)
	else:
		tope = _cupula(n, centro, 2.3, acento)
	antena(n, Vector3(centro.x, tope, centro.z), 2.8)
	bandera(n, Vector3(arriba.position.x + 1.0, alto + 0.16, arriba.end.y - 1.0))
	contar("torre")


## Cúpula sobre un tambor, con linterna. Colisión: tambor (cilindro) y casquete (esfera) para posarse.
## Devuelve la altura de la punta.
static func _cupula(n: Node3D, base: Vector3, radio: float, color: Color) -> float:
	var tambor := 1.8
	Construir.cilindro(n, base + Vector3(0, tambor / 2.0, 0), radio, tambor, c("piedra"), false, 16)
	var forma := CylinderShape3D.new()
	forma.radius = radio
	forma.height = tambor
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, base + Vector3(0, tambor / 2.0, 0)))
	caja(n, base + Vector3(0, tambor + 0.08, 0), Vector3(radio * 2.0 + 0.4, 0.16, radio * 2.0 + 0.4), c("blanco"), true)
	var y_cup := base.y + tambor + 0.16
	Construir.esfera(n, Vector3(base.x, y_cup, base.z), radio, color, Vector3(1, 1.15, 1), 16)
	var esf := SphereShape3D.new()
	esf.radius = radio * 1.05   # Jolt no escala esferas desparejo: una un poco más grande alcanza
	NivelMedio.colision(n, esf, Transform3D(Basis.IDENTITY, Vector3(base.x, y_cup + radio * 0.1, base.z)))
	# Linterna arriba (con colisión: se posa en su techito)
	var y_lin := y_cup + radio * 1.15 - 0.15
	Construir.cilindro(n, Vector3(base.x, y_lin + 0.35, base.z), 0.45, 0.7, c("blanco"), false, 8)
	caja(n, Vector3(base.x, y_lin + 0.78, base.z), Vector3(1.1, 0.16, 1.1), color, true)
	contar("cupula")
	return y_lin + 0.86


## Tejado a cuatro aguas de pizarra (pirámide) sobre un cuerpo bajo, con colisión. Devuelve la punta.
static func _tejado(n: Node3D, base: Vector3, lado: float, color: Color) -> float:
	var cuerpo := 1.6
	caja(n, base + Vector3(0, cuerpo / 2.0, 0), Vector3(lado, cuerpo, lado), c("piedra"), true)
	caja(n, base + Vector3(0, cuerpo + 0.08, 0), Vector3(lado + 0.5, 0.16, lado + 0.5), c("blanco"), true)
	var alto := 3.4
	var pos := base + Vector3(0, cuerpo + 0.16 + alto / 2.0, 0)
	var mi := Construir.cilindro(n, pos, (lado + 0.3) * 0.7071, alto, color, false, 4, 0.0)
	mi.rotation.y = PI / 4.0
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = (lado + 0.3) * 0.7071
	cm.height = alto
	cm.radial_segments = 4
	cm.rings = 1
	var forma := ConvexPolygonShape3D.new()
	forma.points = cm.get_faces()
	NivelMedio.colision(n, forma, Transform3D(Basis.from_euler(Vector3(0, PI / 4.0, 0)), pos))
	contar("tejado")
	return pos.y + alto / 2.0


## Mesas y sombrilla en la terraza del retiro (sólo para ver).
static func _mobiliario_mirador(n: Node3D, r: Rect2, y: float) -> void:
	for k in 2:
		var p := Vector3(r.position.x + 1.1 + k * 2.2, y, r.position.y + 1.1 + k * 2.2)
		Construir.cilindro(n, p + Vector3(0, 0.37, 0), 0.05, 0.74, c("hierro"), false, 6)
		Construir.cilindro(n, p + Vector3(0, 0.76, 0), 0.45, 0.04, c("blanco"), false, 12)
		Construir.cilindro(n, p + Vector3(0, 1.3, 0), 0.03, 1.1, c("hierro"), false, 6)
		Construir.cilindro(n, p + Vector3(0, 1.95, 0), 1.1, 0.4, c("sombrilla_crema" if k == 0 else "toldo_rojo"),
			false, 8, 0.05)


# ---------------------------------------------------------------- Antenas, banderas y terrazas

## Antena de TV: mástil con travesaños y una tapita en la punta con colisión (para posarse).
static func antena(n: Node3D, base: Vector3, alto: float) -> void:
	var hierro := c("metal")
	Construir.cilindro(n, base + Vector3(0, 0.1, 0), 0.18, 0.2, c("hierro"), false, 8)
	Construir.cilindro(n, base + Vector3(0, alto / 2.0, 0), 0.05, alto, hierro, false, 6)
	for k in 3:
		var y := alto - 0.5 - k * 0.55
		var largo := 1.3 - k * 0.3
		caja(n, base + Vector3(0, y, 0), Vector3(largo, 0.04, 0.04), hierro, false, Vector3(0, k * 0.5, 0), true)
	# Riendas finitas hacia el piso (decorativas)
	for k in 3:
		var a := TAU * k / 3.0
		var pie := base + Vector3(cos(a) * 1.2, 0.02, sin(a) * 1.2)
		var arriba := base + Vector3(0, alto * 0.6, 0)
		var d := arriba - pie
		var mi := caja(n, (pie + arriba) / 2.0, Vector3(0.015, 0.015, d.length()), hierro, false, Vector3.ZERO, true)
		mi.basis = Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.FORWARD)
	var punta := base + Vector3(0, alto + 0.03, 0)
	Construir.cilindro(n, punta, 0.2, 0.06, c("luz_roja"), false, 8)
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.42, 0.08, 0.42)
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, punta))
	muestras.append(["antena", n.transform * (punta + Vector3(0, 0.04, 0))])
	contar("antena")


## Bandera argentina en su mástil (sólo para ver, sin colisión).
static func bandera(n: Node3D, base: Vector3) -> void:
	var alto := 3.2
	Construir.cilindro(n, base + Vector3(0, alto / 2.0, 0), 0.04, alto, c("blanco"), false, 6)
	Construir.esfera(n, base + Vector3(0, alto + 0.05, 0), 0.07, c("flor_amarilla"), Vector3.ONE, 6)
	var celeste := Color("74acdf")
	for k in 3:
		var y := alto - 0.15 - k * 0.3
		caja(n, base + Vector3(0.8, y, 0), Vector3(1.5, 0.3, 0.02), celeste if k != 1 else c("blanco"))
	Construir.esfera(n, base + Vector3(0.8, alto - 0.45, 0.0), 0.09, c("flor_amarilla"), Vector3(1, 1, 0.3), 8)
	contar("bandera")


## Lugares libres en la azotea de una pieza del kit (en su marco): busca un rectángulo de "tam" que no
## pise las cajas que sobresalen del techo (tanques, salidas, aires) ni lo ya puesto en "ocupado".
static func _lugar_azotea(d: Dictionary, tam: Vector2, ocupado: Array[Rect2], rng: RandomNumberGenerator) -> Vector2:
	var w := float(d["ancho"]) / 2.0
	var alto := float(d["alto"])
	var obst: Array[Rect2] = ocupado.duplicate()
	for cj: Array in d.get("cajas", []):
		var ce := Vector3(cj[0], cj[1], cj[2])
		var s := Vector3(cj[3], cj[4], cj[5])
		var e := Vector3.ZERO
		for k in 3:
			var eje := Vector3(cj[6 + k * 3], cj[7 + k * 3], cj[8 + k * 3]).abs()
			e += eje * s[k] / 2.0
		if ce.y + e.y > alto + 0.02:
			obst.append(Rect2(ce.x - e.x, ce.z - e.z, e.x * 2.0, e.z * 2.0).grow(0.3))
	var opciones: Array[Vector2] = []
	var x := -w + 0.7 + tam.x / 2.0
	while x <= w - 0.7 - tam.x / 2.0:
		var z := -15.3 + tam.y / 2.0
		while z <= -0.7 - tam.y / 2.0:
			var r := Rect2(x - tam.x / 2.0, z - tam.y / 2.0, tam.x, tam.y)
			var libre := true
			for o in obst:
				if o.intersects(r):
					libre = false
					break
			if libre:
				opciones.append(Vector2(x, z))
			z += 0.5
		x += 0.5
	if opciones.is_empty():
		return Vector2.INF
	return opciones[rng.randi() % opciones.size()]


## Terraza de un edificio alto del kit: tanque de agua, antena, tendedero y pérgola (lo que entre).
static func terraza_kit(n: Node3D, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var alto := float(d["alto"])
	var ocupado: Array[Rect2] = []
	var cosas := [["pergola", Vector2(3.6, 3.0)], ["tanque", Vector2(2.0, 2.0)], ["tendedero", Vector2(3.4, 1.2)],
		["antena", Vector2(1.0, 1.0)]]
	for cosa: Array in cosas:
		var tam: Vector2 = cosa[1]
		var p := _lugar_azotea(d, tam, ocupado, rng)
		if p == Vector2.INF:
			continue
		ocupado.append(Rect2(p - tam / 2.0, tam))
		var base := Vector3(p.x, alto, p.y)
		match cosa[0]:
			"pergola": _pergola(n, base, tam)
			"tanque": _tanque(n, base)
			"tendedero": _tendedero(n, base, tam, rng)
			"antena": antena(n, base, 3.6)
	contar("terraza")


## Pérgola de madera: cuatro postes, dos vigas y listones. Se posa arriba (colisión de techo).
static func _pergola(n: Node3D, base: Vector3, tam: Vector2) -> void:
	var madera := c("madera")
	var h := 2.3
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			caja(n, base + Vector3(sx * (tam.x / 2.0 - 0.1), h / 2.0, sz * (tam.y / 2.0 - 0.1)), Vector3(0.14, h, 0.14), madera)
	for sz in [-1.0, 1.0]:
		caja(n, base + Vector3(0, h + 0.07, sz * (tam.y / 2.0 - 0.1)), Vector3(tam.x, 0.14, 0.12), c("madera_osc"))
	var listones := 7
	for i in listones:
		caja(n, base + Vector3(-tam.x / 2.0 + 0.15 + i * (tam.x - 0.3) / (listones - 1), h + 0.2, 0),
			Vector3(0.1, 0.12, tam.y + 0.2), madera)
	var forma := BoxShape3D.new()
	forma.size = Vector3(tam.x, 0.26, tam.y + 0.2)
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, base + Vector3(0, h + 0.13, 0)))
	# Enredadera arriba y dos sillas abajo
	for k in 3:
		Construir.esfera(n, base + Vector3(-tam.x / 3.0 + k * tam.x / 3.0, h + 0.3, (k - 1) * 0.6), 0.45,
			c("hoja_osc" if k % 2 == 0 else "hoja"), Vector3(1.2, 0.45, 1.0), 6)
	for sx in [-0.6, 0.6]:
		caja(n, base + Vector3(sx, 0.42, 0), Vector3(0.45, 0.06, 0.45), c("plastico_verde"), false, Vector3.ZERO, true)
		caja(n, base + Vector3(sx, 0.7, 0.2), Vector3(0.45, 0.5, 0.05), c("plastico_verde"), false, Vector3.ZERO, true)
	muestras.append(["pergola", n.transform * (base + Vector3(0, h + 0.26, 0))])
	contar("pergola")


## Tanque de agua cilíndrico sobre patas, con colisión (se posa en la tapa).
static func _tanque(n: Node3D, base: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			caja(n, base + Vector3(sx * 0.6, 0.45, sz * 0.6), Vector3(0.1, 0.9, 0.1), c("hierro"))
	caja(n, base + Vector3(0, 0.95, 0), Vector3(1.6, 0.1, 1.6), c("hierro"), true)
	Construir.cilindro(n, base + Vector3(0, 1.75, 0), 0.85, 1.5, c("tanque"), false, 12)
	Construir.cilindro(n, base + Vector3(0, 2.6, 0), 0.85, 0.2, c("tanque"), false, 12, 0.55)
	var forma := CylinderShape3D.new()
	forma.radius = 0.85
	forma.height = 1.7
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, base + Vector3(0, 1.85, 0)))
	muestras.append(["tanque", n.transform * (base + Vector3(0, 2.7, 0))])
	contar("tanque")


## Tendedero: dos postes en T, tres alambres y ropa colgada (sólo para ver).
static func _tendedero(n: Node3D, base: Vector3, tam: Vector2, rng: RandomNumberGenerator) -> void:
	var hierro := c("metal")
	var h := 1.8
	for sx in [-1.0, 1.0]:
		var x: float = sx * (tam.x / 2.0 - 0.1)
		caja(n, base + Vector3(x, h / 2.0, 0), Vector3(0.06, h, 0.06), hierro)
		caja(n, base + Vector3(x, h, 0), Vector3(0.05, 0.05, tam.y - 0.1), hierro, false, Vector3.ZERO, true)
	var colores := ["toldo_rojo", "blanco", "toldo_azul", "flor_amarilla", "fachada_rosa", "toldo_verde"]
	for k in 3:
		var z := (k - 1) * (tam.y - 0.3) / 2.0
		caja(n, base + Vector3(0, h - 0.02, z), Vector3(tam.x, 0.015, 0.015), c("blanco"), false, Vector3.ZERO, true)
		var x := -tam.x / 2.0 + 0.4
		while x < tam.x / 2.0 - 0.4:
			var ropa := Vector2(rng.randf_range(0.35, 0.7), rng.randf_range(0.4, 0.75))
			caja(n, base + Vector3(x + ropa.x / 2.0, h - 0.03 - ropa.y / 2.0, z), Vector3(ropa.x, ropa.y, 0.02),
				c(colores[rng.randi() % colores.size()]), false, Vector3.ZERO, true)
			x += ropa.x + rng.randf_range(0.1, 0.35)
	contar("tendedero")


## Lo de la ciudad (lo llama la etapa Ciudad._nivel_alto, después del nivel medio): terrazas y
## antenas en los edificios altos, postes y cables.
static func ciudad(ci: Ciudad) -> void:
	var rng := ci._rng
	var altos := []
	for e: Array in NivelMedio.edificios_kit(ci):
		var d: Dictionary = e[2]
		if d.get("tipo", "") == "medio" and float(d["alto"]) >= 28.0:
			altos.append(e)
	# Terrazas en los cuatro edificios altos más cerca de la plaza; antenas en uno de cada tres de los demás
	altos.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as MeshInstance3D).position.length() < (b[0] as MeshInstance3D).position.length())
	for i in altos.size():
		var mi: MeshInstance3D = altos[i][0]
		var d: Dictionary = altos[i][2]
		var n := NivelMedio.marco(ci, mi.transform)
		if i < 4:
			terraza_kit(n, d, rng)
			if i % 2 == 0:
				var p := _lugar_azotea(d, Vector2(1.6, 0.6), [], rng)
				if p != Vector2.INF:
					bandera(n, Vector3(p.x - 0.8, float(d["alto"]), p.y))
		elif i % 3 == 0:
			var p := _lugar_azotea(d, Vector2(1.0, 1.0), [], rng)
			if p != Vector2.INF:
				antena(n, Vector3(p.x, float(d["alto"]), p.y), rng.randf_range(3.0, 4.6))
	_tendidos(ci)


# ---------------------------------------------------------------- Postes y cables

## Tramos de fachada en el mundo (edificios del kit y torres): [a, b, alto, transformación, datos].
static func _fachadas(ci: Ciudad) -> Array:
	var out := []
	for e: Array in NivelMedio.edificios_kit(ci):
		var t: Transform3D = (e[0] as MeshInstance3D).transform
		for tr: Array in NivelMedio._tramos_fachada(e[2]):
			out.append([t * (tr[0] as Vector3), t * (tr[1] as Vector3), float((e[2] as Dictionary)["alto"]), t, e[2]])
	for to: Dictionary in TORRES:
		var t := Transform3D(Basis.from_euler(Vector3(0, float(to["rot"]), 0)), to["esquina"])
		out.append([t * Vector3(0, 0, -LADO), t * Vector3.ZERO, float(to["alto"]), t, {}])
		out.append([t * Vector3.ZERO, t * Vector3(LADO, 0, 0), float(to["alto"]), t, {}])
	return out


## La fachada que pasa a menos de 40 cm de "p" (en X/Z), o [] si no hay.
static func _fachada_en(fachadas: Array, p: Vector3) -> Array:
	var q := Vector2(p.x, p.z)
	for f: Array in fachadas:
		var a := Vector2((f[0] as Vector3).x, (f[0] as Vector3).z)
		var b := Vector2((f[1] as Vector3).x, (f[1] as Vector3).z)
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < 0.4:
			return f
	return []


## Mapa V4.5: dónde se agarra a la fachada "f" un cable que viene desde "desde": sobre la pared, entre
## dos columnas de ventanas (no en una ventana, un balcón o un toldo) y en la franja lisa entre el
## dintel del primer piso y el alféizar del segundo. Devuelve [punto, normal hacia afuera], o [] si ahí
## hay un balcón.
static func _agarre(f: Array, desde: Vector3) -> Array:
	var a: Vector3 = f[0]
	var b: Vector3 = f[1]
	var largo := a.distance_to(b)
	var dir := (b - a) / largo
	var normal := Vector3(-dir.z, 0, dir.x)
	if normal.dot(desde - a) < 0.0:
		normal = -normal
	var u := clampf((desde - a).dot(dir), 1.0, largo - 1.0)
	var d: Dictionary = f[4]
	if d.get("tipo", "") == "medio":
		# Entre columnas de ventanas (las X son del marco de la pieza, que va de -ancho/2 a ancho/2)
		var xs := NivelMedio._ventanas_kit(d, float(d["ancho"]))
		var huecos: Array[float] = []
		for i in xs.size() - 1:
			huecos.append((xs[i] + xs[i + 1]) / 2.0)
		if not huecos.is_empty():
			var t: Transform3D = f[3]
			var x_local := (t.affine_inverse() * (a + dir * u)).x
			var mejor := huecos[0]
			for h in huecos:
				if absf(h - x_local) < absf(mejor - x_local):
					mejor = h
			u = clampf(u + (mejor - x_local) * signf((t.basis * Vector3.RIGHT).dot(dir)), 0.6, largo - 0.6)
	var y := minf(Y_AGARRE, float(f[2]) - 1.5)
	var punto := a + dir * u + normal * 0.12 + Vector3(0, y, 0)
	# Donde la fachada tiene balcones propios (los corridos de los departamentos) el cable terminaría
	# adentro de un balcón: ahí no va
	if not d.is_empty():
		var x_local := ((f[3] as Transform3D).affine_inverse() * punto).x
		for l: Array in NivelMedio._losas_kit(d):
			if x_local > float(l[0]) - 0.4 and x_local < float(l[1]) + 0.4 and y > float(l[2]) - 0.4 and y < float(l[2]) + 1.4:
				return []
	return [punto, normal]


## Soporte del cable en la pared: una planchuela con el aislador blanco (sólo para ver).
static func _soporte(ci: Ciudad, p: Vector3, normal: Vector3) -> void:
	var n := NivelMedio.marco(ci, Transform3D(Basis.from_euler(Vector3(0, atan2(normal.x, normal.z), 0)), p))
	caja(n, Vector3(0, 0, -0.06), Vector3(0.06, 0.06, 0.16), c("metal"))
	caja(n, Vector3(0, -0.1, -0.11), Vector3(0.14, 0.26, 0.03), c("metal"))
	Construir.cilindro(n, Vector3(0, 0.05, 0.0), 0.045, 0.1, c("blanco"), false, 6)


## Edificios del kit y torres con sus formas de colisión, para ver si un cable se mete adentro:
## [centro aproximado, radio, transformación inversa, formas de ColisionAuto].
static func _volumenes(ci: Ciudad) -> Array:
	var out := []
	var formas := {}
	for e: Array in NivelMedio.edificios_kit(ci):
		var mi: MeshInstance3D = e[0]
		var nombre: String = e[1]
		if not formas.has(nombre):
			formas[nombre] = ColisionAuto.formas(nombre)
		var aabb := mi.mesh.get_aabb()
		out.append([mi.transform * aabb.get_center(), aabb.size.length() / 2.0, mi.transform.affine_inverse(), formas[nombre]])
	for to: Dictionary in TORRES:
		var t := Transform3D(Basis.from_euler(Vector3(0, float(to["rot"]), 0)), to["esquina"])
		var caja_t := [Transform3D(Basis.IDENTITY, Vector3(LADO / 2.0, float(to["alto"]) / 2.0, -LADO / 2.0)).affine_inverse(),
			Vector3(LADO, float(to["alto"]), LADO) / 2.0]
		out.append([t * Vector3(LADO / 2.0, 0, -LADO / 2.0), LADO + float(to["alto"]), t.affine_inverse(), [caja_t]])
	return out


## Troncos de los árboles de la ciudad (en X/Z): las copas van de 2,5 a 9 m.
static func _arboles(ci: Ciudad) -> PackedVector2Array:
	var out := PackedVector2Array()
	for h in ci.get_children():
		if h is MeshInstance3D and h.has_meta(&"pieza"):
			var nombre := String(h.get_meta(&"pieza"))
			if nombre.contains("arbol") or nombre.contains("jacaranda") or nombre.contains("pino"):
				out.append(Vector2((h as Node3D).position.x, (h as Node3D).position.z))
	for p: Vector3 in NivelMedio.ARBOLES_ALTOS:
		out.append(Vector2(p.x, p.z))
	return out


## Si el cable de "a" a "b" (con su comba) pasa por adentro de un edificio o de la copa de un árbol.
## Los últimos 40 cm (donde se agarra a la pared) no cuentan.
static func _cable_choca(a: Vector3, b: Vector3, comba: float, volumenes: Array, arboles: PackedVector2Array) -> bool:
	var largo := a.distance_to(b)
	var medio := (a + b) / 2.0
	var cerca := []
	for v: Array in volumenes:
		if (v[0] as Vector3).distance_to(medio) < float(v[1]) + largo / 2.0 + 1.0:
			cerca.append(v)
	for s: AABB in NivelMedio.salientes:
		if s.grow(0.3).has_point(b):
			return true
	var pasos := ceili(largo / 0.4)
	for i in range(1, pasos):
		var t := float(i) / pasos
		if (1.0 - t) * largo < 0.4:
			break
		var q := a.lerp(b, t) - Vector3(0, 4.0 * comba * t * (1.0 - t), 0)
		for v: Array in cerca:
			if ColisionAuto._salida((v[2] as Transform3D) * q, v[3]) <= 0.1:
				return true
		for s: AABB in NivelMedio.salientes:
			if s.grow(0.15).has_point(q):
				return true
		if q.y > 2.5 and q.y < 9.0:
			for arbol in arboles:
				if arbol.distance_to(Vector2(q.x, q.z)) < 1.9:
					return true
	return false


static func _tendidos(ci: Ciudad) -> void:
	ci._mapear_ocupado()
	var fachadas := _fachadas(ci)
	var volumenes := _volumenes(ci)
	var arboles := _arboles(ci)
	for td: Array in TENDIDOS:
		var a: Vector3 = td[0]
		var b: Vector3 = td[1]
		var adentro: Vector3 = td[2]
		var largo := a.distance_to(b)
		var dir := (b - a) / largo
		var anterior := Vector3.INF
		var d := 0.0
		var k := 0
		while d <= largo + 0.01:
			var p := Vector3.INF
			for corrido: float in [0.0, 1.5, -1.5, 3.0, -3.0]:
				var q := a + dir * clampf(d + corrido, 0.0, largo) + Vector3(0, Ciudad.Y_VEREDA, 0)
				var h := Rect2(q.x - 0.4, q.z - 0.4, 0.8, 0.8)
				if ci._libre(h):
					ci._ocupar(h)
					p = q
					break
			if p != Vector3.INF:
				poste(ci, p, dir, adentro)
				var arriba := p + Vector3(0, Y_CRUCETA + 0.1, 0)
				# Del poste anterior a éste: dos cables, en las puntas de la cruceta
				if anterior != Vector3.INF and anterior.distance_to(p) < PASO_POSTES + 8.0:
					for lado in [-0.6, 0.6]:
						cable(ci, anterior + Vector3(0, Y_CRUCETA + 0.1, 0) + adentro * lado, arriba + adentro * lado, 0.5)
				# La bajada a una casa: cruzando la calle hasta la fachada de enfrente (uno sí y uno no) y,
				# en los otros, a la de atrás. Termina en un soporte en la pared; si en el camino se mete en
				# un edificio o en un árbol, no va.
				var f: Array = []
				if k % 2 == 0:
					var enfrente := p - adentro * 13.0
					for _paso in 12:
						f = _fachada_en(fachadas, enfrente)
						if not f.is_empty():
							break
						enfrente -= adentro * 0.5
				else:
					f = _fachada_en(fachadas, p + adentro * (Ciudad.VEREDA - 0.45))
				if not f.is_empty() and float(f[2]) >= 9.0:
					var desde := arriba + adentro * (-0.6 if k % 2 == 0 else 0.6)
					var agarre := _agarre(f, desde)
					var comba := 0.35 if k % 2 == 0 else 0.15
					if not agarre.is_empty() and not _cable_choca(desde, agarre[0], comba, volumenes, arboles):
						cable(ci, desde, agarre[0], comba)
						_soporte(ci, agarre[0], agarre[1])
						contar("bajada")
				anterior = p
				k += 1
			else:
				anterior = Vector3.INF
			d += PASO_POSTES


## Poste de luz de madera: base de hormigón con colisión (se posa arriba), cruceta con aisladores y un
## brazo con la lámpara hacia la calle (todo eso decorativo: en lo alto se posa en los cables).
static func poste(ci: Ciudad, p: Vector3, dir: Vector3, adentro: Vector3) -> void:
	var n := NivelMedio.marco(ci, Transform3D(Basis.from_euler(Vector3(0, atan2(adentro.x, adentro.z), 0)), p))
	# En el marco: +Z hacia las fachadas de atrás, -Z hacia la calle
	caja(n, Vector3(0, 0.55, 0), Vector3(0.5, 1.1, 0.5), c("piedra_osc"), true)
	Construir.cilindro(n, Vector3(0, 1.1 + (ALTO_POSTE - 1.1) / 2.0, 0), 0.13, ALTO_POSTE - 1.1, c("madera_osc"), false, 8, 0.1)
	caja(n, Vector3(0, Y_CRUCETA, 0), Vector3(0.1, 0.12, 1.6), c("madera_osc"))
	for z in [-0.6, 0.6]:
		Construir.cilindro(n, Vector3(0, Y_CRUCETA + 0.1, z), 0.04, 0.1, c("blanco"), false, 6)
	# Brazo y lámpara
	caja(n, Vector3(0, 6.9, -0.8), Vector3(0.06, 0.06, 1.6), c("metal"), false, Vector3(-0.2, 0, 0))
	caja(n, Vector3(0, 6.68, -1.6), Vector3(0.28, 0.12, 0.55), c("metal"))
	caja(n, Vector3(0, 6.61, -1.6), Vector3(0.22, 0.03, 0.45), c("luz"))
	muestras.append(["poste", p + Vector3(0, 1.1, 0)])
	contar("poste")


## Cable de "a" a "b" con una comba de "comba" m en el medio: tramos finitos (cajas) con su colisión,
## para que la paloma se pueda posar (no camina por el cable).
static func cable(ci: Ciudad, a: Vector3, b: Vector3, comba: float) -> void:
	var largo := a.distance_to(b)
	var tramos := clampi(ceili(largo / 2.5), 4, 12)
	var negro := c("hierro")
	var prev := a
	for i in range(1, tramos + 1):
		var t := float(i) / tramos
		var q := a.lerp(b, t) - Vector3(0, 4.0 * comba * t * (1.0 - t), 0)
		var d := q - prev
		var base := Basis.looking_at(d.normalized(), Vector3.UP)
		var centro := (prev + q) / 2.0
		var mi := Construir.caja(ci, centro, Vector3(GROSOR_CABLE, GROSOR_CABLE, d.length() + 0.02), negro, false)
		mi.basis = base
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var forma := BoxShape3D.new()
		forma.size = Vector3(GROSOR_COLISION, GROSOR_COLISION, d.length())
		Kit._forma(ci._cuerpo_en(centro), forma, Transform3D(base, centro))
		if i == tramos >> 1:
			muestras.append(["cable", q + Vector3(0, GROSOR_COLISION / 2.0, 0)])
		prev = q
	contar("cable")
