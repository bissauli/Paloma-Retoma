class_name LucesNoche
extends Node3D
## Luces de la noche, hechas para costar casi nada (sin OmniLight ni LUT: una LUT es un filtro de color de
## toda la pantalla y no pone luces en el mundo, y en Compatibility las luces reales son carísimas):
## - Todo son quads aditivos con un solo shader (shaders/luz_noche.gdshader) que se apaga con la global
##   "luces_noche" (la maneja world/cielo.gd según la hora). Sin sombras, sin transparencias ordenadas.
## - Las ventanas encendidas (algunas, al azar) y los faroles de la ciudad van en MultiMesh agrupados en
##   celdas de 48 m: cada celda es UN dibujo y se deja de dibujar a RANGO m de la cámara.
## - De día (valor 0) los nodos se ocultan enteros: cuesta cero.
## - Los autos en movimiento ponen sus propios faros (ver Auto._luces) y los faroles de la plaza los suyos
##   (ver farol_directo): pocos nodos, un material compartido.
## Las ventanas se sacan de las mallas de los edificios del kit (los polígonos con el color "vidrio"), una
## sola vez por pieza.

const RANGO := 170.0
const CELDA := 48.0
const PROB_VENTANA := 0.3
const FAROLES := ["farola", "farola_curva", "farol", "farol_doble"]
const SHADER := preload("res://shaders/luz_noche.gdshader")

static var encendido := false              ## Si las luces están prendidas (los autos nuevos nacen con esto)
static var faroles_extra: Array = []       ## [cabeza (mundo), altura del piso, escala] (postes de luz, ver NivelAlto.poste)
static var _materiales := {}
static var _quad: QuadMesh
static var _plano: QuadMesh
static var _cache_ventanas := {}
static var _valor := 0.0


static func reiniciar() -> void:
	faroles_extra.clear()
	encendido = false


static func es_farol(nombre: String) -> bool:
	return nombre in FAROLES


## Dónde está la lámpara de cada farol, en el espacio de la pieza.
static func cabeza_local(nombre: String) -> Vector3:
	match nombre:
		"farola": return Vector3(0.0, 6.95, 1.95)
		"farola_curva": return Vector3(0.0, 6.25, 2.5)
		"farol": return Vector3(0.0, 2.8, 0.0)
	return Vector3(0.0, 2.9, 0.0)


static func material(modo: int, color := Color.WHITE, intensidad := 1.0) -> ShaderMaterial:
	var clave := "%d_%s_%.2f" % [modo, color.to_html(true), intensidad]
	if not _materiales.has(clave):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("modo", modo)
		m.set_shader_parameter("tinte", color)
		m.set_shader_parameter("intensidad", intensidad)
		m.set_shader_parameter("luces_noche", _valor)
		m.render_priority = 2
		_materiales[clave] = m
	return _materiales[clave]


static func _malla_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


static func _malla_plano() -> QuadMesh:
	if _plano == null:
		_plano = QuadMesh.new()
		_plano.size = Vector2.ONE
		_plano.orientation = PlaneMesh.FACE_Y
	return _plano


## Un destello (mira a la cámara) de "tam" metros en "pos" (espacio local del padre).
static func sprite(pos: Vector3, tam: float, color := Color(1.0, 0.92, 0.7)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _malla_quad()
	mi.material_override = material(0, color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.from_scale(Vector3.ONE * tam), pos)
	return mi


## Un charco de luz plano (haz de faros, círculo bajo un farol) de tam.x por tam.y metros.
static func charco(pos: Vector3, tam: Vector2, color := Color(1.0, 0.9, 0.65, 0.5)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _malla_plano()
	mi.material_override = material(2, color, 0.7)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(Basis.from_scale(Vector3(tam.x, 1.0, tam.y)), pos)
	return mi


## Farol suelto (los de la plaza): destello arriba y charco abajo. Se prenden con el grupo "luces_noche".
static func farol_directo(padre: Node3D, cabeza: Vector3, suelo_y: float) -> void:
	var n := Node3D.new()
	n.name = "LuzFarol"
	n.add_to_group("luces_noche")
	n.visible = encendido
	padre.add_child(n)
	n.add_child(sprite(cabeza, 1.9))
	n.add_child(charco(Vector3(cabeza.x, suelo_y + 0.05, cabeza.z), Vector2(9.0, 9.0)))


## Arma las luces fijas de la ciudad: faroles, postes y algunas ventanas. Lo llama Ciudad al final.
static func construir(ciudad: Ciudad) -> void:
	var nodo := LucesNoche.new()
	nodo.name = "LucesNoche"
	nodo.add_to_group("luces_noche")
	nodo.visible = encendido
	ciudad.add_child(nodo)
	var azar := RandomNumberGenerator.new()
	azar.seed = 777
	# Faroles: destello en la lámpara y charco en el piso
	var destellos := {}    # celda -> Array[Transform3D]
	var charcos := {}
	var lamparas: Array = []
	for f: Array in ciudad.luces_fijas:
		var t: Transform3D = f[1]
		var cab: Vector3 = t * cabeza_local(String(f[0]))
		lamparas.append([cab, t.origin.y, 1.0 if String(f[0]).begins_with("farola") else 0.7])
	lamparas.append_array(faroles_extra)
	for l: Array in lamparas:
		var cab: Vector3 = l[0]
		var esc: float = l[2]
		_sumar(destellos, cab, Transform3D(Basis.from_scale(Vector3.ONE * 2.0 * esc), cab), Color(1.0, 0.9, 0.65, 1.0))
		var r := 11.0 * esc
		var p := Vector3(cab.x, float(l[1]) + 0.05, cab.z)
		_sumar(charcos, p, Transform3D(Basis.from_scale(Vector3(r, 1.0, r)), p), Color(1.0, 0.85, 0.55, 0.55))
	_multimallas(nodo, destellos, _malla_quad(), material(0))
	_multimallas(nodo, charcos, _malla_plano(), material(2, Color.WHITE, 0.7))
	# Ventanas encendidas
	var ventanas := {}
	var colores := [Color(1.0, 0.82, 0.5), Color(1.0, 0.78, 0.45), Color(1.0, 0.9, 0.65), Color(0.75, 0.88, 1.0), Color(1.0, 0.65, 0.35)]
	for e: Array in ciudad.luces_edificios:
		var tr: Transform3D = e[1]
		var esc := tr.basis.get_scale().x
		for v: Array in ventanas_de(String(e[0])):
			if azar.randf() > PROB_VENTANA:
				continue
			var n_local: Vector3 = v[1]
			var n := (tr.basis * n_local).normalized()
			var tang := Vector3.UP.cross(n).normalized()
			var centro: Vector3 = tr * (v[0] as Vector3) + n * 0.06
			var w: float = float(v[2]) * esc * 0.8
			var h: float = float(v[3]) * esc * 0.8
			var c: Color = colores[azar.randi() % colores.size()]
			c.a = azar.randf_range(0.55, 1.0)
			_sumar(ventanas, centro, Transform3D(Basis(tang * w, Vector3.UP * h, n), centro), c)
	_multimallas(nodo, ventanas, _malla_quad(), material(1))


static func _sumar(grupos: Dictionary, pos: Vector3, t: Transform3D, color: Color) -> void:
	var celda := Vector2i(floori(pos.x / CELDA), floori(pos.z / CELDA))
	if not grupos.has(celda):
		grupos[celda] = []
	(grupos[celda] as Array).append([t, color])


static func _multimallas(padre: Node3D, grupos: Dictionary, malla: Mesh, mat: Material) -> void:
	for celda: Vector2i in grupos:
		var items: Array = grupos[celda]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = malla
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = RANGO
		mi.visibility_range_end_margin = 10.0
		mi.custom_aabb = AABB(Vector3((celda.x - 0.5) * CELDA, -5.0, (celda.y - 0.5) * CELDA), Vector3(CELDA * 2.0, 90.0, CELDA * 2.0))
		padre.add_child(mi)


## Las ventanas de un edificio del kit, en su espacio local: [centro, normal horizontal hacia afuera, ancho, alto].
## Salen de los triángulos con el color "vidrio" de la paleta (la celda se lee de la UV); los dos
## triángulos de cada ventana se juntan en una sola. Se calcula una vez por pieza.
static func ventanas_de(nombre: String) -> Array:
	if _cache_ventanas.has(nombre):
		return _cache_ventanas[nombre]
	var res: Array = []
	_cache_ventanas[nombre] = res
	var malla := Kit.malla(nombre)
	if malla == null:
		return res
	var celdas: Array[Vector2i] = []
	for i in KitDatos.PALETA.size():
		var n: String = KitDatos.PALETA[i][0]
		if n == "vidrio" or n == "vidrio_osc":
			celdas.append(Vector2i(i % KitDatos.CELDAS, floori(i / float(KitDatos.CELDAS))))
	if celdas.is_empty():
		return res
	var cajas: Array[Dictionary] = []
	for s in malla.get_surface_count():
		var arr := malla.surface_get_arrays(s)
		if arr.size() <= Mesh.ARRAY_TEX_UV or arr[Mesh.ARRAY_VERTEX] == null or arr[Mesh.ARRAY_TEX_UV] == null:
			continue
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var ns := PackedVector3Array()
		if arr[Mesh.ARRAY_NORMAL] != null:
			ns = arr[Mesh.ARRAY_NORMAL]
		var idx := PackedInt32Array()
		if arr[Mesh.ARRAY_INDEX] != null:
			idx = arr[Mesh.ARRAY_INDEX]
		var cant := idx.size() if idx.size() > 0 else vs.size()
		for k in range(0, cant - 2, 3):
			var a := idx[k] if idx.size() > 0 else k
			var b := idx[k + 1] if idx.size() > 0 else k + 1
			var c := idx[k + 2] if idx.size() > 0 else k + 2
			var uv := (uvs[a] + uvs[b] + uvs[c]) / 3.0
			var celda := Vector2i(floori(uv.x * KitDatos.CELDAS), floori((1.0 - uv.y) * KitDatos.FILAS))
			if not celdas.has(celda):
				continue
			var n := Vector3.ZERO
			if ns.size() > 0:
				n = ns[a] + ns[b] + ns[c]
			else:
				n = (vs[b] - vs[a]).cross(vs[c] - vs[a])
			n = Vector3(n.x, 0.0, n.z)
			if n.length() < 0.3:
				continue      # Tapa o piso: no es una ventana de fachada
			n = n.normalized()
			var tang := Vector3.UP.cross(n).normalized()
			var d := n.dot(vs[a])
			var s_min := INF
			var s_max := -INF
			var y_min := INF
			var y_max := -INF
			for q: Vector3 in [vs[a], vs[b], vs[c]]:
				var sq := q.dot(tang)
				s_min = minf(s_min, sq)
				s_max = maxf(s_max, sq)
				y_min = minf(y_min, q.y)
				y_max = maxf(y_max, q.y)
			var centro_s := (s_min + s_max) / 2.0
			var centro_y := (y_min + y_max) / 2.0
			var unida := false
			for cj in cajas:
				if n.dot(cj["n"]) > 0.97 and absf(d - float(cj["d"])) < 0.12 \
						and centro_s >= float(cj["s0"]) - 0.2 and centro_s <= float(cj["s1"]) + 0.2 \
						and centro_y >= float(cj["y0"]) - 0.2 and centro_y <= float(cj["y1"]) + 0.2:
					cj["s0"] = minf(float(cj["s0"]), s_min)
					cj["s1"] = maxf(float(cj["s1"]), s_max)
					cj["y0"] = minf(float(cj["y0"]), y_min)
					cj["y1"] = maxf(float(cj["y1"]), y_max)
					unida = true
					break
			if not unida:
				cajas.append({"n": n, "d": d, "s0": s_min, "s1": s_max, "y0": y_min, "y1": y_max})
	for cj in cajas:
		var w: float = float(cj["s1"]) - float(cj["s0"])
		var h: float = float(cj["y1"]) - float(cj["y0"])
		if w < 0.4 or h < 0.4 or w > 4.0 or h > 4.0:
			continue
		var n: Vector3 = cj["n"]
		var tang := Vector3.UP.cross(n).normalized()
		var centro := n * float(cj["d"]) + tang * ((float(cj["s0"]) + float(cj["s1"])) / 2.0) + Vector3.UP * ((float(cj["y0"]) + float(cj["y1"])) / 2.0)
		res.append([centro, n, w, h])
	return res


## Lo llama Cielo en cada cambio de hora: 0 de día, 1 de noche. Actualiza el brillo de todos los materiales
## (son pocos y compartidos) y, sólo al prender o apagar, muestra u oculta los nodos (de día no se dibuja nada).
static func poner_noche(valor: float, arbol: SceneTree) -> void:
	if absf(valor - _valor) < 0.004:
		return
	_valor = valor
	for m: ShaderMaterial in _materiales.values():
		m.set_shader_parameter("luces_noche", valor)
	var prendido := valor > 0.02
	if prendido == encendido:
		return
	encendido = prendido
	if arbol:
		for n in arbol.get_nodes_in_group("luces_noche"):
			(n as Node3D).visible = prendido
