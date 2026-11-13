extends Node
## Capturas del mapa desde varios puntos de vista (NO headless):
## godot --path . res://tests/captura_mapa.tscn -- <carpeta_salida>

const VISTAS := {
	"mapa_general": [Vector3(0, 70, 75), Vector3(0, 0, 0)],
	"cabildo": [Vector3(-25, 8, 6), Vector3(-50, 6, 0)],
	"catedral": [Vector3(4, 5, -6), Vector3(0, 8, -30)],
	"cafes": [Vector3(4, 5, 22), Vector3(4, 3, 38)],
	"casa_rosada": [Vector3(22, 9, 6), Vector3(42, 7, 0)],
	"subte": [Vector3(26, 6, -8), Vector3(34, 0, -22)],
}

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 500.0
	add_child(cam)
	await _frames(20)
	cam.current = true
	for nombre: String in VISTAS:
		var v: Array = VISTAS[nombre]
		cam.global_position = v[0]
		cam.look_at(v[1])
		await _frames(8)
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
