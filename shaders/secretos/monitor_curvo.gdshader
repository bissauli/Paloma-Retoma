shader_type canvas_item;
// "Monitor de ciber" (Scan pincushion): pantalla curva con lineas de barrido y esquinas negras.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float curva : hint_range(0.0, 0.5) = 0.18;

void fragment() {
	vec2 d = SCREEN_UV * 2.0 - 1.0;
	d *= 1.0 + curva * dot(d, d) * 0.5;
	vec2 uv = d * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec3 c = texture(pantalla, uv).rgb;
		c *= 0.8 + 0.2 * sin(uv.y / SCREEN_PIXEL_SIZE.y * 1.885);
		c *= 1.0 - smoothstep(0.85, 1.0, max(abs(d.x), abs(d.y))) * 0.6;
		COLOR = vec4(clamp(c * 1.1, 0.0, 1.0), 1.0);
	}
}
