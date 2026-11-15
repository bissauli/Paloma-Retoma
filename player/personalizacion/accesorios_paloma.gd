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
		"espalda":
			match opcion:
				1: _mochila(raiz)
				2: _capa(raiz)
				3: _jetpack(raiz)
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


static func _anteojos(r: Node3D) -> void:
	for lado in [-1.0, 1.0]:
		_caja(r, Vector3(0.07, 0.05, 0.012), Vector3(0.055 * lado, 0.435, 0.206), NEGRO)
		_caja(r, Vector3(0.05, 0.034, 0.004), Vector3(0.055 * lado, 0.435, 0.214), CELESTE)
	_caja(r, Vector3(0.04, 0.01, 0.012), Vector3(0.0, 0.44, 0.206), NEGRO)


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


static func _pieza(r: Node3D, malla: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.8)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(mi)
	return mi
