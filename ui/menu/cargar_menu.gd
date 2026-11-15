class_name CargarMenu
extends PantallaMenu
## Pantalla de CARGAR PARTIDA: muestra la partida guardada (se guarda sola mientras se juega)
## con su bandada, comida, tiempo jugado y fecha, y deja cargarla o borrarla.

signal cargar(datos: Dictionary)

var _tarjeta: PanelContainer
var _resumen: Label
var _detalle: Label
var _boton_cargar: Button
var _boton_borrar: Button
var _vacio: Label
var _confirmar_borrado := false


func _init() -> void:
	armar("Cargar partida")
	seccion("Partida guardada")

	_tarjeta = PanelContainer.new()
	_tarjeta.theme_type_variation = &"Tarjeta"
	contenido.add_child(_tarjeta)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_tarjeta.add_child(caja)
	_resumen = Label.new()
	_resumen.theme_type_variation = &"TextoTarjeta"
	caja.add_child(_resumen)
	_detalle = Label.new()
	_detalle.theme_type_variation = &"TextoChico"
	caja.add_child(_detalle)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.alignment = BoxContainer.ALIGNMENT_END
	caja.add_child(fila)
	_boton_borrar = Button.new()
	_boton_borrar.text = "BORRAR"
	_boton_borrar.custom_minimum_size = Vector2(150, 42)
	_boton_borrar.pressed.connect(_borrar)
	_boton_borrar.focus_exited.connect(func() -> void: _reiniciar_borrado())
	fila.add_child(_boton_borrar)
	_boton_cargar = Button.new()
	_boton_cargar.text = "CARGAR"
	_boton_cargar.custom_minimum_size = Vector2(170, 42)
	_boton_cargar.pressed.connect(_cargar)
	fila.add_child(_boton_cargar)
	for b: Button in [_boton_borrar, _boton_cargar]:
		b.mouse_entered.connect(b.grab_focus)

	_vacio = Label.new()
	_vacio.theme_type_variation = &"TextoChico"
	_vacio.text = "TODAVÍA NO HAY NINGUNA PARTIDA GUARDADA.\nLA PARTIDA SE GUARDA SOLA MIENTRAS JUGÁS."
	_vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contenido.add_child(_vacio)


func abrir() -> void:
	_refrescar()
	super.abrir()


func _refrescar() -> void:
	_reiniciar_borrado()
	var d := GameState.datos_guardados()
	_tarjeta.visible = not d.is_empty()
	_vacio.visible = d.is_empty()
	if d.is_empty():
		return
	var bandada := int(d.get("bandada", 0))
	_resumen.text = tr("%d %s  ·  %d DE COMIDA") % [bandada, tr("PALOMA" if bandada == 1 else "PALOMAS"),
		int(d.get("comida", 0))]
	var t := int(d.get("tiempo_jugado", 0.0))
	var fecha := Time.get_datetime_dict_from_unix_time(int(d.get("fecha", 0)) + _huso_horario())
	_detalle.text = tr("TIEMPO JUGADO %d:%02d\nGUARDADA EL %s A LAS %s") % [
		floori(t / 60.0), t % 60, Idioma.fecha(fecha), Idioma.hora(fecha)]


func _cargar() -> void:
	var d := GameState.datos_guardados()
	if d.is_empty():
		_refrescar()
		return
	AudioManager.reproducir("arrullo", -6.0)
	visible = false   # Sin emitir "cerrada": el menú se va con la transición al juego
	cargar.emit(d)


## Borrar pide confirmación: el primer click cambia el texto y el segundo borra.
func _borrar() -> void:
	if not _confirmar_borrado:
		_confirmar_borrado = true
		_boton_borrar.text = "¿SEGURO?"
		AudioManager.reproducir("picoteo")
		return
	GameState.borrar_partida()
	AudioManager.reproducir("picoteo")
	_refrescar()
	volver.grab_focus()


func _reiniciar_borrado() -> void:
	_confirmar_borrado = false
	if _boton_borrar:
		_boton_borrar.text = "BORRAR"


static func _huso_horario() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60
