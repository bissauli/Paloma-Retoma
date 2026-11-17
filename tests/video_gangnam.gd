extends Control
## Las variantes del baile del caballito (Coreografia.VARIANTES_GANGNAM) lado a lado, en una grilla,
## bailando a la vez con la música 8 bits, para elegir la mejor. Se graba con el escritor de video:
## godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie <salida.avi> res://tests/video_gangnam.tscn
## (dos vueltas del baile: 16 s). Con "-- solo" baila sólo la variante elegida (Coreografia.variante_gangnam), grande.

const COLUMNAS := 3
const VUELTAS := 2

var _bailarinas: Array[Bailarina] = []
var _t := 0.0
var _elegida := 0


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.16, 0.22)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var solo := "solo" in OS.get_cmdline_user_args()
	_elegida = Coreografia.variante_gangnam
	var n := 1 if solo else Coreografia.VARIANTES_GANGNAM.size()
	var columnas := 1 if solo else COLUMNAS
	var filas := ceili(float(n) / columnas)
	var tam := Vector2(get_viewport_rect().size.x / columnas, get_viewport_rect().size.y / filas)
	for i in n:
		var b := Bailarina.new()
		b.position = Vector2(i % columnas, i / columnas) * tam
		b.size = tam
		add_child(b)
		_bailarinas.append(b)
	await get_tree().process_frame
	for i in n:
		Coreografia.variante_gangnam = i if _bailarinas.size() > 1 else _elegida
		_bailarinas[i].ver(String(Coreografia.VARIANTES_GANGNAM[Coreografia.variante_gangnam]["nombre"]), "Gris", &"gangnam", 0.0)
	AudioManager.musica_baile(true)


func _process(delta: float) -> void:
	if _bailarinas.is_empty():
		return
	_t += delta
	var t := fmod(_t, Coreografia.duracion(&"gangnam"))
	for i in _bailarinas.size():
		Coreografia.variante_gangnam = i if _bailarinas.size() > 1 else _elegida
		_bailarinas[i]._aplicar(Coreografia.pose(&"gangnam", t))
	Coreografia.variante_gangnam = _elegida
	# Con una carpeta como argumento, además saca fotos en algunos instantes (para revisar sin video)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] != "solo":
		for instante in [0.5, 3.0, 4.6]:
			if _t - delta < instante and _t >= instante:
				get_viewport().get_texture().get_image().save_png(args[0].path_join("gangnam_%.1f.png" % instante))
	if _t >= Coreografia.duracion(&"gangnam") * VUELTAS:
		get_tree().quit()
