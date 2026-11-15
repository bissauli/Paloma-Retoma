class_name Ciudad
extends Node3D
## La ciudad alrededor de la Plaza de Mayo (mapa V2), según el boceto del mapa:
## - Oeste: el parque (zona de palomas con su estatua, juegos con calesita, plaza en rombo, parque
##   de perros y la cucha de Bolt escondida) y, cruzando la Av. de Mayo, las manzanas comerciales
##   partidas por la Peatonal Florida.
## - Norte y sur de la plaza: más edificios (al sur, detrás de los cafés, el Pasaje Las Palomas).
## - Este: edificios al norte de Reconquista y, al sur, el barrio enemigo (casas de chapa, grafitis,
##   un potrero, autos abandonados y gatos).
## Todo rodeado de calles con veredas, árboles, faroles y carteles. Más allá del borde jugable hay una
## fila de edificios de fondo y túneles por donde entran y salen los autos (ver world/transito.gd).
## Usa las piezas de Blender de world/kit.gd. La semilla es fija: el mapa es siempre el mismo.
## Coordenadas: X = este, Z = sur. Las manzanas van por sus líneas de fachada (Rect2 en X/Z); la
## vereda de 3 m queda afuera de cada una.

# Borde jugable (paredes invisibles, ver plaza.gd) y altura del techo invisible
const X_MIN := -197.0
const X_MAX := 197.0
const Z_MIN := -112.0
const Z_MAX := 110.0
const TECHO := 41.0

const VEREDA := 3.0
const Y_VEREDA := 0.16
const Y_CALZADA := 0.01
const FONDO := 16.0          ## Profundidad de los edificios entre medianeras (y lado de las esquinas)
const T_PARQUE := 0.2        ## Superficie de las losetas del parque

# Manzanas (líneas de fachada)
const PLAZA := Rect2(-61, -40, 122, 88)
const NORTE := Rect2(-61, -112, 122, 56)
const SUR := Rect2(-61, 54, 122, 56)
const PARQUE := Rect2(-197, -112, 120, 102)
const COMERCIAL_A := Rect2(-197, 6, 120, 48)
const COMERCIAL_B := Rect2(-197, 62, 120, 48)
const ESTE := Rect2(77, -112, 120, 98)
const BARRIO := Rect2(77, 2, 120, 108)

# Calzadas de las calles: [x0, z0, x1, z1]
const BOLIVAR := [-74.0, -175.0, -64.0, 175.0]        ## Oeste de la plaza (norte-sur)
const PASEO_COLON := [64.0, -175.0, 74.0, 175.0]      ## Este de la plaza (norte-sur)
const RIVADAVIA := [-64.0, -53.0, 64.0, -43.0]        ## Norte de la plaza
const AV_DE_MAYO := [-200.0, -7.0, -74.0, 3.0]        ## Entre el parque y las comerciales
const RECONQUISTA := [74.0, -11.0, 200.0, -1.0]       ## Entre los edificios del este y el barrio
const PEATONAL := [-200.0, 54.0, -74.0, 62.0]         ## Peatonal Florida (piso peatonal)
const PASAJE := [-64.0, 48.0, 64.0, 54.0]             ## Pasaje Las Palomas, detrás de los cafés

const C_ASFALTO := Color("4a4a4f")
const C_CORDON := Color("d9d5cc")
const C_LINEA := Color("e8e4d0")
const C_TIERRA := Color("8c6a4b")
const C_POTRERO := Color("9b7653")

const POOL_CENTRO := ["ph_6_a", "ph_6_c", "casa_8_a", "dep_8_a", "clas_8_b", "ladr_8_a", "dep_10_a", "clas_10_a",
	"dep_10_b", "clas_10_c", "dep_12_a", "clas_12_a", "ladr_12_a", "clas_14_a", "dep_14_a", "mod_10_a"]
const POOL_COMERCIAL := ["mod_10_a", "mod_12_a", "mod_14_a", "ph_6_b", "ph_6_c", "casa_8_a", "ladr_8_a", "clas_10_c",
	"clas_12_a", "dep_12_a", "dep_10_a", "clas_14_a"]
const POOL_BARRIO := ["barrio_6_a", "barrio_8_a", "barrio_8_b", "barrio_10_a", "barrio_10_b", "barrio_12_a", "barrio_14_a"]
const POOL_FONDO := ["mod_10_a", "mod_12_a", "mod_14_a", "ladr_8_a", "ph_6_b", "ladr_12_a", "casa_8_a", "dep_8_a",
	"ph_6_a", "clas_10_c"]
const ESQ_CENTRO := ["esq_cupula_a", "esq_cupula_b", "esq_dep_a", "esq_ladr_a"]
const ESQ_COMERCIAL := ["esq_mod_a", "esq_cupula_a", "esq_dep_a", "esq_mod_a"]

## Negocios inventados (los nombres propios no se traducen)
const LOCALES := ["Kiosco El Pibe", "Pizzería Los Hornos", "Ferretería Don Tito", "Verdulería Los Primos",
	"Heladería La Cornisa", "Panadería La Espiga", "Lavadero Burbujas", "Almacén Don Pepe", "Café Los Gorriones",
	"Bar El Tero", "Óptica Mirada", "Peluquería Rulos", "Zapatería El Taco", "Regalería Moño", "Disquería Vinilo",
	"Cerrajería La Llave", "Mercería El Ovillo", "Fiambrería La Picada", "Juguetería El Trompo", "Bazar Todo Suelto",
	"Parrilla El Fogón", "Empanadas La Abuela", "Vinoteca El Tonel", "Pastas La Nonna", "Bicicletería Rayo",
	"Pinturería Arcoíris", "Florería Jacarandá", "Kiosco 24 Horas", "Farmacia Del Pasaje", "Librería El Gorrión",
	"Rotisería El Buen Plato", "Tintorería Planchita", "Sastrería El Botón", "Pollería Don Pollo"]
const OFICINAS := ["Seguros El Vuelo", "Banco del Palomar", "Inmobiliaria El Nido", "Estudio Contable Plumas",
	"Agencia de Viajes Migrar", "Galería Paloma", "Bolsa de Migas", "Casa de Cambio La Moneda", "Editorial El Pico",
	"Compañía de Seguros La Cornisa", "Escuela de Idiomas Arrullo", "Consultora Bandada"]

var _rng := RandomNumberGenerator.new()
var _cuerpos := {}                  ## Celda -> StaticBody3D con las colisiones de esa zona (ver _cuerpo_en)
var _mat_vereda: Material
var _mat_peatonal: Material
var _locales: Array = []
var _oficinas: Array = []


func _ready() -> void:
	name = "Ciudad"
	var t0 := Time.get_ticks_msec()
	_rng.seed = 20261115
	_mat_vereda = Construir.material_baldosas(Color("d6ccb6"), Color("b3a88f"), Vector2(0.7, 0.7))
	_mat_peatonal = Construir.material_baldosas(Color("c99a7e"), Color("a87a61"), Vector2(0.55, 0.55))
	_locales = LOCALES.duplicate()
	_oficinas = OFICINAS.duplicate()
	_suelos()
	_manzanas()
	_parque()
	_barrio()
	_peatonal()
	_pasaje()
	_props_veredas()
	_fondo()
	_puntos_de_juego()
	# Los cuerpos entran al árbol recién ahora, con todas sus formas (así cada uno se arma una sola vez)
	for c: Vector2i in _cuerpos:
		add_child(_cuerpos[c])
	# Miles de piezas pasan a ser pocas mallas grandes por celda (los árboles y props chicos van
	# aparte y se dejan de dibujar lejos)
	Construir.fusionar_estaticas(self, 64.0)
	print_verbose("Ciudad armada en %d ms" % (Time.get_ticks_msec() - t0))


## Cuerpo estático de la zona de "pos" (celdas de 48 m): miles de formas repartidas en varios
## cuerpos en vez de uno solo que cubra todo el mapa.
func _cuerpo_en(pos: Vector3) -> StaticBody3D:
	var c := Vector2i(floori(pos.x / 48.0), floori(pos.z / 48.0))
	if not _cuerpos.has(c):
		var b := StaticBody3D.new()
		b.name = "Colisiones_%d_%d" % [c.x, c.y]
		b.collision_layer = Construir.CAPA_MUNDO
		b.collision_mask = 0
		_cuerpos[c] = b
	return _cuerpos[c]


# ---------------------------------------------------------------- Suelos: calles, veredas, sendas

func _losa(x0: float, z0: float, x1: float, z1: float, arriba: float, grosor: float, color: Color, col := true) -> void:
	Construir.caja(self, Vector3((x0 + x1) / 2.0, arriba - grosor / 2.0, (z0 + z1) / 2.0),
		Vector3(x1 - x0, grosor, z1 - z0), color, col)


func _losa_mat(x0: float, z0: float, x1: float, z1: float, arriba: float, grosor: float, mat: Material) -> void:
	Construir.caja_mat(self, Vector3((x0 + x1) / 2.0, arriba - grosor / 2.0, (z0 + z1) / 2.0),
		Vector3(x1 - x0, grosor, z1 - z0), mat)


## Vereda (o piso peatonal) a 16 cm, con cordón claro en los bordes que dan a la calle (N, S, E, O).
func _vereda(x0: float, z0: float, x1: float, z1: float, cordones: String, mat: Material = null) -> void:
	_losa_mat(x0, z0, x1, z1, Y_VEREDA, 0.4, mat if mat else _mat_vereda)
	const A := 0.24
	const E := 0.01   # el cordón asoma 1 cm afuera de la vereda (sin caras superpuestas)
	for l in cordones:
		match l:
			"N": _losa(x0 - E, z0 - E, x1 + E, z0 + A, Y_VEREDA + 0.012, 0.3, C_CORDON, false)
			"S": _losa(x0 - E, z1 - A, x1 + E, z1 + E, Y_VEREDA + 0.012, 0.3, C_CORDON, false)
			"O": _losa(x0 - E, z0 - E, x0 + A, z1 + E, Y_VEREDA + 0.012, 0.3, C_CORDON, false)
			"E": _losa(x1 - A, z0 - E, x1 + E, z1 + E, Y_VEREDA + 0.012, 0.3, C_CORDON, false)


func _calzada(c: Array) -> void:
	_losa(c[0], c[1], c[2], c[3], Y_CALZADA, 0.3, C_ASFALTO)


## Línea discontinua del medio de una calle. "esquivar": tramos [desde, hasta] sin línea (cruces).
func _linea(es_x: bool, fijo: float, desde: float, hasta: float, esquivar: Array) -> void:
	var p := desde + 2.0
	while p + 3.0 < hasta - 2.0:
		var libre := true
		for e: Array in esquivar:
			if p + 3.0 > float(e[0]) - 2.0 and p < float(e[1]) + 2.0:
				libre = false
		if libre:
			if es_x:
				Construir.caja(self, Vector3(p + 1.5, 0.014, fijo), Vector3(3.0, 0.01, 0.2), C_LINEA, false)
			else:
				Construir.caja(self, Vector3(fijo, 0.014, p + 1.5), Vector3(0.2, 0.01, 3.0), C_LINEA, false)
		p += 8.0


## Senda peatonal (rayas blancas). "cruza_x": la senda va a lo largo de X (cruza una calle norte-sur).
func _senda(cx: float, cz: float, cruza_x: bool, largo: float, ancho := 3.0) -> void:
	var n := int(largo)
	for k in n:
		var o := -largo / 2.0 + 0.5 + k * largo / n
		if cruza_x:
			Construir.caja(self, Vector3(cx + o, 0.016, cz), Vector3(0.5, 0.01, ancho), C_LINEA, false)
		else:
			Construir.caja(self, Vector3(cx, 0.016, cz + o), Vector3(ancho, 0.01, 0.5), C_LINEA, false)


func _suelos() -> void:
	# Base de asfalto debajo de todo (por si queda algún hueco) y bien lejos
	_losa(-330, -270, 330, 270, -0.03, 0.3, C_ASFALTO.darkened(0.1))
	# Calzadas
	for c: Array in [BOLIVAR, PASEO_COLON, RIVADAVIA, AV_DE_MAYO, RECONQUISTA]:
		_calzada(c)
	# Calles del borde (más allá de las paredes invisibles), sin pisar Bolívar ni Paseo Colón
	for z: Array in [[-125.0, -115.0], [113.0, 123.0]]:
		for x: Array in [[-213.0, -74.0], [-64.0, 64.0], [74.0, 213.0]]:
			_calzada([x[0], z[0], x[1], z[1]])
	_calzada([-210.0, -115.0, -200.0, 113.0])
	_calzada([200.0, -115.0, 210.0, 113.0])
	# Veredas de cada manzana (la manzana entera a 16 cm, con su vereda alrededor)
	_vereda(-64, -115, 64, -53, "NSEO")           # norte
	_vereda(-64, 51, 64, 113, "SEO")              # sur (el borde norte es el pasaje)
	_vereda(-200, -115, -74, -7, "NSEO")          # parque
	_vereda(-200, 3, -74, 54, "NEO")              # comercial A (al sur, la peatonal)
	_vereda(-200, 62, -74, 113, "SEO")            # comercial B
	_vereda(-200, 54, -74, 62, "EO", _mat_peatonal)   # Peatonal Florida
	_vereda(74, -115, 200, -11, "NSEO")           # este
	_vereda(74, -1, 200, 113, "NSEO")             # barrio
	# Veredas alrededor de la plaza (la plaza está a nivel 0): oeste y este cortadas por la avenida
	_vereda(-64, -43, -61, 26, "OS")
	_vereda(-64, 34, -61, 48, "ON")
	_vereda(61, -43, 64, 26, "ES")
	_vereda(61, 34, 64, 48, "EN")
	_vereda(-61, -43, 61, -40, "N")
	_vereda(-64, 48, 64, 51, "OE")                # el pasaje sigue en la vereda del sur
	_vereda(-61, 40, 61, 48, "")                  # entre los cafés y el pasaje (los huecos entre edificios)
	# Fondo lejano: veredas debajo de los edificios de fondo
	for x: Array in [[-330.0, -74.0], [-64.0, 64.0], [74.0, 330.0]]:
		_vereda(x[0], -270, x[1], -125, "S")
		_vereda(x[0], 123, x[1], 270, "N")
	_vereda(-330, -125, -210, 123, "E")
	_vereda(210, -125, 330, 123, "O")
	# Líneas del medio
	_linea(false, -69.0, -175.0, 175.0, [[-53.0, -43.0], [-7.0, 3.0], [26.0, 34.0], [-125.0, -115.0], [113.0, 123.0]])
	_linea(false, 69.0, -175.0, 175.0, [[-53.0, -43.0], [-11.0, -1.0], [26.0, 34.0], [-125.0, -115.0], [113.0, 123.0]])
	_linea(true, -48.0, -64.0, 64.0, [])
	_linea(true, -2.0, -200.0, -74.0, [])
	_linea(true, -6.0, 74.0, 200.0, [])
	# Sendas peatonales en los cruces
	for x: float in [-62.5, 62.5]:
		_senda(x, -48.0, false, 10.0)                       # cruzando Rivadavia
	for cx: float in [-69.0, 69.0]:
		for z: float in [-54.5, -41.5, 24.5, 35.5]:
			_senda(cx, z, true, 10.0)                       # cruzando Bolívar y Paseo Colón
	_senda(-69.0, -8.5, true, 10.0)
	_senda(-69.0, 4.5, true, 10.0)
	_senda(-75.5, -2.0, false, 10.0)                        # cruzando la Av. de Mayo
	_senda(-69.0, 55.0, true, 10.0, 6.0)                    # de la peatonal al pasaje
	_senda(69.0, -12.5, true, 10.0)
	_senda(69.0, 0.5, true, 10.0)
	_senda(75.5, -6.0, false, 10.0)                         # cruzando Reconquista
	_senda(69.0, 51.0, true, 10.0, 5.0)                     # salida del pasaje


# ---------------------------------------------------------------- Edificios

## Pone una pieza del kit (con colisión) y escribe sus carteles.
func _poner(nombre: String, pos: Vector3, rot := 0.0, escala := Vector3.ONE, colision := true,
		textos := {}, con_textos := true, solo_lejos := false) -> MeshInstance3D:
	var mi := Kit.colocar(self, nombre, pos, rot, escala, _cuerpo_en(pos) if colision else null, solo_lejos)
	mi.set_meta(&"pieza", nombre)
	if not con_textos:
		return mi
	var t := Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)
	for c: Array in Kit.carteles(nombre, t):
		var tipo: String = c[4]
		var texto: String = textos.get(tipo, "")
		if texto == "" and tipo == "local":
			texto = _nombre_local(nombre)
		elif texto == "" and tipo == "kiosco":
			texto = "DIARIOS Y REVISTAS"
		if texto != "":
			_texto(c[0], c[1], texto, c[2], c[3], Color.WHITE, 55.0 if tipo == "local" else 40.0)
	return mi


func _nombre_local(pieza: String) -> String:
	var lista := _oficinas if pieza.begins_with("mod_") or pieza.begins_with("esq_mod") else _locales
	if lista.is_empty():
		lista.append_array(OFICINAS if lista == _oficinas else LOCALES)
	return lista.pop_at(_rng.randi() % lista.size())


## Texto sobre un cartel: el tamaño de letra se ajusta al ancho y al alto del cartel.
func _texto(pos: Vector3, rot_y: float, texto: String, ancho: float, alto: float, color := Color.WHITE,
		rango := 75.0) -> Label3D:
	var tam := clampi(int(minf(alto * 85.0, ancho * 100.0 / (texto.length() * 0.6 + 0.6))), 12, 64)
	var l := Construir.cartel(self, pos, texto, color, tam)
	l.rotation.y = rot_y
	l.outline_size = 6
	# Cada texto es un dibujo aparte: de lejos no se dibujan (tampoco se leerían). En el teléfono, más cerca.
	l.visibility_range_end = rango * (0.7 if Ajustes.movil else 1.0)
	return l


## Reparte "largo" metros en edificios del pool (todos los anchos son pares, de 6 a 14 m).
func _repartir(largo: float, pool: Array) -> Array[String]:
	var por_ancho := {}
	for n: String in pool:
		var w := int(KitDatos.PIEZAS[n]["ancho"])
		if not por_ancho.has(w):
			por_ancho[w] = []
		(por_ancho[w] as Array).append(n)
	var L := roundi(largo)
	var posible := PackedByteArray()
	posible.resize(L + 1)
	posible[0] = 1
	for r in range(1, L + 1):
		for w: int in por_ancho:
			if r >= w and posible[r - w] == 1:
				posible[r] = 1
				break
	var out: Array[String] = []
	var resto := L
	var anterior := ""
	while resto > 0:
		var opciones: Array[int] = []
		for w: int in por_ancho:
			if resto >= w and posible[resto - w] == 1:
				opciones.append(w)
		if opciones.is_empty():
			push_warning("Ciudad: no pude llenar %d m con edificios" % resto)
			break
		var w := opciones[_rng.randi() % opciones.size()]
		var lista: Array = (por_ancho[w] as Array).duplicate()
		if lista.size() > 1:
			lista.erase(anterior)
		anterior = lista[_rng.randi() % lista.size()]
		out.append(anterior)
		resto -= w
	return out


## Fila de edificios sobre una línea de fachada: desde "a" hacia "dir", "largo" metros, con las
## fachadas girando "rot" (0 = mirando a +Z).
func _fila(a: Vector3, dir: Vector3, largo: float, rot: float, pool: Array, colision := true,
		sombra := true, lejos := false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var d := 0.0
	for n in _repartir(largo, pool):
		var w := float(KitDatos.PIEZAS[n]["ancho"])
		var mi := _poner(n, a + dir * (d + w / 2.0), rot, Vector3.ONE, colision, {}, colision, lejos)
		if not sombra:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
		d += w
	return out


## Manzana con edificios en los lados de "lados" (N, S, E, O) y esquinas con ochava donde se tocan
## dos lados. Si "patio", el centro de la manzana es un jardín (pulmón de manzana).
func _manzana(r: Rect2, lados: String, pool: Array, esquinas: Array, patio := true) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var no := lados.contains("N") and lados.contains("O")
	var ne := lados.contains("N") and lados.contains("E")
	var so := lados.contains("S") and lados.contains("O")
	var se := lados.contains("S") and lados.contains("E")
	if so:
		_poner(esquinas[_rng.randi() % esquinas.size()], Vector3(x0, 0, z1), 0.0)
	if se:
		_poner(esquinas[_rng.randi() % esquinas.size()], Vector3(x1, 0, z1), PI / 2.0)
	if ne:
		_poner(esquinas[_rng.randi() % esquinas.size()], Vector3(x1, 0, z0), PI)
	if no:
		_poner(esquinas[_rng.randi() % esquinas.size()], Vector3(x0, 0, z0), -PI / 2.0)
	if lados.contains("S"):
		var a := x0 + (FONDO if so else 0.0)
		_fila(Vector3(a, 0, z1), Vector3.RIGHT, x1 - (FONDO if se else 0.0) - a, 0.0, pool)
	if lados.contains("N"):
		var a := x0 + (FONDO if no else 0.0)
		_fila(Vector3(a, 0, z0), Vector3.RIGHT, x1 - (FONDO if ne else 0.0) - a, PI, pool)
	if lados.contains("E"):
		var a := z0 + (FONDO if ne else 0.0)
		_fila(Vector3(x1, 0, a), Vector3.BACK, z1 - (FONDO if se else 0.0) - a, PI / 2.0, pool)
	if lados.contains("O"):
		var a := z0 + (FONDO if no else 0.0)
		_fila(Vector3(x0, 0, a), Vector3.BACK, z1 - (FONDO if so else 0.0) - a, -PI / 2.0, pool)
	if patio:
		_jardin(r.grow(-FONDO))


## Pulmón de manzana: losetas de pasto con árboles, arbustos y algún tendedero.
func _jardin(r: Rect2) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	var nx := int(r.size.x / 6.0)
	var nz := int(r.size.y / 6.0)
	var x0 := r.get_center().x - nx * 3.0
	var z0 := r.get_center().y - nz * 3.0
	for i in nx:
		for j in nz:
			var c := Vector3(x0 + 3.0 + 6.0 * i, 0.0, z0 + 3.0 + 6.0 * j)
			Kit.colocar(self, "pasto", c)
			var dado := _rng.randf()
			if dado < 0.45:
				var arbol: String = ["arbol_A", "arbol_B", "arbol_C", "arbol_E", "jacaranda", "arbol_D"][_rng.randi() % 6]
				_poner(arbol, c + Vector3(_rng.randf_range(-1.5, 1.5), T_PARQUE, _rng.randf_range(-1.5, 1.5)), _rng.randf() * TAU)
			elif dado < 0.6:
				_poner("tendedero", c + Vector3(_rng.randf_range(-1, 1), T_PARQUE, _rng.randf_range(-1, 1)),
					_rng.randf() * TAU, Vector3.ONE, false)
			if _rng.randf() < 0.5:
				var arbusto: String = ["arbusto_A", "arbusto_B", "arbusto_C", "arbusto_flores"][_rng.randi() % 4]
				_poner(arbusto, c + Vector3(_rng.randf_range(-2.4, 2.4), T_PARQUE, _rng.randf_range(-2.4, 2.4)), _rng.randf() * TAU)
	# Colisión del jardín (a la altura de las losetas)
	var forma := BoxShape3D.new()
	forma.size = Vector3(nx * 6.0, 0.2, nz * 6.0)
	Kit._forma(_cuerpo_en(Vector3(r.get_center().x, 0, r.get_center().y)), forma,
		Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, 0.1, r.get_center().y)))


func _manzanas() -> void:
	_manzana(NORTE, "NSEO", POOL_CENTRO, ESQ_CENTRO)
	_manzana(SUR, "NSEO", POOL_CENTRO, ESQ_CENTRO)
	_manzana(ESTE, "NSEO", POOL_CENTRO, ESQ_CENTRO)
	_manzana(COMERCIAL_A, "NSEO", POOL_COMERCIAL, ESQ_COMERCIAL)
	_manzana(COMERCIAL_B, "NSEO", POOL_COMERCIAL, ESQ_COMERCIAL)


# ---------------------------------------------------------------- Parque (losetas de 6 m)

## Conexiones (N, E, S, O) de cada loseta de camino sin girar.
const CONEXIONES := {
	"camino_recto": [Vector2i(0, -1), Vector2i(0, 1)],
	"camino_curva": [Vector2i(0, 1), Vector2i(1, 0)],
	"camino_t": [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)],
	"camino_cruce": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)],
	"camino_fin": [Vector2i(0, 1)],
}


## Dirección (x, z) girada k veces 90° como lo gira Node3D.rotation.y.
static func _girar(d: Vector2i, k: int) -> Vector2i:
	var r := d
	for i in posmod(k, 4):
		r = Vector2i(r.y, -r.x)
	return r


## Loseta de camino (y su giro) que conecta justo las direcciones de "con".
func _loseta_camino(con: Array[Vector2i]) -> Array:
	for nombre: String in CONEXIONES:
		var base: Array = CONEXIONES[nombre]
		if base.size() != con.size():
			continue
		for k in 4:
			var ok := true
			for d: Vector2i in base:
				if not con.has(_girar(d, k)):
					ok = false
					break
			if ok:
				return [nombre, k * PI / 2.0]
	return ["pasto", 0.0]


func _parque() -> void:
	var r := PARQUE
	var nx := 20
	var nz := 17
	var centro := func(i: int, j: int) -> Vector3:
		return Vector3(r.position.x + 3.0 + 6.0 * i, 0.0, r.position.y + 3.0 + 6.0 * j)
	# Caminos (celdas) y zonas reservadas (losetas de pasto lisas, sin árboles al azar)
	var caminos := {}
	for i in range(11, 19):
		caminos[Vector2i(i, 8)] = true           # del portón este a la plaza en rombo
	for i in range(3, 8):
		caminos[Vector2i(i, 8)] = true           # de la plaza en rombo hacia la zona de palomas
	for j in range(4, 8):
		caminos[Vector2i(3, j)] = true
	for j in range(4, 8):
		caminos[Vector2i(15, j)] = true          # a los juegos
	for j in range(10, 16):
		caminos[Vector2i(9, j)] = true           # del portón sur a la plaza en rombo
	caminos[Vector2i(8, 13)] = true              # entrada al parque de perros
	var portales := {Vector2i(19, 8): -PI / 2.0, Vector2i(9, 16): PI}
	var reservado := func(i: int, j: int) -> bool:
		var p: Vector3 = centro.call(i, j)
		if Vector2(p.x + 179.0, p.z + 94.0).length() < 15.0:
			return true                           # zona de palomas
		if i >= 12 and i <= 18 and j >= 1 and j <= 5:
			return true                           # juegos
		if absf(p.x + 140.0) + absf(p.z + 61.0) < 21.0:
			return true                           # plaza en rombo
		if i >= 1 and i <= 7 and j >= 12 and j <= 15:
			return true                           # parque de perros
		if i <= 2 and j >= 7 and j <= 9:
			return true                           # la cucha de Bolt
		return false
	for i in nx:
		for j in nz:
			var c: Vector3 = centro.call(i, j)
			var celda := Vector2i(i, j)
			var borde_o := i == 0
			var borde_e := i == nx - 1
			var borde_n := j == 0
			var borde_s := j == nz - 1
			if portales.has(celda):
				_poner("portal_faroles", c, portales[celda])
			elif (borde_n or borde_s) and (borde_o or borde_e):
				var rot := 0.0
				if borde_n and borde_o:
					rot = PI / 2.0
				elif borde_s and borde_o:
					rot = PI
				elif borde_s and borde_e:
					rot = -PI / 2.0
				_poner("muro_esquina_arbol", c, rot)
			elif borde_n or borde_s or borde_o or borde_e:
				var rot := 0.0 if borde_n else (PI if borde_s else (PI / 2.0 if borde_o else -PI / 2.0))
				_poner("muro_arboles" if (i + j) % 2 == 0 else "muro_recto", c, rot)
			elif caminos.has(celda):
				var con: Array[Vector2i] = []
				for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					if caminos.has(celda + d) or portales.has(celda + d):
						con.append(d)
				var l := _loseta_camino(con)
				var nombre: String = l[0]
				if nombre == "camino_recto" and _rng.randf() < 0.45:
					nombre = "camino_faroles"
				_poner(nombre, c, l[1])
			elif reservado.call(i, j):
				Kit.colocar(self, "pasto", c)
			else:
				var dado := _rng.randf()
				if dado < 0.24:
					_poner("bosque", c, _rng.randi_range(0, 3) * PI / 2.0)
				elif dado < 0.36:
					_poner("jacaranda_banco", c, _rng.randi_range(0, 3) * PI / 2.0)
				elif dado < 0.41:
					_poner("plaza_cantero", c, 0.0)
				else:
					Kit.colocar(self, "pasto", c)
					if _rng.randf() < 0.75:
						var arbol: String = ["arbol_A", "arbol_B", "arbol_C", "arbol_E", "arbol_D", "jacaranda"][_rng.randi() % 6]
						_poner(arbol, c + Vector3(_rng.randf_range(-1.6, 1.6), T_PARQUE, _rng.randf_range(-1.6, 1.6)), _rng.randf() * TAU)
					for k in _rng.randi_range(0, 2):
						var arbusto: String = ["arbusto_A", "arbusto_B", "arbusto_C", "arbusto_flores"][_rng.randi() % 4]
						_poner(arbusto, c + Vector3(_rng.randf_range(-2.4, 2.4), T_PARQUE, _rng.randf_range(-2.4, 2.4)), _rng.randf() * TAU)
	# Colisión del piso del parque (las losetas están a 20 cm)
	var forma := BoxShape3D.new()
	forma.size = Vector3(r.size.x, T_PARQUE, r.size.y)
	Kit._forma(_cuerpo_en(Vector3(r.get_center().x, 0, r.get_center().y)), forma,
		Transform3D(Basis.IDENTITY, Vector3(r.get_center().x, T_PARQUE / 2.0, r.get_center().y)))
	_zona_palomas_parque()
	_juegos()
	_plaza_rombo()
	_parque_perros()
	_bolt()


const Y_PISO := T_PARQUE + 0.07   ## Superficie de los pisos especiales del parque


func _zona_palomas_parque() -> void:
	var c := Vector3(-179, 0, -94)
	_poner("plaza_palomas", c)
	_poner("estatua_paloma", c + Vector3(0, Y_PISO, 0), 0.0)
	_texto(c + Vector3(0, Y_PISO + 0.75, 1.01), 0.0, "A LAS PALOMAS\nDE LA PLAZA", 1.3, 0.5, Color("5d6b74"), 40.0)
	for k in 8:
		var a := TAU * (k + 0.5) / 8.0
		var d := Vector3(sin(a), 0, cos(a))
		_poner("banco", c + d * 8.6 + Vector3(0, Y_PISO, 0), a + PI)
	for k in 4:
		var a := TAU * k / 4.0
		_poner("farol_doble", c + Vector3(sin(a), 0, cos(a)) * 10.2 + Vector3(0, Y_PISO, 0), a)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		_poner("jacaranda", c + Vector3(sin(a), 0, cos(a)) * 13.5 + Vector3(0, T_PARQUE, 0), _rng.randf() * TAU, Vector3.ONE * 1.15)
	# La señora de las palomas, en el banco que mira al sur
	var a0 := TAU * 0.5 / 8.0
	_senora(c + Vector3(sin(a0), 0, cos(a0)) * 8.6 + Vector3(0, Y_PISO, 0), a0, "MigasParque")


func _juegos() -> void:
	var c := Vector3(-101, 0, -91)
	var y := T_PARQUE + 0.065
	_poner("piso_juegos", c)
	# Calesita (la parte de arriba gira)
	_poner("calesita_base", c + Vector3(7, y, -4))
	_animado("calesita_giro", c + Vector3(7, y, -4), 0.0, "girar", 0.45)
	# Hamacas: el marco fijo y cada asiento se hamaca sobre el eje de arriba
	_poner("hamaca_marco", c + Vector3(-6, y, -6.5))
	for x: float in [-0.65, 0.65]:
		_animado("hamaca_asiento", c + Vector3(-6 + x, y + 2.5, -6.5), 0.0, "hamacar", 1.6 + x, 0.55)
	_poner("tobogan", c + Vector3(-8, y, 5), deg_to_rad(30))
	_poner("subibaja_base", c + Vector3(9, y, 6))
	_animado("subibaja_tabla", c + Vector3(9, y + 0.5, 6), 0.0, "subibaja", 1.2, 0.25)
	_poner("arenero", c + Vector3(0.5, y, 1.5))
	# Cerco bajo de colores alrededor (con la entrada al sur, donde llega el camino)
	var x0 := c.x - 16.5
	var x1 := c.x + 16.5
	var z0 := c.z - 13.5
	var z1 := c.z + 13.5
	_cerco("cerco_juegos", Vector3(x0, T_PARQUE, z0), Vector3(x1, T_PARQUE, z0), [])
	_cerco("cerco_juegos", Vector3(x1, T_PARQUE, z0), Vector3(x1, T_PARQUE, z1), [])
	_cerco("cerco_juegos", Vector3(x1, T_PARQUE, z1), Vector3(x0, T_PARQUE, z1), [6])
	_cerco("cerco_juegos", Vector3(x0, T_PARQUE, z1), Vector3(x0, T_PARQUE, z0), [])
	_poner("cartel_madera", Vector3(-108, T_PARQUE, -76.4), 0.0, Vector3.ONE, true, {"madera": "Plaza de juegos"})
	for x: float in [-12.0, 12.0]:
		_poner("banco", c + Vector3(x, y, 11.6), PI)
	_paseo(c + Vector3(0, y, 3), Vector2(22, 14), 3, "turista", "")


func _plaza_rombo() -> void:
	var c := Vector3(-140, 0, -61)
	_poner("plaza_rombo", c)
	_poner("fuente", c + Vector3(0, Y_PISO, 0), 0.0, Vector3.ONE * 2.1)
	for k in 4:
		var a := TAU * k / 4.0
		var d := Vector3(sin(a), 0, cos(a))
		_poner("banco", c + d * 7.0 + Vector3(0, Y_PISO, 0), a + PI)
		_poner("farol_doble", c + d * 12.5 + Vector3(0, Y_PISO, 0), a)
		var diag := Vector3(sin(a + PI / 4.0), 0, cos(a + PI / 4.0)) * 8.0
		_poner("cantero", c + diag + Vector3(0, Y_PISO, 0))
		_poner("jacaranda", c + diag + Vector3(0, Y_PISO + 0.4, 0), _rng.randf() * TAU, Vector3.ONE * 1.1)
	_paseo(c + Vector3(0, Y_PISO, 0), Vector2(14, 14), 4, "turista", "MigasRombo")


func _parque_perros() -> void:
	var x0 := -191.0
	var x1 := -146.0
	var z0 := -40.0
	var z1 := -19.0
	var y := T_PARQUE
	_cerco("reja", Vector3(x0, y, z0), Vector3(x1, y, z0), [])
	_cerco("reja", Vector3(x1, y, z0), Vector3(x1, y, z1), [2, 3])     # portón donde llega el camino
	_cerco("reja", Vector3(x1, y, z1), Vector3(x0, y, z1), [])
	_cerco("reja", Vector3(x0, y, z1), Vector3(x0, y, z0), [])
	_poner("agility_salto", Vector3(-176, y, -31), 0.0)
	_poner("agility_salto", Vector3(-168, y, -25), 0.6)
	_poner("agility_tunel", Vector3(-160, y, -34), 0.2)
	_poner("agility_rampa", Vector3(-183, y, -24), PI / 2.0)
	_poner("bebedero", Vector3(-149.5, y, -22.5))
	_poner("cartel_madera", Vector3(-143.6, y, -36.5), PI / 2.0, Vector3.ONE, true, {"madera": "Parque de perros"})
	_poner("arbol_A", Vector3(-158, y, -24), 0.7)
	_poner("arbol_E", Vector3(-187, y, -37), 2.0)
	_poner("banco", Vector3(-151, y, -38.3), 0.0)
	_poner("perro_negro", Vector3(-152, y, -35.5), -2.6)
	_poner("perro_echado", Vector3(-185, y, -36), 0.8)
	var zona := Rect2(x0 + 2.0, z0 + 2.0, x1 - x0 - 4.0, z1 - z0 - 4.0)
	for nombre: String in ["perro_marron", "perro_blanco", "perro_marron"]:
		var p := Vector3(_rng.randf_range(zona.position.x, zona.end.x), y, _rng.randf_range(zona.position.y, zona.end.y))
		var a := _animado(nombre, p, _rng.randf() * TAU, "pasear", 1.6)
		a.zona = zona
	_paseo(Vector3(-168, y, -29), Vector2(30, 12), 2, "turista", "")


## El easter egg de Bolt: su cucha escondida entre los arbustos del lado oeste del parque.
func _bolt() -> void:
	var y := T_PARQUE
	_poner("cucha", Vector3(-191.5, y, -61), PI / 2.0, Vector3.ONE, true, {"cucha": "BOLT"})
	_poner("perro_bolt", Vector3(-189.6, y, -61.2), PI / 2.0)
	_poner("plato_hueso", Vector3(-189.9, y, -59.2), 0.4)
	for p: Vector3 in [Vector3(-188.0, y, -64.2), Vector3(-187.4, y, -57.8), Vector3(-186.3, y, -61.5), Vector3(-190.5, y, -64.8),
			Vector3(-190.2, y, -56.9)]:
		_poner(["arbusto_C", "arbusto_B", "arbusto_C", "arbusto_flores", "arbusto_B"][_rng.randi() % 5], p, _rng.randf() * TAU)
	_poner("arbol_E", Vector3(-193, y, -66.5), 1.2)


## Cerco de tramos de 3 m (la pieza tiene el poste en -X) de "a" a "b", con huecos en los tramos de
## "huecos" (por número de tramo). Los tramos se estiran un poco si el largo no es múltiplo de 3.
func _cerco(pieza: String, a: Vector3, b: Vector3, huecos: Array) -> void:
	var largo := a.distance_to(b)
	var n := maxi(1, roundi(largo / 3.0))
	var paso := largo / n
	var dir := (b - a) / largo
	var rot := atan2(-dir.z, dir.x)
	for k in n:
		if k in huecos:
			continue
		_poner(pieza, a + dir * (paso * (k + 0.5)), rot, Vector3(paso / 3.0, 1, 1))
	if pieza == "reja":
		_poner("reja_poste", b, rot)


# ---------------------------------------------------------------- Barrio enemigo

func _barrio() -> void:
	var r := BARRIO
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	# Al norte, sobre Reconquista, edificios comunes ("más edificios" del boceto)
	_poner(ESQ_CENTRO[_rng.randi() % ESQ_CENTRO.size()], Vector3(x0, 0, z0), -PI / 2.0)
	_poner(ESQ_CENTRO[_rng.randi() % ESQ_CENTRO.size()], Vector3(x1, 0, z0), PI)
	_fila(Vector3(x0 + FONDO, 0, z0), Vector3.RIGHT, r.size.x - 2.0 * FONDO, PI, POOL_CENTRO)
	_fila(Vector3(x0, 0, z0 + FONDO), Vector3.BACK, 32.0, -PI / 2.0, POOL_CENTRO)
	_fila(Vector3(x1, 0, z0 + FONDO), Vector3.BACK, 24.0, PI / 2.0, POOL_CENTRO)
	# El barrio: casas bajas sobre Paseo Colón (con un pasillo de entrada), al sur y al este
	var casas: Array[MeshInstance3D] = []
	casas.append_array(_fila(Vector3(x0, 0, 50), Vector3.BACK, 20.0, -PI / 2.0, POOL_BARRIO))
	casas.append_array(_fila(Vector3(x0, 0, 74), Vector3.BACK, z1 - 74.0, -PI / 2.0, POOL_BARRIO))
	casas.append_array(_fila(Vector3(x1, 0, 42), Vector3.BACK, z1 - 42.0, PI / 2.0, POOL_BARRIO))
	casas.append_array(_fila(Vector3(x0 + 12.0, 0, z1), Vector3.RIGHT, r.size.x - 24.0, 0.0, POOL_BARRIO))
	# Casas sueltas adentro, mirando al potrero
	casas.append_array(_fila(Vector3(100, 0, 52), Vector3.RIGHT, 26.0, 0.0, POOL_BARRIO))
	casas.append_array(_fila(Vector3(150, 0, 52), Vector3.RIGHT, 26.0, 0.0, POOL_BARRIO))
	casas.append_array(_fila(Vector3(104, 0, 86), Vector3.RIGHT, 30.0, PI, POOL_BARRIO))
	casas.append_array(_fila(Vector3(146, 0, 86), Vector3.RIGHT, 30.0, PI, POOL_BARRIO))
	# Tierra y el potrero con sus arcos
	_losa(x0 + 12.0, z0 + FONDO, x1 - 12.0, z1 - 12.0, Y_VEREDA + 0.012, 0.2, C_TIERRA)
	var cancha := Rect2(118, 57, 38, 22)
	_losa(cancha.position.x, cancha.position.y, cancha.end.x, cancha.end.y, Y_VEREDA + 0.02, 0.2, C_POTRERO)
	var yl := Y_VEREDA + 0.026
	for l: Array in [[cancha.position.x, cancha.position.y, cancha.end.x, cancha.position.y + 0.15],
			[cancha.position.x, cancha.end.y - 0.15, cancha.end.x, cancha.end.y],
			[cancha.position.x, cancha.position.y, cancha.position.x + 0.15, cancha.end.y],
			[cancha.end.x - 0.15, cancha.position.y, cancha.end.x, cancha.end.y],
			[cancha.get_center().x - 0.075, cancha.position.y, cancha.get_center().x + 0.075, cancha.end.y]]:
		_losa(l[0], l[1], l[2], l[3], yl, 0.02, Color("efeee8"), false)
	_poner("arco_futbol", Vector3(cancha.position.x + 0.3, Y_VEREDA + 0.02, cancha.get_center().y), PI / 2.0)
	_poner("arco_futbol", Vector3(cancha.end.x - 0.3, Y_VEREDA + 0.02, cancha.get_center().y), -PI / 2.0)
	# Paredones de chapa con grafitis, autos abandonados, basura
	_cerco("chapa_cerco", Vector3(112, Y_VEREDA, 55), Vector3(124, Y_VEREDA, 55), [])
	_cerco("chapa_cerco_b", Vector3(150, Y_VEREDA, 55), Vector3(162, Y_VEREDA, 55), [])
	_cerco("chapa_cerco", Vector3(94, Y_VEREDA, 64), Vector3(94, Y_VEREDA, 79), [2])
	_cerco("chapa_cerco_b", Vector3(166, Y_VEREDA, 64), Vector3(166, Y_VEREDA, 80), [])
	# El cartel pintado en el paredón que se ve al entrar por el pasillo
	_texto(Vector3(93.9, 1.25, 68.5), -PI / 2.0, "PROHIBIDO\nPALOMAS", 2.6, 1.0, Color("ff5fb0"), 70.0)
	_poner("auto_abandonado", Vector3(105, Y_VEREDA, 30), 0.3)
	_poner("auto_abandonado", Vector3(172, Y_VEREDA, 34), 2.5)
	for p: Vector3 in [Vector3(100, Y_VEREDA, 40), Vector3(160, Y_VEREDA, 44), Vector3(130, Y_VEREDA, 92)]:
		_poner("contenedor", p, _rng.randf() * TAU)
		_poner("bolsas", p + Vector3(1.6, 0, 0.6), _rng.randf() * TAU, Vector3.ONE, false)
	for k in 5:
		_poner("tendedero", Vector3(_rng.randf_range(100, 175), Y_VEREDA, _rng.randf_range(22, 40)), _rng.randf() * TAU,
			Vector3.ONE, false)
	_poner("tanque", Vector3(140, Y_VEREDA, 36))
	# Los gatos del barrio: en las terrazas (las casas de techo plano), en un auto y cerca del potrero
	var gatos := ["gato_naranja", "gato_negro", "gato_gris"]
	var k := 0
	for casa in casas:
		var n := String(casa.get_meta(&"pieza", ""))
		if not n in ["barrio_8_a", "barrio_10_a", "barrio_12_a"] or k >= 8:
			continue
		var d: Dictionary = KitDatos.PIEZAS[n]
		var local := Vector3(-float(d["ancho"]) / 2.0 + 1.5, float(d["alto"]) + 0.06, -3.0)
		_animado(gatos[k % 3], casa.position + casa.basis * local, _rng.randf() * TAU, "respirar", 1.0)
		k += 1
	for p: Vector3 in [Vector3(120, Y_VEREDA + 0.02, 81), Vector3(153, Y_VEREDA + 0.02, 56), Vector3(108, Y_VEREDA, 33)]:
		_animado(gatos[_rng.randi() % 3], p, _rng.randf() * TAU, "respirar", 1.0)
	_animado("gato_negro", Vector3(105.2, Y_VEREDA + 1.81, 29.95), 1.0, "respirar", 1.0)


# ---------------------------------------------------------------- Peatonal y pasaje

func _peatonal() -> void:
	var z := (PEATONAL[1] + PEATONAL[3]) / 2.0
	var x := PEATONAL[0] + 8.0
	var k := 0
	while x < PEATONAL[2] - 6.0:
		match k % 4:
			0:
				_poner("cazuela", Vector3(x, Y_VEREDA, z))
				_poner(["arbol_calle_A", "arbol_calle_C", "jacaranda_calle"][_rng.randi() % 3], Vector3(x, Y_VEREDA, z), _rng.randf() * TAU)
			1:
				_poner("farol_doble", Vector3(x, Y_VEREDA, z), PI / 2.0)
				_poner("banco", Vector3(x - 1.5, Y_VEREDA, z - 1.2), PI)
				_poner("banco", Vector3(x + 1.5, Y_VEREDA, z + 1.2), 0.0)
			2:
				_poner(["maceton_flores", "maceton"][_rng.randi() % 2], Vector3(x - 1.2, Y_VEREDA, z), 0.0)
				_poner(["maceton_flores", "maceton"][_rng.randi() % 2], Vector3(x + 1.2, Y_VEREDA, z), 0.0)
			3:
				if k == 7:
					_poner("kiosco_diarios", Vector3(x, Y_VEREDA, z), PI / 2.0)
				else:
					_poner("cesto", Vector3(x, Y_VEREDA, z - 0.8))
					_poner(["bici_roja", "bici_azul", "bici_verde"][_rng.randi() % 3], Vector3(x + 1.5, Y_VEREDA, z + 1.5), 0.2, Vector3.ONE, false)
		x += 7.5
		k += 1
	_paseo(Vector3(-137, Y_VEREDA, z), Vector2(110, 5), 6, "oficinista", "MigasPeatonal")


func _pasaje() -> void:
	var z := (PASAJE[1] + PASAJE[3]) / 2.0
	var x := PASAJE[0] + 6.0
	var k := 0
	while x < PASAJE[2] - 4.0:
		_poner("guirnalda", Vector3(x, Y_VEREDA, z), PI / 2.0, Vector3(1.0, 1.0, 1.0), false)
		if k % 2 == 0:
			_poner(["maceton", "maceton_flores"][_rng.randi() % 2], Vector3(x + 2.5, Y_VEREDA, PASAJE[3] - 0.7))
		else:
			_poner(["bici_roja", "bici_azul", "bici_verde"][_rng.randi() % 3], Vector3(x + 3.0, Y_VEREDA, PASAJE[3] - 0.5), 0.0,
				Vector3.ONE, false)
		if k % 3 == 1:
			_poner("cesto", Vector3(x - 2.0, Y_VEREDA, PASAJE[1] + 0.6))
		x += 9.0
		k += 1


# ---------------------------------------------------------------- Veredas: árboles, faroles, carteles

## Árboles en cazuelas, farolas y algo de mobiliario sobre una vereda. "a" y "b" son los extremos
## sobre el cordón y "adentro" apunta hacia las fachadas.
func _props_vereda(a: Vector3, b: Vector3, adentro: Vector3, paso := 9.0) -> void:
	var largo := a.distance_to(b)
	var dir := (b - a) / largo
	var rot_calle := atan2(-adentro.x, -adentro.z)   # +Z local hacia la calle
	var rot_largo := atan2(-dir.z, dir.x)            # X local a lo largo de la vereda
	var d := 6.0
	var k := _rng.randi() % 3
	while d < largo - 5.0:
		var p := a + dir * d + Vector3(0, Y_VEREDA, 0)
		if k % 3 == 1:
			_poner("farola", p + adentro * 0.45, rot_calle)
		else:
			var arbol: String = ["arbol_calle_A", "arbol_calle_B", "arbol_calle_C", "arbol_calle_A", "jacaranda_calle"][_rng.randi() % 5]
			_poner("cazuela", p + adentro * 1.0, rot_largo)
			_poner(arbol, p + adentro * 1.0, _rng.randf() * TAU)
		var extra := _rng.randf()
		if extra < 0.1:
			_poner("contenedor" if _rng.randf() < 0.7 else "contenedor_gris", p - adentro * 0.75 + Vector3(0, -Y_VEREDA + Y_CALZADA, 0),
				rot_largo)
		elif extra < 0.17:
			_poner("cesto", p + adentro * 0.45 + dir * 2.0)
		elif extra < 0.22:
			_poner(["bici_roja", "bici_azul", "bici_verde"][_rng.randi() % 3], p + adentro * 2.4 + dir * 2.5, rot_largo, Vector3.ONE, false)
		elif extra < 0.27:
			_poner(["maceton", "maceton_flores"][_rng.randi() % 2], p + adentro * 2.45 + dir * 3.0)
		d += paso
		k += 1


## Cartel con los nombres de las dos calles que se cruzan, en la esquina de la vereda.
func _cartel_calle(pos: Vector3, este_oeste: String, norte_sur: String) -> void:
	var p := Vector3(pos.x, Y_VEREDA, pos.z)
	_poner("cartel_calle", p)
	for c: Array in Kit.carteles("cartel_calle", Transform3D(Basis.IDENTITY, p)):
		# Las dos primeras caras son de la placa que va a lo largo de X (calle este-oeste)
		var texto := este_oeste if absf(sin(float(c[1]))) < 0.5 else norte_sur
		_texto(c[0], c[1], texto.to_upper(), c[2], c[3], Color.WHITE, 35.0)


func _props_veredas() -> void:
	# Manzanas comunes: las cuatro veredas (las del borde, con menos árboles)
	var calles := {
		NORTE: ["Av. Belgrano", "Av. Rivadavia", "Bolívar", "Paseo Colón"],
		SUR: ["", "Av. Independencia", "Bolívar", "Paseo Colón"],
		PARQUE: ["Av. Belgrano", "Av. de Mayo", "Tacuarí", "Bolívar"],
		COMERCIAL_A: ["Av. de Mayo", "", "Tacuarí", "Bolívar"],
		COMERCIAL_B: ["", "Av. Independencia", "Tacuarí", "Bolívar"],
		ESTE: ["Av. Belgrano", "Reconquista", "Paseo Colón", "Av. Madero"],
		BARRIO: ["Reconquista", "Av. Independencia", "Paseo Colón", "Av. Madero"],
	}
	for r: Rect2 in calles:
		var nombres: Array = calles[r]
		var e := r.grow(VEREDA)
		var x0 := e.position.x
		var z0 := e.position.y
		var x1 := e.end.x
		var z1 := e.end.y
		var borde_n := r.position.y <= Z_MIN + 0.1
		var borde_s := r.end.y >= Z_MAX - 0.1
		var borde_o := r.position.x <= X_MIN + 0.1
		var borde_e := r.end.x >= X_MAX - 0.1
		if nombres[0] != "":
			_props_vereda(Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3.BACK, 14.0 if borde_n else 9.0)
		if nombres[1] != "":
			_props_vereda(Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3.FORWARD, 14.0 if borde_s else 9.0)
		_props_vereda(Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3.RIGHT, 14.0 if borde_o else 9.0)
		_props_vereda(Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3.LEFT, 14.0 if borde_e else 9.0)
		# Carteles de calle en las esquinas que dan a dos calles
		var esquinas := [[Vector3(x0 + 0.6, 0, z0 + 0.6), nombres[0], nombres[2]], [Vector3(x1 - 0.6, 0, z0 + 0.6), nombres[0], nombres[3]],
			[Vector3(x0 + 0.6, 0, z1 - 0.6), nombres[1], nombres[2]], [Vector3(x1 - 0.6, 0, z1 - 0.6), nombres[1], nombres[3]]]
		for q: Array in esquinas:
			if q[1] != "" and q[2] != "":
				_cartel_calle(q[0], q[1], q[2])
				_poner("pilote", (q[0] as Vector3) + Vector3(0, Y_VEREDA, 0) + Vector3(signf(r.get_center().x - (q[0] as Vector3).x), 0, 0) * 1.2)
	# Veredas de la plaza (detrás del Cabildo, de la Catedral y de la Casa Rosada)
	_props_vereda(Vector3(-64, 0, -43), Vector3(-64, 0, 26), Vector3.RIGHT)
	_props_vereda(Vector3(64, 0, -43), Vector3(64, 0, 26), Vector3.LEFT)
	_props_vereda(Vector3(-64, 0, -43), Vector3(64, 0, -43), Vector3.BACK)
	_cartel_calle(Vector3(-63.4, 0, -42.4), "Av. Rivadavia", "Bolívar")
	_cartel_calle(Vector3(63.4, 0, -42.4), "Av. Rivadavia", "Paseo Colón")
	_cartel_calle(Vector3(-63.4, 0, 25.4), "H. Yrigoyen", "Bolívar")
	_cartel_calle(Vector3(63.4, 0, 25.4), "H. Yrigoyen", "Paseo Colón")
	_cartel_calle(Vector3(-63.4, 0, 49.0), "Pasaje Las Palomas", "Bolívar")
	_cartel_calle(Vector3(-76.4, 0, 57.0), "Peatonal Florida", "Bolívar")
	# Paradas de colectivo y kioscos de diarios
	_poner("parada_colectivo", Vector3(-62.6, Y_VEREDA, 10), -PI / 2.0)
	_poner("parada_colectivo", Vector3(75.4, Y_VEREDA, 60), -PI / 2.0)
	_poner("parada_colectivo", Vector3(-75.4, Y_VEREDA, -80), PI / 2.0)
	_poner("kiosco_diarios", Vector3(-62.4, Y_VEREDA, -20), -PI / 2.0)
	_poner("kiosco_diarios", Vector3(30, Y_VEREDA, -54.4), 0.0)
	_poner("buzon", Vector3(-75.6, Y_VEREDA, 20), PI / 2.0)
	_poner("buzon", Vector3(-20, Y_VEREDA, -54.4), 0.0)


# ---------------------------------------------------------------- Fondo (fuera del mapa jugable)

## Una fila de edificios del kit mirando hacia el mapa y, detrás, torres simples que hacen de horizonte.
## No tienen colisión (están del otro lado de las paredes invisibles) ni proyectan sombra.
func _fondo() -> void:
	# Norte y sur (con huecos para Bolívar y Paseo Colón)
	for tramo: Array in [[-213.0, -77.0], [-61.0, 61.0], [77.0, 213.0]]:
		var a: float = tramo[0]
		var b: float = tramo[1]
		_fila(Vector3(a, 0, -128), Vector3.RIGHT, b - a, 0.0, POOL_FONDO, false, false, true)
		_fila(Vector3(a, 0, 126), Vector3.RIGHT, b - a, PI, POOL_FONDO, false, false, true)
	_fila(Vector3(-213, 0, -128), Vector3.BACK, 254.0, PI / 2.0, POOL_FONDO, false, false, true)
	_fila(Vector3(213, 0, -128), Vector3.BACK, 254.0, -PI / 2.0, POOL_FONDO, false, false, true)
	# Torres del horizonte
	var colores := [Color("c9d3dc"), Color("b9c6d2"), Color("d8d2c8"), Color("aebccb"), Color("cfc8d6")]
	for k in 70:
		var ang := TAU * k / 70.0 + _rng.randf_range(-0.03, 0.03)
		var d := Vector3(cos(ang) * 290.0, 0, sin(ang) * 215.0)
		var alto := _rng.randf_range(22.0, 55.0)
		var tam := Vector3(_rng.randf_range(14, 26), alto, _rng.randf_range(14, 26))
		var c: Color = colores[_rng.randi() % colores.size()]
		var mi := Construir.caja(self, d + Vector3(0, alto / 2.0, 0), tam, c, false)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Túneles por donde entran y salen los autos (al final de Bolívar y de Paseo Colón)
	for x: float in [-69.0, 69.0]:
		for s: float in [-1.0, 1.0]:
			_tunel(Vector3(x, 0, s * 158.0), s)


## Edificio que tapa la calle con la boca oscura de un túnel: los autos aparecen y desaparecen adentro.
func _tunel(c: Vector3, sentido: float) -> void:
	var mi := Construir.caja(self, c + Vector3(0, 9.0, 0), Vector3(22, 18, 28), Color("c8c0b2"), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cara := c.z - sentido * 14.02
	Construir.caja(self, Vector3(c.x, 2.8, cara), Vector3(10.4, 5.6, 0.02), Color("15171b"), false)
	Construir.caja(self, Vector3(c.x, 6.0, cara - sentido * 0.15), Vector3(12.0, 0.8, 0.3), Color("9aa0a6"), false)


# ---------------------------------------------------------------- Juego: palomas, migas y gente

func _zona_palomas(nombre: String, pos: Vector3, radio: float, cantidad: int) -> void:
	var m := Marker3D.new()
	m.name = "ZonaPalomas" + nombre
	m.add_to_group("zona_palomas")
	m.set_meta("radio", radio)
	m.set_meta("cantidad", cantidad)
	add_child(m)
	m.position = pos


func _migas(nombre: String, pos: Vector3, radio: float, maximo: int, intervalo: float) -> void:
	var g := GeneradorMigas.new()
	g.name = nombre
	g.radio = radio
	g.maximo = maximo
	g.intervalo = intervalo
	add_child(g)
	g.position = pos


## Una señora sentada en un banco que les tira migas a las palomas (la crea enemies/gente.gd).
func _senora(pos: Vector3, rumbo: float, migas: String) -> void:
	var m := Marker3D.new()
	m.add_to_group("senora_extra")
	m.set_meta("migas", migas)
	m.set_meta("rumbo", rumbo)
	add_child(m)
	m.position = pos


## Zona rectangular donde pasea gente (la crea enemies/gente.gd).
func _paseo(centro: Vector3, tam: Vector2, cantidad: int, tipo: String, migas: String) -> void:
	var m := Marker3D.new()
	m.add_to_group("zona_paseo")
	m.set_meta("tam", tam)
	m.set_meta("cantidad", cantidad)
	m.set_meta("tipo", tipo)
	m.set_meta("migas", migas)
	add_child(m)
	m.position = centro


func _puntos_de_juego() -> void:
	_zona_palomas("Parque", Vector3(-179, Y_PISO, -94), 8.0, 12)
	_migas("MigasParque", Vector3(-179, Y_PISO + 0.02, -91), 6.0, 10, 2.5)
	_zona_palomas("Rombo", Vector3(-140, Y_PISO, -61), 7.0, 6)
	_migas("MigasRombo", Vector3(-140, Y_PISO + 0.02, -55), 5.0, 6, 4.0)
	_zona_palomas("Pasaje", Vector3(0, Y_VEREDA, 51), 6.0, 4)
	_migas("MigasPasaje", Vector3(0, Y_VEREDA + 0.02, 51), 5.0, 4, 6.0)
	_zona_palomas("Peatonal", Vector3(-120, Y_VEREDA, 58), 7.0, 5)
	_migas("MigasPeatonal", Vector3(-120, Y_VEREDA + 0.02, 58), 6.0, 5, 5.0)


## Pieza que se mueve (no se fusiona): la calesita, las hamacas, el subibaja, los perros y los gatos.
func _animado(nombre: String, pos: Vector3, rot: float, tipo: String, velocidad: float, amplitud := 0.5) -> Animado:
	var a := Animado.new()
	a.tipo = tipo
	a.velocidad = velocidad
	a.amplitud = amplitud
	add_child(a)
	a.position = pos
	a.rotation.y = rot
	var mi := Kit.colocar(a, nombre, Vector3.ZERO)
	# Lo que se mueve proyecta su propia sombra (las formas simples de sombra no giran bien: la
	# calesita sería una caja)
	for h in a.get_children():
		if h != mi and (h as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			h.queue_free()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return a
