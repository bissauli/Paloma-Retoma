class_name OpcionesMenu
extends PantallaMenu
## Pantalla de OPCIONES (layout de la referencia de ajustes): título y VOLVER a la izquierda,
## y a la derecha las secciones AUDIO, PANTALLA y CONTROLES.
## Todo se guarda en el autoload Ajustes. Se usa en el menú principal y en la pausa.

const BUSES := [[&"Musica", "Música"], [&"Voces", "Voz"], [&"Efectos", "Efectos"]]

var _volumen: HSlider
var _volumen_txt: Label
var _buses: Dictionary = {}      ## bus -> [HSlider, Label]
var _silencio: CheckButton
var _brillo: HSlider
var _brillo_txt: Label
var _calidad: OptionButton
var _resolucion: OptionButton
var _resoluciones: Array[Vector2i] = []
var _fps: OptionButton
var _pantalla: CheckBox
var _comic: CheckBox
var _sensibilidad: HSlider
var _sensibilidad_txt: Label
var _invertir: CheckBox
var _ultimo_sonido := 0


func _init() -> void:
	armar("Opciones")

	# ---------------------------------------------------------------- Audio
	seccion("Audio")
	_volumen = deslizador(0.0, 100.0, 5.0)
	_volumen_txt = Label.new()
	fila("General", _volumen, _volumen_txt)
	_volumen.value_changed.connect(func(v: float) -> void:
		Ajustes.set_volumen(v / 100.0)
		_volumen_txt.text = _porcentaje(v))
	for b: Array in BUSES:
		var bus: StringName = b[0]
		var s := deslizador(0.0, 100.0, 5.0)
		var t := Label.new()
		fila(b[1], s, t)
		_buses[bus] = [s, t]
		s.value_changed.connect(func(v: float) -> void:
			Ajustes.set_volumen_bus(bus, v / 100.0)
			t.text = _porcentaje(v)
			_muestra_de(bus))
	_silencio = CheckButton.new()
	_silencio.text = "SILENCIAR TODO"
	_silencio.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fila("", _silencio)
	_silencio.toggled.connect(func(on: bool) -> void: Ajustes.set_silencio(on))

	# ---------------------------------------------------------------- Pantalla
	seccion("Pantalla")
	_brillo = deslizador(Ajustes.BRILLO_MIN * 100.0, Ajustes.BRILLO_MAX * 100.0, 5.0)
	_brillo_txt = Label.new()
	fila("Brillo", _brillo, _brillo_txt)
	_brillo.value_changed.connect(func(v: float) -> void:
		Ajustes.set_brillo(v / 100.0)
		_brillo_txt.text = _porcentaje(v))
	_calidad = desplegable()
	fila("Calidad", _calidad)
	for c: String in Ajustes.CALIDADES:
		_calidad.add_item(c.to_upper())
	_calidad.item_selected.connect(Ajustes.set_calidad)
	_resolucion = desplegable()
	fila("Resolución", _resolucion)
	_resolucion.item_selected.connect(func(i: int) -> void:
		if i >= 0 and i < _resoluciones.size():
			Ajustes.set_resolucion(_resoluciones[i]))
	_fps = desplegable()
	fila("Límite de FPS", _fps)
	for f: int in Ajustes.LIMITES_FPS:
		_fps.add_item(Ajustes.nombre_limite_fps(f).to_upper())
	_fps.tooltip_text = "Con un número fijo se desactiva el VSync"
	_fps.item_selected.connect(func(i: int) -> void: Ajustes.set_limite_fps(Ajustes.LIMITES_FPS[i]))
	_comic = CheckBox.new()
	fila("Estilo cómic", _comic)
	_comic.tooltip_text = "Sombras con trama de puntos y contorno de tinta"
	_comic.toggled.connect(Ajustes.set_estilo_comic)
	_pantalla = CheckBox.new()
	fila("Pantalla completa", _pantalla)
	_pantalla.toggled.connect(func(on: bool) -> void:
		Ajustes.set_pantalla_completa(on)
		_refrescar_resoluciones.call_deferred())

	# ---------------------------------------------------------------- Controles
	seccion("Controles")
	_sensibilidad = deslizador(25.0, 200.0, 5.0)
	_sensibilidad_txt = Label.new()
	fila("Sensibilidad", _sensibilidad, _sensibilidad_txt)
	_sensibilidad.value_changed.connect(func(v: float) -> void:
		Ajustes.set_sensibilidad(v / 100.0)
		_sensibilidad_txt.text = _porcentaje(v))
	_invertir = CheckBox.new()
	fila("Invertir eje Y", _invertir)
	_invertir.toggled.connect(Ajustes.set_invertir_y)
	for casilla: BaseButton in [_silencio, _comic, _pantalla, _invertir]:
		casilla.toggled.connect(func(on: bool) -> void: AudioManager.ui("click_in" if on else "click_out", -8.0))


func abrir() -> void:
	_refrescar()
	super.abrir()


## Pone los controles como están los ajustes, sin disparar señales.
func _refrescar() -> void:
	_volumen.set_value_no_signal(Ajustes.volumen * 100.0)
	_volumen_txt.text = _porcentaje(Ajustes.volumen * 100.0)
	for bus: StringName in _buses:
		var v := Ajustes.volumen_bus(bus) * 100.0
		(_buses[bus][0] as HSlider).set_value_no_signal(v)
		(_buses[bus][1] as Label).text = _porcentaje(v)
	_silencio.set_pressed_no_signal(Ajustes.silencio)
	_brillo.set_value_no_signal(Ajustes.brillo * 100.0)
	_brillo_txt.text = _porcentaje(Ajustes.brillo * 100.0)
	_pantalla.set_pressed_no_signal(DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN)
	_sensibilidad.set_value_no_signal(Ajustes.sensibilidad * 100.0)
	_sensibilidad_txt.text = _porcentaje(Ajustes.sensibilidad * 100.0)
	_invertir.set_pressed_no_signal(Ajustes.invertir_y)
	_comic.set_pressed_no_signal(Ajustes.estilo_comic)
	_calidad.select(Ajustes.calidad)
	_fps.select(maxi(Ajustes.LIMITES_FPS.find(Ajustes.limite_fps), 0))
	_refrescar_resoluciones()


func _refrescar_resoluciones() -> void:
	_resoluciones = Ajustes.resoluciones_disponibles()
	if not _resoluciones.has(Ajustes.resolucion):
		_resoluciones.append(Ajustes.resolucion)
	_resolucion.clear()
	var ventana: bool = Ajustes.resolucion_cambia_ventana()
	for r in _resoluciones:
		if r == Vector2i.ZERO:
			_resolucion.add_item("NATIVA")
		else:
			_resolucion.add_item("%d x %d" % [r.x, r.y])
	_resolucion.select(_resoluciones.find(Ajustes.resolucion))
	_resolucion.tooltip_text = "Tamaño de la ventana" if ventana \
		else "En pantalla completa (o en el navegador) el 3D se dibuja a esta resolución"


## Un sonido de muestra al mover el volumen de voces o efectos (como mucho cada 0,3 s).
func _muestra_de(bus: StringName) -> void:
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_sonido < 300:
		return
	_ultimo_sonido = ahora
	if bus == &"Voces":
		AudioManager.reproducir("arrullo", -6.0)
	elif bus == &"Efectos":
		AudioManager.reproducir("picoteo")


static func _porcentaje(v: float) -> String:
	return "%d %%" % roundi(v)
