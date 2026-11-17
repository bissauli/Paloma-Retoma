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
	"mecanico": ["banco_trabajo", 1, "pila_neumaticos", "grilla", 1.2, 0.0, "lampara_taller"],
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
	var largo := tam_m.x * cuantos
	var zm := -hz + 1.4 + tam_m.z / 2.0
	var xm := clampf(ce.x_fondo, -hx + BANDA_PARED + largo / 2.0, hx - BANDA_PARED - largo / 2.0)
	for k in cuantos:
		var x := xm - largo / 2.0 + tam_m.x * (k + 0.5)
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
		if p[3] == "filas":
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
	# --- Las lámparas, en fila sobre el pasillo de la puerta y sobre el mostrador
	var lampara: String = p[6]
	var dl: Dictionary = MueblesDatos.PIEZAS[lampara]
	var y_l := COLGANTE_Y - float(dl["y0"])
	if lampara == "salames":
		for k in cuantos:
			Kit.colocar(sala, "salames", Vector3(xm - largo / 2.0 + tam_m.x * (k + 0.5), 3.4, zm), 0.0)
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
	Kit.colocar(sala, nombre, pos - Vector3(0, float(d["y0"]) * s * sy, 0), giro, Vector3(s, s * sy, s))
	var forma := BoxShape3D.new()
	forma.size = tam
	Construir.colision(sala, c, forma, Vector3(0, giro, 0))
	ce.cajas.append([c, e, giro])
	return true


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
