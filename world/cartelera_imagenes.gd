class_name CarteleraImagenes
extends RefCounted
## Carteleras de la vereda (pieza "cartelera" del kit) con imágenes. Cada cara se arma así:
## 1. Un panel blanco liso tapa los afiches de colores que trae el modelo.
## 2. Se ponen dos imágenes (de res://assets/carteleras/) a buen tamaño, enteras y sin deformar, una
##    arriba y otra abajo, apenas desfasadas para que quede natural. Nunca se pisan.
## 3. En los huecos que quedan se agregan unos pocos cuadros y rectángulos de colores chicos, sin pisar
##    las imágenes ni entre sí.
## Las imágenes rotan entre carteleras, y las dos de una misma cara son siempre distintas (mientras haya
## más de una). Se suman o cambian soltando archivos en la carpeta.

const CARPETA := "res://assets/carteleras/"
const EXTENSIONES := ["png", "jpg", "jpeg", "webp"]
const RANGO := 60.0

## Panel de la cartelera en el espacio de la pieza (ver tools/blender/ciudad_v3.py)
const PANEL_CENTRO := Vector2(0.0, 1.62)
const PANEL_TAM := Vector2(1.25, 1.58)
const AREA := Rect2(-0.57, 0.9, 1.14, 1.44)     ## Zona útil, con margen respecto del borde
const Z_PANEL := 0.0875                          ## Los afiches originales llegan a 0,085
const Z_IMAGEN := 0.0925
const Z_RELLENO := 0.0900
const CAJA_IMAGEN := Vector2(0.92, 0.66)         ## Tamaño máximo de cada imagen (ancho, alto)
const SEPARACION := 0.05
const RELLENOS := 3
const COLORES := [Color("ef5f50"), Color("8fd0f2"), Color("ffdd57"), Color("ff9cc8"), Color("58ba82"), Color("ff9145")]

static var _texturas: Array[Texture2D] = []
static var _cargadas := false
static var _siguiente := 0
static var _contador := 0
static var _quad: QuadMesh
static var _materiales := {}


static func _cargar() -> void:
	if _cargadas:
		return
	_cargadas = true
	var vistos := {}
	for f: String in DirAccess.get_files_at(CARPETA):
		# En el juego exportado los archivos figuran como "nombre.png.import"
		var nombre := f.trim_suffix(".import")
		if nombre.get_extension().to_lower() in EXTENSIONES and not vistos.has(nombre):
			vistos[nombre] = true
			var t := load(CARPETA + nombre) as Texture2D
			if t:
				_texturas.append(t)


static func reiniciar() -> void:
	_siguiente = 0
	_contador = 0


## Arma las dos caras de una cartelera ubicada en "t" (transformación de la pieza).
static func poner(padre: Node3D, t: Transform3D) -> void:
	_cargar()
	if _texturas.is_empty():
		return
	for cara in 2:
		_contador += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 9100 + _contador * 31
		_cara(padre, t, cara, rng)


static func _cara(padre: Node3D, t: Transform3D, cara: int, rng: RandomNumberGenerator) -> void:
	# 1. Panel blanco
	_quad_en(padre, t, cara, Rect2(PANEL_CENTRO - PANEL_TAM / 2.0, PANEL_TAM), Z_PANEL,
		Construir.material(Color("f4f5f7"), 0.85))
	# 2. Dos imágenes, una arriba y otra abajo
	var primera := _texturas[_siguiente % _texturas.size()]
	var segunda := _texturas[(_siguiente + 1) % _texturas.size()]
	_siguiente += 2
	var ocupado: Array[Rect2] = []
	var desfase := rng.randf_range(0.05, 0.14) * (1.0 if rng.randf() < 0.5 else -1.0)
	var y_alto := AREA.position.y + AREA.size.y - CAJA_IMAGEN.y / 2.0 - 0.02
	var y_bajo := AREA.position.y + CAJA_IMAGEN.y / 2.0 + 0.02
	var cajas: Array[Vector2] = [Vector2(desfase, y_alto), Vector2(-desfase, y_bajo)]
	var texs: Array[Texture2D] = [primera, segunda]
	for i in 2:
		var tam := _ajustar(texs[i])
		var r := Rect2(cajas[i] - tam / 2.0, tam)
		ocupado.append(r)
		_quad_en(padre, t, cara, r, Z_IMAGEN, _material(texs[i]))
	# 3. Unos pocos cuadros y rectángulos de colores en los huecos
	var puestos := 0
	var intentos := 0
	while puestos < RELLENOS and intentos < 60:
		intentos += 1
		var tam := Vector2(rng.randf_range(0.1, 0.22), rng.randf_range(0.08, 0.2))
		if rng.randf() < 0.4:
			tam.y = tam.x       # algunos son cuadrados
		var pos := Vector2(rng.randf_range(AREA.position.x, AREA.end.x - tam.x),
			rng.randf_range(AREA.position.y, AREA.end.y - tam.y))
		var r := Rect2(pos, tam)
		var libre := true
		for o in ocupado:
			if r.grow(SEPARACION).intersects(o):
				libre = false
				break
		if not libre:
			continue
		ocupado.append(r)
		puestos += 1
		var color: Color = COLORES[rng.randi() % COLORES.size()]
		_quad_en(padre, t, cara, r, Z_RELLENO, Construir.material(color, 0.85))


## Tamaño con que entra la imagen en CAJA_IMAGEN, sin deformarse (y sin agrandar de más las chicas).
static func _ajustar(tex: Texture2D) -> Vector2:
	var a := float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var ancho := CAJA_IMAGEN.x
	var alto := ancho / a
	if alto > CAJA_IMAGEN.y:
		alto = CAJA_IMAGEN.y
		ancho = alto * a
	return Vector2(ancho, alto)


## Un rectángulo plano pegado a la cara (0 = adelante, 1 = atrás), en el espacio de la pieza.
static func _quad_en(padre: Node3D, t: Transform3D, cara: int, rect: Rect2, z: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	m.mesh = _malla()
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = RANGO
	m.visibility_range_end_margin = 4.0
	var c := rect.get_center()
	# La cara de atrás gira media vuelta para que las imágenes no salgan espejadas
	var giro := 0.0 if cara == 0 else PI
	var lado := 1.0 if cara == 0 else -1.0
	var local := Transform3D(Basis(Vector3.UP, giro).scaled_local(Vector3(rect.size.x, rect.size.y, 1.0)),
		Vector3(c.x * lado, c.y, z * lado))
	padre.add_child(m)
	m.global_transform = t * local


static func _malla() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


static func _material(tex: Texture2D) -> StandardMaterial3D:
	if not _materiales.has(tex):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = tex
		mat.roughness = 1.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materiales[tex] = mat
	return _materiales[tex]
