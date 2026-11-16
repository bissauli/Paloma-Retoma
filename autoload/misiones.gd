extends Node
## Misiones secundarias (autoload "Misiones"): qué misiones hay aceptadas, su avance y las banderas
## que dejan los diálogos. Los datos de cada misión están en misiones/catalogo_misiones.gd.
## Estados: nueva (todavía no la aceptó) -> activa -> lista (objetivos cumplidos, falta volver con
## quien la dio) -> completada (cobró la recompensa). Sin "entrega" pasa directo de activa a completada.
## Se guarda con la partida (GameState.guardar_partida) y la brújula marca a dónde ir.

signal mision_cambio(id: String, estado: String)
signal progreso_cambio(id: String, indice: int)   ## indice: el objetivo que avanzó

const NUEVA := "nueva"
const ACTIVA := "activa"
const LISTA := "lista"
const COMPLETADA := "completada"

var _misiones := {}      ## id -> {estado: String, progreso: Array[int]}   (sólo las que ya se aceptaron)
var _banderas := {}      ## nombre -> true
var _aviso: AvisoMision
var _aceptada_ms := {}   ## id -> cuándo se aceptó (el primer "avance" de una bandada ya cumplida no avisa)


func _ready() -> void:
	GameState.bandada_cambio.connect(func(_n: int) -> void: _revisar_estado_bandada())
	_aviso = AvisoMision.new()
	add_child(_aviso)
	mision_cambio.connect(_avisar_estado)
	progreso_cambio.connect(_avisar_progreso)


# ---------------------------------------------------------------- Consultas

func estado(id: String) -> String:
	return String(_misiones.get(id, {}).get("estado", NUEVA))


func bandera(nombre: String) -> bool:
	return _banderas.has(nombre)


func poner_bandera(nombre: String) -> void:
	_banderas[nombre] = true


## Avance de la misión: [{texto, actual, meta}] (para el diario de misiones).
func objetivos(id: String) -> Array:
	var resultado: Array = []
	var datos: Array = CatalogoMisiones.mision(id).get("objetivos", [])
	var progreso: Array = _misiones.get(id, {}).get("progreso", [])
	for i in datos.size():
		var meta := int(datos[i].get("meta", 1))
		resultado.append({"texto": datos[i].get("texto", ""), "meta": meta,
			"actual": mini(int(progreso[i]) if i < progreso.size() else 0, meta)})
	return resultado


## Ids de las misiones aceptadas que todavía no se completaron (el diario de misiones).
func en_curso() -> Array:
	var ids: Array = []
	for id: String in _misiones:
		if estado(id) == ACTIVA or estado(id) == LISTA:
			ids.append(id)
	return ids


## Ids de las misiones ya completadas.
func completadas() -> Array:
	var ids: Array = []
	for id: String in _misiones:
		if estado(id) == COMPLETADA:
			ids.append(id)
	return ids


## ¿La misión se puede aceptar ahora? (no empezada y con sus requisitos cumplidos)
func disponible(id: String) -> bool:
	return estado(id) == NUEVA and CatalogoMisiones.MISIONES.has(id) \
		and ReglasDialogo.cumple(CatalogoMisiones.mision(id).get("requiere", []))


## Lo que se dibuja sobre la cabeza de un personaje: "!" si tiene una misión para dar, "?" si hay una
## para entregarle, "..." si tiene una en curso, "" si nada.
func marcador(personaje: String) -> String:
	var hay_en_curso := false
	for id: String in CatalogoMisiones.MISIONES:
		var m := CatalogoMisiones.mision(id)
		match estado(id):
			LISTA:
				if m.get("entrega", m.get("dador", "")) == personaje:
					return "?"
			ACTIVA:
				if m.get("entrega", m.get("dador", "")) == personaje:
					hay_en_curso = true
	for id: String in CatalogoMisiones.MISIONES:
		if CatalogoMisiones.mision(id).get("dador", "") == personaje and disponible(id):
			return "!"
	return "..." if hay_en_curso else ""


## A dónde apunta la brújula por las misiones en curso (se suma a los destinos de GameState).
func destinos() -> Array:
	var lista: Array = []
	for id: String in en_curso():
		var m := CatalogoMisiones.mision(id)
		var grupo := ""
		if estado(id) == LISTA:
			grupo = "npc_" + String(m.get("entrega", m.get("dador", "")))
		else:
			grupo = String(m.get("destino", ""))
		if grupo != "":
			lista.append({"grupo": StringName(grupo), "nombre": m.get("titulo", ""), "principal": false})
	return lista


# ---------------------------------------------------------------- Cambios

func aceptar(id: String) -> bool:
	if not disponible(id):
		return false
	var cantidad: int = CatalogoMisiones.mision(id).get("objetivos", []).size()
	var ceros: Array = []
	ceros.resize(cantidad)
	ceros.fill(0)
	_misiones[id] = {"estado": ACTIVA, "progreso": ceros}
	_aceptada_ms[id] = Time.get_ticks_msec()
	mision_cambio.emit(id, ACTIVA)
	_revisar_estado_bandada()
	_revisar(id)
	GameState.actualizar_objetivo()
	return true


## El juego avisa que pasó algo ("miga", "hablar:gato_manchas"...): suma a los objetivos de tipo
## "evento" con esa clave de todas las misiones activas.
func notificar(clave: String, cantidad := 1) -> void:
	for id: String in _misiones:
		if estado(id) != ACTIVA:
			continue
		var datos: Array = CatalogoMisiones.mision(id).get("objetivos", [])
		var progreso: Array = _misiones[id]["progreso"]
		var cambio := false
		for i in datos.size():
			if datos[i].get("tipo", "") == "evento" and datos[i].get("clave", "") == clave:
				progreso[i] = int(progreso[i]) + cantidad
				cambio = true
				progreso_cambio.emit(id, i)
		if cambio:
			_revisar(id)


## Cobra la recompensa de una misión lista. Devuelve false si no estaba lista.
func entregar(id: String) -> bool:
	if estado(id) != LISTA:
		return false
	_completar(id)
	return true


func _revisar_estado_bandada() -> void:
	for id: String in _misiones:
		if estado(id) != ACTIVA:
			continue
		var datos: Array = CatalogoMisiones.mision(id).get("objetivos", [])
		var progreso: Array = _misiones[id]["progreso"]
		var cambio := false
		for i in datos.size():
			if datos[i].get("tipo", "") == "bandada" and int(progreso[i]) != GameState.bandada:
				progreso[i] = GameState.bandada
				cambio = true
				progreso_cambio.emit(id, i)
		if cambio:
			_revisar(id)


## Si ya se cumplieron todos los objetivos: queda lista (o se completa sola si no hay a quién volver).
func _revisar(id: String) -> void:
	if estado(id) != ACTIVA:
		return
	for o: Dictionary in objetivos(id):
		if int(o["actual"]) < int(o["meta"]):
			return
	if CatalogoMisiones.mision(id).has("entrega"):
		_misiones[id]["estado"] = LISTA
		mision_cambio.emit(id, LISTA)
		GameState.actualizar_objetivo()
	else:
		_completar(id)


func _completar(id: String) -> void:
	_misiones[id]["estado"] = COMPLETADA
	var premio: Dictionary = CatalogoMisiones.mision(id).get("recompensa", {})
	if premio.has("comida"):
		GameState.sumar_comida(int(premio["comida"]))
	mision_cambio.emit(id, COMPLETADA)
	GameState.actualizar_objetivo()


# ---------------------------------------------------------------- Avisos en pantalla

func _avisar_estado(id: String, nuevo: String) -> void:
	var m := CatalogoMisiones.mision(id)
	var titulo := tr(String(m.get("titulo", id)))
	match nuevo:
		ACTIVA:
			_aviso.mostrar(tr("MISIÓN ACEPTADA"), titulo, id)
			AudioManager.ui("confirm", -8.0)
		LISTA:
			var a_quien := tr(CatalogoDialogos.nombre(String(m.get("entrega", m.get("dador", "")))))
			_aviso.mostrar(tr("MISIÓN LISTA"), tr("Volvé con %s") % a_quien, id, AvisoMision.ORO, 4.0)
			AudioManager.ui("unlock", -6.0)
		COMPLETADA:
			var premio: Dictionary = m.get("recompensa", {})
			var detalle := titulo
			if premio.has("comida"):
				detalle += "  ·  " + tr("+%d de comida") % int(premio["comida"])
			_aviso.mostrar(tr("MISIÓN COMPLETADA"), detalle, id, AvisoMision.ORO, 4.0)
			AudioManager.ui("success", -6.0)


func _avisar_progreso(id: String, indice: int) -> void:
	if Time.get_ticks_msec() - int(_aceptada_ms.get(id, -10000)) < 400:
		return      # Recién aceptada: ya avisó "MISIÓN ACEPTADA"
	var o: Dictionary = objetivos(id)[indice]
	_aviso.mostrar(tr(String(CatalogoMisiones.mision(id).get("titulo", id))).to_upper(),
		"%s   %d / %d" % [tr(String(o["texto"])), o["actual"], o["meta"]], id, AvisoMision.CIAN, 2.4)
	AudioManager.ui("highlight", -14.0)


# ---------------------------------------------------------------- Guardado

func a_dict() -> Dictionary:
	return {"misiones": _misiones.duplicate(true), "banderas": _banderas.keys()}


## Vuelve a un estado guardado ({} = sin misiones, partida nueva).
func desde_dict(datos: Dictionary) -> void:
	_misiones.clear()
	_banderas.clear()
	var guardadas: Dictionary = datos.get("misiones", {})
	for id: String in guardadas:
		if CatalogoMisiones.MISIONES.has(id):    # Una misión que ya no existe se descarta
			_misiones[id] = {"estado": String(guardadas[id].get("estado", ACTIVA)),
				"progreso": Array(guardadas[id].get("progreso", []))}
	for b in datos.get("banderas", []):
		_banderas[String(b)] = true
