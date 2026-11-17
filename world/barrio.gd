class_name Barrio
extends RefCounted
## El barrio enemigo (mapa V4.5), al sudeste: casas bajas armadas acá con cajas en vez de las piezas
## barrio_* del kit (tenían los techos de chapa flotando sobre las paredes y puertas y ventanas que eran
## parches de color). Cada casa tiene:
## - Paredes revocadas de color con zócalo, una puerta con marco, hoja, picaporte y escalón, y ventanas
##   con marco, vidrio, alféizar y reja.
## - Techo de losa con pretil de color (con tanque de agua, antena o un tendedero) o, las de una planta,
##   techo de chapa a un agua que apoya en las paredes: los costados se cierran con un hastial (triángulo)
##   y la chapa tiene alero y canaleta.
## - Algún detalle: medidor de luz, aire acondicionado, macetas, un grafiti o un balcón con macetas.
## Todo lo que la paloma puede pisar tiene colisión (paredes, losas, pretiles, chapa, alféizares,
## escalones); rejas, marcos y detalles chicos no.
## Además está la guarida de la banda de los BadJokes (ver guarida()) con sus puntos de aparición.
## Coordenadas: cada casa se arma en un marco con la fachada en z = 0 mirando a +Z y el fondo hacia -Z.

const PAREDES := ["fachada_rosa", "fachada_celeste", "fachada_amarilla", "fachada_verde", "fachada_terracota",
	"fachada_lila", "fachada_mostaza", "fachada_salmon", "fachada_menta", "fachada_cielo", "fachada_coral",
	"fachada_ocre", "ladrillo"]
const PUERTAS := ["toldo_azul", "toldo_verde", "toldo_rojo", "remate_marron", "madera", "kiosco", "remate_azul"]
const PRETILES := ["blanco", "remate_crema", "remate_verde", "remate_azul", "remate_marron", "piedra"]
const GRAFITIS := ["grafiti_rosa", "grafiti_cian", "grafiti_lima", "naranja", "plastico_amarillo"]
const TAGS := ["BJ", "BADJOKES", "PROHIBIDO\nPALOMAS", "LOS BJ", "BJ CREW", "RRR", "TITO\n+ PUPI"]

const PISO := 3.0          ## Alto de cada planta
const ZOCALO := 0.55
const VENTANA := Vector2(1.1, 1.25)
const PUERTA := Vector2(0.95, 2.1)
const ESPESOR_CHAPA := 0.06
const Y_UMBRAL := 0.34     ## Escalón de la puerta (el piso de tierra del barrio está a 17 cm)

## Cuántas cosas de cada tipo se armaron (lo miran las pruebas).
static var cuenta := {}
## Puntos de las azoteas (techo plano) en el mundo, para poner gatos.
static var azoteas: Array[Vector3] = []


static func c(nombre: String) -> Color:
	return NivelInferior.c(nombre)


static func _al_azar(lista: Array, rng: RandomNumberGenerator) -> Variant:
	return lista[rng.randi() % lista.size()]


static func reiniciar() -> void:
	cuenta.clear()
	azoteas.clear()


## Fila de casas a lo largo de "dir" desde "a" (sobre la línea de fachada), giradas "rot" (la fachada
## mira a Basis(rot) * +Z), de 5 a 9 m de ancho y "prof" de fondo.
static func fila(ci: Ciudad, a: Vector3, dir: Vector3, largo: float, rot: float, rng: RandomNumberGenerator,
		prof := 12.0) -> void:
	var d := 0.0
	while largo - d >= 4.5:
		var ancho := snappedf(rng.randf_range(5.0, 9.0), 0.5)
		if largo - d - ancho < 4.5:
			ancho = largo - d
		var pos := a + dir * (d + ancho / 2.0)
		casa(ci, Transform3D(Basis.from_euler(Vector3(0, rot, 0)), pos), ancho, prof, rng)
		d += ancho


## Una casa de "ancho" x "prof" con la fachada en el origen del marco "t".
static func casa(ci: Ciudad, t: Transform3D, ancho: float, prof: float, rng: RandomNumberGenerator) -> void:
	var n := NivelMedio.marco(ci, t)
	var pisos := 2 if rng.randf() < 0.45 else 1
	var h := PISO * pisos + 0.3
	var pared := c(_al_azar(PAREDES, rng))
	var w := ancho - 0.1      # Una rendija entre casa y casa: se ve dónde termina cada una
	# Cuerpo y zócalo
	NivelMedio.caja(n, Vector3(0, h / 2.0, -prof / 2.0), Vector3(w, h, prof), pared, true)
	NivelMedio.caja(n, Vector3(0, ZOCALO / 2.0, 0.025), Vector3(w + 0.02, ZOCALO, 0.05), pared.darkened(0.28))
	# Mancha de humedad o revoque gastado en algunas
	if rng.randf() < 0.35:
		var mx := rng.randf_range(-w / 2.0 + 0.8, w / 2.0 - 0.8)
		NivelMedio.caja(n, Vector3(mx, ZOCALO + 0.35, 0.03), Vector3(rng.randf_range(0.8, 1.6), 0.5, 0.02), pared.darkened(0.12))
	# Puerta a un costado y ventanas en el resto
	var lado := -1.0 if rng.randf() < 0.5 else 1.0
	var x_puerta := lado * (w / 2.0 - 1.0)
	_puerta(n, x_puerta, c(_al_azar(PUERTAS, rng)), rng)
	var libre := Vector2(-w / 2.0 + 0.4, w / 2.0 - 0.4)   # Tramo de la fachada sin la puerta
	if lado < 0.0:
		libre.x = x_puerta + PUERTA.x / 2.0 + 0.5
	else:
		libre.y = x_puerta - PUERTA.x / 2.0 - 0.5
	var y_ventana := 1.0 + VENTANA.y / 2.0
	for x in _repartir(libre, 2.2):
		_ventana(n, x, y_ventana, rng)
	if pisos == 2:
		var y2 := PISO + 1.0 + VENTANA.y / 2.0
		var xs := _repartir(Vector2(-w / 2.0 + 0.4, w / 2.0 - 0.4), 2.4)
		var con_balcon := rng.randf() < 0.5 and xs.size() > 0
		for i in xs.size():
			if con_balcon and i == 0:
				# Puerta-ventana con balcón y macetas (las macetas se tiran de un aletazo)
				_ventana(n, xs[i], PISO + 0.15 + 1.1, rng, Vector2(1.0, 2.1), false)
				NivelMedio.balcon(n, xs[i], PISO + 0.1, rng, 1.7, 0.8)
			else:
				_ventana(n, xs[i], y2, rng)
		# Línea de la losa entre las plantas
		NivelMedio.caja(n, Vector3(0, PISO + 0.05, 0.04), Vector3(w + 0.04, 0.12, 0.08), pared.lightened(0.15), true)
	# Techo
	if pisos == 1 and rng.randf() < 0.55:
		_techo_chapa(n, w, prof, h, pared, rng)
	else:
		_techo_losa(n, w, prof, h, rng)
	# Detalles de la fachada
	if rng.randf() < 0.6:
		# Medidor de luz con su caño
		var xm := x_puerta - lado * (PUERTA.x / 2.0 + 0.35)
		NivelMedio.caja(n, Vector3(xm, 1.5, 0.08), Vector3(0.35, 0.45, 0.16), c("metal"), false, Vector3.ZERO, true)
		NivelMedio.caja(n, Vector3(xm, (1.73 + h) / 2.0, 0.05), Vector3(0.05, h - 1.73, 0.05), c("hierro"), false,
			Vector3.ZERO, true)
	if pisos == 2 and rng.randf() < 0.5:
		var xa := -lado * (w / 2.0 - 0.7)
		NivelMedio.caja(n, Vector3(xa, PISO + 2.3, 0.22), Vector3(0.8, 0.5, 0.4), c("aire_ac"), true)
		NivelMedio.caja(n, Vector3(xa, PISO + 2.3, 0.43), Vector3(0.5, 0.36, 0.02), c("rejilla"), false, Vector3.ZERO, true)
	if rng.randf() < 0.45:
		Kit.colocar(n, _al_azar(["maceton", "maceton_flores"], rng), Vector3(x_puerta - lado * 0.9, Ciudad.Y_VEREDA, 0.45))
	if rng.randf() < 0.4:
		grafiti(n, Vector3(rng.randf_range(-w / 2.0 + 1.6, w / 2.0 - 1.6), 0.9, 0.035), rng, minf(2.6, w * 0.4))
	contar("casa")


## Posiciones repartidas en el tramo [a.x, a.y] cada "paso" metros (centradas).
static func _repartir(tramo: Vector2, paso: float) -> Array[float]:
	var out: Array[float] = []
	var largo := tramo.y - tramo.x
	var k := floori((largo + 0.2) / paso)
	if k <= 0:
		return out
	for i in k:
		out.append(tramo.x + largo * (i + 0.5) / k)
	return out


static func _puerta(n: Node3D, x: float, color: Color, rng: RandomNumberGenerator) -> void:
	var marco := c("blanco") if rng.randf() < 0.6 else c("madera_osc")
	var y := PUERTA.y / 2.0 + Y_UMBRAL
	NivelMedio.caja(n, Vector3(x, y + 0.05, 0.03), Vector3(PUERTA.x + 0.24, PUERTA.y + 0.12, 0.06), marco)
	NivelMedio.caja(n, Vector3(x, y, 0.05), Vector3(PUERTA.x, PUERTA.y, 0.04), color)
	# Tableros de la hoja y picaporte
	for dy: float in [-0.5, 0.45]:
		NivelMedio.caja(n, Vector3(x, y + dy, 0.075), Vector3(PUERTA.x - 0.3, 0.7, 0.02), color.darkened(0.15), false,
			Vector3.ZERO, true)
	NivelMedio.caja(n, Vector3(x + PUERTA.x / 2.0 - 0.14, y, 0.1), Vector3(0.05, 0.12, 0.06), c("luz_amarilla"), false,
		Vector3.ZERO, true)
	# Escalón (se pisa) y el número
	NivelMedio.caja(n, Vector3(x, Y_UMBRAL / 2.0, 0.3), Vector3(PUERTA.x + 0.5, Y_UMBRAL, 0.6), c("piedra_osc"), true)
	NivelMedio.caja(n, Vector3(x, PUERTA.y + 0.45, 0.04), Vector3(0.36, 0.22, 0.02), c("cartel_azul"), false, Vector3.ZERO, true)


## Ventana con marco, vidrio, alféizar (se posa) y reja. "y" es el centro.
static func _ventana(n: Node3D, x: float, y: float, rng: RandomNumberGenerator, tam := VENTANA, con_reja := true) -> void:
	var marco := c("blanco") if rng.randf() < 0.7 else c("madera")
	NivelMedio.caja(n, Vector3(x, y, 0.03), Vector3(tam.x + 0.2, tam.y + 0.2, 0.06), marco)
	NivelMedio.caja(n, Vector3(x, y, 0.05), Vector3(tam.x, tam.y, 0.03), c("vidrio_osc"))
	NivelMedio.caja(n, Vector3(x, y, 0.07), Vector3(0.05, tam.y, 0.02), marco, false, Vector3.ZERO, true)
	NivelMedio.caja(n, Vector3(x, y - tam.y / 2.0 - 0.14, 0.12), Vector3(tam.x + 0.36, 0.08, 0.24), c("piedra"), true)
	# Cortina de enrollar a medio bajar en algunas
	if rng.randf() < 0.4:
		var baja := rng.randf_range(0.25, 0.6) * tam.y
		NivelMedio.caja(n, Vector3(x, y + tam.y / 2.0 - baja / 2.0, 0.075), Vector3(tam.x, baja, 0.02), c("persiana"))
	if con_reja:
		var hierro := c("hierro")
		var barras := 5
		for i in barras:
			var xb := x - tam.x / 2.0 + (i + 0.5) * tam.x / barras
			NivelMedio.caja(n, Vector3(xb, y, 0.16), Vector3(0.03, tam.y + 0.1, 0.03), hierro, false, Vector3.ZERO, true)
		for dy: float in [-tam.y / 2.0, 0.0, tam.y / 2.0]:
			NivelMedio.caja(n, Vector3(x, y + dy, 0.16), Vector3(tam.x + 0.06, 0.03, 0.03), hierro, false, Vector3.ZERO, true)
		for lado: float in [-1.0, 1.0]:
			NivelMedio.caja(n, Vector3(x + lado * (tam.x / 2.0 + 0.02), y, 0.09), Vector3(0.03, tam.y + 0.1, 0.16), hierro,
				false, Vector3.ZERO, true)


## Losa con pretil de color alrededor (todo con colisión) y lo de arriba: tanque, antena o tendedero.
static func _techo_losa(n: Node3D, w: float, prof: float, h: float, rng: RandomNumberGenerator, extras := true) -> void:
	const PR := 0.6
	const E := 0.18
	var color := c(_al_azar(PRETILES, rng))
	NivelMedio.caja(n, Vector3(0, h + 0.03, -prof / 2.0), Vector3(w - 2.0 * E, 0.06, prof - 2.0 * E), c("azotea"))
	# Pretil: frente, fondo y costados, con una tapa que sobresale (la colisión cubre la tapa)
	for z: float in [-E / 2.0, -prof + E / 2.0]:
		NivelMedio.caja(n, Vector3(0, h + PR / 2.0, z), Vector3(w, PR, E), color.darkened(0.08), true)
		NivelMedio.caja(n, Vector3(0, h + PR + 0.04, z), Vector3(w + 0.1, 0.08, E + 0.12), color, true)
	for x: float in [-w / 2.0 + E / 2.0, w / 2.0 - E / 2.0]:
		NivelMedio.caja(n, Vector3(x, h + PR / 2.0, -prof / 2.0), Vector3(E, PR, prof - 2.0 * E), color.darkened(0.08), true)
		NivelMedio.caja(n, Vector3(x, h + PR + 0.04, -prof / 2.0), Vector3(E + 0.12, 0.08, prof - 2.0 * E), color, true)
	contar("losa")
	if not extras:
		return
	var dado := rng.randf()
	var fondo := Vector3(rng.randf_range(-0.25, 0.25) * w, h, -prof * 0.7)
	if dado < 0.55:
		_tanque(n, fondo)
	elif dado < 0.75 and w >= 5.5:
		Kit.colocar(n, "tendedero", Vector3(0, h + 0.06, -prof * 0.45), PI / 2.0)
	else:
		# Antena de televisión de caño
		NivelMedio.caja(n, fondo + Vector3(0, 1.5, 0), Vector3(0.05, 3.0, 0.05), c("cano"), false, Vector3.ZERO, true)
		for k in 3:
			NivelMedio.caja(n, fondo + Vector3(0, 2.2 + k * 0.35, 0), Vector3(1.2 - k * 0.3, 0.03, 0.03), c("cano"), false,
				Vector3.ZERO, true)
	azoteas.append(n.transform * Vector3(-fondo.x * 0.5, h + 0.07, -prof * 0.3))


## Tanque de agua negro sobre una base de ladrillos (con colisión: la paloma se sube).
static func _tanque(n: Node3D, base: Vector3) -> void:
	NivelMedio.caja(n, base + Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 1.3), c("ladrillo"), true)
	var tanque := Construir.cilindro(n, base + Vector3(0, 1.3, 0), 0.6, 1.4, c("tanque"), false, 10)
	tanque.position = base + Vector3(0, 1.3, 0)
	var forma := CylinderShape3D.new()
	forma.radius = 0.6
	forma.height = 1.4
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, base + Vector3(0, 1.3, 0)))
	Construir.cilindro(n, base + Vector3(0, 2.05, 0), 0.4, 0.1, c("tanque").lightened(0.1), false, 10)


## Techo de chapa a un agua: alto adelante y bajo atrás. Los costados se cierran con un hastial del color
## de la pared (antes la chapa flotaba sobre la caja); la chapa sale 30 cm de alero y tiene canaleta.
static func _techo_chapa(n: Node3D, w: float, prof: float, h: float, pared: Color, rng: RandomNumberGenerator) -> void:
	var sube := clampf(prof * 0.09, 0.6, 1.1)
	# Frente más alto (una franja de pared sobre la fachada) y hastiales triangulares a los costados
	NivelMedio.caja(n, Vector3(0, h + sube / 2.0, -0.1), Vector3(w, sube, 0.2), pared, true)
	for x: float in [-w / 2.0 + 0.1, w / 2.0 - 0.1]:
		var pm := PrismMesh.new()
		pm.left_to_right = 0.0
		pm.size = Vector3(prof, sube, 0.2)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = Construir.material(pared)
		n.add_child(mi)
		mi.transform = Transform3D(Basis.from_euler(Vector3(0, PI / 2.0, 0)), Vector3(x, h + sube / 2.0, -prof / 2.0))
		var forma := ConvexPolygonShape3D.new()
		forma.points = pm.get_faces()
		NivelMedio.colision(n, forma, mi.transform)
	# La chapa: apoya en la parte de arriba del frente y del fondo, con alero en los cuatro lados
	var ang := atan2(sube, prof)
	var largo := sqrt(prof * prof + sube * sube) + 0.6
	var b := Basis.from_euler(Vector3(ang, 0, 0))
	var centro := Vector3(0, h + sube / 2.0 + ESPESOR_CHAPA / 2.0 + 0.01, -prof / 2.0)
	var color := c("chapa") if rng.randf() < 0.7 else c("oxido")
	NivelMedio.caja(n, centro, Vector3(w + 0.5, ESPESOR_CHAPA, largo), color, true, Vector3(ang, 0, 0))
	# Nervaduras de la chapa (sin colisión) y alguna chapa oxidada suelta
	var nerv := maxi(int((w + 0.5) / 0.45), 2)
	for i in nerv:
		var x := -(w + 0.5) / 2.0 + (i + 0.5) * (w + 0.5) / nerv
		NivelMedio.caja(n, centro + b * Vector3(x, ESPESOR_CHAPA / 2.0 + 0.02, 0), Vector3(0.05, 0.04, largo), color.darkened(0.15),
			false, Vector3(ang, 0, 0), true)
	if rng.randf() < 0.5:
		var x := rng.randf_range(-w / 2.0 + 1.0, w / 2.0 - 1.0)
		NivelMedio.caja(n, centro + b * Vector3(x, ESPESOR_CHAPA / 2.0 + 0.045, rng.randf_range(-1.5, 1.5)),
			Vector3(1.0, 0.012, 1.6), c("oxido"), false, Vector3(ang, 0, 0), true)
	# Canaleta atrás y unos ladrillos encima para que no se vuele (clásico)
	NivelMedio.caja(n, centro + b * Vector3(0, -0.02, -largo / 2.0 + 0.05), Vector3(w + 0.5, 0.12, 0.14), c("cano"), false,
		Vector3(ang, 0, 0), true)
	for k in rng.randi_range(0, 3):
		var q := Vector3(rng.randf_range(-w / 2.0 + 0.6, w / 2.0 - 0.6), ESPESOR_CHAPA / 2.0 + 0.08, rng.randf_range(-largo / 3.0, largo / 3.0))
		NivelMedio.caja(n, centro + b * q, Vector3(0.24, 0.12, 0.12), c("ladrillo"), false, Vector3(ang, rng.randf() * PI, 0), true)
	contar("chapa")


## Grafiti en la pared (en el marco "n", centrado en "p", mirando a +Z): letras infladas con un borde
## grueso de otro color (como las de aerosol), un par de chorreadas y algún manchón de fondo.
static func grafiti(n: Node3D, p: Vector3, rng: RandomNumberGenerator, ancho := 2.4, texto := "") -> void:
	var c1 := c(_al_azar(GRAFITIS, rng))
	var c2 := c(_al_azar(GRAFITIS, rng))
	while c2 == c1:
		c2 = c(_al_azar(GRAFITIS, rng))
	var tag: String = texto if texto != "" else _al_azar(TAGS, rng)
	var linea := 0
	for l in tag.split("\n"):
		linea = maxi(linea, l.length())
	# Manchón de fondo (sólo en la mitad, así no queda un cartel rectangular)
	if rng.randf() < 0.5:
		NivelMedio.caja(n, p + Vector3(-ancho * 0.1, 0.05, -0.008), Vector3(ancho * 0.7, 0.55, 0.012), c2.darkened(0.35), false,
			Vector3(0, 0, rng.randf_range(-0.15, 0.15)), true)
	var l3 := Construir.cartel(n, p + Vector3(0, 0, 0.01), tag, c1, 96)
	l3.outline_size = 30
	l3.outline_modulate = c2.darkened(0.25)
	l3.pixel_size = ancho / (maxf(linea, 2.0) * 96.0 * 0.62)
	l3.rotation.z = rng.randf_range(-0.08, 0.08)
	l3.visibility_range_end = 70.0
	# Chorreadas de pintura
	for k in rng.randi_range(1, 3):
		var x := rng.randf_range(-ancho * 0.4, ancho * 0.4)
		var largo := rng.randf_range(0.15, 0.45)
		NivelMedio.caja(n, p + Vector3(x, -0.3 - largo / 2.0, 0.0), Vector3(0.04, largo, 0.01), c1, false, Vector3.ZERO, true)
	contar("grafiti")


static func contar(tipo: String, k := 1) -> void:
	cuenta[tipo] = int(cuenta.get(tipo, 0)) + k


# ---------------------------------------------------------------- Guarida de los BadJokes

## Dónde está la guarida: el frente del galpón (mira al oeste, al potrero) y su giro.
const GUARIDA := Vector3(171.0, 0.0, 69.0)
const GUARIDA_ROT := -PI / 2.0
const GALPON := Vector3(16.0, 6.0, 12.0)    ## Ancho (a lo largo del frente), alto de las paredes y fondo
const CUMBRERA := 2.2                         ## Lo que sube el techo a dos aguas hasta la cumbrera
const ANEXO := Vector3(5.0, 6.3, 8.0)         ## La casilla de dos plantas al costado, con la terraza del jefe

## Puntos de aparición de la banda: [rol, posición en el marco de la guarida, hacia dónde mira (giro)].
## Roles: "guardia" (en el portón), "vigia" (en el techo), "patrulla" (da vueltas por el patio y el
## barrio) y "jefe" (sentado en su sillón de la terraza, lo pone guarida()). Las patrullas de afuera van
## en el mundo (PATRULLAS).
const SPAWNS := [
	["guardia", Vector3(-3.6, Ciudad.Y_VEREDA + 0.2, 1.6), 0.0],
	["guardia", Vector3(3.6, Ciudad.Y_VEREDA + 0.2, 1.6), 0.0],
	["vigia", Vector3(0.0, GALPON.y + CUMBRERA + 0.1, -0.6), 0.0],
	["vigia", Vector3(0.0, GALPON.y + CUMBRERA + 0.1, -GALPON.z + 0.6), PI],
	["patrulla", Vector3(-1.5, Ciudad.Y_VEREDA + 0.2, 3.6), 0.0],
]
const PATRULLAS := [Vector3(137.0, 0.2, 68.0), Vector3(104.0, 0.2, 70.0), Vector3(160.0, 0.2, 60.0)]


## La guarida de la banda de los BadJokes: un galpón de ladrillo con techo de chapa a dos aguas, portón
## a medio subir con el cartel pintado, grafitis, un patio con tachos de fuego, cajones, un sillón viejo
## y bolsas de plata, y al costado una casilla de dos plantas con la terraza del jefe (sillón dorado,
## sombrilla, parlante y bandera). Deja los puntos de aparición (Marker3D en el grupo "spawn_badjokes",
## con las metas "rol" y "giro"), la zona de la base (grupo "base_badjokes", meta "radio") y el punto para
## la brújula (grupo "punto_badjokes").
static func guarida(ci: Ciudad, rng: RandomNumberGenerator) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, GUARIDA_ROT, 0)), GUARIDA)
	var n := NivelMedio.marco(ci, t)
	n.name = "GuaridaBadJokes"
	var w := GALPON.x
	var h := GALPON.y
	var prof := GALPON.z
	var ladrillo := c("ladrillo")
	# Patio de cemento entre el cerco y el portón
	NivelMedio.caja(n, Vector3(0, Ciudad.Y_VEREDA + 0.03, 2.5), Vector3(w + 2.0, 0.06, 5.0), c("piedra_osc"), true)
	# Galpón: paredes de ladrillo con hiladas más oscuras y un zócalo de cemento
	NivelMedio.caja(n, Vector3(0, h / 2.0, -prof / 2.0), Vector3(w, h, prof), ladrillo, true)
	NivelMedio.caja(n, Vector3(0, 0.45, 0.03), Vector3(w + 0.04, 0.9, 0.06), c("piedra_osc"))
	for k in 6:
		NivelMedio.caja(n, Vector3(0, 1.4 + k * 0.8, 0.012), Vector3(w, 0.05, 0.02), ladrillo.darkened(0.18), false,
			Vector3.ZERO, true)
	# Techo a dos aguas con la cumbrera de adelante hacia atrás: hastiales de ladrillo y chapa con alero
	for z: float in [-0.125, -prof + 0.125]:
		Construir.prisma(n, Vector3(0, h + CUMBRERA / 2.0, z), Vector3(w, CUMBRERA, 0.25), ladrillo, Vector3.ZERO, true)
	var ang := atan2(CUMBRERA, w / 2.0)
	var largo := sqrt(w * w / 4.0 + CUMBRERA * CUMBRERA) + 0.5
	for lado: float in [-1.0, 1.0]:
		var rot := Vector3(0, 0, -lado * ang)
		var b := Basis.from_euler(rot)
		var centro := Vector3(lado * (w / 4.0 + 0.12), h + CUMBRERA / 2.0 + ESPESOR_CHAPA, -prof / 2.0)
		NivelMedio.caja(n, centro, Vector3(largo, ESPESOR_CHAPA, prof + 0.8), c("oxido"), true, rot)
		for i in 14:
			var z := -prof / 2.0 - (prof + 0.8) / 2.0 + (i + 0.5) * (prof + 0.8) / 14.0
			NivelMedio.caja(n, centro + b * Vector3(0, ESPESOR_CHAPA / 2.0 + 0.02, z + prof / 2.0), Vector3(largo, 0.04, 0.05),
				c("oxido").darkened(0.18), false, rot, true)
		# Chapas parcheadas de otro color
		for k in 2:
			NivelMedio.caja(n, centro + b * Vector3(rng.randf_range(-1.5, 1.5), ESPESOR_CHAPA / 2.0 + 0.045, rng.randf_range(-4.0, 4.0)),
				Vector3(1.8, 0.012, 1.4), c("chapa"), false, rot, true)
	NivelMedio.caja(n, Vector3(0, h + CUMBRERA + 0.06, -prof / 2.0), Vector3(0.3, 0.14, prof + 0.8), c("chapa").darkened(0.2), true)
	# Portón de chapa a medio subir (adentro, oscuro) con su marco
	NivelMedio.caja(n, Vector3(0, 2.1, 0.02), Vector3(5.4, 4.2, 0.03), Color("17151c"))
	NivelMedio.caja(n, Vector3(0, 3.3, 0.07), Vector3(5.4, 1.8, 0.06), c("chapa"), true)
	for k in 8:
		NivelMedio.caja(n, Vector3(0, 2.5 + k * 0.22, 0.105), Vector3(5.4, 0.03, 0.02), c("chapa").darkened(0.2), false,
			Vector3.ZERO, true)
	for x: float in [-2.85, 2.85]:
		NivelMedio.caja(n, Vector3(x, 2.15, 0.06), Vector3(0.3, 4.3, 0.12), c("hierro"), true)
	NivelMedio.caja(n, Vector3(0, 4.35, 0.06), Vector3(6.0, 0.3, 0.12), c("hierro"), true)
	# Cartel pintado a mano arriba del portón
	NivelMedio.caja(n, Vector3(0, 5.2, 0.08), Vector3(8.4, 1.2, 0.1), Color("2a1f4a"), true)
	var cartel := Construir.cartel(n, Vector3(0, 5.22, 0.15), "BADJOKES", Color("ffd84a"), 150)
	cartel.outline_size = 28
	cartel.outline_modulate = Color("c8306a")
	cartel.pixel_size = 0.0075
	cartel.visibility_range_end = 120.0
	# Grafitis en el frente y en los costados
	grafiti(n, Vector3(-5.6, 2.2, 0.035), rng, 3.0, "PIGEONS")
	grafiti(n, Vector3(5.6, 2.2, 0.035), rng, 2.6, "BJ\nCREW")
	for lado: float in [-1.0, 1.0]:
		var costado := NivelMedio.marco(n, Transform3D(Basis.from_euler(Vector3(0, lado * PI / 2.0, 0)), Vector3(lado * w / 2.0, 0, -prof / 2.0)))
		grafiti(costado, Vector3(-2.0, 2.4, 0.035), rng, 4.0, "BADJOKES")
		grafiti(costado, Vector3(2.8, 1.6, 0.035), rng, 2.0)
		_ventana(costado, 2.8, 4.4, rng)
	# Patio: tachos de fuego, cajones con bolsas de plata, el sillón viejo y un colchón
	for x: float in [-4.6, 4.6]:
		_tacho_fuego(n, Vector3(x, Ciudad.Y_VEREDA + 0.06, 3.2))
	for k in 3:
		var p := Vector3(-7.2 + k * 0.95, Ciudad.Y_VEREDA + 0.06, 1.2 + (k % 2) * 0.9)
		NivelMedio.caja(n, p + Vector3(0, 0.35, 0), Vector3(0.85, 0.7, 0.85), c("madera"), true, Vector3(0, rng.randf() * 0.4, 0))
		if k != 1:
			_bolsa_plata(n, p + Vector3(0, 0.7, 0))
	NivelMedio.caja(n, Vector3(-6.7, Ciudad.Y_VEREDA + 1.12, 1.6), Vector3(0.85, 0.7, 0.85), c("madera"), true, Vector3(0, 0.3, 0))
	_sillon(n, Vector3(6.4, Ciudad.Y_VEREDA + 0.06, 1.8), -0.4, c("toldo_verde").darkened(0.35))
	NivelMedio.caja(n, Vector3(6.9, Ciudad.Y_VEREDA + 0.5, -0.25), Vector3(1.9, 0.18, 1.0), c("persiana"), true, Vector3(-1.2, 0.0, 0))
	# Parlante grande al lado del portón
	NivelMedio.caja(n, Vector3(-3.6, Ciudad.Y_VEREDA + 0.7, 0.5), Vector3(0.8, 1.3, 0.6), Color("1c1c22"), true)
	for y: float in [0.45, 1.0]:
		Construir.cilindro(n, Vector3(-3.6, Ciudad.Y_VEREDA + y, 0.81), 0.22 if y < 0.6 else 0.13, 0.02, Color("3a3a44"), false, 12).rotation.x = PI / 2.0
	# Anexo: casilla de dos plantas con la terraza del jefe arriba
	var ax := w / 2.0 + ANEXO.x / 2.0 + 0.1
	var anexo := NivelMedio.marco(n, Transform3D(Basis.IDENTITY, Vector3(ax, 0, -2.0)))
	NivelMedio.caja(anexo, Vector3(0, ANEXO.y / 2.0, -ANEXO.z / 2.0), Vector3(ANEXO.x, ANEXO.y, ANEXO.z), c("fachada_lila").darkened(0.15), true)
	NivelMedio.caja(anexo, Vector3(0, ZOCALO / 2.0, 0.025), Vector3(ANEXO.x + 0.02, ZOCALO, 0.05), c("piedra_osc"))
	_puerta(anexo, -1.2, c("toldo_rojo"), rng)
	_ventana(anexo, 1.2, 1.6, rng)
	_ventana(anexo, -1.0, 4.6, rng)
	_ventana(anexo, 1.2, 4.6, rng)
	_techo_losa(anexo, ANEXO.x, ANEXO.z, ANEXO.y, rng, false)
	# Escalera de hierro por el costado (decorativa, la paloma vuela)
	var pie := Vector3(ANEXO.x / 2.0 + 0.35, 0.4, -1.0)
	var paso := Vector3(0, 0.6, -0.55)
	for k in 10:
		NivelMedio.caja(anexo, pie + paso * k, Vector3(0.7, 0.05, 0.3), c("hierro"), false, Vector3.ZERO, true)
	var subida := paso * 9.0
	var inclinacion := atan2(subida.y, -subida.z)
	for x: float in [-0.36, 0.36]:
		NivelMedio.caja(anexo, pie + subida / 2.0 + Vector3(x, 0.05, 0), Vector3(0.05, 0.12, subida.length() + 0.4), c("hierro"),
			false, Vector3(inclinacion, 0, 0), true)
	# Terraza del jefe: sillón dorado, sombrilla, parlante y bandera
	var terraza := ANEXO.y + 0.06
	_sillon(anexo, Vector3(0.0, terraza, -5.4), 0.0, c("plastico_amarillo"), true)
	Construir.cilindro(anexo, Vector3(-1.5, terraza + 1.1, -4.6), 0.03, 2.2, c("metal"), false, 6)
	var sombrilla := Construir.cilindro(anexo, Vector3(-1.5, terraza + 2.25, -4.6), 1.2, 0.35, c("toldo_rojo"), false, 10, 0.05)
	sombrilla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	NivelMedio.caja(anexo, Vector3(1.6, terraza + 0.4, -6.8), Vector3(0.6, 0.8, 0.5), Color("1c1c22"), true)
	Construir.cilindro(anexo, Vector3(-2.1, terraza + 2.0, -7.5), 0.04, 4.0, c("metal"), false, 6)
	NivelMedio.caja(anexo, Vector3(-1.45, terraza + 3.55, -7.5), Vector3(1.3, 0.8, 0.03), Color("1c1c22"))
	var bandera := Construir.cartel(anexo, Vector3(-1.45, terraza + 3.55, -7.47), "BJ", Color("ffd84a"), 64)
	bandera.pixel_size = 0.008
	# Puntos de aparición, la zona de la base y el punto de la brújula
	# El sillón dorado tiene el respaldo hacia -Z y la paloma mira hacia -Z con giro 0: para que mire hacia
	# donde da el asiento (+Z, el patio) va con medio giro
	_spawn(n, "jefe", Vector3(ax, terraza + 0.5, -2.0 - 5.35), PI, 0)
	for i in SPAWNS.size():
		var s: Array = SPAWNS[i]
		_spawn(n, s[0], s[1], float(s[2]), i + 1)
	for i in PATRULLAS.size():
		var m := Marker3D.new()
		m.name = "SpawnBadJokes_patrulla_%d" % i
		m.add_to_group("spawn_badjokes")
		m.set_meta("rol", "patrulla")
		m.set_meta("giro", 0.0)
		ci.add_child(m)
		m.position = PATRULLAS[i]
	var base := Marker3D.new()
	base.name = "BaseBadJokes"
	base.add_to_group("base_badjokes")
	base.add_to_group("punto_badjokes")
	base.set_meta("radio", 12.0)
	n.add_child(base)
	base.position = Vector3(0, Ciudad.Y_VEREDA, 2.5)
	contar("guarida")


static func _spawn(n: Node3D, rol: String, p: Vector3, giro: float, i: int) -> void:
	var m := Marker3D.new()
	m.name = "SpawnBadJokes_%s_%d" % [rol, i]
	m.add_to_group("spawn_badjokes")
	m.set_meta("rol", rol)
	m.set_meta("giro", giro)
	n.add_child(m)
	m.position = p
	m.rotation.y = giro


## Tacho de 200 litros con fuego adentro (las llamas brillan, sin colisión) y su colisión.
static func _tacho_fuego(n: Node3D, p: Vector3) -> void:
	Construir.cilindro(n, p + Vector3(0, 0.45, 0), 0.32, 0.9, c("oxido").darkened(0.2), false, 10)
	var forma := CylinderShape3D.new()
	forma.radius = 0.32
	forma.height = 0.9
	NivelMedio.colision(n, forma, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.45, 0)))
	for k in 3:
		var llama := Construir.esfera(n, p + Vector3((k - 1) * 0.1, 1.0 + (k % 2) * 0.12, (k % 2) * 0.08 - 0.04), 0.16 - k * 0.03,
			Color("ffb347"), Vector3(1, 1.6, 1), 6)
		llama.material_override = Construir.material(Color("ffb347") if k != 1 else Color("ff6a3a"), 0.9, true)
		llama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Bolsa de plata con el signo pesos.
static func _bolsa_plata(n: Node3D, p: Vector3) -> void:
	Construir.esfera(n, p + Vector3(0, 0.2, 0), 0.22, c("arena").darkened(0.2), Vector3(1, 0.9, 1), 8)
	Construir.cilindro(n, p + Vector3(0, 0.42, 0), 0.07, 0.12, c("arena").darkened(0.35), false, 6, 0.1)
	var l := Construir.cartel(n, p + Vector3(0, 0.2, 0.22), "$", Color("2f8a3a"), 48)
	l.outline_size = 0
	l.pixel_size = 0.006


## Sillón viejo (o el dorado del jefe): asiento, respaldo y apoyabrazos, con colisión (la paloma se sienta).
static func _sillon(n: Node3D, p: Vector3, giro: float, color: Color, dorado := false) -> void:
	var s := NivelMedio.marco(n, Transform3D(Basis.from_euler(Vector3(0, giro, 0)), p))
	NivelMedio.caja(s, Vector3(0, 0.25, 0), Vector3(1.7, 0.5, 0.9), color, true)
	NivelMedio.caja(s, Vector3(0, 0.75, -0.35), Vector3(1.7, 0.9 if not dorado else 1.4, 0.25), color.darkened(0.1), true)
	for x: float in [-0.8, 0.8]:
		NivelMedio.caja(s, Vector3(x, 0.62, 0.0), Vector3(0.2, 0.3, 0.9), color.darkened(0.15), true)
	if dorado:
		for x: float in [-0.6, 0.0, 0.6]:
			Construir.esfera(s, Vector3(x, 1.5, -0.35), 0.1, c("plastico_rojo"), Vector3.ONE, 6)
