extends SceneTree
## Escribe autoload/info_version.gd con los datos de git del momento (cantidad de commits y último
## autor), para que las builds exportadas, que no tienen git, muestren la versión correcta.
## Correrlo ANTES de exportar y después del último commit:
##   godot --headless --path . --script tools/generar_version.gd
## Con "-- siguiente" escribe los datos del commit que se va a hacer (uno más, con el autor de
## git config): sirve para exportar la build y subirla en ese mismo commit.

const ARCHIVO := "res://autoload/info_version.gd"


func _init() -> void:
	var d := Version.leer_git()
	if d.is_empty():
		push_error("No pude leer git: no se tocó %s" % ARCHIVO)
		quit(1)
		return
	if "siguiente" in OS.get_cmdline_user_args():
		var carpeta := ProjectSettings.globalize_path("res://")
		d["commits"] = int(d["commits"]) + 1
		d["autor"] = Version._git(carpeta, ["config", "user.name"])
		d["correo"] = Version._git(carpeta, ["config", "user.email"])
		d["hash"] = "siguiente de " + String(d["hash"])
		Version._datos = d
	var f := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	f.store_string('''class_name InfoVersion
extends RefCounted
## GENERADO por tools/generar_version.gd (no editar a mano): los datos de git que usa Version en las
## builds exportadas, donde no hay git. Se regenera antes de exportar:
##   godot --headless --path . --script tools/generar_version.gd

const COMMITS := %d
const AUTOR := "%s"
const CORREO := "%s"
const HASH := "%s"
''' % [d["commits"], d["autor"], d["correo"], d["hash"]])
	f.close()
	print("info_version.gd: v%s.%d (%s) %s" % [Version.BASE, d["commits"], Version.quien(), d["hash"]])
	quit()
