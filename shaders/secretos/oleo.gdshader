shader_type canvas_item;
// "Oleo de feria" (Art): filtro Kuwahara. De los 4 cuadrantes alrededor del pixel se queda con el
// promedio del que menos varia: pinceladas planas que respetan los bordes.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
const int RADIO = 4;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 2.5;
	float var_min = 1e9;
	vec3 o = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec2 s = vec2(k == 0 || k == 2 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0);
		vec3 m = vec3(0.0);
		vec3 m2 = vec3(0.0);
		float n = 0.0;
		for (int j = 0; j <= RADIO; j++) {
			for (int i = 0; i <= RADIO; i++) {
				vec3 c = texture(pantalla, SCREEN_UV + vec2(float(i), float(j)) * s * px).rgb;
				m += c;
				m2 += c * c;
				n += 1.0;
			}
		}
		m /= n;
		vec3 v = m2 / n - m * m;
		float vt = v.r + v.g + v.b;
		if (vt < var_min) {
			var_min = vt;
			o = m;
		}
	}
	COLOR = vec4(o, 1.0);
}
