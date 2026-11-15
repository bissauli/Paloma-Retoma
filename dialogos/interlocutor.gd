class_name Interlocutor
extends Node3D
## Marca a un NPC como "con él se puede hablar" (humano, gato, perro, otra paloma...). Es un nodo
## hijo del NPC: sin él, el NPC no tiene ninguna interacción. Lo único que hace es registrarse
## (grupos "hablables" y "npc_<id>", que usan Dialogos y la brújula) y mostrar encima de la cabeza
## el marcador de misiones: "!" tiene una misión para dar, "?" hay una para entregarle, "..." tiene
## una en curso. El resto (acercarse, apretar E, la conversación) lo maneja el autoload Dialogos.
## Uso: Interlocutor.marcar(npc, "dona_rosa", 2.0)

signal conversacion_iniciada(jugador: PalomaJugador)   ## Para que el NPC se quede quieto, mire a la paloma...
signal conversacion_terminada

@export var personaje := ""        ## Id en CatalogoDialogos.PERSONAJES
@export var radio := 2.4           ## Metros (en el plano) a los que se puede hablar
@export var altura_marcador := 1.9 ## Metros sobre el NPC donde va el marcador

var _marcador: Label3D


## Agrega el interlocutor a un NPC y lo deja listo.
static func marcar(npc: Node3D, id_personaje: String, altura := 1.9, radio_hablar := 2.4) -> Interlocutor:
	var i := Interlocutor.new()
	i.personaje = id_personaje
	i.altura_marcador = altura
	i.radio = radio_hablar
	npc.add_child(i)
	return i


func _ready() -> void:
	name = "Interlocutor"
	add_to_group("hablables")
	add_to_group("npc_" + personaje)
	position = Vector3.UP * altura_marcador
	_marcador = Label3D.new()
	_marcador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marcador.font_size = 96
	_marcador.pixel_size = 0.006
	_marcador.outline_size = 24
	_marcador.modulate = Color("ffd84a")
	_marcador.no_depth_test = true
	_marcador.visible = false
	add_child(_marcador)
	Misiones.mision_cambio.connect(func(_id: String, _e: String) -> void: refrescar())
	# Algunas misiones se habilitan con el avance de la partida (objetivo_cambio sale en cada avance)
	GameState.objetivo_cambio.connect(func(_t: String, _a: int, _m: int) -> void: refrescar())
	refrescar()


func nombre() -> String:
	return CatalogoDialogos.nombre(personaje)


func especie() -> String:
	return String(CatalogoDialogos.personaje(personaje).get("especie", ""))


## Vuelve a decidir qué marcador mostrar.
func refrescar() -> void:
	var m := Misiones.marcador(personaje)
	_marcador.text = m
	_marcador.visible = m != ""
	_marcador.modulate = Color("ffd84a") if m == "!" else Color("9be8ff")
