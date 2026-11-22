extends CanvasLayer
## Contador de FPS arriba a la izquierda (autoload "ContadorFps"). F3 lo muestra u oculta.
## Línea 1: FPS (promedio del último segundo). Línea 2: el cuadro más lento de ese segundo (los tirones
## se ven ahí aunque el promedio sea alto) y los draw calls. Los números se ponen verdes / amarillos / rojos.
## (El ajuste automático de calidad por FPS vive en Ajustes._vigilar_fps.)

var _label: Label
var _acum := 0.0
var _cuadros := 0
var _peor := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(6, 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_acum += delta
	_cuadros += 1
	_peor = maxf(_peor, delta)
	if _acum < 0.5:
		return
	var fps := _cuadros / _acum
	var llamadas := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_label.text = tr("%d FPS\npeor %.0f ms · %d draws") % [roundi(fps), _peor * 1000.0, llamadas]
	_label.add_theme_color_override("font_color", _color(fps))
	_acum = 0.0
	_cuadros = 0
	_peor = 0.0


func _color(fps: float) -> Color:
	if fps >= 55.0:
		return Color("7dff9a")
	if fps >= 40.0:
		return Color("ffe36b")
	return Color("ff6b6b")
