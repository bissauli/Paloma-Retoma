extends Node
## Lista cada cartel con vidriera y el rubro que le tocó (headless):
## godot --headless --path . res://tests/lista_vidrieras.tscn


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	for k in 5:
		await get_tree().process_frame
	for par: Array in Vidrieras.registro:
		print("VIDRIERA | %s | %s" % [par[0], par[1] if par[1] != "" else "(NINGUNO)"])
	get_tree().quit()
