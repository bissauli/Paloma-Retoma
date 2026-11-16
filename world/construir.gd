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
	elif not sin_sombra:
		# Color liso y opaco: las piezas con este material se pueden fusionar (ver fusionar_estaticas)
		m.set_meta(&"color_plano", color)
	_materiales[clave] = m
	return m


## Material que toma el color de los vértices: lo usan las mallas fusionadas, donde cada pieza
## guarda su color en sus vértices. Se ve igual que material(color, rugosidad).
static func material_vertices(rugosidad := 0.9) -> StandardMaterial3D:
	var clave := "vtx_%.2f" % rugosidad
	if _materiales.has(clave):
		return _materiales[clave]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rugosidad
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
	if not proyecta_sombra(malla):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mi)
	mi.position = pos
	mi.rotation = rot
	return mi


## ¿Vale la pena dibujar esta malla en el mapa de sombras? No si es una lámina casi plana
## (líneas de la calle, felpudos) ni si es muy chica: no se nota su sombra y cada
## pieza cuesta un dibujo extra por cada corte de la sombra del sol. El piso grande tampoco:
## sólo recibe sombras.
static func proyecta_sombra(malla: Mesh) -> bool:
	var tam := malla.get_aabb().size
	var mayor := maxf(tam.x, maxf(tam.y, tam.z))
	if tam.y < 0.1 and maxf(tam.x, tam.z) > 1.0:
		return false  # lámina horizontal
	if mayor < 0.35:
		return false  # detalle diminuto
	if tam.y < 1.5 and tam.x > 60.0 and tam.z > 60.0:
		return false  # piso
	return true


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


# ---------------------------------------------------------------- Fusión de mallas
# Cada MeshInstance3D es un dibujo aparte para la placa de video (y uno más por cada corte de la
# sombra del sol). El mundo tiene miles de piezas chicas, así que al terminar de armarlo se juntan
# en pocas mallas grandes: es lo que más rinde, sobre todo en el teléfono (WebGL).

static var _unitarias := {}   ## Forma de primitiva -> arrays de su versión "unitaria" (sin escalar)


## Junta en pocas mallas todas las MeshInstance3D estáticas que cuelgan de "raiz".
## No entra en los nodos con script (autos, comida, el nido...: se mueven o cambian) ni en los que
## tienen la meta "no_fusionar". Las piezas de color liso se juntan por rugosidad (con el color en
## los vértices); las demás, por material. Además se separan por celdas de "celda" metros (así la
## cámara sigue descartando lo que no ve) y por si proyectan sombra o no.
## Las colisiones no se tocan. Devuelve cuántas piezas se fusionaron.
static func fusionar_estaticas(raiz: Node3D, celda := 24.0) -> int:
	var grupos := {}
	var fusionadas: Array[MeshInstance3D] = []
	var inv := raiz.global_transform.affine_inverse()
	var pendientes: Array[Node] = [raiz]
	while not pendientes.is_empty():
		var n: Node = pendientes.pop_back()
		for h in n.get_children():
			if h.get_script() != null or h.has_meta(&"no_fusionar"):
				continue
			var mi := h as MeshInstance3D
			if mi and mi.get_child_count() == 0:
				var mat := mi.material_override
				if mi.mesh == null or mat == null or not mi.is_visible_in_tree():
					continue
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue   # Lo transparente se ordena por distancia: queda suelto
				var con_color := mat.has_meta(&"color_plano")
				var t := inv * mi.global_transform
				var centro := t * mi.mesh.get_aabb().get_center()
				var clave_mat := ("v%.2f" % (mat as BaseMaterial3D).roughness) if con_color else ("m%d" % mat.get_instance_id())
				var clave := "%d_%d_%s_%d" % [floori(centro.x / celda), floori(centro.z / celda), clave_mat, mi.cast_shadow]
				if not grupos.has(clave):
					grupos[clave] = {"mat": material_vertices((mat as BaseMaterial3D).roughness) if con_color else mat,
						"color": con_color, "sombra": mi.cast_shadow, "piezas": []}
				var color: Color = mat.get_meta(&"color_plano") if con_color else Color.WHITE
				(grupos[clave]["piezas"] as Array).append([mi.mesh, t, color])
				fusionadas.append(mi)
				continue
			pendientes.append(h)
	var i := 0
	for clave: String in grupos:
		var g: Dictionary = grupos[clave]
		var mi := MeshInstance3D.new()
		mi.name = "Fusion%d" % i
		mi.mesh = combinar(g["piezas"], g["color"], not g["color"])
		mi.material_override = g["mat"]
		mi.cast_shadow = g["sombra"]
		raiz.add_child(mi)
		i += 1
	for mi in fusionadas:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return fusionadas.size()


## Junta piezas [malla, Transform3D, Color] en una sola ArrayMesh. Con "con_color" cada pieza
## guarda su color en los vértices (para usar con material_vertices()). No le pide nada a la
## placa de video: las primitivas se arman escalando una versión unitaria cacheada por forma.
static func combinar(piezas: Array, con_color := true, con_uv := false) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for p: Array in piezas:
		var u := _unitaria(p[0] as Mesh)
		var arr: Array = u[0]
		var t: Transform3D = (p[1] as Transform3D) * Transform3D(Basis.from_scale(u[1]), Vector3.ZERO)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(t * v)
		# Normales con la inversa transpuesta (sirve aunque la escala no sea pareja)
		norms.append_array(Transform3D(t.basis.inverse().transposed(), Vector3.ZERO) * (arr[Mesh.ARRAY_NORMAL] as PackedVector3Array))
		if con_color:
			var c := PackedColorArray()
			c.resize(v.size())
			c.fill(p[2])
			cols.append_array(c)
		if con_uv:
			var uv = arr[Mesh.ARRAY_TEX_UV]
			if uv is PackedVector2Array and (uv as PackedVector2Array).size() == v.size():
				uvs.append_array(uv)
			else:
				var vacio := PackedVector2Array()
				vacio.resize(v.size())
				uvs.append_array(vacio)
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var n0 := idx.size()
		idx.resize(n0 + ii.size())
		if t.basis.determinant() < 0.0:
			# Espejada: se invierte el orden de cada triángulo para que no quede del revés
			for k in range(0, ii.size(), 3):
				idx[n0 + k] = ii[k] + base
				idx[n0 + k + 1] = ii[k + 2] + base
				idx[n0 + k + 2] = ii[k + 1] + base
		else:
			for k in ii.size():
				idx[n0 + k] = ii[k] + base
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_INDEX] = idx
	if con_color:
		a[Mesh.ARRAY_COLOR] = cols
	if con_uv:
		a[Mesh.ARRAY_TEX_UV] = uvs
	var am := ArrayMesh.new()
	if not verts.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return am


## [arrays de la forma unitaria, escala para llevarla al tamaño de "m"].
## Caja, esfera, cilindro y prisma escalados dan exactamente la misma malla que con su tamaño real.
## Cualquier otra malla (cápsulas, por ejemplo) se lee tal cual una sola vez y se cachea.
static func _unitaria(m: Mesh) -> Array:
	var firma := ""
	var esc := Vector3.ONE
	if m is BoxMesh:
		var b := m as BoxMesh
		if b.subdivide_width == 0 and b.subdivide_height == 0 and b.subdivide_depth == 0:
			firma = "caja"
			esc = b.size
	elif m is SphereMesh:
		var s := m as SphereMesh
		if not s.is_hemisphere:
			firma = "esf_%d_%d" % [s.radial_segments, s.rings]
			esc = Vector3(s.radius, s.height / 2.0, s.radius)
	elif m is CylinderMesh:
		var c := m as CylinderMesh
		if c.bottom_radius > 0.0:
			firma = "cil_%d_%d_%.4f_%s_%s" % [c.radial_segments, c.rings, c.top_radius / c.bottom_radius, c.cap_top, c.cap_bottom]
			esc = Vector3(c.bottom_radius, c.height, c.bottom_radius)
	elif m is PrismMesh:
		var pr := m as PrismMesh
		if pr.subdivide_width == 0 and pr.subdivide_height == 0 and pr.subdivide_depth == 0:
			firma = "prisma_%.4f" % pr.left_to_right
			esc = pr.size
	if firma == "":
		firma = "id_%d" % m.get_instance_id()
		esc = Vector3.ONE
	if not _unitarias.has(firma):
		_unitarias[firma] = _molde(firma, m).surface_get_arrays(0)
	return [_unitarias[firma], esc]


static func _molde(firma: String, m: Mesh) -> Mesh:
	if firma == "caja":
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		return b
	if firma.begins_with("esf_"):
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = (m as SphereMesh).radial_segments
		s.rings = (m as SphereMesh).rings
		return s
	if firma.begins_with("cil_"):
		var o := m as CylinderMesh
		var c := CylinderMesh.new()
		c.bottom_radius = 1.0
		c.top_radius = o.top_radius / o.bottom_radius
		c.height = 1.0
		c.radial_segments = o.radial_segments
		c.rings = o.rings
		c.cap_top = o.cap_top
		c.cap_bottom = o.cap_bottom
		return c
	if firma.begins_with("prisma_"):
		var p := PrismMesh.new()
		p.size = Vector3.ONE
		p.left_to_right = (m as PrismMesh).left_to_right
		return p
	return m
