shader_type canvas_item;
// "Vidrio de baño" (Bumpy): la imagen se ve a traves de un vidrio con relieve de gotas.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float relieve : hint_range(0.0, 0.05) = 0.012;
uniform float escala : hint_range(4.0, 80.0) = 28.0;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void fragment() {
	vec2 asp = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 p = SCREEN_UV * asp * escala;
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Celdas de Voronoi: cada una es una gota del vidrio; la luz se dobla desde su centro.
	float dmin = 9.0;
	vec2 dir = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash2(i + o) - f;
			float d = dot(r, r);
			if (d < dmin) {
				dmin = d;
				dir = r;
			}
		}
	}
	vec2 uv = SCREEN_UV - dir * relieve / asp;
	vec3 c = texture(pantalla, uv).rgb;
	c += (0.5 - dmin) * 0.08;
	COLOR = vec4(c, 1.0);
}
