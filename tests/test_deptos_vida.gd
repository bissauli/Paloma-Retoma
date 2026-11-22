extends Node
## Lo que le da vida a los departamentos y lo que se rompe:
## - Vecinos (world/vecinos.gd): en cada ambiente (menos el baño) vive alguien; está adentro del cuarto,
##   no queda debajo de la ruta de la cinemática ni delante de una ventana, y el que está parado no se
##   mete en un mueble.
## - Cosas para tirar sobre las mesas de los departamentos (PlanoLocal.objetos), y que lo de vidrio o loza
##   se rompe al caer (Golpeable.romper) y vuelve entero; lo que no es de vidrio no se rompe.
## - Lo que cuelga del techo se hamaca si la paloma lo empuja (CasaEnterable.empujar_colgantes), y si
##   sólo lo roza, un empujón por vez.
## Arma sólo los edificios (como test_locales_dentro), con varias semillas.
## godot --headless --path . res://tests/test_deptos_vida.tscn

var fallas := 0


func _falla(msg: String) -> void:
	fallas += 1
	print("  FALLA ", msg)


func _ready() -> void:
	var temas_vistos := {}
	for semilla in [5, 7, 42, 123]:
		OS.set_environment("PALOMA_SEMILLA", str(semilla))
		var raiz := Node3D.new()
		add_child(raiz)
		Pasaje.alrededores(raiz)
		for i in 3:
			await get_tree().physics_frame
		for v in raiz.find_children("Vecinos", "Node3D", true, false):
			var ve := v as Vecinos
			temas_vistos[ve.tema] = int(temas_vistos.get(ve.tema, 0)) + ve.cuantos()
			print("  semilla %d, %s: %d vecinos" % [semilla, ve.tema, ve.cuantos()])
			_revisar_vecinos(ve, semilla)
		_revisar_objetos(raiz, semilla)
		if semilla == 7:
			await _probar_colgantes(raiz)
			await _probar_rotura(raiz)
		raiz.free()
	for t in Vecinos.QUIENES:
		if t != "bano" and temas_vistos.has(t) and int(temas_vistos[t]) == 0:
			_falla("en ningún %s vive nadie" % t)
	print("test_deptos_vida: %s (%d fallas)" % ["OK" if fallas == 0 else "FALLA", fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func _revisar_vecinos(ve: Vecinos, semilla: int) -> void:
	var ce := ve.ce
	if ve.tema != "bano" and ve.cuantos() == 0:
		_falla("semilla %d, %s: no vive nadie" % [semilla, ve.tema])
	var ruta := Pasaje._muestras(ce)
	var hx := ce.ancho / 2.0 - CasaEnterable.ESPESOR
	var hz := ce.fondo / 2.0 - CasaEnterable.ESPESOR
	for m in ve.personas():
		var p := m.position
		if absf(p.x) > hx - 0.2 or absf(p.z) > hz - 0.2:
			_falla("semilla %d, %s: %s fuera del cuarto (%s)" % [semilla, ve.tema, m.personaje, p])
		var alto := 1.45 if m.sentado else 1.85
		if not Pasaje._libre(ruta, Vector3(p.x, alto / 2.0, p.z), Vector3(0.25, alto / 2.0, 0.25), 0.0):
			_falla("semilla %d, %s: %s debajo de la ruta de la cinemática" % [semilla, ve.tema, m.personaje])
		if ve._frente_a_ventana(p):
			_falla("semilla %d, %s: %s delante de una ventana" % [semilla, ve.tema, m.personaje])
		if not m.sentado:
			for caja: Array in ce.cajas:
				var c: Vector3 = caja[0]
				var e: Vector3 = caja[1]
				if c.y - e.y > 1.9:
					continue
				var q := (p - c).rotated(Vector3.UP, -float(caja[2]))
				if absf(q.x) < e.x + 0.12 and absf(q.z) < e.z + 0.12:
					_falla("semilla %d, %s: %s parado adentro de un mueble" % [semilla, ve.tema, m.personaje])
					break


func _revisar_objetos(raiz: Node, semilla: int) -> void:
	for c in raiz.find_children("*", "CasaEnterable", true, false):
		var ce := c as CasaEnterable
		if not ce.con_cinematica:
			continue
		var n := int(ce.get_meta(&"objetos", 0))
		var apoyos := (ce.get_meta(&"apoyos", []) as Array).size()
		if apoyos > 0 and n == 0:
			_falla("semilla %d, %s: tiene %d muebles para apoyar y ninguna cosa para tirar" % [semilla, ce.tema, apoyos])


## Lo que cuelga: un empujón lo hamaca; rozándolo, uno solo hasta que la paloma se aleja.
func _probar_colgantes(raiz: Node) -> void:
	var probados := 0
	for c in raiz.find_children("*", "CasaEnterable", true, false):
		var ce := c as CasaEnterable
		for piv in ce.colgantes:
			if piv.has_meta(&"gira"):
				continue
			var centro := ce.to_global(piv.position - Vector3(0, float(piv.get_meta(&"largo")), 0))
			if ce.empujar_colgantes(centro, Vector3(6, 0, 0), 0.3) == 0:
				_falla("%s: el empujón no llega a lo que cuelga" % ce.tema)
				continue
			var maximo := 0.0
			for k in 60:
				ce._animar_colgantes(1.0 / 60.0)
				maximo = maxf(maximo, absf(piv.rotation.z) + absf(piv.rotation.x))
			if maximo < 0.08:
				_falla("%s: lo que cuelga casi no se movió (%.3f rad)" % [ce.tema, maximo])
			var lejos := centro + Vector3(5, 0, 0)
			var r1 := ce.empujar_colgantes(centro, Vector3(3, 0, 0), 0.3, true)
			var r2 := ce.empujar_colgantes(centro, Vector3(3, 0, 0), 0.3, true)
			ce.empujar_colgantes(lejos, Vector3(3, 0, 0), 0.3, true)
			var r3 := ce.empujar_colgantes(centro, Vector3(3, 0, 0), 0.3, true)
			if r1 == 0 or r2 != 0 or r3 == 0:
				_falla("%s: rozando, empujones %d, %d (seguido) y %d (después de alejarse)" % [ce.tema, r1, r2, r3])
			probados += 1
			break
	if probados == 0:
		_falla("no hay nada colgado para probar")
	print("  colgantes probados: %d" % probados)
	await get_tree().physics_frame


## Un vaso y un plato que caen de 1,5 m se rompen (y vuelven enteros); un libro no.
func _probar_rotura(raiz: Node) -> void:
	var piso := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(20, 0.2, 20)
	cs.shape = b
	piso.add_child(cs)
	raiz.add_child(piso)
	piso.global_position = Vector3(0, -50.1, 0)
	var cosas: Array[Golpeable] = []
	var x := -2.0
	for t in ["vaso", "plato", "taza", "libro"]:
		var g := Golpeable.crear(raiz, t, Vector3(x, -48.5, 0))
		cosas.append(g)
		x += 1.3
	await get_tree().physics_frame
	for g in cosas:
		g.golpear(Vector3.ZERO, 0.0)   # Suelto (sin empujón): cae derecho
	for k in 120:
		await get_tree().physics_frame
	for g in cosas:
		var debe := g.tipo in Golpeable.DE_VIDRIO
		if g.roto != debe:
			_falla("%s que cae de 1,5 m: %s" % [g.tipo, "no se rompió" if debe else "se rompió"])
	var pedazos := 0
	for n in raiz.get_children():
		if n is RigidBody3D and not (n is Golpeable):
			pedazos += 1
	if pedazos == 0:
		_falla("al romperse no quedaron pedazos")
	print("  pedazos en el piso: %d" % pedazos)
	var vaso := cosas[0]
	vaso._volver()
	await get_tree().physics_frame
	if vaso.roto or not vaso._visual.visible or vaso.collision_layer != Golpeable.CAPA_OBJETOS:
		_falla("el vaso roto no volvió entero")
