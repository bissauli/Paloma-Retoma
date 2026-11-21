extends Node3D
## Fotos de la gente nueva (NO headless):
## godot --path . res://tests/captura_personas.tscn -- <carpeta_salida>
## Todos parados, caminando, sentados, con los brazos arriba, sin sombrero y de cerca.

var salida := "user://"
var modelos: Array[ModeloHumano] = []
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("bfe0f5")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.75, 0.76, 0.8)
	entorno.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = entorno
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45, 25, 0)
	sol.light_energy = 0.95
	sol.shadow_enabled = true
	add_child(sol)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40, 20)
	suelo.mesh = plano
	suelo.material_override = Construir.material(Color("d8cbb4"))
	add_child(suelo)
	cam = Camera3D.new()
	cam.fov = 28.0
	add_child(cam)
	cam.current = true
	var nombres := ModeloHumano.personajes()
	nombres.sort()
	print("personajes: ", nombres.size())
	for i in nombres.size():
		var m := ModeloHumano.new()
		m.personaje = nombres[i]
		add_child(m)
		m.position = Vector3((i % 11 - 5) * 0.85, 0, (i / 11) * 1.6)
		modelos.append(m)
	# Color de vértice tal como llega (para ver si hay que pasarlo a sRGB)
	var mi := modelos[0].find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	print("color[0] = ", (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray)[0])
	await _foto("todos_frente", Vector3(0, 2.3, -11.5), Vector3(0, 0.9, 0.8), 0.0, false)
	await _foto("todos_caminando", Vector3(-4, 2.0, -10.5), Vector3(0, 0.9, 0.8), 1.4, false)
	await _foto("todos_atras", Vector3(0, 2.3, 13.5), Vector3(0, 0.9, 0.8), 0.0, false)
	for m in modelos:
		m.cambiar_postura(true)
	await _foto("todos_sentados", Vector3(0, 2.3, -11.5), Vector3(0, 0.7, 0.8), 0.0, false)
	for m in modelos:
		m.cambiar_postura(false)
		m.quitar_sombrero()
	await _foto("todos_brazos_arriba_sin_sombrero", Vector3(0, 2.3, -11.5), Vector3(0, 0.9, 0.8), 0.0, true)
	for m in modelos:
		m.devolver_sombrero()
	# De cerca, de a uno (los demás escondidos), de frente a 3/4 y la cara
	cam.fov = 30.0
	for m in modelos:
		m.visible = false
	for m in modelos:
		m.visible = true
		var p0 := m.position
		m.position = Vector3.ZERO
		for f in 40:
			m.animar(1.0 / 30.0, 0.0, false)
		var h := m.alto
		await _foto_de(m, "cerca_" + m.personaje, Vector3(-1.1 * h / 1.75, h * 0.62, -3.0 * h / 1.75), Vector3(0, h * 0.5, 0))
		await _foto_de(m, "cara_" + m.personaje, Vector3(-0.25, h * 0.93, -0.75), Vector3(0, h * 0.88, 0))
		await _foto_de(m, "espalda_" + m.personaje, Vector3(1.0 * h / 1.75, h * 0.62, 3.0 * h / 1.75), Vector3(0, h * 0.5, 0))
		m.cambiar_postura(true)
		await _foto_de(m, "sentado_" + m.personaje, Vector3(-1.6 * h / 1.75, h * 0.55, -2.4 * h / 1.75), Vector3(0, h * 0.32, 0))
		m.cambiar_postura(false)
		m.position = p0
		m.visible = false
	# Cuadros de una caminata (para armar un GIF): de costado, todos juntos en fila
	for i in modelos.size():
		var m := modelos[i]
		m.visible = true
		m.position = Vector3((i % 11 - 5) * 0.8, 0, (i / 11) * 1.5)
		m.rotation.y = -PI / 2.0
	cam.fov = 26.0
	cam.position = Vector3(1.5, 1.6, -15.0)
	cam.look_at(Vector3(0, 0.85, 0.75))
	for f in 36:
		for m in modelos:
			m.animar(1.0 / 24.0, 1.4, false)
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(salida.path_join("camina_%02d.png" % f))
	print("listo")
	get_tree().quit()


func _foto(nombre: String, pos: Vector3, mira: Vector3, vel: float, agitado: bool) -> void:
	cam.position = pos
	cam.look_at(mira)
	for f in 12:
		for m in modelos:
			m.animar(1.0 / 30.0, vel, agitado)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))


func _foto_de(m: ModeloHumano, nombre: String, pos: Vector3, mira: Vector3) -> void:
	cam.position = pos
	cam.look_at(mira)
	for f in 3:
		m.animar(0.01, 0.0)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
