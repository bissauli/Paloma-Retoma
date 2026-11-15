extends RefCounted
## Genera modelos/paloma/paloma_zonas.png: una máscara de 128x128 (un canal) con el índice de zona de
## cada píxel de la textura de la paloma: 0 = sin zona (ojo, detalles), 1 cuerpo, 2 alas, 3 cabeza/cuello,
## 4 cola, 5 pico, 6 patas. La zona sale del hueso que domina cada triángulo (en el espacio UV);
## el pico es la cajita que sobresale al frente de la cabeza (por geometría). Se corre una vez: load("res://tools/generar_mascara_paloma.gd").new().generar()

const GLB := "res://modelos/paloma/Paloma.glb"
const SALIDA := "res://modelos/paloma/paloma_zonas.png"
const PREVIA := "res://tools/_previa_mascara.png"
const TAM := 128
const ZONA_DE_HUESO := {"root": 1, "body": 1, "head": 3, "tail": 4, "wing_L": 2, "wing_R": 2, "leg_L": 6, "leg_R": 6}
const COLORES_ZONA := [Color.BLACK, Color("e6194b"), Color("3cb44b"), Color("4363d8"), Color("f58231"), Color("ffe119"), Color("911eb4")]


func generar() -> void:
	var raiz: Node = (load(GLB) as PackedScene).instantiate()
	var mi := raiz.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var textura := (mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture.get_image()
	textura.decompress()
	var arr := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var huesos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := huesos.size() / pos.size()
	if idx.is_empty():
		idx = PackedInt32Array(range(pos.size()))

	var mapa := Image.create(TAM, TAM, false, Image.FORMAT_L8)
	var cubierto := PackedByteArray()
	cubierto.resize(TAM * TAM)
	for t in range(0, idx.size(), 3):
		# Zona del triángulo: el hueso con más peso sumando sus 3 vértices
		var suma := {}
		for k in 3:
			var v := idx[t + k]
			for j in per:
				var w := pesos[v * per + j]
				if w <= 0.0:
					continue
				var nombre := String(mi.skin.get_bind_name(huesos[v * per + j])) if mi.skin.get_bind_name(huesos[v * per + j]) != &"" \
						else String(mi.get_node(mi.skeleton).get_bone_name(huesos[v * per + j]))
				suma[nombre] = suma.get(nombre, 0.0) + w
		var mejor := "body"
		var mejor_w := -1.0
		for n in suma:
			if suma[n] > mejor_w:
				mejor_w = suma[n]
				mejor = n
		var zona: int = ZONA_DE_HUESO.get(mejor, 1)
		# El pico es la cajita que sobresale al frente de la cabeza (z >= 0,2 y angosta en x)
		if zona == 3:
			var chico := true
			for k in 3:
				var p := pos[idx[t + k]]
				if p.z < 0.199 or absf(p.x) > 0.03:
					chico = false
			if chico:
				zona = 5
		_rasterizar(mapa, cubierto, textura, uv[idx[t]] * TAM, uv[idx[t + 1]] * TAM, uv[idx[t + 2]] * TAM, zona)

	# Píxeles de textura con color que ningún triángulo tocó (bordes): toman la zona del vecino
	for _i in 2:
		var copia := mapa.duplicate() as Image
		for y in TAM:
			for x in TAM:
				if cubierto[y * TAM + x] == 0 and textura.get_pixel(x, y).a > 0.0 and textura.get_pixel(x, y).to_html(false) != "000000":
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var p: Vector2i = Vector2i(x, y) + d
						if p.x >= 0 and p.y >= 0 and p.x < TAM and p.y < TAM and mapa.get_pixel(p.x, p.y).r > 0.0:
							copia.set_pixel(x, y, mapa.get_pixel(p.x, p.y))
							break
		mapa = copia
		for y in TAM:
			for x in TAM:
				if mapa.get_pixel(x, y).r > 0.0:
					cubierto[y * TAM + x] = 1

	# El mapa guarda el índice como valor del canal (1/255 por zona)
	var salida := Image.create(TAM, TAM, false, Image.FORMAT_L8)
	var cuenta := {}
	for y in TAM:
		for x in TAM:
			var z := int(round(mapa.get_pixel(x, y).r * 255.0))
			cuenta[z] = cuenta.get(z, 0) + 1
			salida.set_pixel(x, y, Color(z / 255.0, z / 255.0, z / 255.0))
	salida.save_png(ProjectSettings.globalize_path(SALIDA))
	print("Zonas (píxeles): ", cuenta)

	# Vista previa: textura | máscara en colores | máscara sobre textura, ampliado x4
	var previa := Image.create(TAM * 3, TAM, false, Image.FORMAT_RGBA8)
	previa.fill(Color(0.15, 0.15, 0.2))
	for y in TAM:
		for x in TAM:
			var z := int(round(salida.get_pixel(x, y).r * 255.0))
			var c := textura.get_pixel(x, y)
			previa.set_pixel(x, y, c if c.to_html(false) != "000000" else Color(0.15, 0.15, 0.2))
			previa.set_pixel(TAM + x, y, COLORES_ZONA[z] if z < 7 else Color.WHITE)
			previa.set_pixel(TAM * 2 + x, y, c.lerp(COLORES_ZONA[z], 0.6) if z > 0 else previa.get_pixel(x, y))
	previa.resize(TAM * 3 * 4, TAM * 4, Image.INTERPOLATE_NEAREST)
	previa.save_png(ProjectSettings.globalize_path(PREVIA))
	raiz.free()


func _rasterizar(mapa: Image, cubierto: PackedByteArray, textura: Image, a: Vector2, b: Vector2, c: Vector2, zona: int) -> void:
	var minx := maxi(int(floor(minf(a.x, minf(b.x, c.x)))), 0)
	var maxx := mini(int(ceil(maxf(a.x, maxf(b.x, c.x)))), TAM - 1)
	var miny := maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
	var maxy := mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), TAM - 1)
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if not _dentro(Vector2(x + 0.5, y + 0.5), a, b, c):
				continue
			var px := textura.get_pixel(x, y)
			if px.to_html(false) == "000000":
				continue
			mapa.set_pixel(x, y, Color(zona / 255.0, 0, 0))
			cubierto[y * TAM + x] = 1


func _dentro(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2 := (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3 := (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)
	var neg := d1 < -0.001 or d2 < -0.001 or d3 < -0.001
	var pos := d1 > 0.001 or d2 > 0.001 or d3 > 0.001
	return not (neg and pos)
