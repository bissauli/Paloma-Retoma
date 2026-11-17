class_name Auto
extends Node3D
## Un vehículo de la avenida: auto particular, taxi (negro y amarillo), patrullero o colectivo. Usa
## los modelos del kit de la ciudad (tools/blender/ciudad_v3.py), los mismos de los autos
## estacionados, con las ruedas aparte para que giren. Lo mueve world/transito.gd. Tiene un cuerpo cinemático (capa de la gente) para que la paloma
## de la jugadora choque contra él, y le pasa dos círculos a la bandada para que las NPC lo esquiven.

const CAPA_GENTE := 4
const MODELOS_AUTO := ["auto_hatch_celeste", "auto_hatch_naranja", "auto_hatch_amarillo", "auto_hatch_verde",
	"auto_hatch_rojo", "auto_hatch_blanco", "auto_sedan_celeste", "auto_sedan_rojo", "auto_sedan_blanco", "auto_sedan_verde"]
const MODELOS_COLECTIVO := ["colectivo_verde", "colectivo_azul"]

var tipo := "auto"
var modelo := ""               ## Pieza del kit (ver MODELOS_AUTO)
var sentido := 1.0            ## Ruta: +1 cruza la avenida hacia el este, -1 hacia el oeste
var s := 0.0                  ## Metros recorridos sobre su ruta (los maneja world/transito.gd)
var largo := 4.2
var ancho := 1.8
var alto := 1.45
var velocidad := 0.0
var velocidad_crucero := 11.0
var bocina_enfriamiento := 0.0

var _ruedas: Array[Node3D] = []
var _radio_rueda := 0.33
var _con_sombra: Array[GeometryInstance3D] = []


## Elige tipo y color al azar (llamar antes de agregarlo al árbol).
func preparar(dir: float) -> void:
	sentido = dir
	var r := randf()
	if r < 0.1:
		tipo = "colectivo"
	elif r < 0.33:
		tipo = "taxi"
	elif r < 0.36:
		tipo = "patrullero"
	else:
		tipo = "auto"
	match tipo:
		"colectivo":
			modelo = MODELOS_COLECTIVO[randi() % MODELOS_COLECTIVO.size()]
			ancho = 2.5
			alto = 3.2
			velocidad_crucero = randf_range(7.5, 9.0)
		"taxi", "patrullero":
			modelo = tipo
			velocidad_crucero = randf_range(11.0, 13.5)
		_:
			modelo = MODELOS_AUTO[randi() % MODELOS_AUTO.size()]
			velocidad_crucero = randf_range(9.5, 12.5)
	largo = float(KitDatos.PIEZAS[modelo]["largo"])
	velocidad = velocidad_crucero


func _ready() -> void:
	add_to_group("autos")
	rotation.y = 0.0 if sentido > 0.0 else PI
	_armar()
	_cuerpo_fisico()
	# La carrocería y la cabina proyectan sombra sólo en calidad Media o Alta
	Ajustes.registrar_sombra_dinamica(_con_sombra)


func _process(delta: float) -> void:
	# Las ruedas giran según la velocidad
	# El eje de las ruedas del kit es el Z local: hacia adelante (+X) giran alrededor de -Z
	var giro := velocidad * delta / _radio_rueda
	for w in _ruedas:
		w.rotate_object_local(Vector3.BACK, -giro)


## Hacia dónde apunta la trompa (el modelo mira a +X local; en las esquinas dobla).
func adelante() -> Vector3:
	return global_transform.basis.x.normalized()


## Dos círculos (adelante y atrás) que las palomas NPC no pueden pisar: [centro, radio, alto].
func circulos() -> Array:
	var a := adelante()
	var r := ancho * 0.55
	var off := largo / 2.0 - r
	return [[global_position + a * off, r, alto], [global_position - a * off, r, alto]]


# ---------------------------------------------------------------- Armado

func _cuerpo_fisico() -> void:
	var cuerpo := AnimatableBody3D.new()
	cuerpo.sync_to_physics = false
	cuerpo.collision_layer = CAPA_GENTE
	cuerpo.collision_mask = 0
	var superficies := Kit.superficies_auto(modelo)
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	if superficies.is_empty():
		forma.size = Vector3(largo, alto - 0.15, ancho)
		cs.position.y = 0.15 + (alto - 0.15) / 2.0
	else:
		# Carrocería baja (los costados) y, aparte, techo y capó donde se puede posar la paloma
		forma.size = Vector3(largo, 0.6, ancho)
		cs.position.y = 0.45
		for sup: Array in superficies:
			var cs2 := CollisionShape3D.new()
			var f2 := BoxShape3D.new()
			f2.size = sup[1]
			cs2.shape = f2
			cs2.position = sup[0]
			cuerpo.add_child(cs2)
	cs.shape = forma
	cuerpo.add_child(cs)
	add_child(cuerpo)


## Carrocería del kit (proyecta sombra según la calidad) y sus ruedas en los lugares que dice el kit.
func _armar() -> void:
	if modelo == "":
		modelo = MODELOS_AUTO[0]
		largo = float(KitDatos.PIEZAS[modelo]["largo"])
	var d: Dictionary = KitDatos.PIEZAS[modelo]
	var cuerpo := MeshInstance3D.new()
	cuerpo.mesh = Kit.malla(modelo)
	cuerpo.material_override = Kit.material()
	add_child(cuerpo)
	_con_sombra.append(cuerpo)
	_radio_rueda = float(d["radio_rueda"])
	var rueda := "rueda_colectivo" if _radio_rueda > 0.4 else "rueda_auto"
	for p: Array in d["ruedas"]:
		var pivote := Node3D.new()
		pivote.position = Vector3(p[0], p[1], p[2])
		add_child(pivote)
		var mi := MeshInstance3D.new()
		mi.mesh = Kit.malla(rueda)
		mi.material_override = Kit.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivote.add_child(mi)
		_ruedas.append(pivote)
	_luces()


## Faros delanteros y luces de freno (destellos) y el haz sobre el camino. Se prenden de noche (grupo
## "luces_noche"): son 5 nodos con materiales compartidos, y de día están ocultos.
func _luces() -> void:
	var luces := Node3D.new()
	luces.name = "Luces"
	luces.add_to_group("luces_noche")
	luces.visible = LucesNoche.encendido
	add_child(luces)
	var y := 0.9 if tipo == "colectivo" else 0.68
	var z := ancho * 0.32
	var x := largo / 2.0 - 0.08
	for lado: float in [-1.0, 1.0]:
		luces.add_child(LucesNoche.sprite(Vector3(x, y, lado * z), 0.8, Color(1.0, 0.95, 0.78)))
		luces.add_child(LucesNoche.sprite(Vector3(-x, y, lado * z), 0.34, Color(1.0, 0.18, 0.1)))
	luces.add_child(LucesNoche.charco(Vector3(x + 3.4, 0.07, 0.0), Vector2(7.5, ancho * 1.5), Color(1.0, 0.95, 0.75, 0.6)))
