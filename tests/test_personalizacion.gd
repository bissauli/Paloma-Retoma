extends Node
## Prueba automática de la personalización de la paloma (headless):
## godot --headless --path . res://tests/test_personalizacion.tscn
## - Aplicar un perfil cambia los colores (material de zonas) y los accesorios (BoneAttachment3D).
## - Guardar y cargar devuelve el mismo perfil.
## - Un perfil vacío deja la paloma como viene del GLB.
## No toca el perfil real de la jugadora: usa un archivo temporal y restaura el perfil en uso.

const ARCHIVO_TEST := "user://test_perfil_paloma.cfg"

var fallas := 0


func _ready() -> void:
	var perfil_previo := PerfilPaloma._actual
	await _vacio_deja_igual()
	await _aplicar_cambia_colores_y_accesorios()
	await _reaplicar_vacio_limpia()
	await _solo_la_jugadora()
	await _pantalla()
	await _pintura()
	await _pantalla_avanzada()
	_guardar_y_cargar()
	_cargar_datos_malos()
	_ciclar_y_aleatorio()
	_luz_base_coincide()
	PerfilPaloma.fijar_actual(perfil_previo)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_TEST))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PerfilPaloma.ruta_pintura(ARCHIVO_TEST)))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _modelo(jugador: bool) -> ModeloPaloma:
	var m := ModeloPaloma.new()
	m.es_jugador = jugador
	add_child(m)
	await get_tree().physics_frame
	return m


func _mallas(m: ModeloPaloma) -> Array[Node]:
	return m._glb.find_children("*", "MeshInstance3D", true, false)


func _adjuntos(m: ModeloPaloma) -> Array[String]:
	var l: Array[String] = []
	for n in m._skel.get_children():
		if n.name.begins_with(AplicadorPaloma.PREFIJO):
			l.append(String(n.name))
	return l


func _perfil_completo() -> PerfilPaloma:
	var p := PerfilPaloma.new()
	p.colores = PackedInt32Array([4, 9, 6, 2, 5, 3])    # canela, azul, coral, grafito, amarillo, marrón
	p.accesorios = PackedInt32Array([1, 2, 3, 1])       # gorra, capa, plumas, bigote
	return p


# ---------------------------------------------------------------- Pruebas

func _vacio_deja_igual() -> void:
	PerfilPaloma.fijar_actual(PerfilPaloma.new())
	var m := await _modelo(true)
	var sin_ids := true
	for mi in _mallas(m):
		if (mi as MeshInstance3D).material_override != null:
			sin_ids = false
	_check("perfil vacío: es_vacio()", PerfilPaloma.actual().es_vacio())
	_check("perfil vacío: ninguna malla tiene material propio", sin_ids)
	_check("perfil vacío: sin accesorios", _adjuntos(m).is_empty())
	_check("perfil vacío: sigue el attachment de la comida", m._skel.get_node_or_null("Pico") != null)
	var piezas := 0
	for n in m._skel.find_children("*", "MeshInstance3D", true, false):
		piezas += 1
	_check("perfil vacío: ninguna malla extra (sólo la del cuerpo)", piezas == 1)
	m.queue_free()


func _aplicar_cambia_colores_y_accesorios() -> void:
	var m := await _modelo(false)
	var p := _perfil_completo()
	m.aplicar_perfil(p)
	var malla := _mallas(m)[0] as MeshInstance3D
	var sm := malla.material_override as ShaderMaterial
	_check("colores: la malla usa el material de zonas", sm != null)
	if sm:
		var activa: PackedFloat32Array = sm.get_shader_parameter("activa")
		var paleta: PackedVector3Array = sm.get_shader_parameter("paleta")
		var todas := true
		for z in range(1, 7):
			if activa[z] != 1.0:
				todas = false
		_check("colores: las 6 zonas quedan activas", todas and activa[0] == 0.0)
		var esperado := CatalogoPaloma.color_paleta(4).srgb_to_linear()   # Cuerpo: canela
		_check("colores: el cuerpo toma el color elegido", paleta[1].is_equal_approx(Vector3(esperado.r, esperado.g, esperado.b)))
		_check("colores: textura y máscara asignadas", sm.get_shader_parameter("albedo_tex") != null and sm.get_shader_parameter("zonas") != null)
	# Colores parciales: las demás zonas conservan el original
	var q := PerfilPaloma.new()
	q.set_color(0, 7)
	m.aplicar_perfil(q)
	var sm2 := (_mallas(m)[0] as MeshInstance3D).material_override as ShaderMaterial
	var act2: PackedFloat32Array = sm2.get_shader_parameter("activa")
	_check("colores parciales: sólo el cuerpo activo", act2[1] == 1.0 and act2[2] == 0.0 and act2[3] == 0.0 and act2[6] == 0.0)

	m.aplicar_perfil(p)
	await get_tree().physics_frame
	var nombres := _adjuntos(m)
	_check("accesorios: hay attachments en cabeza, cuerpo y cola", nombres.has("Acc_head") and nombres.has("Acc_body") and nombres.has("Acc_tail"))
	for par in [["Acc_head", "Slot_cabeza"], ["Acc_head", "Slot_pico"], ["Acc_body", "Slot_espalda"], ["Acc_tail", "Slot_cola"]]:
		var adj := m._skel.get_node_or_null(par[0]) as BoneAttachment3D
		_check("accesorios: %s cuelga de %s" % [par[1], par[0]], adj != null and adj.get_node_or_null(par[1]) != null)
	# La pieza armada en el espacio del GLB tiene que quedar sobre la paloma (no en el origen del mundo)
	var gorra := m._skel.get_node("Acc_head/Slot_cabeza/Pieza") as Node3D
	var origen_glb := m._glb.global_position
	_check("accesorios: la gorra queda sobre la cabeza (%s)" % str(gorra.global_position - origen_glb),
			(gorra.global_position - origen_glb).length() < 0.1)
	var gorra_y := ((gorra.get_child(0) as Node3D).global_position - origen_glb).y
	_check("accesorios: la gorra está arriba de la cabeza (y=%.2f)" % gorra_y, gorra_y > 0.45 and gorra_y < 0.6)
	# No interfieren con las animaciones: la animación sigue moviendo los huesos
	var cab_ini := m._skel.get_bone_pose_rotation(m._skel.find_bone("head"))
	m.animar(0.016, 0, 3.0)
	m.picotear()
	var se_mueve := false
	for i in 20:
		m.animar(0.016, 0, 3.0)
		await get_tree().physics_frame
		m._anim_accion.advance(0.016)
		if not m._skel.get_bone_pose_rotation(m._skel.find_bone("head")).is_equal_approx(cab_ini):
			se_mueve = true
	_check("accesorios: la animación sigue moviendo la cabeza", se_mueve)
	# Con comida en el pico, los accesorios del pico se esconden
	var slot_pico := m._skel.get_node("Acc_head/Slot_pico") as Node3D
	m.mostrar_carga("medialuna")
	_check("pico: con comida se esconden los accesorios del pico", not slot_pico.visible)
	_check("pico: los de la cabeza siguen", (m._skel.get_node("Acc_head/Slot_cabeza") as Node3D).visible)
	m.mostrar_carga("")
	_check("pico: sin comida vuelven", slot_pico.visible)
	m.queue_free()


func _reaplicar_vacio_limpia() -> void:
	var m := await _modelo(false)
	m.aplicar_perfil(_perfil_completo())
	m.aplicar_perfil(PerfilPaloma.new())
	var limpio := true
	for mi in _mallas(m):
		if (mi as MeshInstance3D).material_override != null:
			limpio = false
	_check("reaplicar vacío: vuelve el material original", limpio)
	_check("reaplicar vacío: no quedan accesorios", _adjuntos(m).is_empty())
	m.aplicar_perfil(null)
	_check("perfil null: no rompe", _adjuntos(m).is_empty())
	m.queue_free()


func _solo_la_jugadora() -> void:
	PerfilPaloma.fijar_actual(_perfil_completo())
	var jugadora := await _modelo(true)
	var npc := await _modelo(false)
	_check("jugadora: toma el perfil en uso", (_mallas(jugadora)[0] as MeshInstance3D).material_override is ShaderMaterial and not _adjuntos(jugadora).is_empty())
	_check("NPC: no se personaliza", (_mallas(npc)[0] as MeshInstance3D).material_override == null and _adjuntos(npc).is_empty())
	jugadora.queue_free()
	npc.queue_free()


## La pantalla sólo edita el perfil en uso; la paloma de la vista previa lo sigue sola.
func _pantalla() -> void:
	var perfil := PerfilPaloma.new()
	PerfilPaloma.fijar_actual(perfil)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var menu := PersonalizarMenu.new()
	menu.ruta_guardado = ARCHIVO_TEST
	raiz.add_child(menu)
	var cerradas: Array[int] = [0]
	menu.cerrada.connect(func() -> void: cerradas[0] += 1)
	menu.abrir()
	await get_tree().process_frame
	_check("pantalla: 6 selectores de color y 4 de accesorio", menu._selectores_color.size() == 6 and menu._selectores_slot.size() == 4)
	_check("pantalla: arranca con todo en 'original' y 'ninguno'", menu._selectores_color[0].pos == 0 and menu._selectores_slot[0].pos == 0)

	# Un cambio en el selector edita el perfil, se guarda y se ve en la paloma de la vista previa
	menu._selectores_color[2].elegido.emit(5)       # Cabeza y cuello: 5 = 5º swatch = índice de paleta 4
	_check("pantalla: elegir un color cambia el perfil", perfil.colores[2] == 4)
	menu._selectores_slot[1].elegido.emit(2)        # Espalda: capa
	_check("pantalla: elegir un accesorio cambia el perfil", perfil.accesorios[1] == 2)
	await get_tree().process_frame
	var malla := menu._modelo._glb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_check("pantalla: la paloma de la vista previa cambió de color", malla.material_override is ShaderMaterial)
	_check("pantalla: ...y lleva la capa", menu._modelo._skel.get_node_or_null("Acc_body/Slot_espalda") != null)
	_check("pantalla: se guardó al instante", PerfilPaloma.cargar(ARCHIVO_TEST).es_igual(perfil))

	# Teclado y mando: izquierda/derecha cambian la opción del selector con foco
	var sel := menu._selectores_slot[0]
	sel.grab_focus()
	var tecla := InputEventAction.new()
	tecla.action = "ui_right"
	tecla.pressed = true
	sel._gui_input(tecla)
	_check("pantalla: derecha pasa a la opción siguiente", perfil.accesorios[0] == 1)
	tecla.action = "ui_left"
	sel._gui_input(tecla)
	sel._gui_input(tecla)
	_check("pantalla: izquierda desde 'ninguno' da la vuelta", perfil.accesorios[0] == CatalogoPaloma.cantidad_opciones(0) - 1)

	menu._aleatorio.pressed.emit()
	_check("pantalla: ALEATORIO deja todas las zonas con color", not perfil.colores.has(-1))
	menu._restablecer.pressed.emit()
	_check("pantalla: RESTABLECER vuelve a la paloma de siempre", perfil.es_vacio() and menu._selectores_color[2].pos == 0)
	await get_tree().process_frame
	_check("pantalla: ...también en la vista previa", malla.material_override == null and menu._modelo._skel.get_node_or_null("Acc_body") == null)

	menu.volver.pressed.emit()
	_check("pantalla: VOLVER cierra y avisa", not menu.visible and cerradas[0] == 1)
	raiz.queue_free()


## Pintura libre: de un rayo al texel, pincel, simetría, relleno, perfil y modelo.
func _pintura() -> void:
	# Rayo de frente hacia la cara delantera de la cabeza (el GLB mira a +Z: z = 0,2, y entre 0,3 y 0,5)
	var g := PinturaPaloma.golpe(Vector3(0.05, 0.45, 1.0), Vector3(0, 0, -1))
	_check("pintura: el rayo toca la cabeza", not g.is_empty() and absf(g["punto"].z - 0.2) < 0.001)
	var tex: Vector2i = g["texel"]
	_check("pintura: el texel cae dentro de la textura y de una cara", tex.x >= 0 and tex.x < 128 and PinturaPaloma.cara_de(tex) >= 0)
	_check("pintura: la máscara dice que es la cabeza (zona 3)", int(round(AplicadorPaloma.MASCARA.get_image().get_pixelv(tex).r * 255.0)) == 3)
	_check("pintura: un rayo que no toca nada da {}", PinturaPaloma.golpe(Vector3(2, 2, 2), Vector3(0, 0, -1)).is_empty())
	_check("pintura: el rayo también toca por detrás (la cola)", not PinturaPaloma.golpe(Vector3(0.0, 0.24, -1.0), Vector3(0, 0, 1)).is_empty())

	# Pincel: pinta sólo la cara del centro (no se corre a la vecina del atlas)
	var img := PinturaPaloma.nueva_imagen()
	_check("pintura: la imagen nueva está vacía", img.is_invisible())
	_check("pintura: el pincel cambia texels", PinturaPaloma.pintar(img, tex, 1, Color("e8665a")))
	_check("pintura: pintar de nuevo igual no cambia nada", not PinturaPaloma.pintar(img, tex, 1, Color("e8665a")))
	_check("pintura: el texel quedó del color", img.get_pixelv(tex).is_equal_approx(Color("e8665a")))
	var cara := PinturaPaloma.cara_de(tex)
	PinturaPaloma.pintar(img, tex, 3, Color.BLACK)
	var fuera := 0
	var dentro := 0
	for y in 128:
		for x in 128:
			if img.get_pixel(x, y).a > 0.0:
				if PinturaPaloma.cara_de(Vector2i(x, y)) == cara:
					dentro += 1
				else:
					fuera += 1
	_check("pintura: un pincel de 3 px no se sale de su cara (%d dentro, %d fuera)" % [dentro, fuera], fuera == 0 and dentro >= 4)
	_check("pintura: el borrador borra", PinturaPaloma.borrar(img, tex, 3) and img.is_invisible())
	_check("pintura: el relleno pinta toda la cara", PinturaPaloma.rellenar(img, tex, Color("4a6fd0")) and img.get_pixelv(tex).is_equal_approx(Color("4a6fd0")))
	var llenos := 0
	for y in 128:
		for x in 128:
			if img.get_pixel(x, y).a > 0.0:
				llenos += 1
				if PinturaPaloma.cara_de(Vector2i(x, y)) != cara:
					llenos = -9999
	_check("pintura: ...y sólo esa cara (%d texels)" % llenos, llenos > 4)
	_check("pintura: el cuentagotas devuelve lo pintado, o la textura si no hay pintura",
			PinturaPaloma.muestrear(img, tex).is_equal_approx(Color("4a6fd0")) and PinturaPaloma.muestrear(null, tex).a == 1.0)

	# Perfil: guardar y cargar la pintura, y un perfil sin pintura es vacío
	var p := PerfilPaloma.new()
	_check("perfil: sin pintura es vacío", p.es_vacio() and not p.hay_pintura())
	PinturaPaloma.pintar(p.asegurar_pintura(), tex, 2, Color("9a72d0"))
	_check("perfil: con pintura ya no es vacío", not p.es_vacio() and p.hay_pintura())
	_check("perfil: guardar con pintura", p.guardar(ARCHIVO_TEST) == OK)
	var q := PerfilPaloma.cargar(ARCHIVO_TEST)
	_check("perfil: cargar devuelve la misma pintura", q.es_igual(p) and q.hay_pintura())
	var otro := PerfilPaloma.new()
	_check("perfil: distinto de uno sin pintura", not q.es_igual(otro))
	otro.copiar_de(q)
	_check("perfil: copiar_de copia la pintura (y no la comparte)", otro.es_igual(q) and otro.pintura != q.pintura)
	otro.restablecer()
	_check("perfil: restablecer borra la pintura", otro.es_vacio())
	p.fin_pincelada()
	p.pintura.fill(Color(0, 0, 0, 0))
	p.fin_pincelada()
	_check("perfil: sin nada pintado se descarta la imagen", p.pintura == null)
	p.guardar(ARCHIVO_TEST)
	_check("perfil: guardar sin pintura borra el PNG viejo", not FileAccess.file_exists(PerfilPaloma.ruta_pintura(ARCHIVO_TEST)))

	# Modelo: la pintura se ve en el material y se actualiza al pintar
	var perfil := PerfilPaloma.new()
	PerfilPaloma.fijar_actual(perfil)
	var m := await _modelo(true)
	var malla := _mallas(m)[0] as MeshInstance3D
	_check("modelo: sin pintura ni colores no hay material propio", malla.material_override == null)
	PinturaPaloma.pintar(perfil.asegurar_pintura(), tex, 2, Color("e8665a"))
	perfil.pintura_modificada()
	var sm := malla.material_override as ShaderMaterial
	_check("modelo: la primera pincelada arma el material", sm != null)
	if sm:
		var textura := sm.get_shader_parameter("pintura") as ImageTexture
		_check("modelo: lleva la pintura (no la textura vacía)", textura != null and textura.get_size() == Vector2(128, 128))
		PinturaPaloma.pintar(perfil.pintura, tex + Vector2i(1, 0), 1, Color.BLACK)
		perfil.pintura_modificada()
		_check("modelo: el material se actualiza en el lugar", malla.material_override == sm and sm.get_shader_parameter("pintura") == textura)
		var leida := textura.get_image().get_pixelv(tex)
		_check("modelo: la textura tiene el texel pintado", leida.is_equal_approx(Color("e8665a")))
	# Quieta para pintar: sin animación, sin accesorios
	perfil.set_accesorio(0, 1)
	m.congelar(true)
	var acc := m._skel.get_node_or_null("Acc_head") as Node3D
	_check("modelo: congelada, los accesorios se esconden", acc != null and not acc.visible)
	var cab := m._skel.get_bone_pose_rotation(m._skel.find_bone("head"))
	await _cuadros(10)
	_check("modelo: congelada, la cabeza no se mueve y está en reposo",
			m._skel.get_bone_pose_rotation(m._skel.find_bone("head")).is_equal_approx(cab)
			and cab.is_equal_approx(m._skel.get_bone_rest(m._skel.find_bone("head")).basis.get_rotation_quaternion()))
	perfil.set_accesorio(0, 2)
	_check("modelo: congelada, un accesorio nuevo también queda escondido", not (m._skel.get_node("Acc_head") as Node3D).visible)
	m.congelar(false)
	_check("modelo: descongelada, vuelven los accesorios", (m._skel.get_node("Acc_head") as Node3D).visible)
	perfil.restablecer()
	_check("modelo: restablecer deja la paloma de siempre", malla.material_override == null and _adjuntos(m).is_empty())
	m.queue_free()


## El modo avanzado de la pantalla: pinta con la vista, deshace, rehace y borra.
func _pantalla_avanzada() -> void:
	var perfil := PerfilPaloma.new()
	PerfilPaloma.fijar_actual(perfil)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var menu := PersonalizarMenu.new()
	menu.ruta_guardado = ARCHIVO_TEST
	raiz.add_child(menu)
	menu.abrir()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("avanzado: la primera vez ya se ve el nombre del modo", menu._sel_modo._texto.text == "BÁSICO")
	_check("avanzado: arranca en básico", not menu._avanzado and menu._panel_basico.visible and not menu._panel_avanzado.visible)
	menu._sel_modo.elegido.emit(1)
	await get_tree().process_frame
	_check("avanzado: el modo cambia de panel", menu._avanzado and not menu._panel_basico.visible and menu._panel_avanzado.visible)
	_check("avanzado: la paloma queda congelada", menu._modelo._congelada)

	# Un rayo desde la cámara hacia el centro de la paloma (el pecho) toca el modelo
	menu._ver_desde(0.0, 0.0)
	menu._tween_vista.custom_step(1.0)
	await get_tree().process_frame
	var centro := menu._contenedor.size * 0.5
	var golpes := menu._golpes_en(centro)
	_check("avanzado: el rayo de la vista toca la paloma (%d golpes)" % golpes.size(), golpes.size() >= 1)
	menu._simetria = false
	_check("avanzado: sin simetría, un solo golpe", menu._golpes_en(centro + Vector2(30, 0)).size() <= 1)
	menu._simetria = true

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = centro
	menu._entrada_vista(click)
	click = click.duplicate()
	click.pressed = false
	menu._entrada_vista(click)
	_check("avanzado: un toque pinta", perfil.hay_pintura())
	_check("avanzado: se guardó al soltar", PerfilPaloma.cargar(ARCHIVO_TEST).es_igual(perfil))
	_check("avanzado: se puede deshacer", not menu._btn_deshacer.disabled)
	menu._deshacer_paso()
	_check("avanzado: deshacer saca la pincelada", not perfil.hay_pintura() and not menu._btn_rehacer.disabled)
	menu._rehacer_paso()
	_check("avanzado: rehacer la vuelve a poner", perfil.hay_pintura())

	# Arrastrar: varias pinceladas seguidas son un solo paso de deshacer
	var antes := menu._deshacer.size()
	var arrastre := InputEventMouseButton.new()
	arrastre.button_index = MOUSE_BUTTON_LEFT
	arrastre.pressed = true
	arrastre.position = centro + Vector2(-40, 0)
	menu._entrada_vista(arrastre)
	menu._trazar_hasta(centro + Vector2(40, 10))
	arrastre = arrastre.duplicate()
	arrastre.pressed = false
	menu._entrada_vista(arrastre)
	_check("avanzado: un arrastre es un solo paso de deshacer", menu._deshacer.size() == antes + 1)

	menu._herramienta = PersonalizarMenu.Herramienta.BORRADOR
	menu._tam_pincel = 3
	var pasos := menu._deshacer.size()
	menu._empezar_trazo(centro)
	menu._terminar_trazo()
	menu._herramienta = PersonalizarMenu.Herramienta.PINCEL
	menu._tam_pincel = 1
	_check("avanzado: el borrador deja un paso de deshacer", menu._deshacer.size() == pasos + 1 or menu._deshacer.size() == pasos)

	# Cuentagotas: toma el color pintado y no agrega pasos de deshacer
	perfil.restablecer()
	menu._deshacer.clear()
	menu._color = Color("e8665a")
	menu._empezar_trazo(centro)
	menu._terminar_trazo()
	menu._herramienta = PersonalizarMenu.Herramienta.CUENTAGOTAS
	menu._poner_color(Color.WHITE)
	var pasos2 := menu._deshacer.size()
	menu._empezar_trazo(centro)
	_check("avanzado: el cuentagotas toma el color pintado", menu._color.is_equal_approx(Color("e8665a")) and menu._deshacer.size() == pasos2)
	menu._herramienta = PersonalizarMenu.Herramienta.RELLENO
	menu._poner_color(Color("4a6fd0"))
	menu._empezar_trazo(centro)
	_check("avanzado: el relleno termina solo (un toque)", not menu._trazando and menu._deshacer.size() == pasos2 + 1)
	menu._herramienta = PersonalizarMenu.Herramienta.PINCEL

	menu._borrar_todo()
	_check("avanzado: borrar todo deja sin pintura", not perfil.hay_pintura() and menu._btn_borrar.disabled)
	menu._deshacer_paso()
	_check("avanzado: ...y se puede deshacer", perfil.hay_pintura())

	# Volver al básico: vuelve a moverse y a mostrar los accesorios
	menu._sel_modo.elegido.emit(0)
	_check("avanzado: volver al básico descongela la paloma", not menu._avanzado and not menu._modelo._congelada)
	menu._sel_modo.elegido.emit(1)
	menu.volver.pressed.emit()
	_check("avanzado: cerrar vuelve a básico", not menu._avanzado and not menu.visible)
	raiz.queue_free()


func _guardar_y_cargar() -> void:
	var p := _perfil_completo()
	_check("guardar: sin error", p.guardar(ARCHIVO_TEST) == OK)
	var q := PerfilPaloma.cargar(ARCHIVO_TEST)
	_check("cargar: devuelve el mismo perfil", q.es_igual(p))
	_check("cargar: colores iguales", q.colores == p.colores)
	_check("cargar: accesorios iguales", q.accesorios == p.accesorios)
	var vacio := PerfilPaloma.new()
	vacio.guardar(ARCHIVO_TEST)
	_check("guardar y cargar un perfil vacío", PerfilPaloma.cargar(ARCHIVO_TEST).es_vacio())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_TEST))
	_check("cargar sin archivo: perfil vacío", PerfilPaloma.cargar(ARCHIVO_TEST).es_vacio())


func _cargar_datos_malos() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("paloma", "colores", [99, -5, "x", 3])
	cfg.set_value("paloma", "accesorios", [9, 2, -1, 1, 7, 7])
	cfg.save(ARCHIVO_TEST)
	var p := PerfilPaloma.cargar(ARCHIVO_TEST)
	_check("datos malos: colores fuera de rango se descartan", p.colores[0] == -1 and p.colores[1] == -1 and p.colores[2] == -1 and p.colores[3] == 3)
	_check("datos malos: accesorios fuera de rango se descartan", p.accesorios[0] == 0 and p.accesorios[1] == 2 and p.accesorios[2] == 0 and p.accesorios[3] == 1)
	_check("datos malos: el tamaño no cambia", p.colores.size() == CatalogoPaloma.ZONAS.size() and p.accesorios.size() == CatalogoPaloma.SLOTS.size())


func _ciclar_y_aleatorio() -> void:
	var p := PerfilPaloma.new()
	p.ciclar_color(0, 1)
	_check("ciclar: de original pasa al primer color", p.colores[0] == 0)
	p.ciclar_color(0, -1)
	p.ciclar_color(0, -1)
	_check("ciclar: hacia atrás desde el original da la vuelta al último", p.colores[0] == CatalogoPaloma.PALETA.size() - 1)
	p.ciclar_accesorio(0, -1)
	_check("ciclar accesorio: da la vuelta", p.accesorios[0] == CatalogoPaloma.cantidad_opciones(0) - 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n_cambios: Array[int] = [0]
	p.cambiado.connect(func() -> void: n_cambios[0] += 1)
	p.aleatorio(rng)
	_check("aleatorio: emite cambiado y no deja zonas sin color", n_cambios[0] == 1 and not p.colores.has(-1))
	var ok_rango := true
	for i in p.accesorios.size():
		if p.accesorios[i] < 0 or p.accesorios[i] >= CatalogoPaloma.cantidad_opciones(i):
			ok_rango = false
	_check("aleatorio: accesorios en rango", ok_rango)
	p.restablecer()
	_check("restablecer: vuelve a vacío", p.es_vacio())


## LUZ_BASE tiene que seguir siendo la luminancia media de cada zona de la textura actual.
func _luz_base_coincide() -> void:
	var glb := (ModeloPaloma.VARIANTES["Original"] as PackedScene).instantiate()
	var mi := glb.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tex := ((mi.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture as Texture2D).get_image()
	tex.decompress()
	var masc := AplicadorPaloma.MASCARA.get_image()
	masc.decompress()
	var suma := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	var n := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
	for y in tex.get_height():
		for x in tex.get_width():
			var z := clampi(int(round(masc.get_pixel(x, y).r * 255.0)), 0, 6)
			var c := tex.get_pixel(x, y).srgb_to_linear()
			suma[z] += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			n[z] += 1.0
	var ok := true
	for z in range(1, 7):
		var media := suma[z] / maxf(n[z], 1.0)
		if absf(media - float(AplicadorPaloma.LUZ_BASE[z])) > 0.002:
			ok = false
			print("  zona %d: calculada %.4f, constante %.4f" % [z, media, AplicadorPaloma.LUZ_BASE[z]])
	_check("LUZ_BASE coincide con la textura y la máscara", ok)
	glb.free()


func _cuadros(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
