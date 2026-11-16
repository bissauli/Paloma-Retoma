class_name Kit
extends RefCounted
## Piezas hechas en Blender, listas para poner en el mundo: el kit de la ciudad
## (tools/blender/generar_ciudad.py -> modelos/ciudad/) y el kit del parque
## (tools/blender/generar_parque.py -> modelos/parque/).
## Los dos kits usan la misma paleta de degradés (8 x 16 celdas, ver KitDatos.PALETA y
## tools/blender/paleta.py) y por eso UN solo
## material, cuya textura se arma acá con los colores de la paleta (no hay imagen que importar ni
## comprimir): todas las piezas se pueden fusionar juntas en pocas mallas (ver
## Construir.fusionar_estaticas).
## Las colisiones de la ciudad vienen de modelos/ciudad/kit_datos.gd (las escribe Blender junto con
## los GLB); las del parque están en PARQUE_COL.

const RUTA_CIUDAD := "res://modelos/ciudad/%s/%s.glb"
const RUTA_PARQUE := "res://modelos/parque/%s/%s.glb"
const RUTA_MUEBLES := "res://modelos/muebles/%s.glb"   ## Muebles de los pasajes (generar_muebles.py)

const LOSETAS_PARQUE := ["pasto", "camino_recto", "camino_curva", "camino_t", "camino_cruce", "camino_fin",
	"plaza_cruce", "plaza_redonda", "plaza_circulo", "muro_recto", "muro_esquina", "muro_fin", "portal",
	"bosque", "plaza_fuente", "plaza_cantero", "camino_faroles", "camino_curva_arboles",
	"plaza_cruce_arbustos", "muro_arboles", "muro_esquina_arbol", "portal_faroles", "jacaranda_banco"]

## Datos de las piezas del parque (no los escribe Blender), en coordenadas de Godot de cada pieza.
## cajas: [centro (3), tamaño (3)]; cil: [centro (3), radio, alto]; esferas: [centro (3), radio].
## Sirven para la colisión y, como formas simples, para la sombra (ver colocar).
## Las losetas armadas se arman con su loseta de base y sus props sueltos, en los mismos lugares que
## en generar_parque.py: [pieza, x, y, z, rotación en grados, escala]. Así cada árbol tiene su
## distancia de dibujo (la loseta armada entera se dibujaría siempre).
const T := 0.2   ## Altura de la superficie de las losetas del parque
const SIN_SOMBRA := {"sombra": false}
const PARQUE_COL := {
	"arbol_A": {"esferas": [[0.0, 2.55, 0.0, 1.05]], "cajas": [[0.0, 0.9, 0.0, 0.3, 1.8, 0.3]], "rango": 170.0},
	"arbol_B": {"esferas": [[0.0, 3.0, 0.0, 0.85]], "cajas": [[0.0, 1.2, 0.0, 0.3, 2.4, 0.3]], "rango": 170.0},
	"arbol_C": {"esferas": [[0.85, 2.55, -0.1, 0.85]], "cajas": [[0.3, 0.9, 0.0, 0.3, 1.8, 0.3]], "rango": 170.0},
	"arbol_D": {"esferas": [[0.0, 1.5, 0.0, 0.55]], "cajas": [[0.0, 0.55, 0.0, 0.2, 1.1, 0.2]], "rango": 140.0},
	"arbol_E": {"esferas": [[-0.05, 2.6, -0.1, 1.0]], "cajas": [[0.0, 0.65, 0.0, 0.35, 1.3, 0.35]], "rango": 170.0},
	"jacaranda": {"esferas": [[0.0, 2.6, 0.0, 1.15]], "cajas": [[0.0, 0.8, 0.0, 0.35, 1.6, 0.35]], "rango": 170.0},
	"arbusto_A": {"rango": 100.0}, "arbusto_B": {"rango": 100.0}, "arbusto_C": {"rango": 110.0},
	"arbusto_flores": {"rango": 100.0},
	"banco": {"cajas": [[0.0, 0.42, 0.03, 1.6, 0.1, 0.42], [0.0, 0.73, -0.21, 1.6, 0.3, 0.06]], "rango": 110.0},
	"farol": {"cajas": [[0.0, 1.45, 0.0, 0.14, 2.9, 0.14]], "rango": 140.0},
	"farol_doble": {"cajas": [[0.0, 1.5, 0.0, 0.16, 3.0, 0.16]], "rango": 150.0},
	"fuente": {"cil": [[0.0, 0.325, 0.0, 1.6, 0.65], [0.0, 0.9, 0.0, 0.25, 1.2]]},
	"cantero": {"cil": [[0.0, 0.265, 0.0, 1.32, 0.53]]},
	"pasto": SIN_SOMBRA, "camino_recto": SIN_SOMBRA, "camino_curva": SIN_SOMBRA, "camino_t": SIN_SOMBRA,
	"camino_cruce": SIN_SOMBRA, "camino_fin": SIN_SOMBRA, "plaza_cruce": SIN_SOMBRA, "plaza_redonda": SIN_SOMBRA,
	"plaza_circulo": SIN_SOMBRA,
	"muro_recto": {"cajas": [[0.0, 0.685, -2.5, 6.0, 0.97, 0.6]]},
	"muro_esquina": {"cajas": [[-1.0, 0.685, -2.5, 4.0, 0.97, 0.6], [2.5, 0.685, 1.0, 0.6, 0.97, 4.0],
		[1.75, 0.685, -1.75, 1.1, 0.97, 1.1]]},
	"portal": {"cajas": [[-2.2, 0.685, -2.5, 1.6, 0.97, 0.6], [2.2, 0.685, -2.5, 1.6, 0.97, 0.6],
		[-1.45, 1.4, -2.5, 0.76, 2.4, 0.76], [1.45, 1.4, -2.5, 0.76, 2.4, 0.76]]},
	"bosque": {"base": "pasto", "props": [["arbol_A", -1.5, T, 1.4, 0, 1.0], ["arbol_B", 1.5, T, 1.3, 40, 1.0],
		["arbol_C", -1.6, T, -1.3, 200, 1.0], ["arbol_A", 1.6, T, -1.6, 120, 0.85], ["arbol_D", 0.1, T, -0.1, 60, 1.0],
		["arbusto_B", 0.3, T, 2.4, 10, 1.0], ["arbusto_C", -2.4, T, 0.0, 70, 1.0], ["arbusto_A", 2.5, T, -0.2, 0, 1.0]]},
	"plaza_fuente": {"base": "plaza_redonda", "props": [["fuente", 0.0, T, 0.0, 0, 1.0],
		["banco", 1.556, T, -1.556, -45, 1.0], ["banco", -1.556, T, -1.556, 45, 1.0], ["banco", -1.556, T, 1.556, 135, 1.0],
		["banco", 1.556, T, 1.556, 225, 1.0], ["arbusto_B", 2.45, T, -2.45, 30, 1.0], ["arbusto_B", -2.45, T, -2.45, 120, 1.0],
		["arbusto_B", -2.45, T, 2.45, 210, 1.0], ["arbusto_B", 2.45, T, 2.45, 300, 1.0]]},
	"plaza_cantero": {"base": "plaza_circulo", "props": [["cantero", 0.0, T, 0.0, 0, 1.0],
		["arbol_A", 0.0, T + 0.4, 0.0, 30, 0.8], ["arbusto_A", 0.6, T + 0.4, 0.55, 0, 0.8], ["arbusto_A", -0.6, T + 0.4, -0.5, 0, 0.75],
		["banco", 0.0, T, 2.0, 0, 1.0], ["banco", 0.0, T, -2.0, 180, 1.0], ["arbusto_C", 2.4, T, -2.4, 20, 1.0],
		["arbusto_flores", -2.4, T, -2.4, 80, 1.0], ["arbusto_C", -2.4, T, 2.4, 150, 1.0], ["arbusto_flores", 2.4, T, 2.4, 260, 1.0]]},
	"camino_faroles": {"base": "camino_recto", "props": [["farol", 1.45, T, -1.6, 0, 1.0], ["farol", -1.45, T, 1.6, 0, 1.0],
		["banco", -1.6, T, -0.4, 90, 1.0], ["banco", 1.6, T, 0.4, -90, 1.0], ["arbusto_C", -2.3, T, -2.3, 40, 1.0],
		["arbusto_B", 2.3, T, 2.3, 200, 1.0], ["arbusto_A", -2.4, T, 2.5, 0, 1.0], ["arbusto_flores", 2.4, T, -2.5, 0, 1.0]]},
	"camino_curva_arboles": {"base": "camino_curva", "props": [["arbol_A", -1.7, T, -1.6, 20, 1.0],
		["arbol_D", 1.4, T, -2.2, 90, 1.0], ["arbol_B", -2.0, T, 1.5, 160, 0.85], ["banco", -0.25, T, -0.25, 45, 1.0],
		["arbusto_B", 2.4, T, 2.4, 0, 1.0], ["arbusto_flores", 0.9, T, -0.9, 30, 1.0]]},
	"plaza_cruce_arbustos": {"base": "plaza_cruce", "props": [["arbusto_C", 2.35, T, -2.35, 10, 1.0],
		["arbusto_C", -2.35, T, -2.35, 100, 1.0], ["arbusto_C", -2.35, T, 2.35, 190, 1.0], ["arbusto_C", 2.35, T, 2.35, 280, 1.0]]},
	"muro_arboles": {"base": "muro_recto", "props": [["arbol_A", -1.7, T, -0.6, 30, 1.0], ["arbol_E", 1.6, T, -0.4, 0, 1.0],
		["arbusto_B", 0.0, T, -1.25, 0, 1.0], ["arbusto_A", -0.2, T, 1.4, 0, 1.0]]},
	"muro_esquina_arbol": {"base": "muro_esquina", "props": [["arbol_B", -0.6, T, 0.6, 0, 1.0],
		["arbusto_C", 0.9, T, -0.7, 45, 1.0], ["arbusto_A", -2.0, T, -1.2, 0, 1.0], ["arbusto_A", 1.3, T, 2.0, 0, 1.0]]},
	"portal_faroles": {"base": "portal", "props": [["farol_doble", -2.1, T, -1.4, 0, 1.0], ["farol_doble", 2.1, T, -1.4, 0, 1.0],
		["arbusto_B", -2.3, T, 1.0, 90, 1.0], ["arbusto_B", 2.3, T, 1.2, 270, 1.0]]},
	"jacaranda_banco": {"base": "pasto", "props": [["jacaranda", 0.4, T, -0.6, 0, 1.0], ["banco", 0.3, T, 1.5, 0, 1.0],
		["arbusto_flores", -2.0, T, 1.8, 40, 1.0], ["arbusto_B", 2.3, T, 1.9, 0, 1.0], ["arbusto_A", -2.2, T, -2.0, 0, 1.0]]},
}
const CAMBIO_LEJOS := 120.0   ## A esta distancia de la cámara los edificios pasan a su versión simple

static var _mallas := {}
static var _materiales := {}


static func es_de_ciudad(nombre: String) -> bool:
	return KitDatos.PIEZAS.has(nombre)


## ¿Es un mueble de los interiores de los pasajes (tools/blender/generar_muebles.py)?
static func es_mueble(nombre: String) -> bool:
	return MueblesDatos.PIEZAS.has(nombre)


static func ruta(nombre: String) -> String:
	if es_mueble(nombre):
		return RUTA_MUEBLES % nombre
	if es_de_ciudad(nombre):
		return RUTA_CIUDAD % [KitDatos.PIEZAS[nombre]["carpeta"], nombre]
	return RUTA_PARQUE % ["losetas" if nombre in LOSETAS_PARQUE else "piezas", nombre]


## Malla de una pieza (se lee del GLB una sola vez).
static func malla(nombre: String) -> Mesh:
	if _mallas.has(nombre):
		return _mallas[nombre]
	var m: Mesh = null
	var escena := load(ruta(nombre)) as PackedScene
	if escena:
		var raiz := escena.instantiate()
		var pendientes: Array[Node] = [raiz]
		while not pendientes.is_empty() and m == null:
			var n: Node = pendientes.pop_front()
			if n is MeshInstance3D:
				m = (n as MeshInstance3D).mesh
			pendientes.append_array(n.get_children())
		raiz.free()
	if m == null:
		push_error("Kit: no encontré la malla de '%s'" % nombre)
	_mallas[nombre] = m
	return m


## Datos de la pieza: medidas, sombra, distancia de dibujo, colisiones y carteles.
static func datos(nombre: String) -> Dictionary:
	if es_mueble(nombre):
		return SIN_SOMBRA   # Están adentro: el sol no les llega, la sombra sería un dibujo de más
	if es_de_ciudad(nombre):
		return KitDatos.PIEZAS[nombre]
	return PARQUE_COL.get(nombre, {})


## Material compartido por las piezas de los dos kits, con la luz del estilo cozy
## (shaders/estilo_cozy.gdshader).
static func material() -> ShaderMaterial:
	if _materiales.has("kit"):
		return _materiales["kit"]
	var paleta: Array = KitDatos.PALETA
	var m := Construir.material_cozy(0.85)
	# Sin mipmaps ni filtro raro: cada celda es un degradé liso, así de lejos no se mezclan colores
	# (textura_paleta tiene filtro lineal simple)
	m.set_shader_parameter("usar_paleta", true)
	m.set_shader_parameter("textura_paleta", _paleta(paleta, []))
	# Brillan sólo las lámparas, los faros y la luz verde de los semáforos (KitDatos.EMISION)
	m.set_shader_parameter("usar_textura_emision", true)
	m.set_shader_parameter("textura_emision", _paleta(paleta, KitDatos.EMISION))
	m.set_shader_parameter("emision_energia", 1.2)
	# Las piezas ya traen su degradé en la paleta: sin el degradado por altura del mundo
	m.set_shader_parameter("usar_degradado", false)
	_materiales["kit"] = m
	return m


## Material de las formas que sólo proyectan sombra (nunca se ven).
static func material_sombra() -> StandardMaterial3D:
	if not _materiales.has("sombra"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materiales["sombra"] = m
	return _materiales["sombra"]


## Textura de la paleta: KitDatos.CELDAS columnas x KitDatos.FILAS filas; cada celda tiene 64 px de alto
## con el degradé (abajo oscuro, arriba claro) y 4 px de ancho (la U siempre cae en el medio de la
## celda). La fila 0 queda abajo, como en la imagen de Blender. "solo": si no está vacío, sólo esos
## colores (el resto, negro).
static func _paleta(paleta: Array, solo: Array) -> ImageTexture:
	const CS := 64
	var celdas: int = KitDatos.CELDAS
	var margen: float = KitDatos.MARGEN
	var alto: int = CS * KitDatos.FILAS
	var img := Image.create(celdas * 4, alto, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	for i in paleta.size():
		var p: Array = paleta[i]
		if not solo.is_empty() and not solo.has(p[0]):
			continue
		@warning_ignore("integer_division")
		var cy: int = i / celdas
		var cx: int = i % celdas
		var arriba := Color(p[1] as String)
		var abajo := Color(p[2] as String)
		for r in CS:
			var t := clampf((float(r) / (CS - 1) - margen) / (1.0 - 2.0 * margen), 0.0, 1.0)
			img.fill_rect(Rect2i(cx * 4, alto - 1 - (cy * CS + r), 4, 1), abajo.lerp(arriba, t))
	return ImageTexture.create_from_image(img)


## Pone una pieza del kit: una MeshInstance3D con el material del kit (lista para fusionar) y, si
## "cuerpo" no es null, sus colisiones dentro de ese cuerpo. "padre" y "cuerpo" tienen que estar en
## el mismo espacio (la ciudad los arma a todos en el origen).
## - Las losetas armadas del parque se ponen como su loseta de base más cada prop suelto.
## - Los edificios con versión "_lejos" ponen las dos: la detallada hasta CAMBIO_LEJOS metros de la
##   cámara y la simple desde ahí. Con "solo_lejos" va sólo la simple (el horizonte).
## - La sombra no la proyecta la malla sino formas simples (las mismas cajas, esferas y cilindros de
##   la colisión, en modo "sólo sombra"): un edificio de miles de caras va al mapa de sombras como unas
##   pocas cajas. Las piezas sin formas (perros, gatos...) proyectan su propia sombra.
## Devuelve la malla principal.
static func colocar(padre: Node3D, nombre: String, pos: Vector3, rot_y := 0.0, escala := Vector3.ONE,
		cuerpo: StaticBody3D = null, solo_lejos := false) -> MeshInstance3D:
	var d := datos(nombre)
	var t := Transform3D(Basis.from_euler(Vector3(0, rot_y, 0)) * Basis.from_scale(escala), pos)
	if d.has("props") and d.has("base"):
		var base := colocar(padre, d["base"], pos, rot_y, escala, cuerpo)
		for p: Array in d["props"]:
			colocar(padre, p[0], t * Vector3(p[1], p[2], p[3]), rot_y + deg_to_rad(float(p[4])), escala * float(p[5]), cuerpo)
		return base
	var lejos := nombre + "_lejos"
	var hay_lejos := KitDatos.PIEZAS.has(lejos)
	if solo_lejos and hay_lejos:
		var solo := _instancia(padre, lejos, t)
		solo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return solo
	var mi := _instancia(padre, nombre, t)
	var sombra: bool = d.get("sombra", true)
	# Distancia de dibujo: dos escalones nomás (cada distancia distinta es otro grupo al fusionar, o
	# sea otro dibujo por celda). Los detalles chicos (rango corto) tampoco proyectan sombra.
	# En el teléfono todo un 30 % más cerca (la niebla tapa casi todo lo que deja de dibujarse).
	var rango := float(d.get("rango", 0.0))
	var factor := 0.7 if Ajustes.movil else 1.0
	var escalon := 0.0
	if rango > 0.0:
		escalon = (100.0 if rango < 140.0 else 170.0) * factor
		mi.set_meta(&"rango", escalon)
		if rango < 140.0:
			sombra = false
	if hay_lejos:
		# La versión detallada no se fusiona: cada edificio repetido comparte su malla (fusionados, cada
		# copia ocuparía memoria y tiempo de armado) y sólo se dibujan los que están cerca
		mi.remove_meta(&"rango")
		mi.set_meta(&"no_fusionar", true)
		mi.visibility_range_end = CAMBIO_LEJOS * factor
		mi.visibility_range_end_margin = 4.0
		var ml := _instancia(padre, lejos, t)
		ml.set_meta(&"rango_desde", CAMBIO_LEJOS * factor)
		ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif _tiene_formas(d):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_sombras(nombre, t, padre, escalon)
	if cuerpo:
		colisiones(nombre, t, cuerpo)
	return mi


static func _instancia(padre: Node3D, nombre: String, t: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla(nombre)
	mi.material_override = material()
	padre.add_child(mi)
	mi.transform = t
	return mi


static func _tiene_formas(d: Dictionary) -> bool:
	for k: String in ["cajas", "esferas", "cil", "convexos"]:
		if not (d.get(k, []) as Array).is_empty():
			return true
	return d.has("base")


## Formas simples que sólo proyectan sombra: las cajas, esferas y cilindros de la colisión (los
## convexos van como su caja envolvente). Se fusionan como cualquier pieza.
static func _sombras(nombre: String, t: Transform3D, padre: Node3D, rango: float) -> void:
	var d := datos(nombre)
	if d.has("base"):
		_sombras(d["base"], t, padre, rango)
	for c: Array in d.get("cajas", []):
		var b := Basis.IDENTITY
		if c.size() >= 15:
			b = Basis(Vector3(c[6], c[7], c[8]), Vector3(c[9], c[10], c[11]), Vector3(c[12], c[13], c[14]))
		var tam := Vector3(c[3], c[4], c[5])
		if maxf(tam.x, maxf(tam.y, tam.z)) < 0.3:
			continue
		var caja := BoxMesh.new()
		caja.size = tam
		_sombra(padre, caja, t * Transform3D(b, Vector3(c[0], c[1], c[2])), rango)
	for e: Array in d.get("esferas", []):
		var esf := SphereMesh.new()
		esf.radial_segments = 8
		esf.rings = 4
		esf.radius = float(e[3])
		esf.height = float(e[3]) * 2.0
		_sombra(padre, esf, t * Transform3D(Basis.IDENTITY, Vector3(e[0], e[1], e[2])), rango)
	for c: Array in d.get("cil", []):
		var cil := CylinderMesh.new()
		cil.radial_segments = 8
		cil.rings = 1
		cil.top_radius = float(c[3])
		cil.bottom_radius = float(c[3])
		cil.height = float(c[4])
		_sombra(padre, cil, t * Transform3D(Basis.IDENTITY, Vector3(c[0], c[1], c[2])), rango)
	for pts: Array in d.get("convexos", []):
		var env := AABB(Vector3(pts[0], pts[1], pts[2]), Vector3.ZERO)
		for k in range(3, pts.size(), 3):
			env = env.expand(Vector3(pts[k], pts[k + 1], pts[k + 2]))
		var caja := BoxMesh.new()
		caja.size = env.size
		_sombra(padre, caja, t * Transform3D(Basis.IDENTITY, env.get_center()), rango)


static func _sombra(padre: Node3D, forma: PrimitiveMesh, t: Transform3D, rango: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = forma
	mi.material_override = material_sombra()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if rango > 0.0:
		mi.set_meta(&"rango", rango)
	padre.add_child(mi)
	mi.transform = t


## Suma a "cuerpo" las formas de colisión de la pieza, transformadas por "t".
static func colisiones(nombre: String, t: Transform3D, cuerpo: StaticBody3D) -> void:
	var d := datos(nombre)
	if d.has("base"):
		colisiones(d["base"], t, cuerpo)
	for c: Array in d.get("cajas", []):
		var b := Basis.IDENTITY
		if c.size() >= 15:
			b = Basis(Vector3(c[6], c[7], c[8]), Vector3(c[9], c[10], c[11]), Vector3(c[12], c[13], c[14]))
		var tc := t * Transform3D(b, Vector3(c[0], c[1], c[2]))
		var forma := BoxShape3D.new()
		forma.size = Vector3(c[3], c[4], c[5]) * tc.basis.get_scale()
		_forma(cuerpo, forma, Transform3D(tc.basis.orthonormalized(), tc.origin))
	var esc := t.basis.get_scale()
	var esc_max := maxf(esc.x, maxf(esc.y, esc.z))
	for e: Array in d.get("esferas", []):
		var forma := SphereShape3D.new()
		forma.radius = float(e[3]) * esc_max
		_forma(cuerpo, forma, Transform3D(Basis.IDENTITY, t * Vector3(e[0], e[1], e[2])))
	for c: Array in d.get("cil", []):
		var forma := CylinderShape3D.new()
		forma.radius = float(c[3]) * maxf(esc.x, esc.z)
		forma.height = float(c[4]) * esc.y
		_forma(cuerpo, forma, Transform3D(t.basis.orthonormalized(), t * Vector3(c[0], c[1], c[2])))
	for pts: Array in d.get("convexos", []):
		var puntos := PackedVector3Array()
		for k in range(0, pts.size(), 3):
			puntos.append(t * Vector3(pts[k], pts[k + 1], pts[k + 2]))
		var forma := ConvexPolygonShape3D.new()
		forma.points = puntos
		_forma(cuerpo, forma, Transform3D.IDENTITY)


static func _forma(cuerpo: StaticBody3D, forma: Shape3D, t: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.transform = t
	cuerpo.add_child(cs)


## Los lugares para carteles de la pieza ("local", "calle", "kiosco", "cucha", "madera"), ya en el
## espacio del padre: [posición, ángulo en Y para que un Label3D mire hacia afuera, ancho, alto, tipo].
static func carteles(nombre: String, t: Transform3D) -> Array:
	var out := []
	for c: Array in datos(nombre).get("carteles", []):
		var p := t * Vector3(c[0], c[1], c[2])
		var n := (t.basis * Vector3(c[3], c[4], c[5])).normalized()
		var esc := t.basis.get_scale()
		out.append([p, atan2(n.x, n.z), float(c[6]) * esc.x, float(c[7]), String(c[8])])
	return out
