extends Node
## Opciones del jugador (autoload "Ajustes"): volumen general y por bus (música, voces, efectos),
## silencio, brillo, pantalla completa, mouse, calidad gráfica (bajo / medio / alto), resolución y
## límite de FPS.
## Se guardan en user://opciones.cfg y se aplican al arrancar.

signal cambio

## La versión para teléfonos guarda aparte: en la web las dos comparten el mismo user://.
var ARCHIVO := "user://opciones_movil.cfg" if OS.has_feature("movil") else "user://opciones.cfg"
## Buses de audio que regula el menú (default_bus_layout.tres). Si faltan, se crean al arrancar.
const BUSES := [&"Musica", &"Voces", &"Efectos"]
const BRILLO_MIN := 0.6
const BRILLO_MAX := 1.4

const CALIDADES := ["Baja", "Media", "Alta"]
## Por calidad: distancia de sombras (m), cortes de la sombra direccional (1, 2 o 4), tamaño del
## mapa de sombras, filtro suave (0..5) y MSAA. Las sombras son lo que más cuesta en esta escena.
const PRESETS := [
	{"sombra_dist": 70.0, "cortes": 1, "atlas": 2048, "suave": 0, "msaa": Viewport.MSAA_DISABLED},
	{"sombra_dist": 140.0, "cortes": 2, "atlas": 4096, "suave": 1, "msaa": Viewport.MSAA_2X},
	{"sombra_dist": 240.0, "cortes": 4, "atlas": 4096, "suave": 2, "msaa": Viewport.MSAA_4X},
]
## Resoluciones ofrecidas (se filtran por el tamaño de la pantalla). Índice 0 = nativa.
const RESOLUCIONES := [Vector2i(0, 0), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3840, 2160)]
## Límites de FPS ofrecidos. 0 = sincronizado con la pantalla (VSync), -1 = sin límite.
## Con un número fijo se apaga el VSync para que el tope no lo pise la frecuencia del monitor.
const LIMITES_FPS := [0, 30, 60, 75, 90, 120, 144, 165, 180, 200, 240, -1]

var volumen := 0.8              ## 0..1, lineal (bus Master)
var volumen_musica := 0.8       ## 0..1, bus Musica (ambiente y música)
var volumen_voces := 1.0        ## 0..1, bus Voces (arrullos, gritos, chillidos)
var volumen_efectos := 1.0      ## 0..1, bus Efectos (aleteo, picoteo, silbato...)
var silencio := false           ## "Silenciar todo"
var brillo := 1.0               ## Brillo de la imagen 3D (BRILLO_MIN..BRILLO_MAX)
var pantalla_completa := false
var sensibilidad := 1.0         ## Multiplica la sensibilidad de la cámara (0,25..2)
var invertir_y := false
var calidad := 2                ## 0 bajo, 1 medio, 2 alto
var resolucion := Vector2i.ZERO ## (0, 0) = nativa
var limite_fps := 0             ## Ver LIMITES_FPS

## Versión para teléfonos (preset de exportación "Web Android", feature "movil"): controles táctiles,
## sin captura del mouse y gráficos livianos. En la versión de PC es siempre false.
var movil := OS.has_feature("movil")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# En la web arranca en "Medio": el navegador tiene menos margen
	if OS.has_feature("web"):
		calidad = 1
	# En el teléfono: calidad baja y el 3D dibujado a 720p (la pantalla tiene muchos píxeles)
	if movil:
		calidad = 0
		resolucion = Vector2i(1280, 720)
		_preparar_movil()
	_cargar()
	_asegurar_buses()
	_aplicar_audio()
	# En la web el navegador sólo deja pasar a pantalla completa después de un click
	if pantalla_completa and not OS.has_feature("web"):
		_aplicar_pantalla()
	_aplicar_graficos.call_deferred()
	_aplicar_fps()
	_aplicar_resolucion.call_deferred(true)
	# Si la ventana cambia de tamaño (a mano o al pasar a pantalla completa) se recalcula la escala 3D
	get_tree().root.size_changed.connect(_aplicar_resolucion)


func set_volumen(v: float) -> void:
	volumen = clampf(v, 0.0, 1.0)
	_aplicar_audio()
	_guardar()


## Volumen de un bus (&"Musica", &"Voces" o &"Efectos"), 0..1.
func set_volumen_bus(bus: StringName, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	match bus:
		&"Musica":
			volumen_musica = v
		&"Voces":
			volumen_voces = v
		&"Efectos":
			volumen_efectos = v
	_aplicar_audio()
	_guardar()


func volumen_bus(bus: StringName) -> float:
	match bus:
		&"Musica":
			return volumen_musica
		&"Voces":
			return volumen_voces
		&"Efectos":
			return volumen_efectos
	return volumen


func set_brillo(b: float) -> void:
	brillo = clampf(b, BRILLO_MIN, BRILLO_MAX)
	for n in get_tree().get_nodes_in_group("entorno"):
		aplicar_brillo((n as WorldEnvironment).environment)
	_guardar()


## Brillo de la imagen 3D (la interfaz no cambia). La llama world/plaza.gd al crear el entorno.
func aplicar_brillo(env: Environment) -> void:
	if env == null:
		return
	env.adjustment_enabled = not is_equal_approx(brillo, 1.0)
	env.adjustment_brightness = brillo


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


func set_calidad(c: int) -> void:
	calidad = clampi(c, 0, PRESETS.size() - 1)
	_aplicar_graficos()
	_guardar()


func set_resolucion(r: Vector2i) -> void:
	resolucion = r
	_aplicar_resolucion(true)
	_guardar()


func set_limite_fps(f: int) -> void:
	limite_fps = f if LIMITES_FPS.has(f) else 0
	_aplicar_fps()
	_guardar()


## Texto para mostrar un límite de FPS en el menú.
func nombre_limite_fps(f: int) -> String:
	match f:
		0:
			return "VSync"
		-1:
			return "Sin límite"
		_:
			return "%d FPS" % f


## Resoluciones que entran en la pantalla actual (la nativa siempre está).
func resoluciones_disponibles() -> Array[Vector2i]:
	var pantalla := DisplayServer.screen_get_size()
	var lista: Array[Vector2i] = []
	for r: Vector2i in RESOLUCIONES:
		if r == Vector2i.ZERO or (r.x <= pantalla.x and r.y <= pantalla.y):
			lista.append(r)
	return lista


## ¿La ventana se puede cambiar de tamaño? (en la web y en pantalla completa no:
## ahí la resolución elegida sólo baja la resolución con la que se dibuja el 3D).
func resolucion_cambia_ventana() -> bool:
	return not OS.has_feature("web") and DisplayServer.window_get_mode() < DisplayServer.WINDOW_MODE_FULLSCREEN


## En la PC el juego captura el mouse; en el teléfono nunca (no hay puntero que capturar).
func capturar_mouse(si: bool) -> void:
	if movil:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if si else Input.MOUSE_MODE_VISIBLE


## Godot convierte el primer dedo en un click del mouse (así andan los botones de los menús).
## Para que tocar la pantalla no picotee ni arrulle, esas acciones pierden sus clicks:
## en el teléfono se disparan sólo con los botones táctiles (ui/controles_tactiles.gd).
func _preparar_movil() -> void:
	for accion: StringName in [&"picotear", &"arrullar"]:
		for e in InputMap.action_get_events(accion):
			if e is InputEventMouseButton:
				InputMap.action_erase_event(accion, e)


# ---------------------------------------------------------------- Aplicar

func _asegurar_buses() -> void:
	for nombre: StringName in BUSES:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nombre)
			AudioServer.set_bus_send(i, &"Master")


func _aplicar_audio() -> void:
	_volumen_de_bus(&"Master", volumen, silencio)
	for nombre: StringName in BUSES:
		_volumen_de_bus(nombre, volumen_bus(nombre), false)


func _volumen_de_bus(nombre: StringName, v: float, mudo: bool) -> void:
	var bus := AudioServer.get_bus_index(nombre)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(bus, mudo or v <= 0.0)


func _aplicar_pantalla() -> void:
	var modo := DisplayServer.WINDOW_MODE_FULLSCREEN if pantalla_completa else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(modo)
	_aplicar_resolucion.call_deferred(true)


func _aplicar_graficos() -> void:
	var p: Dictionary = PRESETS[calidad]
	var vp := get_viewport()
	vp.msaa_3d = p["msaa"]
	RenderingServer.directional_shadow_atlas_set_size(p["atlas"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["suave"])
	for n in get_tree().get_nodes_in_group("sol"):
		aplicar_sombras(n as DirectionalLight3D)


func _aplicar_fps() -> void:
	if limite_fps == 0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Engine.max_fps = 0
	else:
		# En la web el navegador siempre sincroniza con la pantalla: sólo sirve para bajar los FPS
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = maxi(limite_fps, 0)


## Distancia y cortes de la sombra del sol según la calidad. La llama world/plaza.gd al crear el sol.
func aplicar_sombras(sol: DirectionalLight3D) -> void:
	if sol == null:
		return
	var p: Dictionary = PRESETS[calidad]
	sol.directional_shadow_max_distance = p["sombra_dist"]
	sol.directional_shadow_fade_start = 0.9
	match int(p["cortes"]):
		1:
			sol.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sol.directional_shadow_split_1 = 0.25
		_:
			sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			# Cortes más concentrados cerca (donde está la paloma) y uno largo para el fondo
			sol.directional_shadow_split_1 = 0.06
			sol.directional_shadow_split_2 = 0.18
			sol.directional_shadow_split_3 = 0.45
			sol.directional_shadow_blend_splits = true


## "cambiar_ventana": sólo al elegir la resolución o al salir de pantalla completa se le cambia el
## tamaño a la ventana (si el jugador la estira a mano, se respeta).
func _aplicar_resolucion(cambiar_ventana := false) -> void:
	var vp := get_viewport()
	if resolucion == Vector2i.ZERO:
		vp.scaling_3d_scale = 1.0
		return
	if resolucion_cambia_ventana():
		vp.scaling_3d_scale = 1.0
		var actual := DisplayServer.window_get_size()
		if cambiar_ventana and actual != resolucion:
			DisplayServer.window_set_size(resolucion)
			# Centrada en la pantalla
			var pantalla := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(pantalla.position + Vector2i(Vector2(pantalla.size - resolucion) * 0.5))
	else:
		# Pantalla completa o web: el 3D se dibuja a esa resolución y se estira (la UI queda nítida)
		var alto_ventana := maxi(DisplayServer.window_get_size().y, 1)
		vp.scaling_3d_scale = clampf(float(resolucion.y) / alto_ventana, 0.25, 1.0)


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	volumen = cfg.get_value("audio", "volumen", volumen)
	volumen_musica = cfg.get_value("audio", "musica", volumen_musica)
	volumen_voces = cfg.get_value("audio", "voces", volumen_voces)
	volumen_efectos = cfg.get_value("audio", "efectos", volumen_efectos)
	silencio = cfg.get_value("audio", "silencio", silencio)
	brillo = clampf(cfg.get_value("video", "brillo", brillo), BRILLO_MIN, BRILLO_MAX)
	pantalla_completa = cfg.get_value("video", "pantalla_completa", pantalla_completa)
	calidad = clampi(cfg.get_value("video", "calidad", calidad), 0, PRESETS.size() - 1)
	resolucion = cfg.get_value("video", "resolucion", resolucion)
	limite_fps = cfg.get_value("video", "limite_fps", limite_fps)
	if not LIMITES_FPS.has(limite_fps):
		limite_fps = 0
	sensibilidad = cfg.get_value("control", "sensibilidad", sensibilidad)
	invertir_y = cfg.get_value("control", "invertir_y", invertir_y)


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volumen", volumen)
	cfg.set_value("audio", "musica", volumen_musica)
	cfg.set_value("audio", "voces", volumen_voces)
	cfg.set_value("audio", "efectos", volumen_efectos)
	cfg.set_value("audio", "silencio", silencio)
	cfg.set_value("video", "brillo", brillo)
	cfg.set_value("video", "pantalla_completa", pantalla_completa)
	cfg.set_value("video", "calidad", calidad)
	cfg.set_value("video", "resolucion", resolucion)
	cfg.set_value("video", "limite_fps", limite_fps)
	cfg.set_value("control", "sensibilidad", sensibilidad)
	cfg.set_value("control", "invertir_y", invertir_y)
	cfg.save(ARCHIVO)
	cambio.emit()
