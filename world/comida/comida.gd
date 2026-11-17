class_name Comida
extends Node3D
## Un pedazo de comida que la paloma puede picotear.
## - miga: se come en el acto, recupera stamina y suma 1 de comida.
## - medialuna / papa / factura: se lleva en el pico (te hace más lenta) hasta el nido.
## - choripan: sólo se puede levantar con 5 palomas o más en la bandada.

signal comida_tomada(tipo: String, posicion: Vector3)

const VALORES := {
	"miga": Config.COMIDA_MIGA,
	"papa": Config.COMIDA_PAPA,
	"medialuna": Config.COMIDA_MEDIALUNA,
	"factura": Config.COMIDA_PAPA,
	"choripan": Config.COMIDA_CHORIPAN,
	"asado": 0,    # No se entrega en el nido: es para Tío Ruffus (ver misión "asado_ruffus")
}

@export_enum("miga", "medialuna", "papa", "factura", "choripan") var tipo := "miga"
@export var reaparece := true               ## Vuelve a aparecer un rato después
@export var tiempo_reaparicion := 35.0
@export var vida := 0.0                     ## > 0: desaparece sola (migas tiradas al piso)


## Comida suelta que no reaparece y desaparece sola a los "vida" segundos (lo que se les cae a
## la gente y las migas que tiran). "pos" es la posición global.
static func soltar(padre: Node, tipo_comida: String, pos: Vector3, vida_s: float) -> Comida:
	var c := Comida.new()
	c.tipo = tipo_comida
	c.reaparece = false
	c.vida = vida_s
	padre.add_child(c)
	c.global_position = pos
	return c

## Las migas brillan suavecito cuando la paloma anda cerca (para avisar que se comen).
const DESTELLO_LEJOS := 6.0
const DESTELLO_CERCA := 2.5

## Malla ya fusionada de cada tipo de comida (las migas tienen varias formas al azar): cada pedazo
## es un solo dibujo en vez de 2 a 7.
static var _mallas := {}
const FORMAS_MIGA := 6

var activa := true
var _volando := false          ## La despidió un aletazo y todavía está en el aire
var _origen_guardado := false  ## Dónde estaba antes del primer aletazo (para volver ahí al reaparecer)
var _origen := Vector3.ZERO
var _visual: Node3D
var _destello: Label3D
var _destello_alfa := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("comida")
	_visual = Node3D.new()
	add_child(_visual)
	_armar()
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	if not activa:
		return
	if _destello:
		_animar_destello(delta)
	# La comida "pesada" flota y gira un poquito para que se note que se puede agarrar
	if tipo != "miga":
		_visual.position.y = 0.05 + sin(_t * 3.0) * 0.04
		_visual.rotation.y += delta * 0.8
	if vida > 0.0:
		vida -= delta
		if vida <= 0.0:
			queue_free()


## La llama la paloma del jugador al picotear cerca.
func picoteada(_jugador: Node3D) -> void:
	if not activa:
		return
	match tipo:
		"miga":
			GameState.set_stamina(GameState.stamina + Config.STAMINA_MIGA)
			GameState.sumar_comida(VALORES["miga"])
			GameState.comio_miga()
			AudioManager.reproducir("recoger", -6.0)
			_consumir()
		"choripan":
			if GameState.bandada >= Config.UMBRAL_CHORIPAN:
				GameState.sumar_comida(VALORES["choripan"])
				Logros.sumar("choripanes")
				AudioManager.ui("currency", -4.0)
				AudioManager.reproducir("arrullo")
				_consumir()
			else:
				AudioManager.ui("lock", -6.0)   # Todavía no alcanza la bandada
		"asado":
			# Sólo se levanta si Tío Ruffus lo pidió (y no se lleva otra cosa en el pico)
			var estado_mision := Misiones.estado("asado_ruffus")
			if (estado_mision != Misiones.ACTIVA and estado_mision != Misiones.LISTA) or GameState.carga != "":
				AudioManager.ui("lock", -6.0)
				return
			GameState.set_carga("asado")
			Misiones.notificar("asado_recogido")
			AudioManager.reproducir("recoger")
			_consumir()
		_:
			if GameState.carga != "":
				return
			GameState.set_carga(tipo)
			AudioManager.reproducir("recoger")
			_consumir()


## Un aletazo de la paloma: sale despedida en la dirección "dir" (en un arco) y cae unos metros más
## allá, en el piso o donde haya algo firme (una mesa de al lado, la vereda). Las migas apenas se
## corren. El choripán no se mueve (está en el carrito). Si es de las que reaparecen, cuando se la
## coma vuelve a su lugar de origen. Devuelve false si no se pudo golpear.
func golpear(dir: Vector3) -> bool:
	if not activa or _volando or tipo == "choripan":
		return false
	if reaparece and not _origen_guardado:
		_origen_guardado = true
		_origen = position
	_volando = true
	var d := dir.rotated(Vector3.UP, randf_range(-0.35, 0.35))
	var dist := randf_range(0.4, 0.8) if tipo == "miga" else randf_range(1.5, 2.2)
	var inicio := global_position
	var destino := inicio + d * dist
	# Una pared en el camino la frena: cae antes de llegar a ella
	var q := PhysicsRayQueryParameters3D.create(inicio + Vector3.UP * 0.15, destino + Vector3.UP * 0.15 + d * 0.15, 1)
	var choque := get_world_3d().direct_space_state.intersect_ray(q)
	if not choque.is_empty():
		var p_choque: Vector3 = choque["position"]
		var llega := maxf((Vector2(p_choque.x - inicio.x, p_choque.z - inicio.z)).length() - 0.2, 0.0)
		destino = inicio + d * minf(llega, dist)
	destino.y = _altura_del_suelo(destino, inicio.y)
	var salto := 0.12 if tipo == "miga" else 0.75
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void:
		var p := inicio.lerp(destino, u)
		p.y = lerpf(inicio.y, destino.y, u) + salto * 4.0 * u * (1.0 - u)
		global_position = p, 0.0, 1.0, 0.42 if tipo != "miga" else 0.25)
	tw.parallel().tween_property(_visual, "rotation:y", _visual.rotation.y + TAU * 1.5, 0.42)
	tw.tween_callback(func() -> void: _volando = false)
	return true


## Altura del suelo (lo más alto que haya, pero por debajo de "desde_y" + 0.7) en un punto.
func _altura_del_suelo(p: Vector3, desde_y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, desde_y + 0.7, p.z), Vector3(p.x, desde_y - 5.0, p.z), 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) + 0.01 if not r.is_empty() else 0.02


func _consumir() -> void:
	comida_tomada.emit(tipo, global_position)
	if not reaparece:
		queue_free()
		return
	activa = false
	visible = false
	remove_from_group("comida")
	get_tree().create_timer(tiempo_reaparicion, false).timeout.connect(_reaparecer)


func _reaparecer() -> void:
	if _origen_guardado:
		position = _origen   # Si la habían tirado de la mesa, vuelve a la mesa
	activa = true
	visible = true
	add_to_group("comida")
	_visual.scale = Vector3.ONE * 0.1
	create_tween().tween_property(_visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Visual

## Destello de la miga: aparece de a poco al acercarse, titila y gira despacio. Lejos no se ve.
func _animar_destello(delta: float) -> void:
	var objetivo := 0.0
	var jugadora := GameState.jugador
	if jugadora:
		var d := jugadora.global_position.distance_to(global_position)
		objetivo = clampf((DESTELLO_LEJOS - d) / (DESTELLO_LEJOS - DESTELLO_CERCA), 0.0, 1.0)
	_destello_alfa = move_toward(_destello_alfa, objetivo, delta * 2.5)
	_destello.visible = _destello_alfa > 0.01
	if not _destello.visible:
		return
	var titileo := 0.55 + 0.45 * sin(_t * 4.2)
	_destello.modulate.a = _destello_alfa * titileo * 0.85
	_destello.position.y = 0.16 + sin(_t * 2.0) * 0.025
	var esc := 0.8 + 0.3 * titileo
	_destello.scale = Vector3(esc, esc, esc)


func _armar() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _malla_visual()
	mi.material_override = Construir.material_vertices(0.9)
	if not Construir.proyecta_sombra(mi.mesh):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)
	_armar_brillo()


## La malla de este tipo de comida: se arma una vez con primitivas y se fusiona.
func _malla_visual() -> ArrayMesh:
	var clave := tipo
	if tipo == "miga":
		clave = "miga_%d" % (randi() % FORMAS_MIGA)
	if not _mallas.has(clave):
		var molde := Node3D.new()
		_armar_piezas(molde)
		var piezas := []
		for h in molde.get_children():
			var p := h as MeshInstance3D
			piezas.append([p.mesh, p.transform, p.material_override.get_meta(&"color_plano", Color.WHITE)])
		molde.free()
		_mallas[clave] = Construir.combinar(piezas)
	return _mallas[clave]


func _armar_piezas(padre: Node3D) -> void:
	match tipo:
		"miga":
			# Un puñadito de migas
			for i in 4:
				var p := Construir.caja(padre, Vector3(randf_range(-0.12, 0.12), 0.025, randf_range(-0.12, 0.12)),
					Vector3(0.06, 0.04, 0.05), Color("e9cf9a"), false)
				p.rotation.y = randf() * TAU
		"medialuna":
			# Medialuna: tres esferas doradas en arco
			for i in 3:
				var a := (i - 1) * 0.6
				Construir.esfera(padre, Vector3(sin(a) * 0.12, 0.06, -cos(a) * 0.12 + 0.1), 0.07,
					Color("d9a24a"), Vector3(1, 0.7, 1.3), 6)
			Construir.cilindro(padre, Vector3(0, 0.0, 0), 0.22, 0.01, Color("ffffff"), false, 10)
		"papa":
			# Cucurucho de papas fritas
			Construir.cilindro(padre, Vector3(0, 0.1, 0), 0.08, 0.2, Color("c8372d"), false, 6, 0.11)
			for i in 6:
				var p := Construir.caja(padre, Vector3(randf_range(-0.05, 0.05), 0.25, randf_range(-0.05, 0.05)),
					Vector3(0.025, 0.14, 0.025), Color("f2d36b"), false)
				p.rotation = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		"factura":
			Construir.esfera(padre, Vector3(0, 0.05, 0), 0.1, Color("c97b3a"), Vector3(1.4, 0.6, 1.0), 6)
			Construir.esfera(padre, Vector3(0, 0.09, 0), 0.05, Color("f0e6d2"), Vector3(1.6, 0.4, 0.8), 6)
		"asado":
			# Un buen pedazo de asado (tira de costilla): carne dorada, parte quemada y el hueso
			Construir.caja(padre, Vector3(0, 0.08, 0), Vector3(0.5, 0.12, 0.26), Color("9a4a2a"), false)
			Construir.caja(padre, Vector3(0, 0.15, 0), Vector3(0.46, 0.03, 0.22), Color("5a2a18"), false)
			Construir.caja(padre, Vector3(0.0, 0.05, 0.13), Vector3(0.5, 0.06, 0.04), Color("f2ead8"), false)
			for i in 3:
				Construir.caja(padre, Vector3(-0.14 + i * 0.14, 0.09, 0.0), Vector3(0.02, 0.14, 0.27), Color("f2ead8"), false)
		"choripan":
			# Pan con chorizo: grande y tentador
			Construir.esfera(padre, Vector3(0, 0.12, 0), 0.18, Color("e0b26a"), Vector3(0.9, 0.6, 2.2), 8)
			Construir.esfera(padre, Vector3(0, 0.2, 0), 0.1, Color("8f3a22"), Vector3(1.0, 0.9, 3.6), 8)
			Construir.esfera(padre, Vector3(0, 0.27, 0), 0.04, Color("3e7d2a"), Vector3(2.5, 0.5, 6.0), 6)


func _armar_brillo() -> void:
	# Las migas: un destello chiquito que sólo aparece si la paloma está cerca
	if tipo == "miga":
		_destello = Label3D.new()
		_destello.text = "✦"
		_destello.font_size = 48
		_destello.modulate = Color(1, 0.97, 0.75, 0.0)
		_destello.outline_modulate = Color(1, 0.85, 0.4, 0.0)
		_destello.outline_size = 0
		_destello.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_destello.pixel_size = 0.0028
		_destello.shaded = false
		_destello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_destello.position = Vector3(0, 0.16, 0)
		_destello.visible = false
		_visual.add_child(_destello)
	# Brillito para que se vea de lejos (no para las migas, que son muchas)
	if tipo != "miga":
		var brillo := Label3D.new()
		brillo.text = "✦"
		brillo.font_size = 64
		brillo.modulate = Color(1, 0.95, 0.6, 0.9)
		brillo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		brillo.no_depth_test = false
		brillo.position = Vector3(0, 0.55 if tipo != "choripan" else 0.8, 0)
		brillo.pixel_size = 0.004
		_visual.add_child(brillo)
