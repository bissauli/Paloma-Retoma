extends Node
## Prueba automática del builder de mapa (headless), sin tocar res://mapa/overrides.json:
## godot --headless --path . res://tests/test_builder_mapa.tscn
## 1) Sin overrides el mapa queda igual que siempre y en modo admin las piezas de piso son editables.
## 2) Un override de "mover" y otro de "borrar" cambian lo que arma el juego normal.
## 3) Una pieza agregada aparece en el juego normal.

var fallas := 0


func _ready() -> void:
	GameState.guardado_habilitado = false
	MapaOverrides.recargar()
	_check("el archivo de overrides del proyecto está vacío (la prueba parte de cero)", not MapaOverrides.hay_cambios())

	# Mundo normal sin cambios
	var base := await _armar(false)
	var cant_base: int = base["colocadas"]
	var bancos_base: int = base["editables"]
	_check("el mundo normal arma piezas", cant_base > 100)
	_check("sin modo admin no hay piezas editables sueltas", bancos_base == 0)

	# Modo admin
	var admin := await _armar(true)
	var ed: int = admin["editables"]
	print("editables en modo admin: ", ed)
	_check("en modo admin hay muchas piezas editables", ed > 100)
	print("colocadas normal=", cant_base, " admin=", admin["colocadas"])
	_check("en modo admin se arman las mismas piezas del kit", admin["colocadas"] == cant_base)
	var ids: Array[String] = []
	var tipos := {}
	for n in admin["nodos"]:
		var t := String(n.get_meta(&"tipo_pieza"))
		tipos[t] = int(tipos.get(t, 0)) + 1
		ids.append(String(n.get_meta(&"id_pieza")))
	print("por tipo: ", tipos)
	_check("hay faroles, bancos, jacarandás y fuentes de la plaza", tipos.has("farol") and tipos.has("banco") and tipos.has("jacaranda") and tipos.has("fuente"))
	_check("hay piezas del kit", tipos.has("kit"))
	var unicos := {}
	for i in ids:
		unicos[i] = true
	_check("los IDs son únicos", unicos.size() == ids.size())

	# Mover un farol de la plaza y borrar un banco, anotando como lo hace el builder
	var farol: Node3D
	var banco: Node3D
	var arbol: Node3D
	for n in admin["nodos"]:
		if farol == null and n.get_meta(&"tipo_pieza") == "farol": farol = n
		if banco == null and n.get_meta(&"tipo_pieza") == "banco": banco = n
		if arbol == null and n.get_meta(&"tipo_pieza") == "kit" and String(n.get_meta(&"nombre_pieza")).begins_with("farola"): arbol = n
	var farol_id := String(farol.get_meta(&"id_pieza"))
	var arbol_id := String(arbol.get_meta(&"id_pieza"))
	var arbol_nombre := String(arbol.get_meta(&"nombre_pieza"))
	var arbol_orig := arbol.position
	farol.position += Vector3(3, 0, 0)
	MapaOverrides.anotar(farol)
	arbol.position += Vector3(0, 0, 5)
	MapaOverrides.anotar(arbol)
	banco.visible = false
	MapaOverrides.anotar(banco)
	var d := MapaOverrides.datos()
	_check("el farol quedó anotado como movido", (d["mover"] as Dictionary).has(farol_id))
	_check("el banco quedó anotado como borrado", (d["borrar"] as Array).size() == 1)

	# Mundo normal con esos cambios
	var cambiado := await _armar(false)
	var hay_nuevo := false
	var hay_viejo := false
	for c: Array in cambiado["lista"]:
		if c[0] == arbol_nombre and (c[1] as Vector3).distance_to(arbol_orig + Vector3(0, 0, 5)) < 0.01:
			hay_nuevo = true
		if c[0] == arbol_nombre and (c[1] as Vector3).distance_to(arbol_orig) < 0.01:
			hay_viejo = true
	_check("la pieza del kit movida aparece en su lugar nuevo", hay_nuevo)
	_check("la pieza del kit movida ya no está en el lugar viejo", not hay_viejo)
	_check("mover no cambia la cantidad de piezas del kit", cambiado["colocadas"] == cant_base)

	# Agregar una pieza
	var e := MapaOverrides.agregar("kit", "hidrante", Vector3(1, 0.16, 1), 0.0, Vector3.ONE)
	var con_agregada := await _armar(false)
	_check("la pieza agregada se arma en el juego normal", con_agregada["colocadas"] == cant_base + 1)
	_check("la agregada tiene su ID", String(e["id"]).begins_with("a:"))

	print("--- %s ---" % ("TODO OK" if fallas == 0 else "%d FALLAS" % fallas))
	get_tree().quit(1 if fallas > 0 else 0)


## Arma el mundo (Plaza) y devuelve cuentas.
func _armar(admin: bool) -> Dictionary:
	MapaOverrides.modo_admin = admin
	var p: Node = load("res://world/plaza.tscn").instantiate()
	add_child(p)
	await get_tree().physics_frame
	var ciudad: Ciudad = p.get_node("Ciudad")
	var nodos := get_tree().get_nodes_in_group(MapaOverrides.GRUPO)
	var r := {"colocadas": ciudad.colocadas.size(), "lista": ciudad.colocadas.duplicate(), "editables": nodos.size(),
		"nodos": nodos.duplicate(), "faroles_plaza": []}
	if not admin:
		remove_child(p)
		p.queue_free()
	else:
		# Se deja armado para tocar los nodos; se libera al final de la prueba
		remove_child(p)
		_pendiente = p
	MapaOverrides.modo_admin = false
	return r

var _pendiente: Node


func _check(nombre: String, ok: bool) -> void:
	print("%s  %s" % ["OK   " if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
