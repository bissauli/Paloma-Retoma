shader_type canvas_item;
// "Sin anteojos" (Blur): todo borroso.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float radio : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	vec3 c = vec3(0.0);
	float n = 0.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			float w = exp(-float(i * i + j * j) / 8.0);
			c += texture(pantalla, SCREEN_UV + vec2(float(i), float(j)) * SCREEN_PIXEL_SIZE * radio).rgb * w;
			n += w;
		}
	}
	COLOR = vec4(c / n, 1.0);
}
