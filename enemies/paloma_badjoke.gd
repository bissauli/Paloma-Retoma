class_name PalomaBadJoke
extends Node3D
## Una paloma de la banda de los BadJokes, la pandilla del barrio enemigo (mapa V4.5). Aparecen en los
## puntos de la guarida (Marker3D del grupo "spawn_badjokes", ver Barrio.guarida) según su rol:
## - "jefe": Don Remate, sentado en su sillón dorado de la terraza (sombrero de ala y cadena de oro).
## - "guardia": en el portón, con gorra para atrás y el bate, o pasamontañas y la bolsa de plata.
## - "vigia": en la cumbrera del galpón, mirando el barrio (gorro de lana y cadena).
## - "patrulla": camina de acá para allá cerca de su punto (sombrero de ala y riñonera).
## Por ahora no pelean: miran a la jugadora cuando se acerca, sacan pecho y arrullan. Están en el grupo
## "banda_badjokes" para que las misiones las encuentren (rol, nombre y punto en metas y variables).
## Los accesorios se arman con primitivas en el espacio del GLB de la paloma (como AccesoriosPaloma) y
## siguen a los huesos de la cabeza y del cuerpo.

const ROLES := {
	"jefe": {"nombres": ["Don Remate"], "variante": "Oscura", "cabeza": "fedora", "cuerpo": ["cadena"]},
	"guardia": {"nombres": ["Bardo", "Capucha"], "variante": "Gris", "cabeza": "", "cuerpo": []},
	"vigia": {"nombres": ["Chamuyo", "Ojota"], "variante": "Oscura", "cabeza": "gorro", "cuerpo": ["cadena"]},
	"patrulla": {"nombres": ["El Chiste", "Fiaca", "Tururú", "Pelusa"], "variante": "Manchada", "cabeza": "fedora",
		"cuerpo": ["rinonera"]},
}
## Los dos guardias: uno con gorra y bate, el otro encapuchado con la bolsa de plata.
const GUARDIAS := [{"cabeza": "gorra", "cuerpo": ["bate"]}, {"cabeza": "pasamontanas", "cuerpo": ["bolsa"]}]

const NEGRO := Color("1d1d24")
const GRAFITO := Color("3a3a46")
const ORO := Color("f2c84b")
const MADERA := Color("b07a48")
const VERDE := Color("2f5a3a")
const ARENA := Color("c9a46a")
const DISTANCIA_MIRAR := 9.0
const RADIO_PATRULLA := 4.0
const VELOCIDAD := 0.9

var rol := "guardia"
var nombre := ""
var punto: Marker3D
var modelo: ModeloPaloma

var _giro_base := 0.0
var _destino := Vector3.ZERO
var _espera := 0.0
var _t_arrullo := 0.0
var _caminando := false
var _cartel: Label3D

static var _k_nombres := {}


## Pone una paloma de la banda en cada punto de aparición que haya debajo de "raiz". Devuelve cuántas.
static func poblar(raiz: Node) -> int:
	_k_nombres.clear()
	var k_guardia := 0
	var cuantas := 0
	for m: Node in raiz.get_tree().get_nodes_in_group("spawn_badjokes") if raiz.is_inside_tree() else raiz.find_children("SpawnBadJokes*", "Marker3D", true, false):
		var marca := m as Marker3D
		if marca == null or not raiz.is_ancestor_of(marca):
			continue
		var p := PalomaBadJoke.new()
		p.rol = String(marca.get_meta("rol", "guardia"))
		p.punto = marca
		var datos: Dictionary = ROLES.get(p.rol, ROLES["guardia"])
		var nombres: Array = datos["nombres"]
		var k := int(_k_nombres.get(p.rol, 0))
		_k_nombres[p.rol] = k + 1
		p.nombre = nombres[k % nombres.size()]
		if p.rol == "guardia":
			p.set_meta("look", GUARDIAS[k_guardia % GUARDIAS.size()])
			k_guardia += 1
		raiz.add_child(p)
		Construir.poner_global(p, Construir.global_de(marca))   # (se arma fuera del árbol, ver Arranque)
		cuantas += 1
	return cuantas


func _ready() -> void:
	# Una copia que sólo se muestra en la tarjeta de presentación (ver PresentacionPersonaje): es sólo el
	# modelo vestido, sin grupo, sin cartel, sin interlocutor y sin moverse
	var solo_modelo: bool = get_meta("presentacion", false)
	if solo_modelo:
		_armar_solo_modelo()
		return
	add_to_group("banda_badjokes")
	set_meta("rol", rol)
	set_meta("nombre", nombre)
	_giro_base = rotation.y
	_destino = position if rol == "patrulla" else Vector3(0, _giro_base, 0)
	var datos: Dictionary = ROLES.get(rol, ROLES["guardia"])
	var look: Dictionary = get_meta("look", {})
	modelo = ModeloPaloma.new()
	modelo.name = "Modelo"
	modelo.variante = datos["variante"]
	add_child(modelo)
	# La banda es un poco más grandota que las palomas de la plaza
	modelo.scale = Vector3.ONE * (1.25 if rol == "jefe" else 1.12)
	_vestir(String(look.get("cabeza", datos["cabeza"])), look.get("cuerpo", datos["cuerpo"]))
	# El nombre arriba de la cabeza (sólo de cerca)
	_cartel = Label3D.new()
	_cartel.text = nombre
	_cartel.font_size = 40
	_cartel.pixel_size = 0.006
	_cartel.outline_size = 10
	_cartel.modulate = Color("ffd84a") if rol == "jefe" else Color("ff8fb8")
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel.no_depth_test = false
	_cartel.position = Vector3(0, 0.95 if rol == "jefe" else 0.85, 0)
	_cartel.visibility_range_end = 14.0
	add_child(_cartel)
	_espera = randf_range(1.0, 4.0)
	if rol == "jefe":
		Interlocutor.marcar(self, "don_remate", 1.5, 3.2)   # Con el jefe se puede hablar (la primera vez, con presentación)


## El modelo vestido de su rol, sin nada más (para la presentación del personaje).
func _armar_solo_modelo() -> void:
	set_process(false)
	var datos: Dictionary = ROLES.get(rol, ROLES["guardia"])
	modelo = ModeloPaloma.new()
	modelo.name = "Modelo"
	modelo.variante = datos["variante"]
	add_child(modelo)
	modelo.scale = Vector3.ONE * (1.25 if rol == "jefe" else 1.12)
	_vestir(String(datos["cabeza"]), datos["cuerpo"])


## Hinchada del partido de fútbol (world/partido_futbol.gd): va volando a su lugar de la tribuna, alienta
## mirando la cancha y, cuando termina, vuelve a su puesto.
var _hincha := Vector3.INF         ## Su lugar en la cancha (INF = no está alentando)
var _mira_a := Vector3.ZERO
var _euforia := 1.0
var _volviendo := false
var _origen_hincha := Vector3.ZERO
var _t_salto := randf() * 10.0


func hinchar(lugar: Vector3, mirar: Vector3) -> void:
	if _hincha == Vector3.INF and not _volviendo:
		_origen_hincha = global_position
	_hincha = lugar
	_mira_a = mirar
	_volviendo = false


func volver_a_puesto() -> void:
	if _hincha != Vector3.INF:
		_hincha = Vector3.INF
		_volviendo = true


func festejar_gol(si: bool) -> void:
	_euforia = 2.0 if si else 1.0


func _paso_hincha(delta: float) -> void:
	var destino := _hincha if _hincha != Vector3.INF else _origen_hincha
	var d := destino - global_position
	var plano := Vector3(d.x, 0.0, d.z)
	var dist := plano.length()
	var vuela := dist > 1.5
	if dist > 0.08:
		global_position += plano / dist * minf(7.0 * delta, dist)
		_girar_hacia(atan2(plano.x, plano.z), delta * 8.0)
	global_position.y = lerpf(global_position.y, destino.y + (1.2 if vuela else 0.0), minf(8.0 * delta, 1.0))
	if dist <= 0.08 and _volviendo:
		_volviendo = false
		global_position = _origen_hincha
		rotation.y = _giro_base
		return
	if dist <= 0.08 and _hincha != Vector3.INF:
		# En su lugar: saltitos y arrullos mirando la cancha
		_t_salto += delta * 4.0 * (1.0 if _euforia <= 1.0 else 1.5)
		var a := _mira_a - global_position
		_girar_hacia(atan2(a.x, a.z), delta * 6.0)
		global_position.y = destino.y + absf(sin(_t_salto)) * 0.2 * _euforia
		_t_arrullo -= delta
		if _t_arrullo <= 0.0:
			_t_arrullo = randf_range(1.5, 3.5)
			modelo.arrullar()
	modelo.animar(delta, 1 if vuela else 0, 0.0 if (vuela or dist <= 0.08) else VELOCIDAD * 3.0)


func _process(delta: float) -> void:
	if _hincha != Vector3.INF or _volviendo:
		_paso_hincha(delta)
		return
	var jugadora := _jugadora()
	var cerca := jugadora != null and jugadora.global_position.distance_to(global_position) < DISTANCIA_MIRAR
	if cerca:
		# Mira a la jugadora y, de vez en cuando, arrulla para hacerse el malo
		_caminando = false
		var a := jugadora.global_position - global_position
		_girar_hacia(atan2(a.x, a.z), delta * 5.0)
		_t_arrullo -= delta
		if _t_arrullo <= 0.0:
			_t_arrullo = randf_range(2.5, 4.5)
			if rol == "patrulla" and randf() < 0.3:
				modelo.picotear()
			else:
				modelo.arrullar()
	elif rol == "patrulla":
		_patrullar(delta)
	else:
		_caminando = false
		_espera -= delta
		if _espera <= 0.0:
			# Mira para un lado y para el otro desde su puesto
			_espera = randf_range(2.0, 5.0)
			_destino = Vector3(0, _giro_base + randf_range(-0.9, 0.9), 0)
		_girar_hacia(_destino.y, delta * 2.0)
	modelo.animar(delta, 0, VELOCIDAD if _caminando else 0.0)


func _patrullar(delta: float) -> void:
	var a := _destino - position
	a.y = 0.0
	if a.length() < 0.2:
		_caminando = false
		_espera -= delta
		if _espera <= 0.0:
			_espera = randf_range(1.5, 4.0)
			var centro := punto.global_position if is_instance_valid(punto) else position
			var ang := randf() * TAU
			_destino = centro + Vector3(cos(ang), 0, sin(ang)) * randf_range(1.0, RADIO_PATRULLA)
			_destino.y = position.y
		return
	_caminando = true
	_girar_hacia(atan2(a.x, a.z), delta * 6.0)
	position += a.normalized() * minf(VELOCIDAD * delta, a.length())


func _girar_hacia(giro: float, peso: float) -> void:
	rotation.y = lerp_angle(rotation.y, giro, clampf(peso, 0.0, 1.0))


func _jugadora() -> Node3D:
	var j := get_tree().get_first_node_in_group("jugador") as Node3D
	return j


# ---------------------------------------------------------------- Ropa de la banda

## Cuelga los accesorios: "cabeza" (fedora, gorra, gorro, pasamontanas) del hueso de la cabeza y los del
## cuerpo (cadena, bolsa, bate, rinonera) del hueso del cuerpo.
func _vestir(cabeza: String, cuerpo: Array) -> void:
	var en_cabeza := _adjunto("head")
	var en_cuerpo := _adjunto("body")
	if en_cabeza:
		match cabeza:
			"fedora": _fedora(en_cabeza)
			"gorra": _gorra(en_cabeza)
			"gorro": _gorro(en_cabeza)
			"pasamontanas": _pasamontanas(en_cabeza)
	if en_cuerpo:
		for pieza: String in cuerpo:
			match pieza:
				"cadena": _cadena(en_cuerpo)
				"bolsa": _bolsa(en_cuerpo)
				"bate": _bate(en_cuerpo)
				"rinonera": _rinonera(en_cuerpo)
	# Una llamada de dibujo por color en vez de una por pieza
	for e in [en_cabeza, en_cuerpo]:
		if e:
			AccesoriosPaloma.fusionar(e)


## Nodo que sigue al hueso "hueso" y cuyos hijos van en el espacio del GLB de la paloma.
func _adjunto(hueso: String) -> Node3D:
	var skel := modelo._skel
	var id := skel.find_bone(hueso)
	if id < 0:
		return null
	var adj := BoneAttachment3D.new()
	adj.name = "Banda_" + hueso
	adj.bone_name = hueso
	skel.add_child(adj)
	var espacio := Node3D.new()
	adj.add_child(espacio)
	var skel_en_glb := modelo._relativo(modelo._glb, skel)
	espacio.transform = skel.get_bone_global_rest(id).affine_inverse() * skel_en_glb.affine_inverse()
	return espacio


func _fedora(r: Node3D) -> void:
	_cil(r, 0.16, 0.16, 0.014, Vector3(0.0, 0.505, 0.09), NEGRO)          # Ala
	_cil(r, 0.085, 0.1, 0.11, Vector3(0.0, 0.565, 0.09), GRAFITO)         # Copa
	_cil(r, 0.102, 0.102, 0.03, Vector3(0.0, 0.527, 0.09), NEGRO)         # Cinta
	_caja(r, Vector3(0.12, 0.012, 0.03), Vector3(0.0, 0.622, 0.09), NEGRO) # Hundido de la copa


func _gorra(r: Node3D) -> void:
	# Gorra para atrás: la visera apunta a la cola
	_caja(r, Vector3(0.215, 0.055, 0.215), Vector3(0.0, 0.525, 0.1), NEGRO)
	_caja(r, Vector3(0.17, 0.014, 0.1), Vector3(0.0, 0.512, -0.055), NEGRO)
	_caja(r, Vector3(0.06, 0.03, 0.01), Vector3(0.0, 0.53, 0.21), ORO)    # Logo


func _gorro(r: Node3D) -> void:
	var g := _esfera(r, 0.115, Vector3(0.0, 0.49, 0.1), Color("23304a"))
	g.scale = Vector3(1.0, 0.72, 1.0)
	_cil(r, 0.112, 0.112, 0.045, Vector3(0.0, 0.47, 0.1), Color("2c3b5a"))


func _pasamontanas(r: Node3D) -> void:
	var p := _esfera(r, 0.13, Vector3(0.0, 0.43, 0.1), NEGRO)
	p.scale = Vector3(1.0, 1.05, 1.08)
	_cil(r, 0.0, 0.06, 0.08, Vector3(0.0, 0.57, 0.08), NEGRO)             # La punta de la capucha
	_caja(r, Vector3(0.2, 0.035, 0.03), Vector3(0.0, 0.445, 0.2), Color("e9e4d8"))   # El tajo de los ojos


func _cadena(r: Node3D) -> void:
	for k in 12:
		var a := -PI * 0.85 + k * PI * 1.7 / 11.0
		_esfera(r, 0.016, Vector3(sin(a) * 0.1, 0.32 - (1.0 - cos(a)) * 0.02, 0.05 + cos(a) * 0.1), ORO)
	var medalla := _cil(r, 0.04, 0.04, 0.012, Vector3(0.0, 0.25, 0.16), ORO)
	medalla.rotation.x = PI / 2.0
	_caja(r, Vector3(0.012, 0.05, 0.01), Vector3(0.0, 0.25, 0.168), Color("b8902a"))


func _bolsa(r: Node3D) -> void:
	var b := _esfera(r, 0.08, Vector3(0.17, 0.2, -0.02), ARENA)
	b.scale = Vector3(1.0, 0.95, 1.0)
	_cil(r, 0.02, 0.03, 0.04, Vector3(0.17, 0.29, -0.02), ARENA.darkened(0.25))
	var signo := Label3D.new()
	signo.text = "$"
	signo.font_size = 32
	signo.pixel_size = 0.004
	signo.modulate = Color("2f8a3a")
	signo.outline_size = 0
	signo.position = Vector3(0.25, 0.2, -0.02)
	signo.rotation.y = PI / 2.0
	r.add_child(signo)


func _bate(r: Node3D) -> void:
	var b := _cil(r, 0.03, 0.016, 0.42, Vector3(-0.17, 0.27, 0.06), MADERA)
	b.rotation = Vector3(0.5, 0.0, 0.45)
	for k in 2:
		var cinta := _cil(r, 0.019, 0.019, 0.025, Vector3(-0.17, 0.27, 0.06), Color("c8423a"))
		cinta.rotation = b.rotation
		cinta.position += b.basis.y * (-0.12 - k * 0.04)


func _rinonera(r: Node3D) -> void:
	_caja(r, Vector3(0.12, 0.06, 0.05), Vector3(0.07, 0.22, 0.15), VERDE)
	var tira := _caja(r, Vector3(0.025, 0.3, 0.012), Vector3(0.0, 0.28, 0.14), NEGRO)
	tira.rotation.z = 0.7


func _caja(r: Node3D, tam: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return _pieza(r, m, pos, color)


func _cil(r: Node3D, radio_arriba: float, radio_abajo: float, alto: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radio_arriba
	m.bottom_radius = radio_abajo
	m.height = alto
	m.radial_segments = 12
	m.rings = 1
	return _pieza(r, m, pos, color)


func _esfera(r: Node3D, radio: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radio
	m.height = radio * 2.0
	m.radial_segments = 10
	m.rings = 6
	return _pieza(r, m, pos, color)


func _pieza(r: Node3D, malla: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	r.add_child(mi)
	return mi
