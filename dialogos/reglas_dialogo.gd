class_name ReglasDialogo
extends RefCounted
## Las condiciones ("si") y acciones ("hace") que pueden usar los diálogos y las misiones, escritas
## como texto para que los datos sean simples. Un solo lugar: para sumar una regla nueva se toca
## sólo este archivo.
##
## Condiciones (con "!" adelante se niegan; una lista = todas se cumplen):
##   "mision:ID:ESTADO"   ESTADO = nueva | activa | lista | completada
##   "bandera:NOMBRE"     una bandera puesta antes (Misiones.poner_bandera)
##   "tutorial"           ya terminó el tutorial de las migas
##   "comida>=N"  "bandada>=N"  "migas>=N"   (también <=, >, <, ==)
## Acciones:
##   "mision_aceptar:ID"  "mision_entregar:ID"  "bandera:NOMBRE"
##   "comida+N"  "comida-N"  "evento:CLAVE" (avisa a las misiones, ver Misiones.notificar)

const OPERADORES := [">=", "<=", "==", ">", "<"]


static func cumple(condicion: Variant) -> bool:
	if condicion is Array:
		for c in condicion:
			if not cumple(c):
				return false
		return true
	var texto := String(condicion).strip_edges()
	if texto == "":
		return true
	var negar := texto.begins_with("!")
	if negar:
		texto = texto.substr(1)
	return _evaluar(texto) != negar


static func _evaluar(c: String) -> bool:
	if c == "tutorial":
		return GameState.tutorial_hecho
	if c.begins_with("mision:"):
		var p := c.split(":")
		return p.size() == 3 and Misiones.estado(p[1]) == p[2]
	if c.begins_with("bandera:"):
		return Misiones.bandera(c.substr(8))
	for op: String in OPERADORES:
		var i := c.find(op)
		if i > 0:
			return _comparar(_valor(c.substr(0, i)), op, int(c.substr(i + op.length())))
	push_warning("ReglasDialogo: condición desconocida '%s'" % c)
	return false


static func _valor(nombre: String) -> int:
	match nombre.strip_edges():
		"comida": return GameState.comida
		"bandada": return GameState.bandada
		"migas": return GameState.migas_comidas
	push_warning("ReglasDialogo: valor desconocido '%s'" % nombre)
	return 0


static func _comparar(a: int, op: String, b: int) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		"==": return a == b
		">": return a > b
		_: return a < b


## Ejecuta una acción (o una lista de acciones).
static func hacer(accion: Variant) -> void:
	if accion is Array:
		for a in accion:
			hacer(a)
		return
	var texto := String(accion).strip_edges()
	if texto == "":
		return
	if texto.begins_with("mision_aceptar:"):
		Misiones.aceptar(texto.get_slice(":", 1))
	elif texto.begins_with("mision_entregar:"):
		Misiones.entregar(texto.get_slice(":", 1))
	elif texto.begins_with("bandera:"):
		Misiones.poner_bandera(texto.substr(8))
	elif texto.begins_with("evento:"):
		Misiones.notificar(texto.substr(7))
	elif texto.begins_with("comida+") or texto.begins_with("comida-"):
		GameState.sumar_comida(int(texto.substr(6)))
	else:
		push_warning("ReglasDialogo: acción desconocida '%s'" % texto)
