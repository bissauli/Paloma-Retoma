extends CanvasLayer
## HUD: bandada (🕊 x N), barra de stamina, comida acumulada, lo que llevás en el pico,
## objetivo actual en una línea, mensajes temporales y el fundido al ser atrapada.
## Sólo escucha señales de GameState.

const C_TEXTO := Color("fffaf0")
const C_BORDE := Color(0.12, 0.1, 0.18, 0.9)

var _bandada: Label
var _comida: Label
var _carga: Label
var _objetivo: Label
var _mensaje: Label
var _stamina: ProgressBar
var _estilo_stamina: StyleBoxFlat
var _fundido: ColorRect
var _aviso_fundido: Label
var _raiz: Control
var _t_mensaje := 0.0
var _pulso_bandada := 0.0


func _ready() -> void:
	layer = 5
	_armar()
	GameState.bandada_cambio.connect(_al_cambiar_bandada)
	GameState.comida_cambio.connect(func(n: int) -> void: _comida.text = "Comida: %d" % n)
	GameState.carga_cambio.connect(_al_cambiar_carga)
	GameState.stamina_cambio.connect(_al_cambiar_stamina)
	GameState.objetivo_cambio.connect(func(t: String) -> void: _objetivo.text = t)
	GameState.mensaje.connect(mostrar_mensaje)
	GameState.jugador_atrapado.connect(_al_ser_atrapada)
	GameState.victoria.connect(func() -> void: visible = false)
	# Estado inicial
	_al_cambiar_bandada(GameState.bandada)
	_comida.text = "Comida: %d" % GameState.comida
	_al_cambiar_carga(GameState.carga)
	_al_cambiar_stamina(GameState.stamina, Config.STAMINA_MAX)
	GameState.actualizar_objetivo()


func _label(padre: Control, tam: int, color := C_TEXTO) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_BORDE)
	l.add_theme_constant_override("outline_size", maxi(tam >> 2, 6))
	padre.add_child(l)
	return l


func _armar() -> void:
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_raiz = raiz

	# --- Panel izquierdo: bandada, stamina, comida ---
	var panel := PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.1, 0.1, 0.16, 0.45)
	fondo.set_corner_radius_all(14)
	fondo.content_margin_left = 16
	fondo.content_margin_right = 16
	fondo.content_margin_top = 10
	fondo.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", fondo)
	panel.position = Vector2(18, 16)
	raiz.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_bandada = _label(col, 44)
	_bandada.pivot_offset = Vector2(0, 30)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	col.add_child(fila)
	var ico := _label(fila, 18)
	ico.text = "Stamina"
	_stamina = ProgressBar.new()
	_stamina.custom_minimum_size = Vector2(200, 18)
	_stamina.show_percentage = false
	_stamina.max_value = Config.STAMINA_MAX
	_stamina.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(8)
	_estilo_stamina = StyleBoxFlat.new()
	_estilo_stamina.bg_color = Color("7fd6ff")
	_estilo_stamina.set_corner_radius_all(8)
	_stamina.add_theme_stylebox_override("background", bg)
	_stamina.add_theme_stylebox_override("fill", _estilo_stamina)
	fila.add_child(_stamina)
	_comida = _label(col, 24, Color("ffe7a8"))
	_carga = _label(col, 20, Color("ffd27a"))

	# --- Objetivo arriba al centro ---
	_objetivo = _label(raiz, 24)
	_objetivo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objetivo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objetivo.offset_left = -480
	_objetivo.offset_right = 480
	_objetivo.offset_top = 18
	_objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- Mensaje temporal (un poco arriba del centro) ---
	_mensaje = _label(raiz, 30, Color("ffe58a"))
	_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.offset_left = -520
	_mensaje.offset_right = 520
	_mensaje.offset_top = -190
	_mensaje.offset_bottom = -140
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje.modulate.a = 0.0

	# --- Ayuda de controles abajo ---
	var ayuda := _label(raiz, 15, Color(1, 1, 1, 0.75))
	ayuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.offset_left = -500
	ayuda.offset_right = 500
	ayuda.offset_top = -34
	ayuda.text = "WASD caminar · Espacio volar · Shift picada · Click izq. picotear · Click der. arrullar · Esc pausa"
	ayuda.visible = not Ajustes.movil   # en el teléfono están los botones en pantalla

	# --- Fundido al ser atrapada ---
	_fundido = ColorRect.new()
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundido.color = Color(0.08, 0.06, 0.12, 0.0)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_fundido)
	_aviso_fundido = _label(_fundido, 40)
	_aviso_fundido.set_anchors_preset(Control.PRESET_CENTER)
	_aviso_fundido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_fundido.offset_left = -400
	_aviso_fundido.offset_right = 400
	_aviso_fundido.modulate.a = 0.0


func _process(delta: float) -> void:
	if _t_mensaje > 0.0:
		_t_mensaje -= delta
		_mensaje.modulate.a = clampf(_t_mensaje * 2.0, 0.0, 1.0)
	if _pulso_bandada > 0.0:
		_pulso_bandada = maxf(_pulso_bandada - delta * 3.0, 0.0)
		_bandada.scale = Vector2.ONE * (1.0 + 0.25 * sin(_pulso_bandada * PI))


## Aparece de a poco (al terminar la transición del menú principal al juego).
func mostrar(segundos := 0.6) -> void:
	visible = true
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, segundos)


func mostrar_mensaje(texto: String, duracion: float) -> void:
	_mensaje.text = texto
	_t_mensaje = duracion
	_mensaje.modulate.a = 1.0


func _al_cambiar_bandada(n: int) -> void:
	_bandada.text = "🕊 x %d" % n
	_pulso_bandada = 1.0
	var c := C_TEXTO
	if n >= Config.UMBRAL_BALCON:
		c = Color("ffd75e")
	elif n >= Config.UMBRAL_TURISTAS:
		c = Color("c9f0ff")
	_bandada.add_theme_color_override("font_color", c)


func _al_cambiar_carga(tipo: String) -> void:
	_carga.text = ("En el pico: %s (llevala al nido)" % tipo) if tipo != "" else ""
	_carga.visible = tipo != ""


func _al_cambiar_stamina(valor: float, maximo: float) -> void:
	_stamina.max_value = maximo
	_stamina.value = valor
	var k := valor / maximo
	_estilo_stamina.bg_color = Color("ff6b6b").lerp(Color("7fd6ff"), clampf(k * 2.0, 0.0, 1.0))


func _al_ser_atrapada(motivo: String) -> void:
	var textos := {
		"granadero": "Te escoltaron de vuelta al nido...",
		"halcon": "¡Uf! Te soltó cerca del nido...",
	}
	_aviso_fundido.text = textos.get(motivo, "De vuelta al nido...")
	var tw := create_tween()
	_fundido.color.a = 0.85
	_aviso_fundido.modulate.a = 1.0
	tw.tween_interval(0.9)
	tw.tween_property(_fundido, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_aviso_fundido, "modulate:a", 0.0, 0.6)
