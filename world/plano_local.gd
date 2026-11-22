class_name PlanoLocal
extends RefCounted
## Cómo se acomodan los muebles de un local de la planta baja (world/pasaje.gd), como en un local de
## verdad y no sobre la ruta en zigzag de la cinemática (que los locales no tienen):
## - El MOSTRADOR al fondo, de frente a la vidriera, con lugar atrás para el empleado (que se para ahí).
## - En el medio, lo propio del rubro bien ordenado: góndolas en FILAS (con pasillos), mesas en GRILLA,
##   puestos de fruta, sillas de espera mirando al mostrador...
## - Un pasillo libre de la puerta al mostrador (por ahí entran y salen los clientes).
## - Lámparas colgadas en fila, sobre los pasillos.
## Las paredes las llena después Pasaje._mas_adornos (estantes, heladeras, bibliotecas) y lo que queda
## arriba de todo es la ruta recta de prueba (la vidriera, el medio y la ventana de atrás).
## Todo en coordenadas de la sala (la vidriera mira a +Z).

const PASILLO := 1.3        ## Ancho de los pasillos entre filas
const BANDA_PARED := 1.0    ## Lo que queda para los muebles de las paredes
const ENTRADA := 2.2        ## Hondo libre detrás de la vidriera
const COLGANTE_Y := 4.3     ## A qué altura queda la parte de abajo de las lámparas
const SEPARACION_MOSTRADORES := 0.15   ## Aire entre dos mostradores puestos uno al lado del otro

## Por rubro: [mostrador, cuántos, pieza del medio, modo ("filas", "grilla" o ""), alto máximo de esa
## pieza, giro de la pieza del medio, lámpara].
## "filas": de punta a punta hacia el fondo, con pasillos. "grilla": sueltas, con aire alrededor.
const PLANO := {
	"supermercado": ["caja_super", 1, "gondola", "filas", 1.9, PI / 2.0, "lampara_taller"],
	"kiosco": ["caja_super", 1, "gondola", "filas", 1.6, PI / 2.0, "lampara_colgante"],
	"farmacia": ["caja_super", 2, "gondola", "filas", 1.5, PI / 2.0, "lampara_colgante"],
	"ferreteria": ["banco_trabajo", 2, "gondola", "filas", 1.9, PI / 2.0, "lampara_taller"],
	"verduleria": ["caja_super", 1, "puesto_frutas", "grilla", 1.0, 0.0, "lampara_colgante"],
	"floreria": ["caja_super", 1, "balde_flores", "grilla", 1.1, 0.0, "lampara_colgante"],
	"fiambreria": ["mostrador_quesos", 2, "barril", "grilla", 0.9, 0.0, "salames"],
	"panaderia": ["mostrador_torta", 2, "canasto_panes", "grilla", 0.7, 0.0, "lampara_colgante"],
	"libreria": ["mesa_lectura", 1, "mesa_lectura", "grilla", 1.2, 0.0, "lampara_verde"],
	"cafe": ["vitrina_tortas", 2, "mesa_cafe", "grilla", 1.0, 0.0, "lampara_colgante"],
	"heladeria": ["vitrina_helados", 2, "mesa_cafe", "grilla", 1.0, 0.0, "lampara_colgante"],
	"restaurante": ["mesada", 1, "mesa_mantel", "grilla", 1.0, 0.0, "lampara_colgante"],
	"consultorio": ["escritorio_pc", 1, "sillas_espera", "grilla", 0.95, PI, "lampara_techo"],
	"oficina": ["escritorio_pc", 1, "escritorio_pc", "grilla", 1.26, 0.0, "lampara_techo"],
	"mecanico": ["banco_trabajo", 1, "", "", 0.0, 0.0, "lampara_taller"],   # En el medio, un auto (ver _auto)
	"peluqueria": ["caja_super", 1, "", "", 0.0, 0.0, "lampara_colgante"],
}
## Aire alrededor de cada pieza de la grilla (x, z), por rubro (el resto, 1.0 x 1.0).
const AIRE := {"cafe": Vector2(1.1, 0.7), "heladeria": Vector2(1.1, 0.7), "restaurante": Vector2(1.0, 1.1),
	"consultorio": Vector2(0.6, 0.9), "oficina": Vector2(1.2, 1.3), "mecanico": Vector2(1.6, 1.4),
	"fiambreria": Vector2(1.6, 1.4), "panaderia": Vector2(1.0, 1.0), "libreria": Vector2(1.4, 1.3)}


## Arma el local. Devuelve cuántos muebles puso (los obstáculos del local).
static func armar(sala: Node3D, ce: CasaEnterable, tema: String) -> int:
	var p: Array = PLANO.get(tema, PLANO["kiosco"])
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	var cant := 0
	# --- El mostrador: al fondo, del lado de la ventana de atrás (lejos de la puerta), de frente a la
	# vidriera. El empleado queda entre el mostrador y la pared.
	var nombre_m: String = p[0]
	var tam_m: Vector3 = MueblesDatos.PIEZAS[nombre_m]["tam"]
	var cuantos: int = p[1]
	# Con aire entre mostrador y mostrador: pegados, el segundo "chocaba" con el primero (_cruzan deja
	# 0,1 m de margen) y no se ponía nunca
	var paso_m := tam_m.x + SEPARACION_MOSTRADORES
	var largo := tam_m.x * cuantos + SEPARACION_MOSTRADORES * (cuantos - 1)
	var zm := -hz + 1.4 + tam_m.z / 2.0
	var xm := clampf(ce.x_fondo, -hx + BANDA_PARED + largo / 2.0, hx - BANDA_PARED - largo / 2.0)
	for k in cuantos:
		var x := xm - largo / 2.0 + tam_m.x / 2.0 + paso_m * k
		if _pieza(sala, ce, nombre_m, Vector3(x, 0.02, zm), 0.0, 1.0):
			cant += 1
	ce.mesas.append(Vector3(xm, tam_m.y, zm))
	ce.set_meta(&"puesto_empleado", Vector3(xm, 0.04, -hz + 0.95))
	ce.set_meta(&"ancho_mostrador", largo)
	# --- Lo del medio
	var x0 := -hx + BANDA_PARED + 0.3
	var x1 := hx - BANDA_PARED - 0.3
	var z0 := zm + tam_m.z / 2.0 + PASILLO       # Delante del mostrador queda un pasillo
	var z1 := hz - 0.9
	var nombre: String = p[2]
	if nombre != "":
		var d: Dictionary = MueblesDatos.PIEZAS[nombre]
		var tam: Vector3 = d["tam"]
		var sy := minf(1.0, float(p[4]) / float(d["y1"]))
		var giro: float = p[5]
		var ancho_x := tam.z if absf(sin(giro)) > 0.5 else tam.x   # Lo que ocupa en X ya girado
		var hondo_z := tam.x if absf(sin(giro)) > 0.5 else tam.z
		if p[3] == "filas" and nombre == "gondola":
			# Góndolas de dos caras armadas acá (con su mercadería), una por fila, de punta a punta hacia
			# el fondo; ninguna en el pasillo de la puerta. Sobre cada pasillo, un cartel colgado.
			var ancho_g := 0.95
			var n_fila := 0
			var x := x0 + ancho_g / 2.0
			while x + ancho_g / 2.0 <= x1:
				if absf(x - ce.x_frente) > ancho_g / 2.0 + 0.8:
					var largo_g := minf(z1 - z0, 4.2)
					if largo_g >= 1.4 and _gondola(sala, ce, tema, Vector3(x, 0.02, (z0 + z1) / 2.0), largo_g, float(p[4]), n_fila):
						cant += 1
						n_fila += 1
				x += ancho_g + PASILLO
		elif p[3] == "filas":
			# Filas hacia el fondo, separadas por pasillos; ninguna en el pasillo de la puerta
			var x := x0 + ancho_x / 2.0
			while x + ancho_x / 2.0 <= x1:
				if absf(x - ce.x_frente) > ancho_x / 2.0 + 0.8:
					var z := z1 - hondo_z / 2.0
					while z - hondo_z / 2.0 >= z0:
						if _pieza(sala, ce, nombre, Vector3(x, 0.02, z), giro, 1.0, sy):
							cant += 1
						z -= hondo_z
				x += ancho_x + PASILLO
		else:
			var aire: Vector2 = AIRE.get(tema, Vector2(1.0, 1.0))
			var px := ancho_x + aire.x
			var pz := hondo_z + aire.y
			var nx := maxi(1, int(floor((x1 - x0 + aire.x) / px)))
			var nz := maxi(1, int(floor((z1 - z0 + aire.y) / pz)))
			var cx := (x0 + x1) / 2.0
			var cz := (z0 + z1) / 2.0
			for i in nx:
				for j in nz:
					var c := Vector3(cx + (i - (nx - 1) / 2.0) * px, 0.02, cz + (j - (nz - 1) / 2.0) * pz)
					if absf(c.x - ce.x_frente) < ancho_x / 2.0 + 0.7:
						continue   # El pasillo de la puerta al mostrador
					if _pieza(sala, ce, nombre, c, giro, 1.0, sy):
						cant += 1
	# --- La peluquería: espejos en la pared izquierda, cada uno con su sillón mirándolo
	if tema == "peluqueria":
		var z := hz - ENTRADA - 0.6
		while z > zm + 0.2:
			var ok := _pieza(sala, ce, "tocador_espejo", Vector3(-hx + 0.34, 0.02, z), PI / 2.0, 1.0, 2.3 / 2.85)
			if ok:
				cant += 1
				if _pieza(sala, ce, "sillon_peluqueria", Vector3(-hx + 1.4, 0.02, z), -PI / 2.0, 1.0):
					cant += 1
			z -= 1.6
	# --- El taller: un auto en el medio, con dos pilas de neumáticos al lado
	if tema == "mecanico":
		# (un taller deja el auto cerca del portón: puede llegar hasta casi la vidriera)
		if _auto(sala, ce, x0, x1, z0 - 0.5, hz - 0.3):
			cant += 1
	# --- Un felpudo en la entrada, del color del local
	var hz_f := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	Construir.caja(sala, Vector3(ce.x_frente, 0.045, hz_f - 0.55), Vector3(1.6, 0.012, 0.8),
		Color(MERCADERIA.get(tema, ["8a5a35"])[0]).darkened(0.45), false)
	# --- Las lámparas, en fila sobre el pasillo de la puerta y sobre el mostrador
	var lampara: String = p[6]
	var dl: Dictionary = MueblesDatos.PIEZAS[lampara]
	var y_l := COLGANTE_Y - float(dl["y0"])
	if lampara == "salames":
		for k in cuantos:
			Kit.colocar(sala, "salames", Vector3(xm - largo / 2.0 + tam_m.x / 2.0 + paso_m * k, 3.4, zm), 0.0)
			cant += 1
		lampara = "lampara_colgante"
		dl = MueblesDatos.PIEZAS[lampara]
		y_l = COLGANTE_Y - float(dl["y0"])
	Kit.colocar(sala, lampara, Vector3(xm, y_l, zm), 0.0)
	_cordon(sala, Vector3(xm, y_l + float(dl["y1"]), zm))
	var zl := hz - 1.6
	while zl > z0:
		for x in [ce.x_frente, (ce.x_frente + hx) / 2.0 + 0.6]:
			Kit.colocar(sala, lampara, Vector3(x, y_l, zl), 0.0)
			_cordon(sala, Vector3(x, y_l + float(dl["y1"]), zl))
			cant += 1
		zl -= 2.6
	return cant


## Pone una pieza con su colisión y la anota en las cajas del local (para la gente y los adornos).
## "sy" achica sólo la altura (una góndola de 3,6 m queda de 1,9). No la pone si se mete en otra
## cosa, se sale del cuarto o tapa la entrada.
static func _pieza(sala: Node3D, ce: CasaEnterable, nombre: String, pos: Vector3, giro: float, s := 1.0,
		sy := 1.0) -> bool:
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	var tam: Vector3 = d["tam"] * Vector3(s, s * sy, s)
	var e := tam / 2.0
	var c := Vector3(pos.x, pos.y + e.y, pos.z)
	var m := _medio_aabb(e, giro)
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	var en_puerta := absf(c.x - ce.x_frente) < CasaEnterable.VENTANA_ANCHO / 2.0 + m.x + 0.2 and c.z + m.y > hz - 1.6
	if not Pasaje._en_cuarto(ce, c, e, giro) or en_puerta:
		return false
	for caja: Array in ce.cajas:
		var c2: Vector3 = caja[0]
		var e2: Vector3 = caja[1]
		if c2.y - e2.y > 1.9:
			continue
		if _cruzan(c, e, giro, c2, e2, float(caja[2])):
			return false
	var origen := pos - Vector3(0, float(d["y0"]) * s * sy, 0)
	Kit.colocar(sala, nombre, origen, giro, Vector3(s, s * sy, s))
	var forma := BoxShape3D.new()
	forma.size = tam
	var c_col := c
	# Si es un mueble donde se apoyan cosas (mesa, mostrador...), la colisión llega hasta su tapa y no
	# hasta lo más alto del mueble (las sillas, una caja registradora): así lo que se apoya no queda
	# metido adentro de la colisión, y la paloma se posa sobre la tapa de verdad
	var t_mueble := Transform3D(Basis.from_euler(Vector3(0, giro, 0)) * Basis.from_scale(Vector3(s, s * sy, s)), origen)
	if nombre in APOYOS:
		var ap := apoyos_de(nombre)
		if not (ap["puntos"] as Array).is_empty():
			var tapa := (t_mueble * Vector3(0, float(ap["altura"]), 0)).y
			if tapa < c.y + e.y - 0.03:
				forma.size.y = tapa - pos.y
				c_col = Vector3(c.x, pos.y + forma.size.y / 2.0, c.z)
			var lista: Array = ce.get_meta(&"apoyos", [])
			lista.append([nombre, t_mueble])
			ce.set_meta(&"apoyos", lista)
	Construir.colision(sala, c_col, forma, Vector3(0, giro, 0))
	ce.cajas.append([c, e, giro])
	return true


# ---------------------------------------------------------------- Cosas para tirar de un aletazo

## Muebles de los locales donde se apoyan cosas (ver objetos()).
const APOYOS := ["mesa_cafe", "mesa_mantel", "mesa_lectura", "puesto_frutas", "mostrador_quesos", "mostrador_torta",
	"vitrina_tortas", "vitrina_helados", "caja_super", "banco_trabajo", "escritorio_pc", "mesada", "barril"]
## Qué cosas hay sobre los mostradores y las mesas de cada rubro (Golpeable.TIPOS) y de qué colores.
const OBJETOS := {
	"supermercado": [["lata", "botella", "caja"], ["c8423a", "f2c23a", "3a7fd0", "4fa060", "e8823a"]],
	"kiosco": [["caja", "lata", "botella"], ["e0403a", "f2c23a", "3a7fd0", "e86aa0", "8ad08a"]],
	"farmacia": [["frasco", "caja"], ["f4f4f4", "bfe4f4", "f2d6e2", "3f9a5a"]],
	"ferreteria": [["lata", "caja"], ["c0c4c8", "d8a03a", "c8423a", "3a6fc0"]],
	"verduleria": [["fruta"], ["d8402e", "f0a030", "f2d23a", "6fae3a"]],
	"floreria": [["florero"], ["4a6fd0", "e06a9a", "f4f1e8"]],
	"fiambreria": [["queso", "botella"], ["f2d070", "e8c060", "7a2a3a"]],
	"panaderia": [["pan"], ["c98a4a", "b8743a", "d8a060"]],
	"libreria": [["libro"], ["2f5a8a", "8a2f3a", "4f7a3a", "d8b04a", "6b4a8a"]],
	"cafe": [["taza", "vaso", "azucarera"], []],
	"heladeria": [["vaso", "taza"], ["f6d6e2", "b8e0c8", "f4e4a8"]],
	"restaurante": [["vaso", "botella", "florero"], ["7a2a3a", "2f4a2a"]],
	"consultorio": [["frasco", "florero"], ["f4f4f4", "bfe4f4"]],
	"oficina": [["taza", "libro", "florero"], ["2f5a8a", "f4f1e8"]],
	"mecanico": [["lata"], ["c8423a", "2f3036", "d8a03a"]],
	"peluqueria": [["frasco", "botella"], ["e06a9a", "f4f4f4", "6aa8e0"]],
	# Ambientes de los departamentos (PlanoCasa.APOYOS): casi todo de vidrio o loza, que se rompe
	"living": [["taza", "vaso", "florero", "libro"], []],
	"comedor": [["plato", "plato", "vaso", "florero", "botella"], []],
	"cocina": [["plato", "taza", "frasco", "botella", "fruta"], []],
	"dormitorio": [["florero", "vaso", "libro"], []],
	"bano": [["frasco", "botella"], ["f4f4f4", "bfe4f4", "e06a9a"]],
	"cuarto_chicos": [["vaso", "libro", "caja"], ["3a7fd0", "e0403a", "f2c23a", "4fa060"]],
	"estudio": [["taza", "libro", "florero"], []],
	"conventillo": [["taza", "florero", "frasco"], []],
}
const MAX_OBJETOS := 10    ## Cuántas cosas para tirar, como mucho, por local
const POR_MUEBLE := 2      ## Y por mueble
const RANGO_OBJETOS := 26.0   ## Desde más lejos no se distinguen (y adentro de un local casi no se ven desde la calle)

static var _apoyos := {}


## Dónde se puede apoyar algo sobre un mueble: los puntos planos y mirando para arriba que se ven desde
## arriba (la tapa de la mesa, el mostrador), medidos con rayos sobre la malla del mueble. En
## coordenadas de la malla: {"altura": la de la tapa, "puntos": [Vector3...]} (vacío si no tiene).
static func apoyos_de(nombre: String) -> Dictionary:
	if _apoyos.has(nombre):
		return _apoyos[nombre]
	var res := {"altura": 0.0, "puntos": []}
	_apoyos[nombre] = res
	var malla := Kit.malla(nombre)
	if malla == null:
		return res
	var tm := malla.generate_triangle_mesh()
	var d: Dictionary = MueblesDatos.PIEZAS[nombre]
	var tam: Vector3 = d["tam"]
	var arriba := float(d["y1"]) + 0.5
	var hits: Array[Vector3] = []
	var n := 9
	for i in n:
		for j in n:
			var x := (float(i) / (n - 1) - 0.5) * tam.x * 0.8
			var z := (float(j) / (n - 1) - 0.5) * tam.z * 0.8
			var r := tm.intersect_ray(Vector3(x, arriba, z), Vector3.DOWN)
			if r.is_empty():
				continue
			var p: Vector3 = r["position"]
			var nor: Vector3 = r["normal"]
			if absf(nor.y) > 0.95 and p.y > 0.45 and p.y < 1.3:
				hits.append(p)
	if hits.is_empty():
		return res
	# La tapa: la altura (de a 2 cm) donde más rayos pegan; se apoya ahí y en nada más
	var votos := {}
	for p in hits:
		var k := roundi(p.y / 0.02)
		votos[k] = int(votos.get(k, 0)) + 1
	var mejor := 0
	var mejor_votos := 0
	for k: int in votos:
		if int(votos[k]) > mejor_votos:
			mejor_votos = votos[k]
			mejor = k
	var altura := mejor * 0.02
	var puntos: Array = []
	for p in hits:
		if absf(p.y - altura) < 0.025:
			puntos.append(p)
	res["altura"] = altura
	res["puntos"] = puntos
	return res


## Pone cosas que la paloma puede tirar de un aletazo (Golpeable) sobre los mostradores y las mesas del
## local, de lo que vende cada rubro: latas y botellas en el súper, fruta en la verdulería, libros en la
## librería, tazas en el café... Vuelven a su lugar a los 40 s (Golpeable).
static func objetos(sala: Node3D, ce: CasaEnterable, tema: String) -> int:
	var o: Array = OBJETOS.get(tema, [["caja"], []])
	var tipos: Array = o[0]
	var colores: Array = o[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ce.nombre) + 17
	var puestos := 0
	var apoyos: Array = ce.get_meta(&"apoyos", [])
	# Con pocos muebles (un solo mostrador) van más cosas en cada uno
	var por_mueble := clampi(ceili(6.0 / maxf(apoyos.size(), 1.0)), POR_MUEBLE, 4)
	for a: Array in apoyos:
		if puestos >= MAX_OBJETOS:
			break
		var puntos: Array = (apoyos_de(a[0])["puntos"] as Array).duplicate()
		var t: Transform3D = a[1]
		var elegidos: Array[Vector3] = []
		while not puntos.is_empty() and elegidos.size() < por_mueble:
			var p: Vector3 = puntos.pop_at(rng.randi_range(0, puntos.size() - 1))
			var lejos := true
			for q in elegidos:
				if Vector2(p.x - q.x, p.z - q.z).length() < 0.3:
					lejos = false
			if lejos:
				elegidos.append(p)
		for p in elegidos:
			if puestos >= MAX_OBJETOS:
				break
			var tipo: String = tipos[rng.randi_range(0, tipos.size() - 1)]
			var color := Color.WHITE if colores.is_empty() else Color(colores[rng.randi_range(0, colores.size() - 1)])
			var g := Golpeable.crear(sala, tipo, sala.to_global(t * p) + Vector3.UP * 0.003, color, 1.0, false, null,
				RANGO_OBJETOS)
			g.rotation.y = rng.randf() * TAU
			g.fijar_origen()
			puestos += 1
	ce.set_meta(&"objetos", puestos)
	return puestos


## ¿Se tocan dos cajas giradas en Y? (con sus rectángulos de planta, aproximados por los que las
## contienen alineados a los ejes, y un margen de 0,1 m)
static func _cruzan(c1: Vector3, e1: Vector3, g1: float, c2: Vector3, e2: Vector3, g2: float) -> bool:
	var a1 := _medio_aabb(e1, g1)
	var a2 := _medio_aabb(e2, g2)
	return absf(c1.x - c2.x) < a1.x + a2.x + 0.1 and absf(c1.z - c2.z) < a1.y + a2.y + 0.1


static func _medio_aabb(e: Vector3, giro: float) -> Vector2:
	var cs := absf(cos(giro))
	var sn := absf(sin(giro))
	return Vector2(e.x * cs + e.z * sn, e.x * sn + e.z * cs)


static func _cordon(sala: Node3D, desde: Vector3) -> void:
	var largo := Pasaje.PLANTA_BAJA - desde.y
	if largo > 0.05:
		Construir.cilindro(sala, desde + Vector3(0, largo / 2.0, 0), 0.02, largo, Color("2a2a2a"), false, 4)


## Colores de la mercadería de las góndolas, por rubro (cada tramo de cada estante, uno de estos).
const MERCADERIA := {
	"supermercado": ["c8423a", "f2c23a", "3a7fd0", "4fa060", "f4f1e8", "e8823a", "8a5a35"],
	"kiosco": ["e0403a", "f2c23a", "3a7fd0", "e86aa0", "8ad08a", "f4f1e8"],
	"farmacia": ["f4f4f4", "3f9a5a", "3a6fc0", "e0403a", "bfe4f4", "f2d6e2"],
	"ferreteria": ["c0c4c8", "d8a03a", "c8423a", "3a6fc0", "2f3036", "4fa060"],
}
## El color de la estructura de la góndola y de sus puntas (con el cartel de ofertas), por rubro.
const GONDOLA := {"supermercado": ["e9ebe6", "3f9a5a"], "kiosco": ["f1ead8", "c8423a"],
	"farmacia": ["f4f6f4", "3f9a5a"], "ferreteria": ["8a8f95", "d8a03a"]}


## Una góndola de dos caras, de "largo" metros hacia el fondo y "alto" de alto, centrada en "c": zócalo,
## panel del medio, cuatro estantes por lado con la mercadería (cada tramo de 0,5 m, un producto) y las
## puntas pintadas. Arriba del pasillo que tiene a la derecha, un cartel colgado con el número.
## Una sola colisión para toda la góndola. Devuelve false si no entra.
static func _gondola(sala: Node3D, ce: CasaEnterable, tema: String, c: Vector3, largo: float, alto: float,
		n: int) -> bool:
	var ancho := 0.95
	var e := Vector3(ancho / 2.0, alto / 2.0, largo / 2.0)
	var centro := c + Vector3(0, e.y, 0)
	for caja: Array in ce.cajas:
		var c2: Vector3 = caja[0]
		var e2: Vector3 = caja[1]
		if c2.y - e2.y <= 1.9 and _cruzan(centro, e, 0.0, c2, e2, float(caja[2])):
			return false
	if not Pasaje._en_cuarto(ce, centro, e, 0.0):
		return false
	var colores: Array = MERCADERIA.get(tema, MERCADERIA["supermercado"])
	var g: Array = GONDOLA.get(tema, GONDOLA["supermercado"])
	var estructura := Color(g[0])
	var punta := Color(g[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ce.nombre) + n * 31
	Construir.caja(sala, c + Vector3(0, 0.07, 0), Vector3(ancho, 0.14, largo), estructura.darkened(0.45), false)
	Construir.caja(sala, c + Vector3(0, alto / 2.0, 0), Vector3(0.06, alto, largo), estructura, false)
	for s in [-1.0, 1.0]:
		Construir.caja(sala, c + Vector3(0, alto / 2.0, s * (largo / 2.0 - 0.02)), Vector3(ancho, alto, 0.04), punta, false)
		Construir.caja(sala, c + Vector3(0, alto - 0.18, s * (largo / 2.0 + 0.01)), Vector3(ancho * 0.8, 0.22, 0.02),
			Color.WHITE, false)   # El cartelito de la punta
	var niveles := 4
	var paso := (alto - 0.3) / niveles
	var tramos := maxi(1, int(round(largo / 0.5)))
	var lt := (largo - 0.08) / tramos
	for lado in [-1.0, 1.0]:
		for k in niveles:
			var y := 0.16 + k * paso
			Construir.caja(sala, c + Vector3(lado * 0.24, y, 0), Vector3(0.42, 0.03, largo - 0.08), estructura.darkened(0.12), false)
			for i in tramos:
				if rng.randf() < 0.06:
					continue   # Un hueco: se lo llevaron
				var col := Color(colores[rng.randi_range(0, colores.size() - 1)])
				var h := paso * rng.randf_range(0.45, 0.75)
				var z := -largo / 2.0 + 0.04 + lt * (i + 0.5)
				Construir.caja(sala, c + Vector3(lado * 0.25, y + 0.015 + h / 2.0, z), Vector3(0.32, h, lt - 0.05), col, false)
	var forma := BoxShape3D.new()
	forma.size = e * 2.0
	Construir.colision(sala, centro, forma)
	ce.cajas.append([centro, e, 0.0])
	# El cartel del pasillo, colgado del techo sobre el pasillo de la derecha
	var xp := c.x + ancho / 2.0 + PASILLO / 2.0
	if xp < ce.ancho / 2.0 - CasaEnterable.ESPESOR - 0.8:
		var yc := 3.0
		Construir.caja(sala, Vector3(xp, yc, c.z), Vector3(0.05, 0.45, 1.1), punta, false)
		for lado in [-1.0, 1.0]:
			var l := Construir.cartel(sala, Vector3(xp + lado * 0.03, yc, c.z), "PASILLO %d" % (n + 1), Color.WHITE, 30)
			l.rotation.y = lado * PI / 2.0
			l.outline_size = 0
		Construir.cilindro(sala, Vector3(xp, (yc + 0.22 + Pasaje.PLANTA_BAJA) / 2.0, c.z), 0.015,
			Pasaje.PLANTA_BAJA - yc - 0.22, Color("2a2a2a"), false, 4)
	return true


## Un auto en el medio del taller (del kit de la ciudad, con sus ruedas), a lo largo si entra y si no
## de costado, lejos del pasillo de la puerta. Con colisión. Devuelve false si no entra.
static func _auto(sala: Node3D, ce: CasaEnterable, x0: float, x1: float, z0: float, z1: float) -> bool:
	var modelo := "auto_hatch_rojo"
	var d: Dictionary = KitDatos.PIEZAS[modelo]
	var mn: Array = d["min"]
	var mx: Array = d["max"]
	var largo0 := float(mx[0]) - float(mn[0])
	# Si el local es corto, un auto un poco más chico (hasta el 80 %)
	var s := clampf((z1 - z0) / largo0, 0.8, 1.0)
	var largo := largo0 * s
	var ancho := (float(mx[2]) - float(mn[2])) * s
	# Del lado de la ventana de atrás (lejos de la puerta)
	for giro in [PI / 2.0, 0.0]:
		var ex := ancho / 2.0 if giro != 0.0 else largo / 2.0
		var ez := largo / 2.0 if giro != 0.0 else ancho / 2.0
		var lo := maxf(x0 + ex, ce.x_frente + CasaEnterable.VENTANA_ANCHO / 2.0 + ex + 0.3)
		if lo > x1 - ex or z1 - z0 < ez * 2.0:
			continue
		var c := Vector3((lo + x1 - ex) / 2.0, 0.02, (z0 + z1) / 2.0)
		var e := Vector3(largo / 2.0, 0.75 * s, ancho / 2.0)
		var centro := c + Vector3(0, 0.75 * s, 0)
		var libre := true
		for caja: Array in ce.cajas:
			var c2: Vector3 = caja[0]
			var e2: Vector3 = caja[1]
			if c2.y - e2.y <= 1.9 and _cruzan(centro, e, giro, c2, e2, float(caja[2])):
				libre = false
		if not libre or not Pasaje._en_cuarto(ce, centro, e, giro):
			continue
		var t := Transform3D(Basis(Vector3.UP, giro).scaled(Vector3.ONE * s), c)
		Kit.colocar(sala, modelo, c, giro, Vector3.ONE * s)
		for r: Array in d["ruedas"]:
			Kit.colocar(sala, "rueda_auto", t * Vector3(r[0], r[1], r[2]), giro, Vector3.ONE * s)
		var forma := BoxShape3D.new()
		forma.size = e * 2.0
		Construir.colision(sala, centro, forma, Vector3(0, giro, 0))
		ce.cajas.append([centro, e, giro])
		return true
	return false
