extends Node
## Capturas de los edificios con locales (world/pasaje.gd) desde AFUERA (NO headless): de frente desde
## la vereda de enfrente, en diagonal desde cada lado, desde atrás y desde arriba. Para revisar que no
## quede nada fuera de lugar (carteles, toldos, gente o muebles que asoman por las paredes).
## godot --path . --resolution 1280x720 res://tests/captura_locales_afuera.tscn -- <carpeta> [segundos]
## "segundos": cuánto esperar con la paloma cerca antes de cada foto (para que la gente camine).

var paloma: PalomaJugador


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas_afuera"
	var seg := float(args[1]) if args.size() > 1 else 0.5
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma")
	await _frames(30)
	GameState.hora_dia = 13.0
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	for k in Edificios.ALREDEDORES.size():
		var e: Array = Edificios.ALREDEDORES[k]
		var base: Vector3 = e[0]
		var tam: Vector3 = e[1]
		var frente: Vector3 = e[3]
		var w := tam.x if absf(frente.z) > 0.5 else tam.z
		var d := tam.z if absf(frente.z) > 0.5 else tam.x
		var lado := frente.cross(Vector3.UP).normalized()
		var cara := base + frente * (d / 2.0)
		paloma.global_position = cara + frente * 4.0 + Vector3.UP * 0.3
		paloma.reset_physics_interpolation()
		paloma.velocity = Vector3.ZERO
		var vistas := [
			["frente", cara + frente * 13.0 + Vector3.UP * 3.0, cara + Vector3.UP * 3.5],
			["izq", cara + frente * 7.0 + lado * (w * 0.75) + Vector3.UP * 2.2, cara - lado * (w * 0.1) + Vector3.UP * 2.5],
			["der", cara + frente * 7.0 - lado * (w * 0.75) + Vector3.UP * 2.2, cara + lado * (w * 0.1) + Vector3.UP * 2.5],
			["atras", base - frente * (d / 2.0 + 10.0) + Vector3.UP * 4.0, base - frente * (d / 2.0) + Vector3.UP * 3.0],
			["arriba", base + frente * (d * 0.9) + Vector3.UP * (tam.y + 16.0), base + Vector3.UP * 2.0],
			["fachada", cara + frente * 30.0 + Vector3.UP * 14.0, cara + Vector3.UP * 12.0],
		]
		for vista: Array in vistas:
			cam.global_position = vista[1]
			cam.look_at(vista[2])
			await _frames(maxi(20, int(seg * 60.0)))
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("%d_%s.png" % [k, vista[0]]))
	get_tree().quit()


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
