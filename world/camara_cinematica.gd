class_name CamaraCinematica
extends Camera3D
## Cámara de las cinemáticas del tutorial. Arranca exactamente donde está la cámara del juego (sin
## cortes), vuela de toma en toma (posición, punto al que mira y FOV) y al final vuelve volando a la
## cámara del juego, que mientras tanto sigue a la paloma, y le devuelve el mando.
## Cada movimiento avisa con "llego". volver() se puede llamar en cualquier momento (saltear).

signal llego

enum Estado { QUIETA, VOLANDO, VOLVIENDO, TERMINADA }

var estado := Estado.QUIETA

var _desde := Transform3D.IDENTITY
var _desde_mira := Vector3.ZERO
var _desde_fov := 70.0
var _hasta_pos := Vector3.ZERO
var _hasta_mira := Vector3.ZERO
var _hasta_fov := 70.0
var _arco := 0.0
var _dur := 1.0
var _t := 1.0
var _suave := true
var _mira := Vector3.ZERO       ## A dónde mira ahora (se interpola, así nunca pierde el foco)
var _juego: Camera3D


func _ready() -> void:
	near = 0.05
	far = 600.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Toma el lugar de la cámara del juego.
func empezar(camara_juego: Camera3D) -> void:
	_juego = camara_juego
	global_transform = camara_juego.global_transform
	fov = camara_juego.fov
	_mira = global_position - global_transform.basis.z * 4.0
	make_current()
	estado = Estado.QUIETA


## Vuela hasta "pos" mirando a "mira". arco: metros que sube a mitad de camino (como una grúa).
## suave = false: velocidad pareja (para el acercamiento lento sobre una toma).
func volar(pos: Vector3, mira: Vector3, fov_destino: float, duracion: float, arco := 0.0, suave := true) -> void:
	if estado == Estado.VOLVIENDO or estado == Estado.TERMINADA:
		return
	_desde = global_transform
	_desde_mira = _mira
	_desde_fov = fov
	_hasta_pos = pos
	_hasta_mira = mira
	_hasta_fov = fov_destino
	_dur = maxf(duracion, 0.01)
	_arco = arco
	_suave = suave
	_t = 0.0
	estado = Estado.VOLANDO


## Vuelve a la cámara del juego (que puede estar moviéndose) y le pasa el mando.
func volver(duracion: float, arco := 0.0) -> void:
	if estado == Estado.VOLVIENDO or estado == Estado.TERMINADA:
		return
	_desde = global_transform
	_desde_fov = fov
	_dur = maxf(duracion, 0.01)
	_arco = arco
	_suave = true
	_t = 0.0
	estado = Estado.VOLVIENDO


func _process(delta: float) -> void:
	if estado != Estado.VOLANDO and estado != Estado.VOLVIENDO:
		return
	_t = minf(_t + delta / _dur, 1.0)
	var w := _ease(_t) if _suave else _t
	var subida := Vector3.UP * _arco * sin(w * PI)
	if estado == Estado.VOLANDO:
		var pos := _desde.origin.lerp(_hasta_pos, w) + subida
		# La mirada llega antes que la cámara: enseguida apunta a lo que se va a mostrar
		var w_mira := _ease(minf(_t * 1.7, 1.0)) if _suave else _t
		_mira = _desde_mira.lerp(_hasta_mira, w_mira)
		global_transform = Transform3D(Basis.looking_at(_mira - pos, Vector3.UP), pos)
		fov = lerpf(_desde_fov, _hasta_fov, w)
		if _t >= 1.0:
			estado = Estado.QUIETA
			llego.emit()
		return
	# Volviendo: la cámara del juego sigue a la paloma, así que el destino se lee en cada cuadro
	if _juego == null or not is_instance_valid(_juego):
		estado = Estado.TERMINADA
		llego.emit()
		return
	var hasta := _juego.global_transform
	var base := _desde.basis.orthonormalized().slerp(hasta.basis.orthonormalized(), w)
	global_transform = Transform3D(base, _desde.origin.lerp(hasta.origin, w) + subida)
	fov = lerpf(_desde_fov, _juego.fov, w)
	if _t >= 1.0:
		_juego.make_current()
		current = false
		estado = Estado.TERMINADA
		llego.emit()


static func _ease(x: float) -> float:
	# Ease in-out cúbico: arranca y llega despacio
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0
