extends CanvasLayer
## Contador de FPS arriba a la izquierda (autoload "ContadorFps"). F3 lo muestra u oculta.
## Línea 1: FPS (promedio del último segundo). Línea 2: el cuadro más lento de ese segundo (los tirones
## se ven ahí aunque el promedio sea alto) y los draw calls. Los números se ponen verdes / amarillos / rojos.
## Además baja solo la calidad gráfica un escalón si en partida el juego anda por debajo de FPS_MINIMO
## durante dos ventanas seguidas (PCs viejas, navegadores): no se vuelve a subir sola.

var _label: Label
var _acum := 0.0
var _cuadros := 0
var _peor := 0.0
var _v_acum := 0.0           ## Ventana de autoajuste (VENTANA_SEG)
var _v_cuadros := 0
var _v_peor := 0.0
var _v_bajas := 0
var _aviso_t := 0.0

const FPS_MINIMO := 38.0
const VENTANA_SEG := 4.0


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
	_autoajustar(delta)
	if _aviso_t > 0.0:
		_aviso_t -= delta
	if not visible:
		return
	_acum += delta
	_cuadros += 1
	_peor = maxf(_peor, delta)
	if _acum < 0.5:
		return
	var fps := _cuadros / _acum
	var llamadas := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_label.text = "%d FPS\npeor %.0f ms · %d draws" % [roundi(fps), _peor * 1000.0, llamadas]
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


## En partida (sin menú, pausa ni escenas) y con la ventana en foco: si el promedio de la ventana queda por
## debajo del mínimo dos veces seguidas, baja un escalón de calidad. Se ignoran las ventanas con un cuadro
## de más de 0,25 s (cargas, alt-tab) y si el jugador puso un límite de FPS bajo (no es culpa de la PC).
func _autoajustar(delta: float) -> void:
	var limite_ok := Ajustes.limite_fps == 0 or Ajustes.limite_fps >= 60 or Ajustes.limite_fps == -1
	var en_juego := GameState.en_partida and not GameState.menu_activo and not get_tree().paused 			and DisplayServer.window_is_focused() and Ajustes.calidad > 0 and limite_ok
	if not en_juego:
		_v_acum = 0.0
		_v_cuadros = 0
		_v_peor = 0.0
		_v_bajas = 0
		return
	_v_acum += delta
	_v_cuadros += 1
	_v_peor = maxf(_v_peor, delta)
	if _v_acum < VENTANA_SEG:
		return
	var fps := _v_cuadros / _v_acum
	if _v_peor > 0.25:
		_v_bajas = 0
	elif fps < FPS_MINIMO:
		_v_bajas += 1
	else:
		_v_bajas = 0
	_v_acum = 0.0
	_v_cuadros = 0
	_v_peor = 0.0
	if _v_bajas >= 2:
		_v_bajas = 0
		Ajustes.set_calidad(Ajustes.calidad - 1)
		_aviso_t = 8.0
		visible = true
