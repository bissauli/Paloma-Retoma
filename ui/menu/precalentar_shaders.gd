class_name PrecalentarShaders
extends SubViewport
## Compila los shaders del mundo mientras está el menú, para que la transición al juego no se trabe.
## Con el renderer Compatibility (OpenGL / WebGL) cada material se compila la primera vez que se
## dibuja: el primer plano del menú sólo ve a la paloma, y al alejarse la cámara aparecía toda la
## plaza de golpe (cuadros de 100-250 ms en PC sin caché, varios segundos en el teléfono).
## Este viewport no se muestra en pantalla: comparte el mundo 3D con la escena y lo dibuja desde
## varios puntos de vista (detrás de la paloma, alrededor a la altura del suelo y desde arriba),
## más algunas mallas sueltas con los materiales que se crean recién durante la partida.
## Los programas compilados quedan para toda la ventana. Al terminar se borra solo.

signal terminado

const ALTURA_VISTA := 1.6


## "jugador": la paloma (los puntos de vista salen de ahí). "camara_juego": la cámara orbital.
func precalentar(jugador: Node3D, camara_juego: Camera3D) -> void:
	world_3d = jugador.get_viewport().world_3d
	size = Vector2i(320, 180)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = jugador.get_viewport().msaa_3d
	positional_shadow_atlas_size = jugador.get_viewport().positional_shadow_atlas_size
	var cam := Camera3D.new()
	cam.far = 600.0
	cam.fov = 75.0
	add_child(cam)
	cam.current = true
	var muestras := _agregar_muestras(cam)

	var centro := jugador.global_position
	var vistas: Array[Transform3D] = []
	if camara_juego:
		vistas.append(camara_juego.global_transform)
	for i in 6:
		var a := TAU * i / 6.0
		var desde := centro + Vector3.UP * ALTURA_VISTA
		var hacia := desde + Vector3(sin(a), -0.08, cos(a))
		vistas.append(Transform3D.IDENTITY.translated(desde).looking_at(hacia, Vector3.UP))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var desde := centro + Vector3(sin(a) * 60.0, 45.0, cos(a) * 60.0)
		vistas.append(Transform3D.IDENTITY.translated(desde).looking_at(centro, Vector3.UP))
	var arriba := centro + Vector3.UP * 140.0
	vistas.append(Transform3D.IDENTITY.translated(arriba).looking_at(centro, Vector3.FORWARD))

	for i in vistas.size():
		cam.global_transform = vistas[i]
		# Las muestras sólo en la última vista (a 140 m de altura): ahí no las ve ninguna otra cámara
		muestras.visible = i == vistas.size() - 1
		# Un cuadro por vista (process_frame también llega sin renderer, en las pruebas headless)
		await get_tree().process_frame
	terminado.emit()
	queue_free()


## Materiales que no existen hasta que pasa algo en la partida (el anillo del arrullo, las rayas
## de viento al volar, y la lluvia, el rayo y el arcoíris del cielo): una copia de cada uno delante
## de la cámara de precalentado.
func _agregar_muestras(cam: Camera3D) -> Node3D:
	var grupo := Node3D.new()
	grupo.visible = false
	cam.add_child(grupo)
	var anillo := StandardMaterial3D.new()
	anillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	anillo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var viento := anillo.duplicate() as StandardMaterial3D
	viento.vertex_color_use_as_albedo = true
	viento.disable_receive_shadows = true
	var materiales: Array[Material] = [anillo, viento]
	var sol := get_tree().get_first_node_in_group("sol")
	if sol and sol.get_parent() is Cielo:
		materiales.append_array((sol.get_parent() as Cielo).materiales_ocultos())
	var x := -0.3 * (materiales.size() - 1)
	for m: Material in materiales:
		var mi := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3.ONE * 0.2
		mi.mesh = caja
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(x, 0.0, -2.0)
		grupo.add_child(mi)
		x += 0.6
	return grupo
