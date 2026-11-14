extends Node
## Opciones del jugador (autoload "Ajustes"): volumen, silencio, pantalla completa y mouse.
## Se guardan en user://opciones.cfg y se aplican al arrancar.

signal cambio

const ARCHIVO := "user://opciones.cfg"

var volumen := 0.8              ## 0..1, lineal
var silencio := false
var pantalla_completa := false
var sensibilidad := 1.0         ## Multiplica la sensibilidad de la cámara (0,25..2)
var invertir_y := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar()
	_aplicar_audio()
	# En la web el navegador sólo deja pasar a pantalla completa después de un click
	if pantalla_completa and not OS.has_feature("web"):
		_aplicar_pantalla()


func set_volumen(v: float) -> void:
	volumen = clampf(v, 0.0, 1.0)
	_aplicar_audio()
	_guardar()


func set_silencio(s: bool) -> void:
	silencio = s
	_aplicar_audio()
	_guardar()


func set_pantalla_completa(p: bool) -> void:
	pantalla_completa = p
	_aplicar_pantalla()
	_guardar()


func set_sensibilidad(s: float) -> void:
	sensibilidad = clampf(s, 0.25, 2.0)
	_guardar()


func set_invertir_y(i: bool) -> void:
	invertir_y = i
	_guardar()


func _aplicar_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volumen, 0.0001)))
	AudioServer.set_bus_mute(bus, silencio or volumen <= 0.0)


func _aplicar_pantalla() -> void:
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	volumen = cfg.get_value("audio", "volumen", volumen)
	silencio = cfg.get_value("audio", "silencio", silencio)
	pantalla_completa = cfg.get_value("video", "pantalla_completa", pantalla_completa)
	sensibilidad = cfg.get_value("control", "sensibilidad", sensibilidad)
	invertir_y = cfg.get_value("control", "invertir_y", invertir_y)


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volumen", volumen)
	cfg.set_value("audio", "silencio", silencio)
	cfg.set_value("video", "pantalla_completa", pantalla_completa)
	cfg.set_value("control", "sensibilidad", sensibilidad)
	cfg.set_value("control", "invertir_y", invertir_y)
	cfg.save(ARCHIVO)
	cambio.emit()
