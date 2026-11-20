extends Node
## BUILDER DE MAPA (escena de administrador): se abre sólo desde acá (res://admin/builder_mapa.tscn,
## F6 en el editor de Godot). El juego normal no lo carga ni lo puede activar: esta carpeta además
## queda afuera de la exportación.
## Arma la plaza como siempre pero en "modo admin" (MapaOverrides.modo_admin): las piezas de piso
## (faroles, árboles, bancos, fuentes, arbustos, contenedores...) quedan sueltas para tocarlas con
## una cámara libre. Cada cambio se guarda solo en res://mapa/overrides.json y el juego lo aplica
## encima de lo que genera el código (nada del mapa original se pierde: "X" restaura una pieza).

const TEXTO_AYUDA := "[center][b][font_size=22]BUILDER DE MAPA[/font_size][/b]\n[color=#9ad]modo administrador[/color][/center]\n\n" \
	+ "[b]CÁMARA[/b]\n" \
	+ "  • Mantené [b]clic derecho[/b] y mové el mouse para mirar\n" \
	+ "  • [b]W A S D[/b] moverte · [b]Espacio[/b] subir · [b]C[/b] bajar · [b]Shift[/b] más rápido\n" \
	+ "  • [b]Rueda del mouse[/b]: cambia la velocidad de la cámara\n\n" \
	+ "[b]PIEZAS[/b]\n" \
	+ "  • [b]Clic izquierdo[/b] sobre una pieza para elegirla; [b]arrastrala[/b] para moverla por el piso\n" \
	+ "  • [b]Q / E[/b] girar (con Shift, 90°) · [b]R / F[/b] subir / bajar · [b]+ / −[/b] agrandar / achicar\n" \
	+ "  • [b]T[/b] apoyar en el piso · [b]Supr[/b] borrar · [b]Ctrl+D[/b] duplicar\n" \
	+ "  • [b]X[/b] volver a su lugar original · [b]Ctrl+Z[/b] deshacer · [b]Esc[/b] soltar la pieza\n\n" \
	+ "[b]OTROS[/b]\n" \
	+ "  • [b]Tab[/b] paleta para agregar piezas nuevas (doble clic en la lista)\n" \
	+ "  • [b]G[/b] grilla de 0,5 m · [b]H[/b] mostrar / ocultar esta ayuda\n" \
	+ "  • Se guarda solo después de cada cambio ([b]Ctrl+S[/b] guarda ya mismo)\n\n" \
	+ "[color=#9ad]Se pueden mover: faroles, árboles, bancos, fuentes, arbustos, contenedores, macetas, juegos...[/color]"

const PASO_ROTACION := 15.0
const PASO_ALTURA := 0.1
const GRILLA := 0.5

var plaza: Node3D
var camara: Camera3D
var _yaw := 0.0
var _pitch := -0.55
var _vel := 25.0
var _mirando := false

var _sel: Node3D
var _arrastre := false
var _desfase := Vector3.ZERO
var _plano_y := 0.0
var _previo := {}
var _snap := false
var _deshacer: Array = []
var _guardado := ""

var _resaltado: MeshInstance3D
var _ui_estado: Label
var _ui_ayuda: PanelContainer
var _ui_paleta: PanelContainer
var _lista: ItemList
var _paleta: Array = []        ## [tipo, pieza] por fila de la lista
var _timer: Timer


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
	_orientar()
	camara.make_current()

	_resaltado = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	_resaltado.mesh = caja
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.65, 0.1, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	_resaltado.material_override = m
	_resaltado.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_resaltado.visible = false
	add_child(_resaltado)

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

	# Paleta (a la derecha, Tab)
	_ui_paleta = PanelContainer.new()
	_ui_paleta.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_ui_paleta.offset_left = -250
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
	titulo.custom_minimum_size = Vector2(220, 0)
	caja.add_child(titulo)
	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.focus_mode = Control.FOCUS_NONE
	_lista.item_activated.connect(_agregar_de_paleta)
	caja.add_child(_lista)
	_llenar_paleta()

	# Ayuda del principio (centrada)
	_ui_ayuda = PanelContainer.new()
	_ui_ayuda.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_ui_ayuda.custom_minimum_size = Vector2(640, 0)
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
	texto.custom_minimum_size = Vector2(600, 0)
	texto.add_theme_font_size_override("normal_font_size", 16)
	texto.add_theme_font_size_override("bold_font_size", 16)
	texto.text = TEXTO_AYUDA
	v.add_child(texto)
	var boton := Button.new()
	boton.text = "Entendido  (Enter)"
	boton.focus_mode = Control.FOCUS_NONE
	boton.pressed.connect(func() -> void: _ui_ayuda.visible = false)
	v.add_child(boton)


func _estilo(color: Color, margen := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(margen)
	s.set_corner_radius_all(8)
	return s


func _llenar_paleta() -> void:
	var kit: Array[String] = []
	for nombre: String in KitDatos.PIEZAS:
		if KitDatos.PIEZAS[nombre]["carpeta"] == "piezas" and MapaOverrides.es_editable(nombre):
			kit.append(nombre)
	kit.sort()
	_paleta = [["banco", "banco"], ["farol", "farol"], ["jacaranda", "jacaranda"]]
	_lista.add_item("Banco de plaza")
	_lista.add_item("Farol de plaza")
	_lista.add_item("Jacarandá de plaza")
	for n in kit:
		_paleta.append(["kit", n])
		_lista.add_item(n.replace("_", " "))


func _estado_texto() -> void:
	var t := ""
	if _sel:
		var g := rad_to_deg(_sel.rotation.y)
		t = "%s   ·   pos (%.1f, %.1f, %.1f)   ·   giro %d°   ·   escala %.2f\n" % [
			String(_sel.get_meta(&"nombre_pieza")), _sel.position.x, _sel.position.y, _sel.position.z,
			roundi(g), _sel.scale.x]
	else:
		t = "Clic izquierdo sobre una pieza para elegirla   ·   H: ayuda   ·   Tab: paleta\n"
	t += "Grilla %s (G)   ·   Cámara %d m/s (rueda)   ·   %s" % ["SÍ" if _snap else "no", roundi(_vel),
		_guardado if _guardado != "" else "Sin cambios guardados todavía"]
	_ui_estado.text = t


# ---------------------------------------------------------------- Cámara

func _orientar() -> void:
	camara.rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not Input.is_key_pressed(KEY_CTRL):
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
	if _sel and is_instance_valid(_sel):
		var a := _aabb_de(_sel)
		_resaltado.visible = _sel.visible
		_resaltado.global_transform = _sel.global_transform * Transform3D(Basis.from_scale(a.size.max(Vector3.ONE * 0.2)), a.get_center())


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


func _elegir(pantalla: Vector2) -> Node3D:
	var o := camara.project_ray_origin(pantalla)
	var d := camara.project_ray_normal(pantalla)
	var mejor: Node3D = null
	var mejor_t := INF
	for x in get_tree().get_nodes_in_group(MapaOverrides.GRUPO):
		var n := x as Node3D
		if n == null or not n.visible:
			continue
		var inv := n.global_transform.affine_inverse()
		var hit: Variant = _aabb_de(n).intersects_ray(inv * o, inv.basis * d)
		if hit != null:
			var t := o.distance_to(n.global_transform * (hit as Vector3))
			if t < mejor_t:
				mejor_t = t
				mejor = n
	return mejor


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


func _confirmar(n: Node3D, antes: Dictionary) -> void:
	var despues := _estado(n)
	if despues == antes:
		return
	_deshacer.append({"nodo": n, "antes": antes})
	if _deshacer.size() > 200:
		_deshacer.pop_front()
	MapaOverrides.anotar(n)
	_timer.start()
	_guardado = "Guardando..."
	_estado_texto()


func _editar(cambio: Callable) -> void:
	if _sel == null:
		return
	var antes := _estado(_sel)
	cambio.call(_sel)
	_confirmar(_sel, antes)


func _guardar() -> void:
	_guardado = ("Guardado ✓  %s" % Time.get_time_string_from_system()) if MapaOverrides.guardar() \
		else "⚠ NO se pudo guardar (el builder tiene que correr desde el editor de Godot)"
	_estado_texto()


func _soltar() -> void:
	_sel = null
	_arrastre = false
	_resaltado.visible = false
	_estado_texto()


func _deshacer_ultimo() -> void:
	if _deshacer.is_empty():
		return
	var u: Dictionary = _deshacer.pop_back()
	var n: Node3D = u["nodo"]
	if not is_instance_valid(n):
		return
	_aplicar(n, u["antes"])
	MapaOverrides.anotar(n)
	_timer.start()
	_sel = n if n.visible else null
	if _sel == null:
		_resaltado.visible = false
	_estado_texto()


func _duplicar() -> void:
	if _sel == null:
		return
	var tipo: String = _sel.get_meta(&"tipo_pieza")
	if tipo == "fuente":
		_guardado = "Las fuentes no se duplican (sólo se mueven o se giran)"
		_estado_texto()
		return
	var escala := _sel.scale
	if tipo == "jacaranda":
		escala *= float(_sel.get_meta(&"param_escala", 1.0))
	var e := MapaOverrides.agregar(tipo, String(_sel.get_meta(&"nombre_pieza")),
		_sel.position + _sel.global_transform.basis.x.normalized() * 2.0, _sel.rotation.y, escala)
	_armar_agregada(e)


func _agregar_de_paleta(i: int) -> void:
	var p: Array = _paleta[i]
	var centro := get_viewport().get_visible_rect().size / 2.0
	var pos := _suelo_en(centro)
	var e := MapaOverrides.agregar(String(p[0]), String(p[1]), pos, camara.rotation.y, Vector3.ONE)
	_armar_agregada(e)


func _armar_agregada(e: Dictionary) -> void:
	var ciudad := plaza.get_node_or_null("Ciudad")
	if ciudad == null:
		return
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
			_sel = x as Node3D
			_deshacer.append({"nodo": _sel, "antes": {"pos": pos, "rot": rot, "escala": escala, "visible": false}})
			break
	_timer.start()
	_guardado = "Guardando..."
	_estado_texto()


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
					_sel = _elegir(mb.position)
					_arrastre = false
					if _sel:
						var o := camara.project_ray_origin(mb.position)
						var d := camara.project_ray_normal(mb.position)
						_plano_y = _sel.global_position.y
						var p: Variant = Plane(Vector3.UP, _plano_y).intersects_ray(o, d)
						if p != null:
							_desfase = (p as Vector3) - _sel.global_position
							_previo = _estado(_sel)
							_arrastre = true
					else:
						_resaltado.visible = false
					_estado_texto()
				elif _arrastre:
					_arrastre = false
					_confirmar(_sel, _previo)
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
		elif _arrastre and _sel:
			var o := camara.project_ray_origin(mm.position)
			var d := camara.project_ray_normal(mm.position)
			var p: Variant = Plane(Vector3.UP, _plano_y).intersects_ray(o, d)
			if p != null:
				var nueva: Vector3 = (p as Vector3) - _desfase
				if _snap:
					nueva.x = snappedf(nueva.x, GRILLA)
					nueva.z = snappedf(nueva.z, GRILLA)
				_sel.global_position = nueva
				_estado_texto()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_tecla(event as InputEventKey)


func _tecla(k: InputEventKey) -> void:
	var fuerte := k.shift_pressed
	if k.ctrl_pressed:
		match k.keycode:
			KEY_Z: _deshacer_ultimo()
			KEY_D: _duplicar()
			KEY_S: _guardar()
		return
	match k.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_ui_ayuda.visible = false
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
		KEY_Q:
			_editar(func(n: Node3D) -> void: n.rotation.y += deg_to_rad(90.0 if fuerte else PASO_ROTACION))
		KEY_E:
			_editar(func(n: Node3D) -> void: n.rotation.y -= deg_to_rad(90.0 if fuerte else PASO_ROTACION))
		KEY_R:
			_editar(func(n: Node3D) -> void: n.position.y += 1.0 if fuerte else PASO_ALTURA)
		KEY_F:
			_editar(func(n: Node3D) -> void: n.position.y -= 1.0 if fuerte else PASO_ALTURA)
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


## Baja la pieza hasta lo que haya debajo (vereda, calzada, pasto...).
func _apoyar(n: Node3D) -> void:
	var desde := n.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 40.0)
	var h := n.get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		n.global_position = h["position"]
