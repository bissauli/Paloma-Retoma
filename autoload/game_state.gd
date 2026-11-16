extends Node
## Estado global de la partida (autoload "GameState").
## Nadie guarda referencias rígidas a otros nodos: todo pasa por estas señales.
## También guarda la partida (un solo lugar, archivo_partida) cada AUTOGUARDADO segundos,
## al salir al menú y al cerrar el juego. El menú principal la usa para CONTINUAR y CARGAR.

const VERSION_PARTIDA := 1
const AUTOGUARDADO := 20.0

# --- Señales de estado ---
signal bandada_cambio(cantidad: int)
signal comida_cambio(cantidad: int)
signal carga_cambio(tipo: String)              ## Lo que la paloma lleva en el pico ("" = nada)
signal stamina_cambio(valor: float, maximo: float)
signal objetivo_cambio(texto: String, actual: int, meta: int) ## meta 0: sin contador
signal fase_dia_cambio(t: float)               ## 0 = mañana, 1 = atardecer
signal umbral_alcanzado(cantidad: int)
signal destinos_cambio(destinos: Array)       ## A dónde apunta la brújula (ver ui/brujula.gd)

# --- Señales de eventos del mundo ---
signal arrullo(posicion: Vector3, radio: float)        ## El jugador arrulló
signal perder_palomas(cantidad: int, desde: Vector3)   ## Pedido a la bandada de soltar palomas
signal jugador_atrapado(motivo: String)                ## Hay que volver al nido
signal jugador_volvio_al_nido
signal halcon_activado
signal victoria
signal partida_iniciada

# --- Estado ---
var bandada := 0
var comida := 0
var carga := ""                 ## Comida pesada que lleva la paloma
var stamina := Config.STAMINA_MAX
var progreso_dia := 0.0
var hora_dia := Config.HORA_INICIO   ## Hora del reloj del cielo (0-24), ver world/cielo.gd
var clima := 0                        ## Clima actual (Cielo.Clima)
var tiempo_jugado := 0.0
var en_partida := false
var partida_terminada := false
var halcon_activo := false
var tutorial_hecho := false
var migas_comidas := 0
var posicion_nido := Vector3(0, 0.5, 0)
## La paloma de la jugadora (la registra ella misma al entrar al árbol). Evita buscarla por
## grupo en cada cuadro desde enemigos, comida, tránsito, etc.
var jugador: PalomaJugador
## Lugares que marca la brújula: [{grupo, nombre, principal}]. "grupo" es el grupo del nodo del
## mundo al que apunta (la brújula lo busca ahí), "nombre" lo que se lee debajo del rombo.
var destinos: Array = []
var _umbrales := {}
var invulnerable := 0.0         ## Segundos de gracia después de que te atrapan
var menu_activo := false        ## El menú principal (o su transición a la partida) está en pantalla
var saltar_menu := false        ## Al recargar la escena (Reiniciar) se arranca directo a jugar
var guardado_habilitado := false ## Sólo la partida "de verdad" guarda (las pruebas automáticas no)
var archivo_partida := "user://partida.cfg"   ## Las pruebas usan otro archivo
var _t_guardado := 0.0


func _ready() -> void:
	# Ajustes es otro autoload: se conecta cuando ya existen todos
	(func() -> void: Ajustes.idioma_cambiado.connect(actualizar_objetivo)).call_deferred()


func _process(delta: float) -> void:
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not en_partida or partida_terminada or get_tree().paused:
		return
	tiempo_jugado += delta
	_t_guardado += delta
	if _t_guardado >= AUTOGUARDADO:
		guardar_partida()
	# El día avanza con el tiempo, pero también con el progreso de la bandada
	var por_tiempo := tiempo_jugado / Config.DURACION_PARTIDA
	var por_bandada := float(bandada) / float(Config.UMBRAL_BALCON)
	var nuevo: float = clampf(maxf(por_tiempo, por_bandada * 0.9), 0.0, 1.0)
	if nuevo > progreso_dia + 0.002:
		progreso_dia = nuevo
		fase_dia_cambio.emit(progreso_dia)


## Deja todo como al principio. Se llama al empezar cada partida.
## "datos" (de datos_guardados()) continúa una partida guardada: la bandada no se cuenta acá,
## la vuelve a armar la escena con Bandada.restaurar().
func reiniciar(datos: Dictionary = {}) -> void:
	bandada = 0
	comida = int(datos.get("comida", 0))
	carga = ""
	stamina = Config.STAMINA_MAX
	progreso_dia = float(datos.get("progreso_dia", 0.0))
	hora_dia = float(datos.get("hora_dia", Config.HORA_INICIO))
	clima = int(datos.get("clima", 0))
	tiempo_jugado = float(datos.get("tiempo_jugado", 0.0))
	partida_terminada = false
	halcon_activo = false
	tutorial_hecho = bool(datos.get("tutorial_hecho", false))
	migas_comidas = int(datos.get("migas_comidas", 0))
	Misiones.desde_dict(datos.get("misiones", {}))   # {} = partida nueva: sin misiones
	_umbrales.clear()
	for u in datos.get("umbrales", []):
		_umbrales[int(u)] = true   # Los avisos de 5, 15 y 30 palomas no se repiten
	invulnerable = 0.0
	_t_guardado = 0.0
	en_partida = true
	partida_iniciada.emit()
	bandada_cambio.emit(bandada)
	comida_cambio.emit(comida)
	carga_cambio.emit(carga)
	stamina_cambio.emit(stamina, Config.STAMINA_MAX)
	if datos.is_empty():
		fase_dia_cambio.emit(0.0)
	actualizar_objetivo()


# ---------------------------------------------------------------- Guardar y cargar

func hay_partida_guardada() -> bool:
	return not datos_guardados().is_empty()


## Lo guardado, o {} si no hay partida (o el archivo no sirve).
func datos_guardados() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(archivo_partida) != OK:
		return {}
	if int(cfg.get_value("partida", "version", 0)) != VERSION_PARTIDA:
		return {}
	var d := {}
	for k in cfg.get_section_keys("partida"):
		d[k] = cfg.get_value("partida", k)
	return d


func guardar_partida() -> void:
	_t_guardado = 0.0
	if not en_partida or partida_terminada or not guardado_habilitado:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("partida", "version", VERSION_PARTIDA)
	cfg.set_value("partida", "fecha", int(Time.get_unix_time_from_system()))
	cfg.set_value("partida", "bandada", bandada)
	cfg.set_value("partida", "comida", comida)
	cfg.set_value("partida", "tiempo_jugado", tiempo_jugado)
	cfg.set_value("partida", "progreso_dia", progreso_dia)
	cfg.set_value("partida", "hora_dia", hora_dia)
	cfg.set_value("partida", "clima", clima)
	cfg.set_value("partida", "tutorial_hecho", tutorial_hecho)
	cfg.set_value("partida", "migas_comidas", migas_comidas)
	cfg.set_value("partida", "umbrales", _umbrales.keys())
	cfg.set_value("partida", "misiones", Misiones.a_dict())
	cfg.save(archivo_partida)


func borrar_partida() -> void:
	if FileAccess.file_exists(archivo_partida):
		DirAccess.remove_absolute(archivo_partida)


func _notification(what: int) -> void:
	# Al cerrar la ventana se guarda lo que haya
	if what == NOTIFICATION_WM_CLOSE_REQUEST and en_partida and not partida_terminada:
		guardar_partida()


# ---------------------------------------------------------------- Bandada

## Las palomas NPC llaman a esto al sumarse (+1) o separarse (-1) de la bandada.
func registrar_seguidora(delta_cantidad: int) -> void:
	bandada = clampi(bandada + delta_cantidad, 0, Config.BANDADA_MAX)
	bandada_cambio.emit(bandada)
	_revisar_umbrales()
	actualizar_objetivo()


func hay_lugar_en_bandada() -> bool:
	return bandada < Config.BANDADA_MAX


func _revisar_umbrales() -> void:
	var textos := {
		Config.UMBRAL_CHORIPAN: "¡5 palomas! Ya pueden levantar el choripán de la avenida",
		Config.UMBRAL_TURISTAS: "¡15 palomas! Los turistas les tienen miedo... y apareció un halcón",
		Config.UMBRAL_BALCON: "¡30 palomas! Los granaderos están distraídos. ¡Al balcón!",
	}
	for u: int in textos.keys():
		if bandada >= u and not _umbrales.has(u):
			_umbrales[u] = true
			umbral_alcanzado.emit(u)
	if bandada >= Config.UMBRAL_HALCON and not halcon_activo:
		halcon_activo = true
		halcon_activado.emit()


## Pide a la bandada que suelte palomas (nene, halcón, granadero).
func pedir_perdida(cantidad: int, desde: Vector3) -> void:
	if cantidad > 0 and bandada > 0:
		perder_palomas.emit(mini(cantidad, bandada), desde)


# ---------------------------------------------------------------- Comida y stamina

func sumar_comida(n: int) -> void:
	comida = maxi(comida + n, 0)
	comida_cambio.emit(comida)
	actualizar_objetivo()


func gastar_comida(n: int) -> bool:
	if comida < n:
		return false
	comida -= n
	comida_cambio.emit(comida)
	return true


func set_carga(tipo: String) -> void:
	carga = tipo
	carga_cambio.emit(carga)
	actualizar_objetivo()


func set_stamina(v: float) -> void:
	var nuevo: float = clampf(v, 0.0, Config.STAMINA_MAX)
	if absf(nuevo - stamina) > 0.01:
		stamina = nuevo
		stamina_cambio.emit(stamina, Config.STAMINA_MAX)


func comio_miga() -> void:
	migas_comidas += 1
	Misiones.notificar("miga")
	if migas_comidas >= 3 and not tutorial_hecho:
		tutorial_hecho = true
	actualizar_objetivo()


# ---------------------------------------------------------------- Objetivos

## Arma el objetivo actual según cómo viene la partida: el texto y, si tiene, el avance (actual/meta).
func actualizar_objetivo() -> void:
	var t := ""
	var actual := 0
	var meta := 0
	var nuevos: Array = []
	if partida_terminada:
		t = "¡La plaza es nuestra!"
	elif carga != "":
		t = tr("Llevá la %s al nido, en la Pirámide de Mayo") % tr(carga)
		nuevos = [_destino(&"nido", "Nido")]
	elif not tutorial_hecho and bandada == 0 and comida < 3:
		t = "Comé las migas de Doña Rosa, en el Cabildo"
		actual = migas_comidas
		meta = 3
		nuevos = [_destino(&"dona_rosa", "Doña Rosa")]
	elif bandada < Config.UMBRAL_CHORIPAN:
		if comida < 1:
			t = "Conseguí comida: migas, medialunas de los cafés o facturas del subte"
			nuevos = [_destino(&"punto_cafes", "Cafés"), _destino(&"punto_subte", "Subte")]
		else:
			t = "Reclutá palomas en la Catedral"
			actual = bandada
			meta = Config.UMBRAL_CHORIPAN
			nuevos = [_destino(&"punto_catedral", "Catedral")]
	elif bandada < Config.UMBRAL_TURISTAS:
		t = "Levantá el choripán de la avenida y juntá más palomas"
		actual = bandada
		meta = Config.UMBRAL_TURISTAS
		nuevos = [_destino(&"punto_choripan", "Choripán"), _destino(&"punto_catedral", "Catedral", false)]
	elif bandada < Config.UMBRAL_BALCON:
		t = "Cuidado con el halcón y seguí juntando palomas"
		actual = bandada
		meta = Config.UMBRAL_BALCON
		nuevos = [_destino(&"punto_catedral", "Catedral")]
	else:
		t = "Tomá el balcón de la Casa Rosada con tu bandada"
		nuevos = [_destino(&"balcon", "Balcón")]
	# El nido siempre queda marcado (más chico) salvo que sea el destino
	if not partida_terminada and carga == "":
		nuevos.append(_destino(&"nido", "Nido", false))
	nuevos.append_array(Misiones.destinos())   # Las misiones secundarias en curso
	if nuevos != destinos:
		destinos = nuevos
		destinos_cambio.emit(destinos)
	objetivo_cambio.emit(t, actual, meta)


func _destino(grupo: StringName, nombre: String, principal := true) -> Dictionary:
	return {"grupo": grupo, "nombre": nombre, "principal": principal}


# ---------------------------------------------------------------- Fin

func ganar() -> void:
	if partida_terminada:
		return
	partida_terminada = true
	en_partida = false
	if guardado_habilitado:
		borrar_partida()   # Ganada: ya no hay nada que continuar
	victoria.emit()
	actualizar_objetivo()


# ---------------------------------------------------------------- Penalizaciones

## Un enemigo atrapó a la paloma: pierde algunas palomas y (si volver_al_nido) vuelve al nido.
## Devuelve false si estaba en su período de gracia.
func atrapar(motivo: String, perdidas: int, desde: Vector3, volver := true) -> bool:
	if invulnerable > 0.0 or partida_terminada:
		return false
	invulnerable = 3.0
	pedir_perdida(perdidas, desde)
	if volver:
		jugador_atrapado.emit(motivo)
	return true
