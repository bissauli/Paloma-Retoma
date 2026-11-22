shader_type canvas_item;
// "Casete de la abuela" (VHS). Basado en "VHS TAPE EFFECT" de blblblblb, godotshaders.com
// (https://godotshaders.com/shader/vhs-tape-effect/, licencia CC0). Cambios: lee SCREEN_UV, el ruido
// se suma en vez de multiplicar (el original multiplicaba por 5 al final), y se agregan el
// corrimiento de color, la banda de tracking que baja y la cinta que tiembla.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float scanlines_1 = 500.0;
uniform float scanlines_2 = 25.0;
uniform float scan_reduction = 0.05;
uniform float vinnette_alpla : hint_range(0.0, 1.0, 0.01) = 0.6;

float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// La cinta tiembla: cada linea se corre un poco, mas dentro de la banda de tracking que baja.
	float banda = smoothstep(0.06, 0.0, abs(fract(uv.y * 0.5 - TIME * 0.11) - 0.5));
	float linea = floor(uv.y * 240.0);
	uv.x += (random(vec2(linea, floor(TIME * 24.0))) - 0.5) * (0.0015 + banda * 0.02);
	// Color corrido (el croma de la cinta no coincide con el brillo).
	float r = texture(pantalla, uv + vec2(0.003, 0.0)).r;
	float g = texture(pantalla, uv).g;
	float b = texture(pantalla, uv - vec2(0.003, 0.0)).b;
	vec3 c = vec3(r, g, b);
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.25) * vec3(1.05, 1.0, 0.95);

	float scan1 = sin((uv.y + TIME) * scanlines_1) * scan_reduction - scan_reduction;
	float scan2 = sin((uv.y + TIME * 0.4) * scanlines_2) * scan_reduction - scan_reduction;
	float ruido = random(uv * fract(TIME) + 0.37) - 0.5;
	c += vec3(scan1 + scan2) + ruido * (0.06 + banda * 0.25);

	float vx = abs(SCREEN_UV.x - 0.5) * 2.0;
	float vy = abs(SCREEN_UV.y - 0.5) * 2.0;
	float vq = sqrt(vx * vx + vy * vy);
	c *= 1.0 - smoothstep(0.6, 1.5, vq) * vinnette_alpla;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
