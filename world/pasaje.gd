class_name Pasaje
extends RefCounted
## Arma un "pasaje": una casa porteña con la planta baja hueca, una ventana abierta adelante (a la
## plaza) y otra atrás (al callejón), y adentro un escenario con obstáculos que la paloma esquiva en
## la cinemática de world/casa_enterable.gd. Hay 5 escenarios (librería, panadería, conventillo,
## oficina y fiambrería), cada uno con su ruta en zigzag, sus alturas y sus obstáculos.
##
## Los obstáculos se ubican SOBRE la ruta real (la misma curva que recorre la cinemática):
## - "costado": en cada vuelta del zigzag, del lado de adentro (la paloma lo rodea).
## - "arriba": colgado del techo justo encima de la ruta (pasa por abajo).
## - "abajo": una mesa o mostrador justo debajo (pasa por arriba).
## - "entre": las dos cosas a la vez (pasa por el medio): ahí va la cámara lenta.
## Cada uno se valida contra la ruta (en los dos sentidos): si queda a menos de MARGEN, se corre o se
## achica, y si no entra, no se pone. Así ninguna ruta choca nunca (lo confirma tests/test_casas.gd).
## La fachada mira a +Z.

const C_MARCO := Color("e9e2d2")
const C_BLANCO := Color("f4f1e8")
const C_VENTANA := Color("3b4250")
const C_MADERA := Color("8a5a35")
const C_METAL := Color("3f4a45")
const C_ORO := Color("d8b04a")
const PLANTA_BAJA := 6.0   ## Alto del cuarto (arriba es macizo)
const MARGEN := 0.45       ## Distancia mínima entre la ruta y cualquier obstáculo

## Cada escenario: alturas de las vueltas del zigzag (una por vuelta), amplitud del zigzag
## (fracción de la profundidad), qué va entre vuelta y vuelta, y los colores del cuarto.
const ESCENARIOS := {
	"libreria": {"alturas": [2.2, 2.9, 2.0, 2.8], "amp": 0.45, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("8a5a35"), "pared": Color("efe4c8"), "cartel": "SILENCIO, POR FAVOR"},
	"panaderia": {"alturas": [2.9, 1.9, 2.8], "amp": 0.32, "medios": ["entre", "arriba"],
		"piso": Color("d8cbb0"), "pared": Color("f3e3c3"), "cartel": "PAN CALIENTE"},
	"conventillo": {"alturas": [2.0, 2.9, 2.1], "amp": 0.32, "medios": ["arriba", "entre"],
		"piso": Color("7c5a3e"), "pared": Color("c9e0d0"), "cartel": "CASA DE DOÑA MARTA"},
	"oficina": {"alturas": [2.6, 1.9, 2.8, 2.0], "amp": 0.45, "medios": ["abajo", "entre", "arriba"],
		"piso": Color("8f969c"), "pared": Color("e6eaee"), "cartel": "ATENCIÓN AL CLIENTE"},
	"fiambreria": {"alturas": [2.0, 2.8, 1.9, 2.7], "amp": 0.4, "medios": ["arriba", "entre", "abajo"],
		"piso": Color("b9b3a6"), "pared": Color("f1ead8"), "cartel": "FIAMBRES Y QUESOS"},
}


## Crea el pasaje y devuelve el nodo que dispara la cinemática.
## "lado_callejon": hacia dónde dobla la paloma al salir por atrás (+1 = este, -1 = oeste).
## "color_remate": el borde de color de la azotea y las cornisas (estilo del mapa V3).
static func crear(padre: Node3D, base: Vector3, tam: Vector3, color: Color, nombre: String,
		color_postigo: Color, lado_callejon: float, textos: Array, tema: String,
		color_remate := C_BLANCO) -> CasaEnterable:
	var w := tam.x
	var h := tam.y
	var d := tam.z
	var esp := CasaEnterable.ESPESOR
	var pb := PLANTA_BAJA
	var esc: Dictionary = ESCENARIOS[tema]
	var pared_int: Color = esc["pared"]
	var casa := Node3D.new()
	casa.name = "Pasaje_" + nombre.replace(" ", "_")
	padre.add_child(casa)
	casa.position = base

	# --- El nodo de la cinemática (con la ruta, que los obstáculos necesitan)
	var ce := CasaEnterable.new()
	ce.name = "Entrada_" + nombre.replace(" ", "_")
	ce.ancho = w
	ce.fondo = d
	ce.x_frente = -w * 0.28
	ce.x_fondo = w * 0.28
	ce.lado_callejon = lado_callejon
	ce.ruta = ruta_zigzag(w, d, ce.x_frente, ce.x_fondo, esc["alturas"], esc["amp"])
	for t in textos:
		ce.textos.append(str(t))

	# --- Cáscara: piso, costados, fachada y contrafachada con ventana, piso de arriba macizo
	Construir.caja(casa, Vector3(0, -0.13, 0), Vector3(w - 2 * esp, 0.3, d - 2 * esp), esc["piso"])
	for sx in [-1.0, 1.0]:
		Construir.caja(casa, Vector3(sx * (w / 2.0 - esp / 2.0), pb / 2.0, 0), Vector3(esp, pb, d - 2 * esp), color)
		Construir.caja(casa, Vector3(sx * (w / 2.0 - esp - 0.01), pb / 2.0, 0), Vector3(0.02, pb, d - 2 * esp), pared_int, false)
	_pared_con_ventana(casa, w, d / 2.0 - esp / 2.0, ce.x_frente, 1.0, color, pared_int)
	_pared_con_ventana(casa, w, -d / 2.0 + esp / 2.0, ce.x_fondo, -1.0, color, pared_int)
	Construir.caja(casa, Vector3(0, (pb + h) / 2.0, 0), Vector3(w, h - pb, d), color)
	Construir.caja(casa, Vector3(0, pb - 0.01, 0), Vector3(w - 2 * esp, 0.02, d - 2 * esp), C_BLANCO, false)

	# --- Exterior: marcos y postigos, cornisas, ventanas de adorno y cartel
	_marco_ventana(casa, ce.x_frente, d / 2.0, 1.0, color_postigo)
	_marco_ventana(casa, ce.x_fondo, -d / 2.0, -1.0, color_postigo)
	for e in [1.0, -1.0]:
		Construir.caja(casa, Vector3(0, pb + 0.15, e * (d / 2.0 + 0.2)), Vector3(w + 0.2, 0.3, 0.6), color_remate)
		var n_col := maxi(int(w / 3.0), 1)
		var filas: Array[float] = []
		if h - pb >= 3.2:
			filas.append(pb + 1.8)
		if h - pb >= 6.0:
			filas.append(pb + 4.6)
		for y in filas:
			for c in n_col:
				var off := (c - (n_col - 1) / 2.0) * (w / n_col)
				Construir.caja(casa, Vector3(off, y, e * (d / 2.0 + 0.03)), Vector3(1.1, 1.6, 0.12), C_VENTANA, false)
	# Azotea gris con el borde de color (para posarse) y un aire acondicionado, como Edificios.edificio
	Construir.caja(casa, Vector3(0, h + 0.05, 0), Vector3(w, 0.1, d), Edificios.C_TECHO)
	const B := 0.55
	for s in [-1.0, 1.0]:
		Construir.caja(casa, Vector3(0, h + 0.35, s * (d / 2.0 + 0.5 - B / 2.0)), Vector3(w + 1.0, 0.7, B), color_remate)
		Construir.caja(casa, Vector3(s * (w / 2.0 + 0.5 - B / 2.0), h + 0.35, 0), Vector3(B, 0.7, d), color_remate)
	Construir.caja(casa, Vector3(w / 2.0 - 2.2, h + 0.5, -d / 4.0), Vector3(1.5, 0.8, 1.0), Color("e8eaea"))
	for dx in [-0.38, 0.38]:
		Construir.cilindro(casa, Vector3(w / 2.0 - 2.2 + dx, h + 0.92, -d / 4.0), 0.32, 0.04, Color("5f666b"), false, 10)
	Construir.letrero(casa, Vector3(w * 0.12, 4.75, d / 2.0 + 0.12), nombre, Color.WHITE, color_postigo.darkened(0.4), 44,
		Vector2(minf(w * 0.5, 7.0), 0.6))

	# --- Adentro: obstáculos sobre la ruta, adornos y luz
	ce.obstaculos = _obstaculos(casa, ce, tema)
	ce.luz = _adornos(casa, tema, w, d, ce.x_frente, ce.x_fondo, esc["cartel"])
	padre.add_child(ce)
	ce.position = base
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
					_poner(casa, tema, "costado", c, e, giro, i)
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
					_poner(casa, tema, "arriba", c, e, giro, k)
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
					_poner(casa, tema, "abajo", c, e, giro, k)
					cant += 1
					break
	return cant


## Arma un obstáculo: la colisión es la caja (c, e, giro) y el dibujo, según el tema, va adentro.
static func _poner(casa: Node3D, tema: String, tipo: String, c: Vector3, e: Vector3, giro: float, i: int) -> void:
	var forma := BoxShape3D.new()
	forma.size = e * 2.0
	Construir.colision(casa, c, forma, Vector3(0, giro, 0))
	var o := Node3D.new()
	casa.add_child(o)
	o.position = c
	o.rotation.y = giro
	match tipo:
		"costado": _dibujar_costado(o, tema, e, i)
		"arriba":
			# El cordón hasta el techo
			var largo := PLANTA_BAJA - (c.y + e.y)
			Construir.cilindro(o, Vector3(0, e.y + largo / 2.0, 0), 0.02, largo, Color("2a2a2a"), false, 4)
			_dibujar_arriba(o, tema, e, i)
		"abajo": _dibujar_abajo(o, tema, e, i)


# ---------------------------------------------------------------- Dibujos de los obstáculos (locales, dentro de ±e)

static func _caja(o: Node3D, pos: Vector3, tam: Vector3, color: Color) -> void:
	Construir.caja(o, pos, tam, color, false)


static func _dibujar_costado(o: Node3D, tema: String, e: Vector3, i: int) -> void:
	var colores := [Color("b8423a"), Color("2b4f8a"), Color("d9b44a"), Color("4f8f45"), Color("8a4f9a")]
	match tema:
		"libreria":   # Biblioteca de dos caras llena de libros
			_caja(o, Vector3.ZERO, e * 2.0, C_MADERA)
			var y := -e.y + 0.5
			var fila := 0
			while y < e.y - 0.25:
				for lado in [-1.0, 1.0]:
					_caja(o, Vector3(0, y, lado * (e.z + 0.012)), Vector3(e.x * 2.0 - 0.12, 0.34, 0.025), colores[(fila + i) % colores.size()])
				y += 0.62
				fila += 1
		"panaderia":   # Estantería de metal con panes
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_caja(o, Vector3(sx * (e.x - 0.03), 0, sz * (e.z - 0.03)), Vector3(0.05, e.y * 2.0, 0.05), C_METAL)
			var y := -e.y + 0.4
			while y < e.y - 0.1:
				_caja(o, Vector3(0, y, 0), Vector3(e.x * 2.0, 0.04, e.z * 2.0), Color("c8ccd0"))
				for k in 3:
					var pan := Construir.esfera(o, Vector3((k - 1) * e.x * 0.6, y + 0.1, 0), 0.12, Color("c98a3a"), Vector3(1.6, 0.7, 1.0), 8)
					pan.rotation.y = 0.3 * k
				y += 0.7
		"conventillo":   # Torre de macetas con plantas
			_caja(o, Vector3.ZERO, Vector3(0.08, e.y * 2.0, 0.08), C_METAL)
			var y := -e.y + 0.6
			var k := 0
			while y < e.y:
				var dx: float = (0.18 if k % 2 == 0 else -0.18) * minf(e.x / 0.5, 1.0)
				Construir.cilindro(o, Vector3(dx, y, 0), 0.16, 0.24, Color("b5532f"), false, 8, 0.2)
				Construir.esfera(o, Vector3(dx, y + 0.25, 0), 0.24, Color("4f8f45").darkened(0.1 * (k % 3)), Vector3(1, 0.9, 1), 8)
				y += 0.75
				k += 1
		"oficina":   # Archivero gris o una planta alta, alternados
			if i % 2 == 0:
				_caja(o, Vector3.ZERO, e * 2.0, Color("9aa1a8"))
				var y := -e.y + 0.4
				while y < e.y - 0.2:
					for lado in [-1.0, 1.0]:
						_caja(o, Vector3(0, y, lado * (e.z + 0.006)), Vector3(e.x * 2.0 - 0.1, 0.03, 0.012), Color("6b7178"))
						_caja(o, Vector3(0, y + 0.22, lado * (e.z + 0.012)), Vector3(0.18, 0.04, 0.02), Color("d0d4d8"))
					y += 0.55
			else:
				Construir.cilindro(o, Vector3(0, -e.y + 0.3, 0), 0.3, 0.6, Color("e6e6e0"), false, 10, 0.34)
				Construir.cilindro(o, Vector3(0, 0, 0), 0.04, e.y * 1.6, Color("6b4a32"), false, 6)
				for k in 3:
					Construir.esfera(o, Vector3(0.1 * (k - 1), e.y - 0.4 - k * 0.45, 0.05 * k), 0.36 - k * 0.04, Color("3f8f4a"), Vector3(1, 0.8, 1), 8)
		"fiambreria":   # Heladera vitrina con cosas adentro
			_caja(o, Vector3.ZERO, e * 2.0, Color("f2f2ee"))
			for lado in [-1.0, 1.0]:
				_caja(o, Vector3(0, 0.2, lado * (e.z + 0.006)), Vector3(e.x * 2.0 - 0.16, e.y * 2.0 - 0.8, 0.012), Color("9fc9d8"))
				var y := -e.y + 1.0
				var k := 0
				while y < e.y - 0.5:
					_caja(o, Vector3(-e.x * 0.4 + 0.3 * (k % 3), y, lado * (e.z + 0.014)), Vector3(0.18, 0.22, 0.01), colores[(k + i) % colores.size()])
					y += 0.45
					k += 1
			_caja(o, Vector3(0, e.y - 0.25, e.z + 0.01), Vector3(e.x * 2.0, 0.3, 0.02), Color("b8423a"))


static func _dibujar_arriba(o: Node3D, tema: String, e: Vector3, i: int) -> void:
	match tema:
		"libreria":   # Lámpara de biblioteca verde
			Construir.cilindro(o, Vector3(0, 0.05, 0), e.x * 0.25, e.y * 1.4, Color("2f6b4a"), false, 10, e.x * 0.9)
			Construir.esfera(o, Vector3(0, -e.y * 0.55, 0), 0.1, Color("fff2c0"), Vector3.ONE, 8)
		"panaderia":   # Canasto colgante con panes
			Construir.cilindro(o, Vector3(0, -e.y + 0.15, 0), e.x * 0.85, 0.3, Color("c9a46a"), false, 10, e.x * 0.95)
			for k in 4:
				Construir.esfera(o, Vector3(cos(k * 1.6) * e.x * 0.45, -e.y + 0.32, sin(k * 1.6) * e.x * 0.45), 0.11, Color("c98a3a"), Vector3(1.5, 0.7, 1), 8)
			for k in 3:
				var cuerda := Construir.cilindro(o, Vector3(cos(k * 2.1) * e.x * 0.4, 0.05, sin(k * 2.1) * e.x * 0.4), 0.01, e.y * 1.4, Color("e8e4d0"), false, 4)
				cuerda.rotation.z = 0.15
		"conventillo":   # Sábana tendida en una soga
			_caja(o, Vector3(0, e.y - 0.02, 0), Vector3(e.x * 2.0, 0.02, 0.02), Color("e8e4d0"))
			var tela := [Color("f7f5ee"), Color("8fd3f0"), Color("f2a0b8"), Color("f0d04a")]
			_caja(o, Vector3(0, 0, 0), Vector3(e.x * 2.0 - 0.1, e.y * 2.0 - 0.06, 0.03), tela[i % tela.size()])
			for lado in [-1.0, 1.0]:
				_caja(o, Vector3(lado * e.x * 0.7, e.y - 0.04, 0), Vector3(0.03, 0.08, 0.05), Color("b8423a"))   # Broches
		"oficina":   # Ventilador de techo
			Construir.cilindro(o, Vector3(0, 0, 0), 0.12, e.y * 1.2, Color("d0d4d8"), false, 10)
			for k in 4:
				var pala := Construir.caja(o, Vector3(cos(k * PI / 2.0 + 0.4) * e.x * 0.5, -e.y * 0.3, sin(k * PI / 2.0 + 0.4) * e.x * 0.5),
					Vector3(e.x * 0.95, 0.03, 0.16), C_MADERA, false)
				pala.rotation.y = -(k * PI / 2.0 + 0.4)
		"fiambreria":   # Barra con salames y un jamón colgando
			_caja(o, Vector3(0, e.y - 0.04, 0), Vector3(e.x * 2.0, 0.05, 0.05), C_METAL)
			for k in 3:
				Construir.cilindro(o, Vector3((k - 1) * e.x * 0.6, 0, 0), 0.07, e.y * 1.6, Color("8e3b2e").darkened(0.08 * k), false, 8)
			var jamon := Construir.esfera(o, Vector3(0, -0.05, e.z * 0.5), 0.2, Color("b0553f"), Vector3(1, 1.5, 0.8), 8)
			jamon.rotation.x = 0.2


static func _dibujar_abajo(o: Node3D, tema: String, e: Vector3, _i: int) -> void:
	match tema:
		"libreria":   # Mesa de lectura con libros apilados
			_caja(o, Vector3(0, e.y - 0.3, 0), Vector3(e.x * 2.0, 0.06, e.z * 2.0), C_MADERA)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_caja(o, Vector3(sx * (e.x - 0.08), -0.15, sz * (e.z - 0.08)), Vector3(0.06, e.y * 2.0 - 0.3, 0.06), C_MADERA)
			var colores := [Color("b8423a"), Color("2b4f8a"), Color("d9b44a")]
			for k in 3:
				_caja(o, Vector3(0.1, e.y - 0.22 + k * 0.08, 0), Vector3(0.36 - k * 0.04, 0.07, 0.26), colores[k])
		"panaderia":   # Mostrador con una torta
			_caja(o, Vector3(0, -0.12, 0), Vector3(e.x * 2.0, e.y * 2.0 - 0.24, e.z * 2.0), Color("f2e6d0"))
			_caja(o, Vector3(0, e.y - 0.26, 0), Vector3(e.x * 2.0 + 0.04, 0.04, e.z * 2.0 + 0.04), Color("e8e4dc"))
			Construir.cilindro(o, Vector3(0, e.y - 0.12, 0), 0.22, 0.2, Color("f7d9e3"), false, 12)
			Construir.cilindro(o, Vector3(0, e.y - 0.01, 0), 0.03, 0.04, Color("b8423a"), false, 6)
		"conventillo":   # Mesa con el mate y el termo
			_caja(o, Vector3(0, e.y - 0.35, 0), Vector3(e.x * 2.0, 0.05, e.z * 2.0), Color("c96f4a"))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_caja(o, Vector3(sx * (e.x - 0.08), -0.18, sz * (e.z - 0.08)), Vector3(0.06, e.y * 2.0 - 0.35, 0.06), C_MADERA)
			Construir.cilindro(o, Vector3(0.2, e.y - 0.16, 0), 0.07, 0.32, Color("2f6b4a"), false, 8)
			Construir.esfera(o, Vector3(-0.15, e.y - 0.25, 0.05), 0.08, Color("8b5a2b"), Vector3.ONE, 8)
		"oficina":   # Escritorio con computadora
			_caja(o, Vector3(0, e.y - 0.45, 0), Vector3(e.x * 2.0, 0.05, e.z * 2.0), Color("d8c9b1"))
			for sx in [-1.0, 1.0]:
				_caja(o, Vector3(sx * (e.x - 0.05), -0.22, 0), Vector3(0.05, e.y * 2.0 - 0.45, e.z * 2.0 - 0.1), Color("9aa1a8"))
			_caja(o, Vector3(0, e.y - 0.2, -0.1), Vector3(0.5, 0.36, 0.05), Color("26262e"))     # Monitor
			_caja(o, Vector3(0, e.y - 0.2, -0.07), Vector3(0.44, 0.3, 0.01), Color("5fa8e8"))    # Pantalla
			_caja(o, Vector3(0, e.y - 0.41, 0.12), Vector3(0.4, 0.02, 0.14), Color("3a3a42"))    # Teclado
		"fiambreria":   # Mostrador refrigerado con quesos
			_caja(o, Vector3(0, -0.15, 0), Vector3(e.x * 2.0, e.y * 2.0 - 0.3, e.z * 2.0), Color("f2f2ee"))
			_caja(o, Vector3(0, e.y - 0.4, e.z - 0.02), Vector3(e.x * 2.0 - 0.1, 0.25, 0.02), Color("9fc9d8"))
			for k in 2:
				Construir.cilindro(o, Vector3((k - 0.5) * 0.5, e.y - 0.12, 0), 0.18, 0.2, Color("f0c850"), false, 12)


# ---------------------------------------------------------------- Exterior y adornos

## Pared de la planta baja con una ventana centrada en "cx" (y su lámina de pintura interior).
## "afuera" = +1 si la cara exterior mira a +Z.
static func _pared_con_ventana(casa: Node3D, w: float, z: float, cx: float, afuera: float, color: Color, pintura: Color) -> void:
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
		Construir.caja(casa, pos - Vector3(0, 0, afuera * (esp / 2.0 + 0.01)), Vector3(tam.x, tam.y, 0.02), pintura, false)


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
static func _adornos(casa: Node3D, tema: String, w: float, d: float, xf: float, xb: float, cartel: String) -> OmniLight3D:
	var esp := CasaEnterable.ESPESOR
	var colores := [Color("b8423a"), Color("2b4f8a"), Color("d9b44a"), Color("4f8f45")]
	# Estantes en las paredes de adelante y de atrás, salvo frente a las ventanas
	for lado in [-1.0, 1.0]:
		var z: float = lado * (d / 2.0 - esp - 0.16)
		var x_ventana := xf if lado > 0.0 else xb
		var x := -w / 2.0 + esp + 0.9
		while x < w / 2.0 - esp - 0.9:
			if absf(x - x_ventana) > 2.4:
				Construir.caja(casa, Vector3(x, 4.6, z), Vector3(1.4, 0.05, 0.3), C_MADERA, false)
				for k in 3:
					Construir.caja(casa, Vector3(x - 0.4 + k * 0.4, 4.78, z), Vector3(0.22, 0.3, 0.2), colores[(k + int(x)) % colores.size()], false)
			x += 2.2
	# Cuadros en los costados
	for lado in [-1.0, 1.0]:
		var xs: float = lado * (w / 2.0 - esp - 0.04)
		for k in 2:
			var zc := (k - 0.5) * d * 0.35
			Construir.caja(casa, Vector3(xs, 3.6, zc), Vector3(0.06, 0.9, 1.1), C_ORO, false)
			Construir.caja(casa, Vector3(xs - lado * 0.03, 3.6, zc), Vector3(0.06, 0.72, 0.92), colores[(k + 1) % colores.size()], false)
	# Cartel del tema, pintado en la pared izquierda
	var l := Construir.cartel(casa, Vector3(-w / 2.0 + esp + 0.03, 4.9, 0), cartel, Color("3a2a1e"), 56)
	l.rotation.y = PI / 2.0
	l.outline_size = 0
	# Un detalle propio de cada lugar, en un rincón
	match tema:
		"libreria":
			Construir.caja(casa, Vector3(0, 0.03, 0), Vector3(minf(w * 0.5, 7.0), 0.02, d * 0.5), Color("7a2e2e"), false)
		"panaderia":
			Construir.caja(casa, Vector3(w / 2.0 - esp - 0.6, 0.8, 0), Vector3(1.0, 1.6, 1.6), Color("4a4a52"), false)   # Horno
			Construir.caja(casa, Vector3(w / 2.0 - esp - 1.11, 0.9, 0), Vector3(0.02, 0.6, 1.0), Color("f08a3a"), false)
		"conventillo":
			var jaula := Construir.cilindro(casa, Vector3(w / 2.0 - esp - 0.4, 4.2, 0), 0.25, 0.5, C_ORO, false, 8)
			jaula.scale = Vector3(1, 1, 1)
			Construir.esfera(casa, Vector3(w / 2.0 - esp - 0.4, 4.12, 0), 0.1, Color("f0d04a"), Vector3.ONE, 6)   # Canario
		"oficina":
			Construir.cilindro(casa, Vector3(w / 2.0 - esp - 0.4, 0.6, 0), 0.2, 1.2, Color("d0d4d8"), false, 10)   # Dispenser
			Construir.cilindro(casa, Vector3(w / 2.0 - esp - 0.4, 1.4, 0), 0.17, 0.45, Color("8fd3f0"), false, 10)
		"fiambreria":
			Construir.cilindro(casa, Vector3(w / 2.0 - esp - 0.5, 0.45, 0), 0.4, 0.9, C_MADERA, false, 10)   # Barril
	var luz := OmniLight3D.new()
	luz.light_color = Color("ffd9a0")
	luz.light_energy = 1.2
	luz.omni_range = maxf(w, d) * 0.9
	luz.shadow_enabled = false
	casa.add_child(luz)
	luz.position = Vector3(0, PLANTA_BAJA - 1.0, 0)
	return luz
