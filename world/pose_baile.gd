class_name PoseBaile
extends RefCounted
## Una pose de baile de la paloma: dónde está el cuerpo (posición y giro de todo el modelo, alrededor
## del centro del cuerpo) y cuánto se gira cada hueso. Los giros de los huesos están en el espacio
## del modelo (X = izquierda de la paloma, Y = arriba, Z = hacia donde mira), no en el de cada hueso:
## así "levantar el ala" es siempre lo mismo. Ver Coreografia, que arma las poses, y
## Bailarina, que las aplica al esqueleto.
##
## Convención de ejes (comprobada con tests/captura_bailes.tscn):
##   ala izquierda  = _ala_izq(abrir, subir): abrir la separa del cuerpo, subir la levanta
##   pata adelante  = giro negativo en X;  cabeza que asiente = giro positivo en X
##   cola que sube  = giro positivo en X;  cola que se mueve de costado = giro en Y

var pos := Vector3.ZERO              ## Desplazamiento del cuerpo (metros): y positivo = en el aire
var rot := Basis.IDENTITY            ## Giro de todo el modelo alrededor del centro del cuerpo
var cuerpo := Basis.IDENTITY
var cabeza := Basis.IDENTITY
var cola := Basis.IDENTITY
var ala_izq := Basis.IDENTITY
var ala_der := Basis.IDENTITY
var pata_izq := Basis.IDENTITY
var pata_der := Basis.IDENTITY


## Mezcla esta pose con otra: w = 0 es esta y w = 1 es la otra (para pasar de un tramo del baile a otro).
func mezclar(otra: PoseBaile, w: float) -> PoseBaile:
	var p := PoseBaile.new()
	p.pos = pos.lerp(otra.pos, w)
	p.rot = _mezclar_giro(rot, otra.rot, w)
	p.cuerpo = _mezclar_giro(cuerpo, otra.cuerpo, w)
	p.cabeza = _mezclar_giro(cabeza, otra.cabeza, w)
	p.cola = _mezclar_giro(cola, otra.cola, w)
	p.ala_izq = _mezclar_giro(ala_izq, otra.ala_izq, w)
	p.ala_der = _mezclar_giro(ala_der, otra.ala_der, w)
	p.pata_izq = _mezclar_giro(pata_izq, otra.pata_izq, w)
	p.pata_der = _mezclar_giro(pata_der, otra.pata_der, w)
	return p


static func _mezclar_giro(a: Basis, b: Basis, w: float) -> Basis:
	return Basis(a.get_rotation_quaternion().slerp(b.get_rotation_quaternion(), w))


## Los giros de cada hueso por nombre (como están en el esqueleto del GLB).
func giros_de_huesos() -> Dictionary:
	return {
		&"body": cuerpo, &"head": cabeza, &"tail": cola,
		&"wing_L": ala_izq, &"wing_R": ala_der, &"leg_L": pata_izq, &"leg_R": pata_der,
	}
