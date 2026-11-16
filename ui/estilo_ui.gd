class_name EstiloUI
extends RefCounted
## Colores y cajas del estilo del menú principal (barras cyan translúcidas cortadas en diagonal).
## Los usan el HUD, la brújula y la pantalla de victoria para verse como una sola interfaz.

const TEMA := preload("res://ui/tema/tema_paloma.tres")
const C_CYAN := Color(0.247, 0.722, 0.839, 0.55)
const C_CYAN_BORDE := Color(0.07, 0.65, 0.83, 0.92)
const C_OSCURO := Color(0.0, 0.03, 0.06, 0.38)
const C_SOMBRA := Color(0.0, 0.03, 0.06, 0.38)


## Caja inclinada como las barras del menú. "inclinacion" positiva corta como los botones del
## menú (columna derecha); negativa, como VOLVER (columna izquierda). "borde" pinta una raya de
## 3 px del lado que da al borde de la pantalla.
static func caja(color: Color, inclinacion: float, borde := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.skew = Vector2(inclinacion, 0)
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.content_margin_left = 26 if inclinacion < 0.0 else 34
	s.content_margin_right = 34 if inclinacion < 0.0 else 26
	if borde.a > 0.0:
		if inclinacion < 0.0:
			s.border_width_right = 3
		else:
			s.border_width_left = 3
		s.border_color = borde
	s.shadow_color = C_SOMBRA
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


## Estilo de botón de acción: caja redondeada y translúcida del color de "acento", con borde claro,
## sombra y el foco como un aro blanco. Para botones sueltos o en fila (las barras inclinadas del
## menú están hechas para ir solas y se pisan entre sí).
static func estilizar_boton(b: Button, acento := Color(0.247, 0.722, 0.839)) -> void:
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
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


static func _caja_boton(color: Color, alfa: float, borde: float) -> StyleBoxFlat:
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


## Etiqueta con una variación del tema (&"TituloPantalla", &"Seccion", &"Etiqueta"...).
static func texto(padre: Node, variacion: StringName, tam: int, contenido := "") -> Label:
	var l := Label.new()
	l.theme_type_variation = variacion
	l.add_theme_font_size_override("font_size", tam)
	l.text = contenido
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padre.add_child(l)
	return l
