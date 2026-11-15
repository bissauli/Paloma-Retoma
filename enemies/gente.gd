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

## Comensales de los cafés: se sientan en las sillas de las mesas de la vereda.
const Z_VEREDA_PASO := 37.0          ## Por dónde caminan (entre las mesas y las vidrieras)
const X_ENTRADAS := [-60.0, 58.0]
@export var max_comensales := 10
@export var intervalo_comensal := Vector2(4.0, 9.0)

var _timer_oleada := 6.0
var _subte := Vector3(34, 0, -22)
var _asientos: Array[Dictionary] = []   ## {pos, lado, ocupado}
var _timer_comensal := 2.0


func _ready() -> void:
	_poblar.call_deferred()


func _punto(nombre: String, defecto: Vector3) -> Vector3:
	var n := get_tree().get_first_node_in_group("punto_" + nombre) as Node3D
	return n.global_position if n else defecto


func _generador(nombre: String) -> GeneradorMigas:
	return get_parent().find_child(nombre, true, false) as GeneradorMigas


func _poblar() -> void:
	_subte = _punto("subte", _subte)
	# Doña Rosa: sentada en el banco del Cabildo, les tira migas a las palomas (la muestra el tutorial)
	var dona_rosa := ESC_HUMANO.instantiate() as Humano
	dona_rosa.tipo = "senora"
	dona_rosa.preparar_aspecto()
	var mr := dona_rosa.get_node("Modelo") as ModeloHumano
	mr.color_ropa = Color("b0577a")
	mr.accesorio = "sombrero"
	mr.color_accesorio = Color("f2e6c9")
	dona_rosa.generador = _generador("MigasDonaRosa")
	dona_rosa.intervalo_migas = 2.6
	dona_rosa.rotation.y = PI / 2.0   # Mira al oeste, hacia el Cabildo
	dona_rosa.add_to_group("dona_rosa")
	add_child(dona_rosa)
	dona_rosa.global_position = _punto("donarosa", Vector3(-35.95, 0, -8))
	# Turistas en el Cabildo (sus migas también caen delante del banco de Doña Rosa)
	var p_tur := _punto("turistas", Vector3(-40, 0, -14))
	for i in 4:
		_humano("turista", p_tur, 3.5, _generador("MigasDonaRosa"), 9.0)
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
	# La ciudad (world/ciudad.gd) marca más señoras en bancos y zonas donde pasea gente
	for m in get_tree().get_nodes_in_group("senora_extra"):
		var p := m as Node3D
		var s := ESC_HUMANO.instantiate() as Humano
		s.tipo = "senora"
		s.preparar_aspecto()
		s.generador = _generador(String(p.get_meta("migas", "")))
		s.intervalo_migas = randf_range(2.5, 4.0)
		s.rotation.y = float(p.get_meta("rumbo", 0.0))
		s.position = p.global_position   # antes de add_child: en _ready toma su altura
		add_child(s)
	for m in get_tree().get_nodes_in_group("zona_paseo"):
		var p := m as Node3D
		var tam: Vector2 = p.get_meta("tam", Vector2(10, 10))
		var nombre_migas := String(p.get_meta("migas", ""))
		for i in int(p.get_meta("cantidad", 3)):
			var h := ESC_HUMANO.instantiate() as Humano
			h.tipo = String(p.get_meta("tipo", "turista"))
			if h.tipo == "oficinista":
				h.tipo = "turista"   # los oficinistas "de verdad" salen del subte y se van
				h.preparar_aspecto()
				var mo := h.get_node("Modelo") as ModeloHumano
				mo.color_ropa = [Color("2f3540"), Color("4a4f5a"), Color("596b80")][randi() % 3]
				mo.color_piernas = Color("22252b")
				mo.accesorio = "ninguno"
			else:
				h.preparar_aspecto()
			h.zona_centro = p.global_position
			h.zona_tam = tam
			h.generador = _generador(nombre_migas) if nombre_migas != "" else null
			h.intervalo_migas = randf_range(8.0, 14.0)
			h.position = p.global_position + Vector3(randf_range(-0.5, 0.5) * tam.x, 0, randf_range(-0.5, 0.5) * tam.y)
			add_child(h)
	# El nene corretea por el centro de la plaza
	var nene := ESC_NENE.instantiate() as Nene
	add_child(nene)
	nene.global_position = Vector3(6, 0, 12)
	# El mozo patrulla la vereda de los cafés
	var mozo := ESC_MOZO.instantiate() as Mozo
	add_child(mozo)
	mozo.global_position = _punto("cafes", Vector3(0, 0.16, 35.7))
	# Dos granaderos frente a la Casa Rosada
	var p_gra := _punto("granaderos", Vector3(40.5, 0, 0))
	for z in [-8.0, 8.0]:
		var g := ESC_GRANADERO.instantiate() as Granadero
		add_child(g)
		g.global_position = p_gra + Vector3(0, 0, z)
	# El halcón (se activa solo cuando la bandada llega a 15)
	add_child(ESC_HALCON.instantiate())
	# Sillas de los cafés: dos por mesa, y algunas ya ocupadas al empezar
	for n in get_tree().get_nodes_in_group("mesa_cafe"):
		var m := (n as Node3D).global_position
		for l: float in [-1.0, 1.0]:
			_asientos.append({"pos": m + Vector3(0.8 * l, 0, 0), "lado": l, "ocupado": false})
	for i in mini(5, _asientos.size()):
		var idx := _asiento_libre()
		if idx >= 0:
			_comensal(idx, true)


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


## Oleadas de oficinistas que salen del subte con facturas, y comensales que llegan a los cafés.
func _process(delta: float) -> void:
	_timer_comensal -= delta
	if _timer_comensal <= 0.0 and not _asientos.is_empty():
		_timer_comensal = randf_range(intervalo_comensal.x, intervalo_comensal.y)
		var ocupados := 0
		for a in _asientos:
			if a["ocupado"]:
				ocupados += 1
		var idx := _asiento_libre()
		if ocupados < max_comensales and idx >= 0:
			_comensal(idx, false)
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



func _asiento_libre() -> int:
	var libres: Array[int] = []
	for i in _asientos.size():
		if not _asientos[i]["ocupado"]:
			libres.append(i)
	return -1 if libres.is_empty() else libres[randi() % libres.size()]


## Un comensal: llega caminando desde una punta de la vereda (o ya sentado, al empezar),
## come entre 25 y 55 s y se va por la punta más cercana.
func _comensal(idx: int, ya_sentado: bool) -> void:
	var a: Dictionary = _asientos[idx]
	a["ocupado"] = true
	var pos: Vector3 = a["pos"]
	var h := ESC_HUMANO.instantiate() as Humano
	h.tipo = "comensal"
	h.preparar_aspecto()
	h.velocidad = randf_range(1.1, 1.5)
	h.asiento = pos
	h.lado = a["lado"]
	h.tiempo_comida = randf_range(25.0, 55.0) * (randf_range(0.2, 1.0) if ya_sentado else 1.0)
	var x_salida: float = X_ENTRADAS[0] if pos.x < 0.0 else X_ENTRADAS[1]
	h.salida = Vector3(x_salida, pos.y, Z_VEREDA_PASO)
	h.se_levanto.connect(func() -> void: a["ocupado"] = false)
	# La posición va antes de add_child: en _ready el humano toma su altura (la vereda está a 16 cm)
	if ya_sentado:
		h.position = pos
		add_child(h)
		h.comenzar_sentado()
		return
	var x_entrada: float = X_ENTRADAS[randi() % 2]
	h.ruta = [Vector3(pos.x, pos.y, Z_VEREDA_PASO), pos]
	h.position = Vector3(x_entrada, pos.y, Z_VEREDA_PASO + randf_range(-0.3, 0.3))
	add_child(h)
