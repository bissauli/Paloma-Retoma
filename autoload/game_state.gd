extends Node
## Estado global de la partida (autoload "GameState").
## Nadie guarda referencias rígidas a otros nodos: todo pasa por estas señales.

# --- Señales de estado ---
signal bandada_cambio(cantidad: int)
signal comida_cambio(cantidad: int)
signal carga_cambio(tipo: String)              ## Lo que la paloma lleva en el pico ("" = nada)
signal stamina_cambio(valor: float, maximo: float)
signal objetivo_cambio(texto: String)
signal mensaje(texto: String, duracion: float) ## Cartel temporal en el HUD
signal fase_dia_cambio(t: float)               ## 0 = mañana, 1 = atardecer
signal umbral_alcanzado(cantidad: int)

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
var tiempo_jugado := 0.0
var en_partida := false
var partida_terminada := false
var halcon_activo := false
var tutorial_hecho := false
var migas_comidas := 0
var posicion_nido := Vector3(0, 0.5, 0)
var _umbrales := {}
var invulnerable := 0.0         ## Segundos de gracia después de que te atrapan


func _process(delta: float) -> void:
	invulnerable = maxf(invulnerable - delta, 0.0)
	if not en_partida or partida_terminada or get_tree().paused:
		return
	tiempo_jugado += delta
	# El día avanza con el tiempo, pero también con el progreso de la bandada
	var por_tiempo := tiempo_jugado / Config.DURACION_PARTIDA
	var por_bandada := float(bandada) / float(Config.UMBRAL_BALCON)
	var nuevo: float = clampf(maxf(por_tiempo, por_bandada * 0.9), 0.0, 1.0)
	if nuevo > progreso_dia + 0.002:
		progreso_dia = nuevo
		fase_dia_cambio.emit(progreso_dia)


## Deja todo como al principio. Se llama al empezar cada partida.
func reiniciar() -> void:
	bandada = 0
	comida = 0
	carga = ""
	stamina = Config.STAMINA_MAX
	progreso_dia = 0.0
	tiempo_jugado = 0.0
	partida_terminada = false
	halcon_activo = false
	tutorial_hecho = false
	migas_comidas = 0
	_umbrales.clear()
	invulnerable = 0.0
	en_partida = true
	partida_iniciada.emit()
	bandada_cambio.emit(bandada)
	comida_cambio.emit(comida)
	carga_cambio.emit(carga)
	stamina_cambio.emit(stamina, Config.STAMINA_MAX)
	fase_dia_cambio.emit(0.0)
	actualizar_objetivo()


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
			mensaje.emit(textos[u], 4.5)
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
	if migas_comidas >= 3 and not tutorial_hecho:
		tutorial_hecho = true
	actualizar_objetivo()


# ---------------------------------------------------------------- Objetivos

## Arma el texto del objetivo actual según cómo viene la partida.
func actualizar_objetivo() -> void:
	var t := ""
	if partida_terminada:
		t = "¡La plaza es nuestra!"
	elif carga != "":
		t = "Llevá la %s al nido (Pirámide de Mayo)" % carga
	elif not tutorial_hecho and bandada == 0 and comida < 3:
		t = "Picoteá migas en el Cabildo (click izquierdo) — %d/3" % migas_comidas
	elif bandada < Config.UMBRAL_CHORIPAN:
		if comida < 1:
			t = "Conseguí comida: migas, medialunas de los cafés o facturas del subte"
		else:
			t = "Reclutá 5 palomas en la Catedral (click derecho) — %d/5" % bandada
	elif bandada < Config.UMBRAL_TURISTAS:
		t = "Levantá el choripán de la avenida y llegá a 15 palomas — %d/15" % bandada
	elif bandada < Config.UMBRAL_BALCON:
		t = "¡Ojo con el halcón! Juntá 30 palomas — %d/30" % bandada
	else:
		t = "¡Tomá el balcón de la Casa Rosada con tu bandada!"
	objetivo_cambio.emit(t)


# ---------------------------------------------------------------- Fin

func ganar() -> void:
	if partida_terminada:
		return
	partida_terminada = true
	en_partida = false
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
