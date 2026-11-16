class_name AletazoPaloma
extends SkeletonModifier3D
## El aletazo: un ala (una vez la izquierda y otra la derecha) se arma hacia atrás, barre hacia
## adelante al costado del pico y vuelve. Se aplica encima de lo que haga la animación (caminar,
## quieta...) girando sólo el hueso del ala, igual que los gestos de la cabeza. Ver ModeloPaloma.aletazo.

const DURACION := 0.36

var _t := -1.0
var _izquierda := true
var _hueso_izq := -1
var _hueso_der := -1
## Cuántas veces se giró el ala (para las pruebas: Skeleton3D restaura la pose después de dibujar,
## así que desde afuera no se ve el giro leyendo los huesos).
var aplicaciones := 0


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		_hueso_izq = sk.find_bone("wing_L")
		_hueso_der = sk.find_bone("wing_R")


## Empieza un aletazo con el ala izquierda o la derecha.
func golpear(con_izquierda: bool) -> void:
	_izquierda = con_izquierda
	_t = 0.0


func esta_golpeando() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t >= 0.0:
		_t += delta
		if _t >= DURACION:
			_t = -1.0


## (abrir, subir) del ala en grados, según cuánto avanzó el golpe (0 a 1): se arma hacia atrás y
## arriba, barre rápido hacia adelante (pasa los 90°, o sea, adelante del cuerpo) y vuelve.
static func curva(u: float) -> Vector2:
	if u < 0.28:
		var k := smoothstep(0.0, 1.0, u / 0.28)
		return Vector2(50.0 * k, 32.0 * k)
	if u < 0.58:
		var s := (u - 0.28) / 0.3
		s = s * s * (3.0 - 2.0 * s)
		return Vector2(lerpf(50.0, 135.0, s), lerpf(32.0, 8.0, s))
	var r := smoothstep(0.0, 1.0, (u - 0.58) / 0.42)
	return Vector2(lerpf(135.0, 0.0, r), lerpf(8.0, 0.0, r))


func _process_modification_with_delta(_delta: float) -> void:
	if _t < 0.0:
		return
	var sk := get_skeleton()
	var hueso := _hueso_izq if _izquierda else _hueso_der
	if sk == null or hueso < 0:
		return
	var a := curva(_t / DURACION)
	aplicaciones += 1
	# El giro está en el espacio del modelo (igual que las poses de baile: ver Coreografia._ala_izq)
	var giro := Coreografia._ala_izq(a.x, a.y) if _izquierda else Coreografia._ala_der(a.x, a.y)
	var padre := sk.get_bone_parent(hueso)
	var global_padre := sk.get_bone_global_pose(padre).basis if padre >= 0 else Basis.IDENTITY
	var global_actual := global_padre * Basis(sk.get_bone_pose_rotation(hueso))
	sk.set_bone_pose_rotation(hueso, (global_padre.inverse() * giro * global_actual).get_rotation_quaternion())
