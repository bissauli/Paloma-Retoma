extends Node
## Revisa que nada de los edificios con locales (world/pasaje.gd) quede fuera de lugar:
## - Muebles y mercadería de adentro que atraviesan una pared (asoman del lado de afuera).
## - Piezas de la fachada (puerta, bici, macetón, ventanas, toldo, cartel) que se meten adentro de una sala.
## - Carteles y toldos que se pisan entre sí.
## - Empleados y clientes fuera del local.
## Arma sólo los edificios (sin fusionar mallas), con varias semillas.
## godot --headless --path . res://tests/test_locales_dentro.tscn

const TOL := 0.15   ## Lo que se mete menos que esto en una pared de 40 cm no se ve de afuera
var fallas := 0

## Lo que tiene que haber en cada local para que el interior sea lo que dice el cartel.
const FIRMA := {
	"supermercado": ["caja_super", "heladera_bebidas"], "kiosco": ["caja_super", "heladera_bebidas"],
	"farmacia": ["caja_super", "armario_medico"], "ferreteria": ["banco_trabajo", "tablero_herramientas"],
	"verduleria": ["puesto_frutas", "estante_cajones"], "floreria": ["balde_flores", "torre_macetas"],
	"fiambreria": ["mostrador_quesos", "heladera_vitrina", "salames"], "panaderia": ["mostrador_torta", "estante_panes"],
	"libreria": ["biblioteca", "mesa_lectura"], "cafe": ["vitrina_tortas", "mesa_cafe"],
	"heladeria": ["vitrina_helados", "mesa_cafe"], "restaurante": ["mesa_mantel"],
	"consultorio": ["escritorio_pc", "sillas_espera", "armario_medico"], "oficina": ["escritorio_pc", "archivero"],
	"mecanico": ["auto_hatch_rojo", "tablero_herramientas"], "peluqueria": ["tocador_espejo", "sillon_peluqueria"],
	# Ambientes de los departamentos (PlanoCasa)
	"dormitorio": ["cama", "mesita_luz", "ropero"], "living": ["sillon_azul", "mesa_ratona", "mueble_tv"],
	"comedor": ["mesa_comedor", "silla", "vajillero"], "cocina": ["heladera_casa", "mesada", "cocina_horno"],
	"bano": ["banera", "inodoro", "lavatorio"], "cuarto_chicos": ["cama_chica", "cajonera_juguetes"],
	"estudio": ["escritorio_pc", "silla", "biblioteca"], "conventillo": ["mesa_mate", "torre_macetas", "cama"],
}
## Lo que va con una mesa: cada silla tiene que estar al lado de una de estas.
const MESAS := ["mesa_comedor", "mesa_mate", "mesa_ratona", "escritorio_pc", "mesa_cafe", "mesa_mantel", "mesa_lectura"]
## Lo que no corresponde (o no tanto) en un rubro: pieza -> cuántas puede haber como mucho.
const AJENO := {"heladeria": {"heladera_bebidas": 1}}


func _ready() -> void:
	for semilla in [5, 7, 42, 123]:
		OS.set_environment("PALOMA_SEMILLA", str(semilla))
		var raiz := Node3D.new()
		add_child(raiz)
		Pasaje.alrededores(raiz)
		for i in 3:
			await get_tree().physics_frame
		_revisar(raiz, semilla)
		_revisar_objetos(raiz, semilla)
		raiz.free()
	print("test_locales_dentro: %s (%d fallas)" % ["OK" if fallas == 0 else "FALLA", fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func _falla(msg: String) -> void:
	fallas += 1
	print("  FALLA ", msg)


## El interior de una sala, en sus coordenadas: dentro de las paredes, del piso al cielorraso.
func _caja_sala(ce: CasaEnterable) -> AABB:
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	return AABB(Vector3(-hx, 0.0, -hz), Vector3(hx * 2.0, Pasaje.PLANTA_BAJA, hz * 2.0))


func _aabb_en(mi: VisualInstance3D, ref: Node3D) -> AABB:
	var t := ref.global_transform.affine_inverse() * mi.global_transform
	return (t * mi.get_aabb()).abs()


func _revisar(raiz: Node3D, semilla: int) -> void:
	var salas := _todas_las_salas(raiz)
	for casa in raiz.get_children():
		if not String(casa.name).begins_with("Edificio_"):
			continue
		for sala in casa.get_children():
			if not String(sala.name).begins_with("Sala_"):
				continue
			var ce := _ce_de(salas, sala as Node3D)
			if ce == null:
				continue
			var caja := _caja_sala(ce)
			var adentro := caja.grow(-0.02)
			# 0) El interior concuerda con el cartel: cada rubro tiene lo suyo (y la heladería, helados)
			var cuenta := {}
			for mi in _mallas(sala):
				if mi.has_meta(&"kit_pieza"):
					var k := String(mi.get_meta(&"kit_pieza"))
					cuenta[k] = int(cuenta.get(k, 0)) + 1
			if OS.has_environment("INVENTARIO"):
				print("INV ", semilla, " ", ce.tema, " | ", ce.nombre, " | ", cuenta)
			if not Pasaje.es_local(ce.tema):
				_revisar_casa(sala as Node3D, ce, semilla)
			if true:
				for pieza: String in FIRMA.get(ce.tema, []):
					if int(cuenta.get(pieza, 0)) == 0 and not (pieza == "gondola" and ce.tema in PlanoLocal.GONDOLA):
						_falla("semilla %d, %s '%s': le falta '%s' (no parece lo que dice el cartel)" % [semilla, ce.tema, ce.nombre, pieza])
				for pieza: String in AJENO.get(ce.tema, {}):
					if int(cuenta.get(pieza, 0)) > int(AJENO[ce.tema][pieza]):
						_falla("semilla %d, %s: demasiados '%s' (%d)" % [semilla, ce.tema, pieza, int(cuenta[pieza])])
				var p: Array = PlanoLocal.PLANO.get(ce.tema, []) if Pasaje.es_local(ce.tema) else []
				if not p.is_empty() and int(cuenta.get(p[0], 0)) < int(p[1]):
					_falla("semilla %d, %s: %d de %d mostradores" % [semilla, ce.tema, int(cuenta.get(p[0], 0)), int(p[1])])
			# 1) Lo de adentro (centro adentro de la sala) no tiene que salir por las paredes
			for mi in _mallas(sala):
				if mi.get_parent() is ModeloHumano or _es_gente(mi):
					continue
				var a := _aabb_en(mi, sala as Node3D)
				var c := a.get_center()
				if not adentro.has_point(c):
					continue
				var sale := maxf(maxf(caja.position.x - a.position.x, a.end.x - caja.end.x),
					maxf(caja.position.z - a.position.z, a.end.z - caja.end.z))
				if sale > TOL and not _es_de_la_ventana(ce, a):
					_falla("semilla %d, %s: '%s' atraviesa la pared %.2f m" % [semilla, ce.tema, _nombre(mi), sale])
			# 4) La gente, adentro del local o en la vereda de adelante
			for m in _personas(sala):
				var p: Vector3 = (sala as Node3D).global_transform.affine_inverse() * m.global_position
				if not caja.grow(0.05).has_point(p + Vector3(0, 0.1, 0)):
					_falla("semilla %d, %s: persona afuera del local en %s" % [semilla, ce.tema, p])
		# 2) Lo de la fachada (cuelga de la casa, no de una sala) no se mete en ninguna sala
		for mi in _mallas_directas(casa):
			for sala in casa.get_children():
				if not String(sala.name).begins_with("Sala_"):
					continue
				var ce := _ce_de(salas, sala as Node3D)
				var caja := _caja_sala(ce).grow(-0.03)
				var a := _aabb_en(mi, sala as Node3D)
				if a.intersects(caja):
					_falla("semilla %d, %s: la pieza de la fachada '%s' se mete adentro" % [semilla, ce.tema, _nombre(mi)])
		# 3) Carteles y toldos de la fachada que se pisan (en coordenadas de la casa)
		var frente: Array = []
		for sala in casa.get_children():
			if not String(sala.name).begins_with("Sala_"):
				continue
			for h in (sala as Node).get_children():
				var v := h as VisualInstance3D
				if v and (h is Label3D or _nombre(v).begins_with("toldo")):
					frente.append([v, _aabb_en(v, casa as Node3D)])
		for h in (casa as Node).get_children():
			var v := h as VisualInstance3D
			if v and (_nombre(v).begins_with("puerta") or _nombre(v).begins_with("ventana") or _nombre(v).begins_with("maceton")
					or _nombre(v).begins_with("bici")):
				frente.append([v, _aabb_en(v, casa as Node3D)])
		for i in frente.size():
			for j in range(i + 1, frente.size()):
				var a: AABB = frente[i][1]
				var b: AABB = frente[j][1]
				if _achicar(a).intersects(_achicar(b)):
					_falla("semilla %d, %s: '%s' y '%s' se pisan en la fachada" % [semilla, casa.name,
						_nombre(frente[i][0]), _nombre(frente[j][0])])


## 5) Las cosas para tirar de un aletazo: cada local tiene algunas, adentro, apoyadas justo sobre la
## colisión de su mueble (ni flotando ni metidas adentro: al golpearlas saldrían disparadas).
func _revisar_objetos(raiz: Node3D, semilla: int) -> void:
	var espacio := get_viewport().world_3d.direct_space_state
	for ce: CasaEnterable in _todas_las_salas(raiz):
		if not Pasaje.es_local(ce.tema):
			continue
		var sala := _sala_de(raiz, ce)
		var objetos: Array[Golpeable] = []
		for g in sala.find_children("*", "Golpeable", true, false):
			objetos.append(g)
		if objetos.size() < 3:
			_falla("semilla %d, %s: sólo %d cosas para tirar" % [semilla, ce.tema, objetos.size()])
		for g in objetos:
			var p: Vector3 = sala.global_transform.affine_inverse() * g.global_position
			if not _caja_sala(ce).has_point(p):
				_falla("semilla %d, %s: '%s' fuera del local" % [semilla, ce.tema, g.tipo])
			var q := PhysicsRayQueryParameters3D.create(g.global_position + Vector3.UP * 0.25, g.global_position + Vector3.DOWN * 0.5, 1)
			var r := espacio.intersect_ray(q)
			var dy := INF if r.is_empty() else g.global_position.y - (r["position"] as Vector3).y
			if absf(dy) > 0.03:
				_falla("semilla %d, %s: '%s' no está apoyado en su mueble (%.2f m)" % [semilla, ce.tema, g.tipo, dy])


func _todas_las_salas(raiz: Node) -> Array[CasaEnterable]:
	var res: Array[CasaEnterable] = []
	for n in raiz.find_children("*", "CasaEnterable", true, false):
		res.append(n)
	return res


## El nodo "Sala_*" del edificio que corresponde a "ce" (mismo lugar y orientación).
func _sala_de(raiz: Node, ce: CasaEnterable) -> Node3D:
	for s in raiz.find_children("Sala_*", "Node3D", true, false):
		var n := s as Node3D
		if n.global_transform.origin.distance_to(ce.global_transform.origin) < 0.01 \
				and n.global_transform.basis.z.dot(ce.global_transform.basis.z) > 0.99:
			return n
	return null


## Un ambiente de casa ordenado: cada silla al lado de una mesa (o escritorio) y todo derecho (girado de a
## 90°, salvo lo chico que va suelto: el oso, la jaula, el gato).
func _revisar_casa(sala: Node3D, ce: CasaEnterable, semilla: int) -> void:
	# La cinemática tiene qué esquivar: cosas de costado en las vueltas y por abajo entre vuelta y vuelta
	var esquiva := int(ce.get_meta(&"esquiva", 0))
	if esquiva < 3:
		_falla("semilla %d, %s: la cinemática esquiva sólo %d cosas" % [semilla, ce.tema, esquiva])
	if OS.has_environment("INVENTARIO"):
		print("ESQ ", semilla, " ", ce.tema, " esquiva ", esquiva)
	var mesas: Array[Vector3] = []
	var sillas: Array[Vector3] = []
	for mi in _mallas(sala):
		if not mi.has_meta(&"kit_pieza") or mi.get_parent() != sala:
			continue
		var k := String(mi.get_meta(&"kit_pieza"))
		var p := (mi as Node3D).position
		if k in MESAS:
			mesas.append(p)
		elif k == "silla":
			sillas.append(p)
		if k in ["oso_peluche", "jaula", "gato", "alfombra", "cuadro", "aplique", "estante_pared"] or k.begins_with("cortina"):
			continue
		var giro := fposmod((mi as Node3D).rotation.y, PI / 2.0)
		if minf(giro, PI / 2.0 - giro) > 0.02:
			_falla("semilla %d, %s: '%s' quedó torcido (%.0f°)" % [semilla, ce.tema, k, rad_to_deg((mi as Node3D).rotation.y)])
	for s in sillas:
		var cerca := false
		for m in mesas:
			if Vector2(s.x - m.x, s.z - m.z).length() < 1.4:
				cerca = true
		if not cerca:
			_falla("semilla %d, %s: una silla suelta, lejos de toda mesa (%s)" % [semilla, ce.tema, s])


## La caja 3 cm más chica de cada lado (sin pasar a tamaño negativo en lo muy finito, como un cartel).
func _achicar(a: AABB) -> AABB:
	var m := Vector3(minf(0.03, a.size.x * 0.25), minf(0.03, a.size.y * 0.25), minf(0.03, a.size.z * 0.25))
	return AABB(a.position + m, a.size - m * 2.0)


func _ce_de(salas: Array[CasaEnterable], sala: Node3D) -> CasaEnterable:
	for ce in salas:
		if ce.global_transform.origin.distance_to(sala.global_transform.origin) < 0.01 \
				and ce.global_transform.basis.z.dot(sala.global_transform.basis.z) > 0.99:
			return ce
	return null


## Lo que está en la ventana o la vidriera (cortinas, marcos) puede tocar la pared: es su lugar.
func _es_de_la_ventana(ce: CasaEnterable, a: AABB) -> bool:
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	var cerca_pared := absf(absf(a.get_center().z) - hz) < 0.3
	return cerca_pared and a.size.y > 3.0   # Las cortinas: altas y pegadas a la pared de una ventana


func _nombre(mi: Node) -> String:
	return String(mi.get_meta(&"kit_pieza", mi.name)) if not mi is Label3D else "cartel '%s'" % (mi as Label3D).text


func _mallas(n: Node) -> Array[VisualInstance3D]:
	var res: Array[VisualInstance3D] = []
	for h in n.get_children():
		if h is GenteLocal:
			continue
		if h is MeshInstance3D or h is Label3D:
			res.append(h)
		res.append_array(_mallas(h))
	return res


func _mallas_directas(n: Node) -> Array[VisualInstance3D]:
	var res: Array[VisualInstance3D] = []
	for h in n.get_children():
		if h is MeshInstance3D:
			res.append(h)
	return res


func _es_gente(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is GenteLocal:
			return true
		p = p.get_parent()
	return false


func _personas(n: Node) -> Array[Node3D]:
	var res: Array[Node3D] = []
	for g in n.get_children():
		if g is GenteLocal:
			for m in g.get_children():
				if m is ModeloHumano:
					res.append(m)
	return res
