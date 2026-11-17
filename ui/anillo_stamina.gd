class_name AnilloStamina
extends Control
## La stamina junto a la paloma (como la de Genshin Impact): un semi anillo celeste pegado a un
## costado de la paloma que se vacía con lo que gastás y se llena al recuperar. Sólo se ve cuando
## hace falta: aparece apenas la stamina baja de lo máximo y se va con un fundido 1,5 s después de
## llenarse (con la stamina llena no hay nada en pantalla). Con poca (menos de 25 %) se pone rojo
## y titila, como antes la barra de la esquina. Se pega del lado derecho de la paloma en la pantalla
## y pasa al izquierdo si está por salirse. Tiene un tamaño fijo y chico (no crece si la cámara se
## acerca) y queda separado de la silueta de la paloma, con las alas abiertas incluidas. Escucha sólo GameState.stamina_cambio.

const ARCO := 150.0                 ## Grados que abarca el semi anillo
const ANCHO := 5.0                  ## Grosor del arco (px)
const RADIO := 26.0                 ## Radio fijo (px): el semi anillo mide unos 50 px de alto
const HOLGURA := 16.0               ## Separación (px) entre la punta del ala y las puntas del arco
const MEDIO_ANCHO := 0.42           ## Metros del centro a la punta del ala abierta
const RETARDO := 1.5                ## Segundos que sigue visible después de llenarse
const FUNDIDO_SALIDA := 0.35
const UMBRAL_BAJA := 0.25
const C_CELESTE := Color(0.42, 0.86, 1.0, 0.95)
const C_BAJA := Color("ff7a6b")
const C_RIEL := Color(0.0, 0.03, 0.06, 0.4)
const ALTURA_CUERPO := 0.22         ## Metros sobre los pies: el centro del cuerpo de la paloma

var _valor := 1.0                   ## 0..1
var _alfa := 0.0                    ## Qué tan visible está (0 = nada)
var _t_lleno := RETARDO             ## Segundos que lleva llena
var _t := 0.0
var _pos := Vector2.ZERO            ## Centro del arco en la pantalla (suavizado)
var _lado := 1.0                    ## 1 = a la derecha de la paloma, -1 = a la izquierda
var _hay_pos := false
var _en_pantalla := false


func _ready() -> void:
	name = "AnilloStamina"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.stamina_cambio.connect(_al_cambiar)
	_al_cambiar(GameState.stamina, Config.STAMINA_MAX)


func _al_cambiar(valor: float, maximo: float) -> void:
	_valor = clampf(valor / maxf(maximo, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	actualizar_visibilidad(delta)
	if _alfa <= 0.0:
		if _en_pantalla:
			_en_pantalla = false
			queue_redraw()
		return
	_seguir_a_la_paloma(delta)
	queue_redraw()


## Aparece en cuanto la stamina no está llena y se va RETARDO segundos después de llenarse.
func actualizar_visibilidad(delta: float) -> void:
	_t += delta
	var objetivo := 1.0
	if _valor >= 0.999:
		_t_lleno += delta
		if _t_lleno >= RETARDO:
			objetivo = 0.0
	else:
		_t_lleno = 0.0
	var velocidad := 8.0 if objetivo > _alfa else 1.0 / FUNDIDO_SALIDA
	_alfa = move_toward(_alfa, objetivo, delta * velocidad)


## ¿Se ve ahora? (para las pruebas)
func esta_visible() -> bool:
	return _alfa > 0.01


## Busca dónde está la paloma en la pantalla y pone el arco a su costado, separado de la silueta
## (con las alas abiertas). El tamaño del arco es fijo; sólo la separación sigue el tamaño aparente
## de la paloma, que de lejos es más chica.
func _seguir_a_la_paloma(delta: float) -> void:
	var camara := get_viewport().get_camera_3d()
	var jugadora := GameState.jugador
	if camara == null or jugadora == null:
		_en_pantalla = false
		return
	var cuerpo := jugadora.get_global_transform_interpolated().origin + Vector3.UP * ALTURA_CUERPO
	_en_pantalla = not camara.is_position_behind(cuerpo)
	if not _en_pantalla:
		return
	var centro := camara.unproject_position(cuerpo)
	var medio_ancho := (camara.unproject_position(cuerpo + camara.global_basis.x * MEDIO_ANCHO) - centro).length()
	# Las puntas del arco quedan a cos(75°) del radio del centro del arco: se compensa
	var separacion := medio_ancho + HOLGURA - RADIO * cos(deg_to_rad(ARCO * 0.5))
	var lado := 1.0 if centro.x < size.x - (medio_ancho + RADIO + HOLGURA + 30.0) else -1.0
	var destino := centro + Vector2(lado * separacion, -4.0)
	if not _hay_pos:
		_pos = destino
		_hay_pos = true
	else:
		_pos = _pos.lerp(destino, 1.0 - exp(-30.0 * delta))
	_lado = lado


func _draw() -> void:
	if _alfa <= 0.01 or not _en_pantalla:
		return
	var color := C_CELESTE
	var parpadeo := 1.0
	if _valor < UMBRAL_BAJA:
		parpadeo = 0.6 + 0.4 * sin(_t * 14.0)
		color = C_BAJA.lerp(C_CELESTE, clampf((_valor - 0.15) * 4.0, 0.0, 1.0))
	# A la derecha es un ")" y a la izquierda un "(". Se llena desde abajo y se vacía desde arriba:
	# el relleno queda pegado a la punta de abajo y lo primero que se gasta es la de arriba.
	var arriba := deg_to_rad(-ARCO * 0.5) if _lado > 0.0 else deg_to_rad(180.0 + ARCO * 0.5)
	var total := deg_to_rad(ARCO)
	var abajo := arriba + _lado * total
	_arco(arriba, abajo, Color(C_RIEL, C_RIEL.a * _alfa), ANCHO + 2.0, false)
	if _valor > 0.0:
		_arco(abajo, abajo - _lado * total * _valor, Color(color, color.a * _alfa * parpadeo), ANCHO, true)


## Arco. Con "con_tapas" las puntas son redondas (medios círculos hacia afuera). El riel translúcido
## va sin tapas: al superponerse con el arco, una tapa translúcida dejaba un punto más oscuro en la punta.
func _arco(a0: float, a1: float, color: Color, ancho: float, con_tapas: bool) -> void:
	var menor := minf(a0, a1)
	var mayor := maxf(a0, a1)
	draw_arc(_pos, RADIO, menor, mayor, 24, color, ancho, true)
	if con_tapas:
		_tapa(menor, -1.0, color, ancho)
		_tapa(mayor, 1.0, color, ancho)


## Medio círculo en la punta del arco que está en el ángulo "angulo"; "salida" es +1 si el arco sigue
## hacia los ángulos menores (la punta es el ángulo mayor) y -1 en el caso contrario.
func _tapa(angulo: float, salida: float, color: Color, ancho: float) -> void:
	var radial := Vector2(cos(angulo), sin(angulo))
	var tangente := Vector2(-sin(angulo), cos(angulo)) * salida
	var centro := _pos + radial * RADIO
	var puntos := PackedVector2Array()
	for i in 9:
		var f := PI * i / 8.0
		puntos.append(centro + (radial * cos(f) + tangente * sin(f)) * ancho * 0.5)
	# Si la paloma está fuera de cuadro (o la ventana no tiene tamaño, como sin pantalla) la posición
	# puede venir rara y el polígono queda degenerado: Godot no lo puede triangular y avisa con un error
	if not centro.is_finite() or Geometry2D.triangulate_polygon(puntos).is_empty():
		return
	draw_colored_polygon(puntos, color)
