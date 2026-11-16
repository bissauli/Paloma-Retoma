class_name Animado
extends Node3D
## Juegos de la plaza que se mueven (piezas del kit que no se fusionan, ver world/ciudad.gd). Mapa V3.1:
## sólo se mueven mientras hay alguien arriba (los chicos de enemies/chico.gd); vacíos se quedan
## quietos.
## - girar: la calesita da vueltas (arranca y frena de a poco).
## - hamacar: el asiento de la hamaca se balancea sobre el eje de arriba (su origen); el envión crece
##   de a poco y al bajarse el chico se va apagando.
## - subibaja: la tabla sube y baja sobre su eje cuando hay uno en cada punta; vacío (o con uno solo)
##   se apoya en una punta, como los de verdad.
## (Los perros y los gatos, que antes daban saltitos acá, ahora son world/animal.gd.)

@export_enum("girar", "hamacar", "subibaja") var tipo := "girar"
@export var velocidad := 1.0
@export var amplitud := 0.5
## Lugares para subirse: [Transform3D del asiento en el espacio de la pieza (el origen es donde se
## apoya el chico y mira hacia -Z), Vector3 donde pararse para subir (en el mundo)].
var asientos: Array = []

var _quien: Array = []          ## Quién reservó cada asiento (o null)
var _arriba: Array[bool] = []
var _t := 0.0
var _amp := 0.0
var _giro := 0.0


func _ready() -> void:
	if tipo == "subibaja":
		rotation.z = -amplitud


func _asegurar() -> void:
	while _quien.size() < asientos.size():
		_quien.append(null)
		_arriba.append(false)


## Un asiento libre (sin reservar) o -1.
func lugar_libre() -> int:
	_asegurar()
	for i in asientos.size():
		if _quien[i] == null or not is_instance_valid(_quien[i]):
			return i
	return -1


func reservar(i: int, quien: Node) -> void:
	_asegurar()
	_quien[i] = quien
	_arriba[i] = false


func subir(i: int) -> void:
	_asegurar()
	_arriba[i] = true


func soltar(i: int) -> void:
	_asegurar()
	_quien[i] = null
	_arriba[i] = false


## Cuántos hay arriba.
func ocupados() -> int:
	_asegurar()
	var n := 0
	for i in _arriba.size():
		if _arriba[i] and is_instance_valid(_quien[i]):
			n += 1
	return n


## ¿Hay alguien que reservó y todavía no se subió? (al subibaja se lo espera)
func alguien_esperando() -> bool:
	return ocupados() == 1


func asiento_global(i: int) -> Transform3D:
	return global_transform * (asientos[i][0] as Transform3D)


func entrada(i: int) -> Vector3:
	return asientos[i][1]


func _process(delta: float) -> void:
	var n := ocupados()
	match tipo:
		"girar":
			_giro = move_toward(_giro, velocidad if n > 0 else 0.0, delta * 0.15)
			rotation.y += delta * _giro
		"hamacar":
			_amp = move_toward(_amp, amplitud if n > 0 else 0.0, delta * (0.1 if n > 0 else 0.06))
			if _amp > 0.0:
				_t += delta * velocidad
			else:
				_t = 0.0
			rotation.x = sin(_t) * _amp
		"subibaja":
			var objetivo := -amplitud
			if n >= 2:
				_t += delta * velocidad
				objetivo = sin(_t) * amplitud
			elif n == 1:
				# Con uno solo, baja su punta
				for i in asientos.size():
					if _arriba[i]:
						objetivo = -signf((asientos[i][0] as Transform3D).origin.x) * amplitud
			rotation.z = move_toward(rotation.z, objetivo, delta * 0.9)
