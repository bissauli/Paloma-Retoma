extends Node
## Las seguidoras entran con la jugadora a las salas (locales y departamentos): la jugadora vuela de
## afuera, por la ventana de adelante (en los locales, por la puerta), hasta el medio del cuarto (por la ruta de la sala, a 5 m/s) y se
## queda ahí; con 12 seguidoras, cuenta cuántas quedaron adentro. Antes iban derecho a su lugar en la
## formación (unos metros alrededor de ella), que adentro cae del otro lado de las paredes, y se
## quedaban aplastadas contra la fachada.
## godot --headless --path . res://tests/test_bandada_interior.tscn

const SEGUIDORAS := 12
const VEL := 5.0

var fallas := 0
var paloma: PalomaJugador
var bandada: Bandada


func _ready() -> void:
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().physics_frame
	paloma = main.get_node("Paloma") as PalomaJugador
	paloma.set_physics_process(false)    # La mueve la prueba
	GameState.menu_activo = false
	GameState.en_partida = true
	bandada = get_tree().get_first_node_in_group("bandada") as Bandada
	var salas := get_tree().get_nodes_in_group("casa_enterable")
	var total := 0
	var adentro := 0
	var probadas := 0
	var peor := SEGUIDORAS
	for n in salas:
		var ce := n as CasaEnterable
		if probadas >= 8:
			break
		probadas += 1
		var k := await _probar(ce)
		print("  %s (%s): %d de %d adentro" % [ce.name, ce.tema, k, SEGUIDORAS])
		total += SEGUIDORAS
		adentro += k
		peor = mini(peor, k)
	_check("en promedio entran casi todas (%d de %d)" % [adentro, total], adentro >= total * 0.85)
	_check("en ninguna sala se quedan afuera más de 4 (lo peor: %d adentro)" % peor, peor >= SEGUIDORAS - 4)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(0 if fallas == 0 else 1)


## La jugadora entra a la sala con sus seguidoras; devuelve cuántas quedaron adentro.
func _probar(ce: CasaEnterable) -> int:
	var t := Construir.global_de(ce)
	var inicio := Vector3(ce.x_frente, CasaEnterable.Y_PASO, ce.fondo / 2.0 + 9.0)
	var pts := ce.puntos_ruta(true, inicio)
	# Hasta la mitad de la ruta de adentro (pts: inicio, frente de la ventana, la ruta, la salida...)
	var hasta := 2 + ce.ruta.size() / 2
	var camino: Array[Vector3] = []
	for i in mini(hasta, pts.size()):
		var q := pts[i]
		if not ce.con_cinematica:
			q.y = 1.1   # A los locales se entra por la puerta (la ruta de la sala pasa por arriba del marco)
		camino.append(t * q)
	if not ce.con_cinematica:
		camino.append(t * Vector3(ce.x_frente * 0.5, 1.1, 0.0))   # Hasta el medio del local
	# Afuera, con la bandada armada
	_poner(camino[0], Vector3.ZERO)
	var mias: Array[PalomaNPC] = []
	for i in SEGUIDORAS:
		var p := bandada._nueva_paloma(camino[0] + Vector3(randf_range(-3, 3), randf_range(0, 1.5), randf_range(-3, 3)))
		p.reclutar()
		bandada.seguidoras.append(p)
		mias.append(p)
	for i in 120:
		_poner(camino[0], Vector3.ZERO)
		await get_tree().physics_frame
	# Entra volando por la ventana hasta el medio del cuarto
	for i in range(1, camino.size()):
		var a := camino[i - 1]
		var b := camino[i]
		var largo := a.distance_to(b)
		var pasos := maxi(1, int(largo / VEL * 60.0))
		for s in pasos:
			_poner(a.lerp(b, float(s + 1) / pasos), (b - a).normalized() * VEL)
			await get_tree().physics_frame
	for i in 300:   # 5 s quieta en el medio
		_poner(camino[camino.size() - 1], Vector3.ZERO)
		await get_tree().physics_frame
	var k := 0
	for p in mias:
		if ce.contiene(p.global_position):
			k += 1
	if k < SEGUIDORAS - 2:   # Dónde quedaron las de afuera (para entender qué las frena)
		var tinv := Construir.global_de(ce).affine_inverse()
		print("   jugadora en %s (local); puerta x=%.1f, sala %.0f x %.0f" % [(tinv * camino[camino.size() - 1]).snapped(Vector3.ONE * 0.1),
			ce.x_frente, ce.ancho, ce.fondo])
		for p in mias:
			if not ce.contiene(p.global_position):
				print("   afuera en %s (local), miga %d" % [(tinv * p.global_position).snapped(Vector3.ONE * 0.1), p.miga])
	for p in mias:
		bandada.seguidoras.erase(p)
		GameState.registrar_seguidora(-1)
		p.queue_free()
	await get_tree().physics_frame
	return k


func _poner(pos: Vector3, vel: Vector3) -> void:
	paloma.global_position = pos
	paloma.velocity = vel
	paloma.estado = PalomaJugador.Estado.AIRE


func _check(texto: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALLA ") + texto)
	if not ok:
		fallas += 1
