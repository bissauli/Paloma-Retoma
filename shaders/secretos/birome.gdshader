shader_type canvas_item;
// "Birome" (Pencil): dibujo con lapicera azul sobre papel. Los bordes son trazos y las zonas oscuras
// llevan rayado (cruzado en lo mas oscuro).
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 papel : source_color = vec3(0.97, 0.95, 0.88);
uniform vec3 tinta : source_color = vec3(0.12, 0.18, 0.55);

float lum(vec2 uv) {
	return dot(texture(pantalla, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 p = SCREEN_PIXEL_SIZE * 1.5;
	float tl = lum(SCREEN_UV + vec2(-p.x, -p.y));
	float t = lum(SCREEN_UV + vec2(0.0, -p.y));
	float tr = lum(SCREEN_UV + vec2(p.x, -p.y));
	float l = lum(SCREEN_UV + vec2(-p.x, 0.0));
	float r = lum(SCREEN_UV + vec2(p.x, 0.0));
	float bl = lum(SCREEN_UV + vec2(-p.x, p.y));
	float b = lum(SCREEN_UV + vec2(0.0, p.y));
	float br = lum(SCREEN_UV + vec2(p.x, p.y));
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float borde = smoothstep(0.15, 0.5, length(vec2(gx, gy)));
	float v = lum(SCREEN_UV);
	vec2 f = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float h1 = step(0.5, fract((f.x + f.y) / 7.0)) * (1.0 - smoothstep(0.35, 0.6, v));
	float h2 = step(0.5, fract((f.x - f.y) / 7.0)) * (1.0 - smoothstep(0.15, 0.35, v));
	float trazo = clamp(borde + (h1 + h2) * 0.55, 0.0, 1.0);
	float veta = fract(sin(dot(floor(f / 2.0), vec2(12.9898, 78.233))) * 43758.5453) * 0.05;
	COLOR = vec4(mix(papel - veta, tinta, trazo), 1.0);
}
