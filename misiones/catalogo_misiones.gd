class_name CatalogoMisiones
extends RefCounted
## Las misiones secundarias (datos, sin lógica; la lógica está en el autoload Misiones).
## MISIONES[id] = {
##   titulo, resumen     lo que se lee en el diario de misiones
##   dador               id del personaje que la da (el que muestra el "!" hasta que se acepta)
##   entrega             id del personaje a quien se vuelve para cobrar (opcional: sin esto se
##                       completa sola al cumplir los objetivos)
##   requiere            condiciones para que esté disponible (ver ReglasDialogo), opcional
##   objetivos           [{tipo, texto, meta, clave?}]
##       tipo "evento":  cuenta las veces que el juego avisa Misiones.notificar(clave) desde que
##                       se aceptó (ej. "miga" cada vez que se come una miga)
##       tipo "bandada": se cumple mientras la bandada tenga "meta" palomas o más
##   destino             grupo del mundo al que apunta la brújula mientras está activa (opcional;
##                       al estar lista apunta al personaje de "entrega")
##   recompensa          {comida: N}
## }

const MISIONES := {
	"migas_rosa": {
		"titulo": "Migas para Doña Rosa",
		"resumen": "Doña Rosa quiere la vereda del Cabildo limpia: comé cinco migas.",
		"dador": "dona_rosa",
		"entrega": "dona_rosa",
		"requiere": ["tutorial"],
		"objetivos": [{"tipo": "evento", "clave": "miga", "meta": 5, "texto": "Comer migas"}],
		"destino": "dona_rosa",
		"recompensa": {"comida": 2},
	},
}


static func mision(id: String) -> Dictionary:
	return MISIONES.get(id, {})
