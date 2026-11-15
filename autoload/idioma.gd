class_name Idioma
extends RefCounted
## Idiomas del juego (español e inglés). Los textos del código y de las escenas están en español y
## ese texto es la clave de la traducción (ver textos_en.gd). Ajustes guarda la elección y llama
## acá; el selector de banderas del menú principal es ui/menu/selector_idioma.gd.

const CODIGOS: Array[String] = ["es", "en"]
const NOMBRES := {"es": "Español", "en": "English"}
const BANDERAS := {
	"es": preload("res://ui/tema/iconos/bandera_ar.svg"),
	"en": preload("res://ui/tema/iconos/bandera_gb.svg"),
}

static var _instalado := false


## Registra las traducciones (una sola vez). El español también tiene la suya, "identidad":
## sin ella Godot caería al idioma de respaldo del proyecto (inglés) con el juego en español.
static func instalar() -> void:
	if _instalado:
		return
	_instalado = true
	var es := Translation.new()
	es.locale = "es"
	var en := Translation.new()
	en.locale = "en"
	for clave: String in TextosEN.MAPA:
		var ingles: String = TextosEN.MAPA[clave]
		_agregar(es, clave, clave)
		_agregar(en, clave, ingles)
	TranslationServer.add_translation(es)
	TranslationServer.add_translation(en)


## Agrega el par y su versión en mayúsculas (muchos textos del menú y del HUD se muestran así).
static func _agregar(t: Translation, clave: String, texto: String) -> void:
	t.add_message(clave, texto)
	var clave_mayus := clave.to_upper()
	if clave_mayus != clave and t.get_message(clave_mayus) == StringName():
		t.add_message(clave_mayus, texto.to_upper())


static func es_valido(codigo: String) -> bool:
	return CODIGOS.has(codigo)


## El idioma del sistema si es español; si no, inglés.
static func por_defecto() -> String:
	return "es" if OS.get_locale_language() == "es" else "en"


static func aplicar(codigo: String) -> void:
	instalar()
	TranslationServer.set_locale(codigo if es_valido(codigo) else "es")


static func actual() -> String:
	return TranslationServer.get_locale().left(2)


## Fecha y hora como se escriben en el idioma actual (dd/mm/aaaa en español, mm/dd/aaaa en inglés).
static func fecha(d: Dictionary) -> String:
	if actual() == "en":
		return "%02d/%02d/%d" % [d.month, d.day, d.year]
	return "%02d/%02d/%d" % [d.day, d.month, d.year]


static func hora(d: Dictionary) -> String:
	return "%02d:%02d" % [d.hour, d.minute]
