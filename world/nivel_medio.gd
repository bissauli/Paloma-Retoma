class_name NivelMedio
extends RefCounted
## Nivel medio del mapa (Fase 2): textura para la ciudad a media altura y lugares para posarse.
## - Balcones con baranda, piso y macetas en los edificios de altura media (10 a 20 m), y toldos sobre
##   las ventanas de esos edificios, de los cafés y de los edificios que rodean la plaza.
## - Cornisas a dos alturas en los edificios de 15 m o más.
## - Columnas de farol (plaza y Peatonal Florida) y carteles salientes en las fachadas.
## - Árboles altos (copas a 6-9 m) en la Plaza de Mayo y en la plaza en rombo del parque.
## Regla de colisión (la de la Fase 1): donde la paloma se posa hay colisión (piso y baranda del balcón,
## toldo, cornisa, base del farol, copa del árbol); lo decorativo no (macetas, barrotes, faldones,
## carteles, brazos y globos de los faroles).
## No hay piezas de Blender para esto: se arma con cajas, esferas y cilindros (Construir) con los
## colores de la paleta del kit. Lo de la ciudad lo llama Ciudad (etapa _nivel_medio, con su propia
## semilla) y lo de la plaza, plaza.gd.

const ALTO_MEDIO := Vector2(10.0, 20.0)   ## Edificios de altura media (balcones y toldos)
const ALTO_CORNISA := 15.0                ## Desde esta altura llevan cornisas
const PISO_0 := 4.26                      ## Losa del primer piso en las piezas del kit (y cada ALTO_PISO)
const ALTO_PISO := 3.0
const BALCON := Vector3(2.3, 0.14, 1.1)   ## Ancho, espesor y salida del piso del balcón
const BARANDA := 1.0
const CORNISA := Vector2(0.26, 0.45)      ## Alto y salida de la cornisa
const TOLDO_INCLINACION := 0.38
const RANGO_DETALLE := 100.0              ## Los detalles chicos no se dibujan más lejos (como los del kit)

const COLORES_TOLDO := ["toldo_rojo", "toldo_verde", "toldo_azul", "toldo_amarillo", "toldo_naranja"]
const COLORES_MACETA := ["tejas", "oxido", "ladrillo", "blanco", "remate_verde"]
const PLANTAS := [["hoja", ""], ["hoja_osc", "flor_rosa"], ["hoja", "flor_amarilla"], ["hoja_clara", "flor_roja"],
	["hoja_osc", "flor_violeta"], ["pino", ""], ["hoja", "flor_blanca"]]
const COLORES_CORNISA := ["blanco", "remate_crema", "piedra", "remate_crema", "piedra_osc"]

## Carteles salientes (verticales, letra por letra). Son rubros, no se traducen.
const RUBROS := ["HOTEL", "BAR", "PIZZA", "TANGO", "LIBROS", "BAZAR", "CAFÉ", "PENSIÓN", "SASTRE", "DISCOS"]
const COLORES_CARTEL := ["toldo_rojo", "remate_azul", "kiosco", "remate_marron", "toldo_naranja", "hierro"]

## Columnas de farol de la Plaza de Mayo (base con colisión para posarse).
const FAROLES_PLAZA := [Vector3(-42, 0, -24), Vector3(42, 0, -24), Vector3(-42, 0, 22), Vector3(42, 0, 22),
	Vector3(-6, 0, 22), Vector3(6, 0, 22)]
## Árboles altos (copas a 6-9 m): dos en la Plaza de Mayo y dos en la plaza en rombo del parque.
const ARBOLES_ALTOS := [Vector3(-25, 0, -26), Vector3(25, 0, -26), Vector3(-129.4, Ciudad.T_PARQUE, -50.4),
	Vector3(-150.6, Ciudad.T_PARQUE, -71.6)]
const ESCALA_ARBOL := 1.65   ## Edificios.jacaranda: tronco de 5,3 m y la copa de 6 a 9 m

## Cuántas cosas de cada tipo se armaron (lo miran las pruebas).
static var cuenta := {}
## Balcones, toldos y cornisas de la ciudad con colisión: [tipo, punto de arriba en el mundo] (pruebas).
static var muestras: Array = []


# ---------------------------------------------------------------- Ayudas para armar

## Color de la paleta del kit por nombre.
static func c(nombre: String) -> Color:
	return NivelInferior.c(nombre)


static func contar(tipo: String, k := 1) -> void:
	cuenta[tipo] = int(cuenta.get(tipo, 0)) + k


## Marco local: un Node3D hijo de "raiz" con la transformación "t". Lo que se arma adentro va en
## coordenadas locales (las piezas se fusionan igual: la fusión usa las transformaciones globales).
static func marco(raiz: Node3D, t: Transform3D) -> Node3D:
	var n := Node3D.new()
	raiz.add_child(n)
	n.transform = t
	return n


## Colisión de una forma en coordenadas del marco "n": en la ciudad va al cuerpo de la celda; en la
## plaza, a un cuerpo propio.
static func colision(n: Node3D, forma: Shape3D, local: Transform3D) -> void:
	var raiz := n.get_parent() as Node3D
	var t := n.transform * local
	if raiz is Ciudad:
		Kit._forma((raiz as Ciudad)._cuerpo_en(t.origin), forma, t)
	else:
		var b := Construir.colision(raiz, t.origin, forma)
		b.transform = t


## Caja de color en el marco "n", girada "rot" (euler). "detalle": chica, sin sombra y no se dibuja lejos.
static func caja(n: Node3D, centro: Vector3, tam: Vector3, color: Color, col := false, rot := Vector3.ZERO,
		detalle := false) -> MeshInstance3D:
	var mi := Construir.caja(n, centro, tam, color, false)
	mi.rotation = rot
	if detalle:
		_detalle(mi)
	if col:
		var forma := BoxShape3D.new()
		forma.size = tam
		colision(n, forma, Transform3D(Basis.from_euler(rot), centro))
	return mi


static func _detalle(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta(&"rango", RANGO_DETALLE * (0.7 if Ajustes.movil else 1.0))


## Caja a lo largo del segmento a-b (en el plano del marco), "alto" de alto y que sale "salida" hacia
## afuera (a la izquierda de a->b mirando desde arriba, o sea con a->b en sentido antihorario).
static func tramo(n: Node3D, a: Vector3, b: Vector3, y: float, alto: float, salida: float, color: Color,
		col := false) -> void:
	var largo := a.distance_to(b)
	if largo < 0.05:
		return
	var dir := (b - a) / largo
	var afuera := Vector3(-dir.z, 0, dir.x)
	var centro := (a + b) / 2.0 + afuera * (salida / 2.0) + Vector3(0, y, 0)
	caja(n, centro, Vector3(largo, alto, salida), color, col, Vector3(0, atan2(-dir.z, dir.x), 0))


# ---------------------------------------------------------------- Piezas

## Balcón sobre la fachada (z = 0 del marco, +Z hacia afuera) con el piso en "y" y centrado en "x":
## losa con colisión, baranda de hierro (el pasamanos de adelante con colisión) y 1 a 3 macetas.
static func balcon(n: Node3D, x: float, y: float, rng: RandomNumberGenerator, ancho := BALCON.x,
		salida := BALCON.z) -> void:
	var hierro := c("hierro")
	caja(n, Vector3(x, y, salida / 2.0), Vector3(ancho, BALCON.y, salida), c("piedra"), true)
	# Ménsulas debajo de la losa
	for lado in [-1.0, 1.0]:
		caja(n, Vector3(x + lado * (ancho / 2.0 - 0.25), y - 0.17, 0.3), Vector3(0.12, 0.2, 0.6), c("piedra_osc"),
			false, Vector3.ZERO, true)
	var yb := y + BALCON.y / 2.0
	# Pasamanos (adelante con colisión, para posarse en la baranda) y barrotes
	caja(n, Vector3(x, yb + BARANDA, salida - 0.04), Vector3(ancho, 0.06, 0.06), hierro, true)
	var nb := maxi(roundi(ancho / 0.38), 3)
	for i in nb + 1:
		var xb := x - ancho / 2.0 + 0.03 + i * (ancho - 0.06) / nb
		caja(n, Vector3(xb, yb + BARANDA / 2.0, salida - 0.04), Vector3(0.035, BARANDA, 0.035), hierro, false,
			Vector3.ZERO, true)
	for lado in [-1.0, 1.0]:
		var xl: float = x + lado * (ancho / 2.0 - 0.03)
		caja(n, Vector3(xl, yb + BARANDA, salida / 2.0), Vector3(0.06, 0.06, salida), hierro, false, Vector3.ZERO, true)
		for j in 2:
			caja(n, Vector3(xl, yb + BARANDA / 2.0, salida * (j + 1) / 3.0), Vector3(0.035, BARANDA, 0.035), hierro,
				false, Vector3.ZERO, true)
	# Macetas contra la baranda (sólo para ver)
	var m := 1 + rng.randi() % 3
	for i in m:
		var px := x + (i - (m - 1) / 2.0) * minf(0.7, (ancho - 0.5) / m)
		maceta(n, Vector3(px, yb, salida - 0.32), rng)
	# Marcador para que las palomas de la bandada se sienten (ver player/descanso.gd)
	var marca := Marker3D.new()
	marca.position = Vector3(x, y + BALCON.y / 2.0, salida / 2.0)
	marca.set_meta("ancho", ancho)
	marca.set_meta("salida", salida)
	marca.add_to_group("balcones_percha")
	n.add_child(marca)
	contar("balcon")
	contar("maceta", m)


## Maceta con su planta (y a veces flores), apoyada en "pos". Sin colisión.
static func maceta(n: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	# Una maceta que se tira de un aletazo (ver Golpeable)
	var planta: Array = PLANTAS[rng.randi() % PLANTAS.size()]
	var g := Golpeable.new()
	g.tipo = "maceta"
	g.color = c(COLORES_MACETA[rng.randi() % COLORES_MACETA.size()])
	g.escala = rng.randf_range(0.9, 1.15)
	g.color_hojas = c(planta[0])
	if planta[1] != "":
		g.color_flor = c(planta[1])
	n.add_child(g)
	g.position = pos
	g.fijar_origen.call_deferred()


## Toldo a rayas sobre una ventana: arranca contra la pared (z = 0 del marco) a la altura "y" y baja
## hacia afuera. La lona tiene colisión (se posa encima); el faldón y los brazos no.
static func toldo(n: Node3D, x: float, y: float, ancho: float, salida: float, color: Color) -> void:
	var ang := TOLDO_INCLINACION
	var largo := salida / cos(ang)
	var centro := Vector3(x, y - sin(ang) * largo / 2.0, salida / 2.0)
	var rot := Vector3(ang, 0, 0)
	# Lona en franjas que se tocan (sin superponerse: no parpadean)
	var franjas := maxi(roundi(ancho / 0.3), 3) | 1
	for i in franjas:
		var xf := x - ancho / 2.0 + (i + 0.5) * ancho / franjas
		caja(n, Vector3(xf, centro.y, centro.z), Vector3(ancho / franjas, 0.05, largo),
			color if i % 2 == 0 else c("blanco"), false, rot)
	var forma := BoxShape3D.new()
	forma.size = Vector3(ancho, 0.1, largo)
	colision(n, forma, Transform3D(Basis.from_euler(rot), centro))
	# Faldón adelante y brazos de hierro
	var y_borde := y - sin(ang) * largo
	caja(n, Vector3(x, y_borde - 0.12, salida + 0.01), Vector3(ancho, 0.24, 0.03), color.darkened(0.12), false,
		Vector3.ZERO, true)
	for lado in [-1.0, 1.0]:
		var a := Vector3(x + lado * (ancho / 2.0 - 0.05), y - 0.75, 0.0)
		var b := Vector3(x + lado * (ancho / 2.0 - 0.05), y_borde - 0.03, salida)
		var d := b - a
		caja(n, (a + b) / 2.0, Vector3(0.03, 0.03, d.length()), c("hierro"), false,
			Vector3(-atan2(d.y, d.z), 0, 0), true)
	contar("toldo")


## Columna de farol de tres globos. Base maciza con colisión (se posa arriba, a 0,95 m); el fuste, los
## brazos y los globos son decorativos.
static func columna_farol(raiz: Node3D, pos: Vector3, rot_y := 0.0) -> void:
	var n := marco(raiz, Transform3D(Basis.from_euler(Vector3(0, rot_y, 0)), pos))
	var verde := Color("2f4a3c")
	caja(n, Vector3(0, 0.45, 0), Vector3(0.62, 0.9, 0.62), c("piedra_osc"), true)
	caja(n, Vector3(0, 0.93, 0), Vector3(0.72, 0.08, 0.72), c("piedra"), false)
	Construir.cilindro(n, Vector3(0, 1.25, 0), 0.16, 0.6, verde, false, 8, 0.11)
	Construir.cilindro(n, Vector3(0, 3.1, 0), 0.09, 3.2, verde, false, 8, 0.07)
	Construir.cilindro(n, Vector3(0, 4.75, 0), 0.13, 0.12, verde, false, 8)
	for k in 2:
		var lado := -1.0 if k == 0 else 1.0
		caja(n, Vector3(lado * 0.38, 4.85, 0), Vector3(0.76, 0.06, 0.06), verde, false, Vector3.ZERO, true)
		Construir.cilindro(n, Vector3(lado * 0.72, 4.98, 0), 0.05, 0.2, verde, false, 6)
		Construir.esfera(n, Vector3(lado * 0.72, 5.25, 0), 0.2, c("luz"), Vector3(1, 1.15, 1), 8)
	Construir.esfera(n, Vector3(0, 5.35, 0), 0.22, c("luz"), Vector3(1, 1.15, 1), 8)
	Construir.cilindro(n, Vector3(0, 5.66, 0), 0.03, 0.18, verde, false, 6, 0.0)
	contar("columna_farol")


## Cartel saliente vertical (de pie en la fachada, a "x" del centro), letra por letra en las dos caras.
static func cartel_saliente(n: Node3D, x: float, y: float, texto: String, color: Color) -> void:
	var letras := texto.length()
	var alto := 0.42 * letras + 0.3
	caja(n, Vector3(x, y, 0.62), Vector3(0.1, alto, 0.78), color, false)
	caja(n, Vector3(x, y, 0.62), Vector3(0.12, alto + 0.08, 0.06), c("blanco"), false, Vector3.ZERO, true)
	for dy in [-alto / 2.0 + 0.15, alto / 2.0 - 0.15]:
		caja(n, Vector3(x, y + dy, 0.12), Vector3(0.05, 0.05, 0.24), c("hierro"), false, Vector3.ZERO, true)
	var vertical := "\n".join(texto.split(""))
	for lado in [-1.0, 1.0]:
		var l := Construir.cartel(n, Vector3(x + lado * 0.056, y, 0.62), vertical, Color.WHITE, 40)
		l.rotation.y = lado * PI / 2.0
		l.line_spacing = -6.0
		l.outline_size = 6
		l.visibility_range_end = 55.0 * (0.7 if Ajustes.movil else 1.0)
	contar("cartel")


# ---------------------------------------------------------------- Plaza

## Lo de la plaza (lo llama plaza.gd): toldos sobre las ventanas de los cafés, balcones y toldos en los
## edificios de alrededor, columnas de farol y los dos árboles altos de la plaza.
static func plaza(padre: Node3D) -> void:
	var raiz := Node3D.new()
	raiz.name = "NivelMedio"
	padre.add_child(raiz)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261116
	for k in Edificios.CAFES.size():
		var e: Dictionary = Edificios.CAFES[k]
		var tam := Vector3(e["ancho"], e["alto"], 10)
		var n := marco(raiz, Transform3D(Basis.from_euler(Vector3(0, PI, 0)), Vector3(e["x"], 0, 38.0)))
		var color: Color = e["toldo"]
		for v: Vector2 in _ventanas_altas(tam, Vector3(0, 0, -1)):
			toldo(n, v.x, v.y + 0.95, 1.5, 0.85, color.lightened(0.08))
	for k in Edificios.ALREDEDORES.size():
		var e: Array = Edificios.ALREDEDORES[k]
		var base: Vector3 = e[0]
		var tam: Vector3 = e[1]
		var frente: Vector3 = e[3]
		var prof := tam.z if absf(frente.z) > 0.5 else tam.x
		var cara := base + frente * (prof / 2.0)
		var n := marco(raiz, Transform3D(Basis.from_euler(Vector3(0, atan2(frente.x, frente.z), 0)), cara))
		var color := c(COLORES_TOLDO[k % COLORES_TOLDO.size()])
		for v: Vector2 in _ventanas_altas(tam, frente):
			if k % 2 == 0:
				balcon(n, v.x, v.y - 0.87, rng, 1.6, 0.95)
			else:
				toldo(n, v.x, v.y + 0.95, 1.5, 0.85, color)
	for p: Vector3 in FAROLES_PLAZA:
		columna_farol(raiz, p)
	for p: Vector3 in ARBOLES_ALTOS:
		if Ciudad.PLAZA.has_point(Vector2(p.x, p.z)):
			Edificios.jacaranda(raiz, p, ESCALA_ARBOL)
			contar("arbol_alto")


## Ventanas de un Edificios.edificio() por encima de la planta baja y que no chocan con la cornisa
## intermedia (ni la ventana ni lo que se le ponga arriba).
static func _ventanas_altas(tam: Vector3, frente: Vector3) -> Array[Vector2]:
	var y_cornisa := tam.y * 0.45
	var out: Array[Vector2] = []
	for v: Vector2 in Edificios.ventanas(tam, frente):
		if v.y < 4.0 or v.y + 1.2 > tam.y:
			continue
		if absf(v.y + 0.95 - y_cornisa) < 0.45 or absf(v.y - 0.87 - y_cornisa) < 0.3:
			continue
		out.append(v)
	return out


# ---------------------------------------------------------------- Ciudad

## Edificios del kit (sin las versiones de lejos) cuyo frente da al mapa jugable:
## [MeshInstance3D, nombre, datos].
static func edificios_kit(ciudad: Ciudad) -> Array:
	var out := []
	for h in ciudad.get_children():
		var mi := h as MeshInstance3D
		if mi == null or not mi.has_meta(&"pieza"):
			continue
		var nombre := String(mi.get_meta(&"pieza"))
		var d: Dictionary = KitDatos.PIEZAS.get(nombre, {})
		if d.get("carpeta", "") != "edificios" or not d.has("alto"):
			continue
		var frente := mi.transform * Vector3(0, 0, 3.0)
		if d.get("tipo", "") == "esquina":
			frente = mi.transform * Vector3(4.0, 0, 4.0)
		if frente.x < Ciudad.X_MIN or frente.x > Ciudad.X_MAX or frente.z < Ciudad.Z_MIN or frente.z > Ciudad.Z_MAX:
			continue
		out.append([mi, nombre, d])
	return out


## Lo de la ciudad (lo llama la etapa Ciudad._nivel_medio).
static func ciudad(ci: Ciudad) -> void:
	var rng := ci._rng
	var k_cartel := 0
	for e: Array in edificios_kit(ci):
		var mi: MeshInstance3D = e[0]
		var nombre: String = e[1]
		var d: Dictionary = e[2]
		var alto := float(d["alto"])
		if nombre.begins_with("hospital") or nombre.begins_with("comisaria") or nombre.begins_with("barrio"):
			continue
		var n := marco(ci, mi.transform)
		var pisos_cornisa: Array[int] = []
		# Los de departamentos ya tienen balcones corridos en cada piso: ahí no van cornisas
		if alto >= ALTO_CORNISA and not nombre.begins_with("dep_") and not nombre.begins_with("esq_dep"):
			pisos_cornisa = _cornisas(n, d, alto, c(COLORES_CORNISA[rng.randi() % COLORES_CORNISA.size()]))
		if d.get("tipo", "") != "medio" or alto < ALTO_MEDIO.x or alto > ALTO_MEDIO.y:
			continue
		var ancho := float(d["ancho"])
		var xs := _ventanas_kit(d, ancho)
		var color_toldo := c(COLORES_TOLDO[rng.randi() % COLORES_TOLDO.size()])
		# Uno de cada cuatro, un cartel saliente en una punta de la fachada (ahí no van balcones ni toldos)
		var x_cartel := INF
		if k_cartel % 4 == 1:
			x_cartel = (-1.0 if rng.randf() < 0.5 else 1.0) * (ancho / 2.0 - 0.35)
			var texto: String = RUBROS[(k_cartel >> 2) % RUBROS.size()]
			var medio_alto := (0.42 * texto.length() + 0.3) / 2.0
			cartel_saliente(n, x_cartel, minf(PISO_0 + 0.6 + medio_alto, alto - 0.5 - medio_alto), texto,
				c(COLORES_CARTEL[rng.randi() % COLORES_CARTEL.size()]))
		k_cartel += 1
		var algo := false
		var pisos := 0
		while PISO_0 + ALTO_PISO * (pisos + 1) <= alto + 0.1:
			pisos += 1
		for k in pisos:
			if k in pisos_cornisa:
				continue
			var r := rng.randf()
			if k == pisos - 1 and not algo:
				r = 0.0
			var y := PISO_0 + ALTO_PISO * k
			for x: float in xs:
				if rng.randf() > 0.85 or absf(x - x_cartel) < 1.45:
					continue
				if r < 0.45:
					balcon(n, x, y, rng)
					if muestras.size() < 400:
						muestras.append(["balcon", n.transform * Vector3(x, y + BALCON.y / 2.0, 0.8)])
					algo = true
				elif r < 0.7:
					toldo(n, x, y + 2.35, 1.9, 0.95, color_toldo)
					if muestras.size() < 400:
						muestras.append(["toldo", n.transform * Vector3(x, y + 2.0, 0.45)])
					algo = true
	_faroles_peatonal(ci)
	for p: Vector3 in ARBOLES_ALTOS:
		if not Ciudad.PLAZA.has_point(Vector2(p.x, p.z)):
			Edificios.jacaranda(ci, p, ESCALA_ARBOL)
			contar("arbol_alto")


## Posiciones en X de las ventanas de una pieza del kit: de los alféizares del primer piso (las cajas de
## 1,85 m a 4,47 m de altura); si no tiene, repartidas cada ~3 m.
static func _ventanas_kit(d: Dictionary, ancho: float) -> Array[float]:
	var xs: Array[float] = []
	for cj: Array in d.get("cajas", []):
		if absf(float(cj[1]) - 4.47) < 0.1 and absf(float(cj[3]) - 1.85) < 0.05:
			xs.append(float(cj[0]))
	if xs.is_empty():
		var nv := maxi(roundi(ancho / 3.0), 1)
		for i in nv:
			xs.append((i - (nv - 1) / 2.0) * ancho / nv)
	xs.sort()
	return xs


## Cornisas a dos alturas (en la línea de un entrepiso: entre la ventana de abajo y el alféizar de
## arriba), con una moldura debajo. Devuelve los pisos donde quedaron (ahí no van balcones).
static func _cornisas(n: Node3D, d: Dictionary, alto: float, color: Color) -> Array[int]:
	var k_a := 1
	var k_b := k_a
	while PISO_0 - 0.24 + ALTO_PISO * (k_b + 1) <= alto - 5.0:
		k_b += 1
	var ks: Array[int] = [k_a]
	if k_b > k_a:
		ks.append(k_b)
	var tramos := _tramos_fachada(d)
	for k in ks:
		var y := PISO_0 - 0.24 + ALTO_PISO * k
		for t: Array in tramos:
			tramo(n, t[0], t[1], y, CORNISA.x, CORNISA.y, color, true)
			tramo(n, t[0], t[1], y - CORNISA.x / 2.0 - 0.06, 0.12, CORNISA.y * 0.6, color.darkened(0.1))
			if muestras.size() < 400:
				var m := ((t[0] as Vector3) + (t[1] as Vector3)) / 2.0
				var dir := ((t[1] as Vector3) - (t[0] as Vector3)).normalized()
				muestras.append(["cornisa", n.transform * (m + Vector3(-dir.z, 0, dir.x) * CORNISA.y / 2.0 + Vector3(0, y + CORNISA.x / 2.0, 0))])
		contar("cornisa")
	return ks


## Tramos rectos de la fachada en el marco de la pieza, en sentido antihorario (afuera a la izquierda).
## Medianeras: la fachada en z = 0 de -ancho/2 a ancho/2. Esquinas: la de -X (x = 0), la ochava a 45°
## (si tiene) y la de +Z (z = 0), de 0 a 16 m.
static func _tramos_fachada(d: Dictionary) -> Array:
	if d.get("tipo", "") != "esquina":
		var w := float(d["ancho"]) / 2.0
		return [[Vector3(-w, 0, 0), Vector3(w, 0, 0)]]
	var lado := float(d.get("ancho", 16.0))
	var ochava := 0.0
	for cj: Array in d.get("cajas", []):
		# El pretil de la ochava: la caja girada 45°, arriba de todo
		if absf(absf(float(cj[6])) - 0.7071) < 0.01 and float(cj[1]) > float(d["alto"]):
			ochava = float(cj[3]) / sqrt(2.0)
	if ochava <= 0.0:
		return [[Vector3(0, 0, -lado), Vector3(0, 0, 0)], [Vector3(0, 0, 0), Vector3(lado, 0, 0)]]
	return [[Vector3(0, 0, -lado), Vector3(0, 0, -ochava)], [Vector3(0, 0, -ochava), Vector3(ochava, 0, 0)],
		[Vector3(ochava, 0, 0), Vector3(lado, 0, 0)]]


## Columnas de farol a los dos lados de la Peatonal Florida, cada 15 m donde haya lugar.
static func _faroles_peatonal(ci: Ciudad) -> void:
	ci._mapear_ocupado()
	var x := Ciudad.PEATONAL[0] + 12.0
	var k := 0
	while x < Ciudad.PEATONAL[2] - 8.0:
		var z: float = Ciudad.PEATONAL[1] + 1.1 if k % 2 == 0 else Ciudad.PEATONAL[3] - 1.1
		for dx: float in [0.0, 1.5, -1.5, 3.0]:
			var p := Vector3(x + dx, Ciudad.Y_VEREDA, z)
			var h := Rect2(p.x - 0.45, p.z - 0.45, 0.9, 0.9)
			if ci._libre(h):
				columna_farol(ci, p)
				ci._ocupar(h)
				break
		x += 15.0
		k += 1
