class_name AccesoriosMenu
extends PantallaMenu
## Pantalla "Accesorios" del menú principal (TEMPORAL, para probar los accesorios rápido): a la
## izquierda la paloma de la jugadora girando en su propio SubViewport; a la derecha, por cada zona
## (cabeza, espalda, cola, pico, ojos, cuello), todas las opciones a la vista como botones. Un clic
## lo equipa al instante (y otro clic en el puesto, lo saca). Edita el PerfilPaloma en uso y lo
## guarda en cada cambio, igual que "Personalizar paloma" (que sigue teniendo lo mismo con flechas).

const VELOCIDAD_GIRO := 0.6
const DISTANCIA_CAMARA := 1.6
const CENTRO_PALOMA := 0.3

## Dónde se guarda el perfil (vacío = el archivo de siempre; las pruebas usan otro).
var ruta_guardado := ""

var _perfil: PerfilPaloma
var _botones: Array = []          ## Por slot: Array[Button] (el 0 es "Ninguno")
var _pivote: Node3D
var _camara: Camera3D


func _init() -> void:
	armar("Accesorios")
	_perfil = PerfilPaloma.actual()
	_armar_vista()
	var aviso := Label.new()
	aviso.text = tr("Temporal: para probar los accesorios. Un clic lo pone, otro clic lo saca.")
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD
	aviso.add_theme_font_size_override("font_size", 15)
	aviso.modulate = Color(1, 1, 1, 0.75)
	contenido.add_child(aviso)
	for slot in CatalogoPaloma.SLOTS.size():
		seccion(CatalogoPaloma.SLOTS[slot]["nombre"])
		var grilla := GridContainer.new()
		grilla.columns = 2
		grilla.add_theme_constant_override("h_separation", 6)
		grilla.add_theme_constant_override("v_separation", 6)
		contenido.add_child(grilla)
		var lista: Array[Button] = []
		for i in CatalogoPaloma.cantidad_opciones(slot):
			var b := Button.new()
			b.text = tr(CatalogoPaloma.nombre_opcion(slot, i))
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(300, 38)
			b.set_meta(&"nombre", tr(CatalogoPaloma.nombre_opcion(slot, i)))
			b.add_theme_font_size_override("font_size", 14)
			EstiloUI.estilizar_boton(b)
			b.pressed.connect(_elegir.bind(slot, i))
			grilla.add_child(b)
			lista.append(b)
		_botones.append(lista)
	var fila_b := HBoxContainer.new()
	fila_b.add_theme_constant_override("separation", 8)
	contenido.add_child(fila_b)
	var quitar := Button.new()
	quitar.text = tr("QUITAR TODO")
	quitar.custom_minimum_size = Vector2(200, 44)
	EstiloUI.estilizar_boton(quitar)
	quitar.pressed.connect(_quitar_todo)
	fila_b.add_child(quitar)
	var azar := Button.new()
	azar.text = tr("AL AZAR")
	azar.custom_minimum_size = Vector2(200, 44)
	EstiloUI.estilizar_boton(azar)
	azar.pressed.connect(_al_azar)
	fila_b.add_child(azar)
	_perfil.cambiado.connect(_refrescar)
	_refrescar()
	set_process(false)


func abrir() -> void:
	var actual := PerfilPaloma.actual()
	if actual != _perfil:
		_perfil.cambiado.disconnect(_refrescar)
		_perfil = actual
		_perfil.cambiado.connect(_refrescar)
	_refrescar()
	set_process(true)
	super.abrir()


func cerrar() -> void:
	set_process(false)
	super.cerrar()


func _process(delta: float) -> void:
	_pivote.rotation.y += VELOCIDAD_GIRO * delta


## Equipa la opción "i" del slot (si ya estaba puesta, la saca) y guarda el perfil.
func _elegir(slot: int, i: int) -> void:
	var nueva := 0 if _perfil.accesorios[slot] == i else i
	_perfil.set_accesorio(slot, nueva)
	_guardar()
	AudioManager.ui("button", -10.0)


func _quitar_todo() -> void:
	for slot in CatalogoPaloma.SLOTS.size():
		_perfil.set_accesorio(slot, 0)
	_guardar()
	AudioManager.ui("button", -10.0)


func _al_azar() -> void:
	for slot in CatalogoPaloma.SLOTS.size():
		_perfil.set_accesorio(slot, randi_range(0, CatalogoPaloma.cantidad_opciones(slot) - 1))
	_guardar()
	AudioManager.ui("button", -10.0)


func _guardar() -> void:
	_perfil.guardar(ruta_guardado)


## Marca el botón de lo que tiene puesto en cada slot.
func _refrescar() -> void:
	for slot in _botones.size():
		var lista: Array = _botones[slot]
		for i in lista.size():
			var b := lista[i] as Button
			var puesto: bool = _perfil.accesorios[slot] == i
			b.set_pressed_no_signal(puesto)
			b.text = ("✓ " if puesto else "") + String(b.get_meta(&"nombre"))
			b.modulate = Color(1.0, 0.95, 0.7) if puesto else Color.WHITE


## La paloma de la jugadora en su propio mundo (con su luz y su cámara), girando despacio.
func _armar_vista() -> void:
	var tarjeta := PanelContainer.new()
	tarjeta.name = "Vista"
	tarjeta.theme_type_variation = &"Tarjeta"
	tarjeta.anchor_left = 0.05
	tarjeta.anchor_right = 0.41
	tarjeta.anchor_top = 0.07
	tarjeta.anchor_bottom = 0.6
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tarjeta)
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.stretch_shrink = 2 if Ajustes.movil else 1
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(contenedor)
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vista.msaa_3d = Viewport.MSAA_DISABLED if Ajustes.movil else Viewport.MSAA_2X
	contenedor.add_child(vista)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.72, 0.76, 0.84)
	env.environment.ambient_light_energy = 0.8
	vista.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38.0, 160.0, 0.0)
	sol.light_energy = 1.1
	vista.add_child(sol)
	_camara = Camera3D.new()
	_camara.fov = 30.0
	_camara.current = true
	vista.add_child(_camara)
	_camara.transform = Transform3D(Basis(), Vector3(0.0, 0.5, -DISTANCIA_CAMARA)).looking_at(Vector3(0.0, CENTRO_PALOMA, 0.0))
	_pivote = Node3D.new()
	vista.add_child(_pivote)
	var modelo := ModeloPaloma.new()
	modelo.es_jugador = true      # Toma el perfil en uso y lo sigue
	_pivote.add_child(modelo)
