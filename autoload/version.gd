class_name Version
extends RefCounted
## Versión del juego, que se muestra chiquita debajo de las banderas del menú: "v0.12 (Manuel)".
## El número es la cantidad de commits (sube solo con cada commit) y entre paréntesis va quién hizo
## el último. En el editor se lee de git en el momento. En una build exportada no hay git: se usan
## los datos que dejó tools/generar_version.gd en info_version.gd (correrlo antes de exportar).

const BASE := "0"                                   ## Versión mayor: "v0.<commits>"
## Autores conocidos (se busca en el nombre y el correo del commit, sin importar mayúsculas)
const AUTORES := {"casimiro": "Manuel", "manuel": "Manuel", "bissauli": "Nahuel", "nahuel": "Nahuel"}

static var _datos := {}


## "v0.12 (Manuel)"
static func texto() -> String:
	return "%s (%s)" % [numero(), quien()]


static func numero() -> String:
	return "v%s.%d" % [BASE, datos()["commits"]]


## Primer nombre de quien hizo el último commit (Manuel o Nahuel; otro autor, su primer nombre).
static func quien() -> String:
	var d := datos()
	var firma := ("%s %s" % [d["autor"], d["correo"]]).to_lower()
	for clave: String in AUTORES:
		if firma.contains(clave):
			return AUTORES[clave]
	return String(d["autor"]).get_slice(" ", 0)


static func datos() -> Dictionary:
	if _datos.is_empty():
		if OS.has_feature("editor"):
			_datos = leer_git()
		if _datos.is_empty():
			_datos = {"commits": InfoVersion.COMMITS, "autor": InfoVersion.AUTOR,
				"correo": InfoVersion.CORREO, "hash": InfoVersion.HASH}
	return _datos


## Pregunta a git por los commits y el último autor. Vacío si no hay git o esto no es un repositorio.
static func leer_git() -> Dictionary:
	var carpeta := ProjectSettings.globalize_path("res://")
	var cuenta := _git(carpeta, ["rev-list", "--count", "HEAD"])
	var autor := _git(carpeta, ["log", "-1", "--format=%an"])
	var correo := _git(carpeta, ["log", "-1", "--format=%ae"])
	var hash_corto := _git(carpeta, ["log", "-1", "--format=%h"])
	if not cuenta.is_valid_int() or autor == "":
		return {}
	return {"commits": cuenta.to_int(), "autor": autor, "correo": correo, "hash": hash_corto}


static func _git(carpeta: String, args: Array) -> String:
	var salida: Array = []
	var todos: PackedStringArray = ["-C", carpeta]
	todos.append_array(PackedStringArray(args))
	if OS.execute("git", todos, salida, true) != 0 or salida.is_empty():
		return ""
	return String(salida[0]).strip_edges()
