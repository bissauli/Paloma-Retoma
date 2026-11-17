class_name Vidrieras
extends RefCounted
## El interior que se ve por la vidriera de cada local de la ciudad, según lo que dice su cartel:
## "Ferretería Don Tito" tiene estantes con cajas de tornillos y pinturas, "Verdulería Los Primos"
## cajones de fruta, "Vinoteca El Tonel" botellas, "Ropa La Percha" percheros... No se entra (los
## edificios del kit son macizos): es un plano sobre el vidrio con shaders/vidriera.gdshader, que pinta
## un local de unos 3 m de fondo con profundidad de verdad.

const SHADER := preload("res://shaders/vidriera.gdshader")
const RANGO := 70.0   ## Más lejos no se distingue el interior: queda el vidrio oscuro del kit

## Cada rubro: pared, piso, mueble (estantes y mostrador), los cuatro colores de la mercadería, la
## forma (ver el shader: 0 cajas, 1 redondos, 2 ropa, 3 botellas, 4 libros, 5 lavarropas, 6 cuadros),
## cuántos estantes y el ancho de cada cosa.
const RUBROS := {
	"kiosco": ["fbe9b0", "d9d2c6", "c8423a", "e0403a", "f2c23a", "3a7fd0", "e86aa0", 0, 4, 0.18],
	"comida": ["f3e3c3", "c96f4a", "8a5a35", "6b8f3a", "b8423a", "e8c060", "3a5a8a", 3, 2, 0.16],
	"ferreteria": ["e4dccd", "9a958c", "4a4a52", "c0c4c8", "d8a03a", "c8423a", "3a6fc0", 0, 4, 0.26],
	"pintureria": ["f2f2ee", "9a958c", "6b6f75", "e0403a", "3a7fd0", "f2c23a", "4fa060", 0, 4, 0.24],
	"verduleria": ["f1e6d0", "b7b2a8", "8a6a45", "e0503a", "f0a030", "6fae3a", "f2d23a", 1, 3, 0.2],
	"heladeria": ["fde7ef", "f4ecef", "e06a9a", "f6d6e2", "b8e0c8", "f4e4a8", "8a5a40", 0, 2, 0.4],
	"lavadero": ["dff0f6", "dfe9ee", "8aa0b0", "f4f6f8", "f4f6f8", "f4f6f8", "f4f6f8", 5, 2, 0.75],
	"tintoreria": ["e8f2f6", "dfe9ee", "6b7a85", "f4f6f8", "3a5a8a", "c8d4dc", "2f3036", 2, 2, 0.22],
	"almacen": ["efe2c4", "b9b1a5", "8a5a35", "c8423a", "f2c23a", "3a7fd0", "f4f1e8", 0, 4, 0.2],
	"bar": ["c98a5a", "7a5a3e", "5b3b2a", "3a6b3a", "8a2f3a", "e0b050", "d8d8c8", 3, 3, 0.13],
	"optica": ["eef2f6", "d8dde2", "f4f4f4", "2f3036", "b8bcc2", "8a5a40", "3a6fc0", 0, 3, 0.22],
	"peluqueria": ["d9c4e4", "2f3036", "4a3a55", "bfe4f4", "c8e8f8", "bfe4f4", "d4eefa", 6, 1, 1.5],
	"zapateria": ["f1ead8", "b07a4a", "6b4a32", "6b4a32", "2f3036", "f4f1e8", "c8423a", 0, 4, 0.32],
	"regaleria": ["fde7ef", "e7d6ea", "c8a0c8", "e06a9a", "f2c23a", "6aa8e0", "8ad08a", 0, 3, 0.26],
	"disqueria": ["2f3036", "54585c", "1f2024", "e0403a", "f2c23a", "3a7fd0", "f4f1e8", 4, 3, 0.07],
	"cerrajeria": ["e4dccd", "9a958c", "4a4a52", "d8b04a", "c0c4c8", "8a8f95", "c8423a", 0, 4, 0.16],
	"merceria": ["f6ead8", "c9b79a", "8a5a35", "e06a9a", "6aa8e0", "f2c23a", "c8423a", 1, 4, 0.16],
	"fiambreria": ["f1ead8", "f4f1e8", "b8423a", "c85a4a", "f2d070", "8a3a2a", "e8b890", 1, 3, 0.22],
	"jugueteria": ["d6ecf8", "c08a5a", "4a90d0", "e0403a", "f2c23a", "3a7fd0", "4fa060", 0, 3, 0.3],
	"bazar": ["f4efe4", "b9b1a5", "8a5a35", "f4f4f4", "c8d4dc", "d8b04a", "3a6fc0", 3, 3, 0.2],
	"vinoteca": ["b8634e", "744a2c", "5b3b2a", "5a1f2a", "2f4a2a", "7a2a3a", "3a3020", 3, 4, 0.11],
	"bicicleteria": ["e6eaee", "8f969c", "3f4a45", "e0403a", "3a7fd0", "2f3036", "f2c23a", 0, 2, 0.4],
	"floreria": ["e9f2dc", "c9b79a", "6b4a32", "e06a9a", "e0403a", "f2c23a", "6fae3a", 1, 3, 0.24],
	"libreria": ["efe4c8", "8a5a35", "6b4a32", "8a2f3a", "2f5a8a", "4f7a3a", "d8b04a", 4, 4, 0.06],
	"ropa": ["f4f1f6", "d8d2c8", "8a8f95", "3a6fc0", "e06a9a", "f4f1e8", "2f3036", 2, 2, 0.24],
	"farmacia": ["f2f7f4", "eef2f0", "f4f4f4", "3f9a5a", "f4f4f4", "3a6fc0", "e0403a", 0, 4, 0.18],
	"panaderia": ["f3e3c3", "e9dcc0", "8a5a35", "d8a050", "c08040", "e8c070", "a86a30", 1, 3, 0.2],
	"golosineria": ["fde7ef", "f4ecef", "e0507a", "e0403a", "f2c23a", "3a7fd0", "8ad08a", 3, 4, 0.14],
	"minimercado": ["e8f2e4", "f2f2ee", "8a8f95", "c8423a", "f2c23a", "3a7fd0", "4fa060", 0, 4, 0.2],
	"cafe": ["f1cf9c", "8d9198", "6b3a2c", "3a6b3a", "8a2f3a", "e0b050", "f4f1e8", 3, 2, 0.14],
	"oficina": ["e6eaee", "8f969c", "8a5a35", "3a5a8a", "8a8f95", "4f7a3a", "c8423a", 4, 2, 0.09],
	"banco": ["dddbd3", "c8c4bc", "5b3b2a", "4f7fc0", "8a8f95", "d8b04a", "f4f1e8", 6, 1, 1.5],
	"galeria": ["f4f4f0", "c8c4bc", "2f3036", "e0403a", "3a7fd0", "f2c23a", "4fa060", 6, 1, 1.5],
	"viajes": ["d6ecf8", "c8c4bc", "3a6fc0", "3aa0d0", "f2c23a", "4fa060", "e06a3a", 6, 1, 1.5],
}

## Qué rubro corresponde a cada palabra del cartel (sin tildes, en minúscula). Gana la primera que aparece.
const PALABRAS := [
	["kiosco", "kiosco"], ["pizzeria", "comida"], ["empanadas", "comida"], ["parrilla", "comida"],
	["rotiseria", "comida"], ["pastas", "comida"], ["polleria", "comida"], ["ferreteria", "ferreteria"],
	["pintureria", "pintureria"], ["verduleria", "verduleria"], ["heladeria", "heladeria"],
	["lavadero", "lavadero"], ["tintoreria", "tintoreria"], ["sastreria", "tintoreria"], ["almacen", "almacen"],
	["optica", "optica"], ["peluqueria", "peluqueria"], ["barberia", "peluqueria"], ["zapateria", "zapateria"],
	["regaleria", "regaleria"], ["disqueria", "disqueria"], ["cerrajeria", "cerrajeria"], ["merceria", "merceria"],
	["fiambreria", "fiambreria"], ["jugueteria", "jugueteria"], ["bazar", "bazar"], ["vinoteca", "vinoteca"],
	["bicicleteria", "bicicleteria"], ["floreria", "floreria"], ["libreria", "libreria"], ["editorial", "libreria"],
	["ropa", "ropa"], ["farmacia", "farmacia"], ["panaderia", "panaderia"], ["golosinas", "golosineria"],
	["minimercado", "minimercado"], ["cafe", "cafe"], ["confiteria", "cafe"], ["bar ", "bar"],
	["banco", "banco"], ["cambio", "banco"], ["bolsa", "banco"], ["galeria", "galeria"], ["viajes", "viajes"],
	["seguros", "oficina"], ["inmobiliaria", "oficina"], ["estudio", "oficina"], ["escuela", "oficina"],
	["consultora", "oficina"],
]

static var _mats := {}


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
	_mats[r] = m
	return m


## Pone el interior delante del vidrio: "centro" es el centro del vidrio (un poquito por delante),
## "rot_y" hacia dónde mira la fachada, "tam" ancho y alto del vidrio y "bajo" cuánto hay del borde de
## abajo del vidrio al piso del local. Devuelve null si el cartel no dice un rubro conocido.
static func poner(padre: Node3D, centro: Vector3, rot_y: float, tam: Vector2, texto: String,
		bajo := 0.5) -> MeshInstance3D:
	var r := rubro(texto)
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
	return mi
