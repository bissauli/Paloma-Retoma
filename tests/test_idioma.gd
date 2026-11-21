extends Node
## Prueba automática del cambio de idioma (headless):
## godot --headless --path . res://tests/test_idioma.tscn
## Usa un archivo de opciones aparte: no toca las del jugador.

var fallas := 0


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_idioma.cfg"
	Ajustes.idioma = ""
	Ajustes.set_idioma("es")
	_check("en español los textos quedan como están", tr("SALIR") == "SALIR" and tr("Opciones") == "Opciones")
	_check("en español también las mayúsculas automáticas", tr("MÚSICA") == "MÚSICA")

	var avisos: Array[String] = []
	Ajustes.idioma_cambiado.connect(func() -> void: avisos.append(Ajustes.idioma))
	Ajustes.set_idioma("en")
	_check("al elegir inglés se traduce", tr("SALIR") == "QUIT" and tr("NUEVA PARTIDA") == "NEW GAME")
	_check("las mayúsculas automáticas se traducen", tr("MÚSICA") == "MUSIC" and tr("RESOLUCIÓN") == "RESOLUTION")
	_check("avisa el cambio una sola vez", avisos == ["en"])
	Ajustes.set_idioma("en")
	_check("elegir el mismo idioma no avisa de nuevo", avisos.size() == 1)
	Ajustes.set_idioma("fr")
	_check("un idioma que no existe se ignora", Ajustes.idioma == "en" and avisos.size() == 1)

	# Un Label de la escena se traduce solo
	var l := Label.new()
	l.text = "PAUSA"
	add_child(l)
	_check("un Label traduce su texto", l.atr("PAUSA") == "PAUSED")
	_check("los textos con formato siguen funcionando",
		tr("NIDO · comida %d") % 7 == "NEST · food 7" and tr("Llevá la %s al nido, en la Pirámide de Mayo") % tr("medialuna") == "Take the croissant to the nest, at the May Pyramid")
	# Los carteles 3D del mundo (locales, kioscos, letreros) se traducen solos, también si se cambia
	# el idioma con el cartel ya armado
	var c3 := Construir.cartel(self, Vector3.ZERO, "Panadería La Espiga")
	await get_tree().process_frame
	_check("un cartel 3D se traduce", c3.atr(c3.text) == "La Espiga Bakery")
	_check("los carteles salientes verticales se traducen", tr("L\nI\nB\nR\nO\nS") == "B\nO\nO\nK\nS")
	_check("los carteles con número se traducen", tr("PASILLO 3") == "AISLE 3")
	_check("el tamaño del cartel mira el idioma más largo",
		Idioma.largo("Kiosco El Pibe") == "El Pibe Kiosk".length() + 1 and Idioma.largo("Casa de Cambio La Moneda") == "The Coin Currency Exchange".length())
	_check("los pisos de los departamentos se traducen", tr("%d.º %s") % [4, "B"] == "Apt 4B")
	Ajustes.set_idioma("es")
	_check("el cartel 3D vuelve a español", c3.atr(c3.text) == "Panadería La Espiga" and tr("PASILLO 3") == "PASILLO 3")
	Ajustes.set_idioma("en")
	_check("la fecha va en el orden del idioma", Idioma.fecha({"day": 3, "month": 11, "year": 2026}) == "11/03/2026")

	# Se guarda y se recupera
	var cfg := ConfigFile.new()
	cfg.load(Ajustes.ARCHIVO)
	_check("se guarda en el archivo de opciones", cfg.get_value("general", "idioma", "") == "en")

	# Todos los pares del diccionario: mismos marcadores de formato y nada vacío
	var mal := 0
	var re := RegEx.create_from_string("%[0-9]*[sd]")
	for clave: String in TextosEN.MAPA:
		var ingles: String = TextosEN.MAPA[clave]
		if ingles.strip_edges() == "" or re.search_all(clave).size() != re.search_all(ingles).size():
			mal += 1
			print("  par con problema: ", clave)
	_check("todos los pares del diccionario son válidos (%d)" % TextosEN.MAPA.size(), mal == 0)

	Ajustes.set_idioma("es")
	_check("se puede volver a español", tr("SALIR") == "SALIR")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
