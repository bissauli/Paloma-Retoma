class_name Horizonte
extends Node3D
## El mundo no jugable detrás de la pared invisible (mapa V4.5): capas de siluetas de ciudad con
## paralaje, para que se sienta que Buenos Aires sigue y sigue.
## - Cuatro anillos (elipses alrededor del mapa) de torres, cada uno más lejos, más alto y más
##   "lavado" por la bruma que el anterior: perspectiva atmosférica.
## - Paralaje: cada anillo sigue a la cámara en X/Z en una proporción distinta (SIGUE). El de adelante
##   casi no se mueve y el del fondo la acompaña casi entera, así al volar los de atrás se desplazan
##   más despacio que los de adelante, como si estuvieran mucho más lejos de lo que están (todo queda
##   adentro del alcance de la cámara, 400 m). Nunca se pueden alcanzar: están detrás de la fila de
##   edificios de fondo y de la pared invisible.
## - Color: cada cuadro se mezcla el color de la silueta con el de la niebla de world/cielo.gd (de día
##   celeste lavanda, al atardecer naranja, de noche oscuro); de noche se prenden ventanitas.
## Cada anillo es una sola malla sin luz ni sombra (barato: 4 dibujos + 2 de ventanas).

## Por capa: radio en X y en Z de la elipse, alto de las torres (mín, máx), cuánto sigue a la cámara y
## cuánto se lava con la bruma (0 = color propio, 1 = color de la niebla).
const CAPAS := [
	{"radio": Vector2(262, 196), "alto": Vector2(16, 46), "sigue": 0.35, "bruma": 0.30, "ancho": Vector2(12, 24)},
	{"radio": Vector2(298, 238), "alto": Vector2(24, 64), "sigue": 0.55, "bruma": 0.50, "ancho": Vector2(14, 28)},
	{"radio": Vector2(332, 280), "alto": Vector2(34, 86), "sigue": 0.72, "bruma": 0.68, "ancho": Vector2(16, 34)},
	{"radio": Vector2(358, 318), "alto": Vector2(46, 118), "sigue": 0.86, "bruma": 0.82, "ancho": Vector2(20, 40)},
]
## Colores propios de las siluetas (de adelante hacia atrás): grises lavanda y celestes de la paleta.
const COLORES := [Color("8e8aa8"), Color("9a9cbc"), Color("a8b0cc"), Color("b4bed6")]
const VENTANA := Color("ffd98a")

var _capas: Array[MeshInstance3D] = []
var _materiales: Array[StandardMaterial3D] = []
var _ventanas: Array[MeshInstance3D] = []
var _mat_ventanas: StandardMaterial3D
var _cielo: Cielo
var _t_color := 0.0


func _ready() -> void:
	name = "Horizonte"
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	_mat_ventanas = StandardMaterial3D.new()
	_mat_ventanas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_ventanas.disable_fog = true
	_mat_ventanas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_ventanas.albedo_color = Color(VENTANA, 0.0)
	_mat_ventanas.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in CAPAS.size():
		var capa: Dictionary = CAPAS[k]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.disable_fog = true
		mat.disable_receive_shadows = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiales.append(mat)
		var ventanas := PackedVector3Array()
		var mi := MeshInstance3D.new()
		mi.name = "Capa%d" % k
		mi.mesh = _anillo(capa, rng, ventanas if k < 2 else null)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.set_meta(&"no_fusionar", true)
		add_child(mi)
		_capas.append(mi)
		if k < 2:
			var mv := MeshInstance3D.new()
			mv.name = "Ventanas%d" % k
			mv.mesh = _quads(ventanas)
			mv.material_override = _mat_ventanas
			mv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mv.visible = false
			mi.add_child(mv)
			_ventanas.append(mv)
	_colorear()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		for k in _capas.size():
			var f: float = CAPAS[k]["sigue"]
			_capas[k].position = Vector3(p.x * f, 0.0, p.z * f)
	_t_color -= delta
	if _t_color <= 0.0:
		_t_color = 0.25
		_colorear()


## Tiñe cada capa con la niebla del cielo (y prende las ventanas de noche).
func _colorear() -> void:
	if _cielo == null or not is_instance_valid(_cielo):
		_cielo = get_tree().get_first_node_in_group("cielo") as Cielo if is_inside_tree() else null
	var niebla := Color("c9d3e6")
	var noche := 0.0
	if _cielo:
		niebla = _cielo.niebla_actual
		noche = _cielo.noche_actual
	for k in _capas.size():
		var c: Color = COLORES[k]
		# De noche las siluetas se oscurecen con la niebla (que ya viene oscura)
		_materiales[k].albedo_color = c.lerp(niebla, float(CAPAS[k]["bruma"])) * lerpf(1.0, 0.55, noche)
	_mat_ventanas.albedo_color = Color(VENTANA, clampf(noche * 1.2, 0.0, 0.9))
	for v in _ventanas:
		v.visible = noche > 0.05


## Malla de un anillo de torres. Colores por vértice: la base más clara (la bruma pega abajo) y la
## parte de arriba el color pleno; el material los multiplica por el color de la capa.
func _anillo(capa: Dictionary, rng: RandomNumberGenerator, ventanas: Variant) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radio: Vector2 = capa["radio"]
	var alto: Vector2 = capa["alto"]
	var ancho: Vector2 = capa["ancho"]
	var perimetro := PI * (3.0 * (radio.x + radio.y) - sqrt((3.0 * radio.x + radio.y) * (radio.x + 3.0 * radio.y)))
	var n := int(perimetro / ((ancho.x + ancho.y) / 2.0 * 0.82))
	for i in n:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / n
		var c := Vector3(cos(a) * radio.x, 0.0, sin(a) * radio.y)
		var w := rng.randf_range(ancho.x, ancho.y)
		var d := rng.randf_range(ancho.x, ancho.y)
		var h := rng.randf_range(alto.x, alto.y)
		# De vez en cuando un rascacielos bien alto
		if rng.randf() < 0.08:
			h *= 1.6
		var giro := -a + rng.randf_range(-0.3, 0.3)
		var b := Basis.from_euler(Vector3(0, giro, 0))
		var tono := rng.randf_range(0.86, 1.08)
		_caja(st, c + Vector3(0, h / 2.0, 0), Vector3(w, h, d), b, tono)
		# Remates: un retiro, sala de máquinas y tanque, una antena o una cúpula achatada
		var dado := rng.randf()
		if dado < 0.35:
			var h2 := h * rng.randf_range(0.12, 0.3)
			_caja(st, c + Vector3(0, h + h2 / 2.0, 0), Vector3(w * 0.62, h2, d * 0.62), b, tono * 1.03)
			h += h2
		elif dado < 0.55:
			_caja(st, c + b * Vector3(w * 0.2, h + 1.6, 0), Vector3(3.5, 3.2, 3.5), b, tono)
		elif dado < 0.65:
			_caja(st, c + b * Vector3(0, h + h * 0.18, 0), Vector3(0.8, h * 0.36, 0.8), b, tono)
		elif dado < 0.72:
			_caja(st, c + Vector3(0, h + 2.0, 0), Vector3(w * 0.5, 4.0, d * 0.5), b * Basis(Vector3.UP, PI / 4.0), tono * 1.05)
		if ventanas is PackedVector3Array and rng.randf() < 0.7:
			# Ventanitas en la cara que mira al centro (para la noche)
			var hacia := -Vector3(cos(a), 0, sin(a))
			for k in rng.randi_range(4, 12):
				var u := rng.randf_range(-w * 0.4, w * 0.4)
				var y := rng.randf_range(3.0, h * 0.9)
				var lado := hacia.cross(Vector3.UP).normalized()
				(ventanas as PackedVector3Array).append(c + hacia * (d * 0.5 + 0.3) + lado * u + Vector3(0, y, 0))
				(ventanas as PackedVector3Array).append(hacia)
	st.generate_normals()
	return st.commit()


## Caja con colores por vértice (la base más clara que el techo).
func _caja(st: SurfaceTool, centro: Vector3, tam: Vector3, b: Basis, tono: float) -> void:
	var h := tam / 2.0
	var esquinas := []
	for i in 8:
		esquinas.append(centro + b * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	var caras := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in caras:
		var q := [esquinas[f[0]], esquinas[f[1]], esquinas[f[2]], esquinas[f[3]]]
		for t: Array in [[0, 1, 2], [0, 2, 3]]:
			for j: int in t:
				var p: Vector3 = q[j]
				var arriba := clampf(p.y / 60.0, 0.0, 1.0)
				st.set_color(Color(tono, tono, tono).lerp(Color(1.12, 1.12, 1.15), (1.0 - arriba) * 0.35))
				st.add_vertex(p)


## Cuadraditos de ventana: pares [posición, normal] en "datos".
func _quads(datos: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, datos.size(), 2):
		var p := datos[i]
		var n := datos[i + 1]
		var lado := n.cross(Vector3.UP).normalized() * 0.7
		var arriba := Vector3(0, 0.9, 0)
		var v := [p - lado - arriba, p + lado - arriba, p + lado + arriba, p - lado + arriba]
		for j: int in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(v[j])
	return st.commit()
