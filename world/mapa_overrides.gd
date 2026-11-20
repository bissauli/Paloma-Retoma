class_name MapaOverrides
extends RefCounted
## Cambios manuales al mapa (los hace el builder de administrador, ver admin/builder_mapa.tscn).
## El mapa se sigue generando por código igual que siempre; después esta clase le aplica una capa
## de cambios guardada en res://mapa/overrides.json: piezas movidas, borradas y agregadas.
## Si el archivo no existe o está vacío, el mapa queda exactamente como lo genera el código.
##
## Cada pieza editable tiene un ID estable: tipo + nombre + posición ORIGINAL (a 10 cm). Si dos
## piezas iguales caen en el mismo punto, la segunda lleva "#2". Los IDs no dependen del orden
## de armado: si el generador cambia, los overrides de lo que no cambió siguen valiendo.
##
## Modo admin: sólo lo activa la escena del builder. En ese modo las piezas editables cuelgan de un
## nodo propio (no se fusionan ni tienen colisión) para poder tocarlas en vivo, y las borradas
## quedan ocultas en vez de desaparecer, así se pueden restaurar.

const RUTA := "res://mapa/overrides.json"
const GRUPO := &"piezas_editables"

## Todas las piezas que pone Ciudad._poner se pueden editar: edificios, props de las veredas, el parque,
## autos estacionados, juegos... (lo que se arma con primitivas, como la fuente, el banco, el farol y la
## jacarandá de la plaza, también). Las calzadas y veredas de base y lo que anda solo (tránsito, gente,
## animales) no se tocan.
const SUELO := ["pasto", "camino_", "plaza_", "piso_", "cancha_", "bosque", "jacaranda_banco"]

static var modo_admin := false          ## Sólo la escena del builder lo pone en true
static var camara_inicial: Variant = null   ## Dónde está la jugadora al apretar F2 (el builder arranca mirando ahí)
static var forzar_id := ""              ## Pieza agregada que se está armando ahora (ver Ciudad)
static var _datos := {}
static var _cargado := false
static var _vistos := {}


# ---------------------------------------------------------------- Archivo

static func datos() -> Dictionary:
	if not _cargado:
		_cargado = true
		_datos = {"mover": {}, "borrar": [], "agregar": [], "siguiente": 1}
		if FileAccess.file_exists(RUTA):
			var f := FileAccess.open(RUTA, FileAccess.READ)
			var j: Variant = JSON.parse_string(f.get_as_text()) if f else null
			if j is Dictionary:
				for k: String in _datos:
					if (j as Dictionary).has(k):
						_datos[k] = (j as Dictionary)[k]
	return _datos


## Vuelve a leer el archivo (el builder lo usa al empezar).
static func recargar() -> void:
	_cargado = false
	datos()


static func guardar() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RUTA.get_base_dir()))
	var f := FileAccess.open(RUTA, FileAccess.WRITE)
	if f == null:
		push_warning("MapaOverrides: no se pudo escribir %s (¿juego exportado?)" % RUTA)
		return false
	f.store_string(JSON.stringify(datos(), "\t", true))
	return true


static func hay_cambios() -> bool:
	var d := datos()
	return not (d["mover"] as Dictionary).is_empty() or not (d["borrar"] as Array).is_empty() \
		or not (d["agregar"] as Array).is_empty()


# ---------------------------------------------------------------- IDs y resolución

## Se llama al empezar a armar el mundo: reinicia el conteo de piezas repetidas en el mismo punto.
static func reiniciar() -> void:
	_vistos.clear()
	forzar_id = ""


static func es_editable(nombre: String) -> bool:
	return Kit.es_de_ciudad(nombre) or Kit.PARQUE_COL.has(nombre) or nombre in Kit.LOSETAS_PARQUE


## "edificio", "suelo" (losetas y pisos grandes) o "prop" (todo lo demás): el builder deja elegir qué se puede agarrar.
static func categoria(tipo: String, nombre: String) -> String:
	if tipo != "kit":
		return "prop"
	if KitDatos.PIEZAS.get(nombre, {}).get("carpeta", "") == "edificios":
		return "edificio"
	for p: String in SUELO:
		if nombre.begins_with(p):
			return "suelo"
	return "prop"


static func _id(tipo: String, nombre: String, pos: Vector3) -> String:
	var base := "%s:%s@%.1f,%.1f,%.1f" % [tipo, nombre, pos.x, pos.y, pos.z]
	var n := int(_vistos.get(base, 0)) + 1
	_vistos[base] = n
	return base if n == 1 else "%s#%d" % [base, n]


static func _v3(a: Variant, por_defecto: Vector3) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return por_defecto


static func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


## Qué hay que hacer con una pieza que el código quiere poner en (pos, rot, escala).
## Devuelve {id, pos, rot, escala, borrado, movido, agregado, orig_pos, orig_rot, orig_escala}.
static func resolver(tipo: String, nombre: String, pos: Vector3, rot: float, escala: Vector3) -> Dictionary:
	var r := {"id": "", "pos": pos, "rot": rot, "escala": escala, "borrado": false, "movido": false,
		"agregado": false, "tipo": tipo, "pieza": nombre, "orig_pos": pos, "orig_rot": rot, "orig_escala": escala}
	if forzar_id != "":
		# Pieza agregada: sus datos salen de su entrada, no de lo que pide el código
		r["id"] = forzar_id
		r["agregado"] = true
		for a: Dictionary in datos()["agregar"]:
			if a["id"] == forzar_id:
				r["pos"] = _v3(a.get("pos"), pos)
				r["rot"] = float(a.get("rot", rot))
				r["escala"] = _v3(a.get("escala"), escala)
		r["orig_pos"] = r["pos"]
		r["orig_rot"] = r["rot"]
		r["orig_escala"] = r["escala"]
		forzar_id = ""
		return r
	var id := _id(tipo, nombre, pos)
	r["id"] = id
	var d := datos()
	if (d["borrar"] as Array).has(id):
		r["borrado"] = true
	var m: Variant = (d["mover"] as Dictionary).get(id)
	if m is Dictionary:
		var md := m as Dictionary
		r["pos"] = _v3(md.get("pos"), pos)
		r["rot"] = float(md.get("rot", rot))
		r["escala"] = _v3(md.get("escala"), escala)
		r["movido"] = true
	return r


## Marca "nodo" como pieza editable del builder (sólo en modo admin).
static func registrar(nodo: Node3D, r: Dictionary) -> void:
	nodo.set_meta(&"no_fusionar", true)
	nodo.set_meta(&"id_pieza", r["id"])
	nodo.set_meta(&"tipo_pieza", r["tipo"])
	nodo.set_meta(&"nombre_pieza", r["pieza"])
	nodo.set_meta(&"orig_pos", r["orig_pos"])
	nodo.set_meta(&"orig_rot", r["orig_rot"])
	nodo.set_meta(&"orig_escala", r["orig_escala"])
	nodo.set_meta(&"agregado", r["agregado"])
	nodo.set_meta(&"categoria", categoria(String(r["tipo"]), String(r["pieza"])))
	nodo.add_to_group(GRUPO)
	if r["borrado"]:
		nodo.visible = false


## Nodo de una pieza armada con primitivas (banco, farol, jacaranda, fuente): lo coloca donde diga el
## override (o donde lo pone el código) y devuelve null si está borrada. Lo armado va adentro, en
## coordenadas locales.
static func envolver(padre: Node3D, tipo: String, nombre: String, pos: Vector3, rot := 0.0) -> Node3D:
	var r := resolver(tipo, nombre, pos, rot, Vector3.ONE)
	if r["borrado"] and not modo_admin:
		return null
	var n := Node3D.new()
	padre.add_child(n)
	n.transform = transformacion(r["pos"], r["rot"], r["escala"])
	if modo_admin:
		registrar(n, r)
	return n


static func transformacion(pos: Vector3, rot: float, escala: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0, rot, 0)) * Basis.from_scale(escala), pos)


# ---------------------------------------------------------------- Lo que anota el builder

## Anota el estado actual de una pieza editable (movida, borrada o igual a la original).
static func anotar(nodo: Node3D) -> void:
	var d := datos()
	var id: String = nodo.get_meta(&"id_pieza")
	var pos := nodo.position
	var rot := nodo.rotation.y
	var escala := nodo.scale
	var borrado := not nodo.visible
	if nodo.get_meta(&"agregado", false):
		var lista: Array = d["agregar"]
		for i in lista.size():
			if lista[i]["id"] == id:
				if borrado:
					lista.remove_at(i)
				else:
					lista[i]["pos"] = _arr(pos)
					lista[i]["rot"] = snappedf(rot, 0.0001)
					lista[i]["escala"] = _arr(escala)
				return
		if not borrado:
			# Una pieza agregada que se había borrado y se restauró (deshacer): vuelve a su lugar en la lista
			lista.append({"id": id, "tipo": String(nodo.get_meta(&"tipo_pieza")), "pieza": String(nodo.get_meta(&"nombre_pieza")),
				"pos": _arr(pos), "rot": snappedf(rot, 0.0001), "escala": _arr(escala)})
		return
	var mover: Dictionary = d["mover"]
	var borrar: Array = d["borrar"]
	borrar.erase(id)
	mover.erase(id)
	if borrado:
		borrar.append(id)
		return
	var op: Vector3 = nodo.get_meta(&"orig_pos")
	var orr: float = nodo.get_meta(&"orig_rot")
	var oe: Vector3 = nodo.get_meta(&"orig_escala")
	if pos.distance_to(op) > 0.001 or absf(angle_difference(rot, orr)) > 0.0005 or escala.distance_to(oe) > 0.001:
		mover[id] = {"pos": _arr(pos), "rot": snappedf(rot, 0.0001), "escala": _arr(escala)}


## Registra una pieza nueva (copia o de la paleta). Devuelve su entrada para armarla.
static func agregar(tipo: String, nombre: String, pos: Vector3, rot: float, escala: Vector3) -> Dictionary:
	var d := datos()
	var e := {"id": "a:%d" % int(d["siguiente"]), "tipo": tipo, "pieza": nombre,
		"pos": _arr(pos), "rot": snappedf(rot, 0.0001), "escala": _arr(escala)}
	d["siguiente"] = int(d["siguiente"]) + 1
	(d["agregar"] as Array).append(e)
	return e


## Arma las piezas agregadas (las llama Ciudad antes de fusionar).
static func armar_agregadas(ciudad: Node3D) -> void:
	for a: Dictionary in datos()["agregar"]:
		var pos := _v3(a.get("pos"), Vector3.ZERO)
		var rot := float(a.get("rot", 0.0))
		var escala := _v3(a.get("escala"), Vector3.ONE)
		forzar_id = String(a["id"])
		match String(a.get("tipo", "kit")):
			"kit":
				ciudad.call("_poner", String(a["pieza"]), pos, rot, escala)
			"banco":
				Edificios.banco(ciudad, pos, rot)
			"farol":
				Edificios.farol(ciudad, pos)
			"jacaranda":
				Edificios.jacaranda(ciudad, pos, 1.0)   # su tamaño va en la escala de la entrada
		forzar_id = ""


## Cuántos cambios hay anotados: [movidas, borradas, agregadas].
static func resumen() -> Array:
	var d := datos()
	return [(d["mover"] as Dictionary).size(), (d["borrar"] as Array).size(), (d["agregar"] as Array).size()]
