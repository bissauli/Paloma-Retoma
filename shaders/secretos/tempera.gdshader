shader_type canvas_item;
// "Tempera" (Blobs2): manchones grandes de color deformados por ruido, con pocos tonos.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float tamano : hint_range(0.002, 0.05) = 0.012;
uniform float niveles : hint_range(2.0, 12.0) = 5.0;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(azar(i), azar(i + vec2(1.0, 0.0)), f.x), mix(azar(i + vec2(0.0, 1.0)), azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 w = vec2(ruido(SCREEN_UV * 18.0), ruido(SCREEN_UV * 18.0 + 7.3)) - 0.5;
	vec2 uv = SCREEN_UV + w * tamano * 2.0;
	vec3 c = vec3(0.0);
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			c += texture(pantalla, uv + vec2(float(i), float(j)) * tamano * 0.35).rgb;
		}
	}
	c /= 25.0;
	c = floor(c * niveles + 0.5) / niveles;
	COLOR = vec4(c, 1.0);
}
