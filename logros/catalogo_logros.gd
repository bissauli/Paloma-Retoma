class_name CatalogoLogros
extends RefCounted
## Los logros y trofeos (datos, sin lógica; la lógica está en el autoload Logros).
## - Logro: algo que se consigue al hacer cosas del juego (comer una miga, volar, reclutar...).
## - Trofeo: una hazaña (terminar el juego, no ser atrapada, todas las misiones secundarias...),
##   con nivel (bronce, plata, oro o platino).
## Cada uno: {id, tipo, nombre, desc, nivel (sólo trofeos)}. Si tiene "stat" (contador que lleva el
## autoload) se desbloquea solo al llegar a "meta" y se muestra su avance; "unidad" y "barra" son
## sólo de presentación. Sin "stat" lo desbloquea el autoload directamente (Logros.desbloquear).
## Los textos están en español y se traducen con tr() (textos_en.gd).

const LOGRO := "logro"
const TROFEO := "trofeo"

const COLOR_NIVEL := {
	"bronce": Color("d9884a"),
	"plata": Color("cfd8e0"),
	"oro": Color("ffc83d"),
	"platino": Color("7fe3ff"),
}
const COLOR_LOGRO := Color("63d4e8")

const LISTA := [
	# ---------------------------------------------------------------- Trofeos
	{"id": "fin_juego", "tipo": TROFEO, "nivel": "oro", "nombre": "¡La plaza es nuestra!",
		"desc": "Terminá el juego."},
	{"id": "intocable", "tipo": TROFEO, "nivel": "oro", "nombre": "Intocable",
		"desc": "Terminá el juego sin que te atrape el halcón, un granadero ni el nene."},
	{"id": "misiones_todas", "tipo": TROFEO, "nivel": "plata", "nombre": "Vecina del año",
		"desc": "Completá todas las misiones secundarias."},
	{"id": "velocista", "tipo": TROFEO, "nivel": "plata", "nombre": "Vuelo directo",
		"desc": "Terminá el juego en menos de 10 minutos."},
	{"id": "nube", "tipo": TROFEO, "nivel": "plata", "nombre": "Nube de alas",
		"desc": "Juntá una bandada con el máximo de palomas.", "stat": "bandada_max", "meta": Config.BANDADA_MAX},
	{"id": "rey_baile", "tipo": TROFEO, "nivel": "bronce", "nombre": "Reina del baile",
		"desc": "Bailá todos los bailes de la rueda."},
	{"id": "miguera", "tipo": TROFEO, "nivel": "bronce", "nombre": "Reina de las migas",
		"desc": "Comé 300 migas.", "stat": "migas", "meta": 300},
	{"id": "casamentera", "tipo": TROFEO, "nivel": "bronce", "nombre": "Casamentera",
		"desc": "Enamorá a 10 palomas con el baile de cortejo.", "stat": "cortejadas", "meta": 10},
	{"id": "spa", "tipo": TROFEO, "nivel": "bronce", "nombre": "Spa de palomas",
		"desc": "Date 10 baños en fuentes y charcos.", "stat": "banos", "meta": 10},
	{"id": "gamberra", "tipo": TROFEO, "nivel": "bronce", "nombre": "Pequeña gamberra",
		"desc": "Tirá 100 cosas de un aletazo.", "stat": "golpes", "meta": 100},
	{"id": "camaleon", "tipo": TROFEO, "nivel": "bronce", "nombre": "Camaleón",
		"desc": "Usá los 6 colores, los 4 accesorios y una pintura a la vez en tu paloma."},
	{"id": "leyenda", "tipo": TROFEO, "nivel": "platino", "nombre": "Paloma de leyenda",
		"desc": "Conseguí todos los demás logros y trofeos."},

	# ---------------------------------------------------------------- Logros
	{"id": "primer_bocado", "tipo": LOGRO, "nombre": "Primer bocado", "desc": "Comé una miga.",
		"stat": "migas", "meta": 1},
	{"id": "picoteadora", "tipo": LOGRO, "nombre": "Picoteadora", "desc": "Picoteá 50 veces.",
		"stat": "picoteos", "meta": 50},
	{"id": "cantora", "tipo": LOGRO, "nombre": "Cantora", "desc": "Arrullá 25 veces.",
		"stat": "arrullos", "meta": 25},
	{"id": "despegue", "tipo": LOGRO, "nombre": "¡Despegue!", "desc": "Levantá vuelo por primera vez.",
		"stat": "despegues", "meta": 1},
	{"id": "aviadora", "tipo": LOGRO, "nombre": "Aviadora", "desc": "Pasá 2 minutos en el aire.",
		"stat": "tiempo_vuelo", "meta": 120, "unidad": "s"},
	{"id": "clavadista", "tipo": LOGRO, "nombre": "Clavadista", "desc": "Hacé 10 picadas.",
		"stat": "picadas", "meta": 10},
	{"id": "primera_amiga", "tipo": LOGRO, "nombre": "Primera amiga", "desc": "Reclutá a tu primera paloma.",
		"stat": "reclutadas", "meta": 1},
	{"id": "pandilla", "tipo": LOGRO, "nombre": "Pandilla", "desc": "Juntá 5 palomas.",
		"stat": "bandada_max", "meta": 5},
	{"id": "bandada", "tipo": LOGRO, "nombre": "Bandada", "desc": "Juntá 15 palomas.",
		"stat": "bandada_max", "meta": 15},
	{"id": "multitud", "tipo": LOGRO, "nombre": "Multitud", "desc": "Juntá 30 palomas.",
		"stat": "bandada_max", "meta": 30},
	{"id": "repartidora", "tipo": LOGRO, "nombre": "Repartidora", "desc": "Llevá comida al nido.",
		"stat": "entregas", "meta": 1},
	{"id": "choripanera", "tipo": LOGRO, "nombre": "Choripanera", "desc": "Levantá el choripán de la avenida.",
		"stat": "choripanes", "meta": 1},
	{"id": "primer_baile", "tipo": LOGRO, "nombre": "A mover las plumas", "desc": "Bailá con la rueda de bailes.",
		"stat": "bailes", "meta": 1},
	{"id": "buena_vecina", "tipo": LOGRO, "nombre": "Buena vecina", "desc": "Completá una misión secundaria.",
		"stat": "misiones", "meta": 1},
	{"id": "primer_susto", "tipo": LOGRO, "nombre": "Primer susto", "desc": "Que te atrape un enemigo. Les pasa hasta a las mejores.",
		"stat": "atrapadas", "meta": 1},
	{"id": "atardecer", "tipo": LOGRO, "nombre": "Hasta el atardecer", "desc": "Llegá al atardecer en una partida.",
		"stat": "dia", "meta": 90, "barra": false},
	{"id": "plaf", "tipo": LOGRO, "nombre": "¡Plaf!", "desc": "Golpeá algo con un aletazo (F, o ALETAZO en el teléfono).",
		"stat": "golpes", "meta": 1},
	{"id": "sombrerazo", "tipo": LOGRO, "nombre": "Sombrerazo", "desc": "Tirale el sombrero a alguien de un aletazo.",
		"stat": "sombreros", "meta": 1},
	{"id": "rompecorazones", "tipo": LOGRO, "nombre": "Rompecorazones",
		"desc": "Enamorá a una paloma suelta con el baile de cortejo.", "stat": "cortejadas", "meta": 1},
	{"id": "remojon", "tipo": LOGRO, "nombre": "Remojón",
		"desc": "Date un baño en una fuente o en un charco.", "stat": "banos", "meta": 1},
	{"id": "con_estilo", "tipo": LOGRO, "nombre": "Con estilo", "desc": "Personalizá tu paloma."},
	{"id": "artista", "tipo": LOGRO, "nombre": "Artista", "desc": "Pintá tu paloma en el modo avanzado."},
]

static var _indice := {}
static var _por_stat := {}


static func _armar_indices() -> void:
	if not _indice.is_empty():
		return
	for d: Dictionary in LISTA:
		_indice[d["id"]] = d
		if d.has("stat"):
			var l: Array = _por_stat.get(d["stat"], [])
			l.append(d)
			_por_stat[d["stat"]] = l


static func por_id(id: String) -> Dictionary:
	_armar_indices()
	return _indice.get(id, {})


## Todos los del tipo "logro" o "trofeo", en el orden de LISTA.
static func de_tipo(tipo: String) -> Array:
	var l: Array = []
	for d: Dictionary in LISTA:
		if d["tipo"] == tipo:
			l.append(d)
	return l


## Los que se desbloquean al llegar a la meta de un contador.
static func con_stat(clave: String) -> Array:
	_armar_indices()
	return _por_stat.get(clave, [])


static func color_de(d: Dictionary) -> Color:
	if d["tipo"] == TROFEO:
		return COLOR_NIVEL.get(d.get("nivel", "bronce"), COLOR_NIVEL["bronce"])
	return COLOR_LOGRO
