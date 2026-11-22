extends Node
## La paloma no se mete en las vidrieras de la ciudad (el interior pintado de world/vidrieras.gd): la
## esfera de choque (22 cm, como la del jugador) que avanza de frente contra cada vidriera, en 9 puntos
## del vidrio, se frena al menos a MIN m del plano (el modelo llega a 40 cm del centro de la esfera).
## Antes se frenaba a 12 cm (media paloma "adentro" del local) y en algunas se pasaba de largo.
## Y ese colchón es sólo para las palomas: la gente y la cámara no lo ven.
## godot --headless --path . res://tests/test_vidrieras_choque.tscn

const MIN := 0.35
var fallas := 0


func _ready() -> void:
	OS.set_environment("PALOMA_SEMILLA", "7")
	Ajustes.ARCHIVO = "user://test_vidrieras.cfg"
	GameState.guardado_habilitado = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for i in 30:
		await get_tree().physics_frame
	var esp := get_viewport().world_3d.direct_space_state
	var paloma := main.get_node("Paloma") as CollisionObject3D
	if paloma.collision_mask & Construir.CAPA_PALOMAS == 0:
		_falla("la paloma no choca con la capa de las palomas")
	var forma := SphereShape3D.new()
	forma.radius = 0.22
	var vidrieras := get_tree().root.find_children("Vidriera_*", "MeshInstance3D", true, false)
	for v in vidrieras:
		var mi := v as MeshInstance3D
		var cuerpo := mi.get_node_or_null("Choque") as StaticBody3D
		if cuerpo == null or cuerpo.collision_layer != Construir.CAPA_PALOMAS:
			_falla("%s sin colchón de choque sólo para palomas" % mi.name)
			continue
		var n := mi.global_basis.z.normalized()
		var u := mi.global_basis.x.normalized()
		var tam := (mi.mesh as QuadMesh).size
		var peor := -INF
		for fx: float in [-0.4, 0.0, 0.4]:
			for fy: float in [-0.35, 0.0, 0.35]:
				var c := mi.global_position + u * tam.x * fx + Vector3.UP * tam.y * fy
				var p := PhysicsShapeQueryParameters3D.new()
				p.shape = forma
				p.collision_mask = paloma.collision_mask
				p.transform = Transform3D(Basis.IDENTITY, c + n * 2.0)
				p.motion = -n * 4.0
				var res := esp.cast_motion(p)
				peor = maxf(peor, -(2.0 - 4.0 * float(res[0])))   # Distancia que se metió (negativo = afuera)
		if peor > -MIN:
			_falla("%s en %s: la paloma llega a %.2f m del vidrio" % [mi.name, mi.global_position.round(), -peor])
	print("  vidrieras revisadas: %d" % vidrieras.size())
	if vidrieras.size() < 20:
		_falla("muy pocas vidrieras (%d)" % vidrieras.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ajustes.ARCHIVO))
	print("test_vidrieras_choque: %s (%d fallas)" % ["OK" if fallas == 0 else "FALLA", fallas])
	get_tree().quit(0 if fallas == 0 else 1)


func _falla(msg: String) -> void:
	fallas += 1
	print("  FALLA ", msg)
