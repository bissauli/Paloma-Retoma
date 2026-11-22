class_name Vidrieras
extends RefCounted
## El interior que se ve por la vidriera de cada local de la ciudad, según lo que dice su cartel:
## "Ferretería Don Tito" tiene estantes con cajas de tornillos y pinturas, "Verdulería Los Primos"
## cajones de fruta, "Vinoteca El Tonel" botellas, "Ropa La Percha" percheros... No se entra (los
## edificios del kit son macizos): es un plano sobre el vidrio con shaders/vidriera.gdshader, que pinta
## un local de unos 3 m de fondo con profundidad de verdad.

const SHADER := preload("res://shaders/vidriera.gdshader")
const RANGO := 70.0   ## Más lejos no se distingue el interior: queda el vidrio oscuro del kit
## El colchón de choque de cada vidriera (sólo para las palomas, ver Construir.CAPA_PALOMAS): sale
## SALIENTE metros por delante del plano y llega FONDO metros hacia adentro. La esfera de la paloma
## mide 22 cm, pero el modelo (pico, cola, alas) llega a 40 cm del centro, y la pared del kit está
## 10 cm detrás del plano: pegada al vidrio, media paloma quedaba "adentro" del local pintado. Y en
## algunas fachadas del kit había huecos detrás del vidrio por donde se metía entera.
const SALIENTE := 0.2
const FONDO := 0.5

## Cada rubro: pared, piso, mueble (estantes y mostrador), los cuatro colores de la mercadería, la
## forma de las paredes (ver el shader: 0 cajas, 1 redondos, 2 ropa, 3 botellas, 4 libros, 5 lavarropas,
## 6 cuadros, 7 espejos de peluquería, 8 boiserie de banco, 9 pizarrón, 10 anteojos, 11 local de comida, 12 bicis
## colgadas, 13 heladería),
## cuántos estantes, el ancho de cada cosa y, si hace falta, los muebles del medio (0 mostrador, 2 banco
## para sentarse, 3 sillones de barbero, 4 cajas de banco, 5 escritorios, 6 parrilla) y el damero del piso (0 a 1).
const RUBROS := {
	"kiosco": ["fbe9b0", "d9d2c6", "c8423a", "e0403a", "f2c23a", "3a7fd0", "e86aa0", 0, 4, 0.18],
	# Locales de comida (forma 11): el menú y el mostrador vidriado con bandejas; cada uno con su comida
	"parrilla": ["e8d2b0", "8a5a35", "5b3b2a", "8a3a2a", "a8462e", "9a3a30", "4a2420", 11, 3, 0.24, 6, 0.0],
	"empanadas": ["f3e3c3", "c96f4a", "8a5a35", "d8a050", "c98a3a", "e0b060", "b8783a", 11, 3, 0.2, 0, 0.0],
	"pizzeria": ["f4e6cc", "b8423a", "6b3a2c", "e07a3a", "d8a040", "c84a2a", "f0c060", 11, 3, 0.26, 0, 0.0],
	"pastas": ["f6ead0", "c9b79a", "8a5a35", "f2d070", "e8c060", "f4e0a0", "c84a2a", 11, 3, 0.18, 0, 0.0],
	"polleria": ["f4ecd8", "d9d2c6", "8a5a35", "c8783a", "b0602a", "d89048", "e0a058", 11, 3, 0.26, 0, 0.0],
	"rotiseria": ["f1e6d0", "b7b2a8", "6b4a32", "c8783a", "4f8a3a", "e0b060", "b8423a", 11, 3, 0.22, 0, 0.0],
	"ferreteria": ["e4dccd", "9a958c", "4a4a52", "c0c4c8", "d8a03a", "c8423a", "3a6fc0", 0, 4, 0.26],
	"pintureria": ["f2f2ee", "9a958c", "6b6f75", "e0403a", "3a7fd0", "f2c23a", "4fa060", 0, 4, 0.24],
	"verduleria": ["f1e6d0", "b7b2a8", "8a6a45", "e0503a", "f0a030", "6fae3a", "f2d23a", 1, 3, 0.2],
	"heladeria": ["fde7ef", "f4ecef", "e06a9a", "f6a0c0", "9ad8b0", "f4e090", "8a5a40", 13, 2, 0.4, 1, 0.0],   # Vitrina con baldes de helado
	"lavadero": ["dff0f6", "dfe9ee", "8aa0b0", "f4f6f8", "f4f6f8", "f4f6f8", "f4f6f8", 5, 2, 0.75],
	"tintoreria": ["e8f2f6", "dfe9ee", "6b7a85", "f4f6f8", "3a5a8a", "c8d4dc", "2f3036", 2, 2, 0.22],
	"almacen": ["efe2c4", "b9b1a5", "8a5a35", "c8423a", "f2c23a", "3a7fd0", "f4f1e8", 0, 4, 0.2],
	"bar": ["c98a5a", "7a5a3e", "5b3b2a", "3a6b3a", "8a2f3a", "e0b050", "d8d8c8", 3, 3, 0.13],
	"optica": ["f4f6f8", "d8dde2", "f4f4f4", "2f3036", "b8423a", "8a5a40", "3a6fc0", 10, 4, 0.32],
	"peluqueria": ["f4f1f6", "2a2a2e", "1f2024", "b8423a", "3a6fc0", "f2c23a", "4fa060", 7, 3, 0.12, 3, 0.9],
	"zapateria": ["f1ead8", "b07a4a", "6b4a32", "6b4a32", "2f3036", "f4f1e8", "c8423a", 0, 4, 0.32],
	"regaleria": ["fde7ef", "e7d6ea", "c8a0c8", "e06a9a", "f2c23a", "6aa8e0", "8ad08a", 0, 3, 0.26],
	"disqueria": ["2f3036", "54585c", "1f2024", "e0403a", "f2c23a", "3a7fd0", "f4f1e8", 4, 3, 0.07],
	"cerrajeria": ["e4dccd", "9a958c", "4a4a52", "d8b04a", "c0c4c8", "8a8f95", "c8423a", 0, 4, 0.16],
	"merceria": ["f6ead8", "c9b79a", "8a5a35", "e06a9a", "6aa8e0", "f2c23a", "c8423a", 1, 4, 0.16],
	"fiambreria": ["f1ead8", "f4f1e8", "b8423a", "c85a4a", "f2d070", "8a3a2a", "e8b890", 1, 3, 0.22],
	"jugueteria": ["d6ecf8", "c08a5a", "4a90d0", "e0403a", "f2c23a", "3a7fd0", "4fa060", 0, 3, 0.3],
	"bazar": ["f4efe4", "b9b1a5", "8a5a35", "f4f4f4", "c8d4dc", "d8b04a", "3a6fc0", 3, 3, 0.2],
	"vinoteca": ["b8634e", "744a2c", "5b3b2a", "5a1f2a", "2f4a2a", "7a2a3a", "3a3020", 3, 4, 0.11],
	"bicicleteria": ["e6eaee", "8f969c", "3f4a45", "e0403a", "3a7fd0", "2f3036", "f2c23a", 12, 2, 0.4, 1, 0.0],   # Bicis colgadas
	"floreria": ["e9f2dc", "c9b79a", "6b4a32", "e06a9a", "e0403a", "f2c23a", "6fae3a", 1, 3, 0.24],
	"libreria": ["efe4c8", "8a5a35", "6b4a32", "8a2f3a", "2f5a8a", "4f7a3a", "d8b04a", 4, 4, 0.06],
	"ropa": ["f4f1f6", "d8d2c8", "8a8f95", "3a6fc0", "e06a9a", "f4f1e8", "2f3036", 2, 2, 0.24],
	"farmacia": ["f2f7f4", "eef2f0", "f4f4f4", "3f9a5a", "f4f4f4", "3a6fc0", "e0403a", 0, 4, 0.18],
	"panaderia": ["f3e3c3", "e9dcc0", "8a5a35", "d8a050", "c08040", "e8c070", "a86a30", 1, 3, 0.2],
	"golosineria": ["fde7ef", "f4ecef", "e0507a", "e0403a", "f2c23a", "3a7fd0", "8ad08a", 3, 4, 0.14],
	"minimercado": ["e8f2e4", "f2f2ee", "8a8f95", "c8423a", "f2c23a", "3a7fd0", "4fa060", 0, 4, 0.2],
	"cafe": ["f1cf9c", "8d9198", "6b3a2c", "3a6b3a", "8a2f3a", "e0b050", "f4f1e8", 3, 2, 0.14],
	"oficina": ["e6eaee", "8f969c", "8a5a35", "3a5a8a", "8a8f95", "4f7a3a", "c8423a", 4, 2, 0.09, 5, 0.0],
	"banco": ["e8e0cc", "c8c4bc", "6b4a32", "1f4f8a", "d8b04a", "3a6fc0", "c8423a", 8, 1, 1.5, 4, 0.0],
	"galeria": ["f4f4f0", "c8c4bc", "2f3036", "e0403a", "3a7fd0", "f2c23a", "4fa060", 6, 1, 1.5, 2, 0.0],
	"viajes": ["d6ecf8", "c8c4bc", "3a6fc0", "3aa0d0", "f2c23a", "4fa060", "e06a3a", 6, 1, 1.5, 5, 0.0],
	"escuela": ["f1ead8", "b07a4a", "8a5a35", "e0403a", "3a7fd0", "f2c23a", "4fa060", 9, 1, 1.5, 5, 0.0],
	"inmobiliaria": ["eef2f6", "c8c4bc", "5b3b2a", "6fae3a", "3a7fd0", "e8c060", "c8423a", 6, 1, 1.5, 5, 0.0],
}

## Qué rubro corresponde a cada palabra del cartel (sin tildes, en minúscula). Gana la primera que aparece.
const PALABRAS := [
	["kiosco", "kiosco"], ["pizzeria", "pizzeria"], ["empanadas", "empanadas"], ["parrilla", "parrilla"],
	["rotiseria", "rotiseria"], ["pastas", "pastas"], ["polleria", "polleria"], ["ferreteria", "ferreteria"],
	["pintureria", "pintureria"], ["verduleria", "verduleria"], ["heladeria", "heladeria"],
	["lavadero", "lavadero"], ["tintoreria", "tintoreria"], ["sastreria", "tintoreria"], ["almacen", "almacen"],
	["optica", "optica"], ["peluqueria", "peluqueria"], ["barberia", "peluqueria"], ["zapateria", "zapateria"],
	["regaleria", "regaleria"], ["disqueria", "disqueria"], ["cerrajeria", "cerrajeria"], ["merceria", "merceria"],
	["fiambreria", "fiambreria"], ["jugueteria", "jugueteria"], ["bazar", "bazar"], ["vinoteca", "vinoteca"],
	["bicicleteria", "bicicleteria"], ["floreria", "floreria"], ["libreria", "libreria"], ["editorial", "libreria"],
	["ropa", "ropa"], ["farmacia", "farmacia"], ["panaderia", "panaderia"], ["golosinas", "golosineria"],
	["minimercado", "minimercado"], ["cafe", "cafe"], ["confiteria", "cafe"], ["bar ", "bar"],
	["banco", "banco"], ["cambio", "banco"], ["bolsa", "banco"], ["galeria", "galeria"], ["viajes", "viajes"],
	["seguros", "oficina"], ["inmobiliaria", "inmobiliaria"], ["estudio", "oficina"], ["escuela", "escuela"],
	["consultora", "oficina"],
]

static var _mats := {}
## Cada cartel que pidió vidriera y qué rubro le tocó ("" si ninguno): [texto, rubro]. Para revisar.
static var registro: Array = []


## El rubro de un cartel ("" si no se reconoce).
static func rubro(texto: String) -> String:
	var t := texto.to_lower() + " "
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"]]:
		t = t.replace(par[0], par[1])
	for p: Array in PALABRAS:
		if t.contains(p[0]):
			return p[1]
	return ""


static func material(r: String) -> ShaderMaterial:
	if _mats.has(r):
		return _mats[r]
	var d: Array = RUBROS[r]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	for i in 7:
		m.set_shader_parameter(["pared", "piso", "mueble", "c1", "c2", "c3", "c4"][i], Color(d[i]))
	m.set_shader_parameter("forma", d[7])
	m.set_shader_parameter("filas", float(d[8]))
	m.set_shader_parameter("celda", d[9])
	m.set_shader_parameter("muebles", d[10] if d.size() > 10 else 0)
	m.set_shader_parameter("damero", d[11] if d.size() > 11 else 0.0)
	_mats[r] = m
	return m


## Pone el interior delante del vidrio: "centro" es el centro del vidrio (un poquito por delante),
## "rot_y" hacia dónde mira la fachada, "tam" ancho y alto del vidrio y "bajo" cuánto hay del borde de
## abajo del vidrio al piso del local. Devuelve null si el cartel no dice un rubro conocido.
static func poner(padre: Node3D, centro: Vector3, rot_y: float, tam: Vector2, texto: String,
		bajo := 0.5) -> MeshInstance3D:
	var r := rubro(texto)
	registro.append([texto, r])
	if r == "" or tam.x < 1.0:
		return null
	var q := QuadMesh.new()
	q.size = tam
	var mi := MeshInstance3D.new()
	mi.name = "Vidriera_" + r
	mi.mesh = q
	var m := material(r)
	if not is_equal_approx(bajo, 0.5):
		m = m.duplicate()
		m.set_shader_parameter("bajo", bajo)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = RANGO * (0.7 if Ajustes.movil else 1.0)
	mi.set_meta(&"no_fusionar", true)
	padre.add_child(mi)
	mi.position = centro
	mi.rotation.y = rot_y
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "Choque"
	cuerpo.collision_layer = Construir.CAPA_PALOMAS
	cuerpo.collision_mask = 0
	# De costado es un trapecio: arriba baja en pendiente hacia afuera (más de 45°), así no queda un
	# estante invisible delante del vidrio donde la paloma se pueda parar
	var hx := tam.x / 2.0 + 0.05
	var y0 := -tam.y / 2.0 - 0.05
	var y1 := tam.y / 2.0 + 0.05
	var puntos := PackedVector3Array()
	for x: float in [-hx, hx]:
		for p: Vector2 in [Vector2(-FONDO, y0), Vector2(-FONDO, y1), Vector2(0.0, y1), Vector2(SALIENTE, y1 - 0.3),
				Vector2(SALIENTE, y0)]:
			puntos.append(Vector3(x, p.y, p.x))
	var forma := ConvexPolygonShape3D.new()
	forma.points = puntos
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	mi.add_child(cuerpo)
	return mi
