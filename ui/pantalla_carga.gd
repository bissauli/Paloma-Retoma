class_name PantallaCarga
extends CanvasLayer
## Pantalla de carga estilo "parallax 2.5D": cuatro escenas (res://assets/loading/escenas/), cada una con
## un fondo (background.jpg) y las palomas recortadas encima (birds.png, con transparencia). Las dos capas
## se mueven solas en sentidos opuestos (Auto Drift, ida y vuelta). El mouse no las mueve.
## Cada SEG_ESCENA segundos pasa a la siguiente escena con un fundido. Abajo: un degradado oscuro, una
## barra de progreso estimada y, a la derecha, "Cargando. . ." (o "Loading. . .") con una paloma que picotea
## (res://assets/loading/paloma_picotea.png: 8 cuadros en una grilla de 4 x 2).
##
## Mientras se arma la ciudad el juego no corre cuadros solo, así que todo se calcula a mano a partir del
## tiempo (_avanzar) y no con Tweens: quien hace trabajo pesado llama a PantallaCarga.refrescar().
## Uso: var p := PantallaCarga.crear(tree); ...; await p.ocultar()

const CARPETA := "res://assets/loading/escenas/"
const ESCENAS := ["01_back_to_back_crew", "02_harbor_pickup", "03_crosswalk_march", "04_fedora_cigar_boss"]
const HOJA := "res://assets/loading/paloma_picotea.png"
const FUENTE := "res://ui/tema/fuentes/BebasNeue-Regular.ttf"

const SEG_ESCENA := 7.0          ## Cuánto se queda cada escena
const SEG_FUNDIDO := 1.2         ## Fundido entre escenas
const SEG_TRAMO := 14.0          ## Auto Drift: duración de cada tramo (ida o vuelta)

## Auto Drift. Escala y desplazamiento (en fracción del tamaño de pantalla) al principio y al final del tramo.
const FONDO_DESDE := [1.08, Vector2(0.015, 0.006)]
const FONDO_HASTA := [1.02, Vector2(-0.015, -0.006)]
const PALOMAS_DESDE := [1.00, Vector2(-0.022, 0.008)]
const PALOMAS_HASTA := [1.10, Vector2(0.024, -0.008)]
## 03_crosswalk_march: las palomas cruzan la senda peatonal con un barrido más marcado
const CRUCE_DESDE := [1.02, Vector2(-0.035, 0.005)]
const CRUCE_HASTA := [1.11, Vector2(0.032, -0.005)]

## Paloma que picotea: grilla de 4 x 2 cuadros de 256 px; REGION es lo que ocupa el dibujo en todos
const COLUMNAS := 4
const FILAS := 2
const CELDA := 256
const REGION := Rect2(16, 56, 200, 166)
const SEG_CUADRO := 0.12
const ALTO_PALOMA := 104.0

const INTERVALO_MS := 33

static var actual: PantallaCarga      ## La que está en pantalla (ver refrescar)
## Cuánto lleva el armado del mundo (0 a 1). Lo escribe el hilo que arma la plaza y la ciudad (ver
## informar_armado); la pantalla lo lee en cada cuadro para la barra.
static var _armado := 0.0

var _ultimo_ms := 0
var _raiz: Control
var _diapos: Array[Control] = []
var _fondos: Array[TextureRect] = []
var _palomas: Array[TextureRect] = []
var _cargadas: Array[bool] = []
var _palabra: Label
var _puntos: Label
var _paloma: TextureRect
var _cuadros: Array[AtlasTexture] = []
var _barra: ColorRect
var _t := 0.0
var _inicio := 0                    ## Escena con la que arrancó
var _progreso := 0.0                ## Lo que muestra la barra
var _meta := 0.0                    ## Hacia dónde va la barra
var _armando := false               ## Ya se está armando el mundo (la barra sigue a _armado)
var _terminando := false
var _t_escenas := -1.0              ## Cuándo apareció la primera escena (-1: todavía cargando sus imágenes)
var _paso_fijo := -1                ## Escena congelada en la etapa final (ver fijar_escena)


## Crea la pantalla encima de todo (agregada a la raíz del árbol).
static func crear(arbol: SceneTree) -> PantallaCarga:
	var p := PantallaCarga.new()
	p.name = "PantallaCarga"
	arbol.root.add_child.call_deferred(p)    # la raíz está ocupada mientras arranca la escena
	return p


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP     # que no se pueda tocar el juego de atrás
	_raiz.clip_contents = true                         # que nunca se vean bordes al hacer zoom
	add_child(_raiz)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(negro)
	_inicio = randi() % ESCENAS.size()
	for i in ESCENAS.size():
		_armar_diapo(i)
	_armar_hud()
	_avanzar(0.0)
	# Cada nodo que entra al árbol (los _ready de todo el juego, uno atrás del otro) le da un respiro a la
	# animación: así no se traba aunque quien arma algo pesado no llame a refrescar
	get_tree().node_added.connect(_nodo_agregado)


func _armar_diapo(i: int) -> void:
	var diapo := Control.new()
	diapo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	diapo.clip_contents = true
	diapo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diapo.visible = false
	_raiz.add_child(diapo)
	var fondo := _capa()
	var palomas := _capa()
	diapo.add_child(fondo)
	diapo.add_child(palomas)
	_diapos.append(diapo)
	_fondos.append(fondo)
	_palomas.append(palomas)
	_cargadas.append(false)
	# Todas las imágenes se cargan en otro hilo (cargarlas acá trababa los primeros cuadros); la primera
	# escena aparece con un fundido desde negro apenas están
	var dir: String = CARPETA + String(ESCENAS[i]) + "/"
	ResourceLoader.load_threaded_request(dir + "background.jpg")
	ResourceLoader.load_threaded_request(dir + "birds.png")


## Si las dos imágenes de la escena ya terminaron de cargarse (traerlas no espera a nadie).
func _lista(i: int) -> bool:
	if _cargadas[i]:
		return true
	var dir: String = CARPETA + String(ESCENAS[i]) + "/"
	return ResourceLoader.load_threaded_get_status(dir + "background.jpg") == ResourceLoader.THREAD_LOAD_LOADED 		and ResourceLoader.load_threaded_get_status(dir + "birds.png") == ResourceLoader.THREAD_LOAD_LOADED


## Capa que llena la pantalla recortando sin deformar. Su tamaño y posición se ponen en cada cuadro
## (_ubicar), por eso no se ancla.
func _capa() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Trae las texturas de una escena que se pidieron en otro hilo (espera si todavía no terminaron).
func _asegurar_cargada(i: int) -> void:
	if _cargadas[i]:
		return
	_cargadas[i] = true
	var dir: String = CARPETA + String(ESCENAS[i]) + "/"
	_fondos[i].texture = ResourceLoader.load_threaded_get(dir + "background.jpg") as Texture2D
	_palomas[i].texture = ResourceLoader.load_threaded_get(dir + "birds.png") as Texture2D


func _armar_hud() -> void:
	var fuente: Font = load(FUENTE) as Font if ResourceLoader.exists(FUENTE) else null
	# Degradado oscuro abajo para que se lea el texto
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.8))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(0, 1)
	gtex.width = 4
	gtex.height = 128
	var sombra := TextureRect.new()
	sombra.texture = gtex
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.anchor_left = 0.0
	sombra.anchor_right = 1.0
	sombra.anchor_top = 0.62
	sombra.anchor_bottom = 1.0
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(sombra)
	# Barra de progreso, finita, de borde a borde abajo de todo
	var riel := ColorRect.new()
	riel.color = Color(1, 1, 1, 0.18)
	riel.anchor_left = 0.0
	riel.anchor_right = 1.0
	riel.anchor_top = 1.0
	riel.anchor_bottom = 1.0
	riel.offset_left = 40.0
	riel.offset_right = -40.0
	riel.offset_top = -30.0
	riel.offset_bottom = -24.0
	riel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(riel)
	_barra = ColorRect.new()
	_barra.color = Color(1.0, 0.78, 0.25)
	_barra.anchor_left = 0.0
	_barra.anchor_top = 0.0
	_barra.anchor_bottom = 1.0
	_barra.anchor_right = 0.0
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riel.add_child(_barra)
	# "Cargando. . ." + paloma, abajo a la derecha (arriba de la barra)
	var caja := HBoxContainer.new()
	caja.anchor_left = 0.4
	caja.anchor_right = 1.0
	caja.anchor_top = 1.0
	caja.anchor_bottom = 1.0
	caja.offset_right = -40.0
	caja.offset_top = -44.0 - ALTO_PALOMA
	caja.offset_bottom = -40.0
	caja.alignment = BoxContainer.ALIGNMENT_END
	caja.add_theme_constant_override("separation", 6)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(caja)
	_palabra = _etiqueta(fuente)
	_palabra.text = "Loading" if Idioma.actual() == "en" else "Cargando"
	caja.add_child(_palabra)
	# Los puntos van aparte y con ancho fijo, así la palabra no se corre cuando cambian
	_puntos = _etiqueta(fuente)
	_puntos.text = ". . ."
	_puntos.custom_minimum_size.x = _puntos.get_minimum_size().x
	_puntos.text = ""
	caja.add_child(_puntos)
	_armar_paloma()
	if _paloma:
		var espacio := Control.new()
		espacio.custom_minimum_size.x = 14.0
		espacio.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caja.add_child(espacio)
		caja.add_child(_paloma)


func _etiqueta(fuente: Font) -> Label:
	var l := Label.new()
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_font_size_override("font_size", 46)
	if fuente:
		l.add_theme_font_override("font", fuente)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _armar_paloma() -> void:
	if not ResourceLoader.exists(HOJA):
		return
	var tex := load(HOJA) as Texture2D
	if tex == null:
		return
	for fila in FILAS:
		for col in COLUMNAS:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(REGION.position + Vector2(col * CELDA, fila * CELDA), REGION.size)
			_cuadros.append(a)
	_paloma = TextureRect.new()
	_paloma.texture = _cuadros[0]
	_paloma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paloma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_paloma.custom_minimum_size = Vector2(ALTO_PALOMA * REGION.size.x / REGION.size.y, ALTO_PALOMA)
	_paloma.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paloma.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_paloma.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	actual = self
	# Mientras está la pantalla no hace falta dibujar el mundo 3D (se tapa igual): cada cuadro a la fuerza
	# durante la construcción cuesta casi nada y la animación sigue fluida
	get_viewport().disable_3d = true


func _nodo_agregado(_n: Node) -> void:
	refrescar()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_nodo_agregado):
		get_tree().node_added.disconnect(_nodo_agregado)
	if actual == self:
		actual = null
	if is_inside_tree():
		get_viewport().disable_3d = false


func _process(delta: float) -> void:
	_avanzar(delta)


## Avance real de la carga en otro hilo de los recursos del juego (0 a 1). Arranque lo informa.
func informar_recursos(p: float) -> void:
	_meta = maxf(_meta, 0.4 * clampf(p, 0.0, 1.0))


## Empieza a armarse el mundo (en otro hilo): desde acá la barra sigue a informar_armado.
func empezar_armado() -> void:
	_meta = maxf(_meta, 0.4)
	_armado = 0.0
	_armando = true


## Lo llama el hilo que arma el mundo (Plaza y Ciudad) a medida que avanza: "p" de 0 a 1.
static func informar_armado(p: float) -> void:
	_armado = maxf(_armado, clampf(p, 0.0, 1.0))


## Etapa final (el juego entra a la escena y se compilan los shaders, en el hilo principal): ya no se
## cambia de escena, así un cuadro lento no corta un fundido a la mitad.
func fijar_escena() -> void:
	if _t_escenas >= 0.0:
		_paso_fijo = int((_t - _t_escenas) / SEG_ESCENA)
	_meta = maxf(_meta, 0.95)


func _avanzar(delta: float) -> void:
	if _raiz == null:
		return
	_t += delta
	var tam := _raiz.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		return
	_escenas(tam)
	# Paloma, puntos y barra
	if _paloma and not _cuadros.is_empty():
		_paloma.texture = _cuadros[int(_t / SEG_CUADRO) % _cuadros.size()]
	var cant := 1 + int(_t / 0.4) % 3
	_puntos.text = " ".join(PackedStringArray([".", ".", "."]).slice(0, cant))
	if _armando and not _terminando:
		_meta = maxf(_meta, 0.4 + 0.55 * _armado)
	if delta > 0.0:
		_progreso = move_toward(_progreso, _meta, maxf(0.6 * (_meta - _progreso), 0.15) * delta * (6.0 if _terminando else 1.0))
	_barra.anchor_right = _progreso


## Muestra la escena que toca y, durante el fundido, la anterior debajo.
func _escenas(tam: Vector2) -> void:
	var n := ESCENAS.size()
	if _t_escenas < 0.0:
		if not _lista(_inicio):
			return          # Negro hasta que estén las imágenes (unos pocos cuadros)
		_asegurar_cargada(_inicio)
		_t_escenas = _t
	var t := _t - _t_escenas
	var paso := int(t / SEG_ESCENA) if _paso_fijo < 0 else _paso_fijo
	# No se pasa a una escena cuyas imágenes todavía no terminaron de cargarse: se queda en la anterior
	while paso > 0 and not _lista((_inicio + paso) % n):
		paso -= 1
	var en_escena := t - paso * SEG_ESCENA
	var cur := (_inicio + paso) % n
	var prev := (_inicio + paso - 1 + n) % n
	_asegurar_cargada(cur)
	# La primera entra desde negro; las demás, encima de la anterior
	var a_cur := clampf(en_escena / SEG_FUNDIDO, 0.0, 1.0)
	for i in n:
		var d := _diapos[i]
		if i == cur:
			d.visible = true
			d.modulate.a = a_cur
			_ubicar(i, en_escena, tam)
		elif i == prev and paso > 0 and a_cur < 1.0:
			d.visible = true
			d.modulate.a = 1.0
			_ubicar(i, en_escena + SEG_ESCENA, tam)
		else:
			d.visible = false
	# La que entra se dibuja arriba de la que sale
	_raiz.move_child(_diapos[cur], ESCENAS.size())


## Coloca las dos capas de una escena según cuánto tiempo lleva en pantalla (Auto Drift).
func _ubicar(i: int, t: float, tam: Vector2) -> void:
	# Ida y vuelta con curva suave (seno de entrada y salida)
	var ciclo := fmod(t, SEG_TRAMO * 2.0) / SEG_TRAMO
	var lineal := ciclo if ciclo <= 1.0 else 2.0 - ciclo
	var k := -(cos(PI * lineal) - 1.0) / 2.0
	var cruce: bool = ESCENAS[i] == "03_crosswalk_march"
	var desde: Array = CRUCE_DESDE if cruce else PALOMAS_DESDE
	var hasta: Array = CRUCE_HASTA if cruce else PALOMAS_HASTA
	# Fondo: se aleja despacio
	var f_esc := lerpf(FONDO_DESDE[0], FONDO_HASTA[0], k)
	var f_pos: Vector2 = (FONDO_DESDE[1] as Vector2).lerp(FONDO_HASTA[1], k) * tam
	# Margen de escala para que el corrimiento nunca deje ver un borde
	var minimo := 1.0 + 2.0 * maxf(absf(f_pos.x) / tam.x, absf(f_pos.y) / tam.y) + 0.004
	_poner(_fondos[i], maxf(f_esc, minimo), f_pos, tam)
	# Palomas: se acercan más rápido y en sentido contrario
	var p_esc := lerpf(desde[0], hasta[0], k)
	var p_pos: Vector2 = (desde[1] as Vector2).lerp(hasta[1], k) * tam
	_poner(_palomas[i], p_esc, p_pos, tam)


func _poner(capa: TextureRect, escala: float, corrimiento: Vector2, tam: Vector2) -> void:
	capa.size = tam
	capa.pivot_offset = tam * 0.5
	capa.position = corrimiento
	capa.scale = Vector2(escala, escala)


## Mientras se arma la ciudad el juego no dibuja cuadros solo (todo pasa dentro de un mismo _ready).
## Quien arma cosas pesadas llama a esto entre una etapa y otra: la animación avanza lo que pasó de
## verdad y se dibuja un cuadro a la fuerza, así la pantalla de carga no queda congelada.
## Se puede llamar todas las veces que se quiera (en cada pieza que se coloca, etc.): como mucho
## dibuja un cuadro cada INTERVALO_MS, el resto del tiempo sólo mira el reloj.
static func refrescar() -> void:
	# Desde el hilo que arma el mundo no se dibuja (la pantalla ya anda sola en el hilo principal)
	if actual == null or OS.get_thread_caller_id() != OS.get_main_thread_id():
		return
	var ahora := Time.get_ticks_msec()
	if ahora - actual._ultimo_ms < INTERVALO_MS:
		return
	var delta := clampf(float(ahora - actual._ultimo_ms) / 1000.0, 0.0, 0.5)
	if actual._ultimo_ms == 0:
		delta = 0.0
	actual._ultimo_ms = ahora
	actual._avanzar(delta)
	RenderingServer.force_draw(false)


## En la web: le avisa a la página que se saque su pantalla de carga (window.ocultarCarga).
static func ocultar_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if(window.ocultarCarga){window.ocultarCarga();}")


## Completa la barra, se va con un fundido corto y se borra.
func ocultar() -> void:
	get_viewport().disable_3d = false
	actual = null
	_terminando = true
	_meta = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.45)
	await tw.finished
	queue_free()
