class_name CatalogoDialogos
extends RefCounted
## Todo lo que se puede decir en el juego, en un solo lugar (datos, sin lógica). Para sumar un NPC
## con el que se pueda hablar (humano, gato, perro, otra paloma...):
##   1) Agregarlo a PERSONAJES (nombre, especie y qué diálogo le toca según cómo viene la partida).
##   2) Escribir sus diálogos en DIALOGOS.
##   3) Marcarlo en la escena con Interlocutor.marcar(nodo, "id_del_personaje") (o agregando el nodo
##      Interlocutor a mano). Sólo los NPC marcados así se pueden hablar; los demás ni se enteran.
##   4) Si da misiones, definirlas en CatalogoMisiones.
## Los textos van en español (son la clave de traducción: sumar el par en TextosEN.MAPA).
##
## PERSONAJES[id] = {nombre, especie, dialogos: [{si: condición(es), dialogo: id}, ...]}
##   Se usa el PRIMER dialogo cuya condición se cumple (el último suele no tener "si": el saludo).
## DIALOGOS[id] = {inicio: nodo, nodos: {nodo: {...}}}. Un nodo tiene:
##   quien   (opcional) quién habla; por defecto el nombre del personaje
##   texto   lo que dice
##   hace    (opcional) acciones al llegar a este nodo
##   opciones (opcional) [{texto, va, si?, hace?}]; "va" "" = termina. Sin opciones se sigue con
##   va      (opcional) el nodo que sigue al apretar E o click; "" o ausente = termina
## Condiciones ("si", una o varias = todas) y acciones ("hace"): ver ReglasDialogo.

const PERSONAJES := {
	"dona_rosa": {
		"nombre": "Doña Rosa",
		"especie": "humano",
		"dialogos": [
			{"si": "mision:migas_rosa:lista", "dialogo": "rosa_entrega"},
			{"si": "mision:migas_rosa:activa", "dialogo": "rosa_recordatorio"},
			{"si": "mision:migas_rosa:completada", "dialogo": "rosa_despues"},
			{"dialogo": "rosa_saludo"},
		],
	},
}

const DIALOGOS := {
	"rosa_saludo": {
		"inicio": "inicio",
		"nodos": {
			"inicio": {
				"texto": "¡Hola, paloma! Qué flaquita estás... Comé tranquila, que hoy hay para todas.",
				"opciones": [
					{"texto": "¿Necesitás algo, Doña Rosa?", "va": "pedido",
						"si": ["tutorial", "mision:migas_rosa:nueva"]},
					{"texto": "Gracias, ¡chau!", "va": ""},
				],
			},
			"pedido": {
				"texto": "Ay, sí. Los chicos me dejaron migas por todo el Cabildo. ¿Me ayudás a comer cinco?",
				"opciones": [
					{"texto": "¡Dale!", "va": "gracias", "hace": "mision_aceptar:migas_rosa"},
					{"texto": "Ahora no puedo", "va": ""},
				],
			},
			"gracias": {"texto": "¡Qué buena paloma! Vení a verme cuando termines."},
		},
	},
	"rosa_recordatorio": {
		"inicio": "inicio",
		"nodos": {"inicio": {"texto": "¿Cómo van esas migas? Cinco, acordate. ¡Y no te las lleves a la calle!"}},
	},
	"rosa_entrega": {
		"inicio": "inicio",
		"nodos": {"inicio": {
			"texto": "¡Mirá cómo quedó la vereda! Tomá, un poquito más de comida por la ayuda.",
			"hace": "mision_entregar:migas_rosa",
		}},
	},
	"rosa_despues": {
		"inicio": "inicio",
		"nodos": {"inicio": {"texto": "Siempre sos bienvenida en el Cabildo, paloma."}},
	},
}


static func personaje(id: String) -> Dictionary:
	return PERSONAJES.get(id, {})


static func dialogo(id: String) -> Dictionary:
	return DIALOGOS.get(id, {})


static func nombre(id: String) -> String:
	return String(personaje(id).get("nombre", id))


## Id del diálogo que le toca hoy a este personaje ("" si no tiene ninguno).
static func elegir(id_personaje: String) -> String:
	for entrada: Dictionary in personaje(id_personaje).get("dialogos", []):
		if ReglasDialogo.cumple(entrada.get("si", [])):
			return String(entrada.get("dialogo", ""))
	return ""
