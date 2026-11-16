class_name LogrosMenu
extends PantallaMenu
## Pantalla LOGROS (se abre con el botón del trofeo, arriba a la izquierda del menú principal):
## un resumen y dos listas, TROFEOS (hazañas, con nivel) y LOGROS (cosas que se consiguen al jugar).
## Cada fila muestra su icono (de color si ya está, gris si falta), el nombre, qué hay que hacer y,
## si lleva cuenta, el avance. Las filas toman el foco (teclado o mando) para recorrer la lista.

const LADO_ICONO := 46.0

var _resumen: Label
var _filas := {}      ## id -> {panel, icono, nombre, valor, barra, relleno}


func _init() -> void:
	armar("Logros")
	_resumen = Label.new()
	_resumen.theme_type_variation = &"TextoChico"
	_resumen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(_resumen)
	seccion("Trofeos")
	for d: Dictionary in CatalogoLogros.de_tipo(CatalogoLogros.TROFEO):
		_armar_fila(d)
	seccion("Logros")
	for d: Dictionary in CatalogoLogros.de_tipo(CatalogoLogros.LOGRO):
		_armar_fila(d)


func abrir() -> void:
	_refrescar()
	super.abrir()
	# Al abrir se ve la lista desde arriba (con el resumen), no recortada por el foco
	(func() -> void:
		for s in find_children("*", "ScrollContainer", true, false):
			(s as ScrollContainer).scroll_vertical = 0).call_deferred()


func _armar_fila(d: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"FilaOpcion"
	panel.focus_mode = Control.FOCUS_ALL
	panel.custom_minimum_size = Vector2(0, 66)
	panel.focus_entered.connect(func() -> void: panel.theme_type_variation = &"FilaOpcionFoco")
	panel.focus_exited.connect(func() -> void: panel.theme_type_variation = &"FilaOpcion")
	panel.mouse_entered.connect(func() -> void:
		if not panel.has_focus():
			panel.grab_focus())
	contenido.add_child(panel)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	panel.add_child(caja)

	var icono := IconoTrofeo.new()
	icono.forma = IconoTrofeo.Forma.TROFEO if d["tipo"] == CatalogoLogros.TROFEO else IconoTrofeo.Forma.MEDALLA
	icono.custom_minimum_size = Vector2(LADO_ICONO, LADO_ICONO)
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(icono)

	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", 0)
	caja.add_child(textos)
	var nombre := Label.new()
	nombre.theme_type_variation = &"Etiqueta"
	nombre.text = String(d["nombre"]).to_upper()
	textos.add_child(nombre)
	var desc := Label.new()
	desc.theme_type_variation = &"TextoChico"
	desc.add_theme_font_size_override("font_size", 14)
	desc.text = d["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(300, 0)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_child(desc)

	var derecha := VBoxContainer.new()
	derecha.custom_minimum_size = Vector2(112, 0)
	derecha.alignment = BoxContainer.ALIGNMENT_CENTER
	derecha.add_theme_constant_override("separation", 4)
	caja.add_child(derecha)
	var valor := Label.new()
	valor.theme_type_variation = &"Valor"
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	derecha.add_child(valor)
	var barra := Control.new()
	barra.custom_minimum_size = Vector2(112, 8)
	derecha.add_child(barra)
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0.03, 0.06, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(fondo)
	var relleno := ColorRect.new()
	relleno.set_anchors_preset(Control.PRESET_FULL_RECT)
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(relleno)
	_filas[d["id"]] = {"panel": panel, "icono": icono, "nombre": nombre, "valor": valor, "barra": barra, "relleno": relleno}


func _refrescar() -> void:
	_resumen.text = tr("Trofeos %d/%d  ·  Logros %d/%d") % [Logros.cantidad(CatalogoLogros.TROFEO),
		Logros.total(CatalogoLogros.TROFEO), Logros.cantidad(CatalogoLogros.LOGRO), Logros.total(CatalogoLogros.LOGRO)]
	for id: String in _filas:
		var d := CatalogoLogros.por_id(id)
		var f: Dictionary = _filas[id]
		var hecho := Logros.hecho(id)
		var icono := f["icono"] as IconoTrofeo
		icono.bloqueado = not hecho
		icono.color = CatalogoLogros.color_de(d)
		(f["nombre"] as Label).modulate = Color.WHITE if hecho else Color(1, 1, 1, 0.7)
		var valor := f["valor"] as Label
		var barra := f["barra"] as Control
		var relleno := f["relleno"] as ColorRect
		var pr := Logros.progreso(id)
		var con_barra: bool = d.has("stat") and d.get("barra", true) and not hecho
		barra.visible = con_barra
		if hecho:
			valor.text = "OBTENIDO"
			valor.add_theme_color_override("font_color", CatalogoLogros.color_de(d))
		elif d.has("stat"):
			var unidad: String = d.get("unidad", "")
			valor.text = "%d / %d%s" % [pr["actual"], pr["meta"], (" " + unidad) if unidad != "" else ""]
			valor.remove_theme_color_override("font_color")
		else:
			valor.text = "PENDIENTE"
			valor.remove_theme_color_override("font_color")
		if con_barra:
			relleno.anchor_right = clampf(float(pr["actual"]) / maxf(float(pr["meta"]), 1.0), 0.0, 1.0)
			relleno.color = CatalogoLogros.color_de(d)
