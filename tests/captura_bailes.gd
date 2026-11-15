extends Control
## Contact sheets de los bailes de los créditos (NO headless): una imagen por baile con la paloma en
## varios instantes. Sirve para afinar las coreografías sin esperar a que pasen en tiempo real.
## godot --path . --resolution 1280x720 res://tests/captura_bailes.tscn -- <carpeta> [baile]

const ANCHO := 420
const ALTO := 520
const CUADROS := 8


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var carpeta := args[0] if args.size() > 0 else "user://capturas"
	DirAccess.make_dir_recursive_absolute(carpeta)
	var solo := StringName(args[1]) if args.size() > 1 else &""
	var b := Bailarina.new()
	b.position = Vector2.ZERO
	b.size = Vector2(ANCHO, ALTO)
	add_child(b)
	await get_tree().process_frame
	var bailes: Array[StringName] = Coreografia.ORDEN.duplicate()
	bailes.append(Coreografia.FINAL)
	for baile in bailes:
		if solo != &"" and baile != solo:
			continue
		var dur := Coreografia.duracion(baile)
		var hoja := Image.create(ANCHO * CUADROS, ALTO, false, Image.FORMAT_RGBA8)
		hoja.fill(Color(0.18, 0.22, 0.3))
		for k in CUADROS:
			var t := dur * (k + 0.5) / CUADROS
			b.ver(String(baile), "Gris", baile, t)
			for i in 3:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			hoja.blit_rect(img, Rect2i(0, 0, ANCHO, ALTO), Vector2i(k * ANCHO, 0))
		hoja.save_png(carpeta.path_join("baile_%s.png" % baile))
		print("BAILE ", baile, " ok")
	get_tree().quit()
