extends Node
## Muestra el HUD solo, sobre un fondo, con valores de ejemplo (para revisar el diseño).

func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("8fb8c9")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	var capa := CanvasLayer.new()
	capa.layer = 0
	capa.add_child(fondo)
	add_child(capa)
	add_child(preload("res://ui/hud.tscn").instantiate())
	await get_tree().process_frame
	GameState.bandada = 7
	GameState.bandada_cambio.emit(7)
	GameState.comida_cambio.emit(12)
	GameState.stamina_cambio.emit(Config.STAMINA_MAX * 0.6, Config.STAMINA_MAX)
	GameState.carga_cambio.emit("medialuna")
	GameState.objetivo_cambio.emit("Levantá el choripán de la avenida y juntá más palomas", 7, 15)
