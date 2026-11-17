class_name IndicadorAmenaza
extends Control
## Aviso de dónde viene el peligro (como el indicador de disparos de Fortnite): un arco rojo alrededor
## de la paloma que apunta hacia la amenaza, relativo a hacia dónde mira la cámara, con la distancia al
## lado. Si la amenaza está a la vista le pone además una marca encima. Escucha el grupo "amenazas": cada
## nodo del grupo implementa nivel_amenaza() (0 = nada, hasta 1 = atacando) y se dibuja a su posición
## global. Hoy lo usa el halcón (enemies/halcon.gd), que desde la alerta hasta que se tira en picada
## era imposible de ubicar.

const RADIO := 120.0                 ## Radio del anillo alrededor de la paloma (px)
const ABERTURA := 0.55               ## Mitad del ancho del arco (rad)
const GROSOR := 9.0
const C_ALERTA := Color("ffb02e")
const C_ATAQUE := Color("ff3b30")
const FUNDIDO_ENTRADA := 10.0
const FUNDIDO_SALIDA := 3.0

var _alfa := 0.0
var _nivel := 0.0                    ## Nivel de la amenaza más fuerte
var _angulo := 0.0                   ## Hacia dónde apunta el arco: 0 arriba, PI/2 derecha
var _distancia := 0.0
var _fuente_pos := Vector3.ZERO
var _t := 0.0
var _centro := Vector2.ZERO
var _marca := Vector2.ZERO
var _marca_visible := false


func _ready() -> void:
	name = "IndicadorAmenaza"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ángulo en pantalla de un vector respecto de la cámara: 0 = al frente (arriba en el anillo), PI/2 = a la
## derecha, PI = atrás, -PI/2 = a la izquierda. "base" es la base global de la cámara. Sólo cuenta el plano
## horizontal de la cámara (si la amenaza está justo arriba, cae al frente).
static func angulo_en_pantalla(base: Basis, vector: Vector3) -> float:
	var local := base.inverse() * vector
	if Vector2(local.x, local.z).length() < 0.001:
		return 0.0
	return atan2(local.x, -local.z)


func _process(delta: float) -> void:
	_t += delta
	var jugadora := GameState.jugador
	var camara := get_viewport().get_camera_3d()
	_nivel = 0.0
	if jugadora != null and camara != null and GameState.en_partida and not GameState.partida_terminada:
		var base_pos := jugadora.global_position
		for n in get_tree().get_nodes_in_group("amenazas"):
			if not n.has_method("nivel_amenaza"):
				continue
			var nivel: float = n.nivel_amenaza()
			if nivel > _nivel:
				_nivel = nivel
				_fuente_pos = (n as Node3D).global_position
		if _nivel > 0.0:
			var hacia := _fuente_pos - base_pos
			_distancia = hacia.length()
			_angulo = angulo_en_pantalla(camara.global_basis, hacia)
			_centro = _centro_en_pantalla(camara, jugadora)
			_marca_visible = not camara.is_position_behind(_fuente_pos)
			if _marca_visible:
				_marca = camara.unproject_position(_fuente_pos)
				_marca_visible = Rect2(Vector2.ZERO, size).has_point(_marca)
	var objetivo := 1.0 if _nivel > 0.0 else 0.0
	_alfa = move_toward(_alfa, objetivo, delta * (FUNDIDO_ENTRADA if objetivo > _alfa else FUNDIDO_SALIDA))
	queue_redraw()


## ¿Hay un aviso en pantalla? (para las pruebas)
func esta_visible() -> bool:
	return _alfa > 0.01


func angulo_actual() -> float:
	return _angulo


func _centro_en_pantalla(camara: Camera3D, jugadora: Node3D) -> Vector2:
	var p := jugadora.global_position + Vector3.UP * 0.3
	if camara.is_position_behind(p):
		return size * 0.5
	var c := camara.unproject_position(p)
	return Vector2(clampf(c.x, RADIO, size.x - RADIO), clampf(c.y, RADIO, size.y - RADIO))


func _draw() -> void:
	if _alfa <= 0.01:
		return
	var ataque := clampf((_nivel - 0.5) * 2.0, 0.0, 1.0)      # 0 en alerta, 1 atacando
	var color := C_ALERTA.lerp(C_ATAQUE, ataque)
	var pulso := 0.65 + 0.35 * sin(_t * lerpf(9.0, 20.0, ataque))
	var a := _alfa * pulso
	var centro_ang := _angulo - PI * 0.5       # draw_arc mide desde la derecha; el 0 nuestro es arriba
	var abertura := ABERTURA * lerpf(0.85, 1.25, ataque)
	var oscuro := Color(0, 0, 0, 0.35 * _alfa)
	draw_arc(_centro, RADIO, centro_ang - abertura, centro_ang + abertura, 28, oscuro, GROSOR + 5.0, true)
	draw_arc(_centro, RADIO, centro_ang - abertura, centro_ang + abertura, 28, Color(color, a), GROSOR, true)
	# Punta de flecha hacia afuera, en el medio del arco
	var dir := Vector2(cos(centro_ang), sin(centro_ang))
	var lado := Vector2(-dir.y, dir.x)
	var base := _centro + dir * (RADIO + GROSOR)
	var punta := _centro + dir * (RADIO + GROSOR + 20.0)
	var flecha := PackedVector2Array([base + lado * 13.0, punta, base - lado * 13.0])
	draw_colored_polygon(flecha, Color(color, a))
	# Distancia al lado del arco
	var fuente := ThemeDB.fallback_font
	var texto := "%d m" % int(round(_distancia))
	var pos_texto := _centro + dir * (RADIO + 48.0) - Vector2(fuente.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x * 0.5, -6.0)
	draw_string_outline(fuente, pos_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, _alfa))
	draw_string(fuente, pos_texto, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(color, _alfa))
	# Marca sobre la amenaza si está a la vista
	if _marca_visible:
		var m := _marca + Vector2(0, -34.0)
		var tri := PackedVector2Array([m + Vector2(-13, -12), m + Vector2(13, -12), m + Vector2(0, 10)])
		draw_colored_polygon(tri, Color(color, a))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0, _alfa), 2.0)
