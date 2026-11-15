class_name PersonalizarMenu
extends PantallaMenu
## Pantalla "Mi paloma": a la izquierda la paloma de la jugadora en su propio SubViewport (con su luz
## y su cámara, sin tocar el mundo del juego); a la derecha, según el modo:
## - BÁSICO: un selector por zona de color y por slot de accesorio, ALEATORIO y RESTABLECER.
## - AVANZADO: pintura libre sobre el modelo (pincel, borrador, cuentagotas, relleno, simetría,
##   paleta y color libre, deshacer y rehacer, vistas). La paloma queda quieta y sin accesorios.
##   Se pinta texel por texel sobre la textura (ver PinturaPaloma), así sigue siendo pixel-art.
## VOLVER es el de PantallaMenu (también Esc o B). Sólo edita el PerfilPaloma en uso
## (PerfilPaloma.actual()): la paloma de la vista previa y la del menú lo siguen solas y cada cambio
## se guarda al instante.
## Controles de la vista: mouse (clic izquierdo pinta, clic derecho o arrastrar afuera gira; en el
## teléfono, el dedo) y teclado o mando con "PINTAR CON LA MIRA": las flechas o el stick mueven la
## mira, aceptar pinta y cancelar vuelve a las herramientas.

enum Herramienta { PINCEL, BORRADOR, CUENTAGOTAS, RELLENO }

## Vistas del modo pintura: [nombre, giro (rad), inclinación (rad)]. La paloma mira a la cámara en
## "Frente"; con +90° se ve su costado derecho.
const VISTAS := [["Frente", 0.0, 0.0], ["Derecha", PI * 0.5, 0.0], ["Atrás", PI, 0.0],
		["Izquierda", -PI * 0.5, 0.0], ["Arriba", 0.0, -1.0]]

const VELOCIDAD_GIRO := 0.7      ## rad/s en el modo básico
const DISTANCIA_CAMARA := 1.7
const MAX_DESHACER := 20
const VELOCIDAD_MIRA := 260.0    ## px/s
const PASO_TRAZO := 3.0          ## px entre rayos al arrastrar el pincel (que no queden huecos)
const CENTRO_PALOMA := 0.28      ## altura a la que miran la cámara y el giro vertical

## Dónde se guarda el perfil (vacío = el archivo de siempre; las pruebas usan otro).
var ruta_guardado := ""

var _perfil: PerfilPaloma
var _selectores_color: Array[SelectorPaloma] = []
var _selectores_slot: Array[SelectorPaloma] = []
var _sel_modo: SelectorPaloma
var _panel_basico: VBoxContainer
var _panel_avanzado: VBoxContainer
var _aleatorio: Button
var _restablecer: Button
var _avanzado := false

# Vista previa
var _vista: SubViewport
var _contenedor: SubViewportContainer
var _mira: Control
var _inclinador: Node3D
var _pivote: Node3D
var _modelo: ModeloPaloma
var _camara: Camera3D
var _tween_vista: Tween

# Pintura
var _sel_herramienta: SelectorPaloma
var _sel_tam: SelectorPaloma
var _sel_paleta: SelectorPaloma
var _chk_simetria: CheckBox
var _sl_h: HSlider
var _sl_s: HSlider
var _sl_v: HSlider
var _muestra: ColorRect
var _btn_pintar: Button
var _fila_pintar: Control
var _btn_deshacer: Button
var _btn_rehacer: Button
var _btn_borrar: Button
var _sel_vista: SelectorPaloma
var _herramienta := Herramienta.PINCEL
var _tam_pincel := 1
var _color := Color("e8665a")
var _simetria := true
var _deshacer: Array = []        ## Imágenes (o null = sin pintura) anteriores a cada pincelada
var _rehacer: Array = []
var _trazando := false
var _trazo_cambio := false
var _girando := false
var _ultima_trazo := Vector2.ZERO
var _cursor := Vector2.ZERO      ## Mira para teclado y mando (coordenadas de la vista)
var _cursor_activo := false


func _init() -> void:
	armar("Mi paloma")   # El título es corto: "Personalizar paloma" ocupaba dos líneas enormes
	# VOLVER más abajo que en las otras pantallas (acá hay más cosas arriba)
	var izq := get_node("Izquierda") as Control
	izq.offset_top += 56.0
	izq.offset_bottom += 56.0
	_perfil = PerfilPaloma.actual()
	_armar_vista()

	var raiz := contenido
	var modos: Array[String] = ["Básico", "Avanzado"]
	_sel_modo = SelectorPaloma.new()
	_sel_modo.configurar_texto(modos)
	_sel_modo.elegido.connect(func(p: int) -> void: _poner_modo(p == 1))
	fila("Modo", _sel_modo)
	_panel_basico = _nuevo_panel(raiz)
	contenido = _panel_basico
	_armar_basico()
	_panel_avanzado = _nuevo_panel(raiz)
	_panel_avanzado.visible = false
	contenido = _panel_avanzado
	_armar_avanzado()
	contenido = raiz

	_perfil.cambiado.connect(_al_cambiar_perfil)
	_refrescar()
	set_process(false)


func _ready() -> void:
	# El modelo se arma al entrar al árbol: los gestos (mirada, parpadeo) se agregan recién ahora
	_modelo.agregar_gestos(_camara)


func abrir() -> void:
	# Si se reemplazó el perfil en uso (pruebas), se vuelve a enlazar
	var actual := PerfilPaloma.actual()
	if actual != _perfil:
		_perfil.cambiado.disconnect(_al_cambiar_perfil)
		_perfil = actual
		_perfil.cambiado.connect(_al_cambiar_perfil)
	_deshacer.clear()
	_rehacer.clear()
	_actualizar_historial()
	_refrescar()
	_mostrar_pintar(not Input.get_connected_joypads().is_empty())
	set_process(true)
	super.abrir()
	_enlazar_extras()


func cerrar() -> void:
	_terminar_trazo()
	_poner_modo(false)
	_mostrar_pintar(false)
	set_process(false)
	super.cerrar()


## "PINTAR CON LA MIRA" sólo sirve sin mouse: aparece si hay un mando conectado o apenas se usa
## una tecla o el mando en esta pantalla.
func _input(event: InputEvent) -> void:
	if not visible or _fila_pintar.visible:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_mostrar_pintar(true)


func _mostrar_pintar(si: bool) -> void:
	if _fila_pintar.visible == si:
		return
	_fila_pintar.visible = si
	if visible and _avanzado:
		_enlazar_extras.call_deferred()


func _process(delta: float) -> void:
	if not _avanzado:
		_pivote.rotation.y += delta * VELOCIDAD_GIRO
		return
	# Mira para teclado y mando
	if _contenedor.has_focus() and _cursor_activo:
		var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if v != Vector2.ZERO:
			_cursor = (_cursor + v * VELOCIDAD_MIRA * delta).clamp(Vector2.ZERO, _contenedor.size)
		if _trazando:
			_trazar_hasta(_cursor)
		_mira.queue_redraw()


# ---------------------------------------------------------------- Armado

func _nuevo_panel(padre: Control) -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 2)
	padre.add_child(p)
	return p


## Botón de acción: caja redondeada y translúcida del color de "acento" (cyan por defecto), con
## borde claro, sombra y el foco como un aro blanco. Más prolijo que las barras inclinadas de VOLVER
## y del menú, que están hechas para ir solas y se pisan cuando hay varias en fila.
func _boton(texto: String, padre: Control, ancho := 190.0, tam_fuente := 18, acento := Color(0.247, 0.722, 0.839)) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", tam_fuente)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(ancho, 44)
	b.add_theme_stylebox_override("normal", _caja_boton(acento.lerp(Color(0, 0.05, 0.1), 0.15), 0.78, 0.55))
	b.add_theme_stylebox_override("hover", _caja_boton(acento.lightened(0.22), 0.92, 1.0))
	b.add_theme_stylebox_override("pressed", _caja_boton(acento.darkened(0.25), 0.95, 1.0))
	b.add_theme_stylebox_override("hover_pressed", _caja_boton(acento.darkened(0.25), 0.95, 1.0))
	b.add_theme_stylebox_override("disabled", _caja_boton(Color(0.35, 0.5, 0.56), 0.22, 0.2))
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.set_border_width_all(3)
	foco.border_color = Color.WHITE
	foco.set_corner_radius_all(11)
	foco.set_expand_margin_all(2)
	b.add_theme_stylebox_override("focus", foco)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	padre.add_child(b)
	return b


func _caja_boton(color: Color, alfa: float, borde: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, alfa)
	s.set_corner_radius_all(9)
	s.set_border_width_all(2)
	s.border_color = Color(1, 1, 1, borde)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	s.shadow_color = Color(0, 0.03, 0.06, 0.4)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


## Una fila centrada de botones (con un poco de aire arriba).
func _fila_de_botones() -> HBoxContainer:
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 16)
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_top", 10)
	margen.add_child(botones)
	contenido.add_child(margen)
	return botones


func _armar_basico() -> void:
	seccion("Colores")
	var nombres_color: Array[String] = []
	var colores: Array[Color] = []
	for c: Dictionary in CatalogoPaloma.PALETA:
		nombres_color.append(c["nombre"])
		colores.append(c["color"])
	for i in CatalogoPaloma.ZONAS.size():
		var s := SelectorPaloma.new()
		s.configurar_colores(colores, nombres_color)
		s.elegido.connect(func(p: int) -> void: _cambio(_perfil.set_color.bind(i, p - 1)))
		fila(CatalogoPaloma.ZONAS[i]["nombre"], s)
		_selectores_color.append(s)

	seccion("Accesorios")
	for i in CatalogoPaloma.SLOTS.size():
		var s := SelectorPaloma.new()
		var nombres: Array[String] = []
		for o in CatalogoPaloma.cantidad_opciones(i):
			nombres.append(CatalogoPaloma.nombre_opcion(i, o))
		s.configurar_texto(nombres)
		s.elegido.connect(func(p: int) -> void: _cambio(_perfil.set_accesorio.bind(i, p)))
		fila(CatalogoPaloma.SLOTS[i]["nombre"], s)
		_selectores_slot.append(s)

	var botones := _fila_de_botones()
	_aleatorio = _boton("ALEATORIO", botones, 190.0, 18, Color(0.96, 0.62, 0.2))
	_aleatorio.pressed.connect(func() -> void: _cambio(_perfil.aleatorio))
	_restablecer = _boton("RESTABLECER", botones)
	_restablecer.pressed.connect(func() -> void: _cambio(_perfil.restablecer))


func _armar_avanzado() -> void:
	# Para teclado y mando: entrar a la vista y mover la mira
	var fila_pintar := _fila_de_botones()
	_fila_pintar = fila_pintar.get_parent() as Control
	_fila_pintar.visible = false   # Sólo con mando o teclado (ver _mostrar_pintar)
	_btn_pintar = _boton("PINTAR CON LA MIRA", fila_pintar, 300.0, 18)
	_btn_pintar.pressed.connect(func() -> void:
		_cursor_activo = true
		_contenedor.grab_focus()
		_mira.queue_redraw())

	seccion("Herramientas")
	var herramientas: Array[String] = ["Pincel", "Borrador", "Cuentagotas", "Relleno"]
	_sel_herramienta = SelectorPaloma.new()
	_sel_herramienta.configurar_texto(herramientas)
	_sel_herramienta.elegido.connect(func(p: int) -> void:
		_herramienta = p as Herramienta
		_sel_herramienta.set_pos(p))
	fila("Herramienta", _sel_herramienta)
	var tamanios: Array[String] = ["1 px", "2 px", "3 px"]
	_sel_tam = SelectorPaloma.new()
	_sel_tam.configurar_texto(tamanios)
	_sel_tam.elegido.connect(func(p: int) -> void:
		_tam_pincel = p + 1
		_sel_tam.set_pos(p))
	fila("Tamaño", _sel_tam)
	_chk_simetria = CheckBox.new()
	_chk_simetria.button_pressed = _simetria
	_chk_simetria.toggled.connect(func(on: bool) -> void: _simetria = on)
	fila("Simetría", _chk_simetria)
	var nombres_vista: Array[String] = []
	for v: Array in VISTAS:
		nombres_vista.append(v[0])
	_sel_vista = SelectorPaloma.new()
	_sel_vista.configurar_texto(nombres_vista)
	_sel_vista.elegido.connect(func(p: int) -> void:
		_sel_vista.set_pos(p)
		_ver_desde(VISTAS[p][1], VISTAS[p][2]))
	fila("Vista", _sel_vista)

	seccion("Color")
	var nombres: Array[String] = []
	var colores: Array[Color] = []
	for c: Dictionary in CatalogoPaloma.PALETA_PINTURA:
		nombres.append(c["nombre"])
		colores.append(c["color"])
	_sel_paleta = SelectorPaloma.new()
	_sel_paleta.configurar_colores(colores, nombres, false)
	_sel_paleta.elegido.connect(func(p: int) -> void:
		_poner_color(colores[p])
		_sel_paleta.set_pos(p))
	fila("Paleta", _sel_paleta)
	_sl_h = deslizador(0.0, 1.0, 0.005)
	_sl_s = deslizador(0.0, 1.0, 0.005)
	_sl_v = deslizador(0.0, 1.0, 0.005)
	fila("Matiz", _sl_h)
	fila("Saturación", _sl_s)
	fila("Brillo", _sl_v)
	for s: HSlider in [_sl_h, _sl_s, _sl_v]:
		s.value_changed.connect(func(_v: float) -> void:
			_color = Color.from_hsv(_sl_h.value, _sl_s.value, _sl_v.value)
			_muestra.color = _color
			_sel_paleta.set_pos(-1))
	_muestra = ColorRect.new()
	_muestra.custom_minimum_size = Vector2(0, 22)
	_muestra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila("Muestra", _muestra)

	seccion("Edición")
	var edicion := _fila_de_botones()
	_btn_deshacer = _boton("DESHACER", edicion, 150.0, 15)
	_btn_deshacer.pressed.connect(_deshacer_paso)
	_btn_rehacer = _boton("REHACER", edicion, 150.0, 15)
	_btn_rehacer.pressed.connect(_rehacer_paso)
	_btn_borrar = _boton("BORRAR TODO", edicion, 170.0, 15, Color(0.91, 0.4, 0.35))
	_btn_borrar.pressed.connect(_borrar_todo)
	var ayuda := Label.new()
	ayuda.text = "Arrastrá sobre la paloma para pintar. Clic derecho: girar."
	ayuda.theme_type_variation = &"TextoChico"
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ayuda.custom_minimum_size = Vector2(500, 0)
	var margen_ayuda := MarginContainer.new()
	margen_ayuda.add_theme_constant_override("margin_top", 8)
	margen_ayuda.add_child(ayuda)
	contenido.add_child(margen_ayuda)

	_sel_herramienta.set_pos(0)
	_sel_tam.set_pos(0)
	_poner_color(_color)
	_actualizar_historial()


## La paloma en su propio mundo 3D transparente, dentro de una tarjeta a la izquierda.
func _armar_vista() -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.name = "Vista"
	tarjeta.theme_type_variation = &"Tarjeta"
	tarjeta.anchor_left = 0.05
	tarjeta.anchor_right = 0.41
	tarjeta.anchor_top = 0.07
	tarjeta.anchor_bottom = 0.6
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tarjeta)
	_contenedor = SubViewportContainer.new()
	_contenedor.stretch = true
	# En el teléfono la vista previa se dibuja a la mitad de resolución
	_contenedor.stretch_shrink = 2 if Ajustes.movil else 1
	_contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	_contenedor.focus_mode = Control.FOCUS_ALL
	_contenedor.gui_input.connect(_entrada_vista)
	_contenedor.focus_exited.connect(_perder_foco_vista)
	tarjeta.add_child(_contenedor)

	_vista = SubViewport.new()
	_vista.own_world_3d = true
	_vista.transparent_bg = true
	_vista.handle_input_locally = false
	_vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_vista.msaa_3d = Viewport.MSAA_DISABLED if Ajustes.movil else Viewport.MSAA_2X
	_contenedor.add_child(_vista)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.76, 0.84)
	env.environment.ambient_light_energy = 0.8
	_vista.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 160.0, 0.0)
	sol.light_energy = 1.1
	_vista.add_child(sol)
	_camara = Camera3D.new()
	_camara.fov = 30.0
	_camara.current = true
	_vista.add_child(_camara)
	# Todavía no está en el árbol: se orienta con la transformación (la paloma mira hacia -Z)
	_camara.transform = Transform3D(Basis(), Vector3(0.0, 0.42, -DISTANCIA_CAMARA)).looking_at(Vector3(0.0, CENTRO_PALOMA + 0.02, 0.0))

	# Dos giros alrededor del centro de la paloma: el de arriba inclina, el de abajo gira
	_inclinador = Node3D.new()
	_inclinador.position = Vector3(0.0, CENTRO_PALOMA, 0.0)
	_vista.add_child(_inclinador)
	_pivote = Node3D.new()
	_pivote.position = Vector3(0.0, -CENTRO_PALOMA, 0.0)
	_inclinador.add_child(_pivote)
	_modelo = ModeloPaloma.new()
	_modelo.es_jugador = true      # Toma el perfil en uso y lo sigue
	_pivote.add_child(_modelo)

	# La mira de teclado y mando, dibujada encima de la vista
	_mira = Control.new()
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mira.draw.connect(_dibujar_mira)
	_contenedor.add_child(_mira)


func _dibujar_mira() -> void:
	if not (_avanzado and _cursor_activo and _contenedor.has_focus()):
		return
	_mira.draw_arc(_cursor, 9.0, 0.0, TAU, 24, Color(0, 0, 0, 0.8), 4.0)
	_mira.draw_arc(_cursor, 9.0, 0.0, TAU, 24, Color.WHITE, 2.0)
	_mira.draw_circle(_cursor, 1.5, Color.WHITE)


# ---------------------------------------------------------------- Modos

func _poner_modo(avanzado: bool) -> void:
	_sel_modo.set_pos(1 if avanzado else 0)
	if avanzado == _avanzado:
		return
	_terminar_trazo()
	_avanzado = avanzado
	_panel_basico.visible = not avanzado
	_panel_avanzado.visible = avanzado
	_modelo.congelar(avanzado)   # Quieta, de frente y sin accesorios para poder pintar
	if avanzado:
		_ver_desde(0.0, 0.0)
		_sel_vista.set_pos(0)
		_cursor = _contenedor.size * 0.5
	else:
		_ver_desde(_pivote.rotation.y, 0.0)
		_cursor_activo = false
	_mira.queue_redraw()
	if is_inside_tree() and visible:
		_enlazar_extras.call_deferred()


## Cada modo tiene sus propios botones en fila: izquierda y derecha pasan de uno al otro.
func _enlazar_extras() -> void:
	_enlazar_foco()
	var filas: Array = [[_btn_deshacer, _btn_rehacer, _btn_borrar]] if _avanzado else [[_aleatorio, _restablecer]]
	for f: Array in filas:
		for i in f.size():
			var b := f[i] as Button
			if i > 0:
				b.focus_neighbor_left = b.get_path_to(f[i - 1] as Control)
			if i < f.size() - 1:
				b.focus_neighbor_right = b.get_path_to(f[i + 1] as Control)


func _ver_desde(giro: float, inclinacion: float) -> void:
	if _tween_vista and _tween_vista.is_valid():
		_tween_vista.kill()
	# Por el camino corto
	var actual := _pivote.rotation.y
	var destino := actual + wrapf(giro - actual, -PI, PI)
	_tween_vista = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween_vista.tween_property(_pivote, "rotation:y", destino, 0.3)
	_tween_vista.tween_property(_inclinador, "rotation:x", inclinacion, 0.3)


# ---------------------------------------------------------------- Entrada en la vista

func _entrada_vista(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_cursor_activo = false
				if _avanzado:
					_contenedor.grab_focus()
				# Pintando, un clic que no toca la paloma gira la vista
				_girando = not (_avanzado and _empezar_trazo(mb.position))
			else:
				_terminar_trazo()
				_girando = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_girando = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _trazando and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_trazar_hasta(mm.position)
		elif _girando:
			_girar(mm.relative)
	elif _avanzado and _contenedor.has_focus():
		_entrada_mira(event)


## Teclado y mando con foco en la vista: las flechas mueven la mira (se las quito al foco) y
## aceptar pinta; cancelar vuelve a las herramientas.
func _entrada_mira(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_terminar_trazo()
		_cursor_activo = false
		_mira.queue_redraw()
		_btn_pintar.grab_focus()
		_contenedor.accept_event()
	elif event.is_action("ui_left") or event.is_action("ui_right") or event.is_action("ui_up") or event.is_action("ui_down"):
		_cursor_activo = true
		_contenedor.accept_event()
	elif event.is_action_pressed("ui_accept"):
		_cursor_activo = true
		_empezar_trazo(_cursor)
		_contenedor.accept_event()
	elif event.is_action_released("ui_accept"):
		_terminar_trazo()
		_contenedor.accept_event()


func _perder_foco_vista() -> void:
	_terminar_trazo()
	_cursor_activo = false
	_mira.queue_redraw()


func _girar(relativo: Vector2) -> void:
	_pivote.rotation.y += relativo.x * 0.012
	if _avanzado:
		_inclinador.rotation.x = clampf(_inclinador.rotation.x + relativo.y * 0.008, -1.2, 1.2)


# ---------------------------------------------------------------- Pintura

## Los golpes del pincel en una posición de la vista: el que cae bajo el puntero y, con simetría,
## el que cae en el lado opuesto de la paloma (el mismo rayo reflejado en X).
func _golpes_en(pos: Vector2) -> Array[Dictionary]:
	var glb := _modelo.get_node_or_null("Paloma") as Node3D
	var res: Array[Dictionary] = []
	if glb == null or not glb.is_inside_tree():
		return res
	var p := pos / float(_contenedor.stretch_shrink)
	var inv := glb.global_transform.affine_inverse()
	var origen := inv * _camara.project_ray_origin(p)
	var dir := (inv.basis * _camara.project_ray_normal(p)).normalized()
	var g := PinturaPaloma.golpe(origen, dir)
	if not g.is_empty():
		res.append(g)
	if _simetria and _herramienta != Herramienta.CUENTAGOTAS:
		var e := PinturaPaloma.golpe(Vector3(-origen.x, origen.y, origen.z), Vector3(-dir.x, dir.y, dir.z))
		if not e.is_empty() and (g.is_empty() or e["texel"] != g["texel"]):
			res.append(e)
	return res


## Empieza una pincelada en "pos". Devuelve false si el puntero no toca la paloma.
func _empezar_trazo(pos: Vector2) -> bool:
	var golpes := _golpes_en(pos)
	if golpes.is_empty():
		return false
	if _herramienta == Herramienta.CUENTAGOTAS:
		_poner_color(PinturaPaloma.muestrear(_perfil.pintura, golpes[0]["texel"]))
		_sel_paleta.set_pos(-1)
		return true
	# Foto de la pintura de antes (para deshacer)
	_deshacer.append(_copia_pintura())
	if _deshacer.size() > MAX_DESHACER:
		_deshacer.pop_front()
	_rehacer.clear()
	_trazando = true
	_trazo_cambio = false
	_ultima_trazo = pos
	_pintar_golpes(golpes)
	if _herramienta == Herramienta.RELLENO:
		_terminar_trazo()   # El relleno es de un solo toque
	_actualizar_historial()
	return true


## Sigue la pincelada hasta "pos", con un rayo cada PASO_TRAZO píxeles para no dejar huecos.
func _trazar_hasta(pos: Vector2) -> void:
	var pasos := maxi(int(ceil(_ultima_trazo.distance_to(pos) / PASO_TRAZO)), 1)
	var desde := _ultima_trazo
	for i in range(1, pasos + 1):
		_pintar_golpes(_golpes_en(desde.lerp(pos, float(i) / pasos)))
	_ultima_trazo = pos


func _pintar_golpes(golpes: Array[Dictionary]) -> void:
	var cambio := false
	for g in golpes:
		var texel: Vector2i = g["texel"]
		match _herramienta:
			Herramienta.PINCEL:
				cambio = PinturaPaloma.pintar(_perfil.asegurar_pintura(), texel, _tam_pincel, _color) or cambio
			Herramienta.BORRADOR:
				if _perfil.pintura != null:
					cambio = PinturaPaloma.borrar(_perfil.pintura, texel, _tam_pincel) or cambio
			Herramienta.RELLENO:
				cambio = PinturaPaloma.rellenar(_perfil.asegurar_pintura(), texel, _color) or cambio
	if cambio:
		_trazo_cambio = true
		_perfil.pintura_modificada()


func _terminar_trazo() -> void:
	if not _trazando:
		return
	_trazando = false
	if _trazo_cambio:
		_perfil.fin_pincelada()   # Avisa (y se guarda)
	else:
		_deshacer.pop_back()      # No cambió nada: no hace falta deshacer
		if _perfil.pintura != null and _perfil.pintura.is_invisible():
			_perfil.pintura = null
	_actualizar_historial()


func _copia_pintura() -> Image:
	return _perfil.pintura.duplicate() if _perfil.pintura != null else null


func _deshacer_paso() -> void:
	if _deshacer.is_empty():
		return
	_rehacer.append(_copia_pintura())
	_perfil.poner_pintura(_deshacer.pop_back())
	_actualizar_historial()


func _rehacer_paso() -> void:
	if _rehacer.is_empty():
		return
	_deshacer.append(_copia_pintura())
	_perfil.poner_pintura(_rehacer.pop_back())
	_actualizar_historial()


func _borrar_todo() -> void:
	if not _perfil.hay_pintura():
		return
	_deshacer.append(_copia_pintura())
	_rehacer.clear()
	_perfil.poner_pintura(null)
	_actualizar_historial()


func _actualizar_historial() -> void:
	if _btn_deshacer == null:
		return
	_btn_deshacer.disabled = _deshacer.is_empty()
	_btn_rehacer.disabled = _rehacer.is_empty()
	_btn_borrar.disabled = not _perfil.hay_pintura()


## Cambia el color del pincel y pone los deslizadores y la muestra como ese color.
func _poner_color(c: Color) -> void:
	_color = Color(c.r, c.g, c.b, 1.0)
	_sl_h.set_value_no_signal(_color.h)
	_sl_s.set_value_no_signal(_color.s)
	_sl_v.set_value_no_signal(_color.v)
	_muestra.color = _color


# ---------------------------------------------------------------- Perfil

## Hace un cambio en el perfil (el perfil avisa y la pantalla se refresca y guarda sola).
func _cambio(accion: Callable) -> void:
	accion.call()
	AudioManager.reproducir("picoteo", -16.0)


func _refrescar() -> void:
	_sel_modo.set_pos(1 if _avanzado else 0)
	for i in _selectores_color.size():
		_selectores_color[i].set_pos(_perfil.colores[i] + 1)
	for i in _selectores_slot.size():
		_selectores_slot[i].set_pos(_perfil.accesorios[i])
	_actualizar_historial()


## Cada cambio del perfil se guarda al instante (en el teléfono la pestaña puede cerrarse sin avisar).
func _al_cambiar_perfil() -> void:
	_refrescar()
	_perfil.guardar(ruta_guardado)
