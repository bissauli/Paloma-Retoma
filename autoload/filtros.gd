extends CanvasLayer
## Filtros de pantalla (autoload "Filtros"), encima del 3D y debajo del HUD y los menús (capa -1).
## - El estilo pixel cozy (shaders/pixel_cozy.gdshader) si Ajustes.estilo_pixel.
## - Uno de los "ajustes súper secretos" (shaders/secretos/), como el botón de Minecraft: Ajustes.filtro.
## Si están los dos, el filtro se aplica sobre la imagen ya pixelada (BackBufferCopy en el medio).

## [nombre, shader]. El nombre es el que se ve en Opciones (traducido en textos_en.gd).
const LISTA := [
	["Óleo de feria", "res://shaders/secretos/oleo.gdshader"],
	["Vidrio de baño", "res://shaders/secretos/vidrio.gdshader"],
	["Témpera", "res://shaders/secretos/tempera.gdshader"],
	["Birome", "res://shaders/secretos/birome.gdshader"],
	["Colores de cancha", "res://shaders/secretos/saturado.gdshader"],
	["Anteojos 3D", "res://shaders/secretos/anteojos_3d.gdshader"],
	["Patas para arriba", "res://shaders/secretos/patas_arriba.gdshader"],
	["Negativo de rollo", "res://shaders/secretos/negativo.gdshader"],
	["Tele de tubo", "res://shaders/secretos/tele_tubo.gdshader"],
	["Libro para pintar", "res://shaders/secretos/contorno.gdshader"],
	["Fosforescente", "res://shaders/secretos/fosforo.gdshader"],
	["Monitor de ciber", "res://shaders/secretos/monitor_curvo.gdshader"],
	["Cartel de neón", "res://shaders/secretos/neon.gdshader"],
	["Family de 8 bits", "res://shaders/secretos/ocho_bits.gdshader"],
	["Domingo nublado", "res://shaders/secretos/nublado.gdshader"],
	["Visión nocturna", "res://shaders/secretos/vision_nocturna.gdshader"],
	["Sin anteojos", "res://shaders/secretos/sin_anteojos.gdshader"],
	["Después del fernet", "res://shaders/secretos/mareado.gdshader"],
	["Acuarela", "res://shaders/secretos/acuarela.gdshader"],
	["Bordes de manteca", "res://shaders/secretos/suavizado.gdshader"],
	["Casete de la abuela", "res://shaders/secretos/vhs.gdshader"],
	["Policial negro", "res://shaders/secretos/noir.gdshader"],
	["Tele del living", "res://shaders/secretos/crt.gdshader"],
]

## Sonidos al azar del botón súper secreto (como Minecraft, que suena un bicho cualquiera).
const SONIDOS := ["arrullo", "aleteo", "picoteo", "grito_nene", "silbato", "chillido_halcon", "bocina",
	"salpicadura", "aletazo", "tintineo", "ladrido"]

var _pixel: ColorRect
var _copia: BackBufferCopy
var _filtro: ColorRect
var _filtro_actual := -2


func _ready() -> void:
	layer = -1
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pixel = _rect(load("res://shaders/pixel_cozy.gdshader"))
	_copia = BackBufferCopy.new()
	_copia.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copia)
	_filtro = _rect(null)
	Ajustes.cambio.connect(aplicar)
	aplicar()


func aplicar() -> void:
	_pixel.visible = Ajustes.estilo_pixel
	var f: int = Ajustes.filtro if Ajustes.filtro >= 0 and Ajustes.filtro < LISTA.size() else -1
	if f != _filtro_actual:
		_filtro_actual = f
		(_filtro.material as ShaderMaterial).shader = load(LISTA[f][1]) if f >= 0 else null
	_filtro.visible = f >= 0
	_copia.visible = _pixel.visible and _filtro.visible


## Elige un filtro al azar distinto del actual y hace un ruido cualquiera. Devuelve el índice.
func super_secreto() -> int:
	var f := randi() % LISTA.size()
	if f == Ajustes.filtro:
		f = (f + 1 + randi() % (LISTA.size() - 1)) % LISTA.size()
	AudioManager.reproducir(SONIDOS.pick_random())
	Ajustes.set_filtro(f)
	return f


func _rect(shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	r.visible = false
	add_child(r)
	return r
