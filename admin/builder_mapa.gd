extends Node
## BUILDER DE MAPA (escena de administrador): en el juego se abre con F2 (ver main.gd).
## Arma la ciudad como siempre pero en "modo admin" (MapaOverrides.modo_admin): casi todo lo que pone el
## código (edificios, árboles, faroles, bancos, fuentes, autos estacionados, juegos, carteles...) queda
## suelto para tocarlo con una cámara libre. Cada cambio se guarda solo en res://mapa/overrides.json y el
## juego lo aplica encima de lo que genera el código (nada del mapa original se pierde: "X" restaura).

const TEXTO_AYUDA := "[center][b][font_size=22]BUILDER DE MAPA[/font_size][/b]\n[color=#9ad]modo administrador[/color][/center]\n\n" \
	+ "[b]CÁMARA[/b]\n" \
	+ "  • Mantené [b]clic derecho[/b] y mové el mouse para mirar\n" \
	+ "  • [b]W A S D[/b] moverte · [b]Espacio[/b] subir · [b]C[/b] bajar · [b]Shift[/b] más rápido · [b]rueda[/b]: velocidad\n" \
	+ "  • [b]Y[/b] vista desde arriba (otra vez Y: vuelve) · [b].[/b] (punto) enfocar lo elegido · [b]Inicio[/b] vista general\n\n" \
	+ "[b]ELEGIR[/b]\n" \
	+ "  • [b]Clic izquierdo[/b] elige una pieza y [b]arrastrando[/b] la movés · [b]Ctrl+clic[/b] suma o saca de la selección\n" \
	+ "  • [b]Arrastrar en el vacío[/b] dibuja un recuadro y elige todo lo de adentro · [b]Ctrl+A[/b] elige todo\n" \
	+ "  • Cuadro \"Se puede elegir\" (arriba a la izquierda): edificios, props, suelo\n\n" \
	+ "[b]EDITAR (todo lo elegido junto)[/b]\n" \
	+ "  • [b]Q / E[/b] girar (con Shift, 90°) · [b]R / F[/b] subir / bajar · [b]+ / −[/b] agrandar / achicar\n" \
	+ "  • [b]Flechas[/b] empujar 10 cm (Shift: 1 m) · [b]T[/b] apoyar en el piso · [b]Supr[/b] borrar · [b]Ctrl+D[/b] duplicar\n" \
	+ "  • [b]X[/b] volver a su lugar original · [b]Ctrl+Z[/b] deshacer · [b]Ctrl+Y[/b] rehacer · [b]Esc[/b] soltar\n" \
	+ "  • El cuadro de la izquierda deja escribir posición, giro y escala (también por eje) con números\n\n" \
	+ "[b]OTROS[/b]\n" \
	+ "  • [b]Tab[/b] paleta: agregar edificios, props, parque... (buscador y categorías)\n" \
	+ "  • [b]G[/b] grilla de 0,5 m · [b]H[/b] esta ayuda · [b]F2[/b] menú del builder · [b]F6[/b] clima · [b]F7[/b] hora\n" \
	+ "  • [b]F9[/b] volver al juego (y en el juego, [b]F2[/b] te trae de nuevo acá, mirando donde estabas)\n" \
	+ "  • Se guarda solo después de cada cambio ([b]Ctrl+S[/b] guarda ya mismo)\n\n" \
	+ "[color=#9ad]Ojo: si movés un edificio, sus pisos de arriba y sus luces de ventanas se arman aparte y no lo siguen.[/color]"

const PASO_ROTACION := 15.0
const PASO_ALTURA := 0.1
const GRILLA := 0.5
const MAX_RESALTADOS := 250

var plaza: Node3D
var camara: Camera3D
var _yaw := 0.0
var _pitch := -0.55
var _vel := 25.0
var _mirando := false
var _vista_arriba := false
var _pitch_previo := -0.55

var _sels: Array[Node3D] = []          ## Lo elegido; la última es la "principal" (la del cuadro de valores)
var _arrastre := false
var _desfase := Vector3.ZERO
var _plano_y := 0.0
var _pos_previas := {}                 ## Nodo -> estado al empezar a arrastrar
var _inicio_arrastre := Vector3.ZERO   ## Posición de la principal al empezar a arrastrar
var _recuadro := false
var _recuadro_ini := Vector2.ZERO
var _snap := false
var _hist: Array = []                  ## Cada entrada es una acción: lista de {nodo, antes, despues}
var _rehacer: Array = []
var _guardado := ""
var _filtro := {"edificio": true, "prop": true, "suelo": false}

var _resaltados: Array[MeshInstance3D] = []
var _ui_estado: Label
var _ui_ayuda: PanelContainer
var _ui_paleta: PanelContainer
var _ui_valores: PanelContainer
var _ui_recuadro: ColorRect
var _lista: ItemList
var _buscar: LineEdit
var _categoria: OptionButton
var _paleta: Array = []        ## [tipo, pieza] por fila de la lista
var _timer: Timer
var _campos := {}              ## "px","py","pz","giro","ex","ey","ez" -> SpinBox
var _pareja: CheckBox
var _refrescando := false


func _ready() -> void:
	MapaOverrides.modo_admin = true
	MapaOverrides.recargar()
	plaza = (load("res://world/plaza.tscn") as PackedScene).instantiate()
	add_child(plaza)
	# Sin autos yendo y viniendo: acá se acomoda el mapa
	var transito := plaza.get_node_or_null("Transito")
	if transito:
		transito.queue_free()

	camara = Camera3D.new()
	camara.far = 900.0
	camara.fov = 70.0
	camara.near = 0.1
	add_child(camara)
	camara.position = Vector3(0, 55, 95)
	_yaw = 0.0
	_pitch = -0.5
	if MapaOverrides.camara_inicial is Vector3:
		# Viene del juego (F2): arranca mirando el lugar donde estaba la jugadora
		var q: Vector3 = MapaOverrides.camara_inicial
		camara.position = q + Vector3(0, 22, 28)
		_pitch = -0.6
		MapaOverrides.camara_inicial = null
	_orientar()
	camara.make_current()

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.4
	_timer.timeout.connect(_guardar)
	add_child(_timer)

	_armar_ui()
	_estado_texto()


func _exit_tree() -> void:
	if _timer and not _timer.is_stopped():
		_guardar()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MapaOverrides.modo_admin = false


# ---------------------------------------------------------------- Interfaz

func _armar_ui() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	add_child(capa)

	# Barra de abajo: qué hay elegido y recordatorio de teclas
	var barra := PanelContainer.new()
	barra.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	barra.offset_top = -62
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.07, 0.1, 0.8)))
	capa.add_child(barra)
	_ui_estado = Label.new()
	_ui_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_estado.add_theme_font_size_override("font_size", 15)
	barra.add_child(_ui_estado)

	# Recuadro de selección
	_ui_recuadro = ColorRect.new()
	_ui_recuadro.color = Color(1.0, 0.65, 0.1, 0.18)
	_ui_recuadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_recuadro.visible = false
	capa.add_child(_ui_recuadro)

	# Arriba a la izquierda: qué se puede elegir + valores de lo elegido
	var izq := VBoxContainer.new()
	izq.position = Vector2(12, 12)
	izq.add_theme_constant_override("separation", 8)
	capa.add_child(izq)

	var filtros := PanelContainer.new()
	filtros.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.07, 0.1, 0.85), 8))
	izq.add_child(filtros)
	var fv := VBoxContainer.new()
	filtros.add_child(fv)
	var ft := Label.new()
	ft.text = "Se puede elegir:"
	ft.add_theme_font_size_override("font_size", 13)
	fv.add_child(ft)
	for par: Array in [["edificio", "Edificios"], ["prop", "Props (árboles, bancos, autos...)"], ["suelo", "Suelo (losetas, canchas)"]]:
		var c := CheckBox.new()
		c.text = par[1]
		c.button_pressed = _filtro[par[0]]
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 13)
		c.toggled.connect(func(v: bool) -> void:
			_filtro[par[0]] = v
			_sels.assign(_sels.filter(func(n: Node3D) -> bool: return _filtro.get(String(n.get_meta(&"categoria", "prop")), true)))
			_estado_texto())
		fv.add_child(c)

	_ui_valores = PanelContainer.new()
	_ui_valores.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.07, 0.1, 0.88), 8))
	_ui_valores.visible = false
	izq.add_child(_ui_valores)
	var vv := VBoxContainer.new()
	_ui_valores.add_child(vv)
	var vt := Label.new()
	vt.text = "VALORES (principal)"
	vt.add_theme_font_size_override("font_size", 13)
	vv.add_child(vt)
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	vv.add_child(rejilla)
	_campo(rejilla, "px", "X", -2000.0, 2000.0, 0.1)
	_campo(rejilla, "py", "Altura", -200.0, 500.0, 0.05)
	_campo(rejilla, "pz", "Z", -2000.0, 2000.0, 0.1)
	_campo(rejilla, "giro", "Giro °", -3600.0, 3600.0, 1.0)
	_campo(rejilla, "ex", "Escala X", 0.05, 40.0, 0.05)
	_campo(rejilla, "ey", "Escala Y", 0.05, 40.0, 0.05)
	_campo(rejilla, "ez", "Escala Z", 0.05, 40.0, 0.05)
	_pareja = CheckBox.new()
	_pareja.text = "Escala pareja (X=Y=Z)"
	_pareja.button_pressed = true
	_pareja.focus_mode = Control.FOCUS_NONE
	_pareja.add_theme_font_size_override("font_size", 13)
	vv.add_child(_pareja)

	# Paleta (a la derecha, Tab)
	_ui_paleta = PanelContainer.new()
	_ui_paleta.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_ui_paleta.offset_left = -270
	_ui_paleta.offset_top = 12
	_ui_paleta.offset_bottom = -72
	_ui_paleta.offset_right = -12
	_ui_paleta.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.07, 0.1, 0.88)))
	_ui_paleta.visible = false
	capa.add_child(_ui_paleta)
	var caja := VBoxContainer.new()
	_ui_paleta.add_child(caja)
	var titulo := Label.new()
	titulo.text = "AGREGAR PIEZA\n(doble clic: va al centro de la pantalla)"
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.custom_minimum_size = Vector2(240, 0)
	caja.add_child(titulo)
	_categoria = OptionButton.new()
	for t: String in ["Todo", "Edificios", "Props", "Parque", "Suelo", "De la plaza"]:
		_categoria.add_item(t)
	_categoria.focus_mode = Control.FOCUS_NONE
	_categoria.item_selected.connect(func(_i: int) -> void: _llenar_paleta())
	caja.add_child(_categoria)
	_buscar = LineEdit.new()
	_buscar.placeholder_text = "Buscar..."
	_buscar.clear_button_enabled = true
	_buscar.text_changed.connect(func(_t: String) -> void: _llenar_paleta())
	_buscar.text_submitted.connect(func(_t: String) -> void: _buscar.release_focus())
	caja.add_child(_buscar)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.focus_mode = Control.FOCUS_NONE
	_lista.item_activated.connect(_agregar_de_paleta)
	caja.add_child(_lista)
	_llenar_paleta()

	# Ayuda del principio (centrada)
	_ui_ayuda = PanelContainer.new()
	_ui_ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ui_ayuda.custom_minimum_size = Vector2(700, 0)
	_ui_ayuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ui_ayuda.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ui_ayuda.add_theme_stylebox_override("panel", _estilo(Color(0.06, 0.09, 0.13, 0.96), 22))
	capa.add_child(_ui_ayuda)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_ui_ayuda.add_child(v)
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.custom_minimum_size = Vector2(660, 0)
	texto.add_theme_font_size_override("normal_font_size", 15)
	texto.add_theme_font_size_override("bold_font_size", 15)
	texto.text = TEXTO_AYUDA
	v.add_child(texto)
	var boton := Button.new()
	boton.text = "Entendido  (Enter)"
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func() -> void: _ui_ayuda.visible = false)
	v.add_child(boton)


func _campo(rejilla: GridContainer, clave: String, etiqueta: String, mn: float, mx: float, paso: float) -> void:
	var l := Label.new()
	l.text = etiqueta
	l.add_theme_font_size_override("font_size", 13)
	rejilla.add_child(l)
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = paso if clave != "giro" else 1.0
	s.allow_greater = true
	s.allow_lesser = true
	s.custom_minimum_size = Vector2(110, 0)
	s.value_changed.connect(func(v: float) -> void: _desde_campo(clave, v))
	s.get_line_edit().text_submitted.connect(func(_t: String) -> void: s.get_line_edit().release_focus())
	rejilla.add_child(s)
	_campos[clave] = s


func _estilo(color: Color, margen := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(margen)
	s.set_corner_radius_all(8)
	return s


## Todas las piezas que se pueden agregar: [categoría, tipo, pieza, texto].
func _todas_las_piezas() -> Array:
	var out: Array = [["De la plaza", "banco", "banco", "Banco de plaza"], ["De la plaza", "farol", "farol", "Farol de plaza"],
		["De la plaza", "jacaranda", "jacaranda", "Jacarandá de plaza"]]
	var nombres: Array[String] = []
	for n: String in KitDatos.PIEZAS:
		nombres.append(n)
	for n: String in Kit.PARQUE_COL:
		if not nombres.has(n):
			nombres.append(n)
	for n: String in Kit.LOSETAS_PARQUE:
		if not nombres.has(n):
			nombres.append(n)
	nombres.sort()
	for n in nombres:
		var cat := MapaOverrides.categoria("kit", n)
		var grupo := "Props"
		if cat == "edificio":
			grupo = "Edificios"
		elif cat == "suelo":
			grupo = "Suelo"
		elif not KitDatos.PIEZAS.has(n):
			grupo = "Parque"
		out.append([grupo, "kit", n, n.replace("_", " ")])
	return out


func _llenar_paleta() -> void:
	_lista.clear()
	_paleta.clear()
	var cat := _categoria.get_item_text(_categoria.selected)
	var q := _buscar.text.strip_edges().to_lower().replace(" ", "_")
	for p: Array in _todas_las_piezas():
		if cat != "Todo" and p[0] != cat:
			continue
		if q != "" and not (String(p[2]).to_lower().contains(q) or String(p[3]).to_lower().contains(q.replace("_", " "))):
			continue
		_paleta.append([p[1], p[2]])
		_lista.add_item("%s   ·   %s" % [p[3], p[0]] if cat == "Todo" else String(p[3]))


func _estado_texto() -> void:
	var t := ""
	if _sels.size() == 1:
		var n := _sels[0]
		t = "%s   ·   pos (%.1f, %.1f, %.1f)   ·   giro %d°   ·   escala %.2f\n" % [
			String(n.get_meta(&"nombre_pieza")), n.position.x, n.position.y, n.position.z,
			roundi(rad_to_deg(n.rotation.y)), n.scale.x]
	elif _sels.size() > 1:
		t = "%d piezas elegidas (juntas: mover, girar, escalar, duplicar, borrar)\n" % _sels.size()
	else:
		t = "Clic izquierdo elige · arrastrar en el vacío elige varias · F2: menú · F9: volver al juego\n"
	var r := MapaOverrides.resumen()
	t += "Grilla %s (G)   ·   Cámara %d m/s (rueda)   ·   Cambios: %d movidas, %d borradas, %d agregadas   ·   %s" % [
		"SÍ" if _snap else "no", roundi(_vel), r[0], r[1], r[2],
		_guardado if _guardado != "" else "Sin cambios guardados todavía"]
	_ui_estado.text = t
	_actualizar_campos()


func _actualizar_campos() -> void:
	_ui_valores.visible = not _sels.is_empty()
	if _sels.is_empty():
		return
	var n := _sels[_sels.size() - 1]
	_refrescando = true
	(_campos["px"] as SpinBox).set_value_no_signal(n.position.x)
	(_campos["py"] as SpinBox).set_value_no_signal(n.position.y)
	(_campos["pz"] as SpinBox).set_value_no_signal(n.position.z)
	(_campos["giro"] as SpinBox).set_value_no_signal(snappedf(rad_to_deg(n.rotation.y), 0.1))
	(_campos["ex"] as SpinBox).set_value_no_signal(n.scale.x)
	(_campos["ey"] as SpinBox).set_value_no_signal(n.scale.y)
	(_campos["ez"] as SpinBox).set_value_no_signal(n.scale.z)
	var sin_escala := n.has_meta(&"sin_escala")
	for k: String in ["ex", "ey", "ez"]:
		(_campos[k] as SpinBox).editable = not sin_escala
	_refrescando = false


## Se escribió un número en el cuadro de valores: la principal toma el valor y las demás lo mismo en relación.
func _desde_campo(clave: String, v: float) -> void:
	if _refrescando or _sels.is_empty():
		return
	var prin := _sels[_sels.size() - 1]
	var viejo_pos := prin.position
	var viejo_rot := prin.rotation.y
	var viejo_esc := prin.scale
	var pareja := _pareja.button_pressed
	_editar(func(n: Node3D) -> void: _poner_valor(n, clave, v, viejo_pos, viejo_rot, viejo_esc, pareja))


func _poner_valor(n: Node3D, clave: String, v: float, viejo_pos: Vector3, viejo_rot: float, viejo_esc: Vector3,
		pareja: bool) -> void:
	match clave:
		"px":
			n.position.x += v - viejo_pos.x
		"py":
			n.position.y += v - viejo_pos.y
		"pz":
			n.position.z += v - viejo_pos.z
		"giro":
			n.rotation.y += deg_to_rad(v) - viejo_rot
		_:
			if n.has_meta(&"sin_escala"):
				return
			var eje := 0 if clave == "ex" else (1 if clave == "ey" else 2)
			var factor := v / maxf(viejo_esc[eje], 0.0001)
			if pareja:
				n.scale *= factor
			else:
				var s := n.scale
				s[eje] *= factor
				n.scale = s


# ---------------------------------------------------------------- Cámara

func _orientar() -> void:
	camara.rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	var escribiendo := get_viewport().gui_get_focus_owner() is LineEdit
	if not Input.is_key_pressed(KEY_CTRL) and not escribiendo:
		var b := camara.global_transform.basis
		if Input.is_physical_key_pressed(KEY_W): dir -= b.z
		if Input.is_physical_key_pressed(KEY_S): dir += b.z
		if Input.is_physical_key_pressed(KEY_A): dir -= b.x
		if Input.is_physical_key_pressed(KEY_D): dir += b.x
		if Input.is_physical_key_pressed(KEY_SPACE): dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_C): dir -= Vector3.UP
	if dir != Vector3.ZERO:
		var v := _vel * (3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		camara.global_position += dir.normalized() * v * delta
	_actualizar_resaltados()
	if _recuadro:
		var a := _recuadro_ini
		var b2 := get_viewport().get_mouse_position()
		_ui_recuadro.position = Vector2(minf(a.x, b2.x), minf(a.y, b2.y))
		_ui_recuadro.size = (a - b2).abs()
		_ui_recuadro.visible = _ui_recuadro.size.length() > 4.0


func _actualizar_resaltados() -> void:
	var n_sel := mini(_sels.size(), MAX_RESALTADOS)
	while _resaltados.size() < n_sel:
		var r := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3.ONE
		r.mesh = caja
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.65, 0.1, 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		r.material_override = m
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(r)
		_resaltados.append(r)
	for i in _resaltados.size():
		var r := _resaltados[i]
		if i >= n_sel or not is_instance_valid(_sels[i]):
			r.visible = false
			continue
		var n := _sels[i]
		var a := _aabb_de(n)
		r.visible = n.visible
		r.global_transform = n.global_transform * Transform3D(Basis.from_scale(a.size.max(Vector3.ONE * 0.2)), a.get_center())


## Mueve la cámara para ver lo elegido (o todo el mapa si no hay nada).
func _enfocar() -> void:
	if _sels.is_empty():
		return
	var c := _centro()
	var radio := 4.0
	for n in _sels:
		radio = maxf(radio, _aabb_de(n).size.length() * 0.5 * n.scale.x + n.global_position.distance_to(c))
	_vista_arriba = false
	_pitch = -0.6
	_orientar()
	camara.global_position = c - camara.global_transform.basis.z * radio * 2.4


func _vista_general() -> void:
	_vista_arriba = false
	_yaw = 0.0
	_pitch = -0.5
	_orientar()
	camara.global_position = Vector3(0, 55, 95)


func _alternar_vista_arriba() -> void:
	_vista_arriba = not _vista_arriba
	if _vista_arriba:
		_pitch_previo = _pitch
		_pitch = -1.5
		camara.global_position.y = maxf(camara.global_position.y, 80.0)
	else:
		_pitch = _pitch_previo
	_orientar()


# ---------------------------------------------------------------- Selección y ayudas de geometría

## Caja que envuelve la pieza, en coordenadas locales de su nodo (se calcula una sola vez).
func _aabb_de(n: Node3D) -> AABB:
	if n.has_meta(&"aabb_local"):
		return n.get_meta(&"aabb_local")
	var inv := n.global_transform.affine_inverse()
	var res := AABB()
	var primero := true
	var pendientes: Array[Node] = [n]
	while not pendientes.is_empty():
		var x: Node = pendientes.pop_back()
		for h in x.get_children():
			if h.is_in_group("luces_noche"):
				continue   # los charcos de luz de los faroles miden 9 m: no cuentan
			var mi := h as MeshInstance3D
			if mi and mi.mesh:
				var a := (inv * mi.global_transform) * mi.mesh.get_aabb()
				res = a if primero else res.merge(a)
				primero = false
			pendientes.append(h)
	if primero:
		res = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1.5, 1))
	res = res.grow(0.12)
	n.set_meta(&"aabb_local", res)
	return res


func _elegible(n: Node3D) -> bool:
	return n != null and is_instance_valid(n) and n.visible and _filtro.get(String(n.get_meta(&"categoria", "prop")), true)


func _elegir(pantalla: Vector2) -> Node3D:
	var o := camara.project_ray_origin(pantalla)
	var d := camara.project_ray_normal(pantalla)
	var mejor: Node3D = null
	var mejor_t := INF
	for x in get_tree().get_nodes_in_group(MapaOverrides.GRUPO):
		var n := x as Node3D
		if not _elegible(n):
			continue
		var inv := n.global_transform.affine_inverse()
		var hit: Variant = _aabb_de(n).intersects_ray(inv * o, inv.basis * d)
		if hit != null:
			var t := o.distance_to(n.global_transform * (hit as Vector3))
			if t < mejor_t:
				mejor_t = t
				mejor = n
	return mejor


func _elegir_en_recuadro(r: Rect2, sumar: bool) -> void:
	if not sumar:
		_sels.clear()
	for x in get_tree().get_nodes_in_group(MapaOverrides.GRUPO):
		var n := x as Node3D
		if not _elegible(n) or _sels.has(n):
			continue
		var c := n.global_transform * _aabb_de(n).get_center()
		if camara.is_position_behind(c):
			continue
		if r.has_point(camara.unproject_position(c)):
			_sels.append(n)


func _centro() -> Vector3:
	var c := Vector3.ZERO
	for n in _sels:
		c += n.global_position
	return c / maxf(_sels.size(), 1.0)


func _suelo_en(pantalla: Vector2) -> Vector3:
	var o := camara.project_ray_origin(pantalla)
	var d := camara.project_ray_normal(pantalla)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 700.0)
	var h := camara.get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		return h["position"]
	var p: Variant = Plane(Vector3.UP, 0.0).intersects_ray(o, d)
	return (p as Vector3) if p != null else o + d * 20.0


# ---------------------------------------------------------------- Edición

func _estado(n: Node3D) -> Dictionary:
	return {"pos": n.position, "rot": n.rotation.y, "escala": n.scale, "visible": n.visible}


func _aplicar(n: Node3D, e: Dictionary) -> void:
	n.position = e["pos"]
	n.rotation.y = e["rot"]
	n.scale = e["escala"]
	n.visible = e["visible"]


## Anota una acción (de una o varias piezas) para deshacerla y guarda.
func _confirmar(acciones: Array) -> void:
	var reales: Array = []
	for a: Dictionary in acciones:
		var n: Node3D = a["nodo"]
		a["despues"] = _estado(n)
		if a["despues"] != a["antes"]:
			reales.append(a)
			MapaOverrides.anotar(n)
	if reales.is_empty():
		return
	_hist.append(reales)
	_rehacer.clear()
	_refrescar_luces(reales.map(func(a: Dictionary) -> Node: return a["nodo"]))
	if _hist.size() > 300:
		_hist.pop_front()
	_timer.start()
	_guardado = "Guardando..."
	_estado_texto()


## Aplica "cambio" (Callable(Node3D)) a todo lo elegido como una sola acción.
func _editar(cambio: Callable) -> void:
	if _sels.is_empty():
		return
	var acciones: Array = []
	for n in _sels:
		acciones.append({"nodo": n, "antes": _estado(n)})
	for n in _sels:
		cambio.call(n)
	_confirmar(acciones)
	_estado_texto()


## Si se tocó algún farol, rehace las luces de la noche para que no queden bolas de luz sin lámpara.
func _refrescar_luces(nodos: Array) -> void:
	for n in nodos:
		if is_instance_valid(n) and (n as Node).has_meta(&"nombre_pieza") \n				and LucesNoche.es_farol(String((n as Node).get_meta(&"nombre_pieza"))):
			var ciudad := plaza.get_node_or_null("Ciudad") as Ciudad
			if ciudad:
				LucesNoche.reconstruir(ciudad)
			return


func _guardar() -> void:
	_guardado = ("Guardado ✓  %s" % Time.get_time_string_from_system()) if MapaOverrides.guardar() \
		else "⚠ NO se pudo guardar (el builder tiene que correr desde el editor de Godot)"
	_estado_texto()


func _soltar() -> void:
	_sels.clear()
	_arrastre = false
	_estado_texto()


func _deshacer_ultimo() -> void:
	if _hist.is_empty():
		return
	var acc: Array = _hist.pop_back()
	_rehacer.append(acc)
	_sels.clear()
	for a: Dictionary in acc:
		var n: Node3D = a["nodo"]
		if not is_instance_valid(n):
			continue
		_aplicar(n, a["antes"])
		MapaOverrides.anotar(n)
		if n.visible:
			_sels.append(n)
	_refrescar_luces(acc.map(func(a: Dictionary) -> Node: return a["nodo"]))
	_timer.start()
	_estado_texto()


func _rehacer_ultimo() -> void:
	if _rehacer.is_empty():
		return
	var acc: Array = _rehacer.pop_back()
	_hist.append(acc)
	_sels.clear()
	for a: Dictionary in acc:
		var n: Node3D = a["nodo"]
		if not is_instance_valid(n):
			continue
		_aplicar(n, a["despues"])
		MapaOverrides.anotar(n)
		if n.visible:
			_sels.append(n)
	_refrescar_luces(acc.map(func(a: Dictionary) -> Node: return a["nodo"]))
	_timer.start()
	_estado_texto()


func _duplicar() -> void:
	if _sels.is_empty():
		return
	var nuevas: Array[Node3D] = []
	var acciones: Array = []
	var salto := camara.global_transform.basis.x
	salto.y = 0.0
	salto = salto.normalized() * 2.0
	var omitidas := 0
	for n in _sels:
		var tipo: String = n.get_meta(&"tipo_pieza")
		if tipo == "fuente":
			omitidas += 1
			continue
		var escala := n.scale
		if tipo == "jacaranda":
			escala *= float(n.get_meta(&"param_escala", 1.0))
		var e := MapaOverrides.agregar(tipo, String(n.get_meta(&"nombre_pieza")), n.position + salto, n.rotation.y, escala)
		var copia := _armar_agregada(e)
		if copia:
			nuevas.append(copia)
			acciones.append({"nodo": copia, "antes": {"pos": copia.position, "rot": copia.rotation.y, "escala": copia.scale, "visible": false}})
	if nuevas.is_empty():
		_guardado = "Las fuentes no se duplican (sólo se mueven o se giran)"
		_estado_texto()
		return
	_sels.assign(nuevas)
	_confirmar(acciones)
	if omitidas > 0:
		_guardado = "Duplicado (las fuentes no se duplican)"
	_estado_texto()


func _agregar_de_paleta(i: int) -> void:
	var p: Array = _paleta[i]
	var centro := get_viewport().get_visible_rect().size / 2.0
	var pos := _suelo_en(centro)
	var e := MapaOverrides.agregar(String(p[0]), String(p[1]), pos, camara.rotation.y, Vector3.ONE)
	var n := _armar_agregada(e)
	if n:
		_sels.assign([n])
		_confirmar([{"nodo": n, "antes": {"pos": n.position, "rot": n.rotation.y, "escala": n.scale, "visible": false}}])
	_estado_texto()


## Arma una pieza agregada (copia o de la paleta) y devuelve su nodo editable.
func _armar_agregada(e: Dictionary) -> Node3D:
	var ciudad := plaza.get_node_or_null("Ciudad")
	if ciudad == null:
		return null
	var a: Array = e["pos"]
	var pos := Vector3(a[0], a[1], a[2])
	var rot := float(e["rot"])
	var s: Array = e["escala"]
	var escala := Vector3(s[0], s[1], s[2])
	MapaOverrides.forzar_id = String(e["id"])
	match String(e["tipo"]):
		"kit": ciudad.call("_poner", String(e["pieza"]), pos, rot, escala)
		"banco": Edificios.banco(ciudad, pos, rot)
		"farol": Edificios.farol(ciudad, pos)
		"jacaranda": Edificios.jacaranda(ciudad, pos, 1.0)
	MapaOverrides.forzar_id = ""
	for x in get_tree().get_nodes_in_group(MapaOverrides.GRUPO):
		if x.get_meta(&"id_pieza") == e["id"]:
			return x as Node3D
	return null


# ---------------------------------------------------------------- Entrada

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_mirando = mb.pressed
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					get_viewport().gui_release_focus()
					_clic(mb)
				else:
					_soltar_clic(mb)
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_vel = minf(_vel * 1.2, 300.0)
					_estado_texto()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_vel = maxf(_vel / 1.2, 2.0)
					_estado_texto()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mirando:
			_yaw -= mm.relative.x * 0.003
			_pitch = clampf(_pitch - mm.relative.y * 0.003, -1.5, 1.5)
			_orientar()
		elif _arrastre and not _sels.is_empty():
			var o := camara.project_ray_origin(mm.position)
			var d := camara.project_ray_normal(mm.position)
			var p: Variant = Plane(Vector3.UP, _plano_y).intersects_ray(o, d)
			if p != null:
				var prin := _sels[_sels.size() - 1]
				var nueva: Vector3 = (p as Vector3) - _desfase
				if _snap:
					nueva.x = snappedf(nueva.x, GRILLA)
					nueva.z = snappedf(nueva.z, GRILLA)
				var delta := nueva - _inicio_arrastre
				for n in _sels:
					var e0: Dictionary = _pos_previas[n]
					n.global_position = (e0["pos"] as Vector3) + delta
				prin.global_position = nueva
				_estado_texto()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_tecla(event as InputEventKey)


func _clic(mb: InputEventMouseButton) -> void:
	_arrastre = false
	_recuadro = false
	var sumar := mb.ctrl_pressed
	var n := _elegir(mb.position)
	if n == null:
		# Vacío: empieza un recuadro de selección
		if not sumar:
			_sels.clear()
		_recuadro = true
		_recuadro_ini = mb.position
		_estado_texto()
		return
	if sumar:
		if _sels.has(n):
			_sels.erase(n)
		else:
			_sels.append(n)
		_estado_texto()
		return
	if _sels.has(n):
		_sels.erase(n)          # sigue elegida pero pasa a ser la principal
		_sels.append(n)
	else:
		_sels.assign([n])
	var o := camara.project_ray_origin(mb.position)
	var d := camara.project_ray_normal(mb.position)
	_plano_y = n.global_position.y
	var p: Variant = Plane(Vector3.UP, _plano_y).intersects_ray(o, d)
	if p != null:
		_desfase = (p as Vector3) - n.global_position
		_inicio_arrastre = n.global_position
		_pos_previas.clear()
		for s in _sels:
			_pos_previas[s] = _estado(s)
		_arrastre = true
	_estado_texto()


func _soltar_clic(mb: InputEventMouseButton) -> void:
	if _recuadro:
		_recuadro = false
		_ui_recuadro.visible = false
		var a := _recuadro_ini
		var r := Rect2(Vector2(minf(a.x, mb.position.x), minf(a.y, mb.position.y)), (a - mb.position).abs())
		if r.size.length() > 6.0:
			_elegir_en_recuadro(r, mb.ctrl_pressed)
		_estado_texto()
	elif _arrastre:
		_arrastre = false
		var acciones: Array = []
		for s in _sels:
			if _pos_previas.has(s):
				acciones.append({"nodo": s, "antes": _pos_previas[s]})
		_confirmar(acciones)
		_estado_texto()


func _tecla(k: InputEventKey) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return   # se está escribiendo en un cuadro
	var fuerte := k.shift_pressed
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z:
				if fuerte: _rehacer_ultimo()
				else: _deshacer_ultimo()
			KEY_Y: _rehacer_ultimo()
			KEY_D: _duplicar()
			KEY_S: _guardar()
			KEY_A:
				_sels.clear()
				for x in get_tree().get_nodes_in_group(MapaOverrides.GRUPO):
					if _elegible(x as Node3D):
						_sels.append(x as Node3D)
				_estado_texto()
		return
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_ui_ayuda.visible = false
		KEY_F9:
			get_tree().change_scene_to_file("res://main.tscn")   # volver al juego
		KEY_F2:
			# Menú del builder: ayuda y paleta juntas
			var abrir := not (_ui_ayuda.visible or _ui_paleta.visible)
			_ui_ayuda.visible = abrir
			_ui_paleta.visible = abrir
		KEY_H:
			_ui_ayuda.visible = not _ui_ayuda.visible
		KEY_TAB:
			_ui_paleta.visible = not _ui_paleta.visible
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _ui_ayuda.visible:
				_ui_ayuda.visible = false
			else:
				_soltar()
		KEY_G:
			_snap = not _snap
			_estado_texto()
		KEY_Y:
			_alternar_vista_arriba()
		KEY_PERIOD, KEY_KP_PERIOD:
			_enfocar()
		KEY_HOME:
			_vista_general()
		KEY_Q:
			_rotar(deg_to_rad(90.0 if fuerte else PASO_ROTACION))
		KEY_E:
			_rotar(-deg_to_rad(90.0 if fuerte else PASO_ROTACION))
		KEY_R:
			_editar(func(n: Node3D) -> void: n.position.y += 1.0 if fuerte else PASO_ALTURA)
		KEY_F:
			_editar(func(n: Node3D) -> void: n.position.y -= 1.0 if fuerte else PASO_ALTURA)
		KEY_LEFT:
			_empujar(Vector3(-1, 0, 0), fuerte)
		KEY_RIGHT:
			_empujar(Vector3(1, 0, 0), fuerte)
		KEY_UP:
			_empujar(Vector3(0, 0, -1), fuerte)
		KEY_DOWN:
			_empujar(Vector3(0, 0, 1), fuerte)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_BRACKETRIGHT:
			_editar(func(n: Node3D) -> void:
				if not n.has_meta(&"sin_escala"):
					n.scale *= 1.1)
		KEY_MINUS, KEY_KP_SUBTRACT, KEY_SLASH, KEY_BRACKETLEFT:
			_editar(func(n: Node3D) -> void:
				if not n.has_meta(&"sin_escala"):
					n.scale /= 1.1)
		KEY_T:
			_editar(_apoyar)
		KEY_X:
			_editar(func(n: Node3D) -> void:
				if not n.get_meta(&"agregado", false):
					n.position = n.get_meta(&"orig_pos")
					n.rotation.y = n.get_meta(&"orig_rot")
					n.scale = n.get_meta(&"orig_escala")
					n.visible = true)
		KEY_DELETE, KEY_BACKSPACE:
			_editar(func(n: Node3D) -> void: n.visible = false)
			_soltar()
	_estado_texto()


## Gira lo elegido: una pieza sobre sí misma; varias, todas alrededor del centro del grupo.
func _rotar(rad: float) -> void:
	var c := _centro()
	var grupo := _sels.size() > 1
	_editar(func(n: Node3D) -> void:
		n.rotation.y += rad
		if grupo:
			var d := n.position - c
			n.position = c + d.rotated(Vector3.UP, rad))


func _empujar(dir: Vector3, fuerte: bool) -> void:
	var paso := 1.0 if fuerte else (GRILLA if _snap else 0.1)
	_editar(func(n: Node3D) -> void: n.position += dir * paso)


## Baja la pieza hasta lo que haya debajo (vereda, calzada, pasto...).
func _apoyar(n: Node3D) -> void:
	var desde := n.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 40.0)
	var h := n.get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		n.global_position = h["position"]
