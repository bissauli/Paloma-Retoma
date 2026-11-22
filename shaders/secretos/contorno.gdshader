shader_type canvas_item;
// "Libro para pintar" (Outline): solo quedan los bordes en negro sobre colores lavados.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

vec3 m(vec2 uv) {
	return texture(pantalla, uv).rgb;
}

void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE * 1.5;
	vec3 c = m(SCREEN_UV);
	float e = length(m(SCREEN_UV + vec2(p.x, 0.0)) - m(SCREEN_UV - vec2(p.x, 0.0)))
		+ length(m(SCREEN_UV + vec2(0.0, p.y)) - m(SCREEN_UV - vec2(0.0, p.y)));
	float borde = smoothstep(0.12, 0.3, e);
	vec3 lavado = mix(c, vec3(1.0), 0.55);
	COLOR = vec4(mix(lavado, vec3(0.05), borde), 1.0);
}
