class_name Construir
extends RefCounted
## Funciones para armar el mundo con primitivas low-poly y colores planos.
## Los materiales y mallas se cachean para que muchas piezas iguales compartan recursos.

const CAPA_MUNDO := 1

static var _materiales := {}
static var _texturas := {}


## Material plano (cacheado por color).
static func material(color: Color, rugosidad := 0.9, sin_sombra := false) -> StandardMaterial3D:
	var clave := "%s_%.2f_%s" % [color.to_html(), rugosidad, sin_sombra]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	if sin_sombra:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materiales[clave] = m
	return m


## Material con textura de baldosas generada por código.
static func material_baldosas(base: Color, junta: Color, escala_uv: Vector2, tam_px := 32) -> StandardMaterial3D:
	var clave := "bald_%s_%s_%s" % [base.to_html(), junta.to_html(), escala_uv]
	if _materiales.has(clave):
		return _materiales[clave]
	var img := Image.create(tam_px, tam_px, false, Image.FORMAT_RGB8)
	var mitad: int = tam_px >> 1
	for y in tam_px:
		for x in tam_px:
			var c := base
			# Leve variación por baldosa para que no quede tan plano
			if ((x >= mitad) != (y >= mitad)):
				c = base.darkened(0.06)
			if x % mitad == 0 or y % mitad == 0:
				c = junta
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(escala_uv.x, escala_uv.y, 1.0)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.roughness = 0.95
	_materiales[clave] = m
	return m


## Cuerpo estático con una forma de colisión.
static func colision(padre: Node, pos: Vector3, forma: Shape3D, rot := Vector3.ZERO) -> StaticBody3D:
	var cuerpo := StaticBody3D.new()
	cuerpo.collision_layer = CAPA_MUNDO
	cuerpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cuerpo.add_child(cs)
	padre.add_child(cuerpo)
	cuerpo.position = pos
	cuerpo.rotation = rot
	return cuerpo


static func _malla(padre: Node, malla: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	padre.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi


## Caja de color (con colisión opcional).
static func caja(padre: Node, pos: Vector3, tam: Vector3, color: Color, con_colision := true, rot_y := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = tam
	var mi := _malla(padre, bm, pos, material(color), Vector3(0, rot_y, 0))
	if con_colision:
		var forma := BoxShape3D.new()
		forma.size = tam
		colision(padre, pos, forma, Vector3(0, rot_y, 0))
	return mi


## Caja con material propio (por ejemplo baldosas).
static func caja_mat(padre: Node, pos: Vector3, tam: Vector3, mat: Material, con_colision := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = tam
	var mi := _malla(padre, bm, pos, mat)
	if con_colision:
		var forma := BoxShape3D.new()
		forma.size = tam
		colision(padre, pos, forma)
	return mi


static func cilindro(padre: Node, pos: Vector3, radio: float, alto: float, color: Color,
		con_colision := true, lados := 10, radio_arriba := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = radio
	cm.top_radius = radio if radio_arriba < 0.0 else radio_arriba
	cm.height = alto
	cm.radial_segments = lados
	cm.rings = 1
	var mi := _malla(padre, cm, pos, material(color))
	if con_colision:
		var forma := CylinderShape3D.new()
		forma.radius = maxf(radio, cm.top_radius)
		forma.height = alto
		colision(padre, pos, forma)
	return mi


static func esfera(padre: Node, pos: Vector3, radio: float, color: Color, escala := Vector3.ONE,
		segmentos := 10) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radio
	sm.height = radio * 2.0
	sm.radial_segments = segmentos
	sm.rings = maxi(segmentos >> 1, 4)
	var mi := _malla(padre, sm, pos, material(color))
	mi.scale = escala
	return mi


## Prisma (techo a dos aguas, pico). El triángulo mira en el eje X/Y, se estira en Z.
static func prisma(padre: Node, pos: Vector3, tam: Vector3, color: Color, rot := Vector3.ZERO,
		con_colision := false) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = tam
	var mi := _malla(padre, pm, pos, material(color), rot)
	if con_colision:
		var forma := ConvexPolygonShape3D.new()
		forma.points = pm.get_faces()
		colision(padre, pos, forma, rot)
	return mi


## Pared invisible para delimitar el mapa.
static func pared_invisible(padre: Node, pos: Vector3, tam: Vector3) -> void:
	var forma := BoxShape3D.new()
	forma.size = tam
	colision(padre, pos, forma)


## Cartel con texto 3D (nombres inventados de negocios, carteles del tutorial).
static func cartel(padre: Node, pos: Vector3, texto: String, color_texto := Color.WHITE,
		tam := 48, mirar_camara := false) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tam
	l.modulate = color_texto
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.pixel_size = 0.01
	# De una sola cara: desde atrás no se ve el texto en espejo
	l.double_sided = false
	if mirar_camara:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	padre.add_child(l)
	l.position = pos
	return l


## Letrero: texto sobre una tabla de color. "pos" es el frente de la tabla (la cara con el texto),
## que mira hacia +Z girado "rot_y". La tabla queda detrás, apoyada en la pared.
static func letrero(padre: Node, pos: Vector3, texto: String, color_texto: Color, color_tabla: Color,
		tam := 48, tam_tabla := Vector2(4, 0.6), rot_y := 0.0) -> Node3D:
	var n := Node3D.new()
	padre.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	var bm := BoxMesh.new()
	bm.size = Vector3(tam_tabla.x, tam_tabla.y, 0.1)
	_malla(n, bm, Vector3(0, 0, -0.05), material(color_tabla))
	# Marco claro arriba y abajo
	var mm := BoxMesh.new()
	mm.size = Vector3(tam_tabla.x + 0.08, 0.05, 0.12)
	for y in [-1.0, 1.0]:
		_malla(n, mm, Vector3(0, y * tam_tabla.y / 2.0, -0.05), material(color_tabla.lightened(0.45)))
	var l := cartel(n, Vector3(0, 0, 0.012), texto, color_texto, tam)
	l.outline_size = 6
	return n
