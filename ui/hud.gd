extends CanvasLayer
## HUD con el estilo del menú principal (barras cyan translúcidas cortadas en diagonal, texto
## blanco, Bebas Neue para los números y Oswald para los rótulos).
## Arriba a la izquierda: la bandada y la comida (y lo que llevás en el
## pico). Arriba a la derecha: la misión actual con su contador. Sólo escucha señales de GameState.

const TEMA := EstiloUI.TEMA
const ICONO_PALOMA := preload("res://ui/tema/iconos/paloma_hud.svg")
const MARGEN := Vector2(28, 24)
const C_CYAN := EstiloUI.C_CYAN
const C_CYAN_BORDE := EstiloUI.C_CYAN_BORDE
const C_OSCURO := EstiloUI.C_OSCURO
const ANCHO_MISION := 400.0         ## Ancho máximo del texto de la misión (en pantallas angostas se achica)
const ANCHO_BRUJULA := Vector2(340.0, 600.0)   ## Mínimo y máximo de la brújula

var _raiz: Control
var _bandada: Label
var _comida: Label
var _carga: PanelContainer
var _carga_texto: Label
var _mision: VBoxContainer
var _mision_texto: Label
var _mision_contador: Label
var _mision_barra: BarraSegmentada
var _estilo_mision: StyleBoxFlat
var _fundido: ColorRect
var _aviso_fundido: Label
var _texto_mision := ""
var _ancho_mision := ANCHO_MISION
var _brujula: Brujula
var _tween_mision: Tween


func _ready() -> void:
	layer = 5
	_armar()
	GameState.bandada_cambio.connect(_al_cambiar_bandada)
	GameState.comida_cambio.connect(_al_cambiar_comida)
	GameState.carga_cambio.connect(_al_cambiar_carga)
	GameState.objetivo_cambio.connect(_al_cambiar_objetivo)
	GameState.jugador_atrapado.connect(_al_ser_atrapada)
	GameState.victoria.connect(func() -> void: visible = false)
	# Estado inicial (sin animaciones)
	_bandada.text = str(GameState.bandada)
	_comida.text = str(GameState.comida)
	_al_cambiar_carga(GameState.carga)
	GameState.actualizar_objetivo()


# ---------------------------------------------------------------- Armado

func _armar() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.theme = TEMA
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.add_child(AnilloStamina.new())    # Atrás de todo lo demás
	_armar_estado()
	_armar_mision()
	_armar_brujula()
	_armar_fundido()
	# Entre la columna de la izquierda y la misión queda un hueco: la brújula y el texto se adaptan
	get_viewport().size_changed.connect(_ajustar_anchos)
	_ajustar_anchos()


## Arriba a la izquierda: bandada (barra cyan), comida (barra oscura) y la carga. La stamina no está
## acá: va junto a la paloma (ver AnilloStamina).
func _armar_estado() -> void:
	var col := VBoxContainer.new()
	col.name = "Estado"
	col.position = MARGEN
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(col)

	# Bandada
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", EstiloUI.caja(C_CYAN, -0.42, C_CYAN_BORDE))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	panel.add_child(fila)
	var ico := TextureRect.new()
	ico.texture = ICONO_PALOMA
	ico.custom_minimum_size = Vector2(44, 44)
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(ico)
	_bandada = EstiloUI.texto(fila, &"TituloPantalla", 62, "0")
	_bandada.custom_minimum_size = Vector2(44, 0)
	_bandada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bandada.resized.connect(func() -> void: _bandada.pivot_offset = _bandada.size / 2.0)
	EstiloUI.texto(fila, &"Seccion", 20, "PALOMAS")

	# Comida
	var barra := PanelContainer.new()
	barra.add_theme_stylebox_override("panel", EstiloUI.caja(C_OSCURO, -0.42))
	barra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(barra)
	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 12)
	barra.add_child(fila2)
	EstiloUI.texto(fila2, &"Seccion", 15, "COMIDA")
	_comida = EstiloUI.texto(fila2, &"TituloPantalla", 34, "0")
	_comida.custom_minimum_size = Vector2(30, 0)
	_comida.resized.connect(func() -> void: _comida.pivot_offset = _comida.size / 2.0)

	# Lo que llevás en el pico (sólo cuando llevás algo): blanco como un botón con foco
	_carga = PanelContainer.new()
	var estilo_carga := EstiloUI.caja(Color(1, 1, 1, 0.16), -0.42)
	estilo_carga.border_width_top = 2
	estilo_carga.border_width_bottom = 2
	estilo_carga.border_width_right = 2
	estilo_carga.border_color = Color.WHITE
	_carga.add_theme_stylebox_override("panel", estilo_carga)
	_carga.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_carga)
	var fila3 := HBoxContainer.new()
	fila3.add_theme_constant_override("separation", 10)
	_carga.add_child(fila3)
	EstiloUI.texto(fila3, &"Seccion", 15, "EN EL PICO")
	_carga_texto = EstiloUI.texto(fila3, &"Etiqueta", 17)


## Arriba a la derecha: "MISIÓN", la barra cyan con el texto y el contador, y el avance.
func _armar_mision() -> void:
	_mision = VBoxContainer.new()
	_mision.name = "Mision"
	_mision.anchor_left = 1.0
	_mision.anchor_right = 1.0
	# En el teléfono arriba a la derecha está el botón de pausa
	var derecha := MARGEN.x + (110.0 if Ajustes.movil else 0.0)
	_mision.offset_right = -derecha
	_mision.offset_left = -derecha
	_mision.offset_top = MARGEN.y
	_mision.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_mision.add_theme_constant_override("separation", 6)
	_mision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_mision)

	var titulo := EstiloUI.texto(_mision, &"Seccion", 18, "MISIÓN")
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	titulo.modulate.a = 0.9

	var panel := PanelContainer.new()
	_estilo_mision = EstiloUI.caja(C_CYAN, 0.42, C_CYAN_BORDE)
	panel.add_theme_stylebox_override("panel", _estilo_mision)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_mision.add_child(panel)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 16)
	panel.add_child(fila)
	_mision_texto = EstiloUI.texto(fila, &"Etiqueta", 18)
	_mision_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mision_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mision_texto.add_theme_constant_override("line_spacing", -2)
	_mision_contador = EstiloUI.texto(fila, &"TituloPantalla", 44)
	_mision_contador.custom_minimum_size = Vector2(0, 52)
	_mision_contador.resized.connect(func() -> void:
		_mision_contador.pivot_offset = _mision_contador.size / 2.0)

	_mision_barra = BarraSegmentada.new()
	_mision_barra.custom_minimum_size = Vector2(0, 7)
	_mision_barra.color = Color.WHITE
	_mision_barra.separacion = 3.0
	_mision_barra.size_flags_horizontal = Control.SIZE_SHRINK_END
	_mision.add_child(_mision_barra)


## Arriba al centro, entre el estado y la misión.
func _armar_brujula() -> void:
	_brujula = Brujula.new()
	_brujula.name = "Brujula"
	_brujula.anchor_left = 0.5
	_brujula.anchor_right = 0.5
	_brujula.offset_top = MARGEN.y + 4.0
	_brujula.offset_bottom = MARGEN.y + 4.0 + Brujula.ALTO
	_raiz.add_child(_brujula)


## La brújula y el texto de la misión crecen con la ventana (ocupan 30 % y 22 % del ancho) con tope.
func _ajustar_anchos() -> void:
	var ancho := get_viewport().get_visible_rect().size.x
	var b := clampf(ancho * 0.30, ANCHO_BRUJULA.x, ANCHO_BRUJULA.y)
	_brujula.offset_left = -b * 0.5
	_brujula.offset_right = b * 0.5
	_ancho_mision = clampf(ancho * 0.22, 260.0, ANCHO_MISION)
	if _texto_mision != "":
		GameState.actualizar_objetivo()


func _armar_fundido() -> void:
	_fundido = ColorRect.new()
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundido.color = Color(0.0, 0.03, 0.06, 0.0)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundido)
	_aviso_fundido = EstiloUI.texto(_fundido, &"TituloPantalla", 76)
	_aviso_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aviso_fundido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_fundido.modulate.a = 0.0


# ---------------------------------------------------------------- Actualizaciones

## Aparece de a poco (al terminar la transición del menú principal al juego).
func mostrar(segundos := 0.6) -> void:
	visible = true
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, segundos)


func _pulso(l: Label, fuerza := 0.22) -> void:
	l.scale = Vector2.ONE * (1.0 + fuerza)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _al_cambiar_bandada(n: int) -> void:
	if _bandada.text != str(n):
		_bandada.text = str(n)
		_pulso(_bandada)


func _al_cambiar_comida(n: int) -> void:
	if _comida.text != str(n):
		_comida.text = str(n)
		_pulso(_comida, 0.3)


func _al_cambiar_carga(tipo: String) -> void:
	_carga.visible = tipo != ""
	_carga_texto.text = tipo.to_upper()


func _al_cambiar_objetivo(texto: String, actual: int, meta: int) -> void:
	var nueva := texto != _texto_mision
	_texto_mision = texto
	_mision_texto.text = texto
	# El texto se corta en líneas sólo si no entra en el ancho máximo
	var fuente := _mision_texto.get_theme_font("font")
	var tam := _mision_texto.get_theme_font_size("font_size")
	var ancho := fuente.get_string_size(tr(texto), HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 4.0
	_mision_texto.custom_minimum_size.x = minf(ancho, _ancho_mision)

	var contador := "%d/%d" % [mini(actual, meta), meta] if meta > 0 else ""
	if contador != _mision_contador.text and contador != "" and not nueva:
		_pulso(_mision_contador, 0.25)
	_mision_contador.text = contador
	_mision_contador.visible = meta > 0
	_mision_barra.visible = meta > 0
	if meta > 0:
		_mision_barra.segmentos = mini(meta, 15)
		_mision_barra.valor = float(actual) / meta
		_mision_barra.custom_minimum_size.x = clampf(meta * 22.0, 90.0, 300.0)

	if nueva:
		_animar_mision_nueva()


## La misión nueva entra desde la derecha y la barra se enciende (como un botón del menú con el
## mouse encima) y vuelve de a poco a su cyan.
func _animar_mision_nueva() -> void:
	if _tween_mision and _tween_mision.is_valid():
		_tween_mision.kill()
	var derecha := -(MARGEN.x + (110.0 if Ajustes.movil else 0.0))
	_mision.modulate.a = 0.0
	_mision.offset_right = derecha + 60.0
	_mision.offset_left = derecha + 60.0
	_estilo_mision.bg_color = Color(0.85, 0.97, 1.0, 0.85)
	_tween_mision = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_mision.tween_property(_mision, "modulate:a", 1.0, 0.35)
	_tween_mision.tween_property(_mision, "offset_right", derecha, 0.45)
	_tween_mision.tween_property(_mision, "offset_left", derecha, 0.45)
	_tween_mision.tween_property(_estilo_mision, "bg_color", C_CYAN, 1.1).set_delay(0.3)


func _al_ser_atrapada(motivo: String) -> void:
	var textos := {
		"granadero": "TE ESCOLTARON AL NIDO",
		"halcon": "EL HALCÓN TE SOLTÓ",
	}
	_aviso_fundido.text = textos.get(motivo, "DE VUELTA AL NIDO")
	var tw := create_tween()
	_fundido.color.a = 0.8
	_aviso_fundido.modulate.a = 1.0
	tw.tween_interval(0.9)
	tw.tween_property(_fundido, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_aviso_fundido, "modulate:a", 0.0, 0.6)
