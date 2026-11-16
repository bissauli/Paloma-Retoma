class_name AvisoLogro
extends CanvasLayer
## El cartelito que baja desde arriba al desbloquear un logro o un trofeo (con su icono, el nombre y
## un sonido). Si se desbloquean varios juntos, van uno detrás del otro. No frena el juego ni
## captura el mouse, y se ve también con la partida en pausa.

const ENTRADA := 0.45
const PERMANENCIA := 3.2
const SALIDA := 0.4

var _cola: Array[Dictionary] = []
var _mostrando := false
var _raiz: Control
var _panel: PanelContainer
var _icono: IconoTrofeo
var _titulo: Label
var _nombre: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.theme = EstiloUI.TEMA
	add_child(_raiz)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"Tarjeta"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_raiz.add_child(_panel)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 16)
	_panel.add_child(caja)
	_icono = IconoTrofeo.new()
	_icono.custom_minimum_size = Vector2(56, 56)
	caja.add_child(_icono)
	var texto := VBoxContainer.new()
	texto.alignment = BoxContainer.ALIGNMENT_CENTER
	texto.add_theme_constant_override("separation", 0)
	caja.add_child(texto)
	_titulo = EstiloUI.texto(texto, &"Valor", 14)
	_nombre = EstiloUI.texto(texto, &"TextoTarjeta", 24)
	_nombre.custom_minimum_size = Vector2(240, 0)


## Pone el aviso de un logro o trofeo (el Dictionary del catálogo) en la cola.
func mostrar(d: Dictionary) -> void:
	_cola.append(d)
	if not _mostrando:
		_siguiente()


func _siguiente() -> void:
	if _cola.is_empty():
		_mostrando = false
		_panel.visible = false
		return
	_mostrando = true
	var d: Dictionary = _cola.pop_front()
	var trofeo: bool = d["tipo"] == CatalogoLogros.TROFEO
	_icono.forma = IconoTrofeo.Forma.TROFEO if trofeo else IconoTrofeo.Forma.MEDALLA
	_icono.color = CatalogoLogros.color_de(d)
	_icono.bloqueado = false
	_titulo.text = "TROFEO DESBLOQUEADO" if trofeo else "LOGRO DESBLOQUEADO"
	_nombre.text = String(d["nombre"]).to_upper()
	_panel.visible = true
	_panel.reset_size()
	# Centrado arriba; arranca fuera de pantalla y baja
	var x := (_raiz.size.x - _panel.size.x) * 0.5
	_panel.position = Vector2(x, -_panel.size.y - 10.0)
	AudioManager.ui("success" if trofeo else "unlock", -4.0)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_panel, "position:y", 24.0, ENTRADA).set_ease(Tween.EASE_OUT)
	tw.tween_interval(PERMANENCIA)
	tw.tween_property(_panel, "position:y", -_panel.size.y - 10.0, SALIDA).set_ease(Tween.EASE_IN)
	tw.tween_callback(_siguiente)
