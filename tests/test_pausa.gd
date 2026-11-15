extends Node
## Prueba automática de la pausa con las Opciones (corre headless, y con ventana saca una captura):
## godot --headless --path . res://tests/test_pausa.tscn
## Con las Opciones abiertas no deben verse el título ni los botones de la pausa (se leían encima).

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_pausa.cfg"   # No toca las opciones del jugador
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	var pausa: Node = main.get_node("Pausa")
	var centro: Control = pausa.get_node("Centro")
	var hud: CanvasLayer = main.get_node("HUD")
	hud.visible = true
	pausa.pausar()
	_check("al pausar se ven el título y los botones", centro.visible and pausa.visible)
	pausa._abrir_opciones()
	_check("con las Opciones abiertas se esconde también el HUD", not hud.visible)
	for i in 30:
		await get_tree().process_frame
	_check("con las Opciones abiertas se esconden", not centro.visible and pausa._opciones.visible)
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://capturas/pausa_opciones.png")
	pausa._opciones.cerrar()
	_check("al cerrar las Opciones vuelven los botones y el HUD", centro.visible and hud.visible)
	# Si el HUD ya estaba escondido (una cinemática), las Opciones no lo muestran al cerrar
	hud.visible = false
	pausa._abrir_opciones()
	pausa._opciones.cerrar()
	_check("un HUD que ya estaba escondido sigue escondido", not hud.visible)
	hud.visible = true
	pausa._abrir_opciones()
	pausa.continuar()
	_check("continuar con las Opciones abiertas cierra todo", not pausa.visible and not get_tree().paused)
	pausa.pausar()
	_check("la próxima pausa muestra los botones", centro.visible)
	pausa.continuar()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
