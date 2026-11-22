shader_type canvas_item;
// "Tele de tubo" (NTSC): el color se corre y se desparrama de costado (el croma tiene menos
// resolucion que el brillo), con un fantasma corrido y lineas.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;

vec3 a_yiq(vec3 c) {
	return mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * c;
}

vec3 a_rgb(vec3 y) {
	return mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * y;
}

void fragment() {
	float px = SCREEN_PIXEL_SIZE.x;
	float y = a_yiq(texture(pantalla, SCREEN_UV).rgb).x;
	vec2 iq = vec2(0.0);
	for (int i = -6; i <= 6; i++) {
		iq += a_yiq(texture(pantalla, SCREEN_UV + vec2(float(i) * px * 2.0 + px * 4.0, 0.0)).rgb).yz;
	}
	iq /= 13.0;
	float fantasma = a_yiq(texture(pantalla, SCREEN_UV - vec2(px * 9.0, 0.0)).rgb).x;
	y = mix(y, fantasma, 0.15);
	vec3 c = a_rgb(vec3(y, iq * 1.15));
	c *= 0.9 + 0.1 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 1.5708);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
