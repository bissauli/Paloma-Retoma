shader_type canvas_item;
// "Cartel de neon" (Sobel): los bordes se encienden con su propio color sobre un fondo oscuro.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

vec3 m(vec2 uv) {
	return texture(pantalla, uv).rgb;
}

void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE;
	vec3 tl = m(SCREEN_UV + vec2(-p.x, -p.y));
	vec3 t = m(SCREEN_UV + vec2(0.0, -p.y));
	vec3 tr = m(SCREEN_UV + vec2(p.x, -p.y));
	vec3 l = m(SCREEN_UV + vec2(-p.x, 0.0));
	vec3 r = m(SCREEN_UV + vec2(p.x, 0.0));
	vec3 bl = m(SCREEN_UV + vec2(-p.x, p.y));
	vec3 b = m(SCREEN_UV + vec2(0.0, p.y));
	vec3 br = m(SCREEN_UV + vec2(p.x, p.y));
	vec3 gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	vec3 gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	vec3 e = sqrt(gx * gx + gy * gy);
	vec3 c = m(SCREEN_UV);
	float fuerza = clamp(length(e) * 1.5, 0.0, 1.0);
	vec3 o = c * 0.08 + normalize(c + 0.05) * fuerza * 1.4;
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
