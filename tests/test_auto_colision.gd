extends Node
## Prueba automática de las colisiones de los autos (corre headless):
## godot --headless --path . res://tests/test_auto_colision.tscn
## La paloma no puede atravesar la parte de arriba de un auto: ni cayendo en picada sobre el techo, ni
## posada en el techo mientras el auto anda, ni volando de costado contra la cabina (las ventanillas).

var fallas := 0
var _j: PalomaJugador
var _main: Node
const ALTO := 300.0          ## Muy arriba de la ciudad, sin nada alrededor
const ORIGEN := Vector3(0, ALTO, -214)


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_auto_colision.cfg"
	GameState.guardado_habilitado = false
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	for i in 10:
		await get_tree().process_frame
	_j = _main.get_node("Paloma")
	# Un piso donde apoyar los autos
	var piso := StaticBody3D.new()
	piso.collision_layer = Construir.CAPA_MUNDO
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(200, 1, 40)
	cs.shape = caja
	piso.add_child(cs)
	_main.add_child(piso)
	piso.global_position = ORIGEN - Vector3(0, 0.5, 0)
	for modelo in ["auto_hatch_rojo", "auto_sedan_celeste", "taxi"]:
		await _probar(modelo)
	for modelo in Auto.MODELOS_COLECTIVO:
		await _probar_colectivo(modelo)
	# Los estacionados (colisión del kit en un StaticBody3D): parabrisas y ventanillas también
	for modelo in ["auto_hatch_naranja", "auto_sedan_rojo", "taxi"]:
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = Construir.CAPA_MUNDO
		_main.add_child(cuerpo)
		var pos := ORIGEN + Vector3(30, 0, 0)
		var mi := Kit.colocar(_main, modelo, pos, 0.0, Vector3.ONE, cuerpo)
		await _fisica(3)
		_ventanas(modelo, func(p: Vector3) -> Vector3: return pos + p, Construir.CAPA_MUNDO, "estacionado")
		mi.queue_free()
		cuerpo.queue_free()
		await _fisica(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _probar(modelo: String) -> void:
	var a := Auto.new()
	a.preparar(1.0)
	a.tipo = "auto"
	a.modelo = modelo
	a.largo = float(KitDatos.PIEZAS[modelo]["largo"])
	_main.add_child(a)
	a.global_position = ORIGEN
	await _fisica(3)
	var techo := _techo(modelo)   # [x del medio del techo (local), altura del techo]
	var x_techo: float = techo[0]
	var y_techo: float = techo[1]
	var centro_techo := a.to_global(Vector3(x_techo, 0, 0))

	# 1) Un rayo de costado a la altura de las ventanillas choca con la cabina
	var q := PhysicsRayQueryParameters3D.create(centro_techo + Vector3(0, 1.1, 3), centro_techo + Vector3(0, 1.1, -3), Auto.CAPA_GENTE)
	_check("%s: la cabina (ventanillas) tiene colisión" % modelo, not get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty())
	_ventanas(modelo, func(p: Vector3) -> Vector3: return a.to_global(p), Auto.CAPA_GENTE, "andando")

	# 2) Cae en picada sobre el techo: queda arriba
	_soltar(centro_techo + Vector3(0, 3.0, 0), Vector3(0, -16, 0))
	var min_y := INF
	for i in 50:
		await _fisica(1)
		min_y = minf(min_y, _j.global_position.y)
	_check("%s: en picada no atraviesa el techo (más baja: %.2f, techo: %.2f)" % [modelo, min_y - ALTO, y_techo],
		min_y >= ALTO + y_techo - 0.08)

	# 3) Posada en el techo, el auto arranca y anda: nunca se mete adentro del auto
	_soltar(centro_techo + Vector3(0, y_techo + 0.4, 0), Vector3.ZERO)
	for i in 30:
		await _fisica(1)
		if OS.has_environment("DEPURAR") and i % 5 == 0:
			print("    posando ", i, " ", a.to_local(_j.global_position), " ", _j.estado)
	_check("%s: se posa arriba del techo" % modelo, absf(a.to_local(_j.global_position).y - y_techo) < 0.1)
	var metida := false
	for i in 90:
		a.global_position += Vector3(11.0 / 60.0, 0, 0)
		await _fisica(1)
		var local := a.to_local(_j.global_position)
		if OS.has_environment("DEPURAR") and i % 6 == 0:
			print("    andando ", i, " ", local, " ", _j.estado)
		if absf(local.z) < 0.6 and local.x > -a.largo / 2.0 + 0.3 and local.x < a.largo / 2.0 - 0.3 \
				and local.y < y_techo - 0.15 and local.y > 0.2:
			metida = true
	_check("%s: posada con el auto andando no se mete en la cabina" % modelo, not metida)

	# 4) Volando de costado contra la cabina: no la atraviesa
	var lado := a.to_global(Vector3(x_techo, 1.05, 2.5))
	_soltar(lado, Vector3(0, 0, -10))
	var cruzo := false
	for i in 30:
		_j.velocity = Vector3(0, 0, -10.0)   # Derecho contra la ventanilla (sin el planeo hacia adelante)
		await _fisica(1)
		var l := a.to_local(_j.global_position)
		if l.z < -0.3 and absf(l.x - x_techo) < 0.8:
			cruzo = true
	_check("%s: de costado no atraviesa la cabina" % modelo, not cruzo)

	# 5) El auto avanza contra la paloma, que planea bajito a la altura de las ventanillas: no queda
	# adentro de la cabina (la empuja, o queda arriba)
	for altura in [0.85, 1.15]:
		a.global_position = ORIGEN
		await _fisica(2)
		_soltar(a.to_global(Vector3(a.largo / 2.0 + 1.0, altura, 0)), Vector3(0, -0.01, 0))
		var adentro := 0
		for i in 40:
			_j.velocity = Vector3(0, minf(_j.velocity.y, 0.0), 0)
			a.global_position += Vector3(11.0 / 60.0, 0, 0)
			await _fisica(1)
			var l := a.to_local(_j.global_position)
			if absf(l.z) < 0.5 and absf(l.x - x_techo) < 0.5 and l.y > 0.6 and l.y < y_techo - 0.2:
				adentro += 1
		_check("%s: el auto la choca a %.2f m y no queda adentro de la cabina" % [modelo, altura], adentro == 0)
	a.queue_free()
	await _fisica(2)


## El colectivo: la colisión sigue al techo de verdad (antes era una caja 18 cm más baja y 25 cm más
## angosta de cada lado, y la paloma se hundía en el techo), y no se mete adentro ni posada ni de costado.
func _probar_colectivo(modelo: String) -> void:
	var a := Auto.new()
	a.preparar(1.0)
	a.tipo = "colectivo"
	a.modelo = modelo
	a.largo = float(KitDatos.PIEZAS[modelo]["largo"])
	a.ancho = 2.5
	a.alto = 3.2
	_main.add_child(a)
	a.global_position = ORIGEN
	await _fisica(3)
	var tm := Kit.malla(modelo).generate_triangle_mesh()
	var espacio := get_viewport().world_3d.direct_space_state
	var peor := 0.0
	var x := -4.8   # (sin la curva de la cola: ahí la forma redondeada queda hasta 8 cm abajo)
	while x <= 5.2:
		for z in [-1.1, -0.5, 0.0, 0.5, 1.1]:
			var r := tm.intersect_ray(Vector3(x, 6, z), Vector3.DOWN)
			if r.is_empty():
				continue
			var y_malla: float = (r["position"] as Vector3).y
			var q := PhysicsRayQueryParameters3D.create(a.to_global(Vector3(x, 6, z)), a.to_global(Vector3(x, 0, z)), Auto.CAPA_GENTE)
			var h := espacio.intersect_ray(q)
			var y_col := a.to_local(h["position"]).y if not h.is_empty() else 0.0
			peor = maxf(peor, y_malla - y_col)
		x += 0.4
	_check("%s: la colisión llega al techo del modelo (lo más hundido: %.2f m)" % [modelo, peor], peor < 0.06)
	var costado := espacio.intersect_ray(PhysicsRayQueryParameters3D.create(a.to_global(Vector3(0, 1.5, 4)), a.to_global(Vector3(0, 1.5, 0)), Auto.CAPA_GENTE))
	var z_lado := a.to_local(costado["position"]).z if not costado.is_empty() else 0.0
	_check("%s: los costados están donde está la chapa (a %.2f m del centro)" % [modelo, z_lado], z_lado > 1.15)
	for punto: Vector3 in [Vector3(0, 0, 0), Vector3(4.5, 0, 0), Vector3(-3, 0, 0.8)]:
		var r := tm.intersect_ray(Vector3(punto.x, 6, punto.z), Vector3.DOWN)
		var y_techo: float = (r["position"] as Vector3).y
		_soltar(a.to_global(punto + Vector3(0, y_techo + 3.0, 0)), Vector3(0, -16, 0))
		var min_y := INF
		for i in 50:
			await _fisica(1)
			min_y = minf(min_y, a.to_local(_j.global_position).y)
		_check("%s: en picada en x=%.1f queda arriba del techo (más baja %.2f, techo %.2f)" % [modelo, punto.x, min_y, y_techo], min_y >= y_techo - 0.06)
	# Posada en el techo y el colectivo andando
	_soltar(a.to_global(Vector3(0, 3.8, 0)), Vector3.ZERO)
	await _fisica(30)
	var hundida := false
	for i in 120:
		a.global_position += Vector3(8.5 / 60.0, 0, 0)
		await _fisica(1)
		var l := a.to_local(_j.global_position)
		if absf(l.z) < 1.2 and absf(l.x) < 5.4 and l.y < 3.2 and l.y > 0.3:
			hundida = true
	_check("%s: posada con el colectivo andando no se hunde en el techo" % modelo, not hundida)
	# De costado contra las ventanillas
	a.global_position = ORIGEN
	await _fisica(2)
	_soltar(a.to_global(Vector3(0, 2.2, 3.0)), Vector3(0, 0, -10))
	var cruzo := false
	for i in 30:
		_j.velocity = a.global_transform.basis * Vector3(0, 0, -10.0)
		await _fisica(1)
		if a.to_local(_j.global_position).z < 1.0:
			cruzo = true
	_check("%s: de costado no se mete por las ventanillas" % modelo, not cruzo)
	a.queue_free()
	await _fisica(2)


## El parabrisas y la luneta (inclinados) tienen colisión: un rayo de arriba que cae justo delante (y
## detrás) del techo pega en el vidrio, bastante más arriba del capó; y las ventanillas a lo largo de la
## cabina frenan un rayo de costado. "a_mundo" pasa de coordenadas del auto al mundo.
func _ventanas(modelo: String, a_mundo: Callable, capa: int, que: String) -> void:
	var espacio := get_viewport().world_3d.direct_space_state
	var techo_x := INF
	var techo_x1 := -INF
	var techo_y := 0.0
	var capo := INF
	for s: Array in Kit.superficies_auto(modelo):
		var c: Vector3 = s[0]
		var t: Vector3 = s[1]
		capo = minf(capo, c.y + t.y / 2.0)
		if c.y + t.y / 2.0 > techo_y:
			techo_y = c.y + t.y / 2.0
			techo_x = c.x - t.x / 2.0
			techo_x1 = c.x + t.x / 2.0
	for lado in [["parabrisas", techo_x1 + 0.18], ["luneta", techo_x - 0.12]]:
		var x: float = lado[1]
		var q := PhysicsRayQueryParameters3D.create(a_mundo.call(Vector3(x, 2.5, 0)), a_mundo.call(Vector3(x, 0.2, 0)), capa)
		var r := espacio.intersect_ray(q)
		var y := -1.0 if r.is_empty() else (r["position"] as Vector3).y - (a_mundo.call(Vector3.ZERO) as Vector3).y
		_check("%s %s: el %s tiene colisión (pega a %.2f m; capó a %.2f)" % [modelo, que, lado[0], y, capo], y > capo + 0.12)
	var tapadas := 0
	var x := techo_x + 0.1
	while x < techo_x1 + 0.1:
		var q := PhysicsRayQueryParameters3D.create(a_mundo.call(Vector3(x, (capo + techo_y) / 2.0, 2.5)),
			a_mundo.call(Vector3(x, (capo + techo_y) / 2.0, -2.5)), capa)
		if not espacio.intersect_ray(q).is_empty():
			tapadas += 1
		x += 0.2
	_check("%s %s: las ventanillas frenan de punta a punta" % [modelo, que], tapadas >= int((techo_x1 - techo_x) / 0.2))


## El techo de cada modelo: [x del medio, altura] (ver Kit.superficies_auto: el bloque más alto).
func _techo(modelo: String) -> Array:
	var mejor: Array = [0.0, 0.0]
	for s: Array in Kit.superficies_auto(modelo):
		var c: Vector3 = s[0]
		var t: Vector3 = s[1]
		if c.y + t.y / 2.0 > float(mejor[1]):
			mejor = [c.x, c.y + t.y / 2.0]
	return mejor


func _soltar(pos: Vector3, vel: Vector3) -> void:
	_j.global_position = pos
	_j.reset_physics_interpolation()
	_j.velocity = vel
	_j.estado = PalomaJugador.Estado.AIRE if vel != Vector3.ZERO else _j.estado


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("  OK   " if ok else "  FALLA ") + nombre)
	if not ok:
		fallas += 1
