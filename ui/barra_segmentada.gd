class_name BarraSegmentada
extends Control
## Barra de segmentos inclinados, con el mismo corte en diagonal que los botones del menú principal.
## Los segmentos llenos van en "color", el que está a medio llenar se llena de izquierda a derecha
## y los vacíos quedan como un hueco oscuro translúcido. Con "alerta" el color titila.

@export var segmentos := 12
@export var separacion := 4.0
@export var inclinacion := 0.42        ## Igual que el skew de los botones del menú
@export var color := Color(1, 1, 1)
@export var color_vacio := Color(0.0, 0.03, 0.06, 0.38)
@export var color_borde := Color(1, 1, 1, 0.35)

var valor := 1.0:   ## 0..1
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, valor):
			valor = v
			queue_redraw()
var alerta := false:
	set(v):
		if v != alerta:
			alerta = v
			queue_redraw()

var _t := 0.0


func _process(delta: float) -> void:
	if alerta:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var alto := size.y
	var corrida := alto * inclinacion
	var ancho_seg := (size.x - corrida - separacion * (segmentos - 1)) / segmentos
	var c := color
	if alerta:
		c.a *= 0.55 + 0.45 * absf(sin(_t * 7.0))
	var lleno := valor * segmentos
	for i in segmentos:
		var x := i * (ancho_seg + separacion)
		_paralelogramo(x, ancho_seg, corrida, color_vacio)
		var k := clampf(lleno - i, 0.0, 1.0)
		if k > 0.0:
			_paralelogramo(x, ancho_seg * k, corrida, c)
		_contorno(x, ancho_seg, corrida, color_borde)


## Segmento con la base corrida a la izquierda (como el skew positivo de StyleBoxFlat).
func _puntos(x: float, ancho: float, corrida: float) -> PackedVector2Array:
	var alto := size.y
	return PackedVector2Array([
		Vector2(x + corrida, 0), Vector2(x + corrida + ancho, 0),
		Vector2(x + ancho, alto), Vector2(x, alto)])


func _paralelogramo(x: float, ancho: float, corrida: float, c: Color) -> void:
	draw_colored_polygon(_puntos(x, ancho, corrida), c)


func _contorno(x: float, ancho: float, corrida: float, c: Color) -> void:
	var p := _puntos(x, ancho, corrida)
	p.append(p[0])
	draw_polyline(p, c, 1.0, true)
