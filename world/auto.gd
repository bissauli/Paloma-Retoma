class_name Auto
extends Node3D
## Un vehículo low-poly de la avenida: auto particular, taxi (negro y amarillo) o colectivo.
## Lo mueve world/transito.gd. Tiene un cuerpo cinemático (capa de la gente) para que la paloma
## de la jugadora choque contra él, y le pasa dos círculos a la bandada para que las NPC lo esquiven.

const CAPA_GENTE := 4
const COLORES := [Color("c8372d"), Color("2b4f8a"), Color("e8e4dc"), Color("8c9196"), Color("3f6b47"),
	Color("2a2a2e"), Color("d9a24a"), Color("6b8fb8")]

var tipo := "auto"
var sentido := 1.0            ## +1 va hacia el este (+X), -1 hacia el oeste
var largo := 4.2
var ancho := 1.8
var alto := 1.45
var velocidad := 0.0
var velocidad_crucero := 11.0
var bocina_enfriamiento := 0.0

var _ruedas: Array[Node3D] = []


## Elige tipo y color al azar (llamar antes de agregarlo al árbol).
func preparar(dir: float) -> void:
	sentido = dir
	var r := randf()
	if r < 0.1:
		tipo = "colectivo"
	elif r < 0.35:
		tipo = "taxi"
	else:
		tipo = "auto"
	match tipo:
		"colectivo":
			largo = 10.5
			ancho = 2.5
			alto = 3.0
			velocidad_crucero = randf_range(7.5, 9.0)
		"taxi":
			velocidad_crucero = randf_range(11.0, 13.5)
		_:
			largo = randf_range(3.9, 4.6)
			velocidad_crucero = randf_range(9.5, 12.5)
	velocidad = velocidad_crucero


func _ready() -> void:
	add_to_group("autos")
	rotation.y = 0.0 if sentido > 0.0 else PI
	if tipo == "colectivo":
		_armar_colectivo()
	else:
		_armar_auto()
	_cuerpo_fisico()


func _process(delta: float) -> void:
	# Las ruedas giran según la velocidad
	var giro := velocidad * delta / 0.33
	for w in _ruedas:
		w.rotate_object_local(Vector3.UP, -giro)


## Dos círculos (adelante y atrás) que las palomas NPC no pueden pisar: [centro, radio, alto].
func circulos() -> Array:
	var adelante := Vector3(sentido, 0, 0)
	var r := ancho * 0.55
	var off := largo / 2.0 - r
	return [[global_position + adelante * off, r, alto], [global_position - adelante * off, r, alto]]


## Punto de la trompa (para frenar y para espantar palomas).
func trompa() -> float:
	return global_position.x + sentido * largo / 2.0


# ---------------------------------------------------------------- Armado

func _cuerpo_fisico() -> void:
	var cuerpo := AnimatableBody3D.new()
	cuerpo.sync_to_physics = false
	cuerpo.collision_layer = CAPA_GENTE
	cuerpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(largo, alto - 0.15, ancho)
	cs.shape = forma
	cs.position.y = 0.15 + (alto - 0.15) / 2.0
	cuerpo.add_child(cs)
	add_child(cuerpo)


## Sólo las piezas grandes (carrocería y cabina) proyectan sombra: las chicas casi no se notan
## y cada una sumaría un dibujo más por cada corte de la sombra.
func _caja(tam: Vector3, pos: Vector3, color: Color, rugosidad := 0.6, sombra := false) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Construir.material(color, rugosidad)
	mi.position = pos
	if not sombra:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _rueda(pos: Vector3, radio: float) -> void:
	var pivote := Node3D.new()
	pivote.position = pos
	pivote.rotation.x = PI / 2.0
	add_child(pivote)
	var cm := CylinderMesh.new()
	cm.top_radius = radio
	cm.bottom_radius = radio
	cm.height = 0.24
	cm.radial_segments = 8
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = Construir.material(Color("1a1a1c"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(mi)
	# Llanta clara para que se note el giro
	var llanta := BoxMesh.new()
	llanta.size = Vector3(radio * 1.2, 0.26, radio * 0.35)
	var ml := MeshInstance3D.new()
	ml.mesh = llanta
	ml.material_override = Construir.material(Color("9ea3a8"))
	ml.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(ml)
	_ruedas.append(pivote)


func _armar_auto() -> void:
	var color: Color = COLORES[randi() % COLORES.size()]
	if tipo == "taxi":
		color = Color("1c1c1e")
	var vidrio := Color("2b3644")
	# Carrocería baja, cabina con vidrios y techo
	_caja(Vector3(largo, 0.62, ancho), Vector3(0, 0.56, 0), color, 0.45, true)
	var largo_cabina := largo * 0.52
	var x_cabina := -largo * 0.06
	_caja(Vector3(largo_cabina, 0.5, ancho * 0.9), Vector3(x_cabina, 1.11, 0), vidrio, 0.2, true)
	var techo := Color("f2c230") if tipo == "taxi" else color
	_caja(Vector3(largo_cabina * 0.92, 0.07, ancho * 0.86), Vector3(x_cabina, 1.39, 0), techo, 0.45)
	# Parantes
	for x in [-1.0, 1.0]:
		_caja(Vector3(0.1, 0.5, ancho * 0.92), Vector3(x_cabina + x * largo_cabina / 2.0, 1.11, 0), color, 0.45)
	if tipo == "taxi":
		_caja(Vector3(0.45, 0.16, 0.22), Vector3(x_cabina, 1.5, 0), Color("f2c230"))
		# Puertas amarillas (el taxi porteño: negro con techo y puertas amarillas)
		for z in [-1.0, 1.0]:
			_caja(Vector3(largo * 0.5, 0.32, 0.02), Vector3(-largo * 0.05, 0.62, z * (ancho / 2.0 + 0.005)),
				Color("f2c230"), 0.45)
	# Luces
	for z in [-1.0, 1.0]:
		_caja(Vector3(0.05, 0.14, 0.32), Vector3(largo / 2.0, 0.66, z * ancho * 0.32), Color("fff3c4"), 0.2)
		_caja(Vector3(0.05, 0.14, 0.3), Vector3(-largo / 2.0, 0.66, z * ancho * 0.32), Color("b3221a"), 0.2)
	# Paragolpes
	_caja(Vector3(0.12, 0.14, ancho * 1.02), Vector3(largo / 2.0, 0.34, 0), Color("3a3a3e"))
	_caja(Vector3(0.12, 0.14, ancho * 1.02), Vector3(-largo / 2.0, 0.34, 0), Color("3a3a3e"))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_rueda(Vector3(x * largo * 0.32, 0.33, z * (ancho / 2.0 - 0.08)), 0.33)


func _armar_colectivo() -> void:
	var colores := [[Color("e0c341"), Color("2d6fb3")], [Color("e8e4dc"), Color("c8372d")], [Color("3f8a5a"), Color("f2f2ee")]]
	var par: Array = colores[randi() % colores.size()]
	var base: Color = par[0]
	var franja: Color = par[1]
	_caja(Vector3(largo, alto - 0.35, ancho), Vector3(0, 0.35 + (alto - 0.35) / 2.0, 0), base, 0.5, true)
	# Ventanillas corridas y franja
	_caja(Vector3(largo * 0.86, 0.85, ancho + 0.02), Vector3(-largo * 0.04, 2.05, 0), Color("2b3644"), 0.2)
	_caja(Vector3(largo + 0.01, 0.22, ancho + 0.02), Vector3(0, 1.2, 0), franja, 0.5)
	# Parabrisas y cartel de línea
	_caja(Vector3(0.04, 1.3, ancho * 0.9), Vector3(largo / 2.0, 1.95, 0), Color("2b3644"), 0.2)
	_caja(Vector3(0.05, 0.28, ancho * 0.6), Vector3(largo / 2.0 + 0.01, 2.78, 0), Color("ffb347"), 0.3)
	for z in [-1.0, 1.0]:
		_caja(Vector3(0.05, 0.16, 0.3), Vector3(largo / 2.0, 0.75, z * ancho * 0.36), Color("fff3c4"), 0.2)
		_caja(Vector3(0.05, 0.2, 0.25), Vector3(-largo / 2.0, 0.85, z * ancho * 0.38), Color("b3221a"), 0.2)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_rueda(Vector3(x * largo * 0.33, 0.45, z * (ancho / 2.0 - 0.1)), 0.45)
