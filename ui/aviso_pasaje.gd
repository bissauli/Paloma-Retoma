class_name AvisoPasaje
extends CanvasLayer
## El aviso en pantalla para atravesar volando un departamento: "E · ATRAVESAR VOLANDO" (en el
## teléfono, sin la tecla). Aparece cuando la paloma está afuera frente a una ventana de un
## CasaEnterable con cinemática; con E (la acción "interactuar"), un click o un toque arranca la
## cinemática. Si no lo aprieta, no pasa nada y puede entrar sola. Hay uno solo: lo crea el primer
## CasaEnterable que lo necesita (si hay varias ventanas cerca, gana la más cercana).

static var _uno: AvisoPasaje

var casa: CasaEnterable          ## La sala que se ofrece ahora (null = ninguna)
var desde_frente := true
var _distancia := INF
var _boton: Button


## La sala "c" ofrece su cinemática (la paloma está a "dist" metros de ella).
static func ofrecer(c: CasaEnterable, frente: bool, dist: float) -> void:
	if _uno == null or not is_instance_valid(_uno):
		_uno = AvisoPasaje.new()
		c.get_tree().root.add_child(_uno)
	if _uno.casa != null and _uno.casa != c and is_instance_valid(_uno.casa) and _uno._distancia < dist:
		return   # Hay otra ventana más cerca
	_uno.casa = c
	_uno.desde_frente = frente
	_uno._distancia = dist
	_uno._mostrar()


## La sala "c" deja de ofrecer (la paloma se alejó, o arrancó o terminó la cinemática).
static func soltar(c: CasaEnterable) -> void:
	if _uno != null and is_instance_valid(_uno) and _uno.casa == c:
		_uno.casa = null
		_uno._distancia = INF
		_uno._boton.visible = false


## ¿Se está mostrando el aviso? (para las pruebas)
static func visible_ahora() -> bool:
	return _uno != null and is_instance_valid(_uno) and _uno.casa != null and _uno._boton.visible


## Aprieta el aviso (lo mismo que E): para las pruebas y para el toque.
static func apretar() -> void:
	if _uno != null and is_instance_valid(_uno):
		_uno._activar()


func _init() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_boton = Button.new()
	_boton.focus_mode = Control.FOCUS_NONE
	_boton.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 180)
	_boton.grow_horizontal = Control.GROW_DIRECTION_BOTH
	for estado in ["normal", "hover", "pressed"]:
		_boton.add_theme_stylebox_override(estado, EstiloUI.caja(EstiloUI.C_OSCURO, 0.25, EstiloUI.C_CYAN_BORDE))
	_boton.add_theme_font_size_override("font_size", 22)
	_boton.pressed.connect(_activar)
	_boton.visible = false
	raiz.add_child(_boton)


func _mostrar() -> void:
	var tecla := "" if Ajustes.movil else "E   "
	_boton.text = tecla + tr("ATRAVESAR VOLANDO")
	_boton.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if casa != null and _boton.visible and event.is_action_pressed("interactuar"):
		_activar()
		get_viewport().set_input_as_handled()


func _activar() -> void:
	if casa != null and is_instance_valid(casa):
		var c := casa
		c.empezar_por_boton(desde_frente)
