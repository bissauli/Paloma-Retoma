extends Node
## Capturas de la ciudad desde varios puntos de vista (NO headless). Sin el HUD ni los menús.
## godot --path . res://tests/captura_ciudad.tscn -- <carpeta_salida> [vista1,vista2...] [segundos de espera]
## (la espera deja que la gente, los chicos y los animales se pongan en movimiento antes de las fotos)

const VISTAS := {
	"aerea": [Vector3(0, 150, 215), Vector3(0, 0, -15)],
	"gente_catedral": [Vector3(1, 1.7, -11.5), Vector3(2, 0.7, -18)],
	"gente_cabildo": [Vector3(-30.5, 1.6, -5), Vector3(-36, 0.8, -8)],
	"gente_plaza": [Vector3(-12, 3.0, 8), Vector3(-2, 0.8, -6)],
	"fuente_cerca": [Vector3(-140, 6.5, -52.5), Vector3(-140, 0.8, -61)],
	"cantero_cerca": [Vector3(-130.5, 2.4, -51.5), Vector3(-134.3, 0.6, -55.3)],
	"mesas_pasaje": [Vector3(-46, 2.2, 49), Vector3(-36, 0.8, 52)],
	"cenital": [Vector3(0, 330, 0.1), Vector3(0, 0, 0)],
	"plaza": [Vector3(0, 70, 75), Vector3(0, 0, 0)],
	"parque_aereo": [Vector3(-95, 65, 5), Vector3(-140, 0, -61)],
	"zona_palomas": [Vector3(-168, 5, -79), Vector3(-179, 2.5, -94)],
	"juegos": [Vector3(-88, 7, -70), Vector3(-101, 1, -91)],
	"rombo": [Vector3(-124, 6, -44), Vector3(-140, 1, -61)],
	"perros": [Vector3(-140, 6, -12), Vector3(-168, 0, -30)],
	"bolt": [Vector3(-185.2, 1.6, -59.5), Vector3(-190.5, 0.4, -61)],
	"bolivar": [Vector3(-68, 1.6, 18), Vector3(-69, 2.5, -60)],
	"rivadavia": [Vector3(55, 1.8, -48), Vector3(-20, 3, -48)],
	"av_de_mayo": [Vector3(-80, 2.2, -2), Vector3(-170, 3, -2)],
	"peatonal": [Vector3(-80, 1.8, 58), Vector3(-150, 2, 58)],
	"pasaje": [Vector3(-55, 1.6, 51), Vector3(10, 2.5, 51)],
	"comercial": [Vector3(-55, 28, 25), Vector3(-137, 5, 58)],
	"barrio": [Vector3(100, 24, 22), Vector3(140, 0, 75)],
	"potrero": [Vector3(110, 3.5, 66), Vector3(140, 0.5, 68)],
	"paseo_colon": [Vector3(69, 1.8, -15), Vector3(70, 3, -100)],
	"reconquista": [Vector3(80, 1.8, -6), Vector3(180, 3, -6)],
	"sur": [Vector3(0, 32, 38), Vector3(0, 5, 85)],
	"esquina": [Vector3(-66.5, 1.7, -39), Vector3(-48, 7, -60)],
	"techos": [Vector3(30, 40, -60), Vector3(120, 10, -80)],
	# Vistas altas en diagonal, como las referencias del mapa V3
	"iso_hospital": [Vector3(45, 38, -30), Vector3(82, 4, -66)],
	"iso_comercial": [Vector3(-105, 34, 22), Vector3(-138, 3, 56)],
	"iso_cancha": [Vector3(-88, 30, -12), Vector3(-110, 0, -37)],
	"iso_rivadavia": [Vector3(22, 26, -24), Vector3(-2, 2, -50)],
	"iso_juegos": [Vector3(-82, 26, -70), Vector3(-101, 0, -91)],
	"iso_reconquista": [Vector3(66, 30, 8), Vector3(120, 2, -8)],
	# Corazones de manzana, fondos de los edificios y balcones
	"manzana_norte": [Vector3(-38, 34, -66), Vector3(0, 0, -86)],
	"manzana_este": [Vector3(100, 38, -30), Vector3(140, 0, -66)],
	"manzana_comercial": [Vector3(-90, 30, 30), Vector3(-140, 0, 30)],
	"balcones": [Vector3(-20, 14, -38), Vector3(-20, 12, -60)],
	"perros_cerca": [Vector3(-160, 4, -18), Vector3(-170, 0, -30)],
	"juegos_cerca": [Vector3(-102, 4.5, -82), Vector3(-104, 1.2, -95)],
	"dueños": [Vector3(-147, 2.2, -30), Vector3(-154, 0.5, -36)],
	"gatos": [Vector3(116, 9, 20), Vector3(124, 4, 30)],
}

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var solo: PackedStringArray = args[1].split(",") if args.size() > 1 and args[1] != "" else PackedStringArray()
	var espera := float(args[2]) if args.size() > 2 else 0.0
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	await _frames(30)
	if espera > 0.0:
		Engine.time_scale = 4.0
		await get_tree().create_timer(espera).timeout
		Engine.time_scale = 1.0
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
