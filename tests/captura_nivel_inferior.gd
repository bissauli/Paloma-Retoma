extends Node
## Capturas del nivel inferior (Fase 1: pasajes, galería, mercado, subte, mobiliario y obra) (NO headless):
## godot --path . res://tests/captura_nivel_inferior.tscn -- <carpeta_salida>

const VISTAS := {
	"pasajes": [Vector3(-12, 7, 28), Vector3(-12, 2, 42)],
	"pasaje_adentro": [Vector3(2.5, 1.4, 36.5), Vector3(2.5, 1.6, 46)],
	"galeria": [Vector3(-34, 7, 34), Vector3(-52, 2, 20)],
	"galeria_adentro": [Vector3(-46, 1.3, 21), Vector3(-58, 2.2, 21)],
	"mercado": [Vector3(42, 5, 30), Vector3(31, 1, 21)],
	"subte": [Vector3(40, 4, -15), Vector3(34, -1, -23)],
	"subte_escalera": [Vector3(34, 1.6, -18.5), Vector3(34, -1.5, -25)],
	"mobiliario": [Vector3(-68, 3, 14), Vector3(-62, 0.5, 0)],
	"obra": [Vector3(70, 4, -76), Vector3(62, 0.5, -90)],
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
