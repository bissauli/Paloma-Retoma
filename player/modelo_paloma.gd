class_name ModeloPaloma
extends Node3D
## Modelo blocky de paloma (GLB hecho en Blender: malla + esqueleto de 8 huesos + animaciones).
## Lo usan la paloma del jugador (variante "Original") y las NPC (variantes de color).
## Todas las variantes comparten malla, huesos y animaciones; sólo cambia la paleta de la textura.
## El GLB mira hacia +Z; este nodo lo gira para que la paloma mire hacia -Z, como espera el juego.

## Llegó el gran final del baile de cortejo (ver Coreografia.MOMENTO_CORTEJO): la jugadora enamora palomas.
signal cortejo_logrado

const VARIANTES := {
	"Original": preload("res://modelos/paloma/Paloma.glb"),
	"Gris": preload("res://modelos/paloma/Paloma_Gris.glb"),
	"Blanca": preload("res://modelos/paloma/Paloma_Blanca.glb"),
	"Marron": preload("res://modelos/paloma/Paloma_Marron.glb"),
	"Oscura": preload("res://modelos/paloma/Paloma_Oscura.glb"),
	"Canela": preload("res://modelos/paloma/Paloma_Canela.glb"),
	"Manchada": preload("res://modelos/paloma/Paloma_Manchada.glb"),
}

## Qué tan seguido aparece cada variante entre las palomas NPC (la "Original" es la de la jugadora).
const PESOS_NPC := {
	"Gris": 30.0,
	"Oscura": 15.0,
	"Marron": 15.0,
	"Canela": 14.0,
	"Manchada": 14.0,
	"Blanca": 12.0,
}

## Punta del pico en el espacio del GLB (ahí se ve la comida que lleva).
const PUNTO_PICO := Vector3(0.0, 0.36, 0.28)
const MEZCLA := 0.15   ## Segundos de transición entre animaciones

@export_enum("Original", "Gris", "Blanca", "Marron", "Oscura", "Canela", "Manchada") var variante := "Original"
@export var es_jugador := false   ## La jugadora picotea más rápido (el picoteo es una acción del juego)

var permite_baile := false     ## Una paloma NPC que imita los emotes de la jugadora (ver Bandada.imitar_baile)
var carga_visual: Node3D
var sombrero_visual: Node3D    ## Dónde se cuelga el sombrero que se le sacó a un humano

var _congelada := false   ## Ver congelar()
var _aletazo: AletazoPaloma
var _baile: StringName = &""    ## Baile en curso (ver bailar); "" = no baila
var _t_baile := 0.0
var _tween_aturdida: Tween      ## Ver aturdir()
var _tween_vaiven: Tween
var _halo: Node3D
var _reposo: Array[Basis] = []  ## Giro global de cada hueso en reposo (para las poses de baile)

var _glb: Node3D
var _anim: AnimationPlayer
var _anim_accion: AnimationPlayer   ## Picoteo y arrullo, aparte de la base (ver _armar_acciones)
var _skel: Skeleton3D
var _base := ""        ## Animación de base actual (Idle, Walk, Fly, Glide, Dive)
var _accion := ""      ## Animación de un solo uso en curso (Peck, Coo)

## Picoteo y arrullo sin los huesos de las patas: se arman una sola vez y las comparten todas las palomas.
static var _acciones_sin_patas: AnimationLibrary
var _mallas: Array[GeometryInstance3D] = []

# Animación de las NPC: se avanza a mano, más espaciado cuanto más lejos está de la cámara (o si
# está fuera de cuadro). De cerca se ve igual; de lejos nadie nota que el aleteo va a 15 cuadros.
var _anim_acum := 0.0      ## Tiempo acumulado sin aplicar a la animación
var _anim_desfase := 0     ## Para repartir las palomas entre cuadros
var _distancia2 := 4900.0  ## Distancia de dibujo al cuadrado (Ajustes.distancia_palomas)
static var _cam_cuadro := -1
static var _cam: Camera3D
static var _cam_pos := Vector3.ZERO


## Variante al azar para una paloma NPC, según PESOS_NPC.
static func variante_al_azar() -> String:
	var total := 0.0
	for v in PESOS_NPC:
		total += PESOS_NPC[v]
	var r := randf() * total
	for v in PESOS_NPC:
		r -= PESOS_NPC[v]
		if r <= 0.0:
			return v
	return "Gris"


func _ready() -> void:
	_armar()


# ---------------------------------------------------------------- Construcción

func _armar() -> void:
	var escena: PackedScene = VARIANTES.get(variante, VARIANTES["Original"])
	_glb = escena.instantiate() as Node3D
	_glb.name = "Paloma"
	_glb.rotation.y = PI
	add_child(_glb)
	_anim = _glb.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_skel = _glb.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_armar_acciones()

	# La comida que lleva en el pico sigue al hueso de la cabeza
	var adjunto := BoneAttachment3D.new()
	adjunto.name = "Pico"
	adjunto.bone_name = "head"
	_skel.add_child(adjunto)
	carga_visual = Node3D.new()
	carga_visual.name = "Carga"
	adjunto.add_child(carga_visual)
	var skel_en_glb := _relativo(_glb, _skel)
	var cabeza_rest := _skel.get_bone_global_rest(_skel.find_bone("head"))
	carga_visual.transform = cabeza_rest.affine_inverse() * Transform3D(Basis(), skel_en_glb.affine_inverse() * PUNTO_PICO)

	# Lugar del sombrero "robado" a la gente (ver poner_sombrero): sigue al hueso de la cabeza
	sombrero_visual = Node3D.new()
	sombrero_visual.name = "Sombrero"
	adjunto.add_child(sombrero_visual)
	sombrero_visual.transform = cabeza_rest.affine_inverse() * skel_en_glb.affine_inverse()

	# Sólo la paloma de la jugadora se personaliza (colores por zona y accesorios)
	if es_jugador:
		var perfil := PerfilPaloma.actual()
		aplicar_perfil(perfil)
		perfil.cambiado.connect(_al_cambiar_perfil)
		perfil.pintura_cambiada.connect(_al_pintar)

	# Arranca en reposo, cada una en un punto distinto del ciclo para que no se muevan todas igual
	_reproducir_base("Idle", 1.0, 0.0)
	_anim.seek(randf() * _anim.current_animation_length, true)
	if not es_jugador:
		for m in _glb.find_children("*", "GeometryInstance3D", true, false):
			_mallas.append(m as GeometryInstance3D)
		# Sombra sólo en calidad Media o Alta (la jugadora siempre)
		Ajustes.registrar_sombra_dinamica(_mallas)
		# Lejos no se dibujan, y la animación la maneja _process (ver _avanzar_animacion)
		add_to_group(Ajustes.GRUPO_DISTANCIA_PALOMAS)
		aplicar_distancia(Ajustes.distancia_palomas())
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_accion.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_desfase = randi() % 16
	set_process(not es_jugador)


## Se pone en la cabeza un "sombrero" o una "gorra" (de un humano) del color dado. Reemplaza al anterior.
func poner_sombrero(tipo_sombrero: String, color_sombrero: Color) -> void:
	if sombrero_visual == null:
		return
	quitar_sombrero()
	var raiz := Node3D.new()
	raiz.name = "Pieza"
	if tipo_sombrero == "sombrero":
		AccesoriosPaloma._cilindro(raiz, 0.16, 0.16, 0.014, Vector3(0.0, 0.507, 0.09), color_sombrero)
		AccesoriosPaloma._cilindro(raiz, 0.085, 0.095, 0.1, Vector3(0.0, 0.565, 0.09), color_sombrero)
		AccesoriosPaloma._cilindro(raiz, 0.097, 0.097, 0.02, Vector3(0.0, 0.53, 0.09), color_sombrero.darkened(0.45))
	else:
		AccesoriosPaloma._caja(raiz, Vector3(0.215, 0.05, 0.215), Vector3(0.0, 0.525, 0.1), color_sombrero)
		AccesoriosPaloma._caja(raiz, Vector3(0.17, 0.014, 0.1), Vector3(0.0, 0.512, 0.255), color_sombrero.darkened(0.25))
	sombrero_visual.add_child(raiz)


func quitar_sombrero() -> void:
	if sombrero_visual == null:
		return
	for n in sombrero_visual.get_children():
		sombrero_visual.remove_child(n)
		n.queue_free()


## Aplica una configuración de colores y accesorios (ver PerfilPaloma). Con un perfil vacío o null
## la paloma queda como viene del GLB.
func aplicar_perfil(perfil: PerfilPaloma) -> void:
	if _glb == null:
		return
	AplicadorPaloma.aplicar(_glb, _skel, perfil)
	var gestos := _skel.get_node_or_null("Gestos") as GestosPaloma   # Los párpados siguen el color de la cabeza
	if gestos:
		gestos.refrescar_material()
	_mostrar_accesorios(not _congelada)


## La paloma de la jugadora sigue al perfil en uso: si la pantalla de personalizar lo cambia,
## se ve al instante (en el menú, en la vista previa y en los créditos).
func _al_cambiar_perfil() -> void:
	aplicar_perfil(PerfilPaloma.actual())


## Se pintó sobre el perfil en uso: la textura de pintura se actualiza en el lugar.
func _al_pintar() -> void:
	if _glb:
		AplicadorPaloma.actualizar_pintura(_glb, PerfilPaloma.actual())


## Modo pintura de "Mi paloma": la paloma queda quieta en su pose de reposo (sin animación, gestos
## ni accesorios) para que lo pintado coincida con lo que se ve.
func congelar(si: bool) -> void:
	if _glb == null or _congelada == si:
		return
	_congelada = si
	_anim.active = not si
	_anim_accion.active = not si
	var gestos := _skel.get_node_or_null("Gestos") as GestosPaloma
	if gestos:
		gestos.pausar(si)
	if si:
		_skel.reset_bone_poses()
	_mostrar_accesorios(not si)


func _mostrar_accesorios(si: bool) -> void:
	for n in _skel.get_children():
		if n.name.begins_with(AplicadorPaloma.PREFIJO):
			(n as Node3D).visible = si


## Distancia máxima a la que se dibuja esta paloma NPC (la cambia Ajustes según la calidad).
func aplicar_distancia(d: float) -> void:
	_distancia2 = d * d
	for m in _mallas:
		m.visibility_range_end = d
		m.visibility_range_end_margin = 2.0


func _process(delta: float) -> void:
	if _baile != &"":
		var antes := fmod(_t_baile, Coreografia.duracion(_baile))
		_t_baile += delta
		_aplicar_baile()
		# El cortejo tiene su momento: cada vez que el baile pasa por ahí (una vez por vuelta)
		if _baile == &"cortejo":
			var ahora := fmod(_t_baile, Coreografia.duracion(_baile))
			if antes < Coreografia.MOMENTO_CORTEJO and ahora >= Coreografia.MOMENTO_CORTEJO:
				cortejo_logrado.emit()
		return
	_avanzar_animacion(delta)


## ¿Está bailando?
func bailando() -> bool:
	return _baile != &""


## Un aletazo con el ala izquierda o la derecha (se agrega el modificador la primera vez).
func aletazo(con_izquierda: bool) -> void:
	if _skel == null:
		return
	if _aletazo == null:
		_aletazo = AletazoPaloma.new()
		_aletazo.name = "Aletazo"
		_skel.add_child(_aletazo)
	_aletazo.golpear(con_izquierda)


## El baile en curso (&"" si no baila).
func baile_actual() -> StringName:
	return _baile


## Empieza un baile de Coreografia (el mismo de los créditos): se apaga la animación del GLB y se giran
## los huesos y el cuerpo a mano. Sólo para la paloma de la jugadora. Se repite hasta dejar_de_bailar.
func bailar(baile: StringName) -> void:
	if not (es_jugador or permite_baile) or _glb == null:
		return
	if _baile == &"":
		_reposo = PoseBaile.reposo_de(_skel)
		_anim.active = false
		_anim_accion.active = false
		_glb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # Se mueve en _process
		_skel.reset_bone_poses()
		set_process(true)
	_baile = baile
	_t_baile = 0.0
	_aplicar_baile()


## Se estrelló contra una pared: se aplasta contra ella un instante y queda mareada "dur" segundos,
## tambaleándose de un lado a otro con un halo de estrellitas sobre la cabeza. Sólo la jugadora.
func aturdir(dur: float) -> void:
	if not es_jugador or _glb == null:
		return
	dejar_de_bailar()
	calmar()
	_glb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # Se mueve con un tween
	_halo = EfectoChoque.halo()
	_halo.position = Vector3(0.0, 0.62, 0.0)
	add_child(_halo)
	scale = Vector3(1.4, 0.65, 1.4)      # Aplastada contra la pared...
	_tween_aturdida = create_tween().set_parallel()
	_tween_aturdida.tween_property(self, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween_aturdida.tween_property(_halo, "rotation:y", TAU * dur * 0.9, dur)
	# ...y después se tambalea cada vez menos
	var vaiven := create_tween()
	var amplitud := 0.5
	var pasos := maxi(int(dur / 0.3), 2)
	for i in pasos:
		var lado := 1.0 if i % 2 == 0 else -1.0
		vaiven.tween_property(_glb, "rotation:z", lado * amplitud * (1.0 - float(i) / pasos), 0.3).set_trans(Tween.TRANS_SINE)
	vaiven.tween_callback(calmar)
	_tween_vaiven = vaiven


## Termina el mareo: vuelve a la pose normal y se va el halo.
func calmar() -> void:
	if _tween_aturdida and _tween_aturdida.is_valid():
		_tween_aturdida.kill()
	if _tween_vaiven and _tween_vaiven.is_valid():
		_tween_vaiven.kill()
	if is_instance_valid(_halo):
		_halo.queue_free()
	_halo = null
	if _glb != null and _baile == &"":
		_glb.rotation.z = 0.0
		_glb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT


func dejar_de_bailar() -> void:
	if _baile == &"":
		return
	_baile = &""
	_glb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	_glb.position = Vector3.ZERO
	_glb.basis = Basis(Vector3.UP, PI)
	_skel.reset_bone_poses()
	_anim.active = not _congelada
	_anim_accion.active = not _congelada
	set_process(not es_jugador)


func _aplicar_baile() -> void:
	var p := Coreografia.pose(_baile, fmod(_t_baile, Coreografia.duracion(_baile)))
	# La pose está pensada para un modelo que mira a +Z (hacia la cámara); acá el GLB va girado PI
	var giro_glb := Basis(Vector3.UP, PI)
	var centro := Vector3(0.0, 0.25, 0.0)
	_glb.basis = giro_glb * p.rot
	_glb.position = centro + giro_glb * p.pos - _glb.basis * centro
	p.aplicar_a(_skel, _reposo)


## Avanza la animación cada 1, 2, 4 u 8 cuadros según la distancia a la cámara (con el tiempo
## acumulado, así nada se atrasa). Fuera de cuadro o más lejos que la distancia de dibujo, cada 16.
func _avanzar_animacion(delta: float) -> void:
	_anim_acum += delta
	var cuadro := Engine.get_process_frames()
	if cuadro != _cam_cuadro:
		_cam_cuadro = cuadro
		_cam = get_viewport().get_camera_3d()
		if _cam:
			_cam_pos = _cam.global_position
	var cada := 1
	if _cam:
		var p := global_position
		var d2 := p.distance_squared_to(_cam_pos)
		if d2 > _distancia2 or not _cam.is_position_in_frustum(p):
			cada = 16
		elif d2 > 900.0:
			cada = 8 if d2 > 2500.0 else 4
		elif d2 > 144.0:
			cada = 2
	if (cuadro + _anim_desfase) % cada != 0:
		return
	_anim.advance(_anim_acum)
	if _accion != "":
		_anim_accion.advance(_anim_acum)
	_anim_acum = 0.0


## Transform de "hijo" relativo a su ancestro "ancestro".
func _relativo(ancestro: Node3D, hijo: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = hijo
	while n != ancestro and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


# ---------------------------------------------------------------- Animación

## Llamar cada frame de física.
## modo: 0 = suelo, 1 = aleteando, 2 = planeando, 3 = picada
func animar(_delta: float, modo: int, velocidad_suelo: float) -> void:
	var base := "Idle"
	var vel := 1.0
	match modo:
		0:
			if velocidad_suelo > 0.15:
				base = "Walk"
				# Pasitos rápidos con cabeceo: más rápido cuanto más camina
				vel = clampf((3.0 + velocidad_suelo * 2.2) / 3.0, 0.8, 2.8)
		1:
			base = "Fly"
		2:
			base = "Glide"
		3:
			base = "Dive"
	if _accion != "" and modo != 0:
		# Despegó: se corta el picoteo/arrullo
		_accion = ""
		_anim_accion.stop()
	# La base (caminar, aletear...) sigue siempre: el picoteo y el arrullo van aparte, encima
	_reproducir_base(base, vel)


func _reproducir_base(nombre: String, vel: float, mezcla := MEZCLA) -> void:
	if nombre != _base or _anim.current_animation != nombre:
		_base = nombre
		_anim.play(nombre, mezcla)
	_anim.speed_scale = vel


func _accion_unica(nombre: String, vel: float) -> void:
	if _base not in ["Idle", "Walk"]:
		return  # En el aire no picotea ni arrulla con el cuerpo (el efecto del juego igual ocurre)
	_accion = nombre
	_anim_accion.play(nombre)
	_anim_accion.seek(0.0, true)
	_anim_accion.speed_scale = vel
	_anim_acum = 0.0


func _al_terminar_animacion(nombre: StringName) -> void:
	if String(nombre) == _accion:
		_accion = ""


## Un segundo AnimationPlayer para el picoteo y el arrullo. Esas animaciones del GLB mueven todos los
## huesos, y como un AnimationPlayer reproduce una sola animación a la vez, al arrullar caminando las
## patas se quedaban quietas. Acá se usan copias sin las pistas de las patas y se reproducen encima
## de la base: el cuerpo hace el gesto y las patas siguen caminando. Va después del otro en el árbol
## para que lo que mueve (cabeza, alas, cola, cuerpo) pise a la base.
func _armar_acciones() -> void:
	if _acciones_sin_patas == null:
		_acciones_sin_patas = AnimationLibrary.new()
		for nombre in ["Peck", "Coo"]:
			var copia := _anim.get_animation(nombre).duplicate() as Animation
			for i in range(copia.get_track_count() - 1, -1, -1):
				var pista := String(copia.track_get_path(i))
				if pista.ends_with(":leg_L") or pista.ends_with(":leg_R"):
					copia.remove_track(i)
			_acciones_sin_patas.add_animation(nombre, copia)
	_anim_accion = AnimationPlayer.new()
	_anim_accion.name = "Acciones"
	_glb.add_child(_anim_accion)
	_anim_accion.add_animation_library("", _acciones_sin_patas)
	_anim_accion.animation_finished.connect(_al_terminar_animacion)


## Agrega los gestos de paloma quieta (mirada, parpadeo, picoteo y arrullo ocasionales) que se
## usan en el menú principal. "mirar_a" es la cámara a la que mira de vez en cuando.
func agregar_gestos(mirar_a: Node3D) -> GestosPaloma:
	var g := GestosPaloma.new()
	g.name = "Gestos"
	g.mirar_a = mirar_a
	g.modelo = self
	_skel.add_child(g)
	return g


func picotear() -> void:
	_accion_unica("Peck", 1.8 if es_jugador else 1.0)


func arrullar() -> void:
	_accion_unica("Coo", 1.0)


## Muestra (o esconde) la comida que lleva en el pico.
func mostrar_carga(tipo: String) -> void:
	for h in carga_visual.get_children():
		h.queue_free()
	AplicadorPaloma.pico_visible(_skel, tipo == "")   # Los accesorios del pico no tapan la comida
	match tipo:
		"medialuna":
			var m := _pieza(_esfera(0.08), Color("d9a24a"), Vector3(1.6, 0.6, 0.8))
			m.rotation.y = 0.3
		"papa":
			_pieza(_caja(Vector3(0.04, 0.04, 0.2)), Color("f2d36b"))
		"factura":
			_pieza(_esfera(0.07), Color("c97b3a"), Vector3(1.4, 0.7, 1.0))
		"asado":
			_pieza(_caja(Vector3(0.1, 0.06, 0.22)), Color("9a4a2a"))
			_pieza(_caja(Vector3(0.11, 0.015, 0.05)), Color("f2ead8")).position = Vector3(0, 0, 0.12)


func _pieza(malla: Mesh, color: Color, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.8)
	mi.scale = escala
	carga_visual.add_child(mi)
	return mi


func _esfera(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 5
	return m


func _caja(t: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = t
	return m
