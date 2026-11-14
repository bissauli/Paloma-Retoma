extends Node
## Prueba automática de enemigos (headless):
## godot --headless --path . res://tests/test_enemigos.tscn

var fallas := 0
var atrapada := false


func _ready() -> void:
	# Con "-- movil" corre con el perfil del teléfono (física a 30 Hz)
	if OS.get_cmdline_user_args().has("movil"):
		Ajustes.movil = true
		Ajustes.aplicar_perfil_movil()
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	var paloma := main.get_node("Paloma") as PalomaJugador
	await _frames(10)
	var gente := main.get_node("Gente")
	print("  humanos y enemigos: ", gente.get_child_count())
	_check("hay gente en la plaza", gente.get_child_count() >= 15)

	# Granadero: acercarse a la Casa Rosada sin 30 palomas -> vuelve al nido
	paloma.global_position = Vector3(40.5, 0.1, 0)
	paloma.reset_physics_interpolation()
	# Los granaderos patrullan: puede que al principio estén de espaldas
	var espera_g := 0
	while Vector2(paloma.global_position.x, paloma.global_position.z).length() > 8.0 and espera_g < 900:
		await get_tree().physics_frame
		espera_g += 1
	var d_nido := Vector2(paloma.global_position.x, paloma.global_position.z).length()
	print("  distancia al nido tras acercarse a los granaderos: ", snappedf(d_nido, 0.1))
	_check("el granadero te manda al nido", d_nido < 8.0)

	# Nene: con bandada, pararse al lado del nene dispersa palomas
	GameState.invulnerable = 0.0
	GameState.sumar_comida(12)
	paloma.global_position = Vector3(0, 0.1, -14)
	paloma.reset_physics_interpolation()
	await _frames(5)
	paloma.arrullar()
	await _frames(5)
	var antes := GameState.bandada
	var nene := gente.get_children().filter(func(n: Node) -> bool: return n is Nene)[0] as Nene
	nene.global_position = paloma.global_position + Vector3(3, 0, 0)
	var espera := 0
	while GameState.bandada == antes and espera < 300:
		await get_tree().physics_frame
		espera += 1
	print("  bandada antes/después del nene: ", antes, " -> ", GameState.bandada, " (", espera, " frames)")
	_check("el nene dispersa parte de la bandada", GameState.bandada < antes and GameState.bandada > 0)

	# Mozo: patrulla la vereda de los cafés (no el centro de la plaza) y si te alcanza te espanta
	var mozo := gente.get_children().filter(func(n: Node) -> bool: return n is Mozo)[0] as Mozo
	print("  línea de patrulla del mozo: z = ", snappedf(mozo.global_position.z, 0.1))
	_check("el mozo patrulla la vereda de los cafés", mozo.global_position.z > 30.0)
	GameState.invulnerable = 0.0
	mozo.estado = Mozo.Estado.PATRULLA
	paloma.global_position = mozo.global_position + Vector3(1.6, 0.1, -1.0)
	paloma.reset_physics_interpolation()
	var persecuciones := 0
	var previo := mozo.estado
	espera = 0
	while GameState.invulnerable <= 0.0 and espera < 300:
		await get_tree().physics_frame
		if mozo.estado == Mozo.Estado.PERSIGUE and previo != Mozo.Estado.PERSIGUE:
			persecuciones += 1
		previo = mozo.estado
		espera += 1
	print("  el mozo te espantó en ", espera, " frames (", persecuciones, " persecución/es)")
	_check("el mozo te alcanza y te espanta", GameState.invulnerable > 0.0)
	_check("el mozo no silba en bucle", persecuciones == 1)
	GameState.invulnerable = 0.0

	# Halcón: se activa con 15 palomas y ataca si volás alto al descubierto
	var halcon := gente.get_children().filter(func(n: Node) -> bool: return n is Halcon)[0] as Halcon
	_check("el halcón empieza inactivo", halcon.estado == Halcon.Estado.INACTIVO)
	GameState.halcon_activo = false
	GameState.halcon_activado.emit()
	GameState.halcon_activo = true
	await _frames(5)
	_check("el halcón se activa", halcon.estado != Halcon.Estado.INACTIVO)
	GameState.invulnerable = 0.0
	paloma.global_position = Vector3(-10, 14, 5)
	paloma.reset_physics_interpolation()
	paloma.estado = PalomaJugador.Estado.AIRE
	atrapada = false
	GameState.jugador_atrapado.connect(_al_atrapar)
	espera = 0
	while not atrapada and espera < 900:
		# Mantenerla volando alto en el lugar
		paloma.global_position = Vector3(-10, 14, 5)
		paloma.velocity = Vector3.ZERO
		await get_tree().physics_frame
		espera += 1
	print("  el halcón la atrapó en ", espera, " frames")
	_check("el halcón ataca si volás alto al descubierto", atrapada)

	print("RESULTADO: ", "OK" if fallas == 0 else "%d FALLAS" % fallas)
	get_tree().quit(fallas)


## Espera n pasos de física "de 60 Hz" (con la física a 30 Hz, la mitad: el mismo tiempo).
## Las esperas cortas (que la física vea una tecla) no se achican.
func _frames(n: int) -> void:
	for i in (n if n <= 4 else roundi(n * Engine.physics_ticks_per_second / 60.0)):
		await get_tree().physics_frame


func _check(nombre: String, ok: bool) -> void:
	print(("[OK]   " if ok else "[FALLA] ") + nombre)
	if not ok:
		fallas += 1


func _al_atrapar(motivo: String) -> void:
	atrapada = motivo == "halcon"
