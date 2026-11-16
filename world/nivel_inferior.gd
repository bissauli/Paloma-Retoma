class_name NivelInferior
extends RefCounted
## Nivel inferior del mapa (Fase 1): lugares para caminar y posarse cerca del piso.
## - Pasajes cubiertos con toldo en los huecos entre los cafés (de la vereda de los cafés al Pasaje
##   Las Palomas).
## - Galería con dos cruces de paso al sur del Cabildo (columnas y arcos con colisión).
## - Mercado: seis puestos con toldo y mesa en la esquina sudeste de la plaza.
## La boca de subte (con escalera) está en Edificios.subte y el mobiliario de las veredas y la obra en
## Ciudad (_mobiliario y _obra_cuadra).
## No hay piezas de Blender para esto: todo se arma con cajas, esferas y cilindros con los colores de la
## paleta del kit (KitDatos.PALETA). Regla: lo que se pisa o donde la paloma se posa tiene colisión
## (pisos, toldos, techos, mesas, columnas y arcos); lo decorativo (faldones, caños, lámparas,
## vidrieras, mercadería) no.

## Pasajes: [x oeste, x este] de cada hueco entre los cafés (ver Edificios.cafes y alrededores).
const PASAJES := [[-46.0, -39.0], [-21.0, -16.0], [0.0, 5.0]]
const Z_PASAJE := Vector2(38.0, 48.0)     ## De la fachada de los cafés al pasaje
const Y_VEREDA := 0.16
const ALERO := 3.4                         ## Altura del toldo contra las paredes
const CUMBRERA := 4.0                      ## ...y en el medio

## Galería: grilla de bahías cuadradas de BAHIA m; las celdas cubiertas forman un pasillo este-oeste
## con dos cruces norte-sur.
const GALERIA_ORIGEN := Vector2(-60.6, 16.2)
const BAHIA := 3.2
const GALERIA_CELDAS := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(1, 0), Vector2i(1, 2), Vector2i(3, 0), Vector2i(3, 2)]
const ARRANQUE := 2.4                      ## Altura donde arrancan los arcos (capitel)
const COLUMNA := 0.5
const ROSCA := 0.25                        ## Espesor de la rosca del arco
const Y_CORNISA := 4.0                     ## Arriba de los arcos
const Y_TERRAZA := 4.55                    ## Piso de la terraza

## Mercado: [posición, giro] de cada puesto (el frente mira a +Z local).
const PUESTOS := [[Vector3(28.0, 0, 18.5), 0.0], [Vector3(31.4, 0, 18.5), 0.0], [Vector3(34.8, 0, 18.5), 0.0],
	[Vector3(28.0, 0, 23.5), PI], [Vector3(31.4, 0, 23.5), PI], [Vector3(34.8, 0, 23.5), PI]]
const MERCADERIA := ["frutas", "flores", "ropa", "verduras", "libros", "artesanias"]
const TOLDOS_PUESTO := ["toldo_rojo", "toldo_verde", "toldo_azul", "toldo_amarillo", "toldo_naranja", "toldo_verde"]

static var _colores := {}


## Color de la paleta del kit por nombre.
static func c(nombre: String) -> Color:
	if _colores.is_empty():
		for p: Array in KitDatos.PALETA:
			_colores[p[0]] = Color(p[1] as String)
	return _colores.get(nombre, Color.MAGENTA)


## Arma todo (lo llama world/plaza.gd).
static func armar(padre: Node3D) -> void:
	var n := Node3D.new()
	n.name = "NivelInferior"
	padre.add_child(n)
	pasajes(n)
	galeria(n)
	mercado(n)


## Zonas donde el mobiliario de las veredas no tiene que ponerse (entradas de la galería y de los pasajes).
static func reservas() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var g := Rect2(GALERIA_ORIGEN, Vector2(5, 3) * BAHIA)
	out.append(g.grow(2.5))
	for p: Array in PASAJES:
		out.append(Rect2(float(p[0]) - 1.0, Z_PASAJE.x - 4.0, float(p[1]) - float(p[0]) + 2.0, Z_PASAJE.y - Z_PASAJE.x + 8.0))
	return out


# ---------------------------------------------------------------- Ayudas

static func cuerpo(padre: Node3D, nombre: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = nombre
	b.collision_layer = Construir.CAPA_MUNDO
	b.collision_mask = 0
	padre.add_child(b)
	return b


## Caja visible (sin colisión) con cualquier giro.
static func pieza(padre: Node3D, t: Transform3D, tam: Vector3, color: Color) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = tam
	var mi := Construir._malla(padre, bm, Vector3.ZERO, Construir.material(color))
	mi.transform = t
	return mi


## Forma de colisión (caja) dentro de "cuerpo".
static func solido(cuerpo_: StaticBody3D, t: Transform3D, tam: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = tam
	Kit._forma(cuerpo_, forma, t)


## Caja visible con su colisión.
static func bloque(padre: Node3D, cuerpo_: StaticBody3D, t: Transform3D, tam: Vector3, color: Color) -> void:
	pieza(padre, t, tam, color)
	solido(cuerpo_, t, tam)


static func en(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


# ---------------------------------------------------------------- Pasajes

static func pasajes(padre: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Pasajes"
	padre.add_child(n)
	var cu := cuerpo(n, "ColisionPasajes")
	var colores := [["toldo_verde", "blanco"], ["toldo_rojo", "remate_crema"], ["toldo_azul", "blanco"]]
	for i in PASAJES.size():
		_pasaje(n, cu, float(PASAJES[i][0]), float(PASAJES[i][1]), colores[i % colores.size()])


## Un pasaje entre dos paredes (x0 y x1): piso de baldosas, toldo a dos aguas de pared a pared (se
## puede aterrizar encima), estructura de caños, faroles colgantes y vidrieras en las paredes.
static func _pasaje(n: Node3D, cu: StaticBody3D, x0: float, x1: float, colores: Array) -> void:
	var ancho := x1 - x0
	var xc := (x0 + x1) / 2.0
	var largo := Z_PASAJE.y - Z_PASAJE.x
	var zc := (Z_PASAJE.x + Z_PASAJE.y) / 2.0
	# Piso de baldosas (1,5 cm sobre la vereda: el escalón no se nota y la paloma lo pisa sin trabarse)
	var mat := Construir.material_baldosas(c("lajas"), c("lajas_osc"), Vector2(0.5, 0.5))
	var tam_piso := Vector3(ancho - 0.02, 0.05, largo)
	var t_piso := en(Vector3(xc, Y_VEREDA + 0.015 - 0.025, zc))
	var piso := Construir._malla(n, _caja(tam_piso), Vector3.ZERO, mat)
	piso.transform = t_piso
	solido(cu, t_piso, tam_piso)
	# Toldo a dos aguas, a rayas de 0,9 m, 40 cm más largo que el pasaje en cada punta
	var medio := ancho / 2.0
	var ang := atan2(CUMBRERA - ALERO, medio)
	var faldon := sqrt(medio * medio + (CUMBRERA - ALERO) * (CUMBRERA - ALERO))
	var largo_toldo := largo + 0.8
	var rayas := 12
	for s: float in [-1.0, 1.0]:
		var rot := Vector3(0, 0, -s * ang)
		var centro := Vector3(xc + s * medio / 2.0, (ALERO + CUMBRERA) / 2.0, zc)
		var b := Basis.from_euler(rot)
		for k in rayas:
			var z := zc - largo_toldo / 2.0 + (k + 0.5) * largo_toldo / rayas
			pieza(n, Transform3D(b, Vector3(centro.x, centro.y, z)), Vector3(faldon + 0.04, 0.06, largo_toldo / rayas),
				c(colores[k % 2]))
		# Colisión: más gruesa que la lona y con la cara de arriba a la misma altura
		solido(cu, Transform3D(b, centro - b.y * 0.07), Vector3(faldon, 0.2, largo_toldo))
		# Faldones en las dos puntas (decorativos)
		for z: float in [zc - largo_toldo / 2.0, zc + largo_toldo / 2.0]:
			pieza(n, Transform3D(b, Vector3(centro.x, centro.y, z) - b.y * 0.17), Vector3(faldon, 0.26, 0.03), c(colores[0]))
		# Caños de la estructura debajo de la lona
		for z in [Z_PASAJE.x + 0.4, zc, Z_PASAJE.y - 0.4]:
			pieza(n, Transform3D(b, Vector3(centro.x, centro.y, z) - b.y * 0.07), Vector3(faldon, 0.05, 0.05), c("hierro"))
	# Cumbrera y caño largo del medio
	pieza(n, en(Vector3(xc, CUMBRERA + 0.02, zc)), Vector3(0.12, 0.06, largo_toldo), c(colores[0]))
	pieza(n, en(Vector3(xc, CUMBRERA - 0.12, zc)), Vector3(0.05, 0.05, largo), c("hierro"))
	# Faroles colgantes
	for z in [zc - largo / 4.0, zc + largo / 4.0]:
		pieza(n, en(Vector3(xc, CUMBRERA - 0.4, z)), Vector3(0.02, 0.5, 0.02), c("hierro"))
		pieza(n, en(Vector3(xc, CUMBRERA - 0.7, z)), Vector3(0.26, 0.12, 0.26), c("hierro"))
		Construir.esfera(n, Vector3(xc, CUMBRERA - 0.82, z), 0.13, c("luz"), Vector3.ONE, 8)
	# Vidrieras y puertas en las dos paredes (pasaje comercial)
	for lado: float in [-1.0, 1.0]:
		var x := (x0 + 0.04) if lado < 0.0 else (x1 - 0.04)
		for k in 2:
			var z := Z_PASAJE.x + largo * (0.3 + 0.4 * k)
			pieza(n, en(Vector3(x, Y_VEREDA + 1.35, z)), Vector3(0.04, 2.1, 2.4), c("marco"))
			pieza(n, en(Vector3(x - lado * 0.01, Y_VEREDA + 1.35, z)), Vector3(0.04, 1.9, 2.2), c("vidrio_osc"))
			pieza(n, en(Vector3(x - lado * 0.02, Y_VEREDA + 2.6, z)), Vector3(0.04, 0.35, 2.4), c(colores[0]))


static func _caja(tam: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = tam
	return bm


# ---------------------------------------------------------------- Galería del Cabildo

## Galería al sur del Cabildo, entre el Cabildo y la avenida: un pasillo este-oeste de cinco bahías con
## dos cruces norte-sur. Cada bahía tiene columnas en las esquinas, un arco de medio punto en cada lado
## (también los de adentro) y una terraza con baranda arriba. Todo tiene colisión: se camina por
## abajo, se pasa por cualquier arco y se aterriza en la terraza, la baranda o la cornisa.
static func galeria(padre: Node3D) -> void:
	var n := Node3D.new()
	n.name = "GaleriaCabildo"
	padre.add_child(n)
	var cu := cuerpo(n, "ColisionGaleria")
	var celdas := {}
	for k: Vector2i in GALERIA_CELDAS:
		celdas[k] = true
	var blanco := c("remate_crema")
	var piedra := c("piedra")
	var mat_piso := Construir.material_baldosas(c("piedra"), c("piedra_osc"), Vector2(1.0 / 1.6, 1.0 / 1.6))
	var vertices := {}
	var lados := {}   # "h_i_j" (a lo largo de X) / "v_i_j" (a lo largo de Z) -> cuántas celdas lo usan
	for k: Vector2i in GALERIA_CELDAS:
		var o := _vertice(k)
		var centro := o + Vector3(BAHIA / 2.0, 0, BAHIA / 2.0)
		# Piso de baldosas (1 cm sobre la plaza) y terraza
		var t_piso := en(centro + Vector3(0, -0.01, 0))
		var piso := Construir._malla(n, _caja(Vector3(BAHIA, 0.04, BAHIA)), Vector3.ZERO, mat_piso)
		piso.transform = t_piso
		solido(cu, t_piso, Vector3(BAHIA, 0.04, BAHIA))
		bloque(n, cu, en(centro + Vector3(0, Y_TERRAZA - 0.1, 0)), Vector3(BAHIA, 0.2, BAHIA), blanco)
		for v: Vector2i in [k, k + Vector2i(1, 0), k + Vector2i(0, 1), k + Vector2i(1, 1)]:
			vertices[v] = true
		for l: String in ["h_%d_%d" % [k.x, k.y], "h_%d_%d" % [k.x, k.y + 1], "v_%d_%d" % [k.x, k.y], "v_%d_%d" % [k.x + 1, k.y]]:
			lados[l] = int(lados.get(l, 0)) + 1
	# Columnas: basa, fuste, capitel y pilar hasta la cornisa (una sola colisión hasta arriba)
	for v: Vector2i in vertices:
		var p := _vertice(v)
		pieza(n, en(p + Vector3(0, 0.1, 0)), Vector3(0.66, 0.2, 0.66), piedra)
		pieza(n, en(p + Vector3(0, ARRANQUE / 2.0, 0)), Vector3(COLUMNA, ARRANQUE, COLUMNA), blanco)
		pieza(n, en(p + Vector3(0, ARRANQUE + 0.075, 0)), Vector3(0.64, 0.15, 0.64), piedra)
		var alto_pilar := Y_CORNISA - ARRANQUE - 0.15
		pieza(n, en(p + Vector3(0, ARRANQUE + 0.15 + alto_pilar / 2.0, 0)), Vector3(COLUMNA, alto_pilar, COLUMNA), blanco)
		solido(cu, en(p + Vector3(0, Y_CORNISA / 2.0, 0)), Vector3(COLUMNA, Y_CORNISA, COLUMNA))
	# Arcos en cada lado, cornisa encima y baranda en los lados de afuera
	for l: String in lados:
		var partes := l.split("_")
		var v := Vector2i(int(partes[1]), int(partes[2]))
		var a := _vertice(v)
		var u := Vector3.RIGHT if partes[0] == "h" else Vector3.BACK
		var m := a + u * BAHIA / 2.0
		_arco(n, cu, m, u, blanco)
		var afuera := int(lados[l]) == 1
		var tam_cornisa := Vector3(BAHIA + COLUMNA, Y_TERRAZA - 0.2 - Y_CORNISA, 0.6)
		var base := Basis(u, Vector3.UP, u.cross(Vector3.UP))
		bloque(n, cu, Transform3D(base, m + Vector3(0, (Y_CORNISA + Y_TERRAZA - 0.2) / 2.0, 0)), tam_cornisa, blanco)
		if afuera:
			# Moldura que asoma y baranda de la terraza (con el pasamanos más ancho)
			pieza(n, Transform3D(base, m + Vector3(0, Y_TERRAZA - 0.05, 0)), Vector3(BAHIA + 0.8, 0.12, 0.8), piedra)
			pieza(n, Transform3D(base, m + Vector3(0, Y_TERRAZA + 0.22, 0)), Vector3(BAHIA + 0.2, 0.44, 0.2), blanco)
			pieza(n, Transform3D(base, m + Vector3(0, Y_TERRAZA + 0.48, 0)), Vector3(BAHIA + 0.3, 0.08, 0.3), piedra)
			solido(cu, Transform3D(base, m + Vector3(0, Y_TERRAZA + 0.26, 0)), Vector3(BAHIA + 0.3, 0.52, 0.3))
	# Faroles colgando en el medio de cada bahía del pasillo
	for k: Vector2i in GALERIA_CELDAS:
		if k.y != 1:
			continue
		var p := _vertice(k) + Vector3(BAHIA / 2.0, 0, BAHIA / 2.0)
		pieza(n, en(p + Vector3(0, Y_CORNISA + 0.1, 0)), Vector3(0.02, 0.5, 0.02), c("hierro"))
		pieza(n, en(p + Vector3(0, Y_CORNISA - 0.2, 0)), Vector3(0.24, 0.14, 0.24), c("hierro"))
		Construir.esfera(n, p + Vector3(0, Y_CORNISA - 0.33, 0), 0.12, c("luz"), Vector3.ONE, 8)


static func _vertice(v: Vector2i) -> Vector3:
	return Vector3(GALERIA_ORIGEN.x + v.x * BAHIA, 0.0, GALERIA_ORIGEN.y + v.y * BAHIA)


## Arco de medio punto entre dos columnas: "m" es el medio del lado al nivel del piso y "u" la
## dirección del lado. La rosca son 9 dovelas y las enjutas (los rincones entre el arco y la cornisa)
## se rellenan con tajadas verticales. Todo con colisión.
static func _arco(n: Node3D, cu: StaticBody3D, m: Vector3, u: Vector3, color: Color) -> void:
	const DOVELAS := 9
	var r_in := (BAHIA - COLUMNA) / 2.0
	var r_medio := r_in + ROSCA / 2.0
	var r_out := r_in + ROSCA
	var centro := m + Vector3(0, ARRANQUE + 0.15, 0)
	var cuerda := 2.0 * r_medio * sin(PI / DOVELAS / 2.0) + 0.03
	for k in DOVELAS:
		var a := PI * (k + 0.5) / DOVELAS
		var radial := u * cos(a) + Vector3.UP * sin(a)
		var tangente := -u * sin(a) + Vector3.UP * cos(a)
		var t := Transform3D(Basis(radial, tangente, radial.cross(tangente)), centro + radial * r_medio)
		bloque(n, cu, t, Vector3(ROSCA, cuerda, COLUMNA), color)
	# Enjutas: tajadas de 25 cm desde la rosca hasta la cornisa
	var base := Basis(u, Vector3.UP, u.cross(Vector3.UP))
	var tajadas := [[0.0, 0.6]]
	for q in 3:
		tajadas.append([0.6 + 0.25 * q, 0.85 + 0.25 * q])
	for s: float in [-1.0, 1.0]:
		for tj: Array in tajadas:
			var u0: float = tj[0]
			var u1: float = tj[1]
			if u0 == 0.0 and s > 0.0:
				continue   # la del medio va una sola vez (de -0,6 a 0,6)
			var abajo := centro.y + sqrt(r_out * r_out - u1 * u1) - 0.02
			var alto := Y_CORNISA - abajo
			if alto <= 0.0:
				continue
			var ancho := (u1 - u0) if u0 > 0.0 else 2.0 * u1
			var off := s * (u0 + u1) / 2.0 if u0 > 0.0 else 0.0
			bloque(n, cu, Transform3D(base, Vector3(m.x, abajo + alto / 2.0, m.z) + u * off), Vector3(ancho, alto, COLUMNA), color)


# ---------------------------------------------------------------- Mercado

## Seis puestos de feria en dos filas, con un pasillo en el medio. Cada uno tiene mesa (colisión),
## cajones atrás (colisión), toldo a rayas inclinado (colisión), parantes, faldón y mercadería
## (decorativos).
static func mercado(padre: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Mercado"
	padre.add_child(n)
	var cu := cuerpo(n, "ColisionMercado")
	for i in PUESTOS.size():
		var p: Array = PUESTOS[i]
		var t := en(p[0], Vector3(0, float(p[1]), 0))
		_puesto(n, cu, t, MERCADERIA[i % MERCADERIA.size()], TOLDOS_PUESTO[i % TOLDOS_PUESTO.size()])


static func _puesto(n: Node3D, cu: StaticBody3D, t: Transform3D, tipo: String, color_toldo: String) -> void:
	var madera := c("madera")
	var lona := c(color_toldo)
	# Mesa: tablero, mantel que cae adelante y la colisión maciza hasta el piso
	pieza(n, t * en(Vector3(0, 0.86, 0.35)), Vector3(2.2, 0.08, 0.8), madera)
	pieza(n, t * en(Vector3(0, 0.45, 0.74)), Vector3(2.2, 0.75, 0.03), lona)
	for x: float in [-1.0, 1.0]:
		pieza(n, t * en(Vector3(x, 0.41, 0.0)), Vector3(0.06, 0.82, 0.06), madera.darkened(0.2))
	solido(cu, t * en(Vector3(0, 0.45, 0.35)), Vector3(2.2, 0.9, 0.8))
	# Cajones apilados atrás
	bloque(n, cu, t * en(Vector3(0, 0.25, -0.55)), Vector3(2.0, 0.5, 0.45), madera.darkened(0.1))
	# Parantes (decorativos) y toldo inclinado hacia adelante
	for x: float in [-1.15, 1.15]:
		pieza(n, t * en(Vector3(x, 1.15, 0.92)), Vector3(0.06, 2.3, 0.06), c("hierro"))
		pieza(n, t * en(Vector3(x, 1.3, -0.82)), Vector3(0.06, 2.6, 0.06), c("hierro"))
	var caida := 0.3
	var fondo := 1.8
	var ang := atan2(caida, fondo)
	var b := Basis.from_euler(Vector3(ang, 0, 0))
	var largo := sqrt(fondo * fondo + caida * caida) + 0.1
	var centro := Vector3(0, 2.45, 0.05)
	for k in 6:
		var x := -1.2 + 0.2 + 0.4 * k
		pieza(n, t * Transform3D(b, centro + Vector3(x, 0, 0)), Vector3(0.4, 0.05, largo), lona if k % 2 == 0 else c("blanco"))
	solido(cu, t * Transform3D(b, centro - b.y * 0.075), Vector3(2.4, 0.2, largo))
	pieza(n, t * en(Vector3(0, 2.2, 0.98)), Vector3(2.4, 0.22, 0.03), lona)
	# Mercadería sobre la mesa
	match tipo:
		"frutas", "verduras":
			var colores := ["naranja", "flor_roja", "flor_amarilla"] if tipo == "frutas" else ["hoja", "flor_roja", "tierra"]
			for k in 3:
				var x := -0.7 + 0.7 * k
				pieza(n, t * en(Vector3(x, 0.96, 0.35)), Vector3(0.6, 0.12, 0.45), madera.lightened(0.15))
				for f in 6:
					var px := x - 0.18 + 0.18 * (f % 3)
					var pz := 0.25 + 0.2 * int(f / 3.0)
					Construir.esfera(n, t * Vector3(px, 1.06, pz), 0.08, c(colores[k]), Vector3.ONE, 6)
		"flores":
			for k in 5:
				var x := -0.8 + 0.4 * k
				Construir.cilindro(n, t * Vector3(x, 1.02, 0.35), 0.13, 0.25, c("metal"), false, 8)
				for f in 3:
					Construir.esfera(n, t * Vector3(x - 0.06 + 0.06 * f, 1.22 + 0.04 * (f % 2), 0.35 + 0.03 * (f - 1)), 0.08,
						c(["flor_rosa", "flor_amarilla", "flor_violeta", "flor_blanca", "flor_roja"][(k + f) % 5]), Vector3.ONE, 6)
		"ropa":
			for k in 4:
				for h in 3:
					pieza(n, t * en(Vector3(-0.75 + 0.5 * k, 0.93 + 0.06 * h, 0.35)), Vector3(0.4, 0.06, 0.35),
						c(["toldo_azul", "toldo_rojo", "blanco", "toldo_amarillo", "fachada_lila"][(k + h) % 5]))
		"libros":
			for k in 9:
				pieza(n, t * en(Vector3(-0.9 + 0.225 * k, 0.94, 0.35), Vector3(0, 0.2 * (k % 3 - 1), 0)), Vector3(0.17, 0.08, 0.24),
					c(["remate_marron", "remate_verde", "remate_azul", "letrero_crema"][k % 4]))
		_:
			for k in 6:
				var x := -0.85 + 0.34 * k
				Construir.esfera(n, t * Vector3(x, 0.98, 0.35), 0.08, c(["grafiti_cian", "naranja", "jacaranda"][k % 3]), Vector3(1, 1.4, 1), 6)
