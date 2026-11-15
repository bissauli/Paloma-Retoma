class_name PerfilPaloma
extends Resource
## La configuración de la paloma de la jugadora: un color por zona, un accesorio por slot y (modo
## avanzado) una pintura libre sobre el modelo. Sólo datos: no sabe nada de la interfaz ni del
## modelo. La pantalla de personalizar edita este perfil y AplicadorPaloma lo aplica a un
## ModeloPaloma. Un perfil vacío es la paloma de siempre.
## Se guarda en user://paloma.cfg (user://paloma_movil.cfg en el teléfono, como Ajustes); la pintura
## va en un PNG al lado (paloma_pintura.png).

signal cambiado
## Se pintó (mientras se arrastra el pincel): los modelos actualizan su textura al instante.
## Al soltar el pincel se avisa también con "cambiado" (ahí se guarda).
signal pintura_cambiada

const SIN_COLOR := -1
const SECCION := "paloma"

## Índice de PALETA por zona (orden de CatalogoPaloma.ZONAS); -1 = color original.
@export var colores: PackedInt32Array = _colores_vacios()
## Índice de opción por slot (orden de CatalogoPaloma.SLOTS); 0 = ninguno.
@export var accesorios: PackedInt32Array = _accesorios_vacios()
## Pintura libre: imagen RGBA de 128x128 alineada con la textura del modelo; null = sin pintar.
var pintura: Image

## El perfil en uso en el juego (se carga la primera vez que se pide).
static var _actual: PerfilPaloma


## Perfil de la jugadora: lo usan el modelo de la paloma, el menú, los créditos y la pantalla de personalizar.
static func actual() -> PerfilPaloma:
	if _actual == null:
		_actual = cargar(ruta_por_defecto())
	return _actual


## Para pruebas: reemplaza (o con null, olvida) el perfil en uso.
static func fijar_actual(p: PerfilPaloma) -> void:
	_actual = p


static func ruta_por_defecto() -> String:
	return "user://paloma_movil.cfg" if Ajustes.movil else "user://paloma.cfg"


## Dónde va el PNG de la pintura de un perfil guardado en "ruta".
static func ruta_pintura(ruta: String) -> String:
	return ruta.get_basename() + "_pintura.png"


static func _colores_vacios() -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(CatalogoPaloma.ZONAS.size())
	a.fill(SIN_COLOR)
	return a


static func _accesorios_vacios() -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(CatalogoPaloma.SLOTS.size())
	a.fill(0)
	return a


func es_vacio() -> bool:
	if hay_pintura():
		return false
	for c in colores:
		if c != SIN_COLOR:
			return false
	for a in accesorios:
		if a != 0:
			return false
	return true


func hay_colores() -> bool:
	for c in colores:
		if c != SIN_COLOR:
			return true
	return false


func hay_pintura() -> bool:
	return pintura != null and not pintura.is_invisible()


func set_color(zona: int, color: int) -> void:
	colores[zona] = clampi(color, SIN_COLOR, CatalogoPaloma.PALETA.size() - 1)
	cambiado.emit()


func set_accesorio(slot: int, opcion: int) -> void:
	accesorios[slot] = clampi(opcion, 0, CatalogoPaloma.cantidad_opciones(slot) - 1)
	cambiado.emit()


## Mueve el color de una zona una posición (con vuelta). La secuencia es: original, paleta...
func ciclar_color(zona: int, paso: int) -> void:
	var n := CatalogoPaloma.PALETA.size() + 1
	set_color(zona, posmod(colores[zona] + 1 + paso, n) - 1)


func ciclar_accesorio(slot: int, paso: int) -> void:
	set_accesorio(slot, posmod(accesorios[slot] + paso, CatalogoPaloma.cantidad_opciones(slot)))


# ---------------------------------------------------------------- Pintura

## La imagen para pintar (se crea vacía la primera vez).
func asegurar_pintura() -> Image:
	if pintura == null:
		pintura = PinturaPaloma.nueva_imagen()
	return pintura


## Avisa que se pintó (los modelos actualizan su textura; no se guarda hasta fin_pincelada).
func pintura_modificada() -> void:
	pintura_cambiada.emit()


## Al soltar el pincel: si no quedó nada pintado se descarta la imagen, y se avisa para guardar.
func fin_pincelada() -> void:
	if pintura != null and pintura.is_invisible():
		pintura = null
	cambiado.emit()


## Reemplaza la pintura por una copia de "img" (null = sin pintura). Para deshacer y rehacer.
func poner_pintura(img: Image) -> void:
	pintura = img.duplicate() if img != null else null
	pintura_cambiada.emit()
	cambiado.emit()


# ---------------------------------------------------------------- Cambios en bloque

func restablecer() -> void:
	colores = _colores_vacios()
	accesorios = _accesorios_vacios()
	pintura = null
	pintura_cambiada.emit()
	cambiado.emit()


## Colores y accesorios al azar (cada slot puede quedar sin nada). No toca la pintura.
func aleatorio(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for i in colores.size():
		colores[i] = rng.randi_range(0, CatalogoPaloma.PALETA.size() - 1)
	for i in accesorios.size():
		accesorios[i] = rng.randi_range(0, CatalogoPaloma.cantidad_opciones(i) - 1)
	cambiado.emit()


func copiar_de(otro: PerfilPaloma) -> void:
	colores = otro.colores.duplicate()
	accesorios = otro.accesorios.duplicate()
	pintura = otro.pintura.duplicate() if otro.hay_pintura() else null
	pintura_cambiada.emit()
	cambiado.emit()


func es_igual(otro: PerfilPaloma) -> bool:
	if otro == null or colores != otro.colores or accesorios != otro.accesorios:
		return false
	if hay_pintura() != otro.hay_pintura():
		return false
	return not hay_pintura() or pintura.get_data() == otro.pintura.get_data()


# ---------------------------------------------------------------- Guardado

func guardar(ruta := "") -> Error:
	if ruta == "":
		ruta = ruta_por_defecto()
	var cfg := ConfigFile.new()
	cfg.set_value(SECCION, "colores", Array(colores))
	cfg.set_value(SECCION, "accesorios", Array(accesorios))
	# La pintura va en un PNG al lado (sin pintura, se borra el viejo)
	var png := ruta_pintura(ruta)
	if hay_pintura():
		var e := pintura.save_png(png)
		if e != OK:
			return e
	elif FileAccess.file_exists(png):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(png))
	return cfg.save(ruta)


## Lee un perfil. Si el archivo no existe o está roto, devuelve uno vacío; los índices fuera de
## rango (por ejemplo de una versión con otra paleta) se descartan.
static func cargar(ruta := "") -> PerfilPaloma:
	if ruta == "":
		ruta = ruta_por_defecto()
	var p := PerfilPaloma.new()
	var png := ruta_pintura(ruta)
	if FileAccess.file_exists(png):
		var img := Image.load_from_file(png)
		if img != null and img.get_width() == PinturaPaloma.TAM and img.get_height() == PinturaPaloma.TAM:
			img.convert(Image.FORMAT_RGBA8)
			if not img.is_invisible():
				p.pintura = img
	var cfg := ConfigFile.new()
	if cfg.load(ruta) != OK:
		return p
	var cs: Variant = cfg.get_value(SECCION, "colores", [])
	var accs: Variant = cfg.get_value(SECCION, "accesorios", [])
	if cs is Array:
		for i in mini((cs as Array).size(), p.colores.size()):
			var v: Variant = cs[i]
			if v is int and v >= SIN_COLOR and v < CatalogoPaloma.PALETA.size():
				p.colores[i] = v
	if accs is Array:
		for i in mini((accs as Array).size(), p.accesorios.size()):
			var v: Variant = accs[i]
			if v is int and v >= 0 and v < CatalogoPaloma.cantidad_opciones(i):
				p.accesorios[i] = v
	return p
