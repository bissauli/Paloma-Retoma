extends Node
## Logros y trofeos (autoload "Logros"). Lleva contadores acumulados de todas las partidas y
## desbloquea lo que define logros/catalogo_logros.gd. Escucha las
## señales del juego (GameState, Misiones, el perfil de la paloma) y mira a la paloma para contar
## picoteos, despegues, picadas y tiempo de vuelo; no toca el movimiento. Se guarda aparte de la
## partida (user://logros.cfg, logros_movil.cfg en el teléfono): sobrevive a "Nueva partida".
## Sólo cuenta en el juego de verdad (GameState.guardado_habilitado), así las pruebas automáticas
## no ensucian el archivo del jugador (las propias lo fuerzan con "forzar").

signal desbloqueado(id: String)

const GUARDAR_CADA := 10.0
const TIEMPO_VELOCISTA := 600.0

## Para las pruebas: cuenta aunque no sea el juego de verdad.
var forzar := false
var archivo := ""

var _stats := {}              ## contador -> float
var _hechos := {}             ## id -> instante (unix) en que se desbloqueó
var _bailes := {}             ## bailes distintos que bailó
var _sombreros := {}          ## sombreros distintos (tipo + color) que se puso
var _aviso: AvisoLogro
var _jugador: PalomaJugador   ## La paloma a la que ya se le escuchó el despegue
var _en_picada := false
var _bandada_previa := 0
var _sucio := false
var _t_guardado := 0.0


func _ready() -> void:
	archivo = "user://logros_movil.cfg" if Ajustes.movil else "user://logros.cfg"
	cargar()
	_aviso = AvisoLogro.new()
	add_child(_aviso)
	# Los demás autoloads ya existen cuando corre esto
	(func() -> void:
		GameState.victoria.connect(_al_ganar)
		GameState.bandada_cambio.connect(_al_cambiar_bandada)
		GameState.fase_dia_cambio.connect(func(t: float) -> void: maximo("dia", t * 100.0))
		GameState.arrullo.connect(func(_p: Vector3, _r: float) -> void: sumar("arrullos"))
		Misiones.mision_cambio.connect(_al_cambiar_mision)
		PerfilPaloma.actual().cambiado.connect(revisar_perfil)).call_deferred()


func activo() -> bool:
	return forzar or GameState.guardado_habilitado


func _process(delta: float) -> void:
	if _sucio:
		_t_guardado += delta
		if _t_guardado >= GUARDAR_CADA:
			guardar()
	if not activo() or not GameState.en_partida or GameState.partida_terminada:
		return
	var j := GameState.jugador
	if j == null:
		return
	if j != _jugador:
		_jugador = j
		j.despego.connect(func() -> void: sumar("despegues"))
	if j.controlable and Input.is_action_just_pressed("picotear"):
		sumar("picoteos")
	if j.estado == PalomaJugador.Estado.AIRE:
		sumar("tiempo_vuelo", delta)
	if j.en_picada and not _en_picada:
		sumar("picadas")
	_en_picada = j.en_picada


# ---------------------------------------------------------------- Consultas

func hecho(id: String) -> bool:
	return _hechos.has(id)


func valor(clave: String) -> float:
	return float(_stats.get(clave, 0.0))


## Avance de un logro con contador: {actual, meta}. Sin contador, meta 0.
func progreso(id: String) -> Dictionary:
	var d := CatalogoLogros.por_id(id)
	if not d.has("stat"):
		return {"actual": 1 if hecho(id) else 0, "meta": 0}
	var meta := int(d["meta"])
	return {"actual": mini(roundi(valor(d["stat"])), meta) if not hecho(id) else meta, "meta": meta}


func cantidad(tipo: String) -> int:
	var n := 0
	for d: Dictionary in CatalogoLogros.de_tipo(tipo):
		if hecho(d["id"]):
			n += 1
	return n


func total(tipo: String) -> int:
	return CatalogoLogros.de_tipo(tipo).size()


# ---------------------------------------------------------------- Registrar

## Suma "n" a un contador y desbloquea lo que ya llegó a su meta.
func sumar(clave: String, n := 1.0) -> void:
	if not activo():
		return
	_stats[clave] = valor(clave) + n
	_sucio = true
	_evaluar(clave)


## Guarda el máximo alcanzado de un contador (la bandada más grande, por ejemplo).
func maximo(clave: String, v: float) -> void:
	if not activo() or v <= valor(clave):
		return
	_stats[clave] = v
	_sucio = true
	_evaluar(clave)


func registrar_baile(baile: StringName) -> void:
	if not activo():
		return
	_bailes[baile] = true
	sumar("bailes")
	if _bailes.size() >= Coreografia.ORDEN.size() + 1:   # Todos los de la rueda (los del orden y el final)
		desbloquear("rey_baile")


## Un sombrero o gorra puesto: cuenta cada combinación de tipo y color una sola vez.
func registrar_sombrero(tipo: String, color: Color) -> void:
	if not activo():
		return
	sumar("sombreros_puestos")
	_sombreros[tipo + color.to_html(false)] = true
	maximo("sombreros_distintos", _sombreros.size())


func _evaluar(clave: String) -> void:
	for d: Dictionary in CatalogoLogros.con_stat(clave):
		if not hecho(d["id"]) and valor(clave) >= float(d["meta"]):
			desbloquear(d["id"])


## Desbloquea un logro o trofeo (si ya lo tenía, no hace nada) y avisa.
func desbloquear(id: String) -> void:
	if hecho(id) or CatalogoLogros.por_id(id).is_empty():
		return
	_hechos[id] = int(Time.get_unix_time_from_system())
	guardar()
	desbloqueado.emit(id)
	if _aviso:
		_aviso.mostrar(CatalogoLogros.por_id(id))
	_revisar_leyenda()


## El trofeo de platino: todos los demás.
func _revisar_leyenda() -> void:
	if hecho("leyenda"):
		return
	for d: Dictionary in CatalogoLogros.LISTA:
		if d["id"] != "leyenda" and not hecho(d["id"]):
			return
	desbloquear("leyenda")


# ---------------------------------------------------------------- Escuchas del juego

func _al_ganar() -> void:
	if not activo():
		return
	sumar("victorias")
	desbloquear("fin_juego")
	if GameState.capturas == 0:
		desbloquear("intocable")
	if GameState.tiempo_jugado <= TIEMPO_VELOCISTA:
		desbloquear("velocista")


func _al_cambiar_bandada(n: int) -> void:
	maximo("bandada_max", n)
	if n > _bandada_previa:
		sumar("reclutadas", n - _bandada_previa)
	_bandada_previa = n


func _al_cambiar_mision(_id: String, estado: String) -> void:
	if estado != Misiones.COMPLETADA:
		return
	sumar("misiones")
	for id: String in CatalogoMisiones.MISIONES:
		if Misiones.estado(id) != Misiones.COMPLETADA:
			return
	desbloquear("misiones_todas")


## Los cambios de la paloma de la jugadora (colores, accesorios y pintura).
func revisar_perfil() -> void:
	if not activo():
		return
	var p := PerfilPaloma.actual()
	if p.es_vacio():
		return
	desbloquear("con_estilo")
	if p.hay_pintura():
		desbloquear("artista")
	if p.hay_pintura() and not p.colores.has(PerfilPaloma.SIN_COLOR) and not p.accesorios.has(0):
		desbloquear("camaleon")


# ---------------------------------------------------------------- Guardado

func guardar() -> void:
	_sucio = false
	_t_guardado = 0.0
	var cfg := ConfigFile.new()
	for k: String in _stats:
		cfg.set_value("stats", k, _stats[k])
	for id: String in _hechos:
		cfg.set_value("hechos", id, _hechos[id])
	cfg.set_value("general", "bailes", _bailes.keys())
	cfg.set_value("general", "sombreros", _sombreros.keys())
	cfg.save(archivo)


func cargar() -> void:
	_stats.clear()
	_hechos.clear()
	_bailes.clear()
	_sombreros.clear()
	var cfg := ConfigFile.new()
	if cfg.load(archivo) != OK:
		return
	if cfg.has_section("stats"):
		for k in cfg.get_section_keys("stats"):
			_stats[k] = float(cfg.get_value("stats", k, 0.0))
	if cfg.has_section("hechos"):
		for id in cfg.get_section_keys("hechos"):
			if not CatalogoLogros.por_id(id).is_empty():   # Uno que ya no existe se descarta
				_hechos[id] = int(cfg.get_value("hechos", id, 0))
	for b in cfg.get_value("general", "bailes", []):
		_bailes[StringName(b)] = true
	for s in cfg.get_value("general", "sombreros", []):
		_sombreros[String(s)] = true


## Borra todo el progreso (para pruebas).
func borrar_todo() -> void:
	_stats.clear()
	_hechos.clear()
	_bailes.clear()
	_sombreros.clear()
	_bandada_previa = 0
	_sucio = false
	if FileAccess.file_exists(archivo):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(archivo))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _sucio:
		guardar()
