shader_type canvas_item;
// "Patas para arriba" (Flip): el mundo dado vuelta.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	COLOR = vec4(texture(pantalla, vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y)).rgb, 1.0);
}
