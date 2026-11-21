extends Node
## Prueba automática del tránsito (corre headless, sin la plaza: sólo las rutas y los autos):
## godot --headless --path . res://tests/test_transito.tscn [-- minutos]
## Simula varios minutos de tránsito con distintas semillas (siempre las mismas: da siempre igual) y mira
## que no se trabe:
## - Que ningún auto quede parado tanto como para tener que destrabarse (Transito.ESPERA_MAX). Antes se
##   armaban nudos en los cruces que duraban minutos: el de atrás tenía el turno del cruce y el de adelante
##   lo esperaba, o uno quedaba parado adentro del cruce detrás de la cola de la cuadra siguiente.
## - Que los autos no se monten unos sobre otros (cajas que se pisan en planta).
## - Que sigan saliendo autos por los túneles (el tránsito fluye).

const PASO := 1.0 / 60.0
const SEMILLAS := [1, 2, 3, 4]
const SOLAPE := 0.25             ## Margen: dos cajas que se pisan menos que esto no cuentan

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_transito.cfg"
	GameState.guardado_habilitado = false
	var minutos := 6.0
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		minutos = float(args[0])
	var peor_parado := 0.0
	var destrabes := 0
	var solapes := 0
	var salidas_min := INF
	for semilla: int in SEMILLAS:
		var r := await _simular(semilla, minutos)
		print("semilla %d: salieron %d autos (%.1f por minuto), parado como mucho %.1f s, %d destrabes, %d solapes, nudo más largo %.1f s"
			% [semilla, r["salidas"], r["salidas"] / minutos, r["parado"], r["destrabes"], r["solapes"], r["nudo"]])
		peor_parado = maxf(peor_parado, r["parado"])
		destrabes += int(r["destrabes"])
		solapes += int(r["solapes"])
		salidas_min = minf(salidas_min, r["salidas"] / minutos)
	_check("ningún auto queda trabado: ninguno pasa %d s parado y tiene que destrabarse (peor: %.1f s)"
		% [Transito.ESPERA_MAX, peor_parado], destrabes == 0)
	_check("los autos no se montan unos sobre otros (%d solapes)" % solapes, solapes == 0)
	_check("el tránsito fluye: salen al menos 20 autos por minuto (peor: %.1f)" % salidas_min, salidas_min >= 20.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _simular(semilla: int, minutos: float) -> Dictionary:
	seed(semilla)
	var t := Transito.new()
	add_child(t)
	t.set_physics_process(false)   # Lo avanza esta prueba, paso a paso y sin esperar cuadros
	var parado := {}               # Auto -> segundos seguidos parado
	var peor := 0.0
	var destrabes := 0
	var salidas := 0
	var solapes := 0
	var pisando := {}              # "id_id" -> true mientras dos autos se pisan (cuenta una vez cada choque)
	var nudo := 0.0                # Segundos seguidos con 6 o más autos parados a la vez
	var peor_nudo := 0.0
	var pasos := int(minutos * 60.0 / PASO)
	for i in pasos:
		var antes := t._autos.size()
		var vivos := {}
		for a in t._autos:
			vivos[a] = true
		t._physics_process(PASO)
		for a: Auto in vivos:
			if not is_instance_valid(a) or not t._autos.has(a):
				salidas += 1
				parado.erase(a)
		var quietos := 0
		for a in t._autos:
			if a.velocidad < 0.3:
				quietos += 1
				var antes_p: float = parado.get(a, 0.0)
				parado[a] = antes_p + PASO
				if antes_p <= Transito.ESPERA_MAX and antes_p + PASO > Transito.ESPERA_MAX:
					destrabes += 1
				peor = maxf(peor, parado[a])
			else:
				parado[a] = 0.0
		nudo = nudo + PASO if quietos >= 6 else 0.0
		peor_nudo = maxf(peor_nudo, nudo)
		if i % 6 == 0:
			solapes += _contar_solapes(t._autos, pisando)
		if antes == 0 and t._autos.is_empty():
			break
		if i % 3600 == 0:
			await get_tree().process_frame
	t.queue_free()
	await get_tree().process_frame
	return {"salidas": salidas, "parado": peor, "destrabes": destrabes, "solapes": solapes, "nudo": peor_nudo}


## Pares de autos cuyas cajas (en planta) se pisan; cada choque cuenta una sola vez.
func _contar_solapes(autos: Array[Auto], pisando: Dictionary) -> int:
	var nuevos := 0
	var ahora := {}
	for i in autos.size():
		var a := autos[i]
		for j in range(i + 1, autos.size()):
			var b := autos[j]
			var lejos := (a.largo + b.largo) / 2.0
			if a.global_position.distance_squared_to(b.global_position) > lejos * lejos:
				continue
			if _se_pisan(a, b):
				var k := "%d_%d" % [a.get_instance_id(), b.get_instance_id()]
				ahora[k] = true
				if not pisando.has(k):
					nuevos += 1
					print("  solape: %s (ruta %s, s %.1f, v %.1f) y %s (ruta %s, s %.1f, v %.1f) en %s" % [a.tipo,
						a.ruta, a.s, a.velocidad, b.tipo, b.ruta, b.s, b.velocidad, a.global_position.snapped(Vector3.ONE * 0.1)])
	pisando.clear()
	pisando.merge(ahora)
	return nuevos


## Dos rectángulos en planta (largo x ancho, girados) que se pisan más que SOLAPE (ejes separadores).
func _se_pisan(a: Auto, b: Auto) -> bool:
	var ca := Vector2(a.global_position.x, a.global_position.z)
	var cb := Vector2(b.global_position.x, b.global_position.z)
	var fa := Vector2(a.adelante().x, a.adelante().z).normalized()
	var fb := Vector2(b.adelante().x, b.adelante().z).normalized()
	var ha := Vector2(a.largo, a.ancho) / 2.0 - Vector2.ONE * SOLAPE
	var hb := Vector2(b.largo, b.ancho) / 2.0 - Vector2.ONE * SOLAPE
	for eje: Vector2 in [fa, fa.orthogonal(), fb, fb.orthogonal()]:
		var ra := ha.x * absf(fa.dot(eje)) + ha.y * absf(fa.orthogonal().dot(eje))
		var rb := hb.x * absf(fb.dot(eje)) + hb.y * absf(fb.orthogonal().dot(eje))
		if absf((cb - ca).dot(eje)) > ra + rb:
			return false
	return true


func _check(desc: String, ok: bool) -> void:
	print(("OK    " if ok else "FALLA ") + desc)
	if not ok:
		fallas += 1
