class_name DiarioMisiones
extends PantallaMenu
## Diario de misiones (botón MISIONES de la pausa): las misiones en curso con su resumen, cada
## objetivo con su avance (y barra), a quién volver si ya está lista y la recompensa; abajo, las ya
## completadas. Los datos salen del autoload Misiones y de misiones/catalogo_misiones.gd.
## Las filas toman el foco (teclado o mando) para recorrer la lista.


func _init() -> void:
	armar("Misiones")


## Vuelve a armar la lista con el estado actual (llamar antes de abrir).
func refrescar() -> void:
	for c in contenido.get_children():
		c.queue_free()
		contenido.remove_child(c)
	var en_curso := Misiones.en_curso()
	seccion("En curso")
	if en_curso.is_empty():
		var vacio := Label.new()
		vacio.theme_type_variation = &"TextoChico"
		vacio.text = tr("No tenés misiones en curso.\nHablá con quienes tienen un ! sobre la cabeza.")
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD
		vacio.custom_minimum_size = Vector2(420, 0)
		contenido.add_child(vacio)
	for id: String in en_curso:
		_armar_mision(id)
	var hechas := Misiones.completadas()
	if not hechas.is_empty():
		seccion("Completadas")
		for id: String in hechas:
			_armar_completada(id)


func _fila() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"FilaOpcion"
	panel.focus_mode = Control.FOCUS_ALL
	panel.focus_entered.connect(func() -> void: panel.theme_type_variation = &"FilaOpcionFoco")
	panel.focus_exited.connect(func() -> void: panel.theme_type_variation = &"FilaOpcion")
	panel.mouse_entered.connect(func() -> void:
		if not panel.has_focus():
			panel.grab_focus())
	contenido.add_child(panel)
	return panel


func _texto(padre: Control, variacion: StringName, tam: int, contenido_texto: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = variacion
	l.add_theme_font_size_override("font_size", tam)
	l.text = contenido_texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(420, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(l)
	return l


func _armar_mision(id: String) -> void:
	var m := CatalogoMisiones.mision(id)
	var panel := _fila()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	_texto(v, &"Etiqueta", 22, tr(String(m.get("titulo", id))).to_upper())
	_texto(v, &"TextoChico", 14, tr(String(m.get("resumen", ""))))
	for o: Dictionary in Misiones.objetivos(id):
		_armar_objetivo(v, o)
	var lista := Misiones.estado(id) == Misiones.LISTA
	if lista:
		var a_quien := tr(CatalogoDialogos.nombre(String(m.get("entrega", m.get("dador", "")))))
		var l := _texto(v, &"Valor", 15, (tr("Volvé con %s para cobrar la recompensa.") % a_quien))
		l.add_theme_color_override("font_color", Color("ffd84a"))
	var premio: Dictionary = m.get("recompensa", {})
	if premio.has("comida"):
		_texto(v, &"TextoChico", 13, tr("Recompensa: %d de comida") % int(premio["comida"]))


func _armar_objetivo(v: VBoxContainer, o: Dictionary) -> void:
	var hecho := int(o["actual"]) >= int(o["meta"])
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 12)
	v.add_child(caja)
	var nombre := _texto(caja, &"TextoChico", 16, ("✔ " if hecho else "• ") + tr(String(o["texto"])))
	nombre.custom_minimum_size = Vector2(200, 0)
	nombre.modulate = Color(1, 1, 1, 0.6) if hecho else Color.WHITE
	var valor := Label.new()
	valor.theme_type_variation = &"Valor"
	valor.text = "%d / %d" % [o["actual"], o["meta"]]
	valor.custom_minimum_size = Vector2(70, 0)
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja.add_child(valor)
	var barra := Control.new()
	barra.custom_minimum_size = Vector2(90, 8)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(barra)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0.03, 0.06, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(fondo)
	var relleno := ColorRect.new()
	relleno.set_anchors_preset(Control.PRESET_FULL_RECT)
	relleno.anchor_right = clampf(float(o["actual"]) / maxf(float(o["meta"]), 1.0), 0.0, 1.0)
	relleno.color = Color("ffd84a") if hecho else Color("3fb8d6")
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(relleno)


func _armar_completada(id: String) -> void:
	var panel := _fila()
	var l := _texto(panel, &"Etiqueta", 18, "✔ " + tr(String(CatalogoMisiones.mision(id).get("titulo", id))).to_upper())
	l.modulate = Color(1, 1, 1, 0.65)
