extends Node3D
## Tutorial integrado. La partida arranca con la paloma sentada en un banco del Cabildo; cuando
## salta al piso (después del menú principal) empieza una cinemática: la cámara se va hasta Doña
## Rosa, que les tira migas a las palomas, y se acerca de a poco para que se entienda que hay que
## comer migas. Después un cartel flotante sobre la paloma enseña las mecánicas (caminar hasta las
## migas, picotear, arrullar, despegar y picada) y avanza solo a medida que la jugadora hace cada
## cosa. Al final otra cinemática muestra el nido (la Pirámide) y el objetivo: el balcón de la
## Casa Rosada con 30 palomas. Las cinemáticas se saltean con cualquier tecla o click.
## Cada paso tiene un tiempo máximo para no trabarse. Si se va lejos, salta directo al objetivo.
## Las cinemáticas sólo están en el juego de verdad (main.gd prende con_cinematicas): las pruebas
## automáticas ven sólo los carteles.

signal intro_terminada

enum Paso { IR_A_LAS_MIGAS, PICOTEAR, ARRULLAR, DESPEGAR, PICADA, OBJETIVO, CATEDRAL }

const PASOS := [
	"Caminá hasta las migas de Doña Rosa\nWASD para moverte, el mouse para mirar",
	"Picoteá las migas con CLICK IZQUIERDO\nTe dan energía para volar y comida",
	"CLICK DERECHO cerca de las palomas para arrullar\nCada una que se suma a tu bandada cuesta 1 de comida",
	"ESPACIO para despegar\nMantenelo apretado para subir",
	"En el aire, SHIFT para tirarte en picada\n¡Soltalo y salís disparada para arriba!",
	"OBJETIVO: juntá 30 palomas\ny tomá el balcón de la Casa Rosada",
	"¡Bien! Andá a la Catedral (al norte)\na reclutar más palomas",
]
## Los mismos pasos en la versión para teléfonos (controles táctiles)
const PASOS_MOVIL := [
	"Caminá hasta las migas de Doña Rosa\nJoystick a la izquierda, deslizá a la derecha para mirar",
	"Tocá PICOTEAR cerca de las migas\nTe dan energía para volar y comida",
	"Tocá ARRULLAR cerca de las palomas\nCada una que se suma a tu bandada cuesta 1 de comida",
	"Tocá DESPEGAR para volar\nMantené ALETEAR apretado para subir",
	"En el aire, mantené PICADA para tirarte en picada\n¡Soltala y salís disparada para arriba!",
	"OBJETIVO: juntá 30 palomas\ny tomá el balcón de la Casa Rosada",
	"¡Bien! Andá a la Catedral (al norte)\na reclutar más palomas",
]
const LEJOS := 32.0               ## Metros desde el banco: más allá se saltea al objetivo

var con_cinematicas := false      ## Lo prende main.gd en el juego de verdad
var paso := -1

var _cartel: Label3D
var _flecha: FlechaObjetivo       ## Marca las migas de Doña Rosa en los primeros pasos
var _jugador: PalomaJugador
var _migas: Node3D                ## El generador de migas de Doña Rosa
var _hud: CanvasLayer
var _inicio := Vector3.ZERO
var _t := 0.0
var _t_paso := 0.0
var _terminado := false
var _espera_suelo := 0.0
var _migas_al_empezar := 0
var _hizo_picada := false

# Cinemáticas
var _barras: BarrasCinematica
var _camara: CamaraCinematica
var _en_cinematica := false
var _saltear := false
var _t_cine := 0.0


func _ready() -> void:
	_cartel = Label3D.new()
	_cartel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cartel.font_size = 56
	_cartel.pixel_size = 0.0032
	_cartel.outline_size = 14
	_cartel.modulate = Color("fffaf0")
	_cartel.outline_modulate = Color(0.3, 0.2, 0.4)
	_cartel.no_depth_test = true
	_cartel.render_priority = 5
	add_child(_cartel)
	_cartel.visible = false
	_barras = BarrasCinematica.new()
	add_child(_barras)


## ¿Va a haber cinemática de entrada? (main.gd no devuelve el control ni muestra el HUD hasta que
## termina). Se pregunta con la partida ya reiniciada.
func va_a_haber_intro() -> bool:
	return con_cinematicas and not GameState.tutorial_hecho


## Arranca cuando ya hay partida (con el menú principal en pantalla todavía no la hay) y, después
## del salto del banco, cuando la paloma se apoya en el piso (o a los 3 s).
func _intentar_empezar(delta: float) -> void:
	if not GameState.en_partida or GameState.menu_activo:
		return
	if GameState.tutorial_hecho:
		_terminado = true
		queue_free()   # Partida continuada: el tutorial ya se hizo
		return
	var j := GameState.jugador
	if j == null:
		return
	_espera_suelo += delta
	if j.estado != PalomaJugador.Estado.SUELO and _espera_suelo < 3.0:
		return
	_jugador = j
	_inicio = j.global_position
	_migas = get_parent().find_child("MigasDonaRosa", true, false) as Node3D
	_hud = get_parent().get_node_or_null("HUD") as CanvasLayer
	_migas_al_empezar = GameState.migas_comidas
	_crear_flecha()
	if con_cinematicas:
		_intro()
	else:
		_mostrar(Paso.IR_A_LAS_MIGAS)


func _intro() -> void:
	await _cinematica_dona_rosa()
	intro_terminada.emit()
	_mostrar(Paso.IR_A_LAS_MIGAS)


func _mostrar(n: int) -> void:
	paso = n
	_t_paso = 0.0
	_cartel.visible = true
	_cartel.text = (PASOS_MOVIL if Ajustes.movil else PASOS)[n]
	_cartel.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_cartel, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.reproducir("recoger", -10.0, false)


func _process(delta: float) -> void:
	if _terminado:
		return
	if _jugador == null:
		_intentar_empezar(delta)
		return
	_t += delta
	_t_paso += delta
	_t_cine += delta
	# El cartel flota un poco por delante y arriba de la paloma
	var objetivo := _jugador.global_position + Vector3(0, 1.5 + sin(_t * 2.0) * 0.05, 0)
	_cartel.global_position = _cartel.global_position.lerp(objetivo, minf(delta * 4.0, 1.0)) if _t > 0.1 else objetivo
	if _flecha:
		_flecha.activa = not _en_cinematica and paso <= Paso.ARRULLAR
	if _en_cinematica or paso < 0:
		return

	var en_suelo := _jugador.estado == PalomaJugador.Estado.SUELO
	# Si se aleja mucho del banco, va directo al objetivo
	if _jugador.global_position.distance_to(_inicio) > LEJOS and paso < Paso.OBJETIVO and en_suelo:
		_objetivo()
		return
	match paso:
		Paso.IR_A_LAS_MIGAS:
			var cerca := _migas != null and _distancia_plana(_migas.global_position) < 2.8
			var sin_migas := _migas == null and _jugador.global_position.distance_to(_inicio) > 2.0
			if cerca or sin_migas or GameState.migas_comidas > _migas_al_empezar or _t_paso > 20.0:
				_mostrar(Paso.PICOTEAR)
		Paso.PICOTEAR:
			if GameState.migas_comidas >= _migas_al_empezar + 2 or GameState.comida >= 3 or _t_paso > 20.0:
				_mostrar(Paso.ARRULLAR)
		Paso.ARRULLAR:
			if GameState.bandada >= 1 or _t_paso > 15.0:
				_mostrar(Paso.DESPEGAR)
		Paso.DESPEGAR:
			if _jugador.estado == PalomaJugador.Estado.AIRE and _t_paso > 0.5:
				_mostrar(Paso.PICADA)
		Paso.PICADA:
			if _jugador.en_picada:
				_hizo_picada = true
			# El objetivo se muestra con la paloma ya apoyada (si no se cansó de esperar)
			if ((_hizo_picada or _t_paso > 12.0) and en_suelo) or _t_paso > 25.0:
				_objetivo()
		Paso.OBJETIVO:
			if _t_paso > 6.0:
				_mostrar(Paso.CATEDRAL)
		Paso.CATEDRAL:
			if _t_paso > 6.0:
				_terminar()


func _distancia_plana(p: Vector3) -> float:
	return Vector2(_jugador.global_position.x - p.x, _jugador.global_position.z - p.z).length()


## El objetivo: con cinemáticas, la cámara muestra el nido y el balcón; si no, un cartel.
func _objetivo() -> void:
	if not con_cinematicas:
		_mostrar(Paso.OBJETIVO)
		return
	paso = Paso.OBJETIVO
	await _cinematica_objetivo()
	_mostrar(Paso.CATEDRAL)


func _terminar() -> void:
	_terminado = true
	GameState.tutorial_hecho = true
	GameState.actualizar_objetivo()
	if _flecha:
		_flecha.queue_free()
	var tw := create_tween()
	tw.tween_property(_cartel, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_cartel, "outline_modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


## Flecha amarilla que gira y rebota sobre las migas de Doña Rosa.
func _crear_flecha() -> void:
	if _migas == null:
		return
	_flecha = FlechaObjetivo.new()
	_flecha.destino = _migas
	_flecha.activa = false
	add_child(_flecha)


# ---------------------------------------------------------------- Cinemáticas

## La cámara se va hasta Doña Rosa, que tira migas, y se acerca despacio.
func _cinematica_dona_rosa() -> void:
	var rosa := get_tree().get_first_node_in_group("dona_rosa") as Humano
	if rosa == null or _migas == null:
		return
	_entrar_cinematica()
	var r := rosa.global_position
	var m := _migas.global_position
	var foco := r.lerp(m, 0.5) + Vector3.UP * 0.6
	# La cámara la toma de frente y de costado, del lado de donde viene la paloma
	var frente := m - r
	frente.y = 0.0
	var hacia_jugador := _jugador.global_position - foco
	hacia_jugador.y = 0.0
	var dir := (frente.normalized() * 0.7 + hacia_jugador.normalized()).normalized()
	var lejos := foco + dir * 6.0 + Vector3.UP * 1.7
	var cerca := foco + dir * 3.8 + Vector3.UP * 0.8
	_barras.texto("¡Hola, paloma flaca! ¿Ves a Doña Rosa?")
	if await _toma(lejos, foco, 50.0, 2.2, 1.2):
		rosa.tirar_migas_ya()
		_barras.texto("Todas las mañanas les tira migas a las palomas del Cabildo")
		_camara.volar(cerca, foco, 42.0, 4.2, 0.0, false)   # El acercamiento lento
		if await _esperar(2.2):
			rosa.tirar_migas_ya()
			_barras.texto("Las migas te dan energía para volar... ¡y comida para armar tu bandada!")
			if await _esperar(2.4):
				_barras.texto("¡Andá a comer vos también!")
				await _esperar(1.4)
	# Al volver, la cámara del juego ya mira hacia las migas (y la flecha)
	_mirar_hacia(m, -0.2)
	await _salir_cinematica(1.3, 0.8)


## El nido (la Pirámide) y después el balcón de la Casa Rosada, que es el objetivo.
func _cinematica_objetivo() -> void:
	var nido := get_tree().get_first_node_in_group("nido") as Node3D
	var balcon := get_tree().get_first_node_in_group("balcon") as Node3D
	if nido == null or balcon == null:
		return
	_entrar_cinematica()
	var n := nido.global_position
	var b := balcon.global_position
	# El nido, visto desde el lado de la paloma y un poco de costado
	var desde_j := _jugador.global_position - n
	desde_j.y = 0.0
	desde_j = desde_j.normalized() if desde_j.length() > 1.0 else Vector3.LEFT
	var costado := desde_j.cross(Vector3.UP)
	var mira_nido := n + Vector3.UP * 9.5   # Así entra el cartel del nido (a 15-16 m)
	var p_nido := n + desde_j * 18.0 + costado * 6.0 + Vector3.UP * 10.0
	# El balcón, desde la plaza (mira al oeste) y un poco del lado sur
	var hacia_plaza := n - b
	hacia_plaza.y = 0.0
	hacia_plaza = hacia_plaza.normalized()
	var mira_balcon := b + Vector3.UP * 0.8
	var p_balcon := b + hacia_plaza * 27.0 + Vector3(0, 3.5, 9.0)
	var p_balcon_cerca := b + hacia_plaza * 19.0 + Vector3(0, 2.2, 6.0)

	_barras.texto("Este es tu nido: la Pirámide de Mayo")
	if await _toma(p_nido, mira_nido, 60.0, 2.6, 4.0):
		_barras.texto("La comida grande (medialunas, papas, facturas) llevala al nido")
		var empuje := (mira_nido - p_nido) * 0.18
		empuje.y = 0.0   # Se acerca sin bajar, así el cartel del nido sigue en cuadro
		_camara.volar(p_nido + empuje, mira_nido, 56.0, 3.2, 0.0, false)
		if await _esperar(3.0):
			_barras.texto("OBJETIVO: juntá 30 palomas y tomá el balcón de la Casa Rosada")
			if await _toma(p_balcon, mira_balcon, 50.0, 2.6, 5.0):
				_camara.volar(p_balcon_cerca, mira_balcon, 44.0, 4.0, 0.0, false)
				if await _esperar(1.8):
					_barras.texto("Con 30 palomas los granaderos se distraen... ¡y la plaza es nuestra!")
					await _esperar(2.6)
	await _salir_cinematica(2.4, 6.0)


## La paloma queda quieta e intocable, se va el HUD, entran las franjas y la cámara de cine toma
## el lugar de la del juego.
func _entrar_cinematica() -> void:
	_en_cinematica = true
	_saltear = false
	_t_cine = 0.0
	_cartel.visible = false
	_jugador.controlable = false
	_jugador.camara.bloqueada = true
	GameState.invulnerable = maxf(GameState.invulnerable, 60.0)
	if _hud:
		_hud.visible = false
	_camara = CamaraCinematica.new()
	_camara.top_level = true
	add_child(_camara)
	_camara.empezar(_jugador.camara.camara)
	_barras.mostrar()


## Gira la cámara del juego (que todavía no se ve) para que mire hacia "punto".
func _mirar_hacia(punto: Vector3, pitch: float) -> void:
	var d := punto - _jugador.global_position
	d.y = 0.0
	if d.length() < 0.5:
		return
	_jugador.camara.yaw = atan2(-d.x, -d.z)
	_jugador.camara.pitch = pitch


## Vuelve a la cámara del juego (si no estaba volviendo ya por saltear) y devuelve el control.
func _salir_cinematica(duracion: float, arco: float) -> void:
	_jugador.camara.bloqueada = false
	if _camara.estado != CamaraCinematica.Estado.TERMINADA:
		_camara.volver(duracion, arco)
		await _camara.llego
	_camara.queue_free()
	_camara = null
	_barras.ocultar()
	_jugador.controlable = true
	GameState.invulnerable = 1.0
	if _hud and _hud.has_method("mostrar"):
		_hud.mostrar()
	_en_cinematica = false


## Una toma: devuelve false si la saltearon mientras tanto.
func _toma(pos: Vector3, mira: Vector3, fov_toma: float, duracion: float, arco := 0.0) -> bool:
	if _saltear:
		return false
	_camara.volar(pos, mira, fov_toma, duracion, arco)
	await _camara.llego
	return not _saltear


## Espera (sin contar la pausa); devuelve false si la saltearon mientras tanto.
func _esperar(segundos: float) -> bool:
	var t := 0.0
	while t < segundos:
		if _saltear:
			return false
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time()
	return not _saltear


## Cualquier tecla (menos la pausa), click, toque o botón del mando saltea la cinemática.
func _input(event: InputEvent) -> void:
	if not _en_cinematica or _saltear or _t_cine < 0.6 or _camara == null:
		return
	var apretado := false
	if event is InputEventKey:
		apretado = event.pressed and not event.echo and not event.is_action("pausa")
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		apretado = event.is_pressed()
	if not apretado:
		return
	_saltear = true
	get_viewport().set_input_as_handled()
	_jugador.camara.bloqueada = false
	_camara.volver(0.8)
