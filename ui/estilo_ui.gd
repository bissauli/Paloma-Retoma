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
