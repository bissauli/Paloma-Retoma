shader_type canvas_item;
// "Bordes de manteca" (Antialiasing): suaviza los bordes dentados a lo largo del borde (FXAA simple).
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

float lu(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE;
	vec3 cm = texture(pantalla, SCREEN_UV).rgb;
	float n = lu(texture(pantalla, SCREEN_UV + vec2(0.0, -p.y)).rgb);
	float s = lu(texture(pantalla, SCREEN_UV + vec2(0.0, p.y)).rgb);
	float e = lu(texture(pantalla, SCREEN_UV + vec2(p.x, 0.0)).rgb);
	float o = lu(texture(pantalla, SCREEN_UV + vec2(-p.x, 0.0)).rgb);
	float lm = lu(cm);
	float rango = max(max(max(n, s), max(e, o)), lm) - min(min(min(n, s), min(e, o)), lm);
	if (rango < 0.05) {
		COLOR = vec4(cm, 1.0);
	} else {
		// Se promedia a lo largo del borde (perpendicular al gradiente).
		vec2 dir = normalize(vec2(-(n - s), e - o) + 1e-4) * p * 1.5;
		vec3 a = 0.5 * (texture(pantalla, SCREEN_UV - dir / 6.0).rgb + texture(pantalla, SCREEN_UV + dir / 6.0).rgb);
		vec3 b = a * 0.5 + 0.25 * (texture(pantalla, SCREEN_UV - dir).rgb + texture(pantalla, SCREEN_UV + dir).rgb);
		COLOR = vec4(mix(cm, b, 0.85), 1.0);
	}
}
