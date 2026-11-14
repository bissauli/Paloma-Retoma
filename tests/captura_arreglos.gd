extends Node
## Capturas de los arreglos (escalinata, letreros, comensales, tránsito, viento) y una prueba de
## que las palomas NPC no atraviesan paredes (NO headless):
## godot --path . res://tests/captura_arreglos.tscn -- <carpeta_salida>

const VISTAS := {
	"escalinata": [Vector3(19, 3.5, -16), Vector3(4, 1, -24)],
	"escalinata_frente": [Vector3(-3, 1.6, -15), Vector3(0, 1.5, -26)],
	"cafes_letreros": [Vector3(-8, 3.2, 27.5), Vector3(-8, 2.5, 38)],
	"comensales": [Vector3(-24, 2.2, 30.5), Vector3(-30, 0.8, 35)],
	"avenida_semaforo": [Vector3(-2, 4, 21), Vector3(5, 1.5, 30)],
	"cabildo_torre": [Vector3(-30, 11, 0), Vector3(-45, 12, 0)],
	"vista_alta": [Vector3(0, 40, 60), Vector3(0, 0, 0)],
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
	await _prueba_paredes()
	cam.current = true
	# Dejar que lleguen comensales y autos
	await _frames(240)
	for nombre: String in VISTAS:
		var v: Array = VISTAS[nombre]
		cam.global_position = v[0]
		cam.look_at(v[1])
		await _frames(8)
		get_viewport().get_texture().get_image().save_png(salida.path_join(nombre + ".png"))
	await _captura_viento()
	get_tree().quit()


## Una paloma NPC que quiere caminar hacia adentro de la Catedral y otra que vuela hacia una pared:
## ninguna debe terminar adentro.
func _prueba_paredes() -> void:
	var bandada := get_tree().get_first_node_in_group("jugador").get_parent().get_node("Bandada") as Bandada
	var p := bandada.ESCENA_PALOMA.instantiate() as PalomaNPC
	bandada.add_child(p)
	p.global_position = Vector3(3, 2.0, -27.5)
	p.altura_suelo = 2.0
	p.configurar_zona(Vector3(3, 2.0, -38.0), 0.1)   # La zona está adentro del edificio
	var q := bandada.ESCENA_PALOMA.instantiate() as PalomaNPC
	bandada.add_child(q)
	q.global_position = Vector3(-30, 4.0, 30.0)
	q.soltar(Vector3(-30, 4.0, 25.0))                 # Sale volando hacia el sur (hacia el café)
	q.ir_a_zona(Vector3(-30, 0, 45.0), 0.1)
	await _frames(400)
	print("PRUEBA_PAREDES caminando z=%.2f (pared en z=-31, debe ser > -31)" % p.global_position.z)
	print("PRUEBA_PAREDES volando z=%.2f (fachada en z=38, debe ser < 38)" % q.global_position.z)
	p.queue_free()
	q.queue_free()


## Simula un vuelo rápido para ver las líneas de viento con la cámara de la paloma.
func _captura_viento() -> void:
	var j := get_tree().get_first_node_in_group("jugador") as PalomaJugador
	j.controlable = false
	j.global_position = Vector3(0, 14, 20)
	j.estado = PalomaJugador.Estado.AIRE
	j.camara.set("yaw", 0.0)
	var cam_j := j.get_node("CamaraOrbital/Brazo/Camara") as Camera3D
	cam_j.current = true
	for i in 50:
		j.velocity = Vector3(0, 0.5, -17)
		await get_tree().physics_frame
	get_viewport().get_texture().get_image().save_png(salida.path_join("viento.png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
