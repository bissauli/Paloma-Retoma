shader_type canvas_item;
// "Anteojos 3D" (Deconverge): rojo, verde y azul se separan como si faltaran los anteojos, mas hacia
// los bordes, y respiran despacio.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float separacion : hint_range(0.0, 0.03) = 0.008;

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float s = separacion * (0.6 + 0.4 * sin(TIME * 1.3)) * (0.5 + length(d) * 2.0);
	float r = texture(pantalla, SCREEN_UV + vec2(s, s * 0.3)).r;
	float g = texture(pantalla, SCREEN_UV - vec2(s * 0.2, s)).g;
	float b = texture(pantalla, SCREEN_UV - vec2(s, -s * 0.3)).b;
	COLOR = vec4(r, g, b, 1.0);
}
