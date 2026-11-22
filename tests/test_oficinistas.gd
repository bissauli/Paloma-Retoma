extends Node
## Los oficinistas que salen del subte (headless):
## godot --headless --path . res://tests/test_oficinistas.tscn
## Salen en oleadas, cruzan la plaza sin atravesar nada, no se apilan unos sobre otros, llegan a su
## salida y desaparecen: con el tiempo no se acumulan trabados por la plaza ni por la ciudad.

const SEGUNDOS := 150.0          ## Tiempo de juego simulado
const VIDA_MAX := 100.0           ## Ninguno debería seguir dando vueltas más que esto

var fallas := 0


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	var gente := main.get_node_or_null("Gente")
	if gente != null:
		gente.set("intervalo_oleada", 12.0)   # más oleadas en menos tiempo
	await _frames(40)
	var nav: Dictionary = gente.get("_nav_plaza") if gente != null else {}
	var salidas: Array = gente.get("_salidas") if gente != null else []
	print("  malla de la plaza: ", nav.get("poligonos", 0), " polígonos; salidas alcanzables: ", salidas.size(), " de ",
		gente.get("SALIDAS").size() if gente != null else 0)
	_check("la plaza tiene malla de navegación", int(nav.get("poligonos", 0)) > 0)
	_check("hay al menos 3 salidas alcanzables desde el subte", salidas.size() >= 3)
	Engine.time_scale = 4.0
	var nacio := {}          # id -> segundo en que apareció
	var vistos := 0
	var se_fueron := 0
	var max_vivos := 0
	var pegados := 0         # muestras con dos oficinistas a menos de 0,35 m
	var muestras := 0
	var mas_viejo := 0.0
	var donde_viejo := Vector3.ZERO
	var t := 0.0
	var fuera := 0           # muestras de oficinistas fuera de la plaza
	while t < SEGUNDOS:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()   # ya viene escalado por time_scale
		var ofis: Array = get_tree().get_nodes_in_group("humanos").filter(func(n: Node) -> bool:
			return n is Humano and (n as Humano).tipo == "oficinista" and not n.is_queued_for_deletion())
		var vivos := {}
		for h: Humano in ofis:
			var id := h.get_instance_id()
			vivos[id] = true
			if not nacio.has(id):
				nacio[id] = t
				vistos += 1
			var edad: float = t - float(nacio[id])
			if edad > mas_viejo:
				mas_viejo = edad
				donde_viejo = h.global_position
		for id: int in nacio.keys():
			if not vivos.has(id) and nacio[id] >= 0.0:
				se_fueron += 1
				nacio[id] = -1.0e9   # ya contado
		max_vivos = maxi(max_vivos, ofis.size())
		if Engine.get_physics_frames() % 10 == 0:
			muestras += 1
			for i in ofis.size():
				var a := ofis[i] as Humano
				if not Ciudad.PLAZA.grow(3.0).has_point(Vector2(a.global_position.x, a.global_position.z)):
					fuera += 1
				for j in range(i + 1, ofis.size()):
					var b := ofis[j] as Humano
					if Enemigo.plano(a.global_position - b.global_position).length() < 0.35:
						pegados += 1
	Engine.time_scale = 1.0
	print("  oficinistas que salieron: ", vistos, ", se fueron: ", se_fueron, ", máximo a la vez: ", max_vivos)
	print("  el que más tardó: ", snappedf(mas_viejo, 0.1), " s (en ", donde_viejo.snappedf(0.1), ")")
	print("  muestras con dos pegados: ", pegados, " de ", muestras, "; muestras fuera de la plaza: ", fuera)
	_check("salen oficinistas del subte", vistos >= 10)
	_check("casi todos llegan a su salida y desaparecen", se_fueron >= vistos - max_vivos and se_fueron >= vistos * 0.6)
	_check("ninguno queda dando vueltas más de %d s" % int(VIDA_MAX), mas_viejo < VIDA_MAX)
	_check("no se apilan unos sobre otros", pegados <= muestras / 20)
	_check("no se escapan de la plaza", fuera == 0)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1
