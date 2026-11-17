class_name AlbumFotos
extends RefCounted
## Las fotos del modo cámara en disco (user://fotos): guardar, listar de la más nueva a la más vieja,
## miniaturas (se guardan en user://fotos/miniaturas la primera vez para que el álbum abra rápido) y borrar.
## La pantalla que las muestra es PantallaAlbum (botón ÁLBUM de la pausa).

const CARPETA := "user://fotos"
const MINIATURAS := "user://fotos/miniaturas"
const ANCHO_MINIATURA := 360
const MESES := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]


## Guarda la imagen como foto nueva (con su miniatura). Devuelve la ruta, o "" si falló.
static func guardar(img: Image) -> String:
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute(MINIATURAS)
	var f := Time.get_datetime_dict_from_system()
	var base := "foto_%04d%02d%02d_%02d%02d%02d" % [f["year"], f["month"], f["day"], f["hour"], f["minute"], f["second"]]
	var ruta := "%s/%s.png" % [CARPETA, base]
	var n := 2
	while FileAccess.file_exists(ruta):         # Dos fotos en el mismo segundo
		ruta = "%s/%s_%d.png" % [CARPETA, base, n]
		n += 1
	if img.save_png(ruta) != OK:
		return ""
	_guardar_miniatura(img, ruta)
	return ruta


## Las rutas de todas las fotos, la más nueva primero.
static func listar() -> Array[String]:
	var l: Array[String] = []
	var d := DirAccess.open(CARPETA)
	if d == null:
		return l
	for nombre in d.get_files():
		if nombre.begins_with("foto_") and nombre.get_extension().to_lower() == "png":
			l.append("%s/%s" % [CARPETA, nombre])
	l.sort()
	l.reverse()
	return l


## Miniatura de la foto (la crea si no existe). Null si no se pudo leer.
static func miniatura(ruta: String) -> ImageTexture:
	var archivo := _ruta_miniatura(ruta)
	if FileAccess.file_exists(archivo):
		var chica := Image.load_from_file(archivo)
		if chica != null:
			return ImageTexture.create_from_image(chica)
	var img := Image.load_from_file(ruta)
	if img == null:
		return null
	DirAccess.make_dir_recursive_absolute(MINIATURAS)
	return _guardar_miniatura(img, ruta)


## La foto entera, para el visor. Null si no se pudo leer.
static func textura(ruta: String) -> ImageTexture:
	var img := Image.load_from_file(ruta)
	return ImageTexture.create_from_image(img) if img != null else null


## Borra la foto y su miniatura.
static func borrar(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta):
		return false
	var ok := DirAccess.remove_absolute(ruta) == OK
	var chica := _ruta_miniatura(ruta)
	if FileAccess.file_exists(chica):
		DirAccess.remove_absolute(chica)
	return ok


## "16 NOV 2026 · 17:07", sacado del nombre del archivo ("" si el nombre no tiene fecha).
static func fecha_de(ruta: String) -> String:
	var partes := ruta.get_file().get_basename().split("_")
	if partes.size() < 3 or partes[1].length() != 8 or partes[2].length() < 6:
		return ""
	var f := String(partes[1])
	var h := String(partes[2])
	var mes := clampi(int(f.substr(4, 2)), 1, 12)
	return "%d %s %s · %s:%s" % [int(f.substr(6, 2)), MESES[mes - 1], f.substr(0, 4), h.substr(0, 2), h.substr(2, 2)]


## Texto oscuro sin contorno ni sombra (el tema del juego los trae pensados para fondos oscuros) para
## escribir sobre el papel claro de las polaroids.
static func tinta(l: Label) -> void:
	l.add_theme_color_override("font_color", Color("2c2a33"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)


static func carpeta_absoluta() -> String:
	return ProjectSettings.globalize_path(CARPETA)


static func _ruta_miniatura(ruta: String) -> String:
	return "%s/%s.jpg" % [MINIATURAS, ruta.get_file().get_basename()]


static func _guardar_miniatura(img: Image, ruta: String) -> ImageTexture:
	var chica := img.duplicate() as Image
	if chica.get_width() > ANCHO_MINIATURA:
		chica.resize(ANCHO_MINIATURA, int(round(float(chica.get_height()) * ANCHO_MINIATURA / chica.get_width())),
			Image.INTERPOLATE_BILINEAR)
	chica.convert(Image.FORMAT_RGB8)
	chica.save_jpg(_ruta_miniatura(ruta), 0.88)
	return ImageTexture.create_from_image(chica)
