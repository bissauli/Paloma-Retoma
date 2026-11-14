extends Node3D
## Construye la Plaza de Mayo con primitivas al iniciar.
## Coordenadas: X = este (+) / oeste (-), Z = sur (+) / norte (-). El mapa mide 120 x 80 m.

const ANCHO := 120.0
const LARGO := 80.0

# Paleta
const C_PISO := Color("a8a59d")
const C_JUNTA := Color("85827c")
const C_ASFALTO := Color("4a4a4f")
const C_VEREDA := Color("a39f97")

var sol: DirectionalLight3D
var entorno: Environment


func _ready() -> void:
	_crear_ambiente()
	_crear_piso()
	_crear_limites()
	_crear_zonas()
	GameState.fase_dia_cambio.connect(_al_cambiar_fase)
	_al_cambiar_fase(0.0)
	# Miles de piezas fijas (edificios, árboles, bancos...) pasan a ser unas pocas mallas grandes
	Construir.fusionar_estaticas(self)


# ---------------------------------------------------------------- Luz y cielo

func _crear_ambiente() -> void:
	var cielo_mat := ProceduralSkyMaterial.new()
	cielo_mat.sky_top_color = Color("5fa8e8")
	cielo_mat.sky_horizon_color = Color("bfe0f5")
	cielo_mat.ground_horizon_color = Color("bfe0f5")
	cielo_mat.ground_bottom_color = Color("8a8f96")
	var cielo := Sky.new()
	cielo.sky_material = cielo_mat

	entorno = Environment.new()
	entorno.background_mode = Environment.BG_SKY
	entorno.sky = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.55, 0.6, 0.7)
	entorno.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	entorno.ambient_light_energy = 0.5
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.fog_enabled = true
	entorno.fog_light_color = Color("cfe3f0")
	entorno.fog_density = 0.0035
	entorno.fog_sky_affect = 0.15

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = entorno
	we.add_to_group("entorno")
	add_child(we)
	Ajustes.aplicar_brillo(entorno)  # Opciones > Pantalla > Brillo

	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.shadow_enabled = true
	sol.light_energy = 0.65
	sol.add_to_group("sol")
	add_child(sol)
	# Distancia y calidad de las sombras según el preset gráfico (Opciones > Gráficos)
	Ajustes.aplicar_sombras(sol)


## Ciclo de día: t = 0 mañana, t = 1 atardecer.
func _al_cambiar_fase(t: float) -> void:
	if sol == null:
		return
	# El sol sale por el este (sobre el Río de la Plata) y se pone por el oeste
	var elevacion: float = lerpf(-30.0, -60.0, t * 2.0) if t < 0.5 else lerpf(-60.0, -12.0, (t - 0.5) * 2.0)
	var azimut := lerpf(110.0, 250.0, t)
	sol.rotation_degrees = Vector3(elevacion, azimut, 0.0)
	var color_maniana := Color("fff1d6")
	var color_mediodia := Color("ffffff")
	var color_atardecer := Color("ffa565")
	var c: Color
	if t < 0.5:
		c = color_maniana.lerp(color_mediodia, t * 2.0)
	else:
		c = color_mediodia.lerp(color_atardecer, (t - 0.5) * 2.0)
	sol.light_color = c
	sol.light_energy = lerpf(0.65, 0.5, maxf(t - 0.5, 0.0) * 2.0)
	var cielo_mat := entorno.sky.sky_material as ProceduralSkyMaterial
	var arriba_dia := Color("5fa8e8")
	var arriba_tarde := Color("5a6fb8")
	var horiz_dia := Color("bfe0f5")
	var horiz_tarde := Color("f6b48a")
	var k: float = clampf((t - 0.55) / 0.45, 0.0, 1.0)
	cielo_mat.sky_top_color = arriba_dia.lerp(arriba_tarde, k)
	cielo_mat.sky_horizon_color = horiz_dia.lerp(horiz_tarde, k)
	cielo_mat.ground_horizon_color = cielo_mat.sky_horizon_color
	entorno.fog_light_color = Color("cfe3f0").lerp(Color("f2b892"), k)
	entorno.ambient_light_color = Color(0.55, 0.6, 0.7).lerp(Color(0.62, 0.5, 0.55), k)


# ---------------------------------------------------------------- Piso y límites

func _crear_piso() -> void:
	var piso := Node3D.new()
	piso.name = "Piso"
	add_child(piso)
	# Plaza de baldosas grises
	var baldosas := Construir.material_baldosas(C_PISO, C_JUNTA, Vector2(0.34, 0.34))
	Construir.caja_mat(piso, Vector3(0, -0.5, -4), Vector3(ANCHO + 40, 1.0, LARGO + 32), baldosas)
	# Avenida al sur (asfalto con líneas)
	Construir.caja(piso, Vector3(0, 0.005, 30), Vector3(ANCHO + 40, 0.01, 8), C_ASFALTO, false)
	for i in range(-8, 9):
		Construir.caja(piso, Vector3(i * 9.0, 0.012, 30), Vector3(4.0, 0.01, 0.25), Color("e8e4d0"), false)
	# Vereda del lado de los cafés
	Construir.caja(piso, Vector3(0, 0.08, 37), Vector3(ANCHO + 40, 0.16, 6), C_VEREDA)


## Paredes invisibles alrededor del mapa (y un techo para no irse al espacio).
func _crear_limites() -> void:
	var lim := Node3D.new()
	lim.name = "Limites"
	add_child(lim)
	var alto := 60.0
	Construir.pared_invisible(lim, Vector3(0, alto / 2, -LARGO / 2 - 1), Vector3(ANCHO + 4, alto, 2))
	Construir.pared_invisible(lim, Vector3(0, alto / 2, LARGO / 2 + 1), Vector3(ANCHO + 4, alto, 2))
	Construir.pared_invisible(lim, Vector3(-ANCHO / 2 - 1, alto / 2, 0), Vector3(2, alto, LARGO + 4))
	Construir.pared_invisible(lim, Vector3(ANCHO / 2 + 1, alto / 2, 0), Vector3(2, alto, LARGO + 4))
	Construir.pared_invisible(lim, Vector3(0, 36, 0), Vector3(ANCHO + 4, 2, LARGO + 4))


# ---------------------------------------------------------------- Zonas

## Posición del balcón de la Casa Rosada (la meta). La usan la UI y la victoria.
var posicion_balcon := Vector3.ZERO


func _crear_zonas() -> void:
	var edif := Node3D.new()
	edif.name = "Edificios"
	add_child(edif)
	Edificios.piramide(edif)
	Edificios.cabildo(edif)
	Edificios.catedral(edif)
	Edificios.alrededores(edif)
	Edificios.subte(edif, Vector3(34, 0, -22))
	posicion_balcon = Edificios.casa_rosada(edif)
	var mesas := Edificios.cafes(edif)
	add_child(Transito.new())

	_crear_jardines()
	_crear_nido()
	_crear_balcon_meta()
	_crear_comida(mesas)
	_crear_zonas_palomas()
	_crear_puntos()


## Canteros de pasto, jacarandás, bancos y faroles.
func _crear_jardines() -> void:
	var j := Node3D.new()
	j.name = "Jardines"
	add_child(j)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var centro := Vector3(17.0 * sx, 0.0, 11.0 * sz)
			# Borde de piedra (tapa a 6 cm) y pasto más alto (tapa a 10 cm): nunca a la misma altura,
			# así no hay z-fighting (texturas que parpadean superpuestas)
			Construir.caja(j, centro + Vector3(0, 0.03, 0), Vector3(16.6, 0.06, 9.6), Color("b8b2a6"), false)
			Construir.caja(j, centro + Vector3(0, 0.05, 0), Vector3(16, 0.1, 9), Edificios.C_PASTO, false)
	# Jacarandás en los bordes de los canteros
	var arboles := [
		Vector3(-24, 0, -14), Vector3(-10, 0, -14), Vector3(10, 0, -14), Vector3(24, 0, -14),
		Vector3(-24, 0, 14), Vector3(-10, 0, 14), Vector3(10, 0, 14), Vector3(24, 0, 14),
		Vector3(-30, 0, -4), Vector3(-30, 0, 5), Vector3(30, 0, -5), Vector3(30, 0, 6),
		Vector3(-38, 0, -20), Vector3(-38, 0, 20), Vector3(14, 0, 22), Vector3(-16, 0, 22),
	]
	for i in arboles.size():
		Edificios.jacaranda(j, arboles[i], 0.9 + (i % 3) * 0.12)
	# Bancos: frente a la Catedral (las señoras), en el Cabildo y alrededor de la Pirámide
	var bancos := [
		[Vector3(-7, 0, -18), PI], [Vector3(-3, 0, -18), PI], [Vector3(3, 0, -18), PI], [Vector3(7, 0, -18), PI],
		[Vector3(-36, 0, -8), PI / 2.0], [Vector3(-36, 0, 8), PI / 2.0],
		# Junto a la Pirámide: sobre el pasto de los canteros, mirando hacia el paso central
		[Vector3(-11, 0.1, 7.3), 0.0], [Vector3(11, 0.1, -7.3), PI], [Vector3(28, 0, -20), 0.0],
	]
	for b: Array in bancos:
		Edificios.banco(j, b[0], b[1])
	for p in [Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20),
			Vector3(-33, 0, 14), Vector3(33, 0, 12)]:
		Edificios.farol(j, p)


func _crear_nido() -> void:
	var nido := Node3D.new()
	nido.name = "Nido"
	nido.set_script(load("res://world/nido.gd"))
	add_child(nido)
	nido.position = Vector3(0, 0.6, 0)


## Área de la meta en el balcón: la usa la escena principal para detectar la victoria.
func _crear_balcon_meta() -> void:
	var m := Marker3D.new()
	m.name = "Balcon"
	m.add_to_group("balcon")
	add_child(m)
	m.position = posicion_balcon


func _crear_comida(mesas: Array[Vector3]) -> void:
	var c := Node3D.new()
	c.name = "Comida"
	add_child(c)
	# Medialunas y papas en las mesas de los cafés (y un marcador por mesa para los comensales)
	for i in mesas.size():
		var marca := Marker3D.new()
		marca.add_to_group("mesa_cafe")
		c.add_child(marca)
		marca.position = mesas[i] - Vector3(0, 0.78, 0)
		var com := Comida.new()
		com.tipo = "medialuna" if i % 3 != 2 else "papa"
		com.tiempo_reaparicion = 40.0
		c.add_child(com)
		com.position = mesas[i] + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
	# El carrito de choripán sobre la avenida
	_carrito_choripan(c, Vector3(23, 0.16, 35.2))
	# Facturas cerca del subte (los oficinistas se las olvidan)
	for p in [Vector3(28, 0.5, -20), Vector3(37, 0.02, -15)]:
		var f := Comida.new()
		f.tipo = "factura"
		f.tiempo_reaparicion = 30.0
		c.add_child(f)
		f.position = p
	# Generadores de migas
	_generador(c, "MigasCabildo", Vector3(-38, 0.02, 0), 5.0, 8, 2.0)
	_generador(c, "MigasCatedral", Vector3(0, 0.02, -15), 6.0, 7, 3.0)
	_generador(c, "MigasSubte", Vector3(33, 0.02, -15), 4.0, 4, 5.0)
	_generador(c, "MigasCentro", Vector3(0, 0.02, 8), 8.0, 4, 6.0)


func _generador(padre: Node, nombre: String, pos: Vector3, radio: float, maximo: int, intervalo: float) -> void:
	var g := GeneradorMigas.new()
	g.name = nombre
	g.radio = radio
	g.maximo = maximo
	g.intervalo = intervalo
	padre.add_child(g)
	g.position = pos


func _carrito_choripan(padre: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "CarritoChori"
	padre.add_child(n)
	n.position = pos
	Construir.caja(n, Vector3(0, 0.6, 0), Vector3(2.2, 1.0, 1.1), Color("c9c9c4"))
	Construir.caja(n, Vector3(0, 1.12, 0), Vector3(2.0, 0.04, 0.9), Color("2a2a2a"))
	for x in [-0.8, 0.8]:
		Construir.cilindro(n, Vector3(x, 0.2, 0.56), 0.2, 0.08, Color("1f1f1f"), false, 10)
	# Un Label3D se lee de frente desde +Z: el de la cara norte (-Z, la que da a la plaza) va girado
	# 180° y el de la cara sur no. Si no, los dos miran hacia adentro del carrito y se ven en espejo.
	var cartel := Construir.cartel(n, Vector3(0, 0.6, -0.57), "El Chori Feliz", Color("ffe08a"), 30)
	cartel.rotation.y = PI
	Construir.cartel(n, Vector3(0, 0.6, 0.57), "El Chori Feliz", Color("ffe08a"), 30)
	var chori := Comida.new()
	chori.tipo = "choripan"
	chori.tiempo_reaparicion = 60.0
	n.add_child(chori)
	chori.position = Vector3(0, 1.14, 0)


## Zonas donde viven palomas sueltas para reclutar.
func _crear_zonas_palomas() -> void:
	var zonas := [
		["Cabildo", Vector3(-36, 0, 0), 6.0, 5],
		["Catedral", Vector3(0, 0, -14), 9.0, 14],
		["Centro", Vector3(0, 0, 9), 8.0, 8],
		["Cafes", Vector3(0, 0, 23), 12.0, 8],
		["Subte", Vector3(30, 0, -14), 6.0, 8],
		["Jardines", Vector3(-17, 0, 11), 6.0, 5],
	]
	for z: Array in zonas:
		var m := Marker3D.new()
		m.name = "ZonaPalomas" + str(z[0])
		m.add_to_group("zona_palomas")
		m.set_meta("radio", z[2])
		m.set_meta("cantidad", z[3])
		add_child(m)
		m.position = z[1]


## Puntos de referencia para enemigos y humanos (los usa la escena principal).
func _crear_puntos() -> void:
	var puntos := {
		"PuntoTuristas": Vector3(-39, 0, -9),
		"PuntoEscolares": Vector3(-34, 0, 12),
		"PuntoSenoras": Vector3(0, 0, -18),
		"PuntoCafes": Vector3(0, 0.16, 35.7),   # Entre las mesas y las vidrieras
		"PuntoSubte": Vector3(34, 0, -22),
		"PuntoGranaderos": Vector3(40.5, 0, 0),
	}
	for nombre: String in puntos:
		var m := Marker3D.new()
		m.name = nombre
		m.add_to_group("punto_" + nombre.trim_prefix("Punto").to_lower())
		add_child(m)
		m.position = puntos[nombre]
