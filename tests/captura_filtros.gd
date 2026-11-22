extends Node
## Saca una captura de cada filtro de los ajustes súper secretos (y del estilo pixel) desde la misma
## vista (NO headless). No guarda nada en las opciones.
## godot --path . res://tests/captura_filtros.tscn -- <carpeta_salida>

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	add_child(load("res://main.tscn").instantiate())
	var cam := Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	await _frames(30)
	cam.current = true
	_esconder_interfaz(get_tree().root)
	cam.global_position = Vector3(-168, 5, -79)
	cam.look_at(Vector3(-179, 2.5, -94))
	cam.fov = 70.0
	Ajustes.filtro = -1
	Ajustes.estilo_pixel = true
	Ajustes.estilo_comic = false
	EstiloComic.aplicar()
	Filtros.aplicar()
	await _frames(10)
	_guardar("00_pixel")
	Ajustes.estilo_pixel = false
	for i in Filtros.LISTA.size():
		Ajustes.filtro = i
		Filtros.aplicar()
		await _frames(4)
		_guardar("%02d_%s" % [i + 1, String(Filtros.LISTA[i][1]).get_file().get_basename()])
	get_tree().quit()


func _guardar(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	print("captura: ", nombre)


func _esconder_interfaz(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and h != Filtros:
			(h as CanvasLayer).visible = false
		_esconder_interfaz(h)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
