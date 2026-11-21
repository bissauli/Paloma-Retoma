extends Node
## Capturas de carteles 3D (NO headless): arma el juego en español, cambia a inglés con el mundo ya
## armado (como el selector del menú) y fotografía de frente varios carteles. user://capturas/.
## godot --path . --resolution 1280x720 res://tests/captura_carteles_idioma.tscn -- [carpeta]

const TEXTOS := ["Panadería La Espiga", "DIARIOS Y REVISTAS", "Café La Medialuna Feliz", "SUBTE\nLínea Ñ",
	"L\nI\nB\nR\nO\nS", "Farmacia del Pasaje", "PEATONAL FLORIDA"]

var carpeta := "user://capturas"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		carpeta = args[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	Ajustes.ARCHIVO = "user://prueba_captura_carteles.cfg"
	Ajustes.idioma = ""
	Ajustes.set_idioma("es")
	var main: Node = load("res://main.tscn").instantiate()
	main.forzar_menu = true
	add_child(main)
	await _esperar(60)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 50.0
	for idioma in ["es", "en"]:
		Ajustes.set_idioma(idioma)
		await _esperar(5)
		for i in TEXTOS.size():
			var l := _buscar(main, TEXTOS[i])
			if l == null:
				print("no encontré: ", TEXTOS[i].c_escape())
				continue
			var frente := l.global_transform.basis.z.normalized()
			cam.global_position = l.global_position + frente * 3.5
			cam.look_at(l.global_position)
			cam.current = true
			await _esperar(8)
			print(idioma, " ", TEXTOS[i].c_escape(), " -> ", l.atr(l.text).c_escape())
			get_viewport().get_texture().get_image().save_png(carpeta.path_join("cartel_%s_%d.png" % [idioma, i]))
	Ajustes.set_idioma("es")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	get_tree().quit()


func _buscar(n: Node, texto: String) -> Label3D:
	if n is Label3D and (n as Label3D).text == texto and (n as Label3D).is_visible_in_tree():
		return n
	for h in n.get_children():
		var r := _buscar(h, texto)
		if r:
			return r
	return null


func _esperar(n: int) -> void:
	for i in n:
		await get_tree().process_frame
