class_name AvisoAccion
extends CanvasLayer
## El indicador de acciones de todo el juego: una pastilla abajo al centro con la tecla en una
## chapita clara y la acción al lado ("E  BAÑARSE"), en el estilo del HUD (caja inclinada cyan).
## Cualquiera lo pide con AvisoAccion.mostrar(...) y lo saca con AvisoAccion.ocultar(...). Si hay
## varios pedidos a la vez se ve el de mayor prioridad. En el teléfono no lleva tecla y se toca.
## Se crea solo la primera vez que se pide, colgado de la raíz del árbol.

static var _nodo: AvisoAccion

var _pedidos := {}            ## id -> {tecla, texto, prioridad, alAccionar}
var _actual := ""
var _pastilla: PanelContainer
var _chapa: PanelContainer
var _tecla: Label
var _texto: Label
var _tween: Tween


## Pide mostrar "tecla  texto". "id" identifica al que pide (para sacarlo después). "al_tocar" se
## llama si la tocan (teléfono o mouse).
static func mostrar(arbol: SceneTree, id: String, tecla: String, texto: String, prioridad := 0,
		al_tocar := Callable()) -> void:
	var n := _obtener(arbol)
	if n:
		n._pedir(id, tecla, texto, prioridad, al_tocar)


static func ocultar(arbol: SceneTree, id: String) -> void:
	if _nodo and is_instance_valid(_nodo) and arbol:
		_nodo._quitar(id)


## Borra todos los pedidos: al volver al menú o reiniciar, los que lo pedían ya no existen (o no van a
## poder sacarlo) y el aviso se quedaba colgado ("HABLAR CON ..." sobre el menú principal).
static func limpiar() -> void:
	if _nodo and is_instance_valid(_nodo):
		_nodo._pedidos.clear()
		_nodo._elegir()


## Esconde o muestra el aviso entero (el modo cámara lo saca de la foto).
static func esconder(si: bool) -> void:
	if _nodo and is_instance_valid(_nodo):
		_nodo.visible = not si


## ¿Se está viendo el aviso de ese pedido? (lo usan las pruebas)
static func visible_de(id: String) -> bool:
	return _nodo != null and is_instance_valid(_nodo) and _nodo._pastilla != null \
			and _nodo._actual == id and _nodo._pastilla.visible


static func _obtener(arbol: SceneTree) -> AvisoAccion:
	if _nodo == null or not is_instance_valid(_nodo):
		if arbol == null:
			return null
		_nodo = AvisoAccion.new()
		_nodo.name = "AvisoAccion"
		arbol.root.add_child.call_deferred(_nodo)
	return _nodo


func _ready() -> void:
	layer = 9       # Arriba de las barras de cinemática (8), abajo de la pausa (20)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = EstiloUI.TEMA
	add_child(raiz)

	_pastilla = PanelContainer.new()
	_pastilla.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 70)
	_pastilla.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pastilla.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pastilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_p := EstiloUI.caja(EstiloUI.C_OSCURO, 0.25, EstiloUI.C_CYAN_BORDE)
	estilo_p.content_margin_top = 2
	estilo_p.content_margin_bottom = 2
	estilo_p.content_margin_left = 18
	estilo_p.content_margin_right = 14
	estilo_p.shadow_size = 5
	_pastilla.add_theme_stylebox_override("panel", estilo_p)
	_pastilla.gui_input.connect(_al_tocar)
	raiz.add_child(_pastilla)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 9)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pastilla.add_child(fila)

	# La tecla, en una chapita clara con el mismo corte inclinado
	_chapa = PanelContainer.new()
	_chapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := EstiloUI.caja(Color(0.88, 0.97, 1.0, 0.95), 0.25)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	estilo.content_margin_top = 0
	estilo.content_margin_bottom = 0
	estilo.shadow_size = 0
	_chapa.add_theme_stylebox_override("panel", estilo)
	fila.add_child(_chapa)
	_tecla = EstiloUI.texto(_chapa, &"Etiqueta", 14)
	_tecla.add_theme_color_override("font_color", Color(0.02, 0.1, 0.16))
	_texto = EstiloUI.texto(fila, &"Etiqueta", 14)
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_pastilla.visible = false
	_elegir()   # Si pidieron algo antes de que el nodo estuviera listo


func _pedir(id: String, tecla: String, texto: String, prioridad: int, al_tocar: Callable) -> void:
	# Quien lo pide lo repite mientras dure: si no cambió nada, sólo se actualiza el callback
	var previo: Dictionary = _pedidos.get(id, {})
	if not previo.is_empty() and previo["tecla"] == tecla and previo["texto"] == texto and previo["prioridad"] == prioridad:
		previo["tocar"] = al_tocar
		return
	_pedidos[id] = {"tecla": tecla, "texto": texto, "prioridad": prioridad, "tocar": al_tocar}
	_elegir()


func _quitar(id: String) -> void:
	if _pedidos.erase(id):
		_elegir()


func _elegir() -> void:
	if _pastilla == null:
		return   # Todavía no entró al árbol: _ready vuelve a llamar
	var mejor := ""
	var mejor_p := -999999
	for id: String in _pedidos:
		var p: int = _pedidos[id]["prioridad"]
		if p > mejor_p or (p == mejor_p and id == _actual):
			mejor = id
			mejor_p = p
	if mejor == "":
		_actual = ""
		_pastilla.visible = false
		return
	var d: Dictionary = _pedidos[mejor]
	var texto := tr(String(d["texto"])).to_upper()
	var movil := Ajustes.movil
	_chapa.visible = not movil and String(d["tecla"]) != ""
	_tecla.text = String(d["tecla"])
	_texto.text = texto
	_pastilla.mouse_filter = Control.MOUSE_FILTER_STOP if (movil or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED) \
			else Control.MOUSE_FILTER_IGNORE
	if mejor != _actual or not _pastilla.visible:
		_actual = mejor
		_pastilla.visible = true
		_pastilla.pivot_offset = _pastilla.size / 2.0
		_pastilla.scale = Vector2(0.85, 0.85)
		_pastilla.modulate.a = 0.0
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_pastilla, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_pastilla, "modulate:a", 1.0, 0.15)


func _al_tocar(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _pedidos.has(_actual):
		var c: Callable = _pedidos[_actual]["tocar"]
		if c.is_valid():
			c.call()
