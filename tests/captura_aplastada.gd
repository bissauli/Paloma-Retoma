extends Node
## Fotos de la paloma atropellada (NO headless): antes, chata en el piso y al inflarse de nuevo.
## godot --path . res://tests/captura_aplastada.tscn -- <carpeta_salida>

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var paloma := main.get_node("Paloma") as PalomaJugador
	await _frames(40)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	paloma.global_position = Vector3(-20, 0.3, 30)
	paloma.reset_physics_interpolation()
	await _frames(40)
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = paloma.global_position + Vector3(1.1, 0.8, 1.3)
	cam.look_at(paloma.global_position + Vector3(0, 0.12, 0))
	cam.current = true
	await _frames(10)
	_foto("1_antes")
	paloma.aplastar()
	await get_tree().create_timer(0.6).timeout
	_foto("2_chata")
	await get_tree().create_timer(PalomaJugador.DURACION_APLASTADA - 0.6 + 0.06).timeout
	_foto("3_boing")
	get_tree().quit()


func _foto(nombre: String) -> void:
	get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
