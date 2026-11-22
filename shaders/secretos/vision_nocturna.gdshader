shader_type canvas_item;
// "Vision nocturna" (Green): todo en verde, con el brillo levantado, ruido y un circulo de mira.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = pow(l, 0.7) * 1.2;
	vec2 f = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float ruido = fract(sin(dot(f + fract(TIME) * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
	l += (ruido - 0.5) * 0.12;
	l *= 0.92 + 0.08 * sin(f.y * 1.5);
	// Circulo de la mira (redondo en cualquier proporcion de pantalla).
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	l *= 1.0 - smoothstep(0.42, 0.5, length(d));
	COLOR = vec4(vec3(0.15, 1.0, 0.25) * l, 1.0);
}
