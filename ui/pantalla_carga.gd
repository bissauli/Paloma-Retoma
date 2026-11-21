class_name PantallaCarga
extends CanvasLayer
## Pantalla de carga: una de las ilustraciones de res://assets/loading/ (loading1.png ... loading5.png,
## al azar) entre dos franjas negras, y abajo a la derecha "Cargando..." con una paloma que picotea.
## La paloma sale de la hoja res://assets/loading/cargando.png: 5 cuadros iguales en fila, con fondo
## transparente. Si la hoja no está, queda sólo el texto.
## Uso: var p := PantallaCarga.crear(tree); ...; await p.ocultar()

const FONDOS := ["loading1", "loading2", "loading3", "loading4", "loading5"]
const CARPETA := "res://assets/loading/"
const HOJA := CARPETA + "cargando.png"
const CUADROS := 5
const SEG_CUADRO := 0.16
const ALTO_PALOMA := 120.0
const FRANJA_ARRIBA := 0.08          ## Franjas negras (parte de la pantalla)
const FRANJA_ABAJO := 0.14
const FUENTE := "res://ui/tema/fuentes/BebasNeue-Regular.ttf"

const INTERVALO_MS := 33

static var _ya_mostrada := false

static var actual: PantallaCarga      ## La que está en pantalla (ver refrescar)

var _ultimo_ms := 0
var _raiz: Control
var _texto: Label
var _paloma: TextureRect
var _cuadros: Array[AtlasTexture] = []
var _t := 0.0
var _puntos_t := 0.0


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
	add_child(_raiz)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(negro)
	# Ilustración entre las franjas, recortada para llenar sin deformarse
	var marco := Control.new()
	marco.anchor_left = 0.0
	marco.anchor_right = 1.0
	marco.anchor_top = FRANJA_ARRIBA
	marco.anchor_bottom = 1.0 - FRANJA_ABAJO
	marco.offset_left = 0.0
	marco.offset_right = 0.0
	marco.offset_top = 0.0
	marco.offset_bottom = 0.0
	marco.clip_contents = true
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(marco)
	var fondo := TextureRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# La primera vez es siempre la ilustración de la pantalla de arranque del motor (splash.png), así no
	# hay un salto entre las dos; después se elige al azar
	var elegido: String = String(FONDOS[0]) if not _ya_mostrada else String(FONDOS[randi() % FONDOS.size()])
	_ya_mostrada = true
	var ruta := CARPETA + elegido + ".png"
	if ResourceLoader.exists(ruta):
		fondo.texture = load(ruta) as Texture2D
	marco.add_child(fondo)
	# "Cargando..." + paloma, abajo a la derecha
	var caja := HBoxContainer.new()
	caja.anchor_left = 0.5
	caja.anchor_right = 1.0
	caja.anchor_top = 1.0 - FRANJA_ABAJO
	caja.anchor_bottom = 1.0
	caja.offset_right = -40.0
	caja.alignment = BoxContainer.ALIGNMENT_END
	caja.add_theme_constant_override("separation", 18)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(caja)
	_texto = Label.new()
	_texto.text = "Cargando..."
	_texto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_texto.add_theme_font_size_override("font_size", 46)
	if ResourceLoader.exists(FUENTE):
		_texto.add_theme_font_override("font", load(FUENTE) as Font)
	caja.add_child(_texto)
	_armar_paloma()
	if _paloma:
		caja.add_child(_paloma)


## Corta la hoja en 5 cuadros del mismo tamaño, ajustados al dibujo (todos con el mismo alto y ancho, y
## apoyados sobre la misma línea) para que la paloma no salte de un cuadro al otro.
func _armar_paloma() -> void:
	if not ResourceLoader.exists(HOJA):
		return
	var tex := load(HOJA) as Texture2D
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_compressed():
		return
	var cw := img.get_width() / CUADROS
	var h := img.get_height()
	# Cada cuadro es una quinta parte exacta de la hoja (así la paloma queda donde la dibujó el artista
	# y no salta de un cuadro al otro); sólo se recorta el alto vacío de arriba y abajo.
	var ancho_max := cw
	var arriba := h
	var abajo := 0
	for i in CUADROS:
		var u := img.get_region(Rect2i(i * cw, 0, cw, h)).get_used_rect()
		if u.size.x == 0:
			continue
		arriba = mini(arriba, u.position.y)
		abajo = maxi(abajo, u.position.y + u.size.y)
	if abajo <= arriba:
		return
	var alto := abajo - arriba
	for i in CUADROS:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * cw, arriba, cw, alto)
		_cuadros.append(a)
	_paloma = TextureRect.new()
	_paloma.texture = _cuadros[0]
	_paloma.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paloma.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_paloma.custom_minimum_size = Vector2(ALTO_PALOMA * float(ancho_max) / float(alto), ALTO_PALOMA)
	_paloma.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paloma.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_paloma.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enter_tree() -> void:
	actual = self
	# Mientras está la pantalla no hace falta dibujar el mundo 3D (se tapa igual): cada cuadro a la fuerza
	# durante la construcción cuesta casi nada y la animación sigue fluida
	get_viewport().disable_3d = true


func _exit_tree() -> void:
	if actual == self:
		actual = null
	if is_inside_tree():
		get_viewport().disable_3d = false


func _process(delta: float) -> void:
	_avanzar(delta)


func _avanzar(delta: float) -> void:
	_t += delta
	if _paloma and not _cuadros.is_empty():
		_paloma.texture = _cuadros[int(_t / SEG_CUADRO) % _cuadros.size()]
	_puntos_t += delta
	_texto.text = "Cargando" + ".".repeat(1 + int(_puntos_t / 0.4) % 3)


## Mientras se arma la ciudad el juego no dibuja cuadros solo (todo pasa dentro de un mismo _ready).
## Quien arma cosas pesadas llama a esto entre una etapa y otra: la animación avanza lo que pasó de
## verdad y se dibuja un cuadro a la fuerza, así la pantalla de carga no queda congelada.
## Se puede llamar todas las veces que se quiera (en cada pieza que se coloca, etc.): como mucho
## dibuja un cuadro cada INTERVALO_MS, el resto del tiempo sólo mira el reloj.
static func refrescar() -> void:
	if actual == null:
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


## Se va con un fundido corto y se borra.
func ocultar() -> void:
	get_viewport().disable_3d = false
	actual = null
	var tw := create_tween()
	tw.tween_property(_raiz, "modulate:a", 0.0, 0.45)
	await tw.finished
	queue_free()
