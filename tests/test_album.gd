extends Node
## Prueba automática del álbum de fotos (corre headless):
## godot --headless --path . res://tests/test_album.tscn
## Guarda fotos de prueba, comprueba el listado (más nueva primero), las miniaturas, la grilla, el visor
## (pasar, borrar con confirmación) y que el botón ÁLBUM de la pausa lo abre. Limpia lo que crea.

var fallas := 0
var _creadas: Array[String] = []


func _ready() -> void:
	Ajustes.ARCHIVO = "user://prueba_album.cfg"
	GameState.guardado_habilitado = false
	var previas := AlbumFotos.listar().size()

	# Guardar y listar
	var rutas: Array[String] = []
	for i in 3:
		var img := Image.create(640, 360, false, Image.FORMAT_RGB8)
		img.fill(Color.from_hsv(i / 3.0, 0.6, 0.9))
		var r := AlbumFotos.guardar(img)
		rutas.append(r)
		_creadas.append(r)
	_check("se guardan las fotos", rutas.size() == 3 and not rutas.has("") and FileAccess.file_exists(rutas[0]))
	_check("tres rutas distintas aunque sean del mismo segundo", rutas[0] != rutas[1] and rutas[1] != rutas[2])
	var lista := AlbumFotos.listar()
	_check("el listado las incluye", lista.size() == previas + 3)
	_check("la miniatura se crea al guardar", FileAccess.file_exists("%s/%s.jpg" % [AlbumFotos.MINIATURAS, rutas[0].get_file().get_basename()]))
	var mini_tex := AlbumFotos.miniatura(rutas[0])
	_check("la miniatura es más chica que la foto", mini_tex != null and mini_tex.get_width() == AlbumFotos.ANCHO_MINIATURA)
	var grande := AlbumFotos.textura(rutas[0])
	_check("la foto entera se lee", grande != null and grande.get_width() == 640)
	_check("la fecha sale del nombre", AlbumFotos.fecha_de("user://fotos/foto_20261116_170700.png") == "16 NOV 2026 · 17:07")
	_check("un nombre sin fecha no rompe", AlbumFotos.fecha_de("user://fotos/otra.png") == "")

	# Ordenadas: la última guardada (nombre mayor) primero
	var primero := lista[0]
	var mayor := rutas[0]
	for r in rutas:
		if r > mayor:
			mayor = r
	_check("la más nueva va primero", primero == mayor)

	# Pantalla
	var album := PantallaAlbum.new()
	add_child(album)
	album.refrescar()
	_check("la grilla tiene todas las fotos", album.cantidad() == previas + 3)
	var grilla := album.contenido.get_node_or_null("Grilla")
	_check("hay grilla con botones", grilla != null and grilla.get_child_count() == mini(previas + 3, PantallaAlbum.MAX_EN_PANTALLA))
	album.abrir()
	await get_tree().process_frame
	album.abrir_visor(0)
	_check("el visor abre", album.visor_abierto() and album.foto_actual() == primero)
	album._mover(1)
	_check("pasa a la siguiente", album.foto_actual() == lista[1])
	album._mover(-1)
	album._mover(-1)
	_check("da la vuelta al principio", album.foto_actual() == lista[lista.size() - 1])
	album.abrir_visor(0)
	album._al_borrar()
	_check("el primer toque en BORRAR sólo pide confirmar", FileAccess.file_exists(primero) and album.cantidad() == previas + 3)
	album._al_borrar()
	_check("el segundo borra", not FileAccess.file_exists(primero) and album.cantidad() == previas + 2)
	_check("se borró también la miniatura", not FileAccess.file_exists("%s/%s.jpg" % [AlbumFotos.MINIATURAS, primero.get_file().get_basename()]))
	_check("sigue en el visor con otra foto", album.visor_abierto() and album.foto_actual() != primero)
	album.cerrar_visor()
	_check("cierra el visor", not album.visor_abierto())

	# Desde la pausa
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	var pausa: Node = main.get_node("Pausa")
	var boton := pausa.find_child("Album", true, false) as Button
	_check("la pausa tiene el botón ÁLBUM", boton != null)
	if boton:
		boton.pressed.emit()
		await get_tree().process_frame
		var alb := pausa.get_child(pausa.get_child_count() - 1)
		var abierto := false
		for c in pausa.get_children():
			if c is PantallaAlbum and (c as PantallaAlbum).visible:
				abierto = true
		_check("el botón abre el álbum", abierto)

	# Limpieza
	for r in rutas:
		AlbumFotos.borrar(r)
	_check("no quedan fotos de prueba", AlbumFotos.listar().size() == previas)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


func _check(nombre: String, ok: bool) -> void:
	if not ok:
		fallas += 1
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
