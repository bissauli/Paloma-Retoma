class_name Ciudad
extends Node3D
## La ciudad alrededor de la Plaza de Mayo, según el boceto del mapa. Mapa V3: la misma distribución
## del V2 con el kit nuevo (tools/blender/ciudad_v3.py): veredas de lajas, edificios con remates de
## color, autos estacionados, faroles curvos, semáforos, hidrantes, contenedores de colores, obras,
## mesas de café, árboles grandes con flores, la cancha de básquet, el hospital, la comisaría y
## locales temáticos.
## - Oeste: el parque (zona de palomas con su estatua, juegos con calesita, plaza en rombo, parque
##   de perros y la cucha de Bolt escondida) y, cruzando la Av. de Mayo, las manzanas comerciales
##   partidas por la Peatonal Florida.
## - Norte y sur de la plaza: más edificios (al sur, detrás de los cafés, el Pasaje Las Palomas).
## - Este: edificios al norte de Reconquista y, al sur, el barrio enemigo (casas bajas de world/barrio.gd,
##   la guarida de la banda de los BadJokes, grafitis,
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
const TECHO := NivelAlto.TECHO   ## 70 m desde la Fase 3 (antes 41): se llega arriba de las torres

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

const C_ASFALTO := Color("76787a")
const C_CORDON := Color("e6e3dc")
const C_LINEA := Color("f4f3ee")
const C_TIERRA := Color("8c6a4b")
const C_POTRERO := Color("9b7653")

const POOL_CENTRO := ["ph_6_a", "ph_6_c", "casa_8_a", "dep_8_a", "clas_8_b", "ladr_8_a", "dep_10_a", "clas_10_a",
	"dep_10_b", "clas_10_c", "dep_12_a", "clas_12_a", "ladr_12_a", "clas_14_a", "dep_14_a", "mod_10_a"]
const POOL_COMERCIAL := ["mod_10_a", "mod_12_a", "mod_14_a", "ph_6_b", "ph_6_c", "casa_8_a", "ladr_8_a", "clas_10_c",
	"clas_12_a", "dep_12_a", "dep_10_a", "clas_14_a"]
const POOL_FONDO := ["mod_10_a", "mod_12_a", "mod_14_a", "ladr_8_a", "ph_6_b", "ladr_12_a", "casa_8_a", "dep_8_a",
	"ph_6_a", "clas_10_c"]
const ESQ_CENTRO := ["esq_cupula_a", "esq_cupula_b", "esq_dep_a", "esq_ladr_a"]
const ESQ_COMERCIAL := ["esq_mod_a", "esq_cupula_a", "esq_dep_a", "esq_mod_a"]

## Negocios inventados (los nombres propios no se traducen)
const LOCALES := ["Kiosco El Pibe", "Pizzería Los Hornos", "Ferretería Don Tito", "Verdulería Los Primos",
	"Heladería La Cornisa", "Lavadero Burbujas", "Almacén Don Pepe",
	"Bar El Tero", "Óptica Mirada", "Peluquería Rulos", "Zapatería El Taco", "Regalería Moño", "Disquería Vinilo",
	"Cerrajería La Llave", "Mercería El Ovillo", "Fiambrería La Picada", "Juguetería El Trompo", "Bazar Todo Suelto",
	"Parrilla El Fogón", "Empanadas La Abuela", "Vinoteca El Tonel", "Pastas La Nonna", "Bicicletería Rayo",
	"Pinturería Arcoíris", "Florería Jacarandá", "Kiosco 24 Horas", "Librería El Gorrión",
	"Rotisería El Buen Plato", "Tintorería Planchita", "Sastrería El Botón", "Pollería Don Pollo"]
const OFICINAS := ["Seguros El Vuelo", "Banco del Palomar", "Inmobiliaria El Nido", "Estudio Contable Plumas",
	"Agencia de Viajes Migrar", "Galería Paloma", "Bolsa de Migas", "Casa de Cambio La Moneda", "Editorial El Pico",
	"Compañía de Seguros La Cornisa", "Escuela de Idiomas Arrullo", "Consultora Bandada"]

## Carteles de los locales temáticos y edificios especiales (por tipo de cartel del kit): texto y color
## de la letra. "HOSPITAL", "GUARDIA" y "POLICÍA" se traducen (autoload/textos_en.gd).
const CARTELES := {
	"panaderia": ["Panadería La Espiga", Color("8a4a2a")],
	"golosineria": ["Golosinas El Caramelo", Color("e0507a")],
	"farmacia": ["Farmacia del Pasaje", Color.WHITE],
	"minimercado": ["Minimercado La Bandada", Color.WHITE],
	"ropa": ["Ropa La Percha", Color("3a6fc0")],
	"cafe": ["Café Los Gorriones", Color.WHITE],
	"taller": ["Taller El Pistón", Color.WHITE],
	"hospital": ["HOSPITAL", Color("e03a3a")],
	"guardia": ["GUARDIA", Color.WHITE],
	"comisaria": ["POLICÍA", Color.WHITE],
}
const AUTOS := ["auto_hatch_celeste", "auto_hatch_naranja", "auto_hatch_amarillo", "auto_hatch_verde", "auto_hatch_rojo",
	"auto_hatch_blanco", "auto_sedan_celeste", "auto_sedan_rojo", "auto_sedan_blanco", "auto_sedan_verde", "taxi", "taxi"]
const ARBOLES := ["arbol_grande_A", "arbol_grande_B", "arbol_grande_C", "jacaranda_grande", "arbol_grande_A", "pino_A", "pino_B"]
const ARBOLES_VEREDA := ["arbol_grande_B", "arbol_grande_A", "jacaranda_grande", "arbol_grande_B"]
const FLORES := ["flores_A", "flores_B", "flores_C", "flores_D"]
const ARBUSTOS := ["arbusto_redondo_A", "arbusto_redondo_B", "arbusto_A", "arbusto_flores"]

var _rng := RandomNumberGenerator.new()
## Las flores tienen su propio azar: en el teléfono van menos y así no cambia el resto del mapa
var _rng_flores := RandomNumberGenerator.new()
var _cuerpos := {}                  ## Celda -> StaticBody3D con las colisiones de esa zona (ver _cuerpo_en)
var _mat_vereda: Material
var _mat_peatonal: Material
var _locales: Array = []
var _oficinas: Array = []
var autos_estacionados := 0         ## Cuántos autos y motos estacionados hay (lo miran las pruebas)
var lotes := 0                      ## Cuántos lotes hay en los corazones de manzana
var mobiliario := {}                ## Pieza -> cuántas puso _mobiliario (lo miran las pruebas)
var _ocupado := {}                  ## Celda de 4 m -> huellas (Rect2 en X/Z) de lo que ya hay en las veredas
var _reservado: Array[Rect2] = []   ## Huellas que no son piezas del kit (la obra de la cuadra)
var colocadas: Array = []           ## [pieza, posición] de todo lo que puso _poner (lo miran las pruebas)
var _edificios: Array = []          ## Edificios del kit ya puestos: [transformación inversa, formas, posición]
var luces_fijas: Array = []         ## [pieza, transformación] de los faroles (ver LucesNoche)
var luces_edificios: Array = []     ## [pieza, transformación] de los edificios con ventanas
var arboles_achicados := 0          ## Árboles de la ciudad que se achicaron o sacaron para no meterse en un edificio


func _ready() -> void:
	name = "Ciudad"
	var t0 := Time.get_ticks_msec()
	_rng.seed = 20261115
	_rng_flores.seed = 4242
	NivelAlto.reiniciar()
	LucesNoche.faroles_extra.clear()
	_mat_vereda = Construir.material_lajas("lajas_vereda", 4.0)
	_mat_peatonal = Construir.material_lajas("lajas_peatonal", 4.0)
	_locales = LOCALES.duplicate()
	_oficinas = OFICINAS.duplicate()
	# Cada etapa anota cuánto tardó (se ve con --verbose) y tiene su propia semilla: si una zona cambia
	# (más o menos piezas al azar), las demás quedan igual
	var etapas: Array[String] = []
	for etapa: Callable in [_suelos, _manzanas, _parque, _barrio, _peatonal, _pasaje, _props_veredas, _estacionamientos,
			_obras, _obra_cuadra, _mobiliario, _nivel_medio, _nivel_alto, _fondo, _puntos_de_juego]:
		var t := Time.get_ticks_usec()
		_rng.seed = 20261115 + hash(etapa.get_method())
		etapa.call()
		etapas.append("%s %d" % [etapa.get_method(), (Time.get_ticks_usec() - t) / 1000])
	# Los cuerpos entran al árbol recién ahora, con todas sus formas (así cada uno se arma una sola vez)
	var t1 := Time.get_ticks_usec()
	for c: Vector2i in _cuerpos:
		add_child(_cuerpos[c])
	etapas.append("colisiones %d" % ((Time.get_ticks_usec() - t1) / 1000))
	# Miles de piezas pasan a ser pocas mallas grandes por celda (los árboles y props chicos van
	# aparte y se dejan de dibujar lejos)
	t1 = Time.get_ticks_usec()
	var piezas := get_child_count()
	Construir.fusionar_estaticas(self, 64.0)
	etapas.append("fusión de %d piezas %d" % [piezas, (Time.get_ticks_usec() - t1) / 1000])
	# Luces de la noche: ventanas encendidas y faroles (después de fusionar, así no se las lleva la fusión)
	LucesNoche.construir(self)
	# La banda de los BadJokes en sus puntos de la guarida (mapa V4.5)
	PalomaBadJoke.poblar(self)
	print_verbose("Ciudad armada en %d ms (%s)" % [Time.get_ticks_msec() - t0, ", ".join(etapas)])


## Al desarmar la ciudad (volver al menú) se sueltan las zonas de navegación: la próxima se arman de nuevo
## con las colisiones nuevas.
func _exit_tree() -> void:
	Navegacion.limpiar()


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
	# (con el hueco de la escalera del subte, ver Edificios.subte)
	for r: Rect2 in Edificios.partir(Rect2(-330, -270, 660, 540), Edificios.hueco_subte(true)):
		_losa(r.position.x, r.position.y, r.end.x, r.end.y, -0.03, 0.3, C_ASFALTO.darkened(0.1))
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
	# Mapa V4.5: la copa de un árbol no se mete en un edificio (en los toldos y carteles de los locales):
	# se achica y, si ni así entra, en la cazuela va un arbusto
	if nombre.begins_with("arbol_grande") or nombre.begins_with("jacaranda_grande") or nombre.begins_with("pino"):
		var e := escala.x
		while e > 0.42 and not _copa_libre(nombre, pos, e):
			e *= 0.88
		if e != escala.x:
			arboles_achicados += 1
			if e <= 0.42:
				nombre = "arbusto_redondo_A"
				e = 1.0
			escala = Vector3.ONE * e
	var mi := Kit.colocar(self, nombre, pos, rot, escala, _cuerpo_en(pos) if colision else null, solo_lejos)
	mi.set_meta(&"pieza", nombre)
	colocadas.append([nombre, pos])
	# Para las luces de la noche (ver LucesNoche): faroles y edificios con su transformación
	if LucesNoche.es_farol(nombre):
		luces_fijas.append([nombre, Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)])
	elif KitDatos.PIEZAS.get(nombre, {}).get("carpeta", "") == "edificios" and not solo_lejos:
		luces_edificios.append([nombre, Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)])
	if KitDatos.PIEZAS.get(nombre, {}).get("carpeta", "") == "edificios" and not solo_lejos:
		var tr := Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)
		_edificios.append([tr.affine_inverse(), ColisionAuto.formas(nombre), pos])
		_ocluir(nombre, tr)
	if not con_textos:
		return mi
	var t := Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)
	for c: Array in Kit.carteles(nombre, t):
		var tipo: String = c[4]
		var texto: String = textos.get(tipo, "")
		var color := Color.WHITE
		if texto == "" and CARTELES.has(tipo):
			texto = CARTELES[tipo][0]
			color = CARTELES[tipo][1]
		elif texto == "" and tipo == "local":
			texto = _nombre_local(nombre)
		elif texto == "" and tipo == "kiosco":
			texto = "DIARIOS Y REVISTAS"
		if texto != "":
			var rango := 40.0 if tipo == "kiosco" else (90.0 if tipo == "hospital" or tipo == "comisaria" else 55.0)
			_texto(c[0], c[1], texto, c[2], c[3], color, rango)
			if tipo in VIDRIERAS and not solo_lejos:
				_vidriera(c, texto, escala.x)
	return mi


## Oclusión: las cajas grandes de cada edificio (las mismas de la colisión, achicadas 40 cm de cada lado
## para no tapar nada de más) esconden lo que queda atrás: en la calle no se dibuja lo que está detrás de
## las manzanas. Hay que prender rendering/occlusion_culling/use_occlusion_culling en el proyecto.
const OCLUSOR_MIN := 3.0         ## Las cajas más finas que esto (pretiles, cornisas) no tapan nada
const OCLUSOR_ACHICAR := 0.8

func _ocluir(nombre: String, tr: Transform3D) -> void:
	var d := Kit.datos(nombre)
	for c: Array in d.get("cajas", []):
		var cj := ColisionAuto.caja(d, c)
		var tam: Vector3 = cj[2]
		if minf(minf(tam.x, tam.y), tam.z) < OCLUSOR_MIN:
			continue
		var o := OccluderInstance3D.new()
		var forma := BoxOccluder3D.new()
		forma.size = tam - Vector3.ONE * OCLUSOR_ACHICAR
		o.occluder = forma
		o.transform = tr * Transform3D(cj[0], cj[1])
		add_child(o)


## Si la copa de la pieza "nombre" (un árbol del kit) en "pos" con escala "e" no toca ningún edificio del
## kit (ni sus toldos, cornisas o carteles): se miran puntos en el borde de la copa a varias alturas.
func _copa_libre(nombre: String, pos: Vector3, e: float) -> bool:
	var d := Kit.datos(nombre)
	var mn: Array = d.get("min", [-2.0, 0.0, -2.0])
	var mx: Array = d.get("max", [2.0, 6.0, 2.0])
	var radio := maxf(maxf(-float(mn[0]), float(mx[0])), maxf(-float(mn[2]), float(mx[2]))) * e * 0.85
	var alto := float(mx[1]) * e
	var puntos: Array[Vector3] = []
	for y: float in [0.4, 0.6, 0.8]:
		for k in 8:
			var a := k * TAU / 8.0
			puntos.append(pos + Vector3(cos(a) * radio, alto * y, sin(a) * radio))
	puntos.append(pos + Vector3(0, alto, 0))
	for ed: Array in _edificios:
		if (ed[2] as Vector3).distance_to(pos) > 40.0:
			continue
		for q in puntos:
			if ColisionAuto._salida((ed[0] as Transform3D) * q, ed[1]) <= 0.0:
				return false
	return true


## Bici estacionada: atada a un bicicletero de caño (una U invertida al costado) y un poco inclinada
## contra él, en vez de parada sola en el medio de la vereda.
func _bici(pos: Vector3, rot: float) -> void:
	var mi := _poner(["bici_roja", "bici_azul", "bici_verde"][_rng.randi() % 3], pos, rot, Vector3.ONE, false)
	mi.basis = Basis.from_euler(Vector3(0, rot, 0)) * Basis(Vector3.RIGHT, 0.12)
	var b := Basis.from_euler(Vector3(0, rot, 0))
	var hierro := _c("hierro")
	for x: float in [-0.35, 0.35]:
		Construir.cilindro(self, pos + b * Vector3(x, 0.38, 0.3), 0.025, 0.76, hierro, false, 6)
	var barra := Construir.caja(self, pos + b * Vector3(0, 0.77, 0.3), Vector3(0.75, 0.05, 0.05), hierro, false)
	barra.basis = b
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.75, 0.8, 0.08)
	Kit._forma(_cuerpo_en(pos), forma, Transform3D(b, pos + b * Vector3(0, 0.4, 0.3)))


## Los carteles que van sobre una vidriera de planta baja (ver generar_ciudad.py, planta_baja).
const VIDRIERAS := ["local", "cafe", "farmacia", "golosineria", "minimercado", "panaderia", "ropa"]


## El interior que se ve por la vidriera de abajo del cartel "c" (ver world/vidrieras.gd). El vidrio
## ocupa de 0.62 a 2.92 m y está centrado en la fachada; el cartel está 3.6 m arriba y 0.125 m
## afuera. Los carteles con dibujo al costado están corridos 0.45 m y son 0.9 m más angostos.
## El plano va 0.105 m afuera: delante de la persiana del kit (que a veces baja hasta tapar casi todo
## el vidrio) y de sus parantes, que dibuja el shader. Así los locales se ven abiertos.
func _vidriera(c: Array, texto: String, esc: float) -> void:
	var p: Vector3 = c[0]
	var rot: float = c[1]
	var n := Vector3(sin(rot), 0, cos(rot))
	var con_icono := String(c[4]) != "local"
	var u := Vector3.UP.cross(n)
	var centro := p - n * (0.125 - 0.105) - Vector3(0, 3.6 - 1.77, 0) - u * (0.45 * esc if con_icono else 0.0)
	var ancho: float = c[2] + (0.8 * esc if con_icono else -0.1 * esc)
	Vidrieras.poner(self, centro, rot, Vector2(ancho, 2.3), texto)


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
## fachadas girando "rot" (0 = mirando a +Z). "fijos": edificios que tienen que estar en la fila
## (locales temáticos, hospital...); el resto se reparte del pool y los fijos caen en lugares al azar.
func _fila(a: Vector3, dir: Vector3, largo: float, rot: float, pool: Array, colision := true,
		sombra := true, lejos := false, fijos: Array = []) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var resto := largo
	for n: String in fijos:
		resto -= float(KitDatos.PIEZAS[n]["ancho"])
	var lista: Array = _repartir(resto, pool)
	for n: String in fijos:
		lista.insert(_rng.randi_range(0, lista.size()), n)
	var d := 0.0
	for n: String in lista:
		var w := float(KitDatos.PIEZAS[n]["ancho"])
		var mi := _poner(n, a + dir * (d + w / 2.0), rot, Vector3.ONE, colision, {}, colision, lejos)
		if not sombra:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.append(mi)
		d += w
	return out


func _manzana(r: Rect2, lados: String, pool: Array, esquinas: Array, patio := true, fijos := {}) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	var no := lados.contains("N") and lados.contains("O")
	var ne := lados.contains("N") and lados.contains("E")
	var so := lados.contains("S") and lados.contains("O")
	var se := lados.contains("S") and lados.contains("E")
	if so:
		_esquina(esquinas[_rng.randi() % esquinas.size()], Vector3(x0, 0, z1), 0.0)
	if se:
		_esquina(esquinas[_rng.randi() % esquinas.size()], Vector3(x1, 0, z1), PI / 2.0)
	if ne:
		_esquina(esquinas[_rng.randi() % esquinas.size()], Vector3(x1, 0, z0), PI)
	if no:
		_esquina(esquinas[_rng.randi() % esquinas.size()], Vector3(x0, 0, z0), -PI / 2.0)
	if lados.contains("S"):
		var a := x0 + (FONDO if so else 0.0)
		_fila(Vector3(a, 0, z1), Vector3.RIGHT, x1 - (FONDO if se else 0.0) - a, 0.0, pool, true, true, false, fijos.get("S", []))
	if lados.contains("N"):
		var a := x0 + (FONDO if no else 0.0)
		_fila(Vector3(a, 0, z0), Vector3.RIGHT, x1 - (FONDO if ne else 0.0) - a, PI, pool, true, true, false, fijos.get("N", []))
	if lados.contains("E"):
		var a := z0 + (FONDO if ne else 0.0)
		_fila(Vector3(x1, 0, a), Vector3.BACK, z1 - (FONDO if se else 0.0) - a, PI / 2.0, pool, true, true, false, fijos.get("E", []))
	if lados.contains("O"):
		var a := z0 + (FONDO if no else 0.0)
		_fila(Vector3(x0, 0, a), Vector3.BACK, z1 - (FONDO if so else 0.0) - a, -PI / 2.0, pool, true, true, false, fijos.get("O", []))
	if patio:
		_corazon_de_manzana(r.grow(-FONDO))


## Pieza de esquina, o una torre hito si en esa esquina va una (Fase 3, ver NivelAlto). Con la torre se
## sacan igual los nombres de los locales que hubiera usado la pieza: así el resto de la ciudad no cambia.
func _esquina(nombre: String, pos: Vector3, rot: float) -> void:
	if not NivelAlto.torre_en(self, pos):
		_poner(nombre, pos, rot)
		return
	for c: Array in Kit.carteles(nombre, Transform3D(Basis.from_euler(Vector3(0, rot, 0)), pos)):
		if c[4] == "local":
			_nombre_local(nombre)


# ---------------------------------------------------------------- Corazón de manzana

const ALTO_MEDIANERA := 2.4      ## Paredes bajas entre lote y lote del corazón de manzana
const COLORES_CASA := ["fachada_crema", "fachada_rosa", "fachada_celeste", "fachada_verde", "fachada_amarilla",
	"fachada_lila", "fachada_beige", "fachada_menta", "fachada_salmon", "fachada_gris", "ladrillo", "fachada_ocre"]
const COLORES_PRETIL := ["blanco", "remate_crema", "remate_marron", "remate_verde", "remate_azul", "piedra"]
const PISOS_AZOTEA := ["azotea", "azotea", "techo", "piedra_osc"]
const PISOS_PATIO := ["azotea", "piedra_osc", "lajas", "vereda", "tejas"]
const ARBOLES_PATIO := ["arbol_grande_A", "arbol_grande_B", "jacaranda_grande"]

var _colores_kit := {}


## Color de la paleta del kit por nombre (las cajas sueltas usan los mismos colores que las piezas).
func _c(nombre: String) -> Color:
	if _colores_kit.is_empty():
		for p: Array in KitDatos.PALETA:
			_colores_kit[p[0]] = Color(p[1] as String)
	return _colores_kit.get(nombre, Color.MAGENTA)


func _al_azar(lista: Array) -> Variant:
	return lista[_rng.randi() % lista.size()]


## Caja de color con su colisión en el cuerpo de la celda (Construir.caja con colisión crea un cuerpo
## por cada caja).
func _bloque(c: Vector3, tam: Vector3, color: Color, col := true) -> void:
	Construir.caja(self, c, tam, color, false)
	if col:
		var forma := BoxShape3D.new()
		forma.size = tam
		Kit._forma(_cuerpo_en(c), forma, Transform3D(Basis.IDENTITY, c))


## Corazón de manzana (mapa V3.1; antes era un pulmón de pasto que parecía una plaza metida en un
## callejón): lotes como los del fondo de una manzana porteña. Cada lote está pegado al fondo de un
## edificio y tiene una casa baja o un PH de una o dos plantas (con azotea, pretil de color y tanque),
## un galpón de chapa, un patio de baldosas o un jardincito; entre lote y lote, medianeras bajas. Todo
## tiene colisión: las palomas se pueden posar en techos y paredes.
func _corazon_de_manzana(r: Rect2) -> void:
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	var lista: Array[Rect2] = []
	_partir_lotes(r, lista)
	lotes += lista.size()
	for l in lista:
		_lote(l, r)
	# Medianeras: en el borde este y en el sur de cada lote, salvo en el borde del corazón (ahí está el
	# fondo de los edificios). Así cada pared se pone una sola vez.
	var y := Y_VEREDA + ALTO_MEDIANERA / 2.0
	var color := _c("medianera")
	for l in lista:
		if l.end.x < r.end.x - 0.01:
			_bloque(Vector3(l.end.x, y, l.get_center().y), Vector3(0.2, ALTO_MEDIANERA, l.size.y), color)
		if l.end.y < r.end.y - 0.01:
			_bloque(Vector3(l.get_center().x, y, l.end.y), Vector3(l.size.x, ALTO_MEDIANERA, 0.2), color)


## Parte el corazón en lotes de 6 a 14 m de ancho y hasta 16 m de fondo (cortes al azar, a metro).
func _partir_lotes(r: Rect2, out: Array[Rect2]) -> void:
	var lx := r.size.x
	var lz := r.size.y
	var cortar_x := lx > 14.0 or (lx >= 12.0 and _rng.randf() < 0.4)
	var cortar_z := lz > 16.0 or (lz >= 13.0 and _rng.randf() < 0.3)
	if cortar_x and (not cortar_z or lx / 14.0 >= lz / 16.0):
		var c := float(_rng.randi_range(6, int(lx) - 6))
		_partir_lotes(Rect2(r.position, Vector2(c, lz)), out)
		_partir_lotes(Rect2(r.position + Vector2(c, 0), Vector2(lx - c, lz)), out)
	elif cortar_z:
		var c := clampf(roundf(lz / 2.0 + _rng.randf_range(-3.0, 3.0)), 6.0, lz - 6.0)
		_partir_lotes(Rect2(r.position, Vector2(lx, c)), out)
		_partir_lotes(Rect2(r.position + Vector2(0, c), Vector2(lx, lz - c)), out)
	else:
		out.append(r)


## Lado del lote pegado al fondo de un edificio ("N", "S", "E" u "O"); si no toca ninguno, uno al azar.
func _lado_lote(l: Rect2, r: Rect2) -> String:
	var lados: Array[String] = []
	if absf(l.position.y - r.position.y) < 0.01:
		lados.append("N")
	if absf(l.end.y - r.end.y) < 0.01:
		lados.append("S")
	if lados.is_empty():
		if absf(l.position.x - r.position.x) < 0.01:
			lados.append("O")
		if absf(l.end.x - r.end.x) < 0.01:
			lados.append("E")
	if lados.is_empty():
		lados.assign(["N", "S", "E", "O"])
	return lados[_rng.randi() % lados.size()]


## Punto del lote en coordenadas locales: "u" a lo largo del lado pegado al edificio (0 en el medio) y
## "v" hacia adentro desde ese lado; "y" es la altura.
func _pl(l: Rect2, lado: String, u: float, v: float, y: float) -> Vector3:
	match lado:
		"N": return Vector3(l.get_center().x + u, y, l.position.y + v)
		"S": return Vector3(l.get_center().x - u, y, l.end.y - v)
		"O": return Vector3(l.position.x + v, y, l.get_center().y - u)
	return Vector3(l.end.x - v, y, l.get_center().y + u)


## Tamaño en ejes del mundo de una caja de "ancho" a lo largo del lado, "alto" y "prof" hacia adentro.
func _tl(lado: String, ancho: float, alto: float, prof: float) -> Vector3:
	return Vector3(ancho, alto, prof) if lado == "N" or lado == "S" else Vector3(prof, alto, ancho)


## Giro en Y de una pieza del kit (que mira a +Z) para que mire hacia adentro del lote.
func _rl(lado: String) -> float:
	match lado:
		"S": return PI
		"O": return PI / 2.0
		"E": return -PI / 2.0
	return 0.0


func _lote(l: Rect2, r: Rect2) -> void:
	var lado := _lado_lote(l, r)
	var a := l.size.x if lado == "N" or lado == "S" else l.size.y      # ancho a lo largo del lado
	var d := l.size.y if lado == "N" or lado == "S" else l.size.x      # fondo hacia adentro
	var dado := _rng.randf()
	if dado < 0.52:
		# Casa baja o PH, pegada al fondo del edificio, y su patio del lado de adentro
		var pisos := 1 if _rng.randf() < 0.62 else 2
		var prof := d if d < 8.0 else roundf(d * _rng.randf_range(0.5, 0.75))
		_casa(l, lado, a, prof, pisos)
		if d - prof > 1.5:
			_patio(l, lado, a, prof, d)
	elif dado < 0.64:
		var prof := d if d < 9.0 else roundf(d * _rng.randf_range(0.6, 0.85))
		_galpon(l, lado, a, prof)
		if d - prof > 1.5:
			_patio(l, lado, a, prof, d)
	elif dado < 0.84:
		_patio(l, lado, a, 0.0, d)
	else:
		_jardincito(l, lado, a, d)


## Casa baja o PH de "pisos" plantas, de "prof" metros desde el fondo del edificio: paredes de color,
## puerta y ventanas hacia el patio y azotea con pretil de color, tanque y alguna cosa más.
func _casa(l: Rect2, lado: String, ancho: float, prof: float, pisos: int) -> void:
	var y0 := Y_VEREDA
	var h := 3.0 * pisos + 0.2
	var a := ancho - 0.24     # deja lugar para la medianera entre lotes
	var p := prof - 0.12
	var vm := 0.12 + p / 2.0
	_bloque(_pl(l, lado, 0, vm, y0 + h / 2.0), _tl(lado, a, h, p), _c(_al_azar(COLORES_CASA)))
	# Azotea: piso, pretil de color alrededor y lo que haya arriba
	_bloque(_pl(l, lado, 0, vm, y0 + h + 0.02), _tl(lado, a - 0.36, 0.04, p - 0.36), _c(_al_azar(PISOS_AZOTEA)), false)
	const PR := 0.55
	var cp := _c(_al_azar(COLORES_PRETIL))
	for s: float in [-1.0, 1.0]:
		_bloque(_pl(l, lado, s * (a / 2.0 - 0.09), vm, y0 + h + PR / 2.0), _tl(lado, 0.18, PR, p), cp)
	for v: float in [0.21, 0.03 + p]:
		_bloque(_pl(l, lado, 0, v, y0 + h + PR / 2.0), _tl(lado, a - 0.36, PR, 0.18), cp)
	var arriba := y0 + h + 0.04
	var rot := _rl(lado)
	if _rng.randf() < 0.75 and a > 3.0 and p > 3.0:
		_poner("tanque", _pl(l, lado, _rng.randf_range(-0.5, 0.5) * (a - 2.4), 0.12 + p - 1.3, arriba), rot)
	var extra := _rng.randf()
	if extra < 0.35 and a > 4.5 and p > 3.5:
		_poner("tendedero", _pl(l, lado, 0, 0.12 + p * 0.4, arriba), rot, Vector3.ONE, false)
	elif extra < 0.6 and not Ajustes.movil:
		for k in _rng.randi_range(1, 3):
			if k * 1.3 + 0.4 < a:
				_poner(_al_azar(["maceton", "maceton_flores"]), _pl(l, lado, k * 1.3 - a / 2.0, 0.9, arriba), _rng.randf() * TAU)
	# Puerta y ventanas hacia el patio (si la casa es angosta y profunda, el frente da a la medianera)
	var vf := 0.12 + p + 0.02
	if prof >= _d_lote(l, lado) - 0.01 and a < 5.0:
		return
	_bloque(_pl(l, lado, -a * 0.25, vf, y0 + 1.05), _tl(lado, 0.9, 2.1, 0.04), _c("madera"), false)
	for k in pisos:
		for u: float in ([a * 0.2] if k == 0 else [-a * 0.25, a * 0.2]):
			if absf(u) + 0.6 < a / 2.0:
				_bloque(_pl(l, lado, u, vf, y0 + 1.6 + 3.0 * k), _tl(lado, 1.1, 1.1, 0.04), _c("vidrio_osc"), false)


## Fondo del lote hacia adentro (la medida perpendicular al lado pegado al edificio).
func _d_lote(l: Rect2, lado: String) -> float:
	return l.size.y if lado == "N" or lado == "S" else l.size.x


## Galpón o taller del fondo: paredes de ladrillo o revoque, techo de chapa con nervaduras y un portón.
func _galpon(l: Rect2, lado: String, ancho: float, prof: float) -> void:
	var y0 := Y_VEREDA
	var h := _rng.randf_range(3.4, 4.2)
	var a := ancho - 0.24
	var p := prof - 0.12
	var vm := 0.12 + p / 2.0
	_bloque(_pl(l, lado, 0, vm, y0 + h / 2.0), _tl(lado, a, h, p), _c(_al_azar(["ladrillo", "medianera", "fachada_gris"])))
	var chapa := _c("chapa")
	var sale := 0.3 if prof < _d_lote(l, lado) - 0.5 else 0.0      # el alero sólo si hay patio adelante
	_bloque(_pl(l, lado, 0, vm + sale / 2.0, y0 + h + 0.04), _tl(lado, a + 0.1, 0.08, p + sale), chapa)
	var n := maxi(int(a / 1.2), 1)
	for k in n:
		_bloque(_pl(l, lado, -a / 2.0 + (k + 0.5) * a / n, vm + sale / 2.0, y0 + h + 0.1), _tl(lado, 0.07, 0.05, p + sale),
			chapa.darkened(0.12), false)
	if sale > 0.0:
		_bloque(_pl(l, lado, 0, 0.12 + p + 0.02, y0 + 1.4), _tl(lado, minf(3.0, a - 1.0), 2.8, 0.05), chapa.darkened(0.25), false)


## Patio de baldosas de "v0" a "v1" metros desde el fondo del edificio, con alguna de estas cosas: un
## tendedero, una mesa con sombrilla, una parrilla de ladrillos, un arbolito, macetas o una bici.
func _patio(l: Rect2, lado: String, ancho: float, v0: float, v1: float) -> void:
	var y0 := Y_VEREDA
	var d := v1 - v0
	var a := ancho - 0.2
	_bloque(_pl(l, lado, 0, v0 + d / 2.0, y0 + 0.01), _tl(lado, a, 0.02, d - 0.1), _c(_al_azar(PISOS_PATIO)), false)
	var piso := y0 + 0.02
	var rot := _rl(lado)
	if d >= 2.5 and a >= 4.0 and _rng.randf() < 0.55:
		_poner("tendedero", _pl(l, lado, 0, v0 + d * 0.5, piso), rot, Vector3.ONE, false)
	elif d >= 4.0 and a >= 5.0 and _rng.randf() < 0.5:
		_poner(_al_azar(["mesa_cafe_roja", "mesa_cafe_verde"]), _pl(l, lado, 0, v0 + d * 0.5, piso), rot)
	if _rng.randf() < 0.3 and a >= 4.0 and d >= 2.5:
		# Parrilla de ladrillos contra la medianera, con su chimenea
		var s := 1.0 if _rng.randf() < 0.5 else -1.0
		var u := s * (a / 2.0 - 0.55)
		_bloque(_pl(l, lado, u, v1 - 0.9, piso + 0.5), _tl(lado, 0.9, 1.0, 1.3), _c("ladrillo"))
		_bloque(_pl(l, lado, u, v1 - 1.1, piso + 1.6), _tl(lado, 0.45, 1.2, 0.45), _c("ladrillo").darkened(0.1))
		_bloque(_pl(l, lado, u, v1 - 1.1, piso + 2.25), _tl(lado, 0.6, 0.1, 0.6), _c("hierro"), false)
	elif _rng.randf() < 0.35 and d >= 4.0:
		_poner(_al_azar(ARBOLES_PATIO), _pl(l, lado, _rng.randf_range(-0.3, 0.3) * a, v1 - 1.6, piso),
			_rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.5, 0.65))
	if not Ajustes.movil:
		if _rng.randf() < 0.6:
			var s := 1.0 if _rng.randf() < 0.5 else -1.0
			_poner(_al_azar(["maceton", "maceton_flores"]), _pl(l, lado, s * (a / 2.0 - 0.7), v1 - 0.7, piso), _rng.randf() * TAU)
		if _rng.randf() < 0.15 and d >= 2.0:
			_bici(_pl(l, lado, 0.0, v0 + 0.5, piso), rot + PI / 2.0)


## Jardincito del fondo: pasto, un árbol, flores y, a veces, una pelopincho.
func _jardincito(l: Rect2, lado: String, ancho: float, d: float) -> void:
	var y0 := Y_VEREDA
	var a := ancho - 0.2
	_bloque(_pl(l, lado, 0, d / 2.0, y0 + 0.02), _tl(lado, a, 0.04, d - 0.1), _c("pasto"), false)
	var piso := y0 + 0.04
	_poner(_al_azar(ARBOLES_PATIO), _pl(l, lado, _rng.randf_range(-0.25, 0.25) * a, d * _rng.randf_range(0.3, 0.7), piso),
		_rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.6, 0.8))
	if _rng.randf() < 0.35 and a >= 5.0 and d >= 6.0:
		# Pelopincho: borde de lona azul y el agua
		var c := _pl(l, lado, a * 0.22, d - 2.0, piso)
		_bloque(c + Vector3(0, 0.17, 0), _tl(lado, 2.6, 0.34, 1.9), _c("plastico_azul"))
		Construir.caja(self, c + Vector3(0, 0.33, 0), _tl(lado, 2.36, 0.03, 1.66), _c("agua"), false)
	for k in (2 if Ajustes.movil else 4):
		var q := _pl(l, lado, _rng_flores.randf_range(-0.4, 0.4) * a, _rng_flores.randf_range(0.6, d - 0.6), piso)
		_poner(_al_azar(FLORES + ARBUSTOS), q, _rng_flores.randf() * TAU, Vector3.ONE, false)


## Matas de flores, arbustos y pasto alto al azar alrededor de "c" (sobre el pasto del parque).
func _flores_en(c: Vector3, radio: float, cantidad: int) -> void:
	for k in cantidad:
		var p := c + Vector3(_rng_flores.randf_range(-radio, radio), T_PARQUE, _rng_flores.randf_range(-radio, radio))
		var dado := _rng_flores.randf()
		if dado < 0.6:
			_poner(FLORES[_rng_flores.randi() % FLORES.size()], p, _rng_flores.randf() * TAU, Vector3.ONE, false)
		elif dado < 0.8:
			_poner(ARBUSTOS[_rng_flores.randi() % ARBUSTOS.size()], p, _rng_flores.randf() * TAU, Vector3.ONE, false)
		else:
			_poner("mata_pasto", p, _rng_flores.randf() * TAU, Vector3.ONE, false)


func _manzanas() -> void:
	# Norte: la farmacia sobre Rivadavia, mirando a la plaza
	_manzana(NORTE, "NSEO", POOL_CENTRO, ESQ_CENTRO, true, {"S": ["farmacia_8"]})
	# Sur: la golosinería sobre el pasaje
	_manzana(SUR, "NSEO", POOL_CENTRO, ESQ_CENTRO, true, {"N": ["golosineria_8"]})
	# Este: el hospital sobre Paseo Colón y la comisaría sobre Reconquista (frente al barrio enemigo)
	_manzana(ESTE, "NSEO", POOL_CENTRO, ESQ_CENTRO, true, {"O": ["hospital_32"], "S": ["comisaria_20"]})
	# Comerciales: los locales temáticos sobre la Peatonal Florida y la Av. de Mayo
	_manzana(COMERCIAL_A, "NSEO", POOL_COMERCIAL, ESQ_COMERCIAL, true,
		{"S": ["panaderia_8", "cafe_10", "ropa_10"], "N": ["minimercado_10"]})
	_manzana(COMERCIAL_B, "NSEO", POOL_COMERCIAL, ESQ_COMERCIAL, true, {"N": ["taller_12", "cafe_10"]})


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
		if i >= 12 and i <= 16 and j >= 11 and j <= 13:
			return true                           # la cancha de básquet
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
				# Mapa V3: menos árboles pero grandes, y muchas flores (como en las referencias)
				var dado := _rng.randf()
				if dado < 0.08:
					_poner("jacaranda_banco", c, _rng.randi_range(0, 3) * PI / 2.0)
				elif dado < 0.13:
					_poner("plaza_cantero", c, 0.0)
				else:
					Kit.colocar(self, "pasto", c)
					if _rng.randf() < 0.42:
						_poner(ARBOLES[_rng.randi() % ARBOLES.size()], c + Vector3(_rng.randf_range(-1.4, 1.4), T_PARQUE,
							_rng.randf_range(-1.4, 1.4)), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(0.85, 1.1))
					_flores_en(c, 2.5, _rng_flores.randi_range(1, 2) if Ajustes.movil else _rng_flores.randi_range(2, 4))
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
	_cancha()


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
	# Los juegos que se mueven sólo se mueven con chicos arriba (world/animado.gd, enemies/chico.gd).
	# Cada uno sabe dónde va sentado cada chico (mirando a -Z en el espacio de la pieza) y dónde se para
	# para subirse.
	# Calesita (la parte de arriba gira): tres lugares sobre la plataforma, mirando hacia donde gira
	var cc := c + Vector3(7, y, -4)
	_poner("calesita_base", cc)
	var cal := _animado("calesita_giro", cc, 0.0, "girar", 0.45)
	Calesita.armar(cal, cc)   # Columna, techo y caballitos sólidos; los 6 caballitos son los asientos
	# Hamacas de madera: el marco fijo y cada asiento se hamaca sobre el eje de arriba; el chico mira
	# hacia la plaza (al sur)
	_poner("hamaca_madera", c + Vector3(-6, y, -6.5))
	var columpios: Array[Animado] = []
	for x: float in [-0.65, 0.65]:
		var h := _animado("hamaca_asiento", c + Vector3(-6 + x, y + 2.5, -6.5), 0.0, "hamacar", 2.1 + x * 0.1, 0.6)
		h.asientos.append([Transform3D(Basis(Vector3.UP, PI), Vector3(0, -1.95, 0)), c + Vector3(-6 + x, y, -5.7)])
		# Lugar de la paloma en el asiento (hijo de la hamaca: se hamaca con ella), mirando al sur
		var asiento_m := Marker3D.new()
		asiento_m.name = "AsientoColumpio"
		asiento_m.set_meta("indice", 0)
		asiento_m.add_to_group("caballitos")
		h.add_child(asiento_m)
		asiento_m.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, -1.9, 0))
		h.radio_baile = 2.6
		columpios.append(h)
	columpios[0].compania = columpios[1]
	columpios[1].compania = columpios[0]
	_poner("tobogan_torre", c + Vector3(-9, y, 4), deg_to_rad(20))
	# Marcador del tobogán (en el espacio de la pieza: la rampa baja hacia +X): por ahí se desliza la paloma
	var tob := Marker3D.new()
	tob.name = "Tobogan"
	tob.add_to_group("toboganes")
	add_child(tob)
	tob.position = c + Vector3(-9, y, 4)
	tob.rotation.y = deg_to_rad(20)
	_poner("subibaja_base", c + Vector3(9, y, 6))
	var sb := _animado("subibaja_tabla", c + Vector3(9, y + 0.5, 6), 0.0, "subibaja", 1.4, 0.25)
	for s: float in [1.0, -1.0]:
		sb.asientos.append([Transform3D(Basis(Vector3.UP, s * PI / 2.0), Vector3(s * 1.45, 0.13, 0)),
			c + Vector3(9 + s * 1.5, y, 6.8)])
	# Lugares de las palomas en el subibaja (hijos de la tabla, suben y bajan con ella): los dos asientos
	# (grupo "caballitos", como los de la calesita) y, más adentro, el lugar de la paloma que salta de
	# un lado al otro ("extras_subibaja"; el índice 2 + lado es el de la punta "lado").
	sb.radio_baile = 3.1
	for k in 4:
		var lado := 1.0 if k % 2 == 0 else -1.0
		var pm := Marker3D.new()
		pm.name = "Asiento%d" % k if k < 2 else "Salto%d" % k
		pm.set_meta("indice", k)
		pm.add_to_group("caballitos" if k < 2 else "extras_subibaja")
		sb.add_child(pm)
		pm.transform = Transform3D(Basis(Vector3.UP, lado * PI / 2.0), Vector3(lado * (1.45 if k < 2 else 0.95), 0.11, 0.0))
	# Colisión del subibaja: la tabla (se mueve con ella) y la base fija con el eje
	var tabla_col := AnimatableBody3D.new()
	tabla_col.name = "Solidos"
	tabla_col.sync_to_physics = false
	tabla_col.collision_layer = 1
	tabla_col.collision_mask = 0
	var f_tabla := BoxShape3D.new()
	f_tabla.size = Vector3(3.4, 0.14, 0.3)
	var cs_tabla := CollisionShape3D.new()
	cs_tabla.shape = f_tabla
	cs_tabla.position = Vector3(0, 0.0, 0)
	tabla_col.add_child(cs_tabla)
	sb.add_child(tabla_col)
	var base_col := StaticBody3D.new()
	base_col.name = "BaseSubibaja"
	base_col.collision_layer = 1
	var f_base := BoxShape3D.new()
	f_base.size = Vector3(0.3, 0.45, 0.5)
	var cs_base := CollisionShape3D.new()
	cs_base.shape = f_base
	cs_base.position = Vector3(0, 0.225, 0)
	base_col.add_child(cs_base)
	add_child(base_col)
	base_col.position = c + Vector3(9, y, 6)
	for j: Animado in [cal, sb]:
		j.add_to_group("juegos_plaza")
	for h in get_children():
		if h is Animado and (h as Animado).tipo == "hamacar":
			h.add_to_group("juegos_plaza")
	_poner("arenero", c + Vector3(0.5, y, 1.5))
	var m := Marker3D.new()
	m.add_to_group("zona_chicos")
	m.set_meta("tam", Vector2(26, 18))
	m.set_meta("cantidad", 3 if Ajustes.movil else 5)
	m.set_meta("arenero", c + Vector3(0.5, y + 0.1, 1.5))
	add_child(m)
	m.position = c + Vector3(0, y, 1)
	# Caballitos de resorte
	_poner("resorte_dino", c + Vector3(3.5, y, 7.5), 0.4)
	_poner("resorte_elefante", c + Vector3(-2.0, y, 8.0), -0.3)
	_poner("resorte_dino", c + Vector3(12.5, y, -1.0), 2.0)
	# Cerco bajo de palos de colores alrededor (con la entrada al sur, donde llega el camino)
	var x0 := c.x - 16.5
	var x1 := c.x + 16.5
	var z0 := c.z - 13.5
	var z1 := c.z + 13.5
	_cerco("cerco_colores", Vector3(x0, T_PARQUE, z0), Vector3(x1, T_PARQUE, z0), [])
	_cerco("cerco_colores", Vector3(x1, T_PARQUE, z0), Vector3(x1, T_PARQUE, z1), [])
	_cerco("cerco_colores", Vector3(x1, T_PARQUE, z1), Vector3(x0, T_PARQUE, z1), [6])
	_cerco("cerco_colores", Vector3(x0, T_PARQUE, z1), Vector3(x0, T_PARQUE, z0), [])
	_poner("cartel_madera", Vector3(-108, T_PARQUE, -76.4), 0.0, Vector3.ONE, true, {"madera": "Plaza de juegos"})
	for x: float in [-12.0, 12.0]:
		_poner("banco_listones", c + Vector3(x, y, 11.6), PI)
	for p: Vector3 in [Vector3(-14.5, 0, -11.5), Vector3(14.5, 0, -11.5), Vector3(14.5, 0, 11.5)]:
		_poner("arbol_grande_B", c + p + Vector3(0, T_PARQUE, 0), _rng.randf() * TAU, Vector3.ONE * 0.8)
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
	# Mitad oeste: circuito de agility. Una pista de tierra en rectángulo y los obstáculos en fila sobre
	# cada recta, cruzados al paso: vallas al norte y al este, la rampa al oeste y el túnel al sur. Un
	# perro lo recorre cada tanto (ver PISTA_AGILITY y world/animal.gd).
	var p := PISTA_AGILITY
	_pista_tierra(p, 1.6, y)
	for x: float in [-182.0, -177.5, -173.0]:
		_poner("agility_salto", Vector3(x, y, p.position.y), PI / 2.0)
	for z: float in [-32.0, -27.5]:
		_poner("agility_salto", Vector3(p.end.x, y, z), 0.0)
	_poner("agility_rampa", Vector3(p.position.x, y, p.get_center().y), 0.0)
	_poner("agility_tunel", Vector3(p.get_center().x, y, p.end.y), 0.0)
	_poner("arbol_E", Vector3(-189.4, y, -21.2), 2.0)
	# Mitad este: lugar libre para correr, con los bancos de los dueños a la sombra contra la reja sur, el
	# bebedero y el tacho al lado del portón
	_poner("bebedero", Vector3(-149.5, y, -22.5))
	_poner("tacho", Vector3(-147.4, y, -36.0), PI / 2.0)
	_poner("cartel_madera", Vector3(-143.6, y, -36.5), PI / 2.0, Vector3.ONE, true, {"madera": "Parque de perros"})
	_poner("arbol_A", Vector3(-158, y, -21.5), 0.7)
	_poner("arbol_E", Vector3(-153.5, y, -39.0), 1.1)
	for x: float in [-157.0, -150.0]:
		_poner("banco", Vector3(x, y, -38.3), PI)     # de espaldas a la reja, mirando a los perros
	_senora(Vector3(-150.0, y, -38.3), 0.0, "")
	# Los perros (world/animal.gd): el negro sentado al lado de su dueña, uno echado a la sombra, dos que
	# pasean por la mitad libre y el blanco, que cada tanto hace el circuito
	_animal("perro_negro", Vector3(-151.2, y, -36.4), PI, "sentado")
	_animal("perro_marron", Vector3(-156.0, y, -21.6), 2.4, "echado", 1.1)
	var zona := Rect2(-165.0, z0 + 2.5, x1 - 2.5 + 165.0, z1 - z0 - 5.0)
	for k in 2:
		var q := Vector3(_rng.randf_range(zona.position.x, zona.end.x), y, _rng.randf_range(zona.position.y, zona.end.y))
		_animal(["perro_marron", "perro_negro"][k], q, _rng.randf() * TAU, "pasear", [1.0, 0.92][k]).zona = zona
	var ag := _animal("perro_blanco", Vector3(-160.0, y, -30.0), -PI / 2.0, "agility", 0.85)
	ag.zona = Rect2(x0 + 1.5, z0 + 1.5, x1 - x0 - 3.0, z1 - z0 - 3.0)
	ag.pista = PackedVector3Array([Vector3(p.end.x, y, p.position.y), Vector3(p.position.x, y, p.position.y),
		Vector3(p.position.x, y, p.end.y), Vector3(p.end.x, y, p.end.y)])
	ag.obstaculos = [["valla", Vector3(-173.0, y, p.position.y)], ["valla", Vector3(-177.5, y, p.position.y)],
		["valla", Vector3(-182.0, y, p.position.y)], ["rampa", Vector3(p.position.x, y, p.get_center().y)],
		["tunel", Vector3(p.get_center().x, y, p.end.y)], ["valla", Vector3(p.end.x, y, -32.0)],
		["valla", Vector3(p.end.x, y, -27.5)]]
	# Los dueños esperan del lado del portón, lejos de la pista
	_paseo(Vector3(-155, y, -29), Vector2(12, 12), 2, "turista", "")


## Pista del circuito de agility del parque de perros (rectángulo por el medio de la pista).
const PISTA_AGILITY := Rect2(-187.5, -36.5, 20.0, 13.0)


## Pista de tierra de "ancho" metros alrededor del rectángulo "r" (las rectas norte y sur cubren las
## esquinas, así no hay dos tiras encimadas).
func _pista_tierra(r: Rect2, ancho: float, y: float) -> void:
	var c := C_TIERRA.lightened(0.18)
	for z: float in [r.position.y, r.end.y]:
		Construir.caja(self, Vector3(r.get_center().x, y + 0.002, z), Vector3(r.size.x + ancho, 0.03, ancho), c, false)
	for x: float in [r.position.x, r.end.x]:
		Construir.caja(self, Vector3(x, y + 0.002, r.get_center().y), Vector3(ancho, 0.03, r.size.y - ancho), c, false)


## Cancha de básquet en el sureste del parque, con sus aros, una pelota, bancos y un par de árboles.
func _cancha() -> void:
	var c := Vector3(-110, T_PARQUE, -37)
	_poner("cancha_basquet", c, 0.0, Vector3.ONE, false)
	_poner("aro_basquet", c + Vector3(-12.6, 0.035, 0), PI / 2.0)
	_poner("aro_basquet", c + Vector3(12.6, 0.035, 0), -PI / 2.0)
	_poner("pelota", c + Vector3(3.0, 0.035, 2.0), 0.0, Vector3.ONE, false)
	for x: float in [-6.0, 0.0, 6.0]:
		_poner("banco_listones", c + Vector3(x, 0, -8.6), 0.0)
	for p: Vector3 in [Vector3(-14.5, 0, -8.5), Vector3(14.5, 0, -8.5), Vector3(14.5, 0, 8.5), Vector3(-14.5, 0, 8.5)]:
		_poner(["arbol_grande_A", "pino_B"][_rng.randi() % 2], c + p, _rng.randf() * TAU)
	var forma := BoxShape3D.new()
	forma.size = Vector3(28, 0.04, 16)
	Kit._forma(_cuerpo_en(c), forma, Transform3D(Basis.IDENTITY, c + Vector3(0, 0.02, 0)))
	_paseo(c + Vector3(0, 0.04, 0), Vector2(22, 10), 2, "turista", "")


## El easter egg de Bolt: su cucha escondida entre los arbustos del lado oeste del parque.
func _bolt() -> void:
	var y := T_PARQUE
	_poner("cucha", Vector3(-191.5, y, -61), PI / 2.0, Vector3.ONE, true, {"cucha": "BOLT"})
	_animal("perro_bolt", Vector3(-189.6, y, -61.2), PI / 2.0, "dormilon")
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
	# El barrio: casas bajas sobre Paseo Colón (con un pasillo de entrada), al sur y al este. Mapa V4.5:
	# las casas las arma Barrio (paredes, puertas, ventanas con rejas y techos bien apoyados) en vez de
	# las piezas barrio_* del kit
	Barrio.reiniciar()
	Barrio.fila(self, Vector3(x0, 0, 50), Vector3.BACK, 20.0, -PI / 2.0, _rng)
	Barrio.fila(self, Vector3(x0, 0, 74), Vector3.BACK, z1 - 74.0, -PI / 2.0, _rng)
	Barrio.fila(self, Vector3(x1, 0, 42), Vector3.BACK, z1 - 42.0, PI / 2.0, _rng)
	Barrio.fila(self, Vector3(x0 + 12.0, 0, z1), Vector3.RIGHT, r.size.x - 24.0, 0.0, _rng)
	# Casas sueltas adentro, mirando al potrero
	Barrio.fila(self, Vector3(100, 0, 52), Vector3.RIGHT, 26.0, 0.0, _rng)
	Barrio.fila(self, Vector3(150, 0, 52), Vector3.RIGHT, 26.0, 0.0, _rng)
	Barrio.fila(self, Vector3(104, 0, 86), Vector3.RIGHT, 30.0, PI, _rng)
	Barrio.fila(self, Vector3(146, 0, 86), Vector3.RIGHT, 30.0, PI, _rng)
	# La guarida de la banda de los BadJokes, al este del potrero (ver Barrio.guarida)
	Barrio.guarida(self, _rng)
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
	# El partido de fútbol 5 contra 5 de la banda (pelota en el centro, ver world/partido_futbol.gd). Va como hermano
	# de la ciudad (no adentro) para que la fusión de mallas no se lleve la pelota
	var partido := PartidoFutbol.new()
	partido.name = "PartidoFutbol"
	get_parent().add_child.call_deferred(partido)
	# Paredones de chapa con grafitis, autos abandonados, basura
	_cerco("chapa_cerco", Vector3(112, Y_VEREDA, 55), Vector3(124, Y_VEREDA, 55), [])
	_cerco("chapa_cerco_b", Vector3(150, Y_VEREDA, 55), Vector3(162, Y_VEREDA, 55), [])
	_cerco("chapa_cerco", Vector3(94, Y_VEREDA, 64), Vector3(94, Y_VEREDA, 79), [2])
	# El paredón de la guarida, con la entrada frente al portón
	_cerco("chapa_cerco_b", Vector3(166, Y_VEREDA, 60), Vector3(166, Y_VEREDA, 78), [2, 3])
	# El cartel pintado en el paredón que se ve al entrar por el pasillo
	_texto(Vector3(93.9, 1.25, 68.5), -PI / 2.0, "PROHIBIDO\nPALOMAS", 2.6, 1.0, Color("ff5fb0"), 70.0)
	_poner("auto_abandonado", Vector3(105, Y_VEREDA, 30), 0.3)
	_poner("auto_abandonado", Vector3(172, Y_VEREDA, 34), 2.5)
	for p: Vector3 in [Vector3(100, Y_VEREDA, 34), Vector3(158, Y_VEREDA, 32), Vector3(131, Y_VEREDA, 82)]:
		_poner("contenedor", p, _rng.randf() * TAU)
		_poner("bolsas", p + Vector3(1.6, 0, 0.6), _rng.randf() * TAU, Vector3.ONE, false)
	for k in 5:
		_poner("tendedero", Vector3(_rng.randf_range(100, 175), Y_VEREDA, _rng.randf_range(22, 40)), _rng.randf() * TAU,
			Vector3.ONE, false)
	_poner("tanque", Vector3(140, Y_VEREDA, 36))
	# Los gatos del barrio: en las azoteas de las casas y cerca del potrero
	var gatos := ["gato_naranja", "gato_negro", "gato_gris"]
	for k in mini(8, Barrio.azoteas.size()):
		var p: Vector3 = Barrio.azoteas[(k * 5) % Barrio.azoteas.size()]
		_animal(gatos[k % 3], p, _rng.randf() * TAU, "gato", 0.55)
	for p: Vector3 in [Vector3(153, Y_VEREDA + 0.02, 56), Vector3(108, Y_VEREDA, 33)]:
		_animal(gatos[_rng.randi() % 3], p, _rng.randf() * TAU, "gato", 0.55)
	_animal("gato_negro", Vector3(105.2, Y_VEREDA + 1.81, 29.95), 1.0, "gato", 0.6)
	# Uno que da vueltas por el potrero
	_animal("gato_naranja", Vector3(120, Y_VEREDA + 0.02, 81), 0.0, "gato_paseo", 0.55).zona = Rect2(114, 76, 12, 10)


# ---------------------------------------------------------------- Peatonal y pasaje

func _peatonal() -> void:
	var z := (PEATONAL[1] + PEATONAL[3]) / 2.0
	var x := PEATONAL[0] + 8.0
	var k := 0
	while x < PEATONAL[2] - 6.0:
		match k % 4:
			0:
				_poner("cazuela", Vector3(x, Y_VEREDA, z))
				_poner(ARBOLES_VEREDA[_rng.randi() % ARBOLES_VEREDA.size()], Vector3(x, Y_VEREDA, z), _rng.randf() * TAU,
					Vector3.ONE * 0.7)
			1:
				_poner("farola_curva", Vector3(x, Y_VEREDA, z), PI / 2.0)
				_poner("banco_listones", Vector3(x - 1.5, Y_VEREDA, z - 1.2), PI)
				_poner("banco_listones", Vector3(x + 1.5, Y_VEREDA, z + 1.2), 0.0)
			2:
				# Mesas de los cafés en el medio de la peatonal
				_poner(["mesa_cafe_roja", "mesa_cafe_verde"][_rng.randi() % 2], Vector3(x - 1.6, Y_VEREDA, z), 0.0)
				_poner(["maceton_flores", "maceton"][_rng.randi() % 2], Vector3(x + 1.4, Y_VEREDA, z), 0.0)
			3:
				if k == 7:
					_poner("kiosco_diarios", Vector3(x, Y_VEREDA, z), PI / 2.0)
				else:
					_poner("tacho", Vector3(x, Y_VEREDA, z - 0.8))
					_bici(Vector3(x + 1.5, Y_VEREDA, z + 1.5), 0.0)
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
		elif k % 4 == 1:
			_poner(["mesa_cafe_roja", "mesa_cafe_verde"][_rng.randi() % 2], Vector3(x + 3.0, Y_VEREDA, z + 0.6), 0.0)
		else:
			_bici(Vector3(x + 3.0, Y_VEREDA, PASAJE[3] - 0.7), PI)
		if k % 3 == 1:
			_poner("tacho", Vector3(x - 2.0, Y_VEREDA, PASAJE[1] + 0.6))
		x += 9.0
		k += 1


# ---------------------------------------------------------------- Veredas: árboles, faroles, carteles

## Árboles en cazuelas, faroles curvos y mobiliario sobre una vereda. "a" y "b" son los extremos
## sobre el cordón y "adentro" apunta hacia las fachadas.
func _props_vereda(a: Vector3, b: Vector3, adentro: Vector3, paso := 9.0) -> void:
	var largo := a.distance_to(b)
	var dir := (b - a) / largo
	var rot_calle := atan2(-adentro.x, -adentro.z)   # +Z local hacia la calle
	var rot_largo := atan2(-dir.z, dir.x)            # X local a lo largo de la vereda
	var rot_adentro := atan2(adentro.x, adentro.z)   # +Z local hacia las fachadas
	var d := 6.0
	var k := _rng.randi() % 3
	while d < largo - 5.0:
		var p := a + dir * d + Vector3(0, Y_VEREDA, 0)
		var extra := _rng.randf()
		if extra < 0.06:
			# Los tres contenedores juntos (reciclables, basura y vidrio) en vez del árbol
			for u in 3:
				_poner(["contenedor_azul", "contenedor", "contenedor_amarillo"][u], p + adentro * 0.75 + dir * (u - 1) * 1.85, rot_largo)
		elif k % 3 == 1:
			_poner("farola_curva", p + adentro * 0.4, rot_calle)
		else:
			_poner("cazuela", p + adentro * 1.0, rot_largo)
			_poner(ARBOLES_VEREDA[_rng.randi() % ARBOLES_VEREDA.size()], p + adentro * 1.0, _rng.randf() * TAU,
				Vector3.ONE * _rng.randf_range(0.6, 0.72))
		var q := p + dir * 3.5
		if extra < 0.06:
			pass
		elif extra < 0.15:
			_poner("hidrante", q + adentro * 0.5, rot_calle)
		elif extra < 0.23:
			_poner("tacho", q + adentro * 0.5)
		elif extra < 0.28:
			_poner("cartelera", q + adentro * 1.3, rot_largo)
		elif extra < 0.33:
			_poner("caja_electrica", q + adentro * 2.6, rot_calle)
		elif extra < 0.38:
			_poner("cartel_estacionamiento", q + adentro * 0.3, rot_calle)
		elif extra < 0.43:
			_bici(q + adentro * 2.2, rot_largo + (PI if Vector3(0, 0, 1).rotated(Vector3.UP, rot_largo).dot(adentro) < 0.0 else 0.0))
		elif extra < 0.48:
			_poner(["maceton", "maceton_flores"][_rng.randi() % 2], q + adentro * 2.45)
		elif extra < 0.52:
			_poner("banco_listones", q + adentro * 2.4, rot_adentro + PI)
		if _rng.randf() < 0.12:
			_poner("tapa_cloaca", p + dir * 1.5 + adentro * 2.0, _rng.randf() * TAU, Vector3.ONE, false)
		d += paso
		k += 1


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
				var esq: Vector3 = q[0]
				var hacia := Vector3(signf(r.get_center().x - esq.x), 0, signf(r.get_center().y - esq.z))
				_poner("pilote", esq + Vector3(0, Y_VEREDA, 0) + Vector3(hacia.x, 0, 0) * 1.2)
				# Semáforo de vereda mirando a la esquina (los de la avenida los maneja Transito)
				_poner("semaforo_vereda", esq + Vector3(0, Y_VEREDA, 0) + Vector3(0, 0, hacia.z) * 1.6, atan2(-hacia.x, -hacia.z))
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


# ---------------------------------------------------------------- Autos estacionados y obras

## Auto del kit estacionado (con colisión) y sus cuatro ruedas. Los modelos miran a +X.
func _auto_estacionado(nombre: String, pos: Vector3, rot: float) -> void:
	autos_estacionados += 1
	_poner(nombre, pos, rot)
	var d: Dictionary = KitDatos.PIEZAS[nombre]
	var rueda := "rueda_colectivo" if float(d["radio_rueda"]) > 0.4 else "rueda_auto"
	var t := Transform3D(Basis.from_euler(Vector3(0, rot, 0)), pos)
	for p: Array in d["ruedas"]:
		Kit.colocar(self, rueda, t * Vector3(p[0], p[1], p[2]), rot)


## Autos estacionados a lo largo de un cordón, de a grupitos de 1 a 3 con varios lugares libres entre
## grupo y grupo (más o menos 1 de cada 5 lugares de 5,5 m), sin marcas en la calle. "a" y "b" son los
## extremos sobre el cordón y "afuera" apunta hacia el medio de la calle; los autos miran hacia
## "sentido" (la mano de ese lado de la calle).
func _estacionar(a: Vector3, b: Vector3, afuera: Vector3, sentido: Vector3, modelos: Array = AUTOS) -> void:
	const LUGAR := 5.5
	var largo := a.distance_to(b)
	var dir := (b - a) / largo
	var n := int(largo / LUGAR)
	var inicio := (largo - n * LUGAR) / 2.0
	var rot := atan2(-sentido.z, sentido.x)
	var k := _rng.randi_range(1, 5)
	while k < n:
		var grupo := mini(_rng.randi_range(1, 3), n - k)
		for g in grupo:
			var c := a + dir * (inicio + (k + g + 0.5) * LUGAR) + afuera * 1.25 + Vector3(0, Y_CALZADA, 0)
			if _rng.randf() < 0.1:
				autos_estacionados += 1
				_poner(["moto_roja", "moto_celeste"][_rng.randi() % 2], c, rot + _rng.randf_range(-0.2, 0.2))
			else:
				_auto_estacionado(modelos[_rng.randi() % modelos.size()], c, rot)
		k += grupo + _rng.randi_range(6, 11)


func _estacionamientos() -> void:
	# Sólo en las calles sin tránsito (Rivadavia, la Av. de Mayo y Reconquista) y de un solo lado: los
	# autos que andan van por Bolívar, la avenida y Paseo Colón (ver world/transito.gd)
	_estacionar(Vector3(-57, 0, -53), Vector3(57, 0, -53), Vector3.BACK, Vector3.LEFT)       # Rivadavia, lado norte
	_estacionar(Vector3(-196, 0, 3), Vector3(-82, 0, 3), Vector3.FORWARD, Vector3.RIGHT)     # Av. de Mayo, lado de los locales
	# Reconquista, del lado de la comisaría: ahí estacionan también los patrulleros
	_estacionar(Vector3(82, 0, -11), Vector3(196, 0, -11), Vector3.BACK, Vector3.LEFT,
		AUTOS + ["patrullero", "patrullero", "patrullero"])


## Obras en la vereda: un pozo con un caño, vallas de rayas y conos.
func _obra(c: Vector3, rot: float) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, rot, 0)), c + Vector3(0, Y_VEREDA, 0))
	_poner("pozo_obra", t.origin, rot, Vector3.ONE, false)
	for v: Array in [[Vector3(0, 0, -1.25), 0.0], [Vector3(0, 0, 1.25), 0.0], [Vector3(-1.7, 0, 0), PI / 2.0],
			[Vector3(1.9, 0, 0), PI / 2.0]]:
		_poner("valla_obra", t * (v[0] as Vector3), rot + float(v[1]))
	for p: Vector3 in [Vector3(-1.6, 0, -1.4), Vector3(1.8, 0, 1.4), Vector3(2.2, 0, -1.2)]:
		_poner("cono", t * p, _rng.randf() * TAU)


func _obras() -> void:
	_obra(Vector3(20, 0, -54.6), 0.0)          # vereda norte de Rivadavia
	_obra(Vector3(-150, 0, 4.6), 0.0)          # vereda de la Av. de Mayo, frente a las comerciales
	_obra(Vector3(76.6, 0, 70), PI / 2.0)      # Paseo Colón, frente al barrio


# ---------------------------------------------------------------- Nivel inferior: obra y mobiliario
# Fase 1 del mapa (ver DECISIONES.md, "Nivel inferior (mapa)"). Van después de los árboles, faroles y
# carteles de las veredas y no se les encima nada: cada pieza mira primero si su lugar está libre.

## Piezas que no ocupan lugar en el piso de la vereda (los árboles cuentan por su cazuela).
const SIN_HUELLA := ["arbol", "jacaranda", "pino", "tapa_cloaca", "guirnalda"]
## Cuadra con la obra: la vereda este de la manzana norte, sobre Paseo Colón (del cordón hacia adentro)
const OBRA_CUADRA := {"a": Vector3(64, 0, -115), "b": Vector3(64, 0, -53), "adentro": Vector3.LEFT,
	"desde": 14.0, "hasta": 42.0}
## Qué va en cada lugar libre de la vereda, en orden (se repite)
const CICLO_MOBILIARIO := ["banco", "farola", "bebedero", "banco", "cesto", "farola"]


## Junta las huellas en el piso de todo lo que ya hay (piezas del kit con su caja envolvente, sin los
## edificios ni lo que está en el aire) más las zonas reservadas.
func _mapear_ocupado() -> void:
	_ocupado.clear()
	for h in get_children():
		var mi := h as MeshInstance3D
		if mi == null or not mi.has_meta(&"pieza") or mi.mesh == null:
			continue
		var nombre := String(mi.get_meta(&"pieza"))
		var sin := false
		for pre: String in SIN_HUELLA:
			sin = sin or nombre.begins_with(pre)
		if sin:
			continue
		var a := mi.transform * mi.mesh.get_aabb()
		if a.position.y > 2.0 or a.size.x > 8.0 or a.size.z > 8.0:
			continue
		_ocupar(Rect2(a.position.x, a.position.z, a.size.x, a.size.z))
	for r: Rect2 in NivelInferior.reservas() + _reservado:
		_ocupar(r)


func _ocupar(r: Rect2) -> void:
	for i in range(floori(r.position.x / 4.0), floori(r.end.x / 4.0) + 1):
		for j in range(floori(r.position.y / 4.0), floori(r.end.y / 4.0) + 1):
			var k := Vector2i(i, j)
			if not _ocupado.has(k):
				_ocupado[k] = []
			(_ocupado[k] as Array).append(r)


func _libre(r: Rect2) -> bool:
	for i in range(floori(r.position.x / 4.0), floori(r.end.x / 4.0) + 1):
		for j in range(floori(r.position.y / 4.0), floori(r.end.y / 4.0) + 1):
			for o: Rect2 in _ocupado.get(Vector2i(i, j), []):
				if o.intersects(r):
					return false
	return true


## Huella de "largo" a lo largo de la vereda (dirección "dir") y "ancho" hacia adentro, centrada en "c".
static func _huella(c: Vector3, dir: Vector3, largo: float, ancho: float) -> Rect2:
	var t := Vector2(largo, ancho) if absf(dir.x) > 0.5 else Vector2(ancho, largo)
	return Rect2(c.x - t.x / 2.0, c.z - t.y / 2.0, t.x, t.y)


## Pone la pieza si su huella está libre (y la marca ocupada). Devuelve si la puso.
func _poner_libre(nombre: String, pos: Vector3, rot: float, huella: Rect2, colision := true) -> bool:
	if not _libre(huella):
		return false
	_poner(nombre, pos, rot, Vector3.ONE, colision)
	_ocupar(huella)
	return true


## Obra en una cuadra (sólo para ver: nada tiene colisión): una fila de vallas a 1,95 m del cordón con
## tramos de cinta de peligro entre conos, la cinta que vuelve hasta la pared en las dos puntas y,
## adentro, tierra removida y montoncitos de arena.
func _obra_cuadra() -> void:
	_mapear_ocupado()
	var a: Vector3 = OBRA_CUADRA["a"]
	var dir: Vector3 = ((OBRA_CUADRA["b"] as Vector3) - a).normalized()
	var adentro: Vector3 = OBRA_CUADRA["adentro"]
	var desde: float = OBRA_CUADRA["desde"]
	var hasta: float = OBRA_CUADRA["hasta"]
	const LINEA := 1.95
	const TRAMO := 1.6
	var y := Vector3(0, Y_VEREDA, 0)
	var rot_largo := atan2(-dir.z, dir.x)
	var d := desde
	var k := 0
	while d + TRAMO <= hasta + 0.01:
		var c := a + dir * (d + TRAMO / 2.0) + adentro * LINEA + y
		if k % 4 == 3:
			var p0 := a + dir * d + adentro * LINEA + y
			var p1 := p0 + dir * TRAMO
			for p: Vector3 in [p0, p1]:
				_poner_libre("cono", p, _rng.randf() * TAU, _huella(p, dir, 0.45, 0.45), false)
			_cinta(p0 + Vector3(0, 0.6, 0), p1 + Vector3(0, 0.6, 0))
		else:
			_poner_libre("valla_obra", c, rot_largo, _huella(c, dir, 1.62, 0.56), false)
		d += TRAMO
		k += 1
	# Cinta de las puntas hasta la pared (la fachada está a 3 m del cordón)
	for dd: float in [desde, d]:
		var p := a + dir * dd + adentro * LINEA + y
		_poner_libre("cono", p, _rng.randf() * TAU, _huella(p, dir, 0.45, 0.45), false)
		_cinta(p + Vector3(0, 0.6, 0), a + dir * dd + adentro * (VEREDA - 0.02) + y + Vector3(0, 0.6, 0))
	# Adentro: tierra removida y arena
	var dt := desde + 2.0
	while dt < d - 2.0:
		var largo := _rng.randf_range(1.6, 3.0)
		var c := a + dir * (dt + largo / 2.0) + adentro * (LINEA + 0.55) + y
		var tam := Vector3(largo, 0.03, 0.75) if absf(dir.x) > 0.5 else Vector3(0.75, 0.03, largo)
		Construir.caja(self, c + Vector3(0, 0.015, 0), tam, _c("tierra_obra"), false)
		if _rng.randf() < 0.6:
			Construir.esfera(self, c + Vector3(0, 0.03, 0) + dir * _rng.randf_range(-0.4, 0.4), 0.4, _c("arena"),
				Vector3(1.0, 0.45, 1.0), 8)
		dt += largo + _rng.randf_range(1.5, 3.0)
	var r := _huella(a + dir * (desde + d) / 2.0 + adentro * (LINEA + VEREDA) / 2.0, dir, d - desde + 0.6, VEREDA - LINEA + 0.6)
	_reservado.append(r)
	_ocupar(r)


## Cinta de peligro a rayas rojas y blancas de "p0" a "p1" (sin colisión).
func _cinta(p0: Vector3, p1: Vector3) -> void:
	var largo := p0.distance_to(p1)
	var dir := (p1 - p0) / largo
	var n := maxi(1, roundi(largo / 0.3))
	var rot := atan2(-dir.z, dir.x)
	for i in n:
		var m := p0 + dir * (largo * (i + 0.5) / n)
		Construir.caja(self, m, Vector3(largo / n, 0.05, 0.01), _c("valla_roja") if i % 2 == 0 else _c("blanco"), false, rot)


## Bancos, bebederos, cestos y faroles en las veredas de las calles, en los lugares que dejan libres
## los árboles, faroles curvos y demás (uno de cada dos huecos). Se posa en el asiento y el respaldo
## del banco, arriba del bebedero, en el borde del cesto y en la cabeza del farol.
func _mobiliario() -> void:
	_mapear_ocupado()
	var lineas := []   # [a, b, adentro]
	var lados := {NORTE: "NSEO", SUR: "SEO", PARQUE: "NSEO", COMERCIAL_A: "NEO", COMERCIAL_B: "SEO", ESTE: "NSEO", BARRIO: "NSEO"}
	for r: Rect2 in lados:
		var e := r.grow(VEREDA)
		var l: String = lados[r]
		# Las veredas del borde quedan del otro lado de las paredes invisibles
		if l.contains("N") and r.position.y > Z_MIN + 0.1:
			lineas.append([Vector3(e.position.x, 0, e.position.y), Vector3(e.end.x, 0, e.position.y), Vector3.BACK])
		if l.contains("S") and r.end.y < Z_MAX - 0.1:
			lineas.append([Vector3(e.position.x, 0, e.end.y), Vector3(e.end.x, 0, e.end.y), Vector3.FORWARD])
		if r.position.x > X_MIN + 0.1:
			lineas.append([Vector3(e.position.x, 0, e.position.y), Vector3(e.position.x, 0, e.end.y), Vector3.RIGHT])
		if r.end.x < X_MAX - 0.1:
			lineas.append([Vector3(e.end.x, 0, e.position.y), Vector3(e.end.x, 0, e.end.y), Vector3.LEFT])
	lineas.append([Vector3(-64, 0, -43), Vector3(-64, 0, 26), Vector3.RIGHT])
	lineas.append([Vector3(64, 0, -43), Vector3(64, 0, 26), Vector3.LEFT])
	lineas.append([Vector3(-64, 0, -43), Vector3(64, 0, -43), Vector3.BACK])
	const PASO := 9.0   # el de las piezas de las veredas que no son del borde (ver _props_vereda)
	var k := 0
	for ln: Array in lineas:
		var a: Vector3 = ln[0]
		var b: Vector3 = ln[1]
		var adentro: Vector3 = ln[2]
		var largo := a.distance_to(b)
		var dir := (b - a) / largo
		var rot_calle := atan2(-adentro.x, -adentro.z)
		var rot_adentro := atan2(adentro.x, adentro.z)
		# Entre pieza y pieza de la vereda (que van cada 9 m desde los 6 m) queda un hueco a los 6,3 m
		var d := 6.0 + 6.3
		var hueco := 0
		while d < largo - 4.0:
			if hueco % 2 == 0:
				var p := a + dir * d + Vector3(0, Y_VEREDA, 0)
				_mueble(CICLO_MOBILIARIO[k % CICLO_MOBILIARIO.size()], p, dir, adentro, rot_calle, rot_adentro)
				k += 1
			d += PASO
			hueco += 1


## Un mueble de vereda en el punto "p" sobre el cordón.
func _mueble(tipo: String, p: Vector3, dir: Vector3, adentro: Vector3, rot_calle: float, rot_adentro: float) -> void:
	match tipo:
		"banco":
			var q := p + adentro * 2.35
			if _poner_libre("banco_listones", q, rot_adentro + PI, _huella(q, dir, 2.0, 0.7)):
				_contar("banco_listones")
				var c := p + dir * 1.45 + adentro * 2.45
				if _poner_libre("cesto", c, 0.0, _huella(c, dir, 0.6, 0.6)):
					_cesto_colision(c)
		"farola":
			var q := p + adentro * 0.4
			if _poner_libre("farola", q, rot_calle, _huella(q, dir, 0.5, 0.5)):
				_contar("farola")
				# Para posarse en la cabeza del farol (el poste ya trae su colisión)
				var t := Transform3D(Basis.from_euler(Vector3(0, rot_calle, 0)), q)
				var forma := BoxShape3D.new()
				forma.size = Vector3(0.42, 0.2, 0.75)
				Kit._forma(_cuerpo_en(q), forma, t * Transform3D(Basis.IDENTITY, Vector3(0, 7.05, 1.9)))
		"bebedero":
			var q := p + adentro * 2.5
			if _poner_libre("bebedero", q, rot_adentro + PI, _huella(q, dir, 0.9, 0.9)):
				_contar("bebedero")
		"cesto":
			var q := p + adentro * 0.55
			if _poner_libre("cesto", q, rot_calle, _huella(q, dir, 0.6, 0.6)):
				_cesto_colision(q)


## El cesto del kit no trae colisión: un cilindro de su tamaño, para pararse en el borde.
func _cesto_colision(q: Vector3) -> void:
	_contar("cesto")
	var forma := CylinderShape3D.new()
	forma.radius = 0.245
	forma.height = 0.95
	Kit._forma(_cuerpo_en(q), forma, Transform3D(Basis.IDENTITY, q + Vector3(0, 0.475, 0)))


func _contar(nombre: String) -> void:
	mobiliario[nombre] = int(mobiliario.get(nombre, 0)) + 1


# ---------------------------------------------------------------- Niveles medio y alto (Fases 2 y 3)

## Balcones, toldos, cornisas, carteles salientes, faroles de la peatonal y árboles altos del parque.
func _nivel_medio() -> void:
	NivelMedio.ciudad(self)


## Terrazas y antenas en los edificios altos, postes y cables (las torres hito van en _manzanas).
func _nivel_alto() -> void:
	NivelAlto.ciudad(self)


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
	# El horizonte (las torres de más allá, en capas con paralaje) lo arma world/horizonte.gd
	# Túneles por donde entran y salen los autos (al final de Bolívar y de Paseo Colón)
	for x: float in [-69.0, 69.0]:
		for s: float in [-1.0, 1.0]:
			_tunel(Vector3(x, 0, s * 158.0), s)
	# ...y al final de la Av. de Mayo (oeste) y de Reconquista (este), por donde entra el tránsito de esas calles
	_tunel_ew(Vector3(-214.0, 0, -2.0))
	_tunel_ew(Vector3(214.0, 0, -6.0))


## Lo mismo para una calle este-oeste (la boca mira hacia el mapa: +X en el túnel del oeste, -X en el del este).
func _tunel_ew(c: Vector3) -> void:
	var hacia := 1.0 if c.x < 0.0 else -1.0
	var mi := Construir.caja(self, c + Vector3(0, 9.0, 0), Vector3(28, 18, 22), Color("c8c0b2"), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cara := c.x + hacia * 14.02
	Construir.caja(self, Vector3(cara, 2.8, c.z), Vector3(0.02, 5.6, 10.4), Color("15171b"), false)
	Construir.caja(self, Vector3(cara + hacia * 0.15, 6.0, c.z), Vector3(0.3, 0.8, 12.0), Color("9aa0a6"), false)


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


## Perro o gato con esqueleto y animaciones (world/animal.gd). "escala": el tamaño (los gatos son
## perros de 0,55).
func _animal(variante: String, pos: Vector3, rot: float, conducta: String, escala := 1.0) -> Animal:
	var a := Animal.new()
	a.variante = variante
	a.conducta = conducta
	a.position = pos
	a.rotation.y = rot
	a.scale = Vector3.ONE * escala
	add_child(a)
	return a


## Pieza que se mueve (no se fusiona): la calesita, las hamacas y el subibaja.
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
