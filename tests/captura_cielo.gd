extends Node
## Capturas del cielo a distintas horas y climas (NO headless):
## godot --path . res://tests/captura_cielo.tscn -- <carpeta_salida> [caso1,caso2...]

## nombre: [hora, clima, vista (desde, hacia), extra]
const CASOS := {
	"amanecer": [6.1, Cielo.Clima.DESPEJADO, "este"],
	"maniana": [8.5, Cielo.Clima.DESPEJADO, "plaza"],
	"mediodia": [12.5, Cielo.Clima.DESPEJADO, "aerea"],
	"nublado": [11.0, Cielo.Clima.NUBLADO, "plaza"],
	"lluvia": [14.0, Cielo.Clima.LLUVIA, "calle"],
	"tormenta": [15.0, Cielo.Clima.TORMENTA, "plaza", "rayo"],
	"arcoiris": [16.0, Cielo.Clima.DESPEJADO, "este", "arcoiris"],
	"atardecer": [18.4, Cielo.Clima.DESPEJADO, "oeste"],
	"crepusculo": [19.4, Cielo.Clima.DESPEJADO, "oeste"],
	"noche": [23.0, Cielo.Clima.DESPEJADO, "plaza"],
	"noche_calle": [1.0, Cielo.Clima.DESPEJADO, "calle"],
	"noche_lluvia": [2.0, Cielo.Clima.LLUVIA, "aerea"],
}
const VISTAS := {
	"plaza": [Vector3(0, 4, 32), Vector3(0, 30, -90)],
	"aerea": [Vector3(0, 60, 130), Vector3(0, 0, -40)],
	"calle": [Vector3(-80, 2.2, -2), Vector3(-170, 8, -2)],
	"este": [Vector3(-40, 6, 0), Vector3(60, 25, 10)],
	"oeste": [Vector3(10, 5, 30), Vector3(-90, 22, 20)],
}

var salida := "user://"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	var solo: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var cam := Camera3D.new()
	cam.far = 400.0
	cam.fov = 70.0
	add_child(cam)
	await _frames(30)
	GameState.menu_activo = false
	cam.current = true
	_esconder_interfaz(get_tree().root)
	var cielo := get_tree().get_first_node_in_group("sol").get_parent() as Cielo
	for nombre: String in CASOS:
		if not solo.is_empty() and not solo.has(nombre):
			continue
		var c: Array = CASOS[nombre]
		GameState.hora_dia = c[0]
		cielo.forzar_clima(c[1], true)
		var v: Array = VISTAS[c[2]]
		cam.global_position = v[0]
		cam.look_at(v[1])
		var extra: String = c[3] if c.size() > 3 else ""
		if extra == "arcoiris":
			cielo.mostrar_arcoiris()
			cielo.set("_arcoiris_t", 40.0)
		await _frames(20)
		if extra == "rayo":
			cielo.set("_t_rayo", 0.0)
			GameState.en_partida = true
			await _frames(3)
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
		print("captura: ", nombre)
	get_tree().quit()


func _esconder_interfaz(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_esconder_interfaz(h)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
