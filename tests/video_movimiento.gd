extends Node
## Un recorrido armado de la paloma (caminar, doblar, despegar, aletear, planear doblando, picada,
## aterrizar y volver a caminar) para ver cómo se mueve. Se graba con el escritor de video:
## godot --path . --resolution 854x480 --fixed-fps 30 --write-movie <salida.avi> res://tests/video_movimiento.tscn

## [desde, hasta, acciones apretadas]
const GUION := [
	[1.0, 3.2, ["mover_adelante"]],
	[3.2, 4.6, ["mover_adelante", "mover_derecha"]],
	[4.6, 5.0, ["mover_adelante", "volar"]],
	[5.0, 7.0, ["mover_adelante", "volar"]],
	[7.0, 9.0, ["mover_adelante", "mover_izquierda"]],
	[9.0, 10.2, ["mover_adelante", "picada"]],
	[10.2, 12.5, ["mover_adelante"]],
	[13.5, 15.5, ["mover_adelante", "mover_derecha"]],
]
const FIN := 16.5

var _t := 0.0
var _apretadas := {}


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)


func _physics_process(delta: float) -> void:
	_t += delta
	var quiero := {}
	for paso: Array in GUION:
		if _t >= float(paso[0]) and _t < float(paso[1]):
			for a: String in paso[2]:
				quiero[a] = true
	for a in _apretadas.keys():
		if not _apretadas[a]:
			continue   # Las marcas de las fotos
		if not quiero.has(a):
			Input.action_release(a)
			_apretadas.erase(a)
	for a in quiero.keys():
		if not _apretadas.has(a):
			Input.action_press(a)
			_apretadas[a] = true
	if _t >= FIN:
		get_tree().quit()


## Con una carpeta como argumento, además saca fotos en algunos instantes (para revisar sin el video).
func _process(_delta: float) -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	for instante in [2.5, 4.2, 5.4, 8.0, 9.8, 12.7, 14.5]:
		var k := "f%.1f" % instante
		if _t >= instante and not _apretadas.has(k):
			_apretadas[k] = false
			get_viewport().get_texture().get_image().save_png(args[0].path_join("mov_%.1f.png" % instante))
