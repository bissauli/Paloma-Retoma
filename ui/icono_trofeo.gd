class_name IconoTrofeo
extends Control
## Icono dibujado por código (nítido a cualquier tamaño, sin imágenes): un trofeo o una medalla.
## Bloqueado se ve gris y apagado. Lo usan el botón del menú, la lista de Logros y el aviso.

enum Forma { TROFEO, MEDALLA }

@export var forma: Forma = Forma.TROFEO:
	set(v):
		forma = v
		queue_redraw()
@export var color := Color("ffc83d"):
	set(v):
		color = v
		queue_redraw()
@export var bloqueado := false:
	set(v):
		bloqueado = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32, 32)


func _draw() -> void:
	var lado := minf(size.x, size.y)
	if lado <= 1.0:
		return
	var c := Color(0.5, 0.56, 0.6, 0.75) if bloqueado else color
	var origen := (size - Vector2(lado, lado)) * 0.5
	# Un punto (0..1, 0..1) del cuadrado del icono -> píxeles
	var p := func(x: float, y: float) -> Vector2: return origen + Vector2(x, y) * lado
	if forma == Forma.TROFEO:
		_trofeo(p, c, lado)
	else:
		_medalla(p, c, lado)


func _trofeo(p: Callable, c: Color, lado: float) -> void:
	var oscuro := c.darkened(0.35)
	var claro := c.lightened(0.45)
	var grosor := maxf(lado * 0.06, 1.5)
	# Asas
	for lado_x in [-1.0, 1.0]:
		var centro: Vector2 = p.call(0.5 + 0.3 * lado_x, 0.27)
		var desde := -PI * 0.5 if lado_x < 0.0 else -PI * 0.5
		var hasta := PI * 0.5
		if lado_x < 0.0:
			draw_arc(centro, lado * 0.13, PI * 0.5, PI * 1.5, 14, oscuro, grosor)
		else:
			draw_arc(centro, lado * 0.13, desde, hasta, 14, oscuro, grosor)
	# Copa
	var copa := PackedVector2Array([p.call(0.2, 0.1), p.call(0.8, 0.1), p.call(0.74, 0.4),
		p.call(0.62, 0.55), p.call(0.38, 0.55), p.call(0.26, 0.4)])
	draw_colored_polygon(copa, c)
	draw_polyline(PackedVector2Array([copa[0], copa[1], copa[2], copa[3], copa[4], copa[5], copa[0]]), oscuro, maxf(lado * 0.035, 1.0))
	# Brillo
	draw_colored_polygon(PackedVector2Array([p.call(0.27, 0.15), p.call(0.37, 0.15), p.call(0.41, 0.46), p.call(0.34, 0.42)]), claro)
	# Tronco y base
	draw_rect(Rect2(p.call(0.43, 0.55), Vector2(0.14, 0.17) * lado), oscuro)
	draw_rect(Rect2(p.call(0.28, 0.72), Vector2(0.44, 0.1) * lado), c)
	draw_rect(Rect2(p.call(0.28, 0.72), Vector2(0.44, 0.1) * lado), oscuro, false, maxf(lado * 0.035, 1.0))
	draw_rect(Rect2(p.call(0.2, 0.82), Vector2(0.6, 0.08) * lado), oscuro)
	# Estrellita en la copa (sólo si no está bloqueado)
	if not bloqueado:
		_estrella(p.call(0.5, 0.31), lado * 0.12, Color(1, 1, 1, 0.9))


func _medalla(p: Callable, c: Color, lado: float) -> void:
	var oscuro := c.darkened(0.35)
	var cinta := Color(0.35, 0.4, 0.45, 0.8) if bloqueado else Color("e8665a")
	# Cintas
	draw_colored_polygon(PackedVector2Array([p.call(0.28, 0.06), p.call(0.5, 0.06), p.call(0.56, 0.5), p.call(0.38, 0.5)]), cinta)
	draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.06), p.call(0.72, 0.06), p.call(0.62, 0.5), p.call(0.44, 0.5)]), cinta.darkened(0.2))
	# Medalla
	var centro: Vector2 = p.call(0.5, 0.62)
	draw_circle(centro, lado * 0.27, oscuro)
	draw_circle(centro, lado * 0.23, c)
	draw_circle(centro, lado * 0.16, c.lightened(0.25))
	if not bloqueado:
		_estrella(centro, lado * 0.15, oscuro)


func _estrella(centro: Vector2, radio: float, relleno: Color) -> void:
	var puntos := PackedVector2Array()
	for i in 10:
		var r := radio if i % 2 == 0 else radio * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		puntos.append(centro + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(puntos, relleno)
