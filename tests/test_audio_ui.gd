extends Node
## Prueba automática de los sonidos de interfaz (headless):
## godot --headless --path . res://tests/test_audio_ui.tscn

var fallas := 0


func _ready() -> void:
	var faltan: Array[String] = []
	for k: String in AudioManager.UI:
		if not AudioManager._ui.has(k):
			faltan.append("%s (%s.wav)" % [k, AudioManager.UI[k]])
	_check("todos los sonidos de interfaz están cargados (%d)" % AudioManager.UI.size(), faltan.is_empty())
	if not faltan.is_empty():
		print("  faltan: ", faltan)
	var cortos := true
	var largos: Array[String] = []
	for k: String in AudioManager._ui:
		var s := AudioManager._ui[k] as AudioStreamWAV
		if s == null or s.get_length() > 2.5 or s.get_length() < 0.02:
			cortos = false
			largos.append(k)
	_check("duran entre 0,02 y 2,5 s (recortados): %s" % str(largos), cortos)
	for k: String in AudioManager.UI:
		AudioManager.ui(k, -40.0)
	AudioManager.ui("no_existe")
	_check("tocar todos (y uno que no existe) no rompe", true)
	_check("salen por el bus de efectos", AudioServer.get_bus_index(&"Efectos") >= 0)
	# Cada uso del juego apunta a un sonido que existe
	var usados := {}
	for ruta in ["res://ui", "res://autoload", "res://enemies", "res://world", "res://flock", "res://player"]:
		_buscar(ruta, usados)
	var desconocidos: Array[String] = []
	for k: String in usados:
		if not AudioManager.UI.has(k):
			desconocidos.append(k)
	_check("el código sólo usa sonidos de interfaz que existen (%d usados) %s" % [usados.size(), str(desconocidos)], desconocidos.is_empty())
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Junta los nombres que se pasan a AudioManager.ui("...") en los scripts de una carpeta.
func _buscar(carpeta: String, usados: Dictionary) -> void:
	var re := RegEx.create_from_string("AudioManager\\.ui\\(\\s*\"([a-z_]+)\"|AudioManager\\.ui\\(\"[a-z_]+\"\\s+if\\s+\\w+\\s+else\\s+\"([a-z_]+)\"|AudioManager\\.ui\\(\\s*\"([a-z_]+)\"\\s+if")
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var t := FileAccess.get_file_as_string(carpeta.path_join(f))
			for m in re.search_all(t):
				for g in range(1, 4):
					if m.get_string(g) != "":
						usados[m.get_string(g)] = true
			# El segundo nombre de un "a si no b" (ui("a" if x else "b"))
			var re2 := RegEx.create_from_string("AudioManager\\.ui\\([^\\n]*? else \"([a-z_]+)\"")
			for m in re2.search_all(t):
				usados[m.get_string(1)] = true
	for d in dir.get_directories():
		_buscar(carpeta.path_join(d), usados)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
