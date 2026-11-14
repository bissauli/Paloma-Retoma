class_name OpcionesMenu
extends VentanaMenu
## Menú de opciones básico: volumen, sonido, pantalla completa y mouse.
## Todo se guarda en el autoload Ajustes.

var _volumen: HSlider
var _volumen_txt: Label
var _sonido: CheckButton
var _pantalla: CheckButton
var _sensibilidad: HSlider
var _sensibilidad_txt: Label
var _invertir: CheckButton


func _init() -> void:
	armar("Opciones")
	var r := _fila_deslizador("Volumen", 0.0, 100.0, 5.0)
	_volumen = r[0]
	_volumen_txt = r[1]
	_volumen.value_changed.connect(func(v: float) -> void:
		Ajustes.set_volumen(v / 100.0)
		_volumen_txt.text = "%d %%" % roundi(v))
	_sonido = _casilla("Sonido activado")
	_sonido.toggled.connect(func(on: bool) -> void: Ajustes.set_silencio(not on))
	_pantalla = _casilla("Pantalla completa")
	_pantalla.toggled.connect(Ajustes.set_pantalla_completa)
	r = _fila_deslizador("Sensibilidad del mouse", 25.0, 200.0, 5.0)
	_sensibilidad = r[0]
	_sensibilidad_txt = r[1]
	_sensibilidad.value_changed.connect(func(v: float) -> void:
		Ajustes.set_sensibilidad(v / 100.0)
		_sensibilidad_txt.text = "%d %%" % roundi(v))
	_invertir = _casilla("Invertir eje vertical de la cámara")
	_invertir.toggled.connect(Ajustes.set_invertir_y)


func abrir() -> void:
	_refrescar()
	super.abrir()


## Pone los controles como están los ajustes, sin disparar señales.
func _refrescar() -> void:
	_volumen.set_value_no_signal(Ajustes.volumen * 100.0)
	_volumen_txt.text = "%d %%" % roundi(Ajustes.volumen * 100.0)
	_sonido.set_pressed_no_signal(not Ajustes.silencio)
	_pantalla.set_pressed_no_signal(DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN)
	_sensibilidad.set_value_no_signal(Ajustes.sensibilidad * 100.0)
	_sensibilidad_txt.text = "%d %%" % roundi(Ajustes.sensibilidad * 100.0)
	_invertir.set_pressed_no_signal(Ajustes.invertir_y)


func _fila_deslizador(texto: String, minimo: float, maximo: float, paso: float) -> Array:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = texto
	l.custom_minimum_size = Vector2(270, 0)
	fila.add_child(l)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = paso
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(160, 24)
	fila.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(70, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila.add_child(v)
	contenido.add_child(fila)
	return [s, v]


func _casilla(texto: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = texto
	contenido.add_child(c)
	return c
