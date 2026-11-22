class_name Construir
extends RefCounted
## Funciones para armar el mundo con primitivas low-poly y colores planos.
## Los materiales y mallas se cachean para que muchas piezas iguales compartan recursos.

const CAPA_MUNDO := 1

static var _materiales := {}
static var _texturas := {}


const SHADER_COZY := preload("res://shaders/estilo_cozy.gdshader")


## Material plano (cacheado por color). Opaco y con sombra usa el shader del estilo cozy
## (shaders/estilo_cozy.gdshader); transparente o sin sombra, un StandardMaterial3D.
static func material(color: Color, rugosidad := 0.9, sin_sombra := false) -> Material:
	var clave := "%s_%.2f_%s" % [color.to_html(), rugosidad, sin_sombra]
	if _materiales.has(clave):
		return _materiales[clave]
	var m: Material
	if sin_sombra or color.a < 1.0:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = color
		sm.roughness = rugosidad
		if sin_sombra:
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if color.a < 1.0:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m = sm
	else:
		m = material_cozy(rugosidad)
		m.set_shader_parameter("color_base", color)
		# Color liso y opaco: las piezas con este material se pueden fusionar (ver fusionar_estaticas)
		m.set_meta(&"color_plano", color)
	_materiales[clave] = m
	return m


## ShaderMaterial nuevo (sin cachear) con el estilo cozy y los ajustes del mundo.
static func material_cozy(rugosidad := 0.9) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER_COZY
	m.set_shader_parameter("roughness", rugosidad)
	# Rim más suave que el default: en paredes grandes vistas de costado se notaba demasiado
	m.set_shader_parameter("rim_intensidad", 0.15)
	# Degradado leve por altura en el mundo: abajo un poco más frío, como en sombra de la calle
	m.set_shader_parameter("usar_degradado", true)
	m.set_shader_parameter("usar_altura_mundial", true)
	m.set_shader_parameter("degradado_altura_min", 0.0)
	m.set_shader_parameter("degradado_altura_max", 10.0)
	m.set_shader_parameter("degradado_fuerza", 0.3)
	m.set_meta(&"rugosidad", rugosidad)
	return m


## Rugosidad de un material del mundo (cozy o StandardMaterial3D).
static func rugosidad_de(m: Material) -> float:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).roughness
	return float(m.get_meta(&"rugosidad", 0.9))


## Material que toma el color de los vértices: lo usan las mallas fusionadas, donde cada pieza
## guarda su color en sus vértices. Se ve igual que material(color, rugosidad).
static func material_vertices(rugosidad := 0.9) -> ShaderMaterial:
	var clave := "vtx_%.2f" % rugosidad
	if _materiales.has(clave):
		return _materiales[clave]
	var m := material_cozy(rugosidad)
	m.set_shader_parameter("usar_color_vertices", true)
	_materiales[clave] = m
	return m


## Material con textura de baldosas generada por código, proyectada con la posición en el mundo.
static func material_baldosas(base: Color, junta: Color, escala_uv: Vector2, tam_px := 128) -> ShaderMaterial:
	var clave := "bald_%s_%s_%s" % [base.to_html(), junta.to_html(), escala_uv]
	if _materiales.has(clave):
		return _materiales[clave]
	var img := Image.create(tam_px, tam_px, false, Image.FORMAT_RGB8)
	var mitad: int = tam_px >> 1
	# El shader filtra suave (no pixelado): con más resolución la junta queda nítida de cerca
	var junta_px := maxi(tam_px >> 5, 1)
	for y in tam_px:
		for x in tam_px:
			var c := base
			# Leve variación por baldosa para que no quede tan plano
			if ((x >= mitad) != (y >= mitad)):
				c = base.darkened(0.06)
			if x % mitad < junta_px or y % mitad < junta_px:
				c = junta
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := material_cozy(0.95)
	m.set_shader_parameter("textura_albedo", tex)
	m.set_shader_parameter("usar_uv_mundo", true)
	m.set_shader_parameter("escala_uv_mundo", escala_uv)
	# El piso no lleva rim (de lejos lo aclaraba entero) ni degradado (está todo a la misma altura)
	m.set_shader_parameter("rim_intensidad", 0.0)
	m.set_shader_parameter("usar_degradado", false)
	_materiales[clave] = m
	return m


## Material de lajas (mapa V3): una textura de modelos/ciudad/texturas/ (la genera
## tools/generar_lajas.py) que cubre "metros" x "metros" y se aplica en coordenadas del mundo, así las
## losas vecinas siguen el mismo dibujo sin uniones.
static func material_lajas(nombre: String, metros := 4.0, tinte := Color.WHITE) -> ShaderMaterial:
	var clave := "lajas_%s_%.2f_%s" % [nombre, metros, tinte.to_html()]
	if _materiales.has(clave):
		return _materiales[clave]
	var m := material_cozy(0.95)
	m.set_shader_parameter("textura_albedo", load("res://modelos/ciudad/texturas/%s.png" % nombre))
	m.set_shader_parameter("color_base", tinte)
	m.set_shader_parameter("usar_uv_mundo", true)
	m.set_shader_parameter("escala_uv_mundo", Vector2.ONE / metros)
	# El piso no lleva rim (de lejos lo aclaraba entero) ni degradado (está todo a la misma altura)
	m.set_shader_parameter("rim_intensidad", 0.0)
	m.set_shader_parameter("usar_degradado", false)
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
	PantallaCarga.refrescar()
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
	_sin_contorno_si_plano(mi, tam)
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
	_sin_contorno_si_plano(mi, tam)
	if con_colision:
		var forma := BoxShape3D.new()
		forma.size = tam
		colision(padre, pos, forma)
	return mi


## Las cajas finitas y anchas (marcas de la calle, sendas, cintas) son decoración pegada al piso: su
## contorno de tinta asomaría alrededor como una raya negra. Van sin contorno (y por eso se fusionan
## aparte de las piezas que sí lo llevan).
static func _sin_contorno_si_plano(mi: MeshInstance3D, tam: Vector3) -> void:
	if tam.y <= 0.06 and maxf(tam.x, tam.z) > 1.0:
		mi.set_meta(&"sin_contorno", true)


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
	# Cada texto es un dibujo aparte y de lejos no se lee: se deja de dibujar pasados 70 m (quien lo necesite
	# distinto lo pisa después, como Ciudad._texto)
	l.visibility_range_end = 70.0
	l.visibility_range_end_margin = 4.0
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
	# La letra se achica si el texto (en el idioma más largo) no entra en la tabla
	tam = mini(tam, int(tam_tabla.x * 100.0 / (Idioma.largo(texto) * 0.6 + 0.6)))
	var l := cartel(n, Vector3(0, 0, 0.012), texto, color_texto, tam)
	l.outline_size = 6
	return n


# ---------------------------------------------------------------- Fusión de mallas
# Cada MeshInstance3D es un dibujo aparte para la placa de video (y uno más por cada corte de la
# sombra del sol). El mundo tiene miles de piezas chicas, así que al terminar de armarlo se juntan
# en pocas mallas grandes: es lo que más rinde, sobre todo en el teléfono (WebGL).

static var _unitarias := {}   ## Forma de primitiva -> arrays de su versión "unitaria" (sin escalar)
static var _suaves := {}      ## Forma de primitiva -> normales suavizadas de la versión unitaria


## Junta en pocas mallas todas las MeshInstance3D estáticas que cuelgan de "raiz".
## No entra en los nodos con script (autos, comida, el nido...: se mueven o cambian) ni en los que
## tienen la meta "no_fusionar". Las piezas de color liso se juntan por rugosidad (con el color en
## los vértices); las demás, por material. Además se separan por celdas de "celda" metros (así la
## cámara sigue descartando lo que no ve) y por si proyectan sombra o no.
## Las colisiones no se tocan. Devuelve cuántas piezas se fusionaron.
## Transformación de "n" en el mundo. Funciona también fuera del árbol (el mundo se arma en otro hilo
## antes de entrar a la escena, ver Arranque): ahí se arma subiendo por los padres.
static func global_de(n: Node3D) -> Transform3D:
	if n.is_inside_tree():
		return n.global_transform
	return _global_padre(n) * n.transform


## Pone "n" en la transformación "t" del mundo (como global_transform = t), también fuera del árbol:
## ahí global_transform tomaría "t" como local y la pieza quedaría corrida si el padre no está en el origen.
static func poner_global(n: Node3D, t: Transform3D) -> void:
	if n.is_inside_tree():
		n.global_transform = t
	else:
		n.transform = _global_padre(n).affine_inverse() * t


## Como poner_global, pero sólo la posición.
static func poner_global_pos(n: Node3D, pos: Vector3) -> void:
	var t := global_de(n)
	t.origin = pos
	poner_global(n, t)


static func _global_padre(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p := n.get_parent()
	while p:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


## Como is_visible_in_tree(), pero también fuera del árbol.
static func visible_de(n: Node3D) -> bool:
	if n.is_inside_tree():
		return n.is_visible_in_tree()
	var p: Node = n
	while p:
		if p is Node3D and not (p as Node3D).visible:
			return false
		p = p.get_parent()
	return true


static func fusionar_estaticas(raiz: Node3D, celda := 24.0) -> int:
	var grupos := {}
	var fusionadas: Array[MeshInstance3D] = []
	var inv := global_de(raiz).affine_inverse()
	var pendientes: Array[Node] = [raiz]
	while not pendientes.is_empty():
		var n: Node = pendientes.pop_back()
		PantallaCarga.refrescar()
		for h in n.get_children():
			if h.get_script() != null or h.has_meta(&"no_fusionar"):
				continue
			var mi := h as MeshInstance3D
			if mi and mi.get_child_count() == 0:
				var mat := mi.material_override
				if mi.mesh == null or mat == null or not visible_de(mi):
					continue
				if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue   # Lo transparente se ordena por distancia: queda suelto
				var con_color := mat.has_meta(&"color_plano")
				var t := inv * global_de(mi)
				var centro := t * mi.mesh.get_aabb().get_center()
				var clave_mat := ("v%.2f" % rugosidad_de(mat)) if con_color else ("m%d" % mat.get_instance_id())
				# Las piezas con la meta "rango" (árboles, props chicos) van aparte y se dejan de
				# dibujar a esa distancia de la cámara
				var rango := float(mi.get_meta(&"rango", 0.0))
				var desde := float(mi.get_meta(&"rango_desde", 0.0))   # versiones "de lejos" (ver Kit)
				# Los pisos sin contorno de tinta (ver Kit.es_piso) van aparte y siguen sin contorno
				var sin_contorno := mi.has_meta(&"sin_contorno")
				var clave := "%d_%d_%s_%d_%d_%d_%d" % [floori(centro.x / celda), floori(centro.z / celda), clave_mat,
					mi.cast_shadow, roundi(rango), roundi(desde), int(sin_contorno)]
				if not grupos.has(clave):
					# La malla fusionada queda con su origen en el centro de la celda: así la distancia
					# de dibujo (visibility_range) se mide desde ahí y no desde el origen del mundo
					var origen := Vector3((floori(centro.x / celda) + 0.5) * celda, 0.0, (floori(centro.z / celda) + 0.5) * celda)
					grupos[clave] = {"mat": material_vertices(rugosidad_de(mat)) if con_color else mat,
						"color": con_color, "sombra": mi.cast_shadow, "rango": rango, "desde": desde, "origen": origen,
						"sin_contorno": sin_contorno, "piezas": []}
				var color: Color = mat.get_meta(&"color_plano") if con_color else Color.WHITE
				var o: Vector3 = grupos[clave]["origen"]
				(grupos[clave]["piezas"] as Array).append([mi.mesh, t.translated(-o), color])
				fusionadas.append(mi)
				continue
			pendientes.append(h)
	var i := 0
	for clave: String in grupos:
		PantallaCarga.refrescar()
		var g: Dictionary = grupos[clave]
		var mi := MeshInstance3D.new()
		mi.name = "Fusion%d" % i
		mi.mesh = combinar(g["piezas"], g["color"], not g["color"])
		mi.material_override = g["mat"]
		mi.cast_shadow = g["sombra"]
		if g["sin_contorno"]:
			mi.set_meta(&"sin_contorno", true)
		if float(g["rango"]) > 0.0:
			mi.visibility_range_end = float(g["rango"])
			mi.visibility_range_end_margin = 4.0
		if float(g["desde"]) > 0.0:
			mi.visibility_range_begin = float(g["desde"])
			mi.visibility_range_begin_margin = 4.0
		raiz.add_child(mi)
		mi.position = g["origen"]
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
	var suaves := PackedVector3Array()
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
		# Las suavizadas sólo con la rotación: en una caja estirada la esquina sigue saliendo en
		# diagonal (con la escala quedaría casi pegada a la cara más grande)
		suaves.append_array(Transform3D(t.basis.orthonormalized(), Vector3.ZERO) * (u[2] as PackedVector3Array))
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
	# Normales suavizadas para el contorno de tinta (ver normales_suaves())
	a[Mesh.ARRAY_CUSTOM0] = suaves.to_byte_array().to_float32_array()
	var formato := Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var am := ArrayMesh.new()
	if not verts.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, formato)
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
		_suaves[firma] = normales_suaves(_unitarias[firma])
	return [_unitarias[firma], esc, _suaves[firma]]


## Normales "suavizadas" para el contorno de tinta (shaders/contorno_tinta.gdshader): cada vértice
## se queda con el promedio de las normales de todos los vértices en la misma posición. En la
## esquina de una caja las tres copias del vértice apuntan en diagonal hacia afuera, así el contorno
## inflado no se abre en las aristas.
static func normales_suaves(arr: Array) -> PackedVector3Array:
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var suma := {}
	var claves: Array[Vector3i] = []
	claves.resize(v.size())
	for i in v.size():
		var k := Vector3i((v[i] * 1000.0).round())
		claves[i] = k
		suma[k] = suma.get(k, Vector3.ZERO) + n[i]
	var out := PackedVector3Array()
	out.resize(v.size())
	for i in v.size():
		var s: Vector3 = suma[claves[i]]
		out[i] = s.normalized() if s.length_squared() > 1e-6 else n[i]
	return out


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
