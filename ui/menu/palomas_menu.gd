extends Node2D
## Palomas del menú principal: cada tanto cruzan volando de izquierda a derecha
## (unas chiquitas por detrás del cartel y otras más grandes por delante)
## y, de vez en cuando, una viene a posarse en el botón JUGAR, se queda unos segundos y se va.

@export var boton_posar: Control                 ## Botón donde se posa la paloma (JUGAR)
@export var punto_posar := Vector2(133, 146)     ## Pies de la paloma, en píxeles del botón
@export var escala_posada := 0.55                ## Tamaño de la paloma posada (en píxeles del botón)
@export var espera_cruce := Vector2(2.0, 5.5)    ## Segundos entre cruces (mín, máx)
@export var espera_posar := Vector2(6.0, 12.0)   ## Segundos entre que se va una y llega otra
@export var primera_llegada := 1.2               ## La primera llega enseguida

var _atras: Node2D
var _prox_cruce := 0.8
var _prox_posar := 0.0
var _posada: PalomaMenu


func _ready() -> void:
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_atras = Node2D.new()
	_atras.name = "Atras"
	_atras.z_index = -6  # relativo: queda en -1, debajo de toda la interfaz
	add_child(_atras)
	_prox_posar = primera_llegada


func _process(delta: float) -> void:
	_prox_cruce -= delta
	if _prox_cruce <= 0.0:
		_prox_cruce = randf_range(espera_cruce.x, espera_cruce.y)
		_soltar_cruce()
	if _posada == null and boton_posar != null and boton_posar.is_visible_in_tree():
		_prox_posar -= delta
		if _prox_posar <= 0.0:
			_mandar_a_posar()


## Si hay una paloma posada en JUGAR, se espanta y se va.
func asustar() -> void:
	if is_instance_valid(_posada) and _posada.estado == PalomaMenu.Estado.POSADA:
		_despedir()


func _soltar_cruce() -> void:
	var tam := get_viewport_rect().size
	var atras := randf() < 0.45
	var cantidad := 1
	if randf() < 0.3:
		cantidad = randi_range(2, 4)
	var y := randf_range(0.08, 0.5 if atras else 0.6) * tam.y
	var escala := randf_range(0.2, 0.3) if atras else randf_range(0.36, 0.58)
	var vel := randf_range(150.0, 210.0) if atras else randf_range(230.0, 330.0)
	for i in cantidad:
		var p := PalomaMenu.new()
		var capa: Node2D = _atras if atras else self
		capa.add_child(p)
		var e := escala * randf_range(0.88, 1.1)
		p.scale = Vector2(e, e)
		if atras:
			p.modulate = Color(0.82, 0.86, 0.96)  # un poco de "aire" de por medio
		p.cruzar(y + randf_range(-30.0, 30.0) * i, vel * randf_range(0.95, 1.05), tam.x)
		# En bandadita: las de atrás arrancan un poco más tarde
		p.position.x -= i * randf_range(55.0, 90.0) * e * 2.0


func _mandar_a_posar() -> void:
	var tam := get_viewport_rect().size
	_posada = PalomaMenu.new()
	_posada.z_index = 5
	_posada.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_posada.scale = Vector2(escala_posada, escala_posada)
	boton_posar.add_child(_posada)
	var desde := _a_local(Vector2(-90.0, tam.y * randf_range(0.25, 0.45)))
	_posada.venir_a_posarse(desde, punto_posar)
	_posada.se_va.connect(_despedir)
	_posada.se_fue.connect(_al_irse)


func _despedir() -> void:
	if not is_instance_valid(_posada):
		return
	var tam := get_viewport_rect().size
	_posada.irse(_a_local(Vector2(tam.x * randf_range(0.55, 0.8), -120.0)))


func _al_irse() -> void:
	_posada = null
	_prox_posar = randf_range(espera_posar.x, espera_posar.y)


## Punto de la pantalla en coordenadas del botón (que está escalado y se agranda al pasar el mouse).
func _a_local(p: Vector2) -> Vector2:
	return boton_posar.get_global_transform().affine_inverse() * p
