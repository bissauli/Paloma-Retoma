class_name PresentacionPersonaje
extends CanvasLayer
## La presentación de un personaje importante, como las de los juegos de peleas: tajos de color de
## fondo, el nombre enorme e inclinado que entra de golpe sobre una sombra angular, unas líneas chicas
## de datos (edad, rol, especialidad) que se escriben solas y una frase abajo. Se muestra la primera
## vez que se habla con alguien (ver "presentacion" en CatalogoDialogos.PERSONAJES y Dialogos.iniciar).
## Se salta con E, Enter, click o Esc. Uso: await PresentacionPersonaje.mostrar(get_tree(), datos)
## datos = {nombre, datos: [líneas], frase, color (de las letras), fondo (del fondo)}.

signal terminada

const DURACION := 4.6
const INCLINACION := -0.12      ## Radianes: el nombre y los datos van torcidos hacia arriba

var datos: Dictionary = {}

var _raiz: Control
var _listo := false
var _tween: Tween


## Muestra la presentación y espera a que termine (o la salten).
static func mostrar(arbol: SceneTree, info: Dictionary) -> void:
	var p := PresentacionPersonaje.new()
	p.datos = info
	arbol.root.add_child(p)
	await p.terminada


func _ready() -> void:
	layer = 18           # Arriba del diálogo y los avisos, debajo de la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	_armar()
	AudioManager.ui("unlock", -6.0)
	AudioManager.ui("highlight", -8.0)


func _armar() -> void:
	var color_letras: Color = datos.get("color", Color("ffd84a"))
	var color_fondo: Color = datos.get("fondo", Color(0.1, 0.02, 0.18))
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = EstiloUI.TEMA
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	# Fondo teñido y tajos verticales de luz que se desplazan
	var fondo := ColorRect.new()
	fondo.color = Color(color_fondo.r, color_fondo.g, color_fondo.b, 0.0)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fondo)
	var tajos := Control.new()
	tajos.set_anchors_preset(Control.PRESET_FULL_RECT)
	tajos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(tajos)
	var azar := RandomNumberGenerator.new()
	azar.seed = hash(String(datos.get("nombre", "")))
	var claro := color_fondo.lightened(0.55)
	for i in 16:
		var t := ColorRect.new()
		t.color = Color(claro.r, claro.g, claro.b, azar.randf_range(0.08, 0.22))
		t.size = Vector2(azar.randf_range(30.0, 150.0), 1000.0)
		t.position = Vector2(azar.randf_range(-100.0, 1280.0), -140.0)
		t.rotation = 0.06
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tajos.add_child(t)
		var sentido := 1.0 if i % 2 == 0 else -1.0
		create_tween().tween_property(t, "position:x", t.position.x + sentido * azar.randf_range(60.0, 160.0), DURACION)
	tajos.modulate.a = 0.0

	# La sombra angular detrás del nombre (un paralelogramo negro con tajos más claros abajo)
	var grupo := Control.new()
	grupo.position = Vector2(150, 372)
	grupo.rotation = INCLINACION
	grupo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(grupo)
	var sombra := Polygon2D.new()
	sombra.color = Color(0.02, 0.01, 0.05, 0.92)
	sombra.polygon = PackedVector2Array([Vector2(-20, 20), Vector2(930, -10), Vector2(1010, 170), Vector2(520, 205), Vector2(60, 200)])
	grupo.add_child(sombra)
	for k in 7:
		var l := Line2D.new()
		l.width = 7.0
		l.default_color = Color(0.45, 0.45, 0.5, 0.55)
		l.points = PackedVector2Array([Vector2(430 + k * 60, 205 - k * 5), Vector2(500 + k * 60 + 40, 60 + k * 18)])
		grupo.add_child(l)

	# El nombre, grande, de color y con borde negro
	var nombre := Label.new()
	nombre.theme_type_variation = &"TituloJuego"
	nombre.text = String(datos.get("nombre", "")).to_upper()
	nombre.add_theme_font_size_override("font_size", 168)
	nombre.add_theme_color_override("font_color", color_letras)
	nombre.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05))
	nombre.add_theme_constant_override("outline_size", 16)
	nombre.position = Vector2(30, -150)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grupo.add_child(nombre)

	# Las líneas de datos, chiquitas, debajo del nombre
	var lineas: Array[Label] = []
	var y := 100.0
	for texto: String in datos.get("datos", []):
		var l := Label.new()
		l.theme_type_variation = &"Etiqueta"
		l.text = texto
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.05))
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(34, y)
		l.visible_ratio = 0.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grupo.add_child(l)
		lineas.append(l)
		y += 30.0

	# El modelo del personaje, de cuerpo entero a la derecha (lo que dice viene después, en el diálogo)
	var modelo_rect := _armar_modelo()
	var saltar := Label.new()
	saltar.theme_type_variation = &"TextoChico"
	saltar.text = tr("E · SALTAR")
	saltar.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	saltar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	saltar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(saltar)

	# La secuencia
	grupo.modulate.a = 0.0
	grupo.position.x -= 700.0
	_tween = create_tween()
	_tween.tween_property(fondo, "color:a", 0.62, 0.25)
	_tween.parallel().tween_property(tajos, "modulate:a", 1.0, 0.4)
	_tween.parallel().tween_property(grupo, "modulate:a", 1.0, 0.12).set_delay(0.18)
	_tween.parallel().tween_property(grupo, "position:x", 150.0, 0.38).set_delay(0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: AudioManager.ui("dialogue_expression", -6.0))
	for i in lineas.size():
		_tween.tween_property(lineas[i], "visible_ratio", 1.0, 0.5)
	_tween.tween_interval(maxf(DURACION - 2.8, 0.5))
	_tween.tween_callback(_terminar)
	# El modelo entra deslizándose desde la derecha un poquito después que el nombre
	if modelo_rect:
		modelo_rect.modulate.a = 0.0
		var x_final := modelo_rect.position.x
		modelo_rect.position.x += 500.0
		var entrada := create_tween().set_parallel(true)
		entrada.tween_property(modelo_rect, "modulate:a", 1.0, 0.15).set_delay(0.35)
		entrada.tween_property(modelo_rect, "position:x", x_final, 0.42).set_delay(0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Un golpe de escala al entrar el nombre
	var golpe := create_tween()
	golpe.tween_interval(0.5)
	golpe.tween_property(grupo, "scale", Vector2(1.04, 1.04), 0.07)
	golpe.tween_property(grupo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## El personaje en 3D dentro de un SubViewport transparente (con su propio mundo, luz y cámara), mostrado
## como una imagen a la derecha. Devuelve null si la presentación no tiene "modelo".
func _armar_modelo() -> TextureRect:
	var info: Dictionary = datos.get("modelo", {})
	if info.is_empty():
		return null
	var personaje := _crear_personaje(info)
	if personaje == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 720)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color(0.85, 0.82, 0.95)
	entorno.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = entorno
	vp.add_child(we)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35.0, -150.0, 0.0)
	luz.light_energy = 1.1
	vp.add_child(luz)
	vp.add_child(personaje)
	# La paloma mira hacia -Z: la cámara va de ese lado, un poco de costado (tres cuartos) y desde abajo
	personaje.rotation.y = 0.6
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.position = Vector3(0.35, 0.62, -3.2)
	cam.look_at(Vector3(0.0, 0.5, 0.0), Vector3.UP)
	var rect := TextureRect.new()
	rect.texture = vp.get_texture()
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(560, 720)
	rect.size = Vector2(560, 720)
	rect.position = Vector2(760, 8)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(rect)
	return rect


## Arma el modelo del personaje según "modelo": {tipo: "badjoke", rol: "jefe"} (una paloma de la banda).
func _crear_personaje(info: Dictionary) -> Node3D:
	match String(info.get("tipo", "")):
		"badjoke":
			var p := PalomaBadJoke.new()
			p.rol = String(info.get("rol", "jefe"))
			p.nombre = String(datos.get("nombre", ""))
			p.set_meta("presentacion", true)   # Sin cartel con el nombre, sin interlocutor, sin seguir a la jugadora
			p.scale = Vector3.ONE * 1.6
			return p
		"animal":
			# Un perro o gato del juego (world/animal.gd), sentado y mirando a la cámara (el modelo mira hacia +Z
			# y la cámara está del otro lado, así que va dado vuelta dentro de un pivote)
			var pivote := Node3D.new()
			var a := Animal.new()
			a.variante = String(info.get("variante", "perro_marron"))
			a.conducta = "presentacion"   # Sentado y callado: no ladra ni espanta a las palomas del mundo
			a.rotation.y = PI
			a.scale = Vector3.ONE * float(info.get("escala", 1.3))
			pivote.add_child(a)
			return pivote
	return null


func _input(event: InputEvent) -> void:
	if _listo:
		return
	var salta: bool = event.is_action_pressed("interactuar") or event.is_action_pressed("ui_accept") \
		or event.is_action_pressed("pausa") or event.is_action_pressed("ui_cancel") \
		or (event is InputEventMouseButton and event.pressed)
	if salta and not event.is_echo():
		get_viewport().set_input_as_handled()
		_terminar()


func _terminar() -> void:
	if _listo:
		return
	_listo = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var salida := create_tween()
	salida.tween_property(_raiz, "modulate:a", 0.0, 0.25)
	salida.tween_callback(func() -> void:
		terminada.emit()
		queue_free())
