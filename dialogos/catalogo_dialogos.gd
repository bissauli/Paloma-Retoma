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

## "presentacion" (opcional): la tarjeta que se muestra la primera vez que se habla con el personaje
## (ver PresentacionPersonaje): {nombre, datos: [líneas], modelo: {tipo, rol}, color: de las letras, fondo}.
## Lo que dice el personaje no va en la tarjeta: viene después, en su diálogo.
## "modelo" acepta {tipo: "badjoke", rol} (una paloma de la banda) o {tipo: "animal", variante, escala?}.
## Regla del proyecto: todo personaje importante de la historia lleva presentación (Doña Rosa no).
const PERSONAJES := {
	"don_remate": {
		"nombre": "Don Remate",
		"especie": "paloma",
		"presentacion": {
			"nombre": "Don Remate",
			"datos": ["Edad: 47 / 47 años de calle", "Rol: Líder de los BadJokes / Chamuyero",
				"Especialidad: Cobrar migas y contar chistes malos"],
			"modelo": {"tipo": "badjoke", "rol": "jefe"},
			"color": Color("ffd84a"),
			"fondo": Color(0.22, 0.04, 0.3),
		},
		"dialogos": [
			{"si": "!bandera:remate_hablado", "dialogo": "remate_primera"},
			{"dialogo": "remate_saludo"},
		],
	},
	"tio_ruffus": {
		"nombre": "Tío Ruffus",
		"especie": "perro",
		"presentacion": {
			"nombre": "Tío Ruffus",
			"datos": ["Edad: 14 años / 98 en años de perro", "Rol: Abuelo de la plaza / Vigía del Cabildo",
				"Especialidad: Dormir al sol y oler asado a diez cuadras"],
			"modelo": {"tipo": "animal", "variante": "perro_blanco"},
			"color": Color("ffcf8a"),
			"fondo": Color(0.3, 0.15, 0.04),
		},
		"dialogos": [
			{"si": ["mision:asado_ruffus:lista", "carga:asado"], "dialogo": "ruffus_entrega"},
			{"si": "mision:asado_ruffus:lista", "dialogo": "ruffus_sin_asado"},
			{"si": "mision:asado_ruffus:activa", "dialogo": "ruffus_recordatorio"},
			{"si": "mision:asado_ruffus:completada", "dialogo": "ruffus_despues"},
			{"si": "!bandera:ruffus_hablado", "dialogo": "ruffus_primera"},
			{"dialogo": "ruffus_saludo"},
		],
	},
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
	# La primera vez con Tío Ruffus (después de la presentación): se presenta y sigue como siempre
	"ruffus_primera": {
		"inicio": "hola",
		"nodos": {
			"hola": {
				"texto": "¡Guau! Ay, mis huesos... Hola, palomita. Soy Tío Ruffus, el más viejo de la plaza.",
				"hace": "bandera:ruffus_hablado",
				"va": "inicio",
			},
			"inicio": {
				"texto": "Yo antes les corría a las palomas, ¿sabías? Ahora apenas me alcanzan las ganas.",
				"opciones": [
					{"texto": "¿Necesitás algo, Tío Ruffus?", "va": "pedido",
						"si": ["tutorial", "mision:asado_ruffus:nueva"]},
					{"texto": "Chau, Tío Ruffus", "va": ""},
				],
			},
			"pedido": {
				"texto": "Hace días que me llega olor a asado desde la parrilla del Obelisco, y con estas patitas no llego ni a la esquina. ¿Me traés un buen pedazo? Es pesado: lo tenés que llevar en el pico.",
				"opciones": [
					{"texto": "¡Dejalo en mis alas!", "va": "gracias", "hace": "mision_aceptar:asado_ruffus"},
					{"texto": "Ahora no puedo", "va": ""},
				],
			},
			"gracias": {"texto": "¡Qué buena paloma! La parrilla está cerca del Obelisco, en el medio de la plaza. Yo te espero acá... haciéndome el dormido."},
		},
	},
	# La primera vez (después de la presentación): arranca con el saludo y sigue como siempre
	"remate_primera": {
		"inicio": "hola",
		"nodos": {
			"hola": {
				"texto": "¿Así que vos sos la paloma nueva del barrio?",
				"hace": "bandera:remate_hablado",
				"va": "inicio",
			},
			"inicio": {
				"texto": "Mirá vos, una paloma de la plaza cruzando la frontera. Acá las migas tienen dueño, ¿sabés? Y el dueño soy yo.",
				"opciones": [
					{"texto": "Sólo estoy de paso, Don Remate.", "va": "paso"},
					{"texto": "¿Y vos quién te creés que sos?", "va": "chiste"},
					{"texto": "Me voy, me voy...", "va": ""},
				],
			},
			"paso": {
				"texto": "De paso, dice. Qué linda costumbre. Bueno, mirá: si querés andar tranquila por el barrio, vas a tener que ganarte el respeto. Pasá más tarde, que se me están ocurriendo ideas.",
			},
			"chiste": {
				"texto": "¿Que quién soy? Soy el que se ríe último. ¿Querés escuchar un chiste? ¿Por qué la paloma cruzó la calle? ¡Para no pagar el peaje de las migas! Jajaja... ¿No? Bueno, ya te vas a reír.",
			},
		},
	},
	"remate_saludo": {
		"inicio": "inicio",
		"nodos": {
			"inicio": {
				"texto": "Mirá vos, una paloma de la plaza cruzando la frontera. Acá las migas tienen dueño, ¿sabés? Y el dueño soy yo.",
				"opciones": [
					{"texto": "Sólo estoy de paso, Don Remate.", "va": "paso"},
					{"texto": "¿Y vos quién te creés que sos?", "va": "chiste"},
					{"texto": "Me voy, me voy...", "va": ""},
				],
			},
			"paso": {
				"texto": "De paso, dice. Qué linda costumbre. Bueno, mirá: si querés andar tranquila por el barrio, vas a tener que ganarte el respeto. Pasá más tarde, que se me están ocurriendo ideas.",
			},
			"chiste": {
				"texto": "¿Que quién soy? Soy el que se ríe último. ¿Querés escuchar un chiste? ¿Por qué la paloma cruzó la calle? ¡Para no pagar el peaje de las migas! Jajaja... ¿No? Bueno, ya te vas a reír.",
			},
		},
	},
	"ruffus_saludo": {
		"inicio": "inicio",
		"nodos": {
			"inicio": {
				"texto": "Guau... ay, mis huesos. Hola, palomita. Yo antes les corría a las palomas, ¿sabías? Ahora apenas me alcanzan las ganas.",
				"opciones": [
					{"texto": "¿Necesitás algo, Tío Ruffus?", "va": "pedido",
						"si": ["tutorial", "mision:asado_ruffus:nueva"]},
					{"texto": "Chau, Tío Ruffus", "va": ""},
				],
			},
			"pedido": {
				"texto": "Hace días que me llega olor a asado desde la parrilla del Obelisco, y con estas patitas no llego ni a la esquina. ¿Me traés un buen pedazo? Es pesado: lo tenés que llevar en el pico.",
				"opciones": [
					{"texto": "¡Dejalo en mis alas!", "va": "gracias", "hace": "mision_aceptar:asado_ruffus"},
					{"texto": "Ahora no puedo", "va": ""},
				],
			},
			"gracias": {"texto": "¡Qué buena paloma! La parrilla está cerca del Obelisco, en el medio de la plaza. Yo te espero acá... haciéndome el dormido."},
		},
	},
	"ruffus_recordatorio": {
		"inicio": "inicio",
		"nodos": {"inicio": {"texto": "Todavía siento el olorcito desde acá... La parrilla está cerca del Obelisco, en el centro de la plaza."}},
	},
	"ruffus_sin_asado": {
		"inicio": "inicio",
		"nodos": {"inicio": {"texto": "¿Y el asado? Se te debe haber perdido por el camino... Fijate en la parrilla del Obelisco, que siempre queda otro pedazo."}},
	},
	"ruffus_entrega": {
		"inicio": "inicio",
		"nodos": {"inicio": {
			"texto": "¡Mi asado! Mmm... qué manjar. Hacía años que no probaba algo así. Tomá, un poco de comida por las molestias.",
			"hace": ["carga_quitar", "mision_entregar:asado_ruffus"],
		}},
	},
	"ruffus_despues": {
		"inicio": "inicio",
		"nodos": {"inicio": {"texto": "Todavía se me hace agua la boca con ese asado. Sos la mejor amiga que un perro viejo puede tener."}},
	},
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
