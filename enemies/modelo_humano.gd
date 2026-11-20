class_name ModeloHumano
extends Node3D
## Persona de la ciudad con esqueleto: uno de los 22 personajes de modelos/personas/<personaje>.glb (hechos
## en tools/blender/personas.py). Una sola malla por persona (más el sombrero, si tiene) y animación por
## código: caminar con rodillas y codos, sentarse, levantar los brazos, comer, tirar migas, mirar alrededor.
## Mira hacia -Z.

## Uno de los personajes de modelos/personas/personas.json ("" = uno al azar según el alto).
@export var personaje := ""
@export var alto := 0.0                    ## 0 = el alto propio del personaje (si no, se escala)
@export var sentado := false
## Colores opcionales (alfa 0 = el del personaje). Se multiplican sobre el sombreado de esa zona.
@export var color_ropa := Color(0, 0, 0, 0)
@export var color_piernas := Color(0, 0, 0, 0)
@export var color_piel := Color(0, 0, 0, 0)
@export var color_pelo := Color(0, 0, 0, 0)
## "" = lo que trae el personaje; "ninguno" = sin sombrero. Después de armarlo dice lo que tiene puesto:
## "sombrero", "gorra", "chef", "morrion" o "ninguno".
@export var accesorio := ""
@export var color_accesorio := Color.WHITE

## Personajes adultos que pueden andar por cualquier lado (turistas, comensales, clientes).
const PASEANTES := ["turista_gringo", "mochilera", "hincha", "estudiante", "artesano", "jubilado", "bailarina",
	"oficinista", "oficinista_mujer", "abuela"]
const CHICOS := ["pibe", "escolar", "escolar_nena"]

const CAPA_GENTE := 4
const ZONAS := ["fijo", "piel", "pelo", "ropa", "piernas"]
const HUESOS := ["cadera", "torso", "cabeza", "brazo_i", "antebrazo_i", "brazo_d", "antebrazo_d",
	"muslo_i", "pierna_i", "muslo_d", "pierna_d"]
const ALTO_ASIENTO := 0.47                 ## Altura de la articulación de la cadera sentado (adulto de 1,75)

static var _info := {}
static var _escenas := {}
static var _mallas := {}                   ## "personaje|colores" -> ArrayMesh repintada

var _datos := {}
var _raiz: Node3D
var _skel: Skeleton3D
var _cuerpo_mi: MeshInstance3D
var _sombrero_mi: MeshInstance3D
var _idx := {}
var _rest_g := {}                          ## hueso -> Basis global de reposo
var _rest_l := {}                          ## hueso -> Quaternion local de reposo
var _rest_pos := Vector3.ZERO              ## posición de reposo de la cadera
var _fase := 0.0
var _arriba := 0.0                         ## brazos levantados (0..1)
var _gesto := 0.0                          ## 0..1 gesto del brazo derecho
var _tipo_gesto := ""
var _mirar := Vector2.ZERO                 ## giro de cabeza actual (y, x)
var _mirar_obj := Vector2.ZERO
var _t_mirar := 0.0
var _respira := 0.0
var _escala := 1.0
var _salteados := 0                        ## Cuadros sin rearmar la pose (los que están lejos se animan menos seguido)


static func info(nombre: String) -> Dictionary:
	if _info.is_empty():
		var f := FileAccess.open("res://modelos/personas/personas.json", FileAccess.READ)
		if f:
			_info = JSON.parse_string(f.get_as_text())
	return _info.get(nombre, {})


static func personajes() -> Array:
	info("")
	return _info.keys()


func _ready() -> void:
	_armar()
	_crear_cuerpo_fisico()
	add_to_group("cuerpos_humanos")
	_fase = randf() * TAU
	_t_mirar = randf_range(1.0, 4.0)


func _armar() -> void:
	if personaje == "":
		personaje = CHICOS.pick_random() if (alto > 0.0 and alto < 1.45) else PASEANTES.pick_random()
	_datos = info(personaje)
	if _datos.is_empty():
		push_warning("Falta el personaje: " + personaje)
		return
	if alto <= 0.0:
		alto = float(_datos["alto"])
	_escala = alto / float(_datos["alto"])
	if not _escenas.has(personaje):
		_escenas[personaje] = load("res://modelos/personas/%s.glb" % personaje)
	_raiz = (_escenas[personaje] as PackedScene).instantiate() as Node3D
	_raiz.scale = Vector3.ONE * _escala
	add_child(_raiz)
	_skel = _raiz.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for n in _raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if String(mi.name).begins_with("Sombrero"):
			_sombrero_mi = mi
		else:
			_cuerpo_mi = mi
	var mat := Construir.material_vertices(0.85)
	_cuerpo_mi.mesh = _malla_pintada(_cuerpo_mi.mesh, false)
	_cuerpo_mi.material_override = mat
	var sombras: Array[GeometryInstance3D] = [_cuerpo_mi]
	if _sombrero_mi:
		_sombrero_mi.mesh = _malla_pintada(_sombrero_mi.mesh, true)
		_sombrero_mi.material_override = mat
		sombras.append(_sombrero_mi)
		if accesorio == "ninguno":
			_sombrero_mi.visible = false
		else:
			accesorio = String(_datos.get("sombrero", ""))
			color_accesorio = Color(String(_datos.get("color_sombrero", "#ffffff")))
	if not tiene_sombrero():
		accesorio = "ninguno"
	Ajustes.registrar_sombra_dinamica(sombras)
	for i in HUESOS.size():
		var b := _skel.find_bone(HUESOS[i])
		_idx[HUESOS[i]] = b
		_rest_g[HUESOS[i]] = _skel.get_bone_global_rest(b).basis.orthonormalized()
		_rest_l[HUESOS[i]] = _skel.get_bone_rest(b).basis.get_rotation_quaternion()
	_rest_pos = _skel.get_bone_rest(_idx["cadera"]).origin
	_aplicar_pose(0.0, 0.0)


## La malla del personaje o, si se pidieron colores, una copia con esas zonas repintadas.
func _malla_pintada(orig: Mesh, es_sombrero: bool) -> Mesh:
	var pedidos := {"piel": color_piel, "pelo": color_pelo, "ropa": color_ropa, "piernas": color_piernas}
	var clave := personaje + ("|s" if es_sombrero else "|c")
	if not es_sombrero:
		for z in pedidos:
			if (pedidos[z] as Color).a > 0.0:
				clave += "|%s=%s" % [z, (pedidos[z] as Color).to_html(false)]
	# Sin colores pedidos se usa la malla importada tal cual: así conserva los niveles de detalle (LOD) que
	# arma Godot al importar (una copia con add_surface_from_arrays los pierde y de lejos dibuja todo).
	if es_sombrero or clave == personaje + "|c":
		return orig
	if _mallas.has(clave):
		return _mallas[clave]
	var base: Dictionary = _datos.get("zonas", {})
	var am := ArrayMesh.new()
	for s in orig.get_surface_count():
		var arr := orig.surface_get_arrays(s)
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in cols.size():
			var c := cols[i]
			if not es_sombrero and uvs.size() == cols.size():
				var z: String = ZONAS[clampi(int(uvs[i].x * 8.0), 0, 4)]
				if pedidos.has(z) and (pedidos[z] as Color).a > 0.0 and base.has(z):
					var b := Color(String(base[z]))
					var p: Color = pedidos[z]
					c = Color(c.r * p.r / maxf(b.r, 0.02), c.g * p.g / maxf(b.g, 0.02), c.b * p.b / maxf(b.b, 0.02))
			cols[i] = c
		arr[Mesh.ARRAY_COLOR] = cols
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mallas[clave] = am
	return am


## ------------------------------------------------------------------ física
func radio_colision() -> float:
	return (0.38 if sentado else 0.3) * alto / 1.75


func alto_colision() -> float:
	return alto * (0.8 if sentado else 1.0)


func _crear_cuerpo_fisico() -> void:
	var cuerpo_fisico := AnimatableBody3D.new()
	cuerpo_fisico.name = "CuerpoFisico"
	cuerpo_fisico.sync_to_physics = false
	cuerpo_fisico.collision_layer = CAPA_GENTE
	cuerpo_fisico.collision_mask = 0
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = radio_colision()
	capsula.height = maxf(alto_colision(), capsula.radius * 2.0)
	forma.shape = capsula
	forma.position.y = capsula.height / 2.0
	cuerpo_fisico.add_child(forma)
	add_child(cuerpo_fisico)


## ------------------------------------------------------------------ pose
## Gira el hueso con una rotación dada en ejes del modelo (x: adelante/atrás, y: girar, z: de costado).
func _rot(hueso: String, euler: Vector3) -> void:
	var rg: Basis = _rest_g[hueso]
	var q := (rg.inverse() * Basis.from_euler(euler) * rg).get_rotation_quaternion()
	_skel.set_bone_pose_rotation(_idx[hueso], (_rest_l[hueso] as Quaternion) * q)


func _bajada_sentado() -> float:
	return float(_datos["cadera"]) - ALTO_ASIENTO * float(_datos["alto"]) / 1.75


func _aplicar_pose(velocidad: float, delta: float) -> void:
	if _skel == null:
		return
	var pose: Dictionary = _datos.get("pose", {})
	var amp := clampf(velocidad / 1.6, 0.0, 1.3)
	var s := sin(_fase)
	var c := cos(_fase)
	var resp := sin(_respira) * 0.02
	var cad := Vector3(0, 0, 0)
	var y_cad := 0.0
	var mi := Vector3.ZERO      # muslo izq
	var md := Vector3.ZERO
	var pi_ := Vector3.ZERO     # pierna (rodilla)
	var pd := Vector3.ZERO
	var bi := Vector3(0, 0, 0)  # brazo
	var bd := Vector3(0, 0, 0)
	var ai := Vector3(0.12, 0, 0)  # antebrazo (un poquito doblado)
	var ad := Vector3(0.12, 0, 0)
	var torso := Vector3(resp, 0, 0)
	if sentado:
		y_cad = -_bajada_sentado()
		mi = Vector3(PI / 2.0, 0, 0.06)
		md = Vector3(PI / 2.0, 0, -0.06)
		pi_ = Vector3(-PI / 2.0, 0, 0)
		pd = Vector3(-PI / 2.0, 0, 0)
		# manos apoyadas sobre los muslos
		bi = Vector3(0.3, 0, 0.14)
		bd = Vector3(0.3, 0, -0.14)
		ai = Vector3(0.5, 0, 0)
		ad = Vector3(0.5, 0, 0)
		torso.x += 0.04
	else:
		# caminar: muslos y brazos opuestos, la rodilla se dobla al pasar la pierna para adelante
		mi.x = s * 0.55 * amp
		md.x = -s * 0.55 * amp
		pi_.x = -(0.08 + maxf(0.0, -c) * 0.9) * amp
		pd.x = -(0.08 + maxf(0.0, c) * 0.9) * amp
		bi.x = -s * 0.45 * amp
		bd.x = s * 0.45 * amp
		ai.x += (0.25 + maxf(0.0, -s) * 0.3) * amp
		ad.x += (0.25 + maxf(0.0, s) * 0.3) * amp
		y_cad = (absf(c) - 0.6) * 0.035 * amp
		cad.y = s * 0.12 * amp
		torso.y = -s * 0.16 * amp
		torso.x += 0.05 * amp
	# brazos levantados (gritar, espantar, festejar)
	if _arriba > 0.01:
		var sacude := sin(_fase * 3.0) * 0.25
		bi = bi.lerp(Vector3(-0.3, 0, -2.6 - sacude), _arriba)
		bd = bd.lerp(Vector3(-0.3, 0, 2.6 + sacude), _arriba)
		ai = ai.lerp(Vector3(0.5, 0, 0), _arriba)
		ad = ad.lerp(Vector3(0.5, 0, 0), _arriba)
	# gestos del brazo derecho
	if _gesto > 0.0:
		match _tipo_gesto:
			"comer":
				bd = bd.lerp(Vector3(1.0, 0, -0.15), _gesto)
				ad = ad.lerp(Vector3(2.0, 0, 0), _gesto)
			"tirar":
				bd = bd.lerp(Vector3(1.4, 0, 0.1), _gesto)
				ad = ad.lerp(Vector3(0.2, 0, 0), _gesto)
	# poses fijas de algunos (la bandeja del mozo, el bandoneón)
	if pose.get("brazo_i", "") == "bandeja":
		bi = Vector3(0.05 * s * amp, 0, 0)
		ai = Vector3.ZERO
	if pose.get("brazo_i", "") == "adelante" and pose.get("brazo_d", "") == "adelante":
		var fuelle := sin(_fase * 0.7) * 0.22
		bi = Vector3(0.05, 0, -fuelle)
		bd = Vector3(0.05, 0, fuelle)
		ai = Vector3.ZERO
		ad = Vector3.ZERO
	elif pose.get("brazo_d", "") == "adelante" and _gesto <= 0.0:
		bd = Vector3(0.05 * s * amp, 0, 0)
		ad = Vector3.ZERO
	if pose.get("brazo_i", "") == "codo":
		bi = Vector3(0.05 * s * amp, 0, 0)
		ai = Vector3.ZERO
	_skel.set_bone_pose_position(_idx["cadera"], _rest_pos + Vector3(0, y_cad, 0))
	_rot("cadera", cad)
	_rot("torso", torso)
	_rot("cabeza", Vector3(_mirar.y - torso.x * 0.5, _mirar.x - torso.y * 0.6, 0))
	_rot("muslo_i", mi)
	_rot("muslo_d", md)
	_rot("pierna_i", pi_)
	_rot("pierna_d", pd)
	_rot("brazo_i", bi)
	_rot("brazo_d", bd)
	_rot("antebrazo_i", ai)
	_rot("antebrazo_d", ad)


## Paso de animación: llamarlo en cada cuadro con la velocidad a la que camina.
func animar(delta: float, velocidad: float, agitado := false) -> void:
	_respira += delta * 1.6
	if velocidad > 0.1 and not sentado:
		_fase += delta * (3.2 + velocidad * 2.2)
	else:
		_fase += delta * 2.0
	_arriba = lerpf(_arriba, 1.0 if agitado else 0.0, minf(delta * 8.0, 1.0))
	# mirar alrededor de vez en cuando (más quieto si camina)
	_t_mirar -= delta
	if _t_mirar <= 0.0:
		_t_mirar = randf_range(1.5, 5.0)
		_mirar_obj = Vector2(randf_range(-0.6, 0.6), randf_range(-0.15, 0.2)) if randf() < 0.6 else Vector2.ZERO
	var obj := _mirar_obj * (0.35 if velocidad > 0.5 else 1.0)
	_mirar = _mirar.lerp(obj, minf(delta * 3.0, 1.0))
	# Lejos de la cámara (o fuera de la vista) los huesos se mueven cada 2, 3 o 6 cuadros: no se nota y ahorra
	var cada := 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		var d2 := cam.global_position.distance_squared_to(global_position)
		if d2 > 3600.0:
			cada = 6
		elif d2 > 625.0:
			cada = 3
		elif d2 > 225.0:
			cada = 2
		elif not cam.is_position_in_frustum(global_position + Vector3.UP):
			cada = 3
	_salteados += 1
	if _salteados < cada:
		return
	_salteados = 0
	_aplicar_pose(velocidad, delta)


## Altura (local, en metros) de la coronilla: de donde sale volando el sombrero.
func altura_sombrero() -> float:
	var y := (float(_datos.get("cabeza", 1.6)) + float(_datos.get("cabeza_r", 0.13))) * _escala
	if sentado:
		y -= _bajada_sentado() * _escala
	return y


## Le saca el sombrero, la gorra o el gorro de cocinero (el morrión del granadero no se cae). Devuelve el
## tipo que tenía ("" si no tenía nada que se pudiera volar).
func quitar_sombrero() -> String:
	if not tiene_sombrero() or accesorio == "morrion":
		return ""
	_sombrero_mi.visible = false
	var tenia := accesorio
	accesorio = "ninguno"
	_rearmar_fisica()
	return tenia


func tiene_sombrero() -> bool:
	return _sombrero_mi != null and _sombrero_mi.visible


## Copia quieta (sin huesos) de la malla del sombrero, con el origen en el centro de su base y a la escala
## de la persona: para el objeto que sale volando de un aletazo. Las mallas se guardan por personaje.
func malla_sombrero() -> Mesh:
	if _sombrero_mi == null:
		return null
	var clave := personaje + "|suelto|%.3f" % _escala
	if not _mallas.has(clave):
		var arr := _sombrero_mi.mesh.surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var base := _base_sombrero_local()
		for i in vs.size():
			vs[i] = (vs[i] - base) * _escala
		var limpio := []
		limpio.resize(Mesh.ARRAY_MAX)
		limpio[Mesh.ARRAY_VERTEX] = vs
		limpio[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
		limpio[Mesh.ARRAY_COLOR] = arr[Mesh.ARRAY_COLOR]
		limpio[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, limpio)
		_mallas[clave] = am
	return _mallas[clave]


## Centro de la base del sombrero en coordenadas del GLB (sin escalar).
func _base_sombrero_local() -> Vector3:
	var aabb := _sombrero_mi.mesh.get_aabb()
	return Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z)


## Dónde está ahora (global) la base del sombrero: de ahí sale el que vuela.
func posicion_sombrero() -> Vector3:
	if _sombrero_mi == null:
		return global_position + Vector3(0, altura_sombrero(), 0)
	var cab := _skel.get_bone_global_pose(_idx["cabeza"]) * _skel.get_bone_global_rest(_idx["cabeza"]).affine_inverse()
	return _skel.global_transform * (cab * _base_sombrero_local())


func devolver_sombrero() -> void:
	if _sombrero_mi:
		_sombrero_mi.visible = true
		accesorio = String(_datos.get("sombrero", ""))


func cambiar_postura(sentar: bool) -> void:
	if sentar == sentado:
		return
	sentado = sentar
	_rearmar_fisica()
	_aplicar_pose(0.0, 0.0)


func _rearmar_fisica() -> void:
	var cf := get_node_or_null("CuerpoFisico")
	if cf:
		remove_child(cf)
		cf.queue_free()
	_crear_cuerpo_fisico()


func gesto_comer() -> void:
	_hacer_gesto("comer", 0.25, 0.35, 0.3)


func gesto_tirar() -> void:
	_hacer_gesto("tirar", 0.15, 0.05, 0.3)


func _hacer_gesto(tipo: String, ida: float, quieto: float, vuelta: float) -> void:
	_tipo_gesto = tipo
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _gesto = v; _aplicar_pose(0.0, 0.0), 0.0, 1.0, ida)
	tw.tween_interval(quieto)
	tw.tween_method(func(v: float) -> void: _gesto = v; _aplicar_pose(0.0, 0.0), 1.0, 0.0, vuelta)


func posicion_mano() -> Vector3:
	if _skel == null:
		return global_position
	var t := _skel.global_transform * _skel.get_bone_global_pose(_idx["antebrazo_d"])
	return t * Vector3(0, 0.3, 0)
