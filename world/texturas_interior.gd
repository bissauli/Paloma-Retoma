class_name TexturasInterior
extends RefCounted
## Texturas de los interiores de los pasajes (world/pasaje.gd), generadas por código: pisos de tablas
## con veta, damero de baldosas y porcelanato; paredes de revoque, empapelado, ladrillo y azulejo.
## Usan el shader del estilo cozy con UV del mundo (como Construir.material_baldosas), así el dibujo
## sigue de una pieza a otra sin uniones y se ve igual en cualquier pared. Se cachean por parámetros.
## Los colores son sutiles a propósito: dan textura sin pelearse con el estilo low poly de los muebles.

## Lado de cada textura, en píxeles. Se pintan pixel por pixel al armar el mundo: en la web (GDScript en
## un solo hilo) van a la mitad, que es la cuarta parte del trabajo y de la memoria.
static var PX := 128 if OS.has_feature("web") else 256
static var _k := PX / 256.0   ## Las juntas y las florcitas están medidas en una textura de 256

static var _cache := {}


## Piso: "tablas" (madera en dos tonos), "baldosas" (damero) o "porcelanato" (losas grandes).
static func piso(tipo: String, c1: Color, c2: Color) -> Material:
	var clave := "piso_%s_%s_%s" % [tipo, c1.to_html(), c2.to_html()]
	if _cache.has(clave):
		return _cache[clave]
	var img: Image
	var metros := 1.6
	match tipo:
		"tablas":
			img = _tablas(c1, c2)
			metros = 1.6
		"porcelanato":
			img = _losas(c1, c2.darkened(0.08), 2, 0.012, 0.035)
			metros = 1.6
		_:
			img = _damero(c1, c2)
			metros = 1.6
	var m := _material(img, metros, 0.8 if tipo == "porcelanato" else 0.92)
	_cache[clave] = m
	return m


## Pared: "lisa" (revoque), "empapelado" (rayas con florcitas), "ladrillo" o "azulejo" (blanco con junta).
static func pared(tipo: String, c: Color) -> Material:
	var clave := "pared_%s_%s" % [tipo, c.to_html()]
	if _cache.has(clave):
		return _cache[clave]
	var img: Image
	var metros := 2.0
	match tipo:
		"empapelado":
			img = _empapelado(c)
			metros = 1.0
		"ladrillo":
			img = _ladrillo(c)
			metros = 1.2
		"azulejo":
			img = _losas(c, c.darkened(0.06), 4, 0.014, 0.025)
			metros = 1.2
		_:
			img = _revoque(c)
			metros = 2.0
	var m := _material(img, metros, 0.95)
	_cache[clave] = m
	return m


## Panel de luz del cielorraso: brilla del color de la luz del lugar (no lo apaga la sombra).
static func panel_luz(c: Color) -> Material:
	var clave := "panel_%s" % c.to_html()
	if _cache.has(clave):
		return _cache[clave]
	var m := StandardMaterial3D.new()
	m.albedo_color = c.lightened(0.35)
	m.emission_enabled = true
	m.emission = c.lightened(0.2)
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[clave] = m
	return m


# ---------------------------------------------------------------- Material y ruido

static func _material(img: Image, metros: float, rugosidad: float) -> ShaderMaterial:
	img.generate_mipmaps()
	var m := Construir.material_cozy(rugosidad)
	m.set_shader_parameter("textura_albedo", ImageTexture.create_from_image(img))
	m.set_shader_parameter("usar_uv_mundo", true)
	m.set_shader_parameter("escala_uv_mundo", Vector2.ONE / metros)
	m.set_shader_parameter("rim_intensidad", 0.0)
	m.set_shader_parameter("usar_degradado", false)
	return m


## Ruido de valor que se repite sin costura (para manchas suaves), entre 0 y 1.
static func _ruido(x: float, y: float, celdas: int, semilla: int) -> float:
	var fx := x * celdas
	var fy := y * celdas
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := smoothstep(0.0, 1.0, fx - x0)
	var ty := smoothstep(0.0, 1.0, fy - y0)
	var a := _hash(posmod(x0, celdas), posmod(y0, celdas), semilla)
	var b := _hash(posmod(x0 + 1, celdas), posmod(y0, celdas), semilla)
	var c := _hash(posmod(x0, celdas), posmod(y0 + 1, celdas), semilla)
	var d := _hash(posmod(x0 + 1, celdas), posmod(y0 + 1, celdas), semilla)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _nueva() -> Image:
	return Image.create(PX, PX, false, Image.FORMAT_RGB8)


# ---------------------------------------------------------------- Dibujos

## Tablas de madera: 5 filas, uniones escalonadas, cada tabla con su tono y una veta suave.
static func _tablas(c1: Color, c2: Color) -> Image:
	var img := _nueva()
	var filas := 5
	var alto := PX / filas
	var junta := maxi(roundi(2 * _k), 1)
	for y in PX:
		var fila := y / alto
		var corte := int(_hash(fila, 0, 7) * PX)
		for x in PX:
			var tabla := 0 if posmod(x - corte, PX) < PX / 2 else 1
			var tono := _hash(fila, tabla, 3)
			var c := c1.lerp(c2, tono)
			var veta := sin((float(x) / PX * 6.0 + _ruido(float(x) / PX, float(y) / PX, 4, fila) * 2.5) * TAU) * 0.5 + 0.5
			c = c.darkened(veta * 0.07 + _ruido(float(x) / PX, float(y) / PX, 16, 11) * 0.05)
			if y % alto < junta or posmod(x - corte, PX / 2) < junta:
				c = c.darkened(0.35)   # Junta entre tablas
			img.set_pixel(x, y, c)
	return img


## Damero de baldosas de 2 x 2 (cada una 0,8 m) con junta clara.
static func _damero(c1: Color, c2: Color) -> Image:
	var img := _nueva()
	var mitad := PX / 2
	var junta := maxi(roundi(3 * _k), 1)
	for y in PX:
		for x in PX:
			var c := c1 if ((x < mitad) == (y < mitad)) else c2
			c = c.darkened(_ruido(float(x) / PX, float(y) / PX, 8, 5) * 0.06)
			if x % mitad < junta or y % mitad < junta:
				c = c1.lerp(Color.WHITE, 0.5)
			img.set_pixel(x, y, c)
	return img


## Losas cuadradas (n x n) con junta y una mancha suave: porcelanato o azulejo.
static func _losas(c: Color, junta: Color, n: int, grosor_junta: float, manchas: float) -> Image:
	var img := _nueva()
	var lado := PX / n
	var jpx := maxi(int(grosor_junta * PX), maxi(roundi(2 * _k), 1))
	for y in PX:
		for x in PX:
			var i := x / lado
			var j := y / lado
			var col := c.darkened(_hash(i, j, 9) * manchas)
			col = col.lightened(_ruido(float(x) / PX, float(y) / PX, 6, 21) * manchas)
			# Brillo de esquina (se ve como un esmalte)
			if x % lado > lado - jpx * 3 and y % lado < jpx * 3:
				col = col.lightened(0.06)
			if x % lado < jpx or y % lado < jpx:
				col = junta
			img.set_pixel(x, y, col)
	return img


## Revoque pintado: el color con manchas muy suaves.
static func _revoque(c: Color) -> Image:
	var img := _nueva()
	for y in PX:
		for x in PX:
			var r := _ruido(float(x) / PX, float(y) / PX, 8, 31) * 0.6 + _ruido(float(x) / PX, float(y) / PX, 32, 37) * 0.4
			img.set_pixel(x, y, c.darkened(r * 0.07).lightened(0.02))
	return img


## Empapelado: rayas verticales de dos tonos con una florcita cada tanto.
static func _empapelado(c: Color) -> Image:
	var img := _nueva()
	var raya := PX / 8
	var flor := c.darkened(0.22).lerp(Color("c06a6a"), 0.35)
	for y in PX:
		for x in PX:
			var col := c if (x / raya) % 2 == 0 else c.darkened(0.06)
			col = col.darkened(_ruido(float(x) / PX, float(y) / PX, 8, 41) * 0.03)
			# Florcita en el medio de las rayas claras, alternando la altura
			var cx := (x / raya) * raya + raya / 2
			var cy := (y / (PX / 4)) * (PX / 4) + PX / 8 + ((x / raya) % 4 / 2) * (PX / 8)
			if (x / raya) % 2 == 0 and Vector2(x - cx, posmod(y - cy, PX / 4)).length() < 4.0 * _k:
				col = flor
			if (x / raya) % 2 == 1 and x % raya == 0:
				col = c.darkened(0.12)
			img.set_pixel(x, y, col)
	return img


## Ladrillos a la vista: hiladas trabadas con junta clara y cada ladrillo con su tono.
static func _ladrillo(c: Color) -> Image:
	var img := _nueva()
	var hiladas := 12
	var largo := PX / 4
	var grosor := maxi(roundi(3 * _k), 1)
	var junta := c.lightened(0.45).lerp(Color("d9d0c4"), 0.6)
	for y in PX:
		var fila := y * hiladas / PX
		var desde_junta := y - (fila * PX + hiladas - 1) / hiladas   # Píxeles desde que empezó la hilada
		var corrido := (largo / 2) if fila % 2 == 1 else 0
		for x in PX:
			var xx := posmod(x + corrido, PX)
			var n := xx / largo
			var col := c.darkened(_hash(n, fila, 13) * 0.18).lightened(_hash(fila, n, 17) * 0.08)
			col = col.darkened(_ruido(float(x) / PX, float(y) / PX, 32, 19) * 0.08)
			if desde_junta < grosor or xx % largo < grosor:
				col = junta
			img.set_pixel(x, y, col)
	return img
