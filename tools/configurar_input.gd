@tool
extends RefCounted
## Aplica la configuración del proyecto (Input Map, autoloads, escena principal, etc.)
## desde DENTRO del editor, para que el editor no la pise al guardar.
## Uso: vía MCP (call_method sobre res://tools/configurar_input.gd, método aplicar)


const TECLAS := {
	"mover_adelante": [KEY_W, KEY_UP],
	"mover_atras": [KEY_S, KEY_DOWN],
	"mover_izquierda": [KEY_A, KEY_LEFT],
	"mover_derecha": [KEY_D, KEY_RIGHT],
	"volar": [KEY_SPACE],
	"picada": [KEY_SHIFT],
	"pausa": [KEY_ESCAPE],
	"interactuar": [KEY_E],
}
const BOTONES := {
	"picotear": MOUSE_BUTTON_LEFT,
	"arrullar": MOUSE_BUTTON_RIGHT,
}


static func aplicar() -> String:
	var ps := ProjectSettings
	ps.set_setting("application/config/name", "Paloma Retoma")
	ps.set_setting("application/run/main_scene", "res://main.tscn")
	ps.set_setting("autoload/GameState", "*res://autoload/game_state.gd")
	ps.set_setting("autoload/AudioManager", "*res://autoload/audio_manager.gd")
	ps.set_setting("autoload/Ajustes", "*res://autoload/ajustes.gd")
	ps.set_setting("display/window/size/viewport_width", 1280)
	ps.set_setting("display/window/size/viewport_height", 720)
	ps.set_setting("physics/common/physics_interpolation", true)
	ps.set_setting("rendering/anti_aliasing/quality/msaa_3d", 2)
	ps.set_setting("layer_names/3d_physics/layer_1", "mundo")
	ps.set_setting("layer_names/3d_physics/layer_2", "jugador")
	ps.set_setting("layer_names/3d_physics/layer_3", "npc")
	ps.set_setting("layer_names/3d_physics/layer_4", "comida")

	for accion: String in TECLAS:
		var eventos: Array = []
		for k: int in TECLAS[accion]:
			var e := InputEventKey.new()
			e.physical_keycode = k as Key
			e.device = -1  # Cualquier dispositivo
			eventos.append(e)
		ps.set_setting("input/" + accion, {"deadzone": 0.2, "events": eventos})
	for accion: String in BOTONES:
		var b := InputEventMouseButton.new()
		b.button_index = BOTONES[accion] as MouseButton
		b.device = -1
		ps.set_setting("input/" + accion, {"deadzone": 0.2, "events": [b]})

	var err := ps.save()
	return "configuración guardada" if err == OK else "error al guardar: %d" % err


## Da de alta un autoload en el editor ya abierto (sin reiniciarlo), para que los scripts
## lo reconozcan enseguida. Uso vía MCP: call_method registrar_autoload ["Ajustes", "res://autoload/ajustes.gd"]
static func registrar_autoload(nombre: String, ruta: String) -> String:
	var clave := "autoload/" + nombre
	if ProjectSettings.has_setting(clave):
		ProjectSettings.clear(clave)
	var plugin := EditorPlugin.new()
	plugin.add_autoload_singleton(nombre, ruta)
	plugin.free()
	return "autoload %s = %s" % [nombre, ProjectSettings.get_setting(clave, "(no quedó)")]


## Reimporta archivos en el editor abierto (por ejemplo después de tocar un .import a mano).
static func reimportar(rutas: PackedStringArray) -> String:
	EditorInterface.get_resource_filesystem().reimport_files(rutas)
	return "reimportados: %d" % rutas.size()
