extends Node
## Prueba automática del choque contra una pared a toda velocidad (corre headless):
## godot --headless --path . res://tests/test_choque.tscn
## En picada (más de VELOCIDAD_CHOQUE) la paloma se estrella: polvo en el golpe, rebota, queda
## aturdida sin control y se recupera. Volando normal o rozando la pared no pasa nada.

var fallas := 0
var _j: PalomaJugador
var _pared: StaticBody3D


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_choque.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	_j = main.get_node("Paloma")
	_pared = StaticBody3D.new()
	_pared.collision_layer = Construir.CAPA_MUNDO
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(60, 200, 2)
	cs.shape = caja
	_pared.add_child(cs)
	main.add_child(_pared)
	_pared.global_position = Vector3(0, 300, -214)     # Muy arriba de la ciudad, sin nada alrededor

	# 1) A velocidad normal de vuelo: no se estrella
	var choques: Array[float] = []
	_j.choco.connect(func(i: float) -> void: choques.append(i))
	await _volar_hacia_la_pared(10.0, false)
	_check("a velocidad normal de vuelo no se estrella", choques.is_empty() and _j._aturdida <= 0.0)

	# 2) En picada contra la pared: se estrella
	await _volar_hacia_la_pared(20.0, true)
	_check("en picada se estrella", choques.size() == 1 and choques[0] >= PalomaJugador.VELOCIDAD_CHOQUE)
	_check("queda aturdida", _j._aturdida > 0.5)
	_check("rebota hacia atrás (se aleja de la pared)", _j.velocity.z > 0.0)
	_check("hay polvo en el golpe", main.get_node_or_null("PolvoChoque") != null)
	_check("el modelo muestra el halo de estrellas", _j.modelo.get_node_or_null("HaloAturdida") != null)
	Input.action_press("mover_adelante")
	await _frames(10)
	_check("mareada no controla la paloma", _j.velocity.z >= -0.01)
	Input.action_release("mover_adelante")

	# 3) Se le pasa
	await get_tree().create_timer(PalomaJugador.DURACION_ATURDIDA + 0.4).timeout
	_check("se recupera del mareo", _j._aturdida <= 0.0)
	_check("se va el halo", _j.modelo.get_node_or_null("HaloAturdida") == null)
	_check("vuelve a poder controlarse", _j.controlable and _j.modelo._glb.rotation.z == 0.0)
	_check("no se choca dos veces con el mismo golpe", choques.size() == 1)
	Input.action_release("picada")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Pone a la paloma en el aire mirando a la pared y la lanza contra ella a esa velocidad.
func _volar_hacia_la_pared(velocidad: float, picada: bool) -> void:
	_j._aturdida = 0.0
	_j.estado = PalomaJugador.Estado.AIRE
	_j.floor_snap_length = 0.0
	_j._rumbo = 0.0                     # Mira hacia -Z, donde está la pared
	_j.global_position = Vector3(0, 300, -204)
	_j.velocity = Vector3(0, 0, -velocidad)
	_j.reset_physics_interpolation()
	if picada:
		Input.action_press("picada")
	else:
		Input.action_release("picada")
	await _frames(60)
	Input.action_release("picada")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
