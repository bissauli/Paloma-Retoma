extends Node
## Capturas con y sin el modo cómic (cel duro + semitono + contorno de tinta), NO headless.
## godot --path . res://tests/captura_comic.tscn -- <carpeta_salida> [vista1,vista2...] [comic:0|1]
## Las vistas son las de tests/captura_ciudad.gd. Noche y lluvia: tests/captura_cielo.tscn (sale con el
## estilo que tenga Ajustes).
## Usa los mismos caminos que el juego (Ajustes.estilo_comic y EstiloComic) sin guardar nada.

const VISTAS: Dictionary = preload("res://tests/captura_ciudad.gd").VISTAS

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var solo: PackedStringArray = args[1].split(",") if args.size() > 1 and args[1] != "" else PackedStringArray()
	Ajustes.estilo_comic = args.size() <= 2 or args[2] != "0"
	Ajustes.calidad = 2
	EstiloComic.aplicar()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	await _frames(30)
	print("comic=", Ajustes.estilo_comic, " mallas con contorno=", EstiloComic.mallas_con_contorno())
	cam.current = true
	_esconder_interfaz(get_tree().root)
	for nombre: String in VISTAS:
		if not solo.is_empty() and not solo.has(nombre):
			continue
		var v: Array = VISTAS[nombre]
		cam.global_position = v[0]
		cam.look_at(v[1])
		cam.fov = 40.0 if nombre == "cenital" else 70.0
		await _frames(10)
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
		print("captura: ", nombre, " dibujos=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


func _esconder_interfaz(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_esconder_interfaz(h)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
