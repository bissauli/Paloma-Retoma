class_name Musico
extends Node3D
## El bandoneonista de la plaza: sentado en un banco de la Catedral, abre y cierra el fuelle.
## Es de adorno (la paloma lo choca como a cualquier persona). El aletazo no lo afecta: no es un Humano.

var modelo: ModeloHumano


func _ready() -> void:
	modelo = ModeloHumano.new()
	modelo.name = "Modelo"
	modelo.personaje = "bandoneonista"
	modelo.sentado = true
	add_child(modelo)


func _process(delta: float) -> void:
	modelo.animar(delta, 0.0)
