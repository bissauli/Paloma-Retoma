extends Node3D
## Catálogo de accesorios en fotos (NO headless):
## godot --path . res://tests/captura_accesorios.tscn -- <carpeta_salida>
## Una foto por slot: una grilla de palomas, cada una con una opción del slot puesta.

const COLUMNAS := 4
const PASO := 0.62

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("bfe0f5")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.7, 0.72, 0.78)
	entorno.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = entorno
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 150, 0)
	sol.light_energy = 0.9
	add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.current = true

	for slot in CatalogoPaloma.SLOTS.size():
		var n := CatalogoPaloma.cantidad_opciones(slot) - 1
		var modelos: Array[ModeloPaloma] = []
		var filas := ceili(float(n) / COLUMNAS)
		for i in n:
			var m := ModeloPaloma.new()
			add_child(m)
			var col := i % COLUMNAS
			var fila := i / COLUMNAS
			m.position = Vector3((col - (COLUMNAS - 1) / 2.0) * PASO, (filas - 1 - fila) * 0.62, 0)
			# El modelo mira a -Z (hacia la cámara); la espalda se ve mejor de atrás
			var clave: String = CatalogoPaloma.SLOTS[slot]["clave"]
			# Los ojos están a los costados de la cabeza: las gafas se ven mejor más de perfil
			m.rotation.y = deg_to_rad(200 if clave in ["espalda", "cola"] else (50 if clave in ["ojos", "pico"] else 25))
			var p := PerfilPaloma.new()
			p.accesorios[slot] = i + 1
			m.aplicar_perfil(p)
			modelos.append(m)
		var centro_y := (filas - 1) * 0.62 / 2.0 + 0.35
		cam.position = Vector3(0.3, centro_y + 0.5, -2.2 - filas * 0.55)
		cam.look_at(Vector3(0, centro_y, 0))
		for f in 12:
			for m in modelos:
				m.animar(0.016, 0, 0.0)
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(salida.path_join("slot_%d_%s.png" % [slot, CatalogoPaloma.SLOTS[slot]["clave"]]))
		print("foto ", CatalogoPaloma.SLOTS[slot]["clave"])
		for m in modelos:
			m.queue_free()
		await get_tree().process_frame

	# Combinaciones de cerca: [cabeza, espalda, cola, pico, ojos, cuello]
	var combos := [
		[9, 4, 0, 0, 0, 0],    # Asesino: capucha y capa
		[8, 5, 0, 0, 1, 6],    # Gaucho: sombrero, termo y mate, gafas de sol, pañuelo
		[6, 6, 0, 0, 3, 2],    # Realeza: corona, alas, lentes redondos, perlas
		[13, 0, 0, 0, 7, 1],   # Trapera: auriculares, visor, cadena de oro
	]
	var modelos: Array[ModeloPaloma] = []
	for i in combos.size():
		var m := ModeloPaloma.new()
		add_child(m)
		m.position = Vector3((i - 1.5) * 0.62, 0, 0)
		m.rotation.y = deg_to_rad(20)
		var p := PerfilPaloma.new()
		var c: Array = combos[i]
		for s in c.size():
			p.accesorios[s] = int(c[s])
		m.aplicar_perfil(p)
		modelos.append(m)
	cam.fov = 30.0
	cam.position = Vector3(0.25, 0.75, -2.4)
	cam.look_at(Vector3(0, 0.38, 0))
	for f in 12:
		for m in modelos:
			m.animar(0.016, 0, 0.0)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(salida.path_join("combos.png"))
	get_tree().quit()
