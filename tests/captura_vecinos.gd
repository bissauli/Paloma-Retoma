extends Node
## Capturas (NO headless) de cerca de cada vecino de los departamentos (world/vecinos.gd): de frente y
## un poco de costado, para ver cómo quedan sentados en sillas y sillones o parados frente a un mueble.
## godot --path . --resolution 1280x720 res://tests/captura_vecinos.tscn -- <carpeta>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas_vecinos"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 30:
		await get_tree().process_frame
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	var paloma := main.get_node_or_null("Paloma") as Node3D
	for v in get_tree().root.find_children("Vecinos", "Node3D", true, false):
		var ve := v as Vecinos
		if ve.ce.luz:
			ve.ce.luz.visible = true
		if paloma:
			var abajo := ve.ce.to_global(Vector3(0, 0, ve.ce.fondo / 2.0 + 8.0))
			paloma.global_position = Vector3(abajo.x, 0.5, abajo.z)
		var i := 0
		for m in ve.personas():
			var mira := -m.global_basis.z.normalized()   # El modelo mira hacia -Z
			var lado := Vector3.UP.cross(mira).normalized()
			var centro := m.global_position + Vector3.UP * (0.6 if m.sentado else 0.9)
			var hasta := centro + mira * 1.9 + lado * 0.9 + Vector3.UP * 0.55
			# Sin atravesar paredes (lo que está pegado a la persona, la mesa o la silla, no cuenta)
			var q := PhysicsRayQueryParameters3D.create(hasta, centro, Construir.CAPA_MUNDO)
			var r := get_viewport().world_3d.direct_space_state.intersect_ray(q)
			cam.global_position = hasta
			if r and (r["position"] as Vector3).distance_to(centro) > 1.2:
				# Mira contra una pared (el escritorio, la mesada): desde atrás y de costado
				cam.global_position = centro - mira * 1.6 + lado * 1.0 + Vector3.UP * 0.8
			cam.look_at(centro)
			for k in 12:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("%s_%d_%s.png" % [ve.tema, i, m.personaje]))
			i += 1
	get_tree().quit()
