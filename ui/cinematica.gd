class_name BarrasCinematica
extends CanvasLayer
## Franjas negras de cine (arriba y abajo) con subtítulos para las cinemáticas del tutorial,
## y abajo a la derecha cómo saltearlas. Va encima del HUD y debajo de la pausa.

const ALTO := 0.11              ## Alto de cada franja (fracción de la pantalla)
const C_TEXTO := Color("fffaf0")
const C_BORDE := Color(0.12, 0.1, 0.18, 0.9)

var _arriba: ColorRect
var _abajo: ColorRect
var _texto: Label
var _saltear: Label
var _tween: Tween


func _ready() -> void:
	layer = 8
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_arriba = _franja(raiz)
	_arriba.anchor_top = 0.0
	_arriba.anchor_bottom = 0.0
	_abajo = _franja(raiz)
	_abajo.anchor_top = 1.0
	_abajo.anchor_bottom = 1.0

	_texto = Label.new()
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 30)
	_texto.add_theme_color_override("font_color", C_TEXTO)
	_texto.add_theme_color_override("font_outline_color", C_BORDE)
	_texto.add_theme_constant_override("outline_size", 9)
	_texto.anchor_left = 0.08
	_texto.anchor_right = 0.92
	_texto.anchor_top = 0.66
	_texto.anchor_bottom = 1.0 - ALTO - 0.01
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_texto)

	_saltear = Label.new()
	_saltear.text = "Tocá la pantalla para saltear" if Ajustes.movil else "Espacio o click: saltear"
	_saltear.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saltear.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_saltear.add_theme_font_size_override("font_size", 16)
	_saltear.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_saltear.anchor_left = 0.5
	_saltear.anchor_right = 0.97
	_saltear.anchor_top = 1.0 - ALTO
	_saltear.anchor_bottom = 1.0
	_saltear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_saltear)
	visible = false


func _franja(raiz: Control) -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(0.02, 0.02, 0.03)
	f.anchor_left = 0.0
	f.anchor_right = 1.0
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(f)
	return f


## Entran las franjas (0,5 s).
func mostrar() -> void:
	visible = true
	_texto.text = ""
	_saltear.modulate.a = 0.0
	_animar(ALTO, 0.5)
	_tween.tween_property(_saltear, "modulate:a", 1.0, 0.4).set_delay(0.6)


## Salen las franjas y se borra el texto.
func ocultar() -> void:
	_texto.text = ""
	_saltear.modulate.a = 0.0
	_animar(0.0, 0.45)
	_tween.chain().tween_callback(func() -> void: visible = false)


## Cambia el subtítulo con un fundido corto.
func texto(t: String) -> void:
	_texto.text = t
	_texto.modulate.a = 0.0
	create_tween().tween_property(_texto, "modulate:a", 1.0, 0.3)


func _animar(alto: float, segundos: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_arriba, "anchor_bottom", alto, segundos)
	_tween.tween_property(_abajo, "anchor_top", 1.0 - alto, segundos)
