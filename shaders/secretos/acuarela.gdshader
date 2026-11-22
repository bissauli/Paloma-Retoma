shader_type canvas_item;
// "Acuarela" (Blobs): manchas suaves de color que se derraman, con el borde mas oscuro y papel.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE;
	vec2 f = SCREEN_UV / p;
	vec2 w = vec2(azar(floor(f / 6.0)), azar(floor(f / 6.0) + 3.1)) - 0.5;
	vec2 uv = SCREEN_UV + w * p * 6.0;
	vec3 c = vec3(0.0);
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			c += texture(pantalla, uv + vec2(float(i), float(j)) * p * 3.0).rgb;
		}
	}
	c /= 25.0;
	vec3 centro = texture(pantalla, uv).rgb;
	float borde = clamp(length(centro - c) * 4.0, 0.0, 1.0);
	c = floor(c * 6.0 + 0.5) / 6.0;
	c = mix(c, c * 0.7, borde);
	c = mix(c, vec3(1.0, 0.98, 0.93), 0.18) - azar(f) * 0.03;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
