class_name GestosPaloma
extends SkeletonModifier3D
## Gestos de la paloma quieta (la jugadora en el menú principal): gira la cabeza a tirones cortos
## como las palomas de verdad (mira a la cámara, a veces de costado con un solo ojo, mira alrededor,
## arriba y al piso), parpadea y cada tanto picotea o arrulla. Nada se repite en bucle: cada gesto
## sale al azar con su propio tiempo.
## Se agrega como hijo del Skeleton3D del modelo (ModeloPaloma.agregar_gestos) y rota el hueso
## "head" después de la animación. Los párpados son dos cajitas que siguen la pose final de la
## cabeza (un BoneAttachment3D no sirve: toma la pose de antes de este modificador).

## Hacia dónde está "la cámara" (la paloma la mira de frente o de costado).
var mirar_a: Node3D
var modelo: ModeloPaloma

## Ojos del modelo en el espacio del hueso "head" (el GLB tiene la cabeza en (0, 0,3, 0,075) y
## los ojos son bloques que sobresalen a los costados).
const OJO_CENTRO := Vector3(0.1135, 0.153, 0.0385)    ## Arriba del ojo (desde ahí baja el párpado)
const OJO_TAM := Vector3(0.031, 0.083, 0.083)
## Punto de la textura de la paloma con el gris de la cabeza (#bcbece), en el medio de una zona
## pareja: el párpado usa el MISMO material del modelo con todas las UV en ese punto, así la luz
## y la sombra le pegan igual que al resto de la cabeza.
const UV_PARPADO := Vector3(0.0508, 0.9258, 0.0)
const MAX_YAW := 1.25
const MAX_PITCH := 0.55

var _hueso := -1
var _mirada := Vector3.ZERO      ## (pitch, yaw, roll) actual de la cabeza, en radianes
var _vel := Vector3.ZERO
var _destino := Vector3.ZERO
var _rigidez := 26.0             ## Qué tan rápido gira la cabeza (las palomas giran a tirones)
var _t_mirada := 0.4
var _t_parpadeo := 1.5
var _t_picoteo := 7.0
var _t_arrullo := 14.0
var _parpado := 0.0              ## 0 abierto, 1 cerrado
var _parpadeo_t := -1.0
var _doble := false
var _segundo := 0.0              ## Cuenta regresiva del segundo parpadeo de uno doble
var _parpados: Array[Node3D] = []
var _cabeza: Node3D              ## Sigue la pose final del hueso "head" (ahí cuelgan los párpados)
var _apagando := false


func _ready() -> void:
	var sk := get_skeleton()
	_hueso = sk.find_bone("head")
	_armar_parpados(sk, _material_modelo(sk))
	_t_picoteo = randf_range(5.0, 9.0)
	_t_arrullo = randf_range(12.0, 20.0)


## Deja de mover la cabeza de a poco (al empezar la partida) y después se borra con los párpados.
func soltar_cabeza() -> void:
	_apagando = true


func _process(delta: float) -> void:
	_actualizar_parpadeo(delta)
	if _apagando:
		influence = move_toward(influence, 0.0, delta * 3.0)
		if influence <= 0.0 and _parpadeo_t < 0.0:
			if is_instance_valid(_cabeza):
				_cabeza.queue_free()
			queue_free()
		return
	_t_mirada -= delta
	if _t_mirada <= 0.0:
		_elegir_mirada()
	_t_picoteo -= delta
	if _t_picoteo <= 0.0:
		_t_picoteo = randf_range(6.0, 14.0)
		_picotear()
	_t_arrullo -= delta
	if _t_arrullo <= 0.0:
		_t_arrullo = randf_range(16.0, 32.0)
		if modelo:
			modelo.arrullar()
			AudioManager.reproducir("arrullo", -14.0)
		_destino = Vector3(-0.15, _destino.y * 0.4, 0.0)


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _hueso < 0:
		return
	# Resorte un poco subamortiguado: llega rápido y se pasa apenas, como un cabeceo vivo.
	# Se integra en pasitos de 4 ms para que sea estable aunque el juego vaya a pocos FPS.
	var restante := minf(delta, 0.1)
	var amort := 2.0 * 0.72 * _rigidez
	while restante > 0.0:
		var d := minf(restante, 0.004)
		restante -= d
		var acel := (_destino - _mirada) * _rigidez * _rigidez - _vel * amort
		_vel += acel * d
		_mirada += _vel * d
	# Un temblorcito casi imperceptible para que nunca quede congelada
	var t := Time.get_ticks_msec() * 0.001
	var micro := Vector3(sin(t * 1.7) * 0.012, sin(t * 1.3 + 1.0) * 0.018, sin(t * 0.9 + 2.0) * 0.01)
	var giro := _mirada + micro
	var pose := sk.get_bone_pose_rotation(_hueso)
	# El hueso de la cabeza tiene Y hacia arriba y Z hacia el pico: yaw en Y, pitch en X, roll en Z
	var extra := Quaternion.from_euler(Vector3(giro.x, giro.y, giro.z))
	sk.set_bone_pose_rotation(_hueso, pose * extra)
	if is_instance_valid(_cabeza):
		_cabeza.transform = sk.get_bone_global_pose(_hueso)


# ---------------------------------------------------------------- Mirada

func _elegir_mirada() -> void:
	var camara := _hacia_camara()
	var r := randf()
	var nuevo: Vector3
	var espera := randf_range(0.6, 2.2)
	if r < 0.34:
		# A la cámara, de frente
		nuevo = camara + Vector3(randf_range(-0.05, 0.05), randf_range(-0.08, 0.08), 0.0)
		espera = randf_range(1.0, 2.6)
	elif r < 0.56:
		# A la cámara pero con un solo ojo: gira la cabeza de costado e inclina
		var lado := 1.0 if randf() < 0.5 else -1.0
		nuevo = Vector3(camara.x - 0.1, camara.y + lado * 1.05, -lado * 0.35)
		espera = randf_range(0.8, 1.8)
	elif r < 0.8:
		# Mira alrededor
		nuevo = Vector3(randf_range(-0.2, 0.15), randf_range(-1.1, 1.1), randf_range(-0.15, 0.15))
	elif r < 0.9:
		# Algo arriba (un ojo al cielo, con la cabeza inclinada)
		var lado := 1.0 if randf() < 0.5 else -1.0
		nuevo = Vector3(-0.45, lado * randf_range(0.4, 0.8), -lado * 0.5)
	else:
		# Al piso, buscando migas
		nuevo = Vector3(0.42, randf_range(-0.4, 0.4), 0.0)
	nuevo.x = clampf(nuevo.x, -MAX_PITCH, MAX_PITCH)
	nuevo.y = clampf(nuevo.y, -MAX_YAW, MAX_YAW)
	# Los giros grandes muchas veces vienen con un parpadeo
	if absf(nuevo.y - _destino.y) > 0.7 and randf() < 0.45:
		_parpadear()
	_rigidez = randf_range(22.0, 32.0)
	_destino = nuevo
	_t_mirada = espera


## (pitch, yaw, 0) para que el pico apunte a "mirar_a", relativo al cuerpo de la paloma.
func _hacia_camara() -> Vector3:
	if mirar_a == null or not is_instance_valid(mirar_a):
		return Vector3.ZERO
	var sk := get_skeleton()
	var cabeza := sk.global_transform * sk.get_bone_global_rest(_hueso)
	var cuerpo := sk.global_transform.basis.orthonormalized()
	var dir := cuerpo.inverse() * (mirar_a.global_position - cabeza.origin)
	var yaw := atan2(dir.x, dir.z)
	var pitch := -atan2(dir.y, Vector2(dir.x, dir.z).length())
	return Vector3(clampf(pitch, -MAX_PITCH, MAX_PITCH), clampf(yaw, -MAX_YAW, MAX_YAW), 0.0)


func _picotear() -> void:
	if modelo == null:
		return
	_destino = Vector3(0.2, randf_range(-0.15, 0.15), 0.0)
	_t_mirada = randf_range(0.7, 1.1)
	modelo.picotear()


# ---------------------------------------------------------------- Párpados

## Material de la malla de la paloma (o uno gris parecido si no lo encuentra).
func _material_modelo(sk: Skeleton3D) -> Material:
	for n in sk.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		if m:
			var copia := m.duplicate() as BaseMaterial3D
			copia.uv1_scale = Vector3.ZERO
			copia.uv1_offset = UV_PARPADO
			return copia
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color("bcbece")
	return gris


func _armar_parpados(sk: Skeleton3D, mat: Material) -> void:
	var adjunto := Node3D.new()
	adjunto.name = "Parpados"
	sk.add_child(adjunto)
	adjunto.transform = sk.get_bone_global_pose(_hueso)
	_cabeza = adjunto
	var caja := BoxMesh.new()
	caja.size = OJO_TAM
	for lado in [1.0, -1.0]:
		var bisagra := Node3D.new()
		bisagra.position = Vector3(OJO_CENTRO.x * lado, OJO_CENTRO.y, OJO_CENTRO.z)
		bisagra.scale = Vector3(1.0, 0.001, 1.0)
		bisagra.visible = false
		adjunto.add_child(bisagra)
		var m := MeshInstance3D.new()
		m.mesh = caja
		m.material_override = mat
		m.position = Vector3(0, -OJO_TAM.y * 0.5, 0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bisagra.add_child(m)
		_parpados.append(bisagra)


func _parpadear(puede_ser_doble := true) -> void:
	if _parpadeo_t < 0.0:
		_parpadeo_t = 0.0
		_doble = puede_ser_doble and randf() < 0.2


func _actualizar_parpadeo(delta: float) -> void:
	_t_parpadeo -= delta
	if _t_parpadeo <= 0.0:
		_t_parpadeo = randf_range(2.0, 5.5)
		_parpadear()
	if _segundo > 0.0:
		_segundo -= delta
		if _segundo <= 0.0:
			_parpadear(false)   # Segundo parpadeo de uno doble
	if _parpadeo_t < 0.0:
		return
	_parpadeo_t += delta
	# Cierra rápido (0,05 s) y abre un poco más lento (0,09 s)
	var cierre := 0.05
	var total := 0.14
	if _parpadeo_t < cierre:
		_parpado = _parpadeo_t / cierre
	elif _parpadeo_t < total:
		_parpado = 1.0 - (_parpadeo_t - cierre) / (total - cierre)
	else:
		_parpado = 0.0
		_parpadeo_t = -1.0
		if _doble:
			_doble = false
			_segundo = 0.08
	for p in _parpados:
		p.visible = _parpado > 0.02
		p.scale.y = maxf(_parpado, 0.001)
