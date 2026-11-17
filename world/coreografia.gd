class_name Coreografia
extends RefCounted
## Los bailes de los créditos: cada uno es una función del tiempo (en segundos desde que empieza)
## que devuelve la PoseBaile de ese instante. Ninguno usa animaciones del GLB: se arman girando los
## huesos y el cuerpo entero, así se pueden afinar sin tocar el modelo de Blender.
## Los bailes largos se arman con tramos (toprock, suelo, congelado...) que se mezclan entre sí.
## El orden de ORDEN es el de los créditos (el primero es el break dance de Carlos) y FINAL cierra
## con la paloma flaca. Para sumar uno: escribir su función, agregarlo a DURACION y a pose().

const ORDEN: Array[StringName] = [&"breakdance", &"moonwalk", &"disco", &"robot", &"twist",
	&"salto", &"pirueta", &"cabeceo", &"salsa", &"cortejo", &"gangnam"]
## El baño de la fuente (ver world/fuente.gd) usa esta misma maquinaria pero no está en la rueda ni en
## los créditos: la paloma lo baila sola al meterse al agua.
const BANO := &"bano"
## En qué segundo del cortejo la paloma que mira "se enamora" (después del gran final).
const MOMENTO_CORTEJO := 6.5
const FINAL := &"voltereta"
const DURACION := {
	&"breakdance": 6.5, &"moonwalk": 5.0, &"disco": 5.0, &"robot": 5.0, &"twist": 5.0,
	&"salto": 5.0, &"pirueta": 5.5, &"cabeceo": 5.0, &"salsa": 5.0, &"voltereta": 7.0,
	&"cortejo": 8.0, &"bano": 4.8, &"gangnam": 8.0,
}
const NOMBRES := {
	&"breakdance": "Break dance", &"moonwalk": "Moonwalk", &"disco": "Disco", &"robot": "Robot",
	&"twist": "Twist", &"salto": "Salto", &"pirueta": "Pirueta", &"cabeceo": "Cabeceo",
	&"salsa": "Salsa", &"voltereta": "Voltereta", &"cortejo": "Cortejo", &"bano": "Baño",
	&"gangnam": "Gangnam Style",
}
const YAW := 20.0       ## Cada paloma se ve de tres cuartos, no justo de frente


## El nombre del baile para mostrar (en español: es la clave de la traducción).
static func nombre(baile: StringName) -> String:
	return NOMBRES.get(baile, String(baile))


static func duracion(baile: StringName) -> float:
	return DURACION.get(baile, 5.0)


static func pose(baile: StringName, t: float) -> PoseBaile:
	match baile:
		&"breakdance": return _breakdance(t)
		&"moonwalk": return _moonwalk(t)
		&"disco": return _disco(t)
		&"robot": return _robot(t)
		&"twist": return _twist(t)
		&"salto": return _salto(t)
		&"pirueta": return _pirueta(t)
		&"cabeceo": return _cabeceo(t)
		&"salsa": return _salsa(t)
		&"cortejo": return _cortejo(t)
		&"gangnam": return _gangnam(t)
		&"bano": return _bano(t)
		&"voltereta": return _voltereta(t)
	return PoseBaile.new()


# ---------------------------------------------------------------- Giros de ayuda

static func _x(grados: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(grados))


static func _y(grados: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(grados))


static func _z(grados: float) -> Basis:
	return Basis(Vector3.BACK, deg_to_rad(grados))


## Ala izquierda: "abrir" la separa del cuerpo (0 = plegada, 90 = recta al costado) y "subir" la
## levanta (90 = vertical). El ala derecha es igual, espejada.
static func _ala_izq(abrir: float, subir := 0.0) -> Basis:
	return _z(subir) * _y(-abrir)


static func _ala_der(abrir: float, subir := 0.0) -> Basis:
	return _z(-subir) * _y(abrir)


## 0 -> 1 y vuelve a 0 (una campana), para cosas que pasan una sola vez en un rato.
static func _campana(desde: float, hasta: float, t: float) -> float:
	return sin(clampf((t - desde) / (hasta - desde), 0.0, 1.0) * PI)


# ---------------------------------------------------------------- 1. Break dance (Carlos)

## Toprock (pasos de pie), giro de espaldas en el piso pateando al aire y un "freeze" final.
static func _breakdance(t: float) -> PoseBaile:
	var w_suelo := smoothstep(0.9, 1.6, t)
	var w_freeze := smoothstep(4.5, 5.1, t)
	var p := _break_toprock(t).mezclar(_break_suelo(t), w_suelo).mezclar(_break_freeze(t), w_freeze)
	# El giro del cuerpo NO se mezcla con slerp: entre "de pie" y "de espaldas" hay casi 180° y el
	# camino más corto cambia de lado de golpe (un tirón). Se mezclan el rumbo y el vuelco por separado.
	var a := _break_toprock_ejes(t)
	var b := _break_suelo_ejes(t)
	var c := Vector2(-15.0, 38.0 + sin(t * 30.0) * 1.2)
	var ejes := _mezclar_ejes(_mezclar_ejes(a, b, w_suelo), c, w_freeze)
	p.rot = _y(ejes.x) * _z(ejes.y)
	return p


## Rumbo (x) y vuelco (y) del cuerpo, en grados.
static func _mezclar_ejes(a: Vector2, b: Vector2, w: float) -> Vector2:
	return Vector2(rad_to_deg(lerp_angle(deg_to_rad(a.x), deg_to_rad(b.x), w)), lerpf(a.y, b.y, w))


static func _break_toprock_ejes(t: float) -> Vector2:
	return Vector2(YAW + sin(t * TAU * 0.9) * 25.0, sin(t * TAU * 2.0) * 6.0)


static func _break_suelo_ejes(t: float) -> Vector2:
	return Vector2(YAW + 3.0 * 360.0 * smoothstep(1.1, 4.7, t), 180.0)


static func _break_toprock(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var beat := t * TAU * 2.0
	p.pos = Vector3(sin(t * TAU * 0.9) * 0.13, absf(sin(beat)) * 0.035, 0.0)
	p.rot = _y(YAW + sin(t * TAU * 0.9) * 25.0) * _z(sin(beat) * 6.0)
	p.ala_izq = _ala_izq(45.0 + 30.0 * sin(beat), 10.0 * sin(beat))
	p.ala_der = _ala_der(45.0 - 30.0 * sin(beat), -10.0 * sin(beat))
	p.cabeza = _y(20.0 * sin(beat)) * _x(14.0 * sin(beat * 2.0))
	p.pata_izq = _x(-25.0 * maxf(sin(beat), 0.0))
	p.pata_der = _x(-25.0 * maxf(-sin(beat), 0.0))
	p.cola = _y(18.0 * sin(beat))
	return p


## De espaldas, girando como un "windmill" y pateando al aire con las alas abiertas en el piso.
static func _break_suelo(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var giro := 3.0 * 360.0 * smoothstep(1.1, 4.7, t)    # Tres vueltas que arrancan y frenan suave
	p.rot = _y(YAW + giro) * _z(180.0)
	p.pos = Vector3(0.0, -0.07 + 0.015 * sin(t * TAU * 3.0), 0.0)
	p.pata_izq = _x(-30.0 - 40.0 * sin(t * 13.0))
	p.pata_der = _x(-30.0 - 40.0 * sin(t * 13.0 + PI))
	p.ala_izq = _ala_izq(78.0 + 8.0 * sin(t * 9.0))
	p.ala_der = _ala_der(78.0 + 8.0 * sin(t * 9.0 + 1.0))
	p.cabeza = _x(-20.0)
	p.cola = _x(-15.0)
	return p


## Pose congelada de costado, con un ala arriba, una abajo, una pata en el aire y un temblor.
static func _break_freeze(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	p.rot = _y(-15.0) * _z(38.0 + sin(t * 30.0) * 1.2)
	p.pos = Vector3(0.0, 0.03, 0.0)
	p.ala_izq = _ala_izq(95.0, 75.0)
	p.ala_der = _ala_der(40.0, -25.0)
	p.cabeza = _y(35.0) * _z(-30.0)
	p.pata_der = _x(-70.0)
	p.cola = _x(35.0)
	return p


# ---------------------------------------------------------------- 2. Moonwalk (La Tana)

## De perfil, desliza para atrás con los pasos para adelante; al final un giro y la pose del sombrero.
static func _moonwalk(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var fase := t * TAU * 1.6
	var desliza := smoothstep(0.2, 3.6, t)
	p.pos = Vector3(lerpf(0.4, -0.4, desliza), 0.012 + 0.02 * maxf(sin(fase * 2.0), 0.0), 0.0)
	p.rot = _y(90.0) * _x(5.0)
	p.pata_izq = _x(-32.0 * sin(fase))
	p.pata_der = _x(-32.0 * sin(fase + PI))
	p.ala_izq = _ala_izq(25.0 + 15.0 * sin(fase), 6.0 * sin(fase))
	p.ala_der = _ala_der(25.0 + 15.0 * sin(fase + PI), 6.0 * sin(fase + PI))
	p.cabeza = _x(8.0 * sin(fase * 2.0)) * _y(-10.0 * sin(fase))
	p.cola = _y(10.0 * sin(fase))

	var f := PoseBaile.new()
	f.rot = _y(90.0 + 360.0 * smoothstep(3.7, 4.4, t))
	f.pos = Vector3(-0.4, 0.045, 0.0)
	f.ala_izq = _ala_izq(55.0, 105.0)       # Se toca el "sombrero" con el ala
	f.ala_der = _ala_der(20.0, -10.0)
	f.cabeza = _x(20.0) * _z(12.0)
	f.pata_izq = _x(-12.0)
	f.pata_der = _x(-12.0)
	return p.mezclar(f, smoothstep(3.5, 3.9, t))


# ---------------------------------------------------------------- 3. Disco (El Ruso)

## El dedo al cielo de Fiebre de sábado por la noche, de un lado y del otro, con cadera y pasitos.
static func _disco(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var beat := t * TAU * 1.0
	var s := sin(beat)
	var izq := smoothstep(-0.2, 0.5, s)        # 1 = ala izquierda arriba
	var der := smoothstep(-0.2, 0.5, -s)
	p.pos = Vector3(0.1 * s, 0.02 * absf(cos(beat)), 0.0)
	p.rot = _y(YAW + 20.0 * s) * _z(10.0 * s)
	p.ala_izq = _ala_izq(20.0 + 30.0 * izq, 70.0 * izq - 5.0)
	p.ala_der = _ala_der(20.0 + 30.0 * der, 70.0 * der - 5.0)
	p.cabeza = _z(15.0 * s) * _x(8.0 * sin(beat * 2.0))
	p.pata_izq = _x(-25.0 * maxf(cos(beat), 0.0))
	p.pata_der = _x(-25.0 * maxf(-cos(beat), 0.0))
	p.cola = _x(20.0) * _y(15.0 * sin(beat * 2.0))
	# Final: las dos alas arriba
	var f := PoseBaile.new()
	f.rot = _y(YAW)
	f.pos = Vector3(0.0, 0.03, 0.0)
	f.ala_izq = _ala_izq(40.0, 80.0)
	f.ala_der = _ala_der(40.0, 80.0)
	f.cabeza = _x(-10.0) * _z(10.0)
	f.cola = _x(30.0)
	return p.mezclar(f, smoothstep(4.2, 4.7, t))


# ---------------------------------------------------------------- 4. Robot (Coqui)

## Movimientos duros: cada medio segundo se "traba" en una pose distinta, con un chasquido rápido.
## Cada pose: [giro del cuerpo, giro de la cabeza, ala izq (abrir, subir), ala der (abrir, subir), x, inclinación]
const ROBOT_POSES := [
	[0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[30.0, 60.0, 90.0, 0.0, 0.0, 0.0, 0.08, 0.0],
	[-30.0, -60.0, 0.0, 0.0, 90.0, 0.0, -0.08, 0.0],
	[0.0, 0.0, 90.0, 90.0, 90.0, 90.0, 0.0, 0.0],
	[0.0, 0.0, 90.0, -60.0, 90.0, -60.0, 0.0, 10.0],
	[45.0, 0.0, 90.0, 45.0, 0.0, 0.0, 0.06, 0.0],
	[-45.0, 0.0, 0.0, 0.0, 90.0, 45.0, -0.06, 0.0],
	[0.0, 90.0, 90.0, 0.0, 90.0, 0.0, 0.0, 0.0],
]


static func _robot(t: float) -> PoseBaile:
	var paso := t * 2.0
	var i := int(floorf(paso))
	# En el primer paso arranca desde la pose de firme (no desde la última, que está al otro lado)
	var anterior := _robot_pose(ROBOT_POSES[maxi(i - 1, 0) % ROBOT_POSES.size()], t)
	var actual := _robot_pose(ROBOT_POSES[i % ROBOT_POSES.size()], t)
	return anterior.mezclar(actual, smoothstep(0.0, 0.2, paso - i))


static func _robot_pose(d: Array, t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var tiembla := sin(t * 50.0) * 1.2          # Un temblorcito mecánico mientras está trabada
	p.rot = _y(YAW + d[0]) * _x(d[7])
	p.pos = Vector3(d[6], 0.0, 0.0)
	p.cabeza = _y(d[1] + tiembla)
	p.ala_izq = _ala_izq(d[2], d[3])
	p.ala_der = _ala_der(d[4], d[5])
	return p


# ---------------------------------------------------------------- 5. Twist

## La cadera gira para un lado y las alas para el otro, agachándose, y un giro de vuelta entera al final.
static func _twist(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var beat := t * TAU * 2.5
	p.pos = Vector3(0.0, 0.03 + 0.03 * cos(beat * 2.0), 0.0)
	p.rot = _y(YAW + 55.0 * sin(beat)) * _z(8.0 * cos(beat))
	p.ala_izq = _ala_izq(55.0 + 25.0 * sin(beat + PI), 25.0 * sin(beat))
	p.ala_der = _ala_der(55.0 + 25.0 * sin(beat), -25.0 * sin(beat))
	p.cola = _y(35.0 * sin(beat))
	p.cabeza = _y(-35.0 * sin(beat))
	p.pata_izq = _x(-14.0 * maxf(sin(beat), 0.0))
	p.pata_der = _x(-14.0 * maxf(-sin(beat), 0.0))
	var f := PoseBaile.new()
	f.rot = _y(YAW + 720.0 * smoothstep(4.0, 4.9, t))
	f.pos = Vector3(0.0, 0.03 + 0.1 * _campana(4.0, 4.9, t), 0.0)
	f.ala_izq = _ala_izq(40.0, 80.0)
	f.ala_der = _ala_der(40.0, 80.0)
	f.cola = _x(30.0)
	return p.mezclar(f, smoothstep(3.9, 4.2, t))


# ---------------------------------------------------------------- 6. Saltos

## Saltitos tipo "jumping jack": abre alas y patas en el aire, se agacha al caer y cada cuatro
## saltos da una vuelta entera.
static func _salto(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var periodo := 0.55
	var n := int(floorf(t / periodo))
	var fase := fmod(t, periodo) / periodo
	var k := 4.0 * fase * (1.0 - fase)             # 0 en el piso, 1 arriba de todo
	var aterriza := sin(clampf(fase / 0.14, 0.0, 1.0) * PI)     # Se agacha un instante al caer
	var vuelta := 360.0 * fase if n % 4 == 3 else 0.0
	p.pos = Vector3(0.1 * sin(t * 1.4), 0.32 * k - 0.045 * aterriza, 0.0)
	p.rot = _y(YAW + vuelta) * _x(-6.0 * aterriza)
	p.ala_izq = _ala_izq(20.0 + 70.0 * k, 70.0 * k)
	p.ala_der = _ala_der(20.0 + 70.0 * k, 70.0 * k)
	p.pata_izq = _x(-34.0 * k)
	p.pata_der = _x(-34.0 * k)
	p.cabeza = _x(-8.0 * k + 14.0 * aterriza)
	p.cola = _x(24.0 * k)
	return p


# ---------------------------------------------------------------- 7. Pirueta

## Ballet: gira sobre una pata con la otra levantada atrás, alas abiertas, y termina con una reverencia.
static func _pirueta(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var arabesco := smoothstep(0.2, 0.9, t) * (1.0 - smoothstep(4.0, 4.5, t))
	var giro := 3.0 * 360.0 * smoothstep(0.5, 4.1, t)
	p.rot = _y(YAW + giro) * _x(16.0 * arabesco)
	p.pos = Vector3(0.0, 0.03 * arabesco + 0.012 * sin(t * 6.0) * arabesco, 0.0)
	p.ala_izq = _ala_izq(86.0, 14.0 * arabesco)
	p.ala_der = _ala_der(86.0, 14.0 * arabesco)
	p.pata_der = _x(55.0 * arabesco)
	p.cabeza = _x(-16.0 * arabesco) * _z(10.0 * arabesco)
	p.cola = _x(26.0 * arabesco)
	# Reverencia final
	var f := PoseBaile.new()
	f.rot = _y(YAW) * _x(24.0)
	f.pos = Vector3(0.0, -0.03, 0.0)
	f.ala_izq = _ala_izq(70.0, -15.0)
	f.ala_der = _ala_der(70.0, -15.0)
	f.cabeza = _x(30.0)
	f.cola = _x(35.0)
	return p.mezclar(f, smoothstep(4.3, 4.8, t))


# ---------------------------------------------------------------- 8. Cabeceo (rock)

## Cabecea fuerte con la música, un ala arriba como puño (alternando), patadas y la cola temblando.
static func _cabeceo(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var beat := t * TAU * 2.0
	var puno_izq := smoothstep(-0.1, 0.4, sin(beat * 0.5))
	var puno_der := 1.0 - puno_izq
	p.pos = Vector3(0.0, 0.02 * absf(sin(beat)), 0.0)
	p.rot = _y(YAW) * _x(14.0 * sin(beat))
	p.cabeza = _x(10.0 + 35.0 * maxf(sin(beat), 0.0) - 10.0)
	p.ala_izq = _ala_izq(25.0 + 25.0 * puno_izq, 80.0 * puno_izq)
	p.ala_der = _ala_der(25.0 + 25.0 * puno_der, 80.0 * puno_der)
	p.pata_izq = _x(-22.0 * maxf(sin(beat), 0.0))
	p.pata_der = _x(-22.0 * maxf(-sin(beat), 0.0))
	p.cola = _x(25.0) * _y(20.0 * sin(beat * 3.0))
	return p


# ---------------------------------------------------------------- 9. Salsa

## Cadera que se mueve, un ala saludando y la otra en la cintura (cambian a la mitad), pasitos y giros de cabeza.
static func _salsa(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var beat := t * TAU * 1.5
	var cambio := smoothstep(2.3, 2.7, t)             # 0 = saluda con la izquierda, 1 = con la derecha
	var saluda := 55.0 + 25.0 * sin(beat * 3.0)
	p.pos = Vector3(0.08 * sin(beat), 0.015 * (1.0 + cos(beat * 2.0)), 0.0)
	p.rot = _y(YAW + 25.0 * sin(beat)) * _z(14.0 * sin(beat))
	p.ala_izq = _ala_izq(lerpf(70.0, 18.0, cambio), lerpf(saluda, -5.0, cambio))
	p.ala_der = _ala_der(lerpf(18.0, 70.0, cambio), lerpf(-5.0, saluda, cambio))
	p.pata_izq = _x(-30.0 * maxf(sin(beat * 2.0), 0.0))
	p.pata_der = _x(-30.0 * maxf(-sin(beat * 2.0), 0.0))
	p.cabeza = _y(30.0 * sin(beat + PI / 2.0)) * _z(10.0 * sin(beat))
	p.cola = _y(20.0 * sin(beat * 2.0))
	return p


# ---------------------------------------------------------------- Gangnam Style

## El baile del caballito (Gangnam Style), como el emote de Roblox: 8 s en bucle (arranca y termina
## igual) y siempre galopando. Sólo dos movimientos que se alternan, fundidos en ~0,3 s:
##   0 - 2,4 s    Caballito: alas cruzadas adelante del pecho como riendas, agachada, patas abiertas y
##                saltitos levantando la rodilla de a una (dos saltitos por pata).
##   2,4 - 4 s    El lazo: el ala derecha sube al costado de la cabeza y revolea arriba; la izquierda
##                sigue con las riendas.
##   4 - 5,6 s    Caballito yendo de costado (va y vuelve).
##   5,6 - 7,2 s  Otra vez el lazo.
##   7,2 - 8 s    Caballito, igual que al principio.
static func _gangnam(t: float) -> PoseBaile:
	var beat := t * TAU * 1.25                         # 2,5 saltitos por segundo
	var salto := absf(sin(beat))                       # Cada medio ciclo, un saltito
	# La pata que se levanta cambia cada dos saltitos, justo cuando está apoyada (salto = 0)
	var lado := 1.0 if fmod(t * 1.25, 2.0) < 1.0 else -1.0
	var costado := sin(t * PI * 1.25)                  # El cuerpo va de un lado al otro, suave
	var w_lazo := smoothstep(2.3, 2.7, t) * (1.0 - smoothstep(3.8, 4.2, t)) \
		+ smoothstep(5.5, 5.9, t) * (1.0 - smoothstep(7.0, 7.4, t))
	var w_lateral := smoothstep(4.0, 4.3, t) * (1.0 - smoothstep(5.3, 5.6, t))

	var p := PoseBaile.new()
	var x_lateral := 0.2 * sin((t - 4.0) / 1.6 * TAU)  # De costado: va y vuelve
	p.pos = Vector3(lerpf(0.04 * costado, x_lateral, w_lateral), 0.1 * salto - 0.05, 0.0)
	p.rot = _y(YAW + 10.0 * costado) * _x(-12.0 + 8.0 * sin(beat * 2.0))   # Agachada, cabeceando
	# Patas abiertas (como las piernas separadas del emote) y la rodilla de turno bien arriba
	p.pata_izq = _x(-50.0 * salto if lado > 0.0 else -6.0 * salto) * _z(-10.0)
	p.pata_der = _x(-50.0 * salto if lado < 0.0 else -6.0 * salto) * _z(10.0)
	p.cabeza = _x(16.0 * salto - 6.0) * _y(10.0 * costado)
	p.cola = _x(24.0 * salto) * _y(-14.0 * costado)
	# Alas CRUZADAS adelante del pecho (las riendas): cada una pasa la línea del medio hacia el otro
	# lado (más de 180°) y una va inclinada hacia arriba y la otra hacia abajo, así forman una X.
	# Atraviesan un poco el cuerpo; está bien, lo que importa es que la cruz se lea.
	# Las alas se arman al final con su apertura y altura ([abrir, subir]): de la cruz a cualquier otra
	# pose se pasa interpolando esos dos números, no mezclando giros. La cruz está casi del lado
	# opuesto a las otras poses y la mezcla de giros tomaría el atajo de golpe (un tirón de 80°).
	var bombeo := 8.0 * salto
	var izq := Vector2(228.0, 30.0 + bombeo)
	var der := Vector2(228.0, -30.0 + bombeo)
	# --- El lazo: el ala derecha arriba, al costado de la cabeza, dando vueltas (una por beat)
	var giro := t * TAU * 1.25
	der = der.lerp(Vector2(80.0 + 15.0 * sin(giro), 120.0 + 15.0 * cos(giro)), w_lazo)
	izq = izq.lerp(Vector2(214.0, 22.0 + bombeo), w_lazo)   # Sola con las riendas, un poco más al medio
	p.cabeza = PoseBaile._mezclar_giro(p.cabeza, _x(-12.0) * _y(-12.0 + 10.0 * sin(giro)) * _z(-8.0), w_lazo)
	p.ala_izq = _ala_izq(izq.x, izq.y)
	p.ala_der = _ala_der(der.x, der.y)
	return p

# ---------------------------------------------------------------- 10. Cortejo

## El cortejo del palomo, como el de verdad (8 s, y vuelve a empezar igual que arrancó):
##   0 - 1 s     Se infla: el cuello se hincha (escala de la cabeza), abre la cola en abanico y se endereza.
##   1,2 - 4 s   Da dos vueltas en círculo pavoneándose, con reverencias rápidas, el buche que "arrulla"
##               (la cabeza late), pasitos cortos y las alas caídas temblando.
##   4 - 6 s     Se planta de frente y hace reverencias lentas y profundas.
##   6 - 7 s     Gran final: una vuelta más con un saltito, alas abiertas, cabeza en alto y la cola al máximo.
##               En MOMENTO_CORTEJO las palomas sueltas que miran se enamoran (ver Bandada).
##   7 - 8 s     Se desinfla y cierra con una última reverencia.
static func _cortejo(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	# Envolventes (0 a 1) de cada tramo
	var infla := smoothstep(0.0, 1.0, t) * (1.0 - smoothstep(7.2, 7.9, t))
	var abanico := smoothstep(0.1, 1.1, t) * (1.0 - smoothstep(7.1, 7.9, t))
	var circula := smoothstep(1.0, 1.4, t) * (1.0 - smoothstep(3.8, 4.2, t))
	var frente := smoothstep(4.0, 4.5, t) * (1.0 - smoothstep(5.8, 6.2, t))
	var gran := smoothstep(5.9, 6.3, t) * (1.0 - smoothstep(6.9, 7.4, t))
	# Dos vueltas en el tramo 2 y una en el gran final: son 1080°, así que termina mirando como empezó
	var yaw := YAW + 720.0 * smoothstep(1.2, 4.0, t) + 360.0 * smoothstep(5.9, 7.0, t)
	# Reverencias: rápidas girando, lentas de frente, y una última al cerrar
	var rapida := pow(maxf(0.5 - 0.5 * cos(TAU * t / 0.9), 0.0), 1.3)
	var lenta := pow(maxf(0.5 - 0.5 * cos(TAU * (t - 4.0) / 1.6), 0.0), 1.2)
	var reverencia := clampf(rapida * circula + lenta * frente + _campana(7.2, 8.0, t) * 0.8, 0.0, 1.0)
	# El buche que late al arrullar (más rápido en el gran final)
	var pulso := reverencia * (0.5 + 0.5 * sin(t * TAU * 6.5)) + gran * (0.5 + 0.5 * sin(t * TAU * 9.0))
	var paso := t * TAU * 3.2

	# Cuerpo: gira en círculo (se corre en una órbita chica a medida que gira), se agacha en cada
	# reverencia y pega un saltito en el final
	var angulo := deg_to_rad(yaw)
	p.pos = Vector3(sin(angulo), 0.0, cos(angulo)) * 0.11 * circula
	p.pos.y = 0.012 * absf(sin(paso)) * circula + 0.015 * infla - 0.025 * reverencia + 0.11 * _campana(6.2, 6.9, t)
	var cabeceo := 30.0 * reverencia - 7.0 * gran * (1.0 - reverencia) - 6.0 * infla * (1.0 - reverencia)
	p.rot = _y(yaw) * _z(3.0 * sin(t * TAU * 9.0) * gran) * _x(cabeceo)

	# Cabeza: baja en la reverencia, sube en el final, y el cuello se hincha (escala)
	p.cabeza = _y(9.0 * sin(t * TAU * 6.5) * reverencia) * _z(8.0 * sin(t * TAU * 0.8) * circula) \
		* _x(24.0 * reverencia - 14.0 * gran * (1.0 - reverencia) - 5.0 * infla)
	p.escala_cabeza = Vector3.ONE * (1.0 + 0.22 * infla + 0.07 * pulso)

	# Alas: caídas y temblando mientras se pavonea; abiertas y en alto en el gran final
	var abrir := 16.0 + 14.0 * infla + 44.0 * gran
	var subir := -10.0 * infla * (1.0 - gran) + 55.0 * gran
	p.ala_izq = _ala_izq(abrir + 3.0 * sin(t * TAU * 8.0) * infla, subir + 2.0 * sin(t * TAU * 8.0) * infla)
	p.ala_der = _ala_der(abrir + 3.0 * sin(t * TAU * 8.0 + 1.3) * infla, subir + 2.0 * sin(t * TAU * 8.0 + 1.3) * infla)

	# Patas: pasitos alternados al girar, listas para saltar en el final
	var s := sin(paso)
	p.pata_izq = _x(-22.0 * maxf(s, 0.0) * circula - 8.0 * gran)
	p.pata_der = _x(-22.0 * maxf(-s, 0.0) * circula - 8.0 * gran)

	# Cola: se levanta, se abre en abanico (escala en el ancho) y tiembla
	p.cola = _x(12.0 * abanico + 20.0 * reverencia) * _y(5.0 * sin(t * TAU * 2.0) * abanico)
	p.escala_cola = Vector3(1.0 + 0.95 * abanico + 0.05 * sin(t * TAU * 9.0) * abanico * (0.5 + gran), 1.0, 1.0 + 0.15 * abanico)
	return p


# ---------------------------------------------------------------- Baño (fuentes y charcos)

## Cómo se baña una paloma de verdad (4,8 s en bucle; arranca y termina igual): se agacha en el agua,
## zambulle el pecho y la cabeza una y otra vez mientras aletea rápido con las alas medio abiertas,
## se balancea de un lado al otro y, antes de volver a empezar, se sacude con las plumas esponjadas.
static func _bano(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var zambulle := pow(maxf(0.5 - 0.5 * cos(TAU * t / 1.2), 0.0), 1.2)   # 0 = cabeza arriba, 1 = en el agua
	var aleteo := sin(t * TAU * 5.0)
	var aleteo_der := sin(t * TAU * 5.0 + 0.9)
	var vaiven := sin(t * TAU / 0.6)
	var sacude := _campana(3.5, 4.6, t)                          # El sacudón de plumas del final
	var temblor := sin(t * TAU * 10.0) * sacude

	p.pos = Vector3(0.012 * vaiven, -0.04 - 0.012 * zambulle + 0.035 * sacude, 0.0)
	p.rot = _y(YAW + 16.0 * temblor) * _z(9.0 * vaiven * (1.0 - sacude)) * _x(4.0 + 12.0 * zambulle)
	p.cabeza = _y(12.0 * sin(t * TAU * 10.0) * zambulle + 14.0 * temblor) * _x(34.0 * zambulle - 8.0 * sacude)
	p.escala_cabeza = Vector3.ONE * (1.0 + 0.08 * sacude)          # Plumas esponjadas
	p.ala_izq = _ala_izq(50.0 + 10.0 * zambulle + 9.0 * aleteo + 32.0 * sacude, 12.0 + 18.0 * aleteo + 30.0 * sacude)
	p.ala_der = _ala_der(50.0 + 10.0 * zambulle + 9.0 * aleteo_der + 32.0 * sacude, 12.0 + 18.0 * aleteo_der + 30.0 * sacude)
	p.cola = _x(8.0 + 10.0 * zambulle) * _y(20.0 * sin(t * TAU * 5.0 + 1.0))
	p.escala_cola = Vector3(1.0 + 0.45 * sacude, 1.0, 1.0)
	p.pata_izq = _x(-10.0 * maxf(vaiven, 0.0))
	p.pata_der = _x(-10.0 * maxf(-vaiven, 0.0))
	return p


# ---------------------------------------------------------------- Final: la paloma flaca

## El cierre de los créditos: saltitos, una vuelta de carnero hacia atrás, una pirueta con las alas
## abiertas y la pose final con las alas arriba.
static func _voltereta(t: float) -> PoseBaile:
	var a := _salto(t * 1.15)
	a.rot = _y(YAW + 360.0 * smoothstep(0.2, 1.6, t))
	var b := _voltereta_aire(t)
	var c := _pirueta_final(t)
	var d := _pose_final(t)
	var p := a.mezclar(b, smoothstep(1.45, 1.75, t))
	p = p.mezclar(c, smoothstep(3.25, 3.55, t))
	return p.mezclar(d, smoothstep(5.0, 5.4, t))


static func _voltereta_aire(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var agacha := _campana(1.6, 2.0, t)               # Se agacha para tomar impulso...
	var u := clampf((t - 2.0) / 1.0, 0.0, 1.0)         # ...salta y da la vuelta entera en un segundo
	var cae := _campana(3.0, 3.35, t)                 # y amortigua al caer
	p.pos = Vector3(0.0, 0.62 * 4.0 * u * (1.0 - u) - 0.07 * agacha - 0.06 * cae, 0.0)
	p.rot = _y(YAW) * _x(-360.0 * smoothstep(0.0, 1.0, u))
	var recogida := sin(clampf(u, 0.0, 1.0) * PI)       # Alas y patas recogidas en el aire
	p.ala_izq = _ala_izq(20.0 - 18.0 * recogida + 60.0 * agacha, -10.0 * agacha)
	p.ala_der = _ala_der(20.0 - 18.0 * recogida + 60.0 * agacha, -10.0 * agacha)
	p.pata_izq = _x(-60.0 * recogida)
	p.pata_der = _x(-60.0 * recogida)
	p.cabeza = _x(30.0 * recogida + 12.0 * agacha)
	return p


static func _pirueta_final(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	var giro := 2.0 * 360.0 * smoothstep(3.3, 5.1, t)
	p.rot = _y(YAW + giro) * _x(12.0)
	p.pos = Vector3(0.0, 0.03 + 0.05 * _campana(3.3, 5.1, t), 0.0)
	p.ala_izq = _ala_izq(88.0, 12.0)
	p.ala_der = _ala_der(88.0, 12.0)
	p.pata_der = _x(45.0)
	p.cabeza = _x(-14.0) * _z(8.0)
	p.cola = _x(30.0)
	return p


static func _pose_final(t: float) -> PoseBaile:
	var p := PoseBaile.new()
	p.rot = _y(YAW) * _z(sin(t * 4.0) * 3.0)
	p.pos = Vector3(0.0, 0.04 + 0.025 * absf(sin(t * TAU * 1.2)), 0.0)
	p.ala_izq = _ala_izq(45.0, 85.0)
	p.ala_der = _ala_der(45.0, 85.0)
	p.cabeza = _x(-12.0) * _z(10.0)
	p.cola = _x(32.0) * _y(12.0 * sin(t * 8.0))
	p.pata_izq = _x(-10.0)
	p.pata_der = _x(-10.0)
	return p
