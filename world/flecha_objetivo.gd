class_name FlechaObjetivo
extends MeshInstance3D
## Cono amarillo que flota, sube y baja y gira sobre un lugar (apuntando hacia abajo): marca adonde
## hay que ir sin necesidad de leer. Aparece y desaparece achicándose. Lo usan el tutorial (las
## migas de Doña Rosa) y GuiaBalcon (el balcón al final de la partida). Una subclase decide cuándo
## se ve sobreescribiendo _quiere_verse().

@export var altura := 1.8                 ## Metros sobre el destino
@export var crece_con_la_distancia := false   ## De lejos se agranda, para que se vea desde toda la plaza

var destino: Node3D                       ## Sobre qué nodo flota
var activa := true                        ## Para quien la maneja a mano (el tutorial)

var _t := 0.0
var _k := 0.0                             ## 0 = escondida, 1 = completa (aparece de a poco)


func _ready() -> void:
	var cono := CylinderMesh.new()
	cono.top_radius = 0.3
	cono.bottom_radius = 0.0
	cono.height = 0.55
	cono.radial_segments = 4
	cono.rings = 1
	# Transparente y sin luz: la misma variante de shader que el anillo del arrullo, que ya se
	# compiló con el menú (ver ui/menu/precalentar_shaders.gd)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.3, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh = cono
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


## ¿Debe verse ahora? Las subclases lo deciden; por defecto, lo que diga "activa".
func _quiere_verse() -> bool:
	return activa


func _process(delta: float) -> void:
	_t += delta
	var quiere := is_instance_valid(destino) and _quiere_verse()
	_k = move_toward(_k, 1.0 if quiere else 0.0, delta * 4.0)
	visible = _k > 0.01
	if not visible:
		return
	position = destino.global_position + Vector3.UP * (altura + sin(_t * 4.0) * 0.15)
	rotation.y += delta * 1.5
	var tam := _k
	if crece_con_la_distancia:
		var camara := get_viewport().get_camera_3d()
		if camara:
			tam *= clampf(camara.global_position.distance_to(position) / 10.0, 1.0, 4.0)
	scale = Vector3.ONE * tam
