shader_type canvas_item;
// "Fosforescente" (Phosphor): lo claro brilla y se derrama alrededor, como una pantalla de fosforo.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float brillo : hint_range(0.0, 3.0) = 1.3;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	vec3 halo = vec3(0.0);
	float n = 0.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			vec2 o = vec2(float(i), float(j)) * SCREEN_PIXEL_SIZE * 5.0;
			halo += max(texture(pantalla, SCREEN_UV + o).rgb - 0.55, 0.0);
			n += 1.0;
		}
	}
	halo /= n;
	c += halo * brillo * vec3(0.9, 1.2, 1.0);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
