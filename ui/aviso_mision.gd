class_name AvisoMision
extends CanvasLayer
## Carteles cortos de lo que va pasando en las misiones (aceptada, avance, lista para entregar,
## completada con su recompensa). Aparecen arriba a la izquierda, debajo de la bandada y la comida,
## se apilan (máximo MAXIMO) y se apagan solos. Un cartel nuevo con la misma "clave" reemplaza al
## anterior en vez de apilarse: comer cinco migas seguidas deja un solo cartel que va contando.
## Los crea el autoload Misiones. Los logros tienen su propio cartel (ui/aviso_logro.gd).

const MAXIMO := 3
const ENTRADA := 0.2
const SALIDA := 0.4
const ARRIBA := 190.0           ## Debajo del bloque de bandada y comida del HUD
const IZQUIERDA := 28.0
const ORO := Color("ffd84a")
const CIAN := Color("9be8ff")

var _columna: VBoxContainer
var _vivos := {}                ## clave -> {panel, titulo, cuerpo, tween, clave}


func _ready() -> void:
	layer = 6       # Arriba del HUD (5), abajo del diálogo (9); la pausa lo tapa y lo congela
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = EstiloUI.TEMA
	add_child(raiz)
	_columna = VBoxContainer.new()
	_columna.position = Vector2(IZQUIERDA, ARRIBA)
	_columna.add_theme_constant_override("separation", 8)
	_columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(_columna)


## Muestra un cartel: "titulo" chico arriba (de color) y "cuerpo" abajo.
func mostrar(titulo: String, cuerpo: String, clave := "", color := ORO, permanencia := 2.8) -> void:
	if not GameState.en_partida or GameState.partida_terminada:
		return
	var v: Dictionary = _vivos.get(clave, {}) if clave != "" else {}
	if v.is_empty() or not is_instance_valid(v["panel"]):
		v = _crear()
		v["clave"] = clave
		if clave != "":
			_vivos[clave] = v
	(v["titulo"] as Label).text = titulo
	(v["titulo"] as Label).add_theme_color_override("font_color", color)
	(v["cuerpo"] as Label).text = cuerpo
	var panel := v["panel"] as PanelContainer
	if v["tween"] != null and (v["tween"] as Tween).is_valid():
		(v["tween"] as Tween).kill()
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, ENTRADA)
	tw.tween_interval(permanencia)
	tw.tween_property(panel, "modulate:a", 0.0, SALIDA)
	tw.tween_callback(_quitar.bind(v))
	v["tween"] = tw
	while _columna.get_child_count() > MAXIMO:
		_quitar(_vivo_de(_columna.get_child(0)))


func cantidad() -> int:
	return _columna.get_child_count()


func _crear() -> Dictionary:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Tarjeta"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0
	_columna.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	panel.add_child(caja)
	var titulo := EstiloUI.texto(caja, &"Valor", 13)
	var cuerpo := EstiloUI.texto(caja, &"TextoTarjeta", 20)
	cuerpo.custom_minimum_size = Vector2(280, 0)
	return {"panel": panel, "titulo": titulo, "cuerpo": cuerpo, "tween": null, "clave": ""}


func _vivo_de(panel: Node) -> Dictionary:
	for c: String in _vivos:
		if _vivos[c]["panel"] == panel:
			return _vivos[c]
	return {"panel": panel, "clave": "", "tween": null}


func _quitar(v: Dictionary) -> void:
	if v["tween"] != null and (v["tween"] as Tween).is_valid():
		(v["tween"] as Tween).kill()
	if v["clave"] != "":
		_vivos.erase(v["clave"])
	var panel: Node = v["panel"]
	if is_instance_valid(panel):
		panel.get_parent().remove_child(panel)
		panel.queue_free()
