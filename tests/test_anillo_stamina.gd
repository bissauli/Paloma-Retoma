extends Node
## Prueba automática del semi anillo de stamina (headless; con ventana también saca capturas en
## user://capturas/): godot --headless --path . res://tests/test_anillo_stamina.tscn
## Sólo se ve cuando la stamina no está llena y hasta 1,5 s después de llenarse.

var fallas := 0


func _ready() -> void:
	# 1) La lógica de cuándo se ve, sin mundo
	var a := AnilloStamina.new()
	add_child(a)
	a.actualizar_visibilidad(0.1)
	_check("con la stamina llena no se ve", not a.esta_visible())
	a._al_cambiar(60.0, 100.0)
	a.actualizar_visibilidad(0.2)
	_check("apenas baja, aparece", a.esta_visible())
	a._al_cambiar(100.0, 100.0)
	for i in 14:
		a.actualizar_visibilidad(0.1)         # 1,4 s llena
	_check("sigue visible 1,4 s después de llenarse", a.esta_visible())
	for i in 8:
		a.actualizar_visibilidad(0.1)         # 0,8 s más: ya pasaron 1,5 s y el fundido
	_check("se va después de 1,5 s llena", not a.esta_visible())
	a._al_cambiar(99.0, 100.0)
	a.actualizar_visibilidad(0.2)
	_check("si vuelve a gastar, reaparece", a.esta_visible())
	a._al_cambiar(100.0, 100.0)
	a.actualizar_visibilidad(1.0)
	a._al_cambiar(50.0, 100.0)
	a.actualizar_visibilidad(0.1)
	_check("gastar mientras se iba la hace volver", a.esta_visible())
	a.queue_free()

	# 2) En el juego: sigue a la paloma y queda dentro de la pantalla
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var hud: CanvasLayer = main.get_node("HUD")
	var anillo: AnilloStamina = hud.find_child("AnilloStamina", true, false)
	_check("el HUD tiene el anillo", anillo != null)
	var rotulos := hud.find_children("*", "Label", true, false).filter(func(l: Node) -> bool: return (l as Label).text == "STAMINA")
	_check("el HUD ya no tiene el rótulo de la barra de stamina de la esquina", rotulos.is_empty())
	GameState.set_stamina(55.0)
	for i in 20:
		await get_tree().process_frame
	_check("con 55 % se ve y sigue a la paloma", anillo.esta_visible() and anillo._en_pantalla)
	var pantalla := get_viewport().get_visible_rect()
	_check("queda dentro de la pantalla", pantalla.has_point(anillo._pos))
	_capturar("stamina_55")
	GameState.set_stamina(15.0)
	for i in 10:
		await get_tree().process_frame
	_capturar("stamina_baja")
	GameState.set_stamina(Config.STAMINA_MAX)
	await get_tree().create_timer(3.0).timeout     # Pasó el retardo (en tiempo real: los cuadros de la prueba son muy rápidos)
	_check("llena y pasado el retardo no se ve", not anillo.esta_visible())
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _capturar(nombre: String) -> void:
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("user://capturas")
		get_viewport().get_texture().get_image().save_png("user://capturas/%s.png" % nombre)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
