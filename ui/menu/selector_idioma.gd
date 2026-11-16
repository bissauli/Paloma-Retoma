class_name SelectorIdioma
extends HBoxContainer
## Banderas para cambiar entre español e inglés (abajo a la izquierda del menú principal).
## La bandera del idioma actual queda con borde blanco y las otras atenuadas. Cada bandera es un
## botón con su nombre de idioma como tooltip. La elección la guarda Ajustes (set_idioma).

const TAM_BANDERA := Vector2(66, 46)
const C_BORDE := Color(1, 1, 1, 0.95)

var _botones := {}


func _ready() -> void:
	name = "SelectorIdioma"
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for codigo in Idioma.CODIGOS:
		var b := Button.new()
		b.name = codigo
		b.icon = Idioma.BANDERAS[codigo]
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = TAM_BANDERA
		b.tooltip_text = Idioma.NOMBRES[codigo]
		b.pressed.connect(_elegir.bind(codigo))
		for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(estado, _estilo(estado == "hover" or estado == "focus"))
		add_child(b)
		_botones[codigo] = b
	Ajustes.idioma_cambiado.connect(_actualizar)
	_actualizar()


## Prende o apaga los clics (mientras el menú se va para empezar la partida).
func set_activo(si: bool) -> void:
	for b: Button in _botones.values():
		b.mouse_filter = Control.MOUSE_FILTER_STOP if si else Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_ALL if si else Control.FOCUS_NONE


func _elegir(codigo: String) -> void:
	if codigo == Ajustes.idioma:
		return
	AudioManager.ui("button", -8.0)
	Ajustes.set_idioma(codigo)


func _actualizar() -> void:
	for codigo: String in _botones:
		var b: Button = _botones[codigo]
		var actual: bool = codigo == Ajustes.idioma
		b.modulate = Color.WHITE if actual else Color(1, 1, 1, 0.5)
		b.add_theme_stylebox_override("normal", _estilo(actual))


## Marco redondeado: borde blanco si es la bandera elegida (o tiene el mouse o el foco encima).
func _estilo(con_borde: bool) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color(0, 0, 0, 0)
	e.set_corner_radius_all(6)
	e.set_border_width_all(3 if con_borde else 0)
	e.border_color = C_BORDE
	e.set_content_margin_all(4.0)
	e.anti_aliasing = true
	return e
