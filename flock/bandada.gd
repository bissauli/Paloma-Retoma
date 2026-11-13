class_name Bandada
extends Node3D
## Maneja todas las palomas NPC: las sueltas en sus zonas, el reclutamiento por arrullo,
## y el movimiento de la bandada con boids (separación, alineación, cohesión y seguir al jugador).

const ESCENA_PALOMA := preload("res://flock/paloma_npc.tscn")

@export_group("Boids")
@export var radio_separacion := 0.9
@export var radio_vecinos := 4.0
@export var peso_separacion := 6.0
@export var peso_alineacion := 0.8
@export var peso_cohesion := 0.5
@export var peso_seguir := 3.0
@export var velocidad_minima := 5.0
@export var distancia_lejana := 25.0      ## Más lejos que esto se actualizan con menos frecuencia

@export_group("Población")
@export var minimo_sueltas := 14          ## Si quedan menos, llegan palomas nuevas volando
@export var maximo_total := 110
@export var intervalo_llegada := 6.0

var seguidoras: Array[PalomaNPC] = []
var _zonas: Array[Marker3D] = []
var _jugador: PalomaJugador
var _frame := 0
var _timer_llegada := 0.0
var _aviso_sin_comida := 0.0


func _ready() -> void:
	GameState.arrullo.connect(_al_arrullar)
	GameState.perder_palomas.connect(_al_perder)
	GameState.victoria.connect(_al_ganar)
	_poblar.call_deferred()


## Crea las palomas iniciales en cada zona marcada por la plaza.
func _poblar() -> void:
	_jugador = get_tree().get_first_node_in_group("jugador") as PalomaJugador
	for n in get_tree().get_nodes_in_group("zona_palomas"):
		var z := n as Marker3D
		_zonas.append(z)
		var cant: int = z.get_meta("cantidad", 5)
		var radio: float = z.get_meta("radio", 5.0)
		for i in cant:
			var a := randf() * TAU
			var pos := z.global_position + Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * radio
			var p := _crear_paloma(pos)
			p.configurar_zona(z.global_position, radio)


func _crear_paloma(pos: Vector3) -> PalomaNPC:
	var p := ESCENA_PALOMA.instantiate() as PalomaNPC
	p.randomizar_colores()
	add_child(p)
	p.global_position = pos
	p.altura_suelo = p.medir_suelo(pos)
	p.global_position.y = p.altura_suelo
	return p


# ---------------------------------------------------------------- Reclutar y perder

func _al_arrullar(pos: Vector3, radio: float) -> void:
	var candidatas: Array[PalomaNPC] = []
	for n in get_children():
		var p := n as PalomaNPC
		if p and p.modo == PalomaNPC.Modo.SUELTA and p.global_position.distance_to(pos) <= radio:
			candidatas.append(p)
	if candidatas.is_empty():
		return
	candidatas.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	var reclutadas := 0
	for p in candidatas:
		if not GameState.hay_lugar_en_bandada():
			GameState.mensaje.emit("¡La bandada está llena! (%d palomas)" % Config.BANDADA_MAX, 2.5)
			break
		if not GameState.gastar_comida(Config.COSTO_RECLUTAR):
			if reclutadas == 0:
				GameState.mensaje.emit("Las palomas te miran... pero quieren comida. ¡Conseguí migas o medialunas!", 3.0)
			else:
				GameState.mensaje.emit("Se te acabó la comida para seguir reclutando", 2.5)
			break
		p.reclutar()
		seguidoras.append(p)
		reclutadas += 1
	if reclutadas > 0:
		AudioManager.reproducir("arrullo", -4.0)
		if reclutadas > 1:
			GameState.mensaje.emit("¡Se sumaron %d palomas a la bandada!" % reclutadas, 2.0)


## Suelta "cantidad" palomas de la bandada (las más cercanas al peligro).
func _al_perder(cantidad: int, desde: Vector3) -> void:
	seguidoras.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(desde) < b.global_position.distance_squared_to(desde))
	var n := mini(cantidad, seguidoras.size())
	for i in n:
		var p: PalomaNPC = seguidoras.pop_front()
		p.soltar(desde)
		var z := _zona_al_azar()
		if z:
			p.ir_a_zona(z.global_position, z.get_meta("radio", 5.0))
	if n > 0:
		GameState.mensaje.emit("¡Se te dispersaron %d palomas!" % n, 2.5)


## Victoria: la bandada se reparte entre el balcón y la plaza frente a la Casa Rosada,
## llegan muchas palomas más, y todas festejan arrullando.
func _al_ganar() -> void:
	var balcon := get_tree().get_first_node_in_group("balcon") as Node3D
	var pb := balcon.global_position if balcon else Vector3(39.9, 7.15, 0)
	for i in seguidoras.size():
		var p := seguidoras[i]
		if i < 10:
			p.global_position = pb + Vector3(randf_range(-0.8, 0.6), 0, randf_range(-2.6, 2.6))
		else:
			p.global_position = Vector3(randf_range(18, 36), 0, randf_range(-16, 16))
	# Más palomas que vienen a festejar
	for i in 50:
		var p := ESCENA_PALOMA.instantiate() as PalomaNPC
		p.randomizar_colores()
		add_child(p)
		p.global_position = Vector3(randf_range(-10, 36), 0, randf_range(-20, 20))
	for n in get_children():
		var p := n as PalomaNPC
		if p:
			p.altura_suelo = p.medir_suelo(p.global_position)
			p.global_position.y = p.altura_suelo
			p.festejar()


func _zona_al_azar() -> Marker3D:
	if _zonas.is_empty():
		return null
	return _zonas[randi() % _zonas.size()]


# ---------------------------------------------------------------- Boids

func _physics_process(delta: float) -> void:
	_frame += 1
	_aviso_sin_comida = maxf(_aviso_sin_comida - delta, 0.0)
	if _jugador == null or not is_instance_valid(_jugador):
		return
	if GameState.partida_terminada:
		return  # En la victoria cada paloma festeja por su cuenta
	_mover_seguidoras(delta)
	_llegadas(delta)


func _mover_seguidoras(delta: float) -> void:
	var jpos := _jugador.global_position
	var jvel := _jugador.velocity
	var j_suelo := _jugador.estado == PalomaJugador.Estado.SUELO
	var j_picada := _jugador.en_picada
	var vel_max := maxf(jvel.length() * 1.15, velocidad_minima)
	var rumbo_j := Vector2(jvel.x, jvel.z)
	var cant := seguidoras.size()
	for i in cant:
		var p := seguidoras[i]
		var dist_j := p.global_position.distance_to(jpos)
		# Las lejanas se actualizan 1 de cada 3 frames (con delta triple)
		var paso := delta
		if dist_j > distancia_lejana:
			if (_frame + i) % 3 != 0:
				continue
			paso = delta * 3.0

		var pos := p.global_position
		var sep := Vector3.ZERO
		var ali := Vector3.ZERO
		var coh := Vector3.ZERO
		var vecinos := 0
		for k in cant:
			if k == i:
				continue
			var o := seguidoras[k]
			var d := pos - o.global_position
			var dl := d.length()
			if dl < radio_separacion and dl > 0.001:
				sep += d / (dl * dl)
			if dl < radio_vecinos:
				ali += o.velocidad
				coh += o.global_position
				vecinos += 1
		if vecinos > 0:
			ali = ali / vecinos - p.velocidad
			coh = coh / vecinos - pos

		# Punto propio en la formación alrededor de la jugadora (un poco detrás si va rápido)
		var objetivo := jpos + Vector3(p.desplazamiento.x, 0, p.desplazamiento.z)
		if rumbo_j.length() > 1.0:
			var atras := -Vector3(rumbo_j.x, 0, rumbo_j.y).normalized()
			objetivo += atras * (1.5 + rumbo_j.length() * 0.15)
		var aterrizar := j_suelo and dist_j < 7.0
		if aterrizar:
			objetivo.y = p.altura_suelo
		else:
			objetivo.y = jpos.y + p.desplazamiento.y

		var hacia := objetivo - pos
		var deseada := hacia.limit_length(1.0) * vel_max
		if hacia.length() > 1.0:
			deseada = hacia.normalized() * minf(vel_max + hacia.length() * 0.35, 30.0)
		var seek := deseada - p.velocidad

		var acel := sep * peso_separacion + ali * peso_alineacion + coh * peso_cohesion + seek * peso_seguir
		if aterrizar:
			acel.y = seek.y * peso_seguir * 2.0   # Al aterrizar no se amontonan en altura
		var nueva := p.velocidad + acel * paso
		var limite := minf(vel_max + hacia.length() * 0.35, 30.0)
		if aterrizar and hacia.length() < 1.5:
			limite = 2.6
		nueva = nueva.limit_length(limite)

		# Animación según cómo se mueve
		var anim := 2
		if p.en_suelo and aterrizar:
			anim = 0
			nueva.y = 0.0
		elif j_picada and dist_j < 12.0:
			anim = 3
		elif nueva.y > 0.6 or nueva.length() < 3.0:
			anim = 1
		p.mover_como_seguidora(paso, nueva, anim)


## Si quedan pocas palomas sueltas en el mapa, llegan algunas volando desde afuera.
func _llegadas(delta: float) -> void:
	_timer_llegada -= delta
	if _timer_llegada > 0.0:
		return
	_timer_llegada = intervalo_llegada
	var sueltas := 0
	for n in get_children():
		var p := n as PalomaNPC
		if p and p.modo != PalomaNPC.Modo.SIGUIENDO:
			sueltas += 1
	if sueltas >= minimo_sueltas or get_child_count() >= maximo_total:
		return
	var z := _zona_al_azar()
	if z == null:
		return
	var borde := Vector3(randf_range(-55, 55), 18.0, -38.0 if randf() < 0.5 else 38.0)
	var p := ESCENA_PALOMA.instantiate() as PalomaNPC
	p.randomizar_colores()
	add_child(p)
	p.global_position = borde
	p.soltar(borde + Vector3(0, 0, 1))
	p.ir_a_zona(z.global_position, z.get_meta("radio", 5.0))
