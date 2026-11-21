class_name SuperficiesSonido
extends RefCounted
## Dice si un golpe fue contra algo metálico. Las colisiones del mapa se agrupan por zonas y no
## saben de qué pieza vienen, así que la ciudad anota acá dónde puso cada pieza de metal (faroles,
## semáforos, postes, rejas, vallas, carteleras...) y al chocar se mira si hay una cerca del golpe.

const PREFIJOS_METAL := ["farol", "farola", "semaforo", "poste", "reja", "valla", "cartel", "hidrante",
	"contenedor", "parada_colectivo", "caja_electrica", "aro_basquet", "tacho", "cesto", "buzon",
	"bici", "cerco", "pilote", "subibaja", "hamaca", "tobogan", "resorte", "tendedero"]
const CELDA := 3.0
const RADIO := 2.2

static var _celdas := {}     ## Vector2i -> Array[Vector3]


static func reiniciar() -> void:
	_celdas.clear()


static func es_metal(pieza: String) -> bool:
	for p in PREFIJOS_METAL:
		if pieza.begins_with(p):
			return true
	return false


## La ciudad llama a esto por cada pieza que pone.
static func registrar(pieza: String, pos: Vector3) -> void:
	if not es_metal(pieza):
		return
	var c := Vector2i(floori(pos.x / CELDA), floori(pos.z / CELDA))
	if not _celdas.has(c):
		_celdas[c] = []
	(_celdas[c] as Array).append(pos)


## ¿Hay una pieza de metal pegada al punto de un golpe?
static func hay_metal_cerca(punto: Vector3) -> bool:
	var c := Vector2i(floori(punto.x / CELDA), floori(punto.z / CELDA))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var l: Array = _celdas.get(Vector2i(c.x + dx, c.y + dz), [])
			for p: Vector3 in l:
				if Vector2(p.x - punto.x, p.z - punto.z).length() <= RADIO and punto.y >= p.y - 0.5:
					return true
	return false
