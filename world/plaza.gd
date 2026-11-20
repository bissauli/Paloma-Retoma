extends Node3D
## Construye la Plaza de Mayo con primitivas al iniciar, y la ciudad que la rodea (world/ciudad.gd).
## Coordenadas: X = este (+) / oeste (-), Z = sur (+) / norte (-). La plaza mide 120 x 80 m y la
## ciudad entera unos 394 x 222 m (ver Ciudad.X_MIN...).

const ANCHO := 120.0
const LARGO := 80.0

# Paleta
const C_ASFALTO := Color("76787a")

var sol: DirectionalLight3D
var entorno: Environment
var cielo: Cielo


func _ready() -> void:
	MapaOverrides.reiniciar()   # IDs de las piezas editables (ver MapaOverrides)
	_crear_ambiente()
	_crear_piso()
	_crear_limites()
	_crear_zonas()
	# Miles de piezas fijas (edificios, árboles, bancos...) pasan a ser unas pocas mallas grandes
	Construir.fusionar_estaticas(self)


# ---------------------------------------------------------------- Luz y cielo

## El cielo, el sol (y la luna), el día y la noche y el clima los arma world/cielo.gd.
func _crear_ambiente() -> void:
	cielo = Cielo.new()
	cielo.name = "Cielo"
	add_child(cielo)
	sol = cielo.sol
	entorno = cielo.entorno
	# Mapa V4.5: la ciudad que sigue detrás de la pared invisible, en capas con paralaje
	add_child(Horizonte.new())


# ---------------------------------------------------------------- Piso y límites

func _crear_piso() -> void:
	var piso := Node3D.new()
	piso.name = "Piso"
	add_child(piso)
	# Plaza de baldosas grises: sólo su manzana (alrededor están las calles y veredas de la ciudad,
	# ver world/ciudad.gd)
	var baldosas := Construir.material_lajas("lajas_plaza", 5.0)
	# Con el hueco de la escalera del subte (las lajas van en coordenadas del mundo: no se notan los cortes)
	for r: Rect2 in Edificios.partir(Ciudad.PLAZA, Edificios.hueco_subte(true)):
		Construir.caja_mat(piso, Vector3(r.get_center().x, -0.5, r.get_center().y), Vector3(r.size.x, 1.0, r.size.y), baldosas)
	# La tira de piso donde sale la rampa de la escalera: sólo se ve
	var h := Edificios.hueco_subte()
	var tira := Rect2(h.position.x, h.end.y, h.size.x, Edificios.hueco_subte(true).end.y - h.end.y)
	Construir.caja_mat(piso, Vector3(tira.get_center().x, -0.5, tira.get_center().y), Vector3(tira.size.x, 1.0, tira.size.y),
		baldosas, false)
	var r := Ciudad.PLAZA
	# Avenida al sur (asfalto con líneas): cruza la manzana y llega hasta Bolívar y Paseo Colón
	Construir.caja(piso, Vector3(0, 0.005, 30), Vector3(128, 0.01, 8), C_ASFALTO, false)
	for i in range(-6, 7):
		Construir.caja(piso, Vector3(i * 9.0, 0.012, 30), Vector3(4.0, 0.01, 0.25), Color("f4f3ee"), false)
	# Vereda del lado de los cafés (las mismas lajas que el resto de las veredas)
	Construir.caja_mat(piso, Vector3(0, 0.08, 37), Vector3(r.size.x, 0.16, 6), Construir.material_lajas("lajas_vereda", 4.0))


## Paredes invisibles en el borde de la ciudad (y un techo para no irse al espacio).
func _crear_limites() -> void:
	var lim := Node3D.new()
	lim.name = "Limites"
	add_child(lim)
	var alto := 90.0
	var x0 := Ciudad.X_MIN
	var x1 := Ciudad.X_MAX
	var z0 := Ciudad.Z_MIN
	var z1 := Ciudad.Z_MAX
	var ancho := x1 - x0
	var largo := z1 - z0
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	Construir.pared_invisible(lim, Vector3(cx, alto / 2, z0 - 1), Vector3(ancho + 4, alto, 2))
	Construir.pared_invisible(lim, Vector3(cx, alto / 2, z1 + 1), Vector3(ancho + 4, alto, 2))
	Construir.pared_invisible(lim, Vector3(x0 - 1, alto / 2, cz), Vector3(2, alto, largo + 4))
	Construir.pared_invisible(lim, Vector3(x1 + 1, alto / 2, cz), Vector3(2, alto, largo + 4))
	# El techo queda por encima de las azoteas más altas, así se puede aterrizar en todas
	Construir.pared_invisible(lim, Vector3(cx, Ciudad.TECHO + 1.0, cz), Vector3(ancho + 4, 2, largo + 4))


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
	Edificios.subte(edif, Edificios.SUBTE)
	posicion_balcon = Edificios.casa_rosada(edif)
	var mesas := Edificios.cafes(edif)
	# Nivel inferior (Fase 1): pasajes entre los cafés, galería del Cabildo y mercado
	NivelInferior.armar(self)
	# La ciudad alrededor de la plaza (mapa V2): arma y fusiona sus propias piezas
	add_child(Ciudad.new())
	# Nivel medio (Fase 2): toldos de los cafés, balcones alrededor, columnas de farol y árboles altos
	# (después de la ciudad: al armarse, la ciudad pone en cero las cuentas que miran las pruebas)
	NivelMedio.plaza(self)
	add_child(Transito.new())

	_crear_jardines()
	_crear_fuentes()
	_crear_nido()
	_crear_balcon_meta()
	_crear_comida(mesas)
	_crear_parrilla()
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
	# Bancos: frente a la Catedral (las señoras), en el Cabildo (el de Doña Rosa, al norte) y
	# alrededor de la Pirámide. En el del medio del Cabildo arranca el juego: la paloma está sentada
	# mirando a la plaza (el respaldo queda del lado del Cabildo; la posición está en main.tscn).
	var bancos := [
		[Vector3(-7, 0, -18), PI], [Vector3(-3, 0, -18), PI], [Vector3(3, 0, -18), PI], [Vector3(7, 0, -18), PI],
		[Vector3(-36, 0, -8), PI / 2.0], [Vector3(-36, 0, 8), PI / 2.0], [Vector3(-36, 0, 3), -PI / 2.0],
		# Junto a la Pirámide: sobre el pasto de los canteros, mirando hacia el paso central
		[Vector3(-11, 0.1, 7.3), 0.0], [Vector3(11, 0.1, -7.3), PI], [Vector3(28, 0, -20), 0.0],
	]
	for b: Array in bancos:
		Edificios.banco(j, b[0], b[1])
	for p in [Vector3(-20, 0, -20), Vector3(20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20),
			Vector3(-33, 0, 14), Vector3(33, 0, 12)]:
		Edificios.farol(j, p)


## Dos fuentes sobre el eje de la plaza (a cada lado de la Pirámide, entre los canteros) y charcos en
## las baldosas: lugares donde la paloma se puede dar un baño de agua (ver Fuente).
func _crear_fuentes() -> void:
	var f := Node3D.new()
	f.name = "Fuentes"
	add_child(f)
	Fuente.crear(f, Vector3(-19, 0, 0), 2.1, 0.3, true)
	Fuente.crear(f, Vector3(19, 0, 0), 2.1, 0.3, true)
	for c: Array in [[Vector3(11.5, 0, 19.5), 1.3], [Vector3(-10, 0, 19), 1.5],
			[Vector3(27, 0, 2.5), 1.2], [Vector3(-27.5, 0, -2.0), 1.3]]:
		Fuente.crear(f, c[0], c[1])


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
	# La flecha amarilla sobre el balcón cuando ya hay 30 palomas (ver GuiaBalcon)
	var guia := GuiaBalcon.new()
	guia.destino = m
	add_child(guia)


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
		# ...y una tacita, un vaso, un florero o una azucarera, para tirar de un aletazo (ver Golpeable)
		var objeto: String = ["taza", "vaso", "florero", "azucarera"][i % 4]
		var lado := 1.0 if i % 2 == 0 else -1.0
		Golpeable.crear(c, objeto, mesas[i] + Vector3(0.27 * lado, 0.0, 0.14 * lado), Color.WHITE, 1.5)
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
	# Las de Doña Rosa caen delante de su banco (ella tira además, ver enemies/gente.gd)
	_generador(c, "MigasDonaRosa", Vector3(-38.2, 0.02, -8), 1.6, 6, 4.0)
	_generador(c, "MigasCatedral", Vector3(0, 0.02, -15), 6.0, 7, 3.0)
	_generador(c, "MigasSubte", Vector3(33, 0.02, -15), 4.0, 4, 5.0)
	_generador(c, "MigasCentro", Vector3(0, 0.02, 8), 8.0, 4, 6.0)


## La parrilla cerca del Obelisco (a unos 10 m, al noreste): carbón encendido, humito y un buen pedazo de
## asado. Tío Ruffus lo pide (misión "asado_ruffus"); el asado sólo se levanta con la misión aceptada.
func _crear_parrilla() -> void:
	var n := Node3D.new()
	n.name = "Parrilla"
	n.add_to_group("parrilla")
	add_child(n)
	n.position = Vector3(7.5, 0.0, -7.5)
	n.rotation.y = -0.35
	# Patas, cajón de hierro con brasas, grilla y cartel
	for x in [-0.8, 0.8]:
		for z in [-0.3, 0.3]:
			Construir.cilindro(n, Vector3(x, 0.3, z), 0.04, 0.6, Color("2a2a2e"), false, 6)
	Construir.caja(n, Vector3(0, 0.66, 0), Vector3(1.9, 0.28, 0.8), Color("3a3430"))
	Construir.caja(n, Vector3(0, 0.81, 0), Vector3(1.74, 0.04, 0.64), Color("ff6a2a"), false)
	Construir.caja(n, Vector3(0, 0.88, 0), Vector3(1.8, 0.025, 0.66), Color("1c1c20"), false)
	for i in 9:
		Construir.caja(n, Vector3(-0.8 + i * 0.2, 0.9, 0), Vector3(0.025, 0.025, 0.66), Color("1c1c20"), false)
	# La leña de abajo y el cartel (un tablero sobre dos postes, con texto de los dos lados)
	Construir.caja(n, Vector3(1.15, 0.2, 0), Vector3(0.5, 0.4, 0.6), Color("8a5a36"), false)
	Construir.caja(n, Vector3(-0.85, 1.1, 0), Vector3(0.05, 0.9, 0.05), Color("2a2a2e"), false)
	Construir.caja(n, Vector3(0.85, 1.1, 0), Vector3(0.05, 0.9, 0.05), Color("2a2a2e"), false)
	Construir.caja(n, Vector3(0, 1.45, 0), Vector3(1.8, 0.38, 0.05), Color("3a2a22"), false)
	Construir.cartel(n, Vector3(0, 1.45, 0.035), "Parrilla El Obelisco", Color("ffe08a"), 34)
	Construir.cartel(n, Vector3(0, 1.45, -0.035), "Parrilla El Obelisco", Color("ffe08a"), 34).rotation.y = PI
	# El asado sobre la grilla (reaparece solo si se lo llevan)
	var asado := Comida.new()
	asado.tipo = "asado"
	asado.tiempo_reaparicion = 20.0
	n.add_child(asado)
	asado.position = Vector3(0.1, 0.92, 0)
	# Humo que sube de las brasas
	var humo := CPUParticles3D.new()
	humo.amount = 14
	humo.lifetime = 2.6
	humo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	humo.emission_box_extents = Vector3(0.8, 0.02, 0.28)
	humo.direction = Vector3.UP
	humo.spread = 14.0
	humo.gravity = Vector3(0.18, 0.35, 0.0)
	humo.initial_velocity_min = 0.35
	humo.initial_velocity_max = 0.7
	humo.scale_amount_min = 0.7
	humo.scale_amount_max = 1.6
	var esfera := SphereMesh.new()
	esfera.radius = 0.09
	esfera.height = 0.18
	esfera.radial_segments = 6
	esfera.rings = 3
	humo.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.82, 0.84, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	humo.material_override = mat
	humo.position = Vector3(0, 0.95, 0)
	humo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(humo)


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
		["Cabildo", Vector3(-38, 0, 0), 5.0, 3],
		["DonaRosa", Vector3(-38.4, 0, -8), 2.2, 6],   # Las que come de la mano de Doña Rosa
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
		"PuntoTuristas": Vector3(-40, 0, -14),
		"PuntoDonaRosa": Vector3(-35.95, 0, -8),   # Sentada en el banco del Cabildo, mirando al oeste
		"PuntoEscolares": Vector3(-34, 0, 12),
		"PuntoSenoras": Vector3(0, 0, -18),
		"PuntoCafes": Vector3(0, 0.16, 35.7),   # Entre las mesas y las vidrieras
		"PuntoSubte": Edificios.SUBTE,
		"PuntoGranaderos": Vector3(40.5, 0, 0),
		"PuntoCatedral": Vector3(0, 0, -14),      # Marca la brújula
		"PuntoChoripan": Vector3(23, 0.16, 35.2),   # El carrito (ver _carrito_choripan)
	}
	for nombre: String in puntos:
		var m := Marker3D.new()
		m.name = nombre
		m.add_to_group("punto_" + nombre.trim_prefix("Punto").to_lower())
		add_child(m)
		m.position = puntos[nombre]
