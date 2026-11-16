extends Node
## Prueba automática del aletazo (headless):
## godot --headless --path . res://tests/test_aletazo.tscn
## Usa un archivo de logros aparte: no toca el progreso del jugador.

const ARCHIVO_LOGROS := "user://test_logros_aletazo.cfg"

var fallas := 0
var main: Node
var paloma: PalomaJugador


func _ready() -> void:
	var archivo_real := Logros.archivo
	Logros.forzar = true
	Logros.archivo = ARCHIVO_LOGROS
	Logros.borrar_todo()
	main = load("res://main.tscn").instantiate()
	add_child(main)
	paloma = main.get_node("Paloma") as PalomaJugador
	await _fisica(15)
	GameState.menu_activo = false
	GameState.en_partida = true
	paloma.controlable = true

	await _animacion()
	await _comida()
	await _objetos()
	await _sombrero()
	await _palomas()
	await _entrada()

	GameState.en_partida = false
	Logros.borrar_todo()
	Logros.forzar = false
	Logros.archivo = archivo_real
	Logros.cargar()
	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Pone a la paloma en el piso a "dist" metros de "objetivo" (en el plano), mirándolo.
func _ubicar_frente_a(objetivo: Vector3, dist := 0.7, desde := Vector3(0.6, 0.0, 0.0)) -> void:
	var piso := Vector3(objetivo.x, 0.12, objetivo.z) + desde.normalized() * dist
	paloma.global_position = piso
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	var d := objetivo - piso
	paloma._rumbo = atan2(-d.x, -d.z)
	paloma.modelo.rotation.y = paloma._rumbo


# ---------------------------------------------------------------- Animación

func _animacion() -> void:
	var m := paloma.modelo
	m.aletazo(true)
	_check("animación: el aletazo agrega su modificador al esqueleto", m._aletazo != null and m._aletazo.esta_golpeando())
	await get_tree().create_timer(AletazoPaloma.DURACION * 0.5).timeout
	_check("animación: gira el ala mientras dura el golpe (%d veces)" % m._aletazo.aplicaciones, m._aletazo.aplicaciones >= 3)
	await get_tree().create_timer(AletazoPaloma.DURACION).timeout
	var aplicadas := m._aletazo.aplicaciones
	await get_tree().create_timer(0.2).timeout
	_check("animación: al terminar deja de girar el ala", not m._aletazo.esta_golpeando() and m._aletazo.aplicaciones == aplicadas)
	# La curva pasa de los 90°: el ala barre por delante del cuerpo, y empieza y termina en reposo
	_check("animación: la curva barre hacia adelante (pasa de 90°) y vuelve a 0", AletazoPaloma.curva(0.58).x > 90.0
		and AletazoPaloma.curva(0.0).x == 0.0 and AletazoPaloma.curva(1.0).x == 0.0)
	var continua := true
	var previo := AletazoPaloma.curva(0.0)
	for i in range(1, 101):
		var c := AletazoPaloma.curva(i / 100.0)
		if c.distance_to(previo) > 18.0:
			continua = false
		previo = c
	_check("animación: la curva no da saltos bruscos", continua)
	# Empieza con una ala y la siguiente con la otra
	m.aletazo(false)
	_check("animación: puede hacerlo con la otra ala", not m._aletazo._izquierda)
	await get_tree().create_timer(AletazoPaloma.DURACION + 0.1).timeout


# ---------------------------------------------------------------- Comida

func _comida() -> void:
	var medialuna: Comida = null
	for n in get_tree().get_nodes_in_group("comida"):
		var c := n as Comida
		if c and c.tipo == "medialuna":
			medialuna = c
			break
	_check("comida: hay una medialuna en una mesa", medialuna != null)
	if medialuna == null:
		return
	var origen := medialuna.global_position
	_ubicar_frente_a(origen)
	var golpes0 := Logros.valor("golpes")
	paloma._golpear_adelante()
	_check("comida: el golpe la despide (está en el aire)", medialuna._volando)
	await _fisica(60)
	var distancia := Vector2(medialuna.global_position.x - origen.x, medialuna.global_position.z - origen.z).length()
	_check("comida: cae lejos de la mesa (%.1f m)" % distancia, not medialuna._volando and distancia > 1.0)
	_check("comida: cayó al piso, no flota (y=%.2f)" % medialuna.global_position.y, medialuna.global_position.y < origen.y - 0.5)
	_check("comida: sigue siendo comida (se puede picotear)", medialuna.activa and medialuna.is_in_group("comida"))
	_check("comida: el golpe cuenta (%d)" % int(Logros.valor("golpes") - golpes0), Logros.valor("golpes") > golpes0 and Logros.hecho("plaf"))
	# Si la comen, vuelve a la mesa
	medialuna._reaparecer()
	_check("comida: al reaparecer vuelve a su mesa", medialuna.global_position.distance_to(origen) < 0.01)

	# Con el choripán no pasa nada
	var chori := Comida.new()
	chori.tipo = "choripan"
	main.add_child(chori)
	chori.global_position = Vector3(0, 0.1, 0)
	_check("comida: el choripán no se puede golpear", not chori.golpear(Vector3.FORWARD))
	chori.queue_free()


# ---------------------------------------------------------------- Objetos de las mesas

func _objetos() -> void:
	var objetos := get_tree().get_nodes_in_group("golpeables")
	_check("objetos: hay cosas para tirar en las mesas (%d)" % objetos.size(), objetos.size() >= 6)
	var g := objetos[objetos.size() - 1] as Golpeable    # De otra mesa que la de la medialuna de antes
	var origen := g.global_position
	_check("objetos: quietos están congelados (no gastan física)", g.freeze and not g.golpeado)
	_check("objetos: no bloquean a la paloma (capa 5, ella no la mira)", g.collision_layer == 16 and (paloma.collision_mask & 16) == 0)
	_ubicar_frente_a(origen)
	paloma._golpear_adelante()
	_check("objetos: el golpe lo descongela", g.golpeado and not g.freeze)
	await _fisica(90)
	var lejos := g.global_position.distance_to(origen)
	_check("objetos: sale despedido y cae (%.2f m)" % lejos, lejos > 0.3)
	_check("objetos: con el tiempo vuelve a su lugar", true)
	g._t_vuelta = 0.0
	await _fisica(3)
	_check("objetos: al volver queda en su lugar y congelado", g.global_position.distance_to(origen) < 0.01 and g.freeze and not g.golpeado)


# ---------------------------------------------------------------- Sombreros

func _sombrero() -> void:
	var humano: Humano = null
	for n in get_tree().get_nodes_in_group("humanos"):
		var h := n as Humano
		if h and h.tipo != "senora" and (h.modelo.accesorio == "sombrero" or h.modelo.accesorio == "gorra"):
			humano = h
			break
	_check("sombreros: hay alguien con sombrero o gorra", humano != null)
	if humano == null:
		return
	var tenia := String(humano.modelo.accesorio)
	var sombreros0 := Logros.valor("sombreros")
	var cuerpo := humano.modelo.get_node_or_null("CuerpoFisico")
	_ubicar_frente_a(humano.global_position, 0.8, Vector3(0.0, 0.0, 1.0))
	humano.set_physics_process(false)    # Que no se mueva mientras se prueba
	paloma._golpear_adelante()
	_check("sombreros: le tira el %s" % tenia, humano.modelo.accesorio == "ninguno")
	_check("sombreros: la persona se queda sorprendida con los brazos arriba", humano._por_sorpresa and humano._atendiendo != null)
	var sombrero_suelto: Golpeable = null
	for n in get_tree().get_nodes_in_group("golpeables"):
		var g := n as Golpeable
		if g and g.desechable and g.tipo == tenia:
			sombrero_suelto = g
	_check("sombreros: el sombrero es un objeto con física que salió volando", sombrero_suelto != null and sombrero_suelto.golpeado)
	_check("sombreros: cuenta en los logros (Sombrerazo)", Logros.valor("sombreros") >= sombreros0 + 1.0 and Logros.hecho("sombrerazo"))
	_check("sombreros: la persona sigue con su cuerpo físico (se rearmó)", humano.modelo.get_node_or_null("CuerpoFisico") != null
		and humano.modelo.get_node_or_null("CuerpoFisico") != cuerpo)
	# Sin sombrero no hay nada más que tirarle
	humano.set_physics_process(true)
	_check("sombreros: sin sombrero no hay nada que tirar", not humano.sombrerazo(Vector3.FORWARD))
	# Al rato se le pasa la sorpresa y sigue con lo suyo
	for i in 190:
		await get_tree().physics_frame
	_check("sombreros: se le pasa la sorpresa", not humano._por_sorpresa and humano._atendiendo == null)
	if is_instance_valid(sombrero_suelto):
		sombrero_suelto.queue_free()


# ---------------------------------------------------------------- Palomas sueltas

func _palomas() -> void:
	var suelta: PalomaNPC = null
	for n in get_tree().get_nodes_in_group("palomas_npc"):
		var p := n as PalomaNPC
		if p and p.modo == PalomaNPC.Modo.SUELTA:
			suelta = p
			break
	_check("palomas: hay una suelta", suelta != null)
	if suelta == null:
		return
	_ubicar_frente_a(suelta.global_position, 0.6, Vector3(0.0, 0.0, 1.0))
	paloma._golpear_adelante()
	_check("palomas: el aletazo asusta a una paloma suelta (sale volando)", suelta.modo != PalomaNPC.Modo.SUELTA)
	_check("palomas: asustar no la suma a la bandada", suelta.modo != PalomaNPC.Modo.SIGUIENDO)


# ---------------------------------------------------------------- Teclas

func _entrada() -> void:
	paloma.global_position = Vector3(0, 0.1, 40)
	paloma.velocity = Vector3.ZERO
	paloma.reset_physics_interpolation()
	paloma.estado = PalomaJugador.Estado.SUELO
	await _fisica(5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("  (sin ventana el mouse no se captura: las teclas se prueban con la API)")
		_check("teclas: la acción 'aletazo' existe con F y botón X del mando", _tiene_f_y_x())
		return
	_apretar("aletazo")
	await _fisica(4)
	_check("teclas: F hace el aletazo", paloma.modelo._aletazo != null and paloma.modelo._aletazo.esta_golpeando())
	var lado := paloma._ala_izquierda
	_apretar("aletazo")
	await _fisica(2)
	_check("teclas: no se puede encadenar sin pausa (enfriamiento)", paloma._ala_izquierda == lado)
	await _fisica(45)
	_apretar("aletazo")
	await _fisica(3)
	_check("teclas: el siguiente aletazo es con la otra ala", paloma._ala_izquierda != lado)
	paloma.estado = PalomaJugador.Estado.AIRE
	paloma._enfriamiento_aletazo = 0.0
	var antes := paloma._ala_izquierda
	_apretar("aletazo")
	await _fisica(3)
	_check("teclas: volando no hay aletazo", paloma._ala_izquierda == antes)
	_check("teclas: la acción 'aletazo' existe con F y botón X del mando", _tiene_f_y_x())


func _tiene_f_y_x() -> bool:
	var f := false
	var x := false
	for e in InputMap.action_get_events("aletazo"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F:
			f = true
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_X:
			x = true
	return f and x


func _apretar(accion: String) -> void:
	var e := InputEventAction.new()
	e.action = accion
	e.pressed = true
	Input.parse_input_event(e)
	var s := InputEventAction.new()
	s.action = accion
	s.pressed = false
	Input.parse_input_event(s)


func _fisica(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print("[%s] %s" % ["OK" if ok else "FALLA", nombre])
	if not ok:
		fallas += 1
