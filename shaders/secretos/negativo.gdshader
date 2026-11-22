shader_type canvas_item;
// "Negativo de rollo" (Invert): colores invertidos.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	COLOR = vec4(1.0 - texture(pantalla, SCREEN_UV).rgb, 1.0);
}
