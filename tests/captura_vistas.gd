extends Node
## Capturas de vistas sueltas (NO headless). Sin vistas saca las de los niveles medio y alto (Fases 2 y 3):
## godot --path . res://tests/captura_vistas.tscn -- <carpeta_salida> [nombre:x,y,z:x,y,z ...]
## (cada vista: nombre, posición de la cámara y punto al que mira).

const VISTAS := {
	"aerea": [Vector3(0, 150, 215), Vector3(0, 0, -15)],
	"balcones": [Vector3(20, 12, -42), Vector3(-15, 9, -58)],
	"cafes": [Vector3(-10, 9, 25), Vector3(-10, 8, 40)],
	"arboles_plaza": [Vector3(0, 12, -5), Vector3(-25, 7, -26)],
	"peatonal": [Vector3(-80, 9, 58), Vector3(-150, 4, 58)],
	"torre_norte": [Vector3(-20, 45, -20), Vector3(-53, 40, -64)],
	"torre_este": [Vector3(40, 40, 10), Vector3(85, 35, -22)],
	"torre_oeste": [Vector3(-50, 40, 30), Vector3(-85, 40, 14)],
	"desde_mirador": [Vector3(-58, 61, -60), Vector3(0, 0, 0)],
	"cables_av_de_mayo": [Vector3(-120, 10, -12), Vector3(-160, 7, 0)],
	"cables_reconquista": [Vector3(120, 12, -25), Vector3(150, 6, -1)],
}

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var vistas := VISTAS.duplicate()
	if args.size() > 0:
		salida = args[0]
	if args.size() > 1:
		vistas.clear()
		for a: String in args.slice(1):
			var p := a.split(":")
			var d := p[1].split_floats(",")
			var m := p[2].split_floats(",")
			vistas[p[0]] = [Vector3(d[0], d[1], d[2]), Vector3(m[0], m[1], m[2])]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 900.0
	add_child(cam)
	await _frames(20)
	cam.current = true
	for nombre: String in vistas:
		var v: Array = vistas[nombre]
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP if absf((v[1] - v[0]).normalized().y) < 0.99 else Vector3.FORWARD)
		await _frames(8)
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
