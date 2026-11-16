extends Node
## Prueba automática de las coreografías de los créditos (headless):
## godot --headless --path . res://tests/test_bailes.tscn
## Recorre cada baile a 60 cuadros por segundo y revisa que nunca haya un salto brusco (un tramo mal
## empalmado se vería como un tirón), que los números sean válidos y que la paloma no se hunda en el piso.

const PASO := 1.0 / 60.0
const MAX_GIRO_POR_CUADRO := deg_to_rad(40.0)
const MAX_SALTO_POR_CUADRO := 0.08

var fallas := 0


func _ready() -> void:
	var bailes: Array[StringName] = Coreografia.ORDEN.duplicate()
	bailes.append(Coreografia.FINAL)
	bailes.append(Coreografia.BANO)   # No está en la rueda ni en los créditos, pero tiene que andar igual de bien
	_check("hay al menos un baile por cada paloma de los créditos", Coreografia.ORDEN.size() >= 9)
	_check("el primero es el break dance", Coreografia.ORDEN[0] == &"breakdance")
	_check("el cortejo está en la rueda", Coreografia.ORDEN.has(&"cortejo"))
	_check("el cortejo vuelve a empezar igual: la pose final es la inicial", _igual(Coreografia.pose(&"cortejo", 0.0),
		Coreografia.pose(&"cortejo", Coreografia.duracion(&"cortejo") - 0.0001)))
	_check("el baño vuelve a empezar igual: la pose final es la inicial", _igual(Coreografia.pose(&"bano", 0.0),
		Coreografia.pose(&"bano", Coreografia.duracion(&"bano") - 0.0001)))
	_check("el momento del cortejo cae dentro del baile", Coreografia.MOMENTO_CORTEJO > 0.0
		and Coreografia.MOMENTO_CORTEJO < Coreografia.duracion(&"cortejo"))
	var inflado := Coreografia.pose(&"cortejo", 1.0)
	_check("el cortejo infla el cuello y abre la cola", inflado.escala_cabeza.x > 1.15 and inflado.escala_cola.x > 1.7)
	_check("el cortejo no engorda el resto del tiempo (empieza y termina sin inflar)",
		Coreografia.pose(&"cortejo", 0.0).escala_cabeza.distance_to(Vector3.ONE) < 0.001
		and Coreografia.pose(&"cortejo", 7.99).escala_cola.distance_to(Vector3.ONE) < 0.001)
	for baile in bailes:
		_revisar(baile)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _revisar(baile: StringName) -> void:
	var dur := Coreografia.duracion(baile)
	var anterior := Coreografia.pose(baile, 0.0)
	var peor_giro := 0.0
	var t_peor := 0.0
	var peor_salto := 0.0
	var invalida := false
	var hundida := false
	var t := PASO
	while t <= dur:
		var p := Coreografia.pose(baile, t)
		for q in [p.rot, p.cuerpo, p.cabeza, p.cola, p.ala_izq, p.ala_der, p.pata_izq, p.pata_der]:
			if not (q as Basis).is_finite():
				invalida = true
		if not p.pos.is_finite():
			invalida = true
		if p.pos.y < -0.15:
			hundida = true
		var giro_cuerpo := p.rot.get_rotation_quaternion().angle_to(anterior.rot.get_rotation_quaternion())
		if giro_cuerpo > peor_giro:
			t_peor = t
		peor_giro = maxf(peor_giro, giro_cuerpo)
		for par in [[p.cabeza, anterior.cabeza], [p.ala_izq, anterior.ala_izq], [p.ala_der, anterior.ala_der],
				[p.pata_izq, anterior.pata_izq], [p.pata_der, anterior.pata_der], [p.cola, anterior.cola]]:
			peor_giro = maxf(peor_giro, (par[0] as Basis).get_rotation_quaternion().angle_to((par[1] as Basis).get_rotation_quaternion()))
		peor_salto = maxf(peor_salto, p.pos.distance_to(anterior.pos))
		anterior = p
		t += PASO
	_check("%s: sin números inválidos" % baile, not invalida)
	_check("%s: no se hunde en el piso" % baile, not hundida)
	_check("%s: sin giros bruscos (peor %.0f° por cuadro, en t=%.2f s)" % [baile, rad_to_deg(peor_giro), t_peor], peor_giro <= MAX_GIRO_POR_CUADRO)
	_check("%s: sin saltos bruscos de posición (peor %.3f m)" % [baile, peor_salto], peor_salto <= MAX_SALTO_POR_CUADRO)


## ¿Dos poses son (casi) la misma? Sirve para ver que un baile en bucle empalma sin tirón.
func _igual(a: PoseBaile, b: PoseBaile) -> bool:
	if a.pos.distance_to(b.pos) > 0.001 or a.escala_cabeza.distance_to(b.escala_cabeza) > 0.001 or a.escala_cola.distance_to(b.escala_cola) > 0.001:
		return false
	for par in [[a.rot, b.rot], [a.cabeza, b.cabeza], [a.cola, b.cola], [a.ala_izq, b.ala_izq], [a.ala_der, b.ala_der],
			[a.pata_izq, b.pata_izq], [a.pata_der, b.pata_der]]:
		if (par[0] as Basis).get_rotation_quaternion().angle_to((par[1] as Basis).get_rotation_quaternion()) > 0.01:
			return false
	return true


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
