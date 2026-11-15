class_name Brujula
extends Control
## Brújula arriba al centro (como la de Skyrim, con el estilo del menú): una barra oscura cortada
## en diagonal con marcas cada 5 grados y las letras N, E, S y O que se desplazan según hacia
## dónde mira la cámara. Los destinos de la misión (GameState.destinos) aparecen como rombos que
## se mueven con ellos; si quedan fuera de la barra se pegan al borde con una flecha, así siempre
## indica para dónde ir. Debajo del destino más cercano al centro se lee su nombre y la distancia.
## 0 = norte (-Z), y los ángulos crecen hacia el este (+X), como en el mapa de la plaza.

const ALTO := 50.0
const INCLINACION := 0.42            ## Igual que las barras del menú y del HUD
const ABERTURA := PI                 ## Lo que se ve de lado a lado (radianes): 180 grados
const FUNDIDO := 80.0                ## Las marcas se desvanecen en los últimos píxeles de cada punta
const RADIO_META := 10.0
const RADIO_META_SECUNDARIA := 6.0
const AVISO_CERCA := 6.0             ## Metros: el destino "late" cuando ya estás llegando
const C_MARCA := Color(1, 1, 1, 0.95)
const LETRAS := {0: "N", 90: "E", 180: "S", 270: "O"}
const LETRAS_INTERMEDIAS := {45: "NE", 135: "SE", 225: "SO", 315: "NO"}

var destinos: Array = []:
	set(v):
		destinos = v
		_nodos.clear()
		_nodos.resize(destinos.size())
		_buscar_nodos()
		queue_redraw()

var _nodos: Array = []               ## Node3D de cada destino (null hasta encontrarlo)
var _rumbo := 0.0
var _pos := Vector3.ZERO
var _t_busqueda := 0.0
var _pulso := 0.0


func _ready() -> void:
	theme = EstiloUI.TEMA
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = ALTO
	GameState.destinos_cambio.connect(func(d: Array) -> void: destinos = d)
	destinos = GameState.destinos


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t_busqueda -= delta
	if _t_busqueda <= 0.0:
		_t_busqueda = 1.0
		_buscar_nodos()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := -cam.global_transform.basis.z
	var rumbo := atan2(f.x, -f.z)
	var jugadora := GameState.jugador
	var pos := jugadora.global_position if jugadora else cam.global_position
	var cerca := _hay_destino_cerca()
	if cerca:
		_pulso += delta
	if cerca or absf(angle_difference(rumbo, _rumbo)) > 0.0004 or pos.distance_squared_to(_pos) > 0.01:
		_rumbo = rumbo
		_pos = pos
		queue_redraw()


## Busca en el árbol los nodos de los destinos que todavía no se encontraron.
func _buscar_nodos() -> void:
	for i in destinos.size():
		if not is_instance_valid(_nodos[i]):
			_nodos[i] = get_tree().get_first_node_in_group(destinos[i]["grupo"])


func _hay_destino_cerca() -> bool:
	for i in destinos.size():
		var n := _nodos[i] as Node3D
		if is_instance_valid(n) and destinos[i].get("principal", true) \
				and _distancia(n.global_position) < AVISO_CERCA:
			return true
	return false


func _distancia(destino: Vector3) -> float:
	return Vector2(destino.x - _pos.x, destino.z - _pos.z).length()


## Ángulo (rad) del destino respecto de hacia dónde mira la cámara: 0 = justo enfrente, positivo = a la derecha.
func _relativo(destino: Vector3) -> float:
	return wrapf(atan2(destino.x - _pos.x, -(destino.z - _pos.z)) - _rumbo, -PI, PI)


func _draw() -> void:
	var w := size.x
	var mitad := w * 0.5
	var px_por_rad := w / ABERTURA
	_dibujar_barra(w)
	var fuente_letras := get_theme_font("font", &"TituloPantalla")
	var fuente_chica := get_theme_font("font", &"Etiqueta")
	for g in range(0, 360, 5):
		var x := mitad + wrapf(deg_to_rad(g) - _rumbo, -PI, PI) * px_por_rad
		var fundido := clampf((mitad - absf(x - mitad) - 6.0) / FUNDIDO, 0.0, 1.0)
		if fundido <= 0.0:
			continue
		var color := Color(C_MARCA, fundido * (0.95 if g % 15 == 0 else 0.5))
		if LETRAS.has(g):
			_texto(fuente_letras, Vector2(x, ALTO * 0.44), tr(LETRAS[g]), 30, Color(C_MARCA, fundido))
		elif LETRAS_INTERMEDIAS.has(g):
			_texto(fuente_chica, Vector2(x, ALTO * 0.44), tr(LETRAS_INTERMEDIAS[g]), 15, Color(C_MARCA, fundido * 0.8))
		else:
			var alto := 11.0 if g % 15 == 0 else 6.0
			draw_line(Vector2(x, ALTO - 9.0 - alto), Vector2(x, ALTO - 9.0), color, 2.0)
	# Marca fija del centro (hacia donde mira la cámara)
	draw_colored_polygon(PackedVector2Array([Vector2(mitad - 7, 0), Vector2(mitad + 7, 0), Vector2(mitad, 9)]), C_MARCA)
	_dibujar_destinos(w, mitad, px_por_rad, fuente_chica)


## Fondo oscuro translúcido con el mismo corte en diagonal que las barras del menú.
func _dibujar_barra(w: float) -> void:
	var dx := ALTO * INCLINACION
	draw_colored_polygon(PackedVector2Array([Vector2(dx, 0), Vector2(w, 0), Vector2(w - dx, ALTO), Vector2(0, ALTO)]),
		Color(EstiloUI.C_OSCURO, 0.5))
	draw_line(Vector2(dx, 1), Vector2(w, 1), EstiloUI.C_CYAN_BORDE, 2.0)
	draw_line(Vector2(0, ALTO - 1), Vector2(w - dx, ALTO - 1), EstiloUI.C_CYAN_BORDE, 2.0)


func _dibujar_destinos(w: float, mitad: float, px_por_rad: float, fuente: Font) -> void:
	var margen := 30.0
	var elegido := -1            ## El principal más cercano al centro: el que lleva el nombre debajo
	var menor := INF
	for i in destinos.size():
		var n := _nodos[i] as Node3D
		if not is_instance_valid(n) or not destinos[i].get("principal", true):
			continue
		var rel := absf(_relativo(n.global_position))
		if rel < menor:
			menor = rel
			elegido = i
	# Primero los secundarios (quedan debajo) y al final los principales
	for pasada in 2:
		for i in destinos.size():
			var d: Dictionary = destinos[i]
			var principal: bool = d.get("principal", true)
			var n := _nodos[i] as Node3D
			if not is_instance_valid(n) or principal != (pasada == 1):
				continue
			var rel := _relativo(n.global_position)
			var x := mitad + rel * px_por_rad
			var afuera := absf(x - mitad) > mitad - margen
			x = clampf(x, mitad - (mitad - margen), mitad + (mitad - margen))
			var y := ALTO * 0.5
			var dist := _distancia(n.global_position)
			if afuera:
				_flecha(Vector2(x, y), signf(rel), principal)
			else:
				_rombo(Vector2(x, y), principal, dist)
			if i == elegido and not afuera:
				var nombre := "%s  ·  %d m" % [tr(d["nombre"]), roundi(dist)]
				_texto(fuente, Vector2(x, ALTO + 16.0), nombre, 16, C_MARCA)


func _rombo(c: Vector2, principal: bool, dist: float) -> void:
	var r := RADIO_META if principal else RADIO_META_SECUNDARIA
	if principal and dist < AVISO_CERCA:
		# Ya estás llegando: un aro que se agranda y se apaga
		var k := fmod(_pulso * 1.4, 1.0)
		_forma_rombo(c, r + 14.0 * k, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0)
	var relleno := Color.WHITE if principal else Color(EstiloUI.C_CYAN_BORDE, 0.9)
	_forma_rombo(c, r + 2.0, Color(0, 0.03, 0.06, 0.55), Color.TRANSPARENT, 0.0)
	_forma_rombo(c, r, relleno, EstiloUI.C_CYAN_BORDE if principal else Color.WHITE, 2.0)


func _forma_rombo(c: Vector2, r: float, relleno: Color, borde: Color, grosor: float) -> void:
	var p := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if relleno.a > 0.0:
		draw_colored_polygon(p, relleno)
	if borde.a > 0.0 and grosor > 0.0:
		p.append(p[0])
		draw_polyline(p, borde, grosor, true)


## Destino fuera de la barra: flecha pegada al borde del lado en que está.
func _flecha(c: Vector2, lado: float, principal: bool) -> void:
	var r := 9.0 if principal else 6.0
	var color := Color(1, 1, 1, 0.85 if principal else 0.5)
	var p := PackedVector2Array([c + Vector2(lado * r, 0), c + Vector2(-lado * r * 0.6, -r), c + Vector2(-lado * r * 0.6, r)])
	draw_colored_polygon(p, color)


func _texto(fuente: Font, centro: Vector2, texto: String, tam: int, color: Color) -> void:
	var ancho := fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	var pos := Vector2(centro.x - ancho * 0.5, centro.y + tam * 0.35)
	draw_string_outline(fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(0, 0.08, 0.12, color.a * 0.55))
	draw_string(fuente, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)
