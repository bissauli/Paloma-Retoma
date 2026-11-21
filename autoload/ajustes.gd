extends Node
## Opciones del jugador (autoload "Ajustes"): volumen general y por bus (música, voces, efectos),
## silencio, brillo, pantalla completa, mouse, calidad gráfica (bajo / medio / alto), resolución y
## límite de FPS.
## Se guardan en user://opciones.cfg y se aplican al arrancar.

signal cambio
## Se cambió el idioma (selector de banderas del menú). Los Label ya se traducen solos; esto es
## para lo que arma textos por código.
signal idioma_cambiado

## La versión para teléfonos guarda aparte: en la web las dos comparten el mismo user://.
var ARCHIVO := "user://opciones_movil.cfg" if _es_movil() else "user://opciones.cfg"
## Buses de audio que regula el menú (default_bus_layout.tres). Si faltan, se crean al arrancar.
const BUSES := [&"Musica", &"Voces", &"Efectos"]
const BRILLO_MIN := 0.6
const BRILLO_MAX := 1.4

const CALIDADES := ["Baja", "Media", "Alta"]
const GRUPO_SOMBRA_DINAMICA := &"sombra_dinamica"
const GRUPO_DISTANCIA_PALOMAS := &"distancia_palomas"
## Por calidad: distancia de sombras (m), cortes de la sombra direccional (1, 2 o 4), tamaño del
## mapa de sombras, filtro suave (0..5) y MSAA. Las sombras son lo que más cuesta en esta escena.
const PRESETS := [
	{"sombra_dist": 60.0, "cortes": 1, "atlas": 2048, "suave": 0, "msaa": Viewport.MSAA_DISABLED},
	{"sombra_dist": 110.0, "cortes": 1, "atlas": 4096, "suave": 1, "msaa": Viewport.MSAA_2X},
	# Alta: 2 cortes en vez de 4 (cada corte vuelve a dibujar toda la escena en el mapa de sombras:
	# eran la mitad de las llamadas de dibujo) y MSAA 2X en vez de 4X
	{"sombra_dist": 180.0, "cortes": 2, "atlas": 4096, "suave": 2, "msaa": Viewport.MSAA_2X},
]
## En el teléfono la calidad "Baja" usa un mapa de sombras más chico y menos distancia.
const PRESET_MOVIL_BAJA := {"sombra_dist": 45.0, "cortes": 1, "atlas": 1024, "suave": 0, "msaa": Viewport.MSAA_DISABLED}
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
var calidad_manual := false     ## La jugadora eligió la calidad a mano: no se baja sola (ver _vigilar_fps)

## Ajuste automático de calidad: si el juego anda por debajo de este FPS durante VENTANAS ventanas de
## VENTANA_S segundos seguidas, baja un escalón de calidad (Alta -> Media -> Baja) y no vuelve a subir.
const FPS_MINIMO := 50.0
const VENTANA_S := 4.0
const VENTANAS := 2
var _acum_t := 0.0
var _acum_n := 0
var _ventanas_lentas := 0
var _gracia := 0.0
var resolucion := Vector2i.ZERO ## (0, 0) = nativa
var limite_fps := 0             ## Ver LIMITES_FPS
var idioma := ""                ## "es" o "en" (ver Idioma). Vacío = el del sistema hasta que elija
var estilo_comic := true        ## Modo cómic: cel duro, semitono y contorno de tinta (ver EstiloComic)

## Versión para teléfonos: controles táctiles, sin captura del mouse y gráficos livianos.
## Una sola build web sirve para PC y teléfono: se activa sola al abrirla desde Android o iOS
## (features "web_android" / "web_ios"). La feature "movil" la fuerza (tests, bench).
var movil := _es_movil()


static func _es_movil() -> bool:
	return OS.has_feature("movil") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# En la web arranca en "Medio": el navegador tiene menos margen
	if OS.has_feature("web"):
		calidad = 1
		# La web corre todo en un solo hilo y WebGL cuesta más por píxel: el 3D se dibuja a 720p (la UI
		# queda nítida, ver _aplicar_resolucion) y la física a 30 pasos por segundo (todo lo que se ve
		# se interpola). Si el jugador elige otra cosa en Opciones, se respeta (se carga después).
		resolucion = Vector2i(1280, 720)
		aplicar_perfil_movil()
	else:
		calidad = _calidad_inicial()
	# En el teléfono: calidad baja y el 3D dibujado a 720p (la pantalla tiene muchos píxeles)
	if movil:
		calidad = 0
		resolucion = Vector2i(1280, 720)
		_preparar_movil()
		aplicar_perfil_movil()
	Idioma.instalar()
	_cargar()
	if not Idioma.es_valido(idioma):
		idioma = Idioma.por_defecto()
	Idioma.aplicar(idioma)
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


func _process(delta: float) -> void:
	_vigilar_fps(delta)


func _vigilar_fps(delta: float) -> void:
	# (con un tope de FPS bajo elegido a propósito, por ejemplo 30, no se mide: sería siempre "lento")
	var tope_bajo := limite_fps > 0 and limite_fps < 60
	if calidad_manual or calidad == 0 or tope_bajo or not GameState.en_partida or GameState.menu_activo \
			or get_tree().paused or not DisplayServer.window_is_focused():
		_gracia = 6.0          # Después de pausar, cargar o cambiar de ventana se espera antes de medir
		_acum_t = 0.0
		_acum_n = 0
		_ventanas_lentas = 0
		return
	if _gracia > 0.0:
		_gracia -= delta
		return
	_acum_t += delta
	_acum_n += 1
	if _acum_t < VENTANA_S:
		return
	var fps := float(_acum_n) / _acum_t
	_acum_t = 0.0
	_acum_n = 0
	if fps < FPS_MINIMO:
		_ventanas_lentas += 1
	else:
		_ventanas_lentas = 0
	if _ventanas_lentas >= VENTANAS:
		_ventanas_lentas = 0
		_gracia = 6.0
		calidad -= 1
		_aplicar_graficos()
		_guardar()
		cambio.emit()
		print("Calidad bajada sola a ", CALIDADES[calidad], " (", int(fps), " FPS)")


## Calidad de la primera vez que se abre el juego en PC (después manda lo que elija el jugador): Alta
## sólo con una placa dedicada; con video integrado, Baja; si no se sabe, Media.
static func _calidad_inicial() -> int:
	var placa := RenderingServer.get_video_adapter_name().to_lower()
	for integrada: String in ["intel", "uhd", "iris", "basic render", "llvmpipe", "swiftshader", "vega 3", "vega 6", "vega 8", "graphics"]:
		if integrada in placa and not ("arc a" in placa or "radeon rx" in placa):
			return 0
	for potente: String in ["rtx", "gtx 16", "gtx 10", "radeon rx", "arc a"]:
		if potente in placa:
			return 2
	return 1


## Cambia el idioma de todo el juego y lo guarda.
func set_idioma(codigo: String) -> void:
	if not Idioma.es_valido(codigo) or codigo == idioma:
		return
	idioma = codigo
	Idioma.aplicar(idioma)
	_guardar()
	idioma_cambiado.emit()


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
	# Los ajustes se prenden si el brillo no es el normal o si el entorno pide saturación o contraste
	# propios (el mapa V3 sube un poco la saturación, ver world/plaza.gd)
	var propios := not is_equal_approx(env.adjustment_saturation, 1.0) or not is_equal_approx(env.adjustment_contrast, 1.0)
	env.adjustment_enabled = propios or not is_equal_approx(brillo, 1.0)
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
	calidad_manual = true      # Si la eligió la jugadora, el ajuste automático deja de tocarla
	calidad = clampi(c, 0, PRESETS.size() - 1)
	_aplicar_graficos()
	_guardar()


func set_estilo_comic(e: bool) -> void:
	estilo_comic = e
	_guardar()


## ¿Se dibuja el contorno de tinta? Es un dibujo más por malla (medido en PC: +2 ms en Alta, casi
## nada en Media y Baja); en el teléfono no, ahí cada dibujo pesa mucho más.
func contorno_comic() -> bool:
	return estilo_comic and not movil and not OS.has_feature("web") and calidad >= 1


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


## Versión para teléfonos: la física corre a 30 pasos por segundo en vez de 60. Todo lo que se ve
## se interpola entre pasos (physics_interpolation), así que se mueve igual de suave, y la
## lógica del juego (palomas, gente, autos, enemigos) le cuesta la mitad al procesador.
## Con pocos cuadros por segundo no se acumulan más de 3 pasos por cuadro (si no, cada cuadro
## lento hace más lento al siguiente).
const FISICA_MOVIL := 30


func aplicar_perfil_movil() -> void:
	Engine.physics_ticks_per_second = FISICA_MOVIL
	Engine.max_physics_steps_per_frame = 3


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


## Preset de gráficos vigente (el de teléfono en calidad baja es más liviano).
func preset_actual() -> Dictionary:
	if movil and calidad == 0:
		return PRESET_MOVIL_BAJA
	if OS.has_feature("web"):
		# En el navegador el MSAA y las sombras suaves cuestan demasiado: sin MSAA y sin filtro suave
		var p: Dictionary = (PRESETS[calidad] as Dictionary).duplicate()
		p["msaa"] = Viewport.MSAA_DISABLED
		p["suave"] = 0
		p["atlas"] = mini(int(p["atlas"]), 2048)
		return p
	return PRESETS[calidad]


## ¿Las palomas NPC, la gente y los autos proyectan sombra? Sólo de calidad Media para arriba: son
## decenas de cuerpos que se mueven y en calidad Baja cada uno sumaba un dibujo al mapa de sombras.
func sombras_dinamicas() -> bool:
	return calidad >= 1


func _modo_sombra_dinamica() -> GeometryInstance3D.ShadowCastingSetting:
	if sombras_dinamicas():
		return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Anota mallas de cosas que se mueven (palomas NPC, gente, autos): proyectan sombra según
## sombras_dinamicas() y se actualizan solas cuando el jugador cambia la calidad (por grupo:
## cuando la malla se borra sale sola del grupo, no queda nada colgado).
func registrar_sombra_dinamica(mallas: Array) -> void:
	var modo := _modo_sombra_dinamica()
	for m in mallas:
		var g := m as GeometryInstance3D
		if g:
			g.add_to_group(GRUPO_SOMBRA_DINAMICA)
			g.cast_shadow = modo


## Hasta qué distancia de la cámara se dibujan las palomas NPC (miden 35 cm: más lejos son un par
## de píxeles). Más allá tampoco se les calcula la animación. Alcanza para ver de lejos dónde hay
## palomas sueltas para reclutar (cruzando la plaza son unos 60 m).
func distancia_palomas() -> float:
	if movil:
		return 60.0
	return [60.0, 80.0, 100.0][calidad]


func _aplicar_graficos() -> void:
	var p: Dictionary = preset_actual()
	var vp := get_viewport()
	vp.msaa_3d = p["msaa"]
	RenderingServer.directional_shadow_atlas_set_size(p["atlas"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["suave"])
	for n in get_tree().get_nodes_in_group("sol"):
		aplicar_sombras(n as DirectionalLight3D)
	get_tree().set_group(GRUPO_SOMBRA_DINAMICA, "cast_shadow", _modo_sombra_dinamica())
	get_tree().call_group(GRUPO_DISTANCIA_PALOMAS, "aplicar_distancia", distancia_palomas())


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
	var p: Dictionary = preset_actual()
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
	calidad_manual = cfg.get_value("video", "calidad_manual", calidad_manual)
	resolucion = cfg.get_value("video", "resolucion", resolucion)
	limite_fps = cfg.get_value("video", "limite_fps", limite_fps)
	estilo_comic = cfg.get_value("video", "estilo_comic", estilo_comic)
	if not LIMITES_FPS.has(limite_fps):
		limite_fps = 0
	sensibilidad = cfg.get_value("control", "sensibilidad", sensibilidad)
	invertir_y = cfg.get_value("control", "invertir_y", invertir_y)
	idioma = cfg.get_value("general", "idioma", idioma)


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
	cfg.set_value("video", "calidad_manual", calidad_manual)
	cfg.set_value("video", "resolucion", resolucion)
	cfg.set_value("video", "limite_fps", limite_fps)
	cfg.set_value("video", "estilo_comic", estilo_comic)
	cfg.set_value("control", "sensibilidad", sensibilidad)
	cfg.set_value("control", "invertir_y", invertir_y)
	cfg.set_value("general", "idioma", idioma)
	cfg.save(ARCHIVO)
	cambio.emit()
