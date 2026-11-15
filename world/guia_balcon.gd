class_name GuiaBalcon
extends FlechaObjetivo
## La flecha sobre el balcón de la Casa Rosada: aparece cuando la bandada llega a 30 palomas (cuando
## ya se puede ganar), para que cualquiera entienda adónde hay que ir, aunque no lea el idioma.
## Se esconde al estar sobre el balcón y al ganar, así no estorba en los créditos con los bailes.


func _init() -> void:
	crece_con_la_distancia = true
	altura = 2.2


func _quiere_verse() -> bool:
	if GameState.partida_terminada or GameState.menu_activo or GameState.bandada < Config.UMBRAL_BALCON:
		return false
	var j := GameState.jugador
	if j == null:
		return false
	var d := j.global_position - destino.global_position
	return Vector2(d.x, d.z).length() >= Config.RADIO_BALCON
