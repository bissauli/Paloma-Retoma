extends Node
## Prueba automática de logros y trofeos (headless):
## godot --headless --path . res://tests/test_logros.tscn
## Usa un archivo aparte y restaura todo: no toca el progreso del jugador.

const ARCHIVO_TEST := "user://test_logros.cfg"

var fallas := 0
var _archivo_real := ""
var _perfil_previo: PerfilPaloma


func _ready() -> void:
	_archivo_real = Logros.archivo
	_perfil_previo = PerfilPaloma._actual
	_nuevo_progreso()
	_catalogo()
	_contadores()
	_trofeos_de_fin()
	_intocable_falla()
	_misiones()
	_bailes()
	_perfil()
	_leyenda()
	_guardado()
	_inactivo()
	await _pantalla()
	# Restaurar
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_TEST))
	Logros.forzar = false
	Logros.archivo = _archivo_real
	Logros.cargar()
	Misiones.desde_dict({})
	GameState.capturas = 0
	GameState.tiempo_jugado = 0.0
	PerfilPaloma.fijar_actual(_perfil_previo)
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _nuevo_progreso() -> void:
	Logros.forzar = true
	Logros.archivo = ARCHIVO_TEST
	Logros.borrar_todo()


func _catalogo() -> void:
	var ids := {}
	var ok_ids := true
	var ok_stat := true
	var ok_texto := true
	for d: Dictionary in CatalogoLogros.LISTA:
		if ids.has(d["id"]):
			ok_ids = false
		ids[d["id"]] = true
		if d.has("stat") and int(d.get("meta", 0)) <= 0:
			ok_stat = false
		if d["tipo"] == CatalogoLogros.TROFEO and not CatalogoLogros.COLOR_NIVEL.has(d.get("nivel", "")):
			ok_stat = false
		# Todos los textos tienen traducción al inglés
		for k in ["nombre", "desc"]:
			if not TextosEN.MAPA.has(d[k]):
				ok_texto = false
				print("  sin traducción: ", d[k])
	_check("catálogo: ids únicos (%d)" % CatalogoLogros.LISTA.size(), ok_ids)
	_check("catálogo: los contadores tienen meta y los trofeos nivel", ok_stat)
	_check("catálogo: nombres y descripciones están en inglés", ok_texto)
	_check("catálogo: hay trofeos y logros", Logros.total(CatalogoLogros.TROFEO) >= 6 and Logros.total(CatalogoLogros.LOGRO) >= 10)
	_check("catálogo: están los trofeos pedidos", not CatalogoLogros.por_id("fin_juego").is_empty()
			and not CatalogoLogros.por_id("misiones_todas").is_empty() and not CatalogoLogros.por_id("intocable").is_empty())


func _contadores() -> void:
	var avisos: Array[String] = []
	var anotar := func(id: String) -> void: avisos.append(id)
	Logros.desbloqueado.connect(anotar)
	Logros.sumar("migas")
	_check("contador: la primera miga desbloquea 'Primer bocado'", Logros.hecho("primer_bocado") and avisos == ["primer_bocado"])
	Logros.sumar("migas")
	_check("contador: no se desbloquea dos veces", avisos.size() == 1)
	Logros.sumar("picoteos", 49)
	_check("contador: 49 picoteos todavía no", not Logros.hecho("picoteadora") and Logros.progreso("picoteadora")["actual"] == 49)
	Logros.sumar("picoteos")
	_check("contador: 50 picoteos sí", Logros.hecho("picoteadora"))
	Logros.maximo("bandada_max", 5.0)
	Logros.maximo("bandada_max", 3.0)
	_check("máximo: 5 palomas desbloquea 'Pandilla' y el máximo no baja", Logros.hecho("pandilla") and Logros.valor("bandada_max") == 5.0 and not Logros.hecho("bandada"))
	Logros.maximo("bandada_max", float(Config.BANDADA_MAX))
	_check("máximo: el tope de bandada desbloquea 15, 30 y el trofeo 'Nube de alas'", Logros.hecho("bandada") and Logros.hecho("multitud") and Logros.hecho("nube"))
	Logros.sumar("tiempo_vuelo", 30.5)
	_check("tiempo de vuelo: suma segundos con decimales", absf(Logros.valor("tiempo_vuelo") - 30.5) < 0.001 and not Logros.hecho("aviadora"))
	Logros.sumar("migas", 298)
	_check("trofeo por contador: 300 migas", Logros.hecho("miguera"))
	_check("cantidades por tipo", Logros.cantidad(CatalogoLogros.TROFEO) == 2 and Logros.cantidad(CatalogoLogros.LOGRO) >= 4)
	Logros.desbloqueado.disconnect(anotar)


func _trofeos_de_fin() -> void:
	_nuevo_progreso()
	GameState.capturas = 0
	GameState.tiempo_jugado = 420.0
	Logros._al_ganar()
	_check("fin del juego: trofeo 'La plaza es nuestra'", Logros.hecho("fin_juego"))
	_check("fin del juego: sin que te atrapen, 'Intocable'", Logros.hecho("intocable"))
	_check("fin del juego: en menos de 10 minutos, 'Vuelo directo'", Logros.hecho("velocista"))
	_nuevo_progreso()
	GameState.tiempo_jugado = 700.0
	Logros._al_ganar()
	_check("fin del juego lento: sigue el trofeo del final pero no 'Vuelo directo'", Logros.hecho("fin_juego") and not Logros.hecho("velocista"))


func _intocable_falla() -> void:
	_nuevo_progreso()
	GameState.capturas = 2
	GameState.tiempo_jugado = 300.0
	Logros._al_ganar()
	_check("atrapada antes del final: no hay 'Intocable'", Logros.hecho("fin_juego") and not Logros.hecho("intocable"))
	GameState.capturas = 0


func _misiones() -> void:
	_nuevo_progreso()
	Misiones.desde_dict({})
	Logros._al_cambiar_mision("migas_rosa", Misiones.ACTIVA)
	_check("misiones: una activa no cuenta", Logros.valor("misiones") == 0.0)
	Misiones.desde_dict({"misiones": {"migas_rosa": {"estado": "completada", "progreso": [5]}}})
	Logros._al_cambiar_mision("migas_rosa", Misiones.COMPLETADA)
	_check("misiones: completar una da 'Buena vecina'", Logros.hecho("buena_vecina"))
	var todas := true
	for id: String in CatalogoMisiones.MISIONES:
		if Misiones.estado(id) != Misiones.COMPLETADA:
			todas = false
	_check("misiones: todas las secundarias completadas dan 'Vecina del año' (hay %d)" % CatalogoMisiones.MISIONES.size(),
			Logros.hecho("misiones_todas") == todas)
	Misiones.desde_dict({})


func _bailes() -> void:
	_nuevo_progreso()
	Logros.registrar_baile(Coreografia.ORDEN[0])
	_check("bailes: el primero da 'A mover las plumas'", Logros.hecho("primer_baile") and not Logros.hecho("rey_baile"))
	Logros.registrar_baile(Coreografia.ORDEN[0])
	for b in Coreografia.ORDEN:
		Logros.registrar_baile(b)
	_check("bailes: repetir uno no completa la rueda", not Logros.hecho("rey_baile"))
	Logros.registrar_baile(Coreografia.FINAL)
	_check("bailes: todos los de la rueda dan 'Reina del baile'", Logros.hecho("rey_baile"))


func _perfil() -> void:
	_nuevo_progreso()
	var p := PerfilPaloma.new()
	PerfilPaloma.fijar_actual(p)
	Logros.revisar_perfil()
	_check("perfil vacío: no desbloquea nada", Logros.cantidad(CatalogoLogros.LOGRO) == 0)
	p.set_color(0, 3)
	Logros.revisar_perfil()
	_check("personalizar: 'Con estilo'", Logros.hecho("con_estilo") and not Logros.hecho("artista") and not Logros.hecho("camaleon"))
	var g := PinturaPaloma.golpe(Vector3(0.05, 0.45, 1.0), Vector3(0, 0, -1))
	PinturaPaloma.pintar(p.asegurar_pintura(), g["texel"], 1, Color.RED)
	Logros.revisar_perfil()
	_check("pintar: 'Artista'", Logros.hecho("artista") and not Logros.hecho("camaleon"))
	p.colores = PackedInt32Array([1, 2, 3, 4, 5, 6])
	p.accesorios = PackedInt32Array([1, 1, 1, 1])
	Logros.revisar_perfil()
	_check("todo a la vez: trofeo 'Camaleón'", Logros.hecho("camaleon"))


func _leyenda() -> void:
	_nuevo_progreso()
	for d: Dictionary in CatalogoLogros.LISTA:
		if d["id"] != "leyenda":
			if d["id"] == "fin_juego":
				_check("leyenda: antes de tener todo no está", not Logros.hecho("leyenda"))
			Logros.desbloquear(d["id"])
	_check("leyenda: con todo lo demás se desbloquea 'Paloma de leyenda'", Logros.hecho("leyenda"))
	_check("leyenda: todos los trofeos y logros", Logros.cantidad(CatalogoLogros.TROFEO) == Logros.total(CatalogoLogros.TROFEO)
			and Logros.cantidad(CatalogoLogros.LOGRO) == Logros.total(CatalogoLogros.LOGRO))


func _guardado() -> void:
	_nuevo_progreso()
	Logros.sumar("migas", 40)
	Logros.desbloquear("fin_juego")
	Logros.registrar_baile(&"disco")
	Logros.guardar()
	Logros._stats.clear()
	Logros._hechos.clear()
	Logros._bailes.clear()
	Logros.cargar()
	_check("guardado: vuelven los desbloqueados", Logros.hecho("fin_juego") and Logros.hecho("primer_bocado"))
	_check("guardado: vuelven los contadores", Logros.valor("migas") == 40.0 and Logros.valor("bailes") == 1.0)
	_check("guardado: vuelven los bailes distintos", Logros._bailes.has(&"disco"))
	# Un id que ya no existe se descarta
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_TEST)
	cfg.set_value("hechos", "logro_inventado", 1)
	cfg.save(ARCHIVO_TEST)
	Logros.cargar()
	_check("guardado: un logro que ya no existe se descarta", not Logros.hecho("logro_inventado") and Logros.hecho("fin_juego"))


func _inactivo() -> void:
	_nuevo_progreso()
	Logros.forzar = false
	GameState.guardado_habilitado = false
	Logros.sumar("migas", 5)
	if Logros.activo():
		Logros.desbloquear("fin_juego")
	_check("fuera del juego de verdad no cuenta (pruebas, bench)", Logros.valor("migas") == 0.0 and not Logros.hecho("fin_juego"))
	Logros.forzar = true


func _pantalla() -> void:
	_nuevo_progreso()
	Logros.desbloquear("fin_juego")
	Logros.sumar("picoteos", 20)
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(raiz)
	var menu := LogrosMenu.new()
	raiz.add_child(menu)
	menu.abrir()
	await get_tree().process_frame
	_check("pantalla: una fila por logro y trofeo", menu._filas.size() == CatalogoLogros.LISTA.size())
	var icono := menu._filas["fin_juego"]["icono"] as IconoTrofeo
	var otro := menu._filas["intocable"]["icono"] as IconoTrofeo
	_check("pantalla: el trofeo conseguido está de color y el que falta gris", not icono.bloqueado and otro.bloqueado)
	_check("pantalla: lo conseguido dice OBTENIDO", (menu._filas["fin_juego"]["valor"] as Label).text == "OBTENIDO")
	_check("pantalla: el avance se ve (20 / 50)", (menu._filas["picoteadora"]["valor"] as Label).text == "20 / 50")
	_check("pantalla: el resumen cuenta", menu._resumen.text.contains("1/%d" % Logros.total(CatalogoLogros.TROFEO)))
	_check("pantalla: las filas se pueden recorrer con el foco", (menu._filas["fin_juego"]["panel"] as Control).focus_mode == Control.FOCUS_ALL)
	menu.volver.pressed.emit()
	_check("pantalla: VOLVER cierra", not menu.visible)
	raiz.queue_free()
	# El aviso: encola y no se rompe con varios seguidos
	Logros.desbloquear("intocable")
	Logros.desbloquear("velocista")
	await get_tree().process_frame
	_check("aviso: varios desbloqueos seguidos quedan en cola", Logros._aviso._mostrando and Logros._aviso._cola.size() >= 1)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
