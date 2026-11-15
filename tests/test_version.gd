extends Node
## Prueba automática de la versión que se muestra en el menú (headless):
## godot --headless --path . res://tests/test_version.tscn

var fallas := 0


func _ready() -> void:
	var original := Version._datos
	Version._datos = {"commits": 12, "autor": "Manuel Casimiro", "correo": "manuel.casimiro.et26@gmail.com", "hash": "abc"}
	_check("el número sale de la cantidad de commits", Version.numero() == "v0.12")
	_check("un commit de Manuel dice Manuel", Version.quien() == "Manuel" and Version.texto() == "v0.12 (Manuel)")
	Version._datos = {"commits": 40, "autor": "bissauli", "correo": "bissauli@users.noreply.github.com", "hash": "abc"}
	_check("un commit de bissauli dice Nahuel", Version.quien() == "Nahuel" and Version.texto() == "v0.40 (Nahuel)")
	Version._datos = {"commits": 3, "autor": "Ana Pérez", "correo": "ana@example.com", "hash": "abc"}
	_check("otro autor muestra su primer nombre", Version.quien() == "Ana")
	Version._datos = original

	var git := Version.leer_git()
	_check("lee los datos de git del repositorio", not git.is_empty() and git["commits"] > 0 and git["autor"] != "")
	_check("los datos de las builds exportadas existen", InfoVersion.COMMITS > 0 and InfoVersion.AUTOR != "")
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
