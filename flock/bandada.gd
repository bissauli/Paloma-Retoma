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

@export_group("Choques")
@export var radio_cuerpo := 0.2           ## Radio de cada paloma: dos palomas no se acercan a menos del doble
@export var radio_jugadora := 0.24

@export_group("Población")
@export var minimo_sueltas := 14          ## Si quedan menos, llegan palomas nuevas volando
@export var maximo_total := 110
@export var intervalo_llegada := 6.0

var seguidoras: Array[PalomaNPC] = []
## Pasillo sin palomas [desde, hasta, radio] (en el plano XZ). Lo usa el menú principal para que
## ninguna se cruce entre la cámara y la paloma de la jugadora. Vacío = sin pasillo.
var zona_libre: Array = []
var _zonas: Array[Marker3D] = []
var _jugador: PalomaJugador
## Todas las palomas NPC (hijas de este nodo). Se mantiene sola al agregar o sacar hijos, así no
## hay que recorrer get_children() en cada paso de física.
var _palomas: Array[PalomaNPC] = []
var _frame := 0
var _timer_llegada := 0.0
var _aviso_sin_comida := 0.0
var descansando := false     ## La jugadora está descansando: las seguidoras se sientan a su lado
var en_calesita: Node3D      ## La calesita (o el subibaja) en que está montada la jugadora (null = ninguno)
var _saltarina: PalomaNPC    ## Subibaja: la paloma que salta de una punta a la otra
var _lado_salt := 0
var _t_salto := 0.0
var _rumbo_descanso := 0.0


func _ready() -> void:
	child_entered_tree.connect(func(n: Node) -> void:
		if n is PalomaNPC:
			_palomas.append(n as PalomaNPC))
	child_exiting_tree.connect(func(n: Node) -> void:
		if n is PalomaNPC:
			_palomas.erase(n as PalomaNPC)
			seguidoras.erase(n as PalomaNPC))
	add_to_group("bandada")
	GameState.arrullo.connect(_al_arrullar)
	GameState.cortejo.connect(_al_cortejar)
	GameState.perder_palomas.connect(_al_perder)
	GameState.victoria.connect(_al_ganar)
	_poblar.call_deferred()


## Crea las palomas iniciales en cada zona marcada por la plaza.
func _poblar() -> void:
	_jugador = GameState.jugador
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


## Paloma NPC nueva (de color al azar) ya dentro de la bandada, en la posición global "pos".
func _nueva_paloma(pos: Vector3) -> PalomaNPC:
	var p := ESCENA_PALOMA.instantiate() as PalomaNPC
	p.randomizar_colores()
	add_child(p)
	p.global_position = pos
	return p


## Punto en el aire sobre el borde norte o sur del mapa, por donde llegan palomas nuevas.
func _punto_de_llegada() -> Vector3:
	return Vector3(randf_range(-55, 55), 18.0, -38.0 if randf() < 0.5 else 38.0)


## Paloma suelta apoyada en el piso.
func _crear_paloma(pos: Vector3) -> PalomaNPC:
	var p := _nueva_paloma(pos)
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
			break
		if not GameState.gastar_comida(Config.COSTO_RECLUTAR):
			break
		p.reclutar()
		seguidoras.append(p)
		reclutadas += 1
	if reclutadas > 0:
		AudioManager.reproducir("arrullo", -4.0)
		AudioManager.ui("purchase", -10.0)   # Gastó comida


## El baile de cortejo de la jugadora enamora a las palomas sueltas de alrededor: se suman a la
## bandada GRATIS (sin gastar comida), hasta CORTEJO_MAX por vez y las más cercanas primero.
## Cada una muestra su corazón (PalomaNPC.reclutar). Devuelve cuántas se sumaron.
func _al_cortejar(pos: Vector3, radio: float) -> int:
	var candidatas: Array[PalomaNPC] = []
	for n in get_children():
		var p := n as PalomaNPC
		if p and p.modo == PalomaNPC.Modo.SUELTA and p.global_position.distance_to(pos) <= radio:
			candidatas.append(p)
	candidatas.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	var enamoradas := 0
	for p in candidatas:
		if enamoradas >= Config.CORTEJO_MAX or not GameState.hay_lugar_en_bandada():
			break
		p.reclutar()
		seguidoras.append(p)
		enamoradas += 1
	if enamoradas > 0:
		AudioManager.reproducir("arrullo", -4.0)
		Logros.sumar("cortejos")
		Logros.sumar("cortejadas", enamoradas)
	return enamoradas


## Al continuar una partida guardada: suma "cantidad" palomas a la bandada sin gastar comida.
## Vienen las sueltas más cercanas y, si no alcanzan, llegan volando desde los bordes del mapa.
func restaurar(cantidad: int) -> void:
	if _jugador == null:
		_jugador = GameState.jugador
	var desde := _jugador.global_position if _jugador else Vector3.ZERO
	var sueltas: Array[PalomaNPC] = []
	for n in get_children():
		var p := n as PalomaNPC
		if p and p.modo == PalomaNPC.Modo.SUELTA:
			sueltas.append(p)
	sueltas.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(desde) < b.global_position.distance_squared_to(desde))
	for i in mini(cantidad, Config.BANDADA_MAX):
		var p: PalomaNPC
		if i < sueltas.size():
			p = sueltas[i]
		else:
			p = _nueva_paloma(_punto_de_llegada())
		p.reclutar()
		seguidoras.append(p)


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
		_nueva_paloma(Vector3(randf_range(-10, 36), 0, randf_range(-20, 20)))
	for n in get_children():
		var p := n as PalomaNPC
		if p:
			p.altura_suelo = p.medir_suelo(p.global_position)
			p.global_position.y = p.altura_suelo
			p.festejar()


## La jugadora descansa: cada seguidora vuela al puesto libre más cercano (los puestos vienen de
## Descanso.puestos) y se sienta mirando hacia "rumbo". Las que no tengan puesto siguen volando.
func descansar(puestos: Array[Vector3], rumbo: float) -> void:
	descansando = true
	_rumbo_descanso = rumbo
	var libres: Array[Vector3] = puestos.duplicate()
	var jpos := _jugador.global_position if _jugador else Vector3.ZERO
	var orden: Array[PalomaNPC] = seguidoras.duplicate()
	orden.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(jpos) < b.global_position.distance_squared_to(jpos))
	for p in orden:
		if libres.is_empty():
			break
		var mejor := 0
		var mejor_d := INF
		for k in libres.size():
			var d := p.global_position.distance_squared_to(libres[k])
			if d < mejor_d:
				mejor_d = d
				mejor = k
		p.puesto = libres[mejor]
		p.sentada = false
		libres.remove_at(mejor)


## La jugadora se subió al caballito "suyo" de la calesita: las seguidoras cercanas se suben a los
## caballitos que quedan libres (las más cercanas a cada uno) y las que sobran bailan alrededor, por
## fuera de la calesita.
func subir_calesita(suyo: Marker3D) -> void:
	var cal := suyo.get_parent() as Node3D
	if cal == null:
		return
	en_calesita = cal
	var centro := cal.global_position
	var libres: Array[Marker3D] = []
	var animado := cal as Animado
	for n in get_tree().get_nodes_in_group("caballitos"):
		var m := n as Marker3D
		if m == null or m == suyo:
			continue
		var dueno := m.get_parent() as Animado
		if m.get_parent() == cal or (animado != null and animado.compania != null and dueno == animado.compania):
			# Los que ya tienen un chico (o una paloma) sentado no se pueden usar
			if dueno and (dueno.humano_sentado(int(m.get_meta("indice", -1))) or dueno.ocupado_por_paloma(int(m.get_meta("indice", -1)))):
				continue
			libres.append(m)
	# Sólo las que están cerca de la calesita se suman
	var candidatas: Array[PalomaNPC] = []
	for p in seguidoras:
		if p.global_position.distance_to(centro) <= 35.0:
			candidatas.append(p)
	candidatas.sort_custom(func(a: PalomaNPC, b: PalomaNPC) -> bool:
		return a.global_position.distance_squared_to(centro) < b.global_position.distance_squared_to(centro))
	var sobran: Array[PalomaNPC] = []
	# Subibaja: la más cercana se sienta en la punta de enfrente y otra es la que salta de un lado al
	# otro (su punta baja). Con una sola paloma, ella es la que salta.
	var es_subibaja := animado != null and animado.tipo == "subibaja"
	var saltarina: PalomaNPC = null
	_saltarina = null
	if es_subibaja:
		animado.lado_pesado = -1
		if candidatas.size() == 1:
			libres.clear()
	for p in candidatas:
		if es_subibaja and libres.is_empty() and saltarina == null:
			saltarina = p
			continue
		if libres.is_empty():
			sobran.append(p)
			continue
		var mejor := 0
		var mejor_d := INF
		for k in libres.size():
			var d := p.global_position.distance_squared_to(libres[k].global_position)
			if d < mejor_d:
				mejor_d = d
				mejor = k
		p.caballito = libres[mejor]
		var dueno_m := libres[mejor].get_parent() as Animado
		if dueno_m:
			dueno_m.marcar_paloma(int(libres[mejor].get_meta("indice", -1)), p)
		p.baila_afuera = false
		p.sentada = false
		libres.remove_at(mejor)
	if saltarina:
		_lado_salt = 1 - int(suyo.get_meta("indice", 0))
		var spot := _lugar_de_salto(cal, _lado_salt)
		if spot:
			saltarina.caballito = spot
			saltarina.baila_afuera = false
			saltarina.sentada = false
			_saltarina = saltarina
			_t_salto = 2.2
		else:
			sobran.push_front(saltarina)
	# Las que sobran: en anillos por fuera (de la calesita o del subibaja), sobre el piso del parque
	var radio_base: float = animado.radio_baile if animado else 5.5
	var fila := 0
	var en_fila := 0
	var radio := radio_base
	var cupo := maxi(int(TAU * radio / 0.75), 1)
	var a0 := randf() * TAU
	for p in sobran:
		if en_fila >= cupo:
			fila += 1
			en_fila = 0
			radio = radio_base + fila * 0.95
			cupo = maxi(int(TAU * radio / 0.75), 1)
		var ang := a0 + TAU * en_fila / float(cupo) + fila * 0.4
		var pos := centro + Vector3(cos(ang) * radio, 0.0, sin(ang) * radio)
		pos.y = p.medir_suelo(pos)
		p.puesto = pos
		p.baila_afuera = true
		p._llego_baile = false
		p.sentada = false
		en_fila += 1


## El lugar de la paloma que salta en la punta "lado" (0 o 1) del subibaja, o null.
func _lugar_de_salto(cal: Node3D, lado: int) -> Marker3D:
	for n in get_tree().get_nodes_in_group("extras_subibaja"):
		var m := n as Marker3D
		if m and m.get_parent() == cal and int(m.get_meta("indice", -1)) == 2 + lado:
			return m
	return null


## Cada tanto la paloma que salta cruza al otro lado del subibaja; cuando cae, esa punta baja.
func _actualizar_subibaja(delta: float) -> void:
	if _saltarina == null or not is_instance_valid(_saltarina) or not (en_calesita is Animado):
		return
	var an := en_calesita as Animado
	if _saltarina.caballito == null or not _saltarina.sentada:
		return
	an.lado_pesado = int(_saltarina.caballito.get_meta("indice", 2)) - 2
	_t_salto -= delta
	if _t_salto > 0.0:
		return
	_t_salto = 2.4
	_lado_salt = 1 - _lado_salt
	var spot := _lugar_de_salto(an, _lado_salt)
	if spot:
		_saltarina.saltar_a(spot)


## La jugadora se baja de la calesita: todas vuelven a seguirla.
func bajar_calesita() -> void:
	if en_calesita is Animado:
		var an := en_calesita as Animado
		an.lado_pesado = -1
		an.palomas_en.clear()
		if an.compania:
			an.compania.palomas_en.clear()
	_saltarina = null
	en_calesita = null
	for p in seguidoras:
		if p.caballito != null or p.baila_afuera:
			p.levantar()


## La jugadora hace un emote: al menos la mitad de la bandada cercana hace el mismo y el resto, el mismo u otro
## al azar. Empiezan escalonadas para que no se vea todo sincronizado.
func imitar_baile(baile: StringName) -> void:
	if _jugador == null:
		_jugador = GameState.jugador
	var jpos := _jugador.global_position if _jugador else Vector3.ZERO
	var aptas: Array[PalomaNPC] = []
	for p in seguidoras:
		if p.controlada or p.tiene_puesto() or p.global_position.distance_to(jpos) > 40.0:
			continue
		aptas.append(p)
	aptas.shuffle()
	var iguales := ceili(aptas.size() * 0.5)
	for i in aptas.size():
		var p := aptas[i]
		var cual: StringName = baile
		if i >= iguales and randf() < 0.6:
			cual = Coreografia.ORDEN[randi() % Coreografia.ORDEN.size()]
		p.bailar_emote(cual, randf_range(0.0, 0.6))


## La jugadora dejó de bailar: todas retoman lo suyo.
func parar_baile() -> void:
	for p in seguidoras:
		p.parar_emote()


## Cuántas seguidoras ya están sentadas en su puesto.
func cantidad_sentadas() -> int:
	var n := 0
	for p in seguidoras:
		if p.sentada:
			n += 1
	return n


## La jugadora se levanta: todas retoman el vuelo con ella.
func levantarse() -> void:
	descansando = false
	for p in seguidoras:
		if p.tiene_puesto():
			p.levantar()


## La jugadora golpeó a una seguidora: se va de la bandada llorando.
func expulsar(p: PalomaNPC, desde: Vector3) -> void:
	if not seguidoras.has(p):
		return
	seguidoras.erase(p)
	p.llorar(desde, _zona_al_azar())


func _zona_al_azar() -> Marker3D:
	if _zonas.is_empty():
		return null
	return _zonas[randi() % _zonas.size()]


# ---------------------------------------------------------------- Boids

var _obstaculos_fijos: Array = []    ## Gente y autos, releídos cada 3 pasos (ver _resolver_choques)


func _physics_process(delta: float) -> void:
	_frame += 1
	_aviso_sin_comida = maxf(_aviso_sin_comida - delta, 0.0)
	if _jugador == null or not is_instance_valid(_jugador):
		return
	if not GameState.partida_terminada:  # En la victoria cada paloma festeja por su cuenta
		_actualizar_subibaja(delta)
		_mover_seguidoras(delta)
		_llegadas(delta)
	# Un paso de física sí y otro no (las palomas se mueven despacio): reparte el costo entre los cuadros
	if _frame % 2 == 0:
		_resolver_choques()


# ---------------------------------------------------------------- Choques

## Las palomas NPC no usan física, así que acá se separan a mano para que no se atraviesen:
## entre ellas (se empujan las dos), y contra la jugadora y la gente (sólo se corre la paloma).
## Usa una grilla de 1 m (listas enlazadas en arreglos, sin crear un arreglo por celda) para no
## comparar todas contra todas.
func _resolver_choques() -> void:
	var cant := _palomas.size()
	if cant == 0:
		return
	var pos := PackedVector3Array()
	pos.resize(cant)
	var cx := PackedInt32Array()
	cx.resize(cant)
	var cz := PackedInt32Array()
	cz.resize(cant)
	var siguiente := PackedInt32Array()
	siguiente.resize(cant)
	var primera := {}   # celda -> primera paloma de la celda (las demás siguen en "siguiente")
	for i in cant:
		var p := _palomas[i].global_position
		pos[i] = p
		var c := Vector2i(floori(p.x), floori(p.z))
		cx[i] = c.x
		cz[i] = c.y
		siguiente[i] = primera.get(c, -1)
		primera[c] = i
	var corr := PackedVector3Array()
	corr.resize(cant)

	# Paloma contra paloma
	var min_d := radio_cuerpo * 2.0
	var min_d2 := min_d * min_d
	for i in cant:
		var pi := pos[i]
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k: int = primera.get(Vector2i(cx[i] + dx, cz[i] + dz), -1)
				while k != -1:
					if k > i:
						var d := pos[k] - pi
						if absf(d.y) <= 0.35:
							var l2 := d.x * d.x + d.z * d.z
							if l2 < min_d2:
								var h: Vector2
								var l := sqrt(l2)
								if l < 0.001:
									h = Vector2.from_angle(float(i * 7 + k) * 1.3)  # Encimadas justo: las separa en cualquier dirección
									l = 0.0
								else:
									h = Vector2(d.x, d.z) / l
								var empuje := h * (min_d - l) * 0.5
								var e3 := Vector3(empuje.x, 0, empuje.y)
								corr[i] -= e3
								corr[k] += e3
					k = siguiente[k]

	# Obstáculos fijos para las palomas: la jugadora y cada humano (cilindros)
	var obstaculos: Array = [[_jugador.global_position, radio_jugadora, 0.45]]
	# La gente y los autos se releen cada 3 pasos de física (se mueven poco entre paso y paso)
	if _frame % 3 == 0 or _obstaculos_fijos.is_empty():
		_obstaculos_fijos.clear()
		for n in get_tree().get_nodes_in_group("cuerpos_humanos"):
			var m := n as ModeloHumano
			if m and m.is_visible_in_tree():
				_obstaculos_fijos.append([m.global_position, m.radio_colision(), m.alto_colision()])
		# Los autos: dos círculos cada uno (adelante y atrás)
		for n in get_tree().get_nodes_in_group("autos"):
			if n is Auto:
				_obstaculos_fijos.append_array((n as Auto).circulos())
	obstaculos.append_array(_obstaculos_fijos)
	for o: Array in obstaculos:
		var centro: Vector3 = o[0]
		var radio: float = o[1] + radio_cuerpo
		var alto: float = o[2]
		var ox := floori(centro.x)
		var oz := floori(centro.z)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var k: int = primera.get(Vector2i(ox + dx, oz + dz), -1)
				while k != -1:
					var p := pos[k] + corr[k]
					if p.y >= centro.y - 0.3 and p.y <= centro.y + alto:
						var h := Vector2(p.x - centro.x, p.z - centro.z)
						var l := h.length()
						if l < radio:
							h = h / l if l > 0.001 else Vector2.from_angle(float(k) * 2.1)
							var empuje := h * (radio - l)
							corr[k] += Vector3(empuje.x, 0, empuje.y)
					k = siguiente[k]

	if zona_libre.size() == 3:
		_despejar_pasillo(pos, corr)

	# Las correcciones también se chequean contra las paredes: si la bandada se aprieta contra
	# un edificio, ninguna queda empujada adentro. Las de menos de 1 mm no hacen falta.
	for i in cant:
		if corr[i].length_squared() > 0.000001 and not _palomas[i].sentada and not _palomas[i].controlada:
			_palomas[i].mover_con_choques(corr[i])


## Corre hacia afuera las palomas (en el piso) que estén dentro del pasillo libre.
func _despejar_pasillo(pos: PackedVector3Array, corr: PackedVector3Array) -> void:
	var a: Vector3 = zona_libre[0]
	var b: Vector3 = zona_libre[1]
	var radio: float = zona_libre[2] + radio_cuerpo
	var a2 := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - a2
	var largo2 := maxf(ab.length_squared(), 0.0001)
	for k in pos.size():
		var p := pos[k] + corr[k]
		if p.y > a.y + 1.5:
			continue
		var p2 := Vector2(p.x, p.z)
		var t := clampf((p2 - a2).dot(ab) / largo2, 0.0, 1.0)
		var h := p2 - (a2 + ab * t)
		var l := h.length()
		if l >= radio:
			continue
		h = h / l if l > 0.001 else ab.orthogonal().normalized()
		var empuje := h * minf(radio - l, 0.08)   # De a poco: se van caminando, no saltan
		corr[k] += Vector3(empuje.x, 0, empuje.y)


func _mover_seguidoras(delta: float) -> void:
	var cant := seguidoras.size()
	if cant == 0:
		return
	var jpos := _jugador.global_position
	var jvel := _jugador.velocity
	var j_suelo := _jugador.estado == PalomaJugador.Estado.SUELO
	var j_picada := _jugador.en_picada
	var vel_max := maxf(jvel.length() * 1.15, velocidad_minima)
	var rumbo_j := Vector2(jvel.x, jvel.z)
	# Si va rápido, la formación queda un poco detrás
	var atras := Vector3.ZERO
	if rumbo_j.length() > 1.0:
		atras = -Vector3(rumbo_j.x, 0, rumbo_j.y).normalized() * (1.5 + rumbo_j.length() * 0.15)

	# Posiciones y velocidades de todas una sola vez (leer global_position de un nodo cuesta)
	var pos := PackedVector3Array()
	pos.resize(cant)
	var vel := PackedVector3Array()
	vel.resize(cant)
	for i in cant:
		pos[i] = seguidoras[i].global_position
		vel[i] = seguidoras[i].velocidad
	# Separación, alineación y cohesión: cada par se mira una sola vez y suma a las dos
	var sep := PackedVector3Array()
	sep.resize(cant)
	var ali := PackedVector3Array()
	ali.resize(cant)
	var coh := PackedVector3Array()
	coh.resize(cant)
	var vecinos := PackedInt32Array()
	vecinos.resize(cant)
	var rs2 := radio_separacion * radio_separacion
	var rv2 := radio_vecinos * radio_vecinos
	for i in cant:
		var pi := pos[i]
		var vi := vel[i]
		var s_i := Vector3.ZERO
		var a_i := Vector3.ZERO
		var c_i := Vector3.ZERO
		var n_i := 0
		for k in range(i + 1, cant):
			var pk := pos[k]
			var d := pi - pk
			var dl2 := d.length_squared()
			if dl2 >= rv2:
				continue
			a_i += vel[k]
			c_i += pk
			n_i += 1
			ali[k] += vi
			coh[k] += pi
			vecinos[k] += 1
			if dl2 < rs2 and dl2 > 0.000001:
				var e := d / dl2
				s_i += e
				sep[k] -= e
		sep[i] += s_i
		ali[i] += a_i
		coh[i] += c_i
		vecinos[i] += n_i

	for i in cant:
		var p := seguidoras[i]
		if p.controlada:
			continue    # Juega o alienta en el partido de fútbol
		if p.bailando_emote:
			continue    # Imita el emote de la jugadora
		if (descansando or en_calesita != null) and p.tiene_puesto():
			p.paso_posada(delta, _rumbo_descanso)
			continue
		var pos_i := pos[i]
		var dist_j := pos_i.distance_to(jpos)
		# Las lejanas se actualizan 1 de cada 3 frames (con delta triple)
		var paso := delta
		if dist_j > distancia_lejana:
			if (_frame + i) % 3 != 0:
				continue
			paso = delta * 3.0

		var a := Vector3.ZERO
		var c := Vector3.ZERO
		if vecinos[i] > 0:
			a = ali[i] / vecinos[i] - vel[i]
			c = coh[i] / vecinos[i] - pos_i

		# Punto propio en la formación alrededor de la jugadora
		var objetivo := jpos + Vector3(p.desplazamiento.x, 0, p.desplazamiento.z) + atras
		var aterrizar := j_suelo and dist_j < 7.0
		if aterrizar:
			objetivo.y = p.altura_suelo
		else:
			objetivo.y = jpos.y + p.desplazamiento.y

		var hacia := objetivo - pos_i
		var largo_hacia := hacia.length()
		var deseada := hacia.limit_length(1.0) * vel_max
		if largo_hacia > 1.0:
			deseada = hacia / largo_hacia * minf(vel_max + largo_hacia * 0.35, 30.0)
		var seek := deseada - vel[i]

		var acel := sep[i] * peso_separacion + a * peso_alineacion + c * peso_cohesion + seek * peso_seguir
		if aterrizar:
			acel.y = seek.y * peso_seguir * 2.0   # Al aterrizar no se amontonan en altura
		var nueva := vel[i] + acel * paso
		var limite := minf(vel_max + largo_hacia * 0.35, 30.0)
		if aterrizar and largo_hacia < 1.5:
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
	for p in _palomas:
		if p.modo != PalomaNPC.Modo.SIGUIENDO:
			sueltas += 1
	if sueltas >= minimo_sueltas or get_child_count() >= maximo_total:
		return
	var z := _zona_al_azar()
	if z == null:
		return
	var borde := _punto_de_llegada()
	var p := _nueva_paloma(borde)
	p.soltar(borde + Vector3(0, 0, 1))
	p.ir_a_zona(z.global_position, z.get_meta("radio", 5.0))
