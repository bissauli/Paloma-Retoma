class_name CamaraMenu
extends Camera3D
## Cámara del menú principal: primer plano de la paloma de la jugadora, que queda abajo a la
## izquierda de la pantalla (la interfaz va a la derecha y no le tapa la cabeza).
## Al empezar la partida se desengancha del menú y vuela hasta la cámara del juego sin cortes:
## gira alrededor de la paloma (ángulo, altura y distancia interpolados, así nunca la atraviesa),
## ajusta el FOV y el encuadre, y al final calza exacto con la cámara orbital y le pasa el mando.

signal transicion_terminada

@export var distancia := 1.6            ## Metros desde el pecho de la paloma
@export var altura := 0.3               ## Altura de la cámara sobre los pies de la paloma
@export var angulo := -24.0             ## Grados de costado respecto del frente de la paloma
@export var centro := 0.24              ## Altura del "pecho" de la paloma (lo que se encuadra)
## Dónde queda el pecho de la paloma en la pantalla, en coordenadas normalizadas (-1..1):
## x negativo = izquierda, y negativo = abajo.
@export var en_pantalla := Vector2(-0.5, -0.22)
@export var fov_menu := 36.0
@export var duracion := 2.1             ## Segundos de la transición al juego

var objetivo: Node3D                    ## La paloma
var rumbo := 0.0                        ## Hacia dónde mira la paloma (yaw, como PalomaJugador._rumbo)

var _destino: Camera3D
var _t := -1.0                          ## Progreso de la transición (-1 = en el menú)
var _vaiven := 0.0


func _ready() -> void:
	fov = fov_menu
	near = 0.03
	far = 400.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Encuadra la paloma de una vez (sin esperar al primer cuadro).
func encuadrar(paloma: Node3D, rumbo_paloma: float) -> void:
	objetivo = paloma
	rumbo = rumbo_paloma
	global_transform = _pose_menu()
	make_current()


## Empieza la transición hacia la cámara del juego (que tiene que estar moviéndose sola).
func transicionar_a(camara_juego: Camera3D) -> void:
	_destino = camara_juego
	_t = 0.0


func _process(delta: float) -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		return
	_vaiven += delta
	if _t < 0.0:
		global_transform = _pose_menu()
		fov = fov_menu
		return
	_t = minf(_t + delta / duracion, 1.0)
	var w := _suave(_t)
	var desde := _pose_menu()
	var hasta := _destino.global_transform
	var pecho := _pecho()

	# Posición: órbita alrededor del pecho (ángulos y distancia interpolados)
	var o1 := desde.origin - pecho
	var o2 := hasta.origin - pecho
	var yaw := lerp_angle(atan2(o1.x, o1.z), atan2(o2.x, o2.z), w)
	var pitch := lerpf(asin(clampf(o1.y / maxf(o1.length(), 0.001), -1.0, 1.0)),
		asin(clampf(o2.y / maxf(o2.length(), 0.001), -1.0, 1.0)), w)
	var dist := lerpf(o1.length(), o2.length(), w)
	var pos := pecho + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist

	# Orientación: mira a un punto que va del pecho (con el encuadre corrido del menú) al punto
	# que mira la cámara del juego
	var mira_juego := hasta.origin - hasta.basis.z * o2.length()
	var mira := pecho.lerp(mira_juego, w)
	var base := Basis.looking_at(mira - pos, Vector3.UP)
	base = base * _corrimiento(lerpf(fov_menu, _destino.fov, w), 1.0 - w)
	var t := Transform3D(base, pos)
	# Los últimos cuadros calzan exacto con la cámara del juego
	t = t.interpolate_with(hasta, smoothstep(0.7, 1.0, _t))
	global_transform = t
	fov = lerpf(fov_menu, _destino.fov, w)
	if _t >= 1.0:
		_destino.make_current()
		current = false
		set_process(false)
		transicion_terminada.emit()


func _pecho() -> Vector3:
	var p := objetivo.get_global_transform_interpolated().origin if objetivo.is_inside_tree() else objetivo.global_position
	return p + Vector3.UP * centro


func _pose_menu() -> Transform3D:
	var pecho := _pecho()
	var frente := Vector3(-sin(rumbo), 0.0, -cos(rumbo))
	var dir := frente.rotated(Vector3.UP, deg_to_rad(angulo))
	# Vaivén muy suave, como una cámara en mano que respira
	var v := Vector3(sin(_vaiven * 0.53) * 0.018, sin(_vaiven * 0.37 + 1.0) * 0.012, 0.0)
	var pos := pecho + dir * distancia + Vector3.UP * (altura - centro) + v
	var base := Basis.looking_at(pecho - pos, Vector3.UP)
	return Transform3D(base * _corrimiento(fov_menu, 1.0), pos)


## Rotación que corre el encuadre para que lo que estaba en el centro quede en "en_pantalla".
## Depende del ancho de la ventana (el FOV vertical es fijo), así se ve igual en cualquier formato.
func _corrimiento(fov_grados: float, cuanto: float) -> Basis:
	var vp := get_viewport().get_visible_rect().size
	var aspecto := vp.x / maxf(vp.y, 1.0)
	var tan_v := tan(deg_to_rad(fov_grados) * 0.5)
	var ax := atan(en_pantalla.x * tan_v * aspecto) * cuanto
	var ay := atan(-en_pantalla.y * tan_v) * cuanto
	return Basis(Vector3.UP, ax) * Basis(Vector3.RIGHT, ay)


static func _suave(x: float) -> float:
	# Ease in-out cúbico: arranca y llega despacio
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
