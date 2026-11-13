class_name ModeloPaloma
extends Node3D
## Modelo low-poly de paloma armado con primitivas, con animación procedural.
## Lo usan tanto la paloma del jugador como las NPC. Mira hacia -Z.

@export var color_cuerpo := Color("8b90a3")
@export var color_cabeza := Color("6f748a")
@export var color_cuello := Color("4f9a72")   ## Toque verde (o violeta) tornasolado
@export var color_alas := Color("9da2b3")
@export var es_jugador := false               ## La del jugador es un poco más flaca y despeinada

const C_NARANJA := Color("f08a24")
const C_NEGRO := Color("1a1a1a")
const C_PATAS := Color("e0645a")

static var _mallas := {}

var cabeza: Node3D
var cuello: MeshInstance3D
var cuerpo: MeshInstance3D
var ala_izq: Node3D
var ala_der: Node3D
var cola: MeshInstance3D
var carga_visual: Node3D

var _fase_paso := 0.0
var _fase_aleteo := 0.0
var _picoteo := 0.0       ## 0..1 animación de picotear
var _arrullo := 0.0       ## 0..1 animación de arrullar (inflar el pecho)
var _cabeza_base := Vector3.ZERO


func _ready() -> void:
	_armar()


# ---------------------------------------------------------------- Construcción

static func _malla_esfera(r: float) -> SphereMesh:
	var clave := "esf_%.3f" % r
	if not _mallas.has(clave):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 8
		m.rings = 5
		_mallas[clave] = m
	return _mallas[clave]


static func _malla_caja(t: Vector3) -> BoxMesh:
	var clave := "caja_%s" % t
	if not _mallas.has(clave):
		var m := BoxMesh.new()
		m.size = t
		_mallas[clave] = m
	return _mallas[clave]


func _pieza(padre: Node3D, malla: Mesh, color: Color, pos: Vector3, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = Construir.material(color, 0.8)
	mi.position = pos
	mi.scale = escala
	padre.add_child(mi)
	return mi


func _armar() -> void:
	var flaca := 0.85 if es_jugador else 1.0
	# Cuerpo: esfera achatada y alargada
	cuerpo = _pieza(self, _malla_esfera(0.22), color_cuerpo, Vector3(0, 0.27, 0.02), Vector3(0.85 * flaca, 0.75, 1.25))
	# Cuello tornasolado
	cuello = _pieza(self, _malla_esfera(0.13), color_cuello, Vector3(0, 0.38, -0.17), Vector3(1.0 * flaca, 1.0, 0.9))
	# Cola
	cola = _pieza(self, _malla_caja(Vector3(0.17, 0.035, 0.22)), color_cabeza, Vector3(0, 0.27, 0.33))
	cola.rotation.x = 0.25
	# Patitas
	if not _mallas.has("pata"):
		var cm := CylinderMesh.new()
		cm.top_radius = 0.016
		cm.bottom_radius = 0.016
		cm.height = 0.12
		cm.radial_segments = 5
		_mallas["pata"] = cm
	for lado in [-1.0, 1.0]:
		_pieza(self, _mallas["pata"], C_PATAS, Vector3(0.06 * lado, 0.06, 0.02))

	# Cabeza (pivote para el cabeceo y el picoteo)
	cabeza = Node3D.new()
	cabeza.name = "Cabeza"
	cabeza.position = Vector3(0, 0.44, -0.2)
	add_child(cabeza)
	_cabeza_base = cabeza.position
	_pieza(cabeza, _malla_esfera(0.1), color_cabeza, Vector3(0, 0.07, -0.04))
	# Pico: prisma naranja apuntando hacia adelante
	if not _mallas.has("pico"):
		var nuevo := PrismMesh.new()
		nuevo.size = Vector3(0.05, 0.09, 0.04)
		_mallas["pico"] = nuevo
	var pm: PrismMesh = _mallas["pico"]
	var pico := _pieza(cabeza, pm, C_NARANJA, Vector3(0, 0.05, -0.17))
	pico.rotation.x = -PI / 2.0
	# Ojos naranjas grandes con pupila
	for lado in [-1.0, 1.0]:
		_pieza(cabeza, _malla_esfera(0.036), C_NARANJA, Vector3(0.068 * lado, 0.1, -0.08))
		_pieza(cabeza, _malla_esfera(0.017), C_NEGRO, Vector3(0.094 * lado, 0.105, -0.095))
	if es_jugador:
		# Un mechón despeinado: la protagonista es flaca y medio desprolija
		var mechon := _pieza(cabeza, pm, color_cabeza, Vector3(0, 0.18, -0.02), Vector3(0.6, 0.8, 0.6))
		mechon.rotation.z = 0.4

	# Carga (medialuna/papa) que se ve en el pico
	carga_visual = Node3D.new()
	carga_visual.position = Vector3(0, 0.02, -0.22)
	cabeza.add_child(carga_visual)

	# Alas: pivote en el hombro, la caja se extiende hacia afuera
	ala_izq = _crear_ala(-1.0)
	ala_der = _crear_ala(1.0)

	if not es_jugador:
		# Las NPC no dibujan los detalles chiquitos (ojos, patas, pico) de lejos: ahorra mucho
		for mi in find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh.get_aabb().size.length() < 0.2:
				m.visibility_range_end = 26.0


func _crear_ala(lado: float) -> Node3D:
	var pivote := Node3D.new()
	pivote.position = Vector3(0.15 * lado, 0.34, 0.0)
	add_child(pivote)
	var ala := _pieza(pivote, _malla_caja(Vector3(0.4, 0.03, 0.26)), color_alas, Vector3(0.2 * lado, 0, 0.04))
	# Franja oscura típica de las alas de paloma
	_pieza(ala, _malla_caja(Vector3(0.3, 0.035, 0.04)), C_NEGRO.lightened(0.25), Vector3(0.02 * lado, 0, 0.06))
	return pivote


# ---------------------------------------------------------------- Animación

## Llamar cada frame de física.
## modo: 0 = suelo, 1 = aleteando, 2 = planeando, 3 = picada
func animar(delta: float, modo: int, velocidad_suelo: float) -> void:
	# --- Cabeceo al caminar: la cabeza va adelante rápido y vuelve lento ---
	var objetivo_cabeza := _cabeza_base
	if modo == 0 and velocidad_suelo > 0.15:
		_fase_paso += delta * (3.0 + velocidad_suelo * 2.2)
		var f := fmod(_fase_paso, 1.0)
		var empuje := smoothstep(0.0, 0.25, f) * (1.0 - smoothstep(0.35, 1.0, f))
		objetivo_cabeza += Vector3(0, -0.01 * empuje, -0.07 * empuje)
		cuerpo.position.y = 0.27 + absf(sin(_fase_paso * PI)) * 0.015
	else:
		cuerpo.position.y = lerpf(cuerpo.position.y, 0.27, delta * 8.0)
	cabeza.position = cabeza.position.lerp(objetivo_cabeza, minf(delta * 25.0, 1.0))

	# --- Picoteo: la cabeza baja de golpe ---
	if _picoteo > 0.0:
		_picoteo = maxf(_picoteo - delta * 4.0, 0.0)
		var k := sin(_picoteo * PI)
		cabeza.rotation.x = -1.1 * k
		cabeza.position.z -= 0.05 * k
	else:
		cabeza.rotation.x = lerpf(cabeza.rotation.x, 0.0, delta * 10.0)

	# --- Arrullo: se infla el pecho y la cabeza hace reverencias ---
	if _arrullo > 0.0:
		_arrullo = maxf(_arrullo - delta * 1.1, 0.0)
		var inflado := sin(_arrullo * PI)
		cuello.scale = Vector3.ONE * (1.0 + 0.45 * inflado)
		cabeza.rotation.x += sin(_arrullo * 18.0) * 0.25 * inflado
		cola.rotation.x = 0.25 - 0.6 * inflado
	else:
		cuello.scale = cuello.scale.lerp(Vector3.ONE, delta * 6.0)
		cola.rotation.x = lerpf(cola.rotation.x, 0.25, delta * 6.0)

	# --- Alas ---
	# Ángulos expresados para el ala derecha (+X): z > 0 levanta la punta, z < 0 la baja.
	# barrido > 0 lleva la punta hacia atrás. El ala izquierda es el espejo.
	var z_ala := 0.0
	var barrido := 0.0
	match modo:
		0: # Plegadas: barridas hacia atrás a lo largo del cuerpo
			z_ala = -0.75
			barrido = 1.35
		1: # Aleteo rápido
			_fase_aleteo += delta * 15.0
			z_ala = sin(_fase_aleteo) * 0.95 + 0.1
		2: # Planeo: abiertas con un leve temblor
			_fase_aleteo += delta * 3.0
			z_ala = 0.12 + sin(_fase_aleteo) * 0.06
		3: # Picada: medio plegadas y hacia atrás
			z_ala = -0.2
			barrido = 0.9
	var vel := 30.0 if modo == 1 else 12.0
	ala_der.rotation.z = lerp_angle(ala_der.rotation.z, z_ala, minf(delta * vel, 1.0))
	ala_izq.rotation.z = -ala_der.rotation.z
	ala_der.rotation.y = lerp_angle(ala_der.rotation.y, -barrido, minf(delta * 10.0, 1.0))
	ala_izq.rotation.y = -ala_der.rotation.y


func picotear() -> void:
	_picoteo = 1.0


func arrullar() -> void:
	_arrullo = 1.0


## Muestra (o esconde) la comida que lleva en el pico.
func mostrar_carga(tipo: String) -> void:
	for h in carga_visual.get_children():
		h.queue_free()
	match tipo:
		"medialuna":
			var m := _pieza(carga_visual, _malla_esfera(0.08), Color("d9a24a"), Vector3.ZERO, Vector3(1.6, 0.6, 0.8))
			m.rotation.y = 0.3
		"papa":
			_pieza(carga_visual, _malla_caja(Vector3(0.04, 0.04, 0.2)), Color("f2d36b"), Vector3.ZERO)
		"factura":
			_pieza(carga_visual, _malla_esfera(0.07), Color("c97b3a"), Vector3.ZERO, Vector3(1.4, 0.7, 1.0))
