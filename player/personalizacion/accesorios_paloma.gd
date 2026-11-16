class_name AccesoriosPaloma
extends RefCounted
## Fábrica de accesorios hechos con primitivas (colores fijos). Cada uno devuelve un Node3D con las
## piezas ubicadas en el espacio del GLB (la paloma mira a +Z, la cabeza ocupa y 0.3..0.5 y z 0..0.2,
## el pico sale al frente hasta z 0.25, el lomo está en y 0.3 y la cola va hacia -Z).
## AplicadorPaloma lo cuelga de un BoneAttachment3D. Sin colisión, sin sombra propia, sin scripts:
## sólo siguen al hueso, así que no tocan las animaciones. Los materiales se cachean por color.

const NEGRO := Color("26262e")
const ROJO := Color("c8423a")
const AMARILLO := Color("f2c84b")
const AZUL := Color("3c78c8")
const ROSA := Color("ff6fa5")
const CELESTE := Color("8fd3f0")
const VERDE := Color("5fb86a")
const MARRON := Color("5a3a24")
const GRIS := Color("8a8a96")
const NARANJA := Color("f08a3a")
const ORO := Color("e2b53c")
const BLANCO := Color("f6f4ee")
const TELA := Color("e9e6dc")        ## Blanco de tela (capucha y capa de asesino)
const MARFIL := Color("efe3c2")
const PLATA := Color("c9ccd4")
const AZUL_MARINO := Color("2c3550")

## Centro del cuello (en la base de la cabeza): ahí van los collares, en el espacio del GLB.
const CUELLO := Vector3(0.0, 0.315, 0.1)


## Arma el accesorio "opcion" (1..n; 0 = ninguno) del slot "slot" del catálogo. Null si es "ninguno".
static func crear(slot: int, opcion: int) -> Node3D:
	if opcion <= 0:
		return null
	var raiz := Node3D.new()
	raiz.name = "Pieza"
	match CatalogoPaloma.SLOTS[slot]["clave"]:
		"cabeza":
			match opcion:
				1: _gorra(raiz)
				2: _monio(raiz, Vector3(0.0, 0.515, 0.06), ROSA, 1.0)
				3: _copa(raiz)
				4: _antenas(raiz)
				5: _boina(raiz)
				6: _corona(raiz)
				7: _gorro_lana(raiz)
				8: _sombrero_gaucho(raiz)
				9: _capucha_asesino(raiz)
				10: _casco_vikingo(raiz)
				11: _gorrito_cumple(raiz)
				12: _gorro_chef(raiz)
				13: _auriculares(raiz)
		"espalda":
			match opcion:
				1: _mochila(raiz)
				2: _capa(raiz)
				3: _jetpack(raiz)
				4: _capa_asesino(raiz)
				5: _termo_mate(raiz)
				6: _alas_angel(raiz)
		"ojos":
			match opcion:
				1: _gafas_sol(raiz)
				2: _gafas_aviador(raiz)
				3: _lentes_redondos(raiz)
				4: _gafas_3d(raiz)
				5: _antifaz(raiz)
				6: _monoculo(raiz)
				7: _visor(raiz)
		"cuello":
			match opcion:
				1: _cadena_oro(raiz)
				2: _perlas(raiz)
				3: _bufanda(raiz)
				4: _monio_gala(raiz)
				5: _medalla(raiz)
				6: _panuelo(raiz)
				7: _pinchos(raiz)
				8: _cascabel(raiz)
			# Un poco más arriba que la unión con el cuerpo: si no, el collar queda medio enterrado
			raiz.position.y = 0.02
		"cola":
			match opcion:
				1: _monio(raiz, Vector3(0.0, 0.29, -0.33), CELESTE, 0.9)
				2: _cinta(raiz)
				3: _plumas(raiz)
		"pico":
			match opcion:
				1: _bigote(raiz)
				2: _pipa(raiz)
				3: _anteojos(raiz)
	return raiz


# ---------------------------------------------------------------- Cabeza

static func _gorra(r: Node3D) -> void:
	_caja(r, Vector3(0.215, 0.05, 0.215), Vector3(0.0, 0.525, 0.1), ROJO)
	_caja(r, Vector3(0.17, 0.014, 0.1), Vector3(0.0, 0.512, 0.255), NEGRO)    # Visera
	_esfera(r, 0.02, Vector3(0.0, 0.557, 0.1), AMARILLO)                       # Pompón


static func _monio(r: Node3D, centro: Vector3, color: Color, escala: float) -> void:
	for lado in [-1.0, 1.0]:
		var ala := _caja(r, Vector3(0.07, 0.045, 0.035) * escala, centro + Vector3(0.045 * lado * escala, 0.0, 0.0), color)
		ala.rotation.z = -0.35 * lado
	_caja(r, Vector3(0.035, 0.035, 0.04) * escala, centro, color.darkened(0.25))


static func _copa(r: Node3D) -> void:
	_cilindro(r, 0.15, 0.15, 0.014, Vector3(0.0, 0.507, 0.09), NEGRO)         # Ala
	_cilindro(r, 0.095, 0.095, 0.14, Vector3(0.0, 0.58, 0.09), NEGRO)          # Copa
	_cilindro(r, 0.099, 0.099, 0.03, Vector3(0.0, 0.53, 0.09), ROJO)           # Cinta


static func _antenas(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		var tallo := _cilindro(r, 0.005, 0.005, 0.13, Vector3(0.04 * lado, 0.565, 0.06), NEGRO)
		tallo.rotation.z = -0.3 * lado
		_esfera(r, 0.02, Vector3(0.0592 * lado, 0.629, 0.06), AMARILLO if lado < 0.0 else NARANJA)


static func _boina(r: Node3D) -> void:
	var b := _esfera(r, 0.125, Vector3(-0.015, 0.515, 0.085), AZUL_MARINO)
	b.scale = Vector3(1.05, 0.38, 1.0)
	b.rotation.z = 0.18
	_cilindro(r, 0.008, 0.008, 0.03, Vector3(-0.03, 0.56, 0.085), AZUL_MARINO)   # El palito de arriba


static func _corona(r: Node3D) -> void:
	_cilindro(r, 0.1, 0.1, 0.05, Vector3(0.0, 0.53, 0.095), ORO)
	for i in 6:
		var a := i * TAU / 6.0
		_cilindro(r, 0.0, 0.022, 0.06, Vector3(sin(a) * 0.088, 0.585, 0.095 + cos(a) * 0.088), ORO)
	var joyas := [ROJO, AZUL, VERDE]
	for i in 3:
		var a := (i - 1) * 0.9
		_esfera(r, 0.014, Vector3(sin(a) * 0.101, 0.53, 0.095 + cos(a) * 0.101), joyas[i])


static func _gorro_lana(r: Node3D) -> void:
	var g := _esfera(r, 0.112, Vector3(0.0, 0.5, 0.095), CELESTE)
	g.scale = Vector3(1.0, 0.85, 1.0)
	_cilindro(r, 0.097, 0.097, 0.018, Vector3(0.0, 0.55, 0.095), BLANCO)    # Raya
	_cilindro(r, 0.117, 0.117, 0.04, Vector3(0.0, 0.505, 0.095), BLANCO)    # Doblez
	_esfera(r, 0.032, Vector3(0.0, 0.6, 0.095), BLANCO)                     # Pompón


static func _sombrero_gaucho(r: Node3D) -> void:
	_cilindro(r, 0.175, 0.175, 0.012, Vector3(0.0, 0.508, 0.09), NEGRO)     # Ala ancha
	_cilindro(r, 0.092, 0.1, 0.07, Vector3(0.0, 0.55, 0.09), NEGRO)         # Copa chata
	_cilindro(r, 0.101, 0.101, 0.015, Vector3(0.0, 0.522, 0.09), ROJO)      # Cinta


## La de Assassin's Creed: tapa arriba, costados y nuca, con la punta sobre la frente.
static func _capucha_asesino(r: Node3D) -> void:
	_caja(r, Vector3(0.235, 0.03, 0.215), Vector3(0.0, 0.515, 0.085), TELA)          # Arriba
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.025, 0.2, 0.215), Vector3(0.118 * lado, 0.42, 0.085), TELA)  # Costados
	_caja(r, Vector3(0.235, 0.22, 0.03), Vector3(0.0, 0.415, -0.025), TELA)          # Nuca
	_caja(r, Vector3(0.235, 0.03, 0.03), Vector3(0.0, 0.5, 0.19), TELA)              # Borde de adelante
	var punta := _caja(r, Vector3(0.07, 0.025, 0.07), Vector3(0.0, 0.51, 0.2), TELA)
	punta.rotation.y = PI / 4.0
	_caja(r, Vector3(0.237, 0.012, 0.032), Vector3(0.0, 0.487, 0.19), ROJO)          # Ribete
	_caja(r, Vector3(0.2, 0.03, 0.01), Vector3(0.0, 0.468, 0.203), Color("4a4a52"))  # Sombra de la abertura
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.01, 0.12, 0.012), Vector3(0.104 * lado, 0.41, 0.203), Color("4a4a52"))


static func _casco_vikingo(r: Node3D) -> void:
	var c := _esfera(r, 0.118, Vector3(0.0, 0.49, 0.095), GRIS)
	c.scale = Vector3(1.0, 0.8, 1.0)
	_cilindro(r, 0.121, 0.121, 0.03, Vector3(0.0, 0.49, 0.095), MARRON)
	for lado in [-1.0, 1.0]:
		var cuerno := _cilindro(r, 0.0, 0.026, 0.11, Vector3(0.13 * lado, 0.545, 0.095), MARFIL)
		cuerno.rotation.z = -0.75 * lado


static func _gorrito_cumple(r: Node3D) -> void:
	var cono := _cilindro(r, 0.0, 0.065, 0.17, Vector3(0.02, 0.585, 0.09), ROSA)
	cono.rotation.z = -0.15
	_esfera(r, 0.025, Vector3(0.033, 0.675, 0.09), AMARILLO)


static func _gorro_chef(r: Node3D) -> void:
	_cilindro(r, 0.09, 0.09, 0.07, Vector3(0.0, 0.535, 0.09), BLANCO)
	var copa := _esfera(r, 0.11, Vector3(0.0, 0.61, 0.09), BLANCO)
	copa.scale = Vector3(1.15, 0.75, 1.15)


static func _auriculares(r: Node3D) -> void:
	_caja(r, Vector3(0.2, 0.022, 0.04), Vector3(0.0, 0.525, 0.08), NEGRO)
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.02, 0.08, 0.04), Vector3(0.11 * lado, 0.49, 0.08), NEGRO)
		var copa := _cilindro(r, 0.04, 0.04, 0.035, Vector3(0.122 * lado, 0.43, 0.08), NEGRO)
		copa.rotation.z = PI / 2.0
		var tapa := _cilindro(r, 0.03, 0.03, 0.01, Vector3(0.141 * lado, 0.43, 0.08), ROJO)
		tapa.rotation.z = PI / 2.0


# ---------------------------------------------------------------- Espalda

static func _mochila(r: Node3D) -> void:
	_caja(r, Vector3(0.15, 0.1, 0.1), Vector3(0.0, 0.355, -0.09), AZUL)
	_caja(r, Vector3(0.1, 0.045, 0.02), Vector3(0.0, 0.34, -0.15), AMARILLO)   # Bolsillo
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.018, 0.008, 0.2), Vector3(0.06 * lado, 0.304, -0.04), NEGRO)   # Correas


static func _capa(r: Node3D) -> void:
	_caja(r, Vector3(0.27, 0.014, 0.3), Vector3(0.0, 0.31, -0.04), ROJO)
	_caja(r, Vector3(0.2, 0.012, 0.06), Vector3(0.0, 0.318, 0.1), ROJO.lightened(0.15))
	_esfera(r, 0.014, Vector3(0.0, 0.315, 0.13), AMARILLO)                     # Broche


static func _jetpack(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_cilindro(r, 0.035, 0.035, 0.13, Vector3(0.05 * lado, 0.37, -0.09), GRIS)
		_cilindro(r, 0.036, 0.036, 0.02, Vector3(0.05 * lado, 0.435, -0.09), ROJO)
		_cilindro(r, 0.0, 0.03, 0.05, Vector3(0.05 * lado, 0.28, -0.09), NARANJA)  # Llama


static func _capa_asesino(r: Node3D) -> void:
	_caja(r, Vector3(0.28, 0.014, 0.36), Vector3(0.0, 0.305, -0.07), TELA)
	_caja(r, Vector3(0.29, 0.03, 0.03), Vector3(0.0, 0.3, 0.08), ROJO)            # Faja
	var emblema := _caja(r, Vector3(0.04, 0.006, 0.04), Vector3(0.0, 0.314, -0.05), ROJO)
	emblema.rotation.y = PI / 4.0


## Bien porteño: el termo en la espalda y el mate con la bombilla.
static func _termo_mate(r: Node3D) -> void:
	_cilindro(r, 0.035, 0.035, 0.16, Vector3(0.05, 0.38, -0.09), Color("2f6b4a"))      # Termo
	_cilindro(r, 0.03, 0.035, 0.025, Vector3(0.05, 0.47, -0.09), NEGRO)               # Tapón
	_esfera(r, 0.04, Vector3(-0.05, 0.36, -0.09), Color("8b5a2b"))                   # Mate
	_cilindro(r, 0.03, 0.03, 0.01, Vector3(-0.05, 0.395, -0.09), VERDE)              # Yerba
	var bombilla := _cilindro(r, 0.004, 0.004, 0.08, Vector3(-0.04, 0.42, -0.09), PLATA)
	bombilla.rotation.z = -0.25
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.018, 0.008, 0.2), Vector3(0.06 * lado, 0.304, -0.04), MARRON)   # Correas


static func _alas_angel(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		var ala := _caja(r, Vector3(0.16, 0.012, 0.09), Vector3(0.11 * lado, 0.38, -0.08), BLANCO)
		ala.rotation.z = 0.6 * lado
		var punta := _caja(r, Vector3(0.09, 0.012, 0.06), Vector3(0.19 * lado, 0.44, -0.1), BLANCO)
		punta.rotation.z = 0.9 * lado


# ---------------------------------------------------------------- Ojos
# La paloma tiene los ojos a los COSTADOS de la cabeza (como las palomas de verdad): un cuadrado
# amarillo en cada cara lateral, que sobresale hasta x = ±0.125, en y 0.375..0.45 y z 0.075..0.15
# (medido sobre la textura del GLB). La cara de adelante está en z 0.2 y los costados en x ±0.1.
# Así que cada lente va pegado al costado, sobre su ojo, y el armazón da la vuelta por delante de
# la frente (el puente) y sigue hacia atrás (las patillas).

const OJO := Vector3(0.125, 0.4125, 0.1125)   ## Centro del ojo derecho (el izquierdo, con x negativa)
const FRENTE_Z := 0.2                          ## Cara de adelante de la cabeza
const COSTADO_X := 0.1                         ## Caras de los costados


## Lente rectangular sobre el ojo de un lado: cristal y marco de cuatro barras (en el plano YZ).
static func _lente(r: Node3D, lado: float, alto: float, largo: float, color_lente: Color, color_marco: Color,
		marco := 0.012) -> void:
	var x := (OJO.x + 0.006) * lado
	_caja(r, Vector3(0.006, alto, largo), Vector3(x, OJO.y, OJO.z), color_lente)
	var xm := (OJO.x + 0.008) * lado
	for s in [-1.0, 1.0]:
		_caja(r, Vector3(0.012, marco, largo + marco * 2.0), Vector3(xm, OJO.y + s * (alto + marco) / 2.0, OJO.z), color_marco)
		_caja(r, Vector3(0.012, alto, marco), Vector3(xm, OJO.y, OJO.z + s * (largo + marco) / 2.0), color_marco)


## Lente redondo sobre el ojo de un lado (disco y aro, con el eje hacia el costado).
static func _lente_redondo(r: Node3D, lado: float, radio: float, color_lente: Color, color_marco: Color) -> void:
	var disco := _cilindro(r, radio, radio, 0.006, Vector3((OJO.x + 0.006) * lado, OJO.y, OJO.z), color_lente)
	disco.rotation.z = PI / 2.0
	var aro := _toro(r, radio, radio + 0.008, Vector3((OJO.x + 0.008) * lado, OJO.y, OJO.z), color_marco)
	aro.rotation.z = PI / 2.0


## Armazón: de cada lente hacia adelante, el puente que cruza por delante de la frente y las
## patillas hacia la nuca. "borde" = hasta dónde llega el lente hacia adelante y hacia atrás.
static func _armazon(r: Node3D, color: Color, borde := 0.05, y_puente := 0.45, grueso := 0.012) -> void:
	var xa := COSTADO_X + 0.012
	for lado in [-1.0, 1.0]:
		var z0 := OJO.z + borde
		_caja(r, Vector3(grueso, grueso, FRENTE_Z + 0.008 - z0), Vector3(xa * lado, y_puente, (z0 + FRENTE_Z + 0.008) / 2.0), color)
		var zt := OJO.z - borde
		_caja(r, Vector3(grueso, grueso, zt + 0.01), Vector3(xa * lado, OJO.y + 0.015, (zt - 0.01) / 2.0), color)   # Patilla
	_caja(r, Vector3(xa * 2.0 + grueso, grueso, grueso), Vector3(0.0, y_puente, FRENTE_Z + 0.008), color)   # Puente


static func _gafas_sol(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_lente(r, lado, 0.075, 0.09, Color("1c1c26"), NEGRO, 0.014)
		_caja(r, Vector3(0.002, 0.008, 0.025), Vector3((OJO.x + 0.01) * lado, OJO.y + 0.02, OJO.z + 0.02), BLANCO)   # Brillo
	_armazon(r, NEGRO, 0.059, 0.45, 0.014)


static func _gafas_aviador(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_lente(r, lado, 0.08, 0.09, Color("3d5a3a"), ORO, 0.007)
		_caja(r, Vector3(0.006, 0.02, 0.06), Vector3((OJO.x + 0.006) * lado, OJO.y - 0.048, OJO.z + 0.008), Color("3d5a3a"))  # Gota
	_armazon(r, ORO, 0.052, 0.452, 0.007)
	_caja(r, Vector3((COSTADO_X + 0.012) * 2.0, 0.007, 0.007), Vector3(0.0, 0.438, FRENTE_Z + 0.008), ORO)   # Doble puente


static func _lentes_redondos(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_lente_redondo(r, lado, 0.042, Color("7a4a9a"), ORO)
	_armazon(r, ORO, 0.048, 0.445, 0.007)


static func _gafas_3d(r: Node3D) -> void:
	_lente(r, -1.0, 0.075, 0.09, ROJO, BLANCO, 0.016)
	_lente(r, 1.0, 0.075, 0.09, Color("2fc6d8"), BLANCO, 0.016)
	_armazon(r, BLANCO, 0.061, 0.45, 0.016)


## Antifaz de ladrón: una franja negra que da la vuelta a la cabeza, con un agujero en cada ojo.
static func _antifaz(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		var xm: float = (OJO.x + 0.006) * lado
		for s in [-1.0, 1.0]:
			_caja(r, Vector3(0.012, 0.022, 0.13), Vector3(xm, OJO.y + s * 0.048, OJO.z), NEGRO)    # Arriba y abajo del ojo
			_caja(r, Vector3(0.012, 0.075, 0.025), Vector3(xm, OJO.y, OJO.z + s * 0.052), NEGRO)    # Adelante y atrás del ojo
		_caja(r, Vector3(0.012, 0.06, 0.045), Vector3((COSTADO_X + 0.006) * lado, OJO.y, 0.18), NEGRO)   # Hasta la frente
		_caja(r, Vector3(0.012, 0.03, 0.06), Vector3((COSTADO_X + 0.006) * lado, OJO.y + 0.01, 0.025), NEGRO)  # Tira a la nuca
	_caja(r, Vector3(COSTADO_X * 2.0 + 0.024, 0.06, 0.012), Vector3(0.0, OJO.y + 0.005, FRENTE_Z + 0.006), NEGRO)   # Frente
	_caja(r, Vector3(COSTADO_X * 2.0 + 0.024, 0.03, 0.012), Vector3(0.0, OJO.y + 0.01, -0.006), NEGRO)             # Nuca
	for lado in [-1.0, 1.0]:
		var punta := _caja(r, Vector3(0.012, 0.012, 0.05), Vector3(0.02 * lado, OJO.y - 0.01, -0.025), NEGRO)      # Nudo
		punta.rotation.y = 0.5 * lado


static func _monoculo(r: Node3D) -> void:
	_lente_redondo(r, 1.0, 0.045, Color("cfe8f0"), ORO)
	var cadena := _cilindro(r, 0.003, 0.003, 0.14, Vector3(OJO.x + 0.012, OJO.y - 0.1, OJO.z - 0.03), ORO)
	cadena.rotation.x = 0.4


## Visor futurista: una banda celeste que envuelve la cabeza a la altura de los ojos.
static func _visor(r: Node3D) -> void:
	var celeste := Color("39e0ff")
	var y := OJO.y
	_caja(r, Vector3(COSTADO_X * 2.0 + 0.04, 0.07, 0.014), Vector3(0.0, y, FRENTE_Z + 0.007), celeste)   # Frente
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.014, 0.085, 0.15), Vector3((OJO.x + 0.007) * lado, y, 0.13), celeste)        # Costados, sobre el ojo
		_caja(r, Vector3(0.026, 0.026, 0.03), Vector3((OJO.x + 0.012) * lado, y, 0.04), GRIS)          # Botón
	for s in [-1.0, 1.0]:
		_caja(r, Vector3(COSTADO_X * 2.0 + 0.044, 0.008, 0.018), Vector3(0.0, y + s * 0.039, FRENTE_Z + 0.008), NEGRO)
		for lado in [-1.0, 1.0]:
			_caja(r, Vector3(0.018, 0.008, 0.154), Vector3((OJO.x + 0.008) * lado, y + s * 0.046, 0.13), NEGRO)


# ---------------------------------------------------------------- Cuello (en la base de la cabeza)

static func _cadena_oro(r: Node3D) -> void:
	_toro(r, 0.1, 0.124, CUELLO, ORO)
	var segunda := _toro(r, 0.102, 0.12, CUELLO + Vector3(0, -0.014, 0.004), ORO.darkened(0.12))
	segunda.rotation.x = 0.1
	_cilindro(r, 0.004, 0.004, 0.035, Vector3(0.0, 0.29, 0.214), ORO)
	var medallon := _cilindro(r, 0.028, 0.028, 0.01, Vector3(0.0, 0.265, 0.218), ORO)
	medallon.rotation.x = PI / 2.0


static func _perlas(r: Node3D) -> void:
	for i in 16:
		var a := i * TAU / 16.0
		var caida := 0.012 * (1.0 + cos(a)) / 2.0   # Cuelga un poco más adelante
		_esfera(r, 0.015, CUELLO + Vector3(sin(a) * 0.112, -caida, cos(a) * 0.112), Color("f4f0e6"))


static func _bufanda(r: Node3D) -> void:
	var colores := [CELESTE, BLANCO, CELESTE]
	for i in 3:
		_toro(r, 0.088, 0.125, CUELLO + Vector3(0, (1 - i) * 0.022, 0), colores[i])
	var punta := _caja(r, Vector3(0.05, 0.13, 0.02), Vector3(0.06, 0.25, 0.205), CELESTE)
	punta.rotation.z = 0.15
	var raya := _caja(r, Vector3(0.051, 0.025, 0.021), Vector3(0.06, 0.25, 0.206), BLANCO)
	raya.rotation.z = 0.15


static func _monio_gala(r: Node3D) -> void:
	_toro(r, 0.1, 0.112, CUELLO, BLANCO)
	_monio(r, Vector3(0.0, 0.3, 0.215), NEGRO, 1.1)


static func _medalla(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		var cinta := _caja(r, Vector3(0.02, 0.09, 0.006), Vector3(0.03 * lado, 0.28, 0.21), AZUL)
		cinta.rotation.z = -0.35 * lado
	var m := _cilindro(r, 0.032, 0.032, 0.01, Vector3(0.0, 0.235, 0.215), ORO)
	m.rotation.x = PI / 2.0
	var estrella := _caja(r, Vector3(0.02, 0.02, 0.004), Vector3(0.0, 0.235, 0.221), ORO.darkened(0.25))
	estrella.rotation.z = PI / 4.0


static func _panuelo(r: Node3D) -> void:
	_toro(r, 0.1, 0.11, CUELLO, ROJO)
	var tri := _caja(r, Vector3(0.11, 0.11, 0.01), Vector3(0.0, 0.275, 0.205), ROJO)
	tri.rotation.z = PI / 4.0
	for p in [Vector3(-0.02, 0.27, 0.211), Vector3(0.022, 0.255, 0.211), Vector3(0.0, 0.235, 0.211)]:
		_esfera(r, 0.008, p, BLANCO)


static func _pinchos(r: Node3D) -> void:
	_toro(r, 0.1, 0.126, CUELLO, NEGRO)
	for i in 8:
		var a := i * TAU / 8.0
		var pincho := _cilindro(r, 0.0, 0.015, 0.05, CUELLO + Vector3(sin(a), 0, cos(a)) * 0.14, PLATA)
		pincho.rotation = Vector3(PI / 2.0, a, 0.0)   # Apunta hacia afuera


static func _cascabel(r: Node3D) -> void:
	_toro(r, 0.1, 0.11, CUELLO, ROJO)
	_esfera(r, 0.025, Vector3(0.0, 0.275, 0.214), ORO)
	_caja(r, Vector3(0.03, 0.004, 0.004), Vector3(0.0, 0.27, 0.238), NEGRO)


# ---------------------------------------------------------------- Cola

static func _cinta(r: Node3D) -> void:
	_caja(r, Vector3(0.03, 0.008, 0.2), Vector3(0.0, 0.245, -0.5), VERDE)
	_caja(r, Vector3(0.04, 0.03, 0.03), Vector3(0.0, 0.245, -0.405), VERDE.darkened(0.2))


static func _plumas(r: Node3D) -> void:
	var colores := [ROJO, AMARILLO, AZUL]
	for i in 3:
		var g := (i - 1) * 0.35
		var p := _caja(r, Vector3(0.025, 0.01, 0.13), Vector3(sin(g) * -0.07, 0.245, -0.43 - cos(g) * 0.04), colores[i])
		p.rotation.y = g


# ---------------------------------------------------------------- Pico (se esconden con comida en el pico)

static func _bigote(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		var m := _caja(r, Vector3(0.06, 0.014, 0.016), Vector3(0.038 * lado, 0.326, 0.214), MARRON)
		m.rotation.z = 0.25 * lado


static func _pipa(r: Node3D) -> void:
	var tallo := _cilindro(r, 0.007, 0.007, 0.1, Vector3(0.048, 0.335, 0.25), MARRON)
	tallo.rotation.x = PI * 0.5
	_cilindro(r, 0.02, 0.016, 0.045, Vector3(0.048, 0.355, 0.305), MARRON.darkened(0.2))


## Anteojos de leer (los de antes): ahora también sobre los ojos de los costados (ver "Ojos").
static func _anteojos(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_lente(r, lado, 0.06, 0.075, CELESTE, NEGRO, 0.01)
	_armazon(r, NEGRO, 0.048, 0.44, 0.01)


# ---------------------------------------------------------------- Piezas

static func _caja(r: Node3D, tam: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return _pieza(r, m, pos, color)


static func _cilindro(r: Node3D, radio_arriba: float, radio_abajo: float, alto: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radio_arriba
	m.bottom_radius = radio_abajo
	m.height = alto
	m.radial_segments = 8
	m.rings = 1
	return _pieza(r, m, pos, color)


static func _esfera(r: Node3D, radio: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radio
	m.height = radio * 2.0
	m.radial_segments = 8
	m.rings = 4
	return _pieza(r, m, pos, color)


## Aro (TorusMesh): acostado en el plano XZ, como un collar.
static func _toro(r: Node3D, radio_int: float, radio_ext: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = radio_int
	m.outer_radius = radio_ext
	m.rings = 16
	m.ring_segments = 6
	return _pieza(r, m, pos, color)


static func _pieza(r: Node3D, malla: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.8)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	return mi
