class_name PinturaPaloma
extends RefCounted
## Pintura libre sobre la paloma (modo avanzado de "Mi paloma"). La pintura es una imagen RGBA de
## 128x128 alineada 1:1 con la textura del modelo (transparente = sin pintar), así cada pincelada
## cambia texels reales y se conserva el pixel-art.
## - golpe(): de un rayo en el espacio del GLB al texel que toca (contra los 156 triángulos del modelo
##   en reposo; son 78 caras de 2 triángulos cada una).
## - El pincel sólo pinta texels de la MISMA cara que el centro: la textura es un atlas de caras
##   pegadas y sin esto la pincelada se correría a la cara vecina.
## Sólo datos y cuentas: no sabe de la interfaz ni del perfil.

const TAM := 128

static var _listo := false
static var _pos := PackedVector3Array()    ## 3 vértices por triángulo (espacio del GLB, en reposo)
static var _uvs := PackedVector2Array()    ## 3 UV (en texels) por triángulo
static var _cara := PackedInt32Array()     ## Cara de cada texel (TAM*TAM), -1 = no es parte del modelo
static var _base: Image                    ## Textura original (para el cuentagotas)


static func preparar() -> void:
	if _listo:
		return
	var glb := (ModeloPaloma.VARIANTES["Original"] as PackedScene).instantiate()
	var mi := glb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	_pos.clear()
	_uvs.clear()
	for i in idx:
		_pos.append(v[i])
		_uvs.append(uv[i] * TAM)
	_cara.resize(TAM * TAM)
	_cara.fill(-1)
	for t in floori(idx.size() / 3.0):
		_asignar_cara(t)
	_base = ((mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture as Texture2D).get_image()
	if _base.is_compressed():
		_base.decompress()
	_base.convert(Image.FORMAT_RGBA8)
	glb.free()
	_listo = true


## Marca los texels de un triángulo con el número de su cara (la cara es el par de triángulos 2k, 2k+1).
static func _asignar_cara(t: int) -> void:
	var a := _uvs[t * 3]
	var b := _uvs[t * 3 + 1]
	var c := _uvs[t * 3 + 2]
	var minx := maxi(int(floor(minf(a.x, minf(b.x, c.x)))), 0)
	var maxx := mini(int(ceil(maxf(a.x, maxf(b.x, c.x)))), TAM - 1)
	var miny := maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
	var maxy := mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), TAM - 1)
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if _cara[y * TAM + x] == -1 and _dentro(Vector2(x + 0.5, y + 0.5), a, b, c):
				_cara[y * TAM + x] = t >> 1


static func _dentro(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var neg := d1 < -0.001 or d2 < -0.001 or d3 < -0.001
	var pos := d1 > 0.001 or d2 > 0.001 or d3 > 0.001
	return not (neg and pos)


## Rayo (origen y dirección en el espacio del GLB) -> el texel que toca, o {} si no toca la paloma.
## Devuelve {"texel": Vector2i, "cara": int, "punto": Vector3}.
static func golpe(origen: Vector3, dir: Vector3) -> Dictionary:
	preparar()
	var mejor := INF
	var res := {}
	for t in floori(_pos.size() / 3.0):
		var a := _pos[t * 3]
		var b := _pos[t * 3 + 1]
		var c := _pos[t * 3 + 2]
		var p: Variant = Geometry3D.ray_intersects_triangle(origen, dir, a, b, c)
		if p == null:
			continue
		var d := origen.distance_squared_to(p)
		if d >= mejor:
			continue
		var bar := _baricentricas(p, a, b, c)
		var uv := _uvs[t * 3] * bar.x + _uvs[t * 3 + 1] * bar.y + _uvs[t * 3 + 2] * bar.z
		var texel := Vector2i(clampi(int(floor(uv.x)), 0, TAM - 1), clampi(int(floor(uv.y)), 0, TAM - 1))
		var cara := _cara[texel.y * TAM + texel.x]
		if cara < 0:
			continue
		mejor = d
		res = {"texel": texel, "cara": cara, "punto": p}
	return res


static func _baricentricas(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var den := d00 * d11 - d01 * d01
	if absf(den) < 0.0000001:
		return Vector3(1, 0, 0)
	var y := (d11 * d20 - d01 * d21) / den
	var z := (d00 * d21 - d01 * d20) / den
	return Vector3(1.0 - y - z, y, z)


static func cara_de(texel: Vector2i) -> int:
	preparar()
	if texel.x < 0 or texel.y < 0 or texel.x >= TAM or texel.y >= TAM:
		return -1
	return _cara[texel.y * TAM + texel.x]


## Imagen vacía para pintar (transparente).
static func nueva_imagen() -> Image:
	var img := Image.create(TAM, TAM, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Los texels que cubre un pincel cuadrado de "tam" (1 a 3) centrado en "texel", sólo de su cara.
static func texels_del_pincel(texel: Vector2i, tam: int) -> Array[Vector2i]:
	preparar()
	var lista: Array[Vector2i] = []
	var cara := cara_de(texel)
	if cara < 0:
		return lista
	var desde := -((tam - 1) >> 1)
	for dy in range(desde, desde + tam):
		for dx in range(desde, desde + tam):
			var t := texel + Vector2i(dx, dy)
			if cara_de(t) == cara:
				lista.append(t)
	return lista


## Pinta con "color". Devuelve true si cambió algún texel.
static func pintar(img: Image, texel: Vector2i, tam: int, color: Color) -> bool:
	var cambio := false
	color.a = 1.0
	for t in texels_del_pincel(texel, tam):
		if img.get_pixelv(t) != color:
			img.set_pixelv(t, color)
			cambio = true
	return cambio


## Borra la pintura (vuelve a verse la textura y el color de zona).
static func borrar(img: Image, texel: Vector2i, tam: int) -> bool:
	var cambio := false
	for t in texels_del_pincel(texel, tam):
		if img.get_pixelv(t).a > 0.0:
			img.set_pixelv(t, Color(0, 0, 0, 0))
			cambio = true
	return cambio


## Rellena toda la cara que toca el texel. Devuelve true si cambió algo.
static func rellenar(img: Image, texel: Vector2i, color: Color) -> bool:
	preparar()
	var cara := cara_de(texel)
	if cara < 0:
		return false
	color.a = 1.0
	var cambio := false
	for y in TAM:
		for x in TAM:
			if _cara[y * TAM + x] == cara and img.get_pixel(x, y) != color:
				img.set_pixel(x, y, color)
				cambio = true
	return cambio


## Color de un texel: el pintado, o si no hay, el de la textura original (cuentagotas).
static func muestrear(img: Image, texel: Vector2i) -> Color:
	preparar()
	if img != null:
		var p := img.get_pixelv(texel)
		if p.a > 0.0:
			p.a = 1.0
			return p
	var c := _base.get_pixelv(texel)
	c.a = 1.0
	return c
