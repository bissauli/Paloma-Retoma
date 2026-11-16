extends Node3D
## Escena para validar shaders/estilo_cozy.gdshader: personaje, gato, edificio, árbol y props
## bajo una DirectionalLight3D y un WorldEnvironment con luz ambiente.
## Abrirla en el editor alcanza. Para sacar una captura (NO headless):
## godot --path . res://tests/prueba_estilo.tscn -- <carpeta_salida>


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return
	for i in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args[0].path_join("prueba_estilo.png"))
	get_tree().quit()
