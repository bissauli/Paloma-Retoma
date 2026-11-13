extends Node3D
## Ubica a los humanos y enemigos en la plaza y maneja las oleadas del subte.
## Usa los marcadores y generadores de migas que arma world/plaza.gd (los busca por nombre/grupo).

const ESC_HUMANO := preload("res://enemies/humano.tscn")
const ESC_NENE := preload("res://enemies/nene.tscn")
const ESC_MOZO := preload("res://enemies/mozo.tscn")
const ESC_GRANADERO := preload("res://enemies/granadero.tscn")
const ESC_HALCON := preload("res://enemies/halcon.tscn")

@export var intervalo_oleada := 28.0       ## Cada cuánto salen oficinistas del subte
@export var oficinistas_por_oleada := Vector2i(4, 7)

const SALIDAS := [Vector3(58, 0, -30), Vector3(40, 0, -39), Vector3(-15, 0, -39),
	Vector3(58, 0, 22), Vector3(-58, 0, -30)]

var _timer_oleada := 6.0
var _subte := Vector3(34, 0, -22)


func _ready() -> void:
	_poblar.call_deferred()


func _punto(nombre: String, defecto: Vector3) -> Vector3:
	var n := get_tree().get_first_node_in_group("punto_" + nombre) as Node3D
	return n.global_position if n else defecto


func _generador(nombre: String) -> GeneradorMigas:
	return get_parent().find_child(nombre, true, false) as GeneradorMigas


func _poblar() -> void:
	_subte = _punto("subte", _subte)
	# Turistas en el Cabildo
	var p_tur := _punto("turistas", Vector3(-38, 0, 0))
	for i in 4:
		_humano("turista", p_tur, 4.0, _generador("MigasCabildo"), 7.0)
	# Grupo escolar con su maestra
	var p_esc := _punto("escolares", Vector3(-34, 0, 12))
	for i in 5:
		var h := _humano("escolar", p_esc, 3.0, _generador("MigasCabildo"), 9.0)
		h.velocidad = 1.4
	_humano("turista", p_esc, 2.0, null, 99.0)
	# Señoras en los bancos de la Catedral (de frente a la plaza)
	var gen_cat := _generador("MigasCatedral")
	for x in [-7.0, -3.0, 3.0]:
		var s := ESC_HUMANO.instantiate() as Humano
		s.tipo = "senora"
		s.preparar_aspecto()
		s.generador = gen_cat
		s.intervalo_migas = randf_range(3.0, 5.0)
		s.rotation.y = PI
		add_child(s)
		s.global_position = Vector3(x, 0.0, -18.05)
	# El nene corretea por el centro de la plaza
	var nene := ESC_NENE.instantiate() as Nene
	add_child(nene)
	nene.global_position = Vector3(6, 0, 12)
	# El mozo patrulla la vereda de los cafés
	var mozo := ESC_MOZO.instantiate() as Mozo
	add_child(mozo)
	mozo.global_position = _punto("cafes", Vector3(0, 0.16, 33.5))
	# Dos granaderos frente a la Casa Rosada
	var p_gra := _punto("granaderos", Vector3(40.5, 0, 0))
	for z in [-8.0, 8.0]:
		var g := ESC_GRANADERO.instantiate() as Granadero
		add_child(g)
		g.global_position = p_gra + Vector3(0, 0, z)
	# El halcón (se activa solo cuando la bandada llega a 15)
	add_child(ESC_HALCON.instantiate())


func _humano(tipo: String, centro: Vector3, radio: float, gen: GeneradorMigas, intervalo: float) -> Humano:
	var h := ESC_HUMANO.instantiate() as Humano
	h.tipo = tipo
	h.preparar_aspecto()
	h.zona_centro = centro
	h.zona_radio = radio
	h.generador = gen
	h.intervalo_migas = intervalo
	add_child(h)
	var a := randf() * TAU
	h.global_position = centro + Vector3(cos(a), 0, sin(a)) * randf() * radio
	return h


## Oleadas de oficinistas que salen del subte con facturas.
func _process(delta: float) -> void:
	_timer_oleada -= delta
	if _timer_oleada > 0.0:
		return
	_timer_oleada = intervalo_oleada
	var cant := randi_range(oficinistas_por_oleada.x, oficinistas_por_oleada.y)
	for i in cant:
		get_tree().create_timer(i * 0.7, false).timeout.connect(_salir_oficinista)


func _salir_oficinista() -> void:
	var h := ESC_HUMANO.instantiate() as Humano
	h.tipo = "oficinista"
	h.preparar_aspecto()
	h.destino_final = SALIDAS[randi() % SALIDAS.size()] + Vector3(randf_range(-4, 4), 0, 0)
	add_child(h)
	h.global_position = _subte + Vector3(randf_range(-0.8, 0.8), 0, 2.5)
