shader_type canvas_item;
// "Family de 8 bits" (Bits): pixeles enormes y pocos colores, con tramado.
uniform sampler2D pantalla : hint_screen_texture, filter_nearest, repeat_disable;
uniform float alto : hint_range(60.0, 400.0) = 150.0;
uniform float niveles : hint_range(2.0, 8.0) = 4.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 res = vec2(alto * SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, alto);
	vec2 celda = floor(SCREEN_UV * res);
	vec3 c = texture(pantalla, (celda + 0.5) / res).rgb;
	int i = int(mod(celda.x, 4.0)) + 4 * int(mod(celda.y, 4.0));
	float b = (BAYER[i] + 0.5) / 16.0 - 0.5;
	c = floor(c * (niveles - 1.0) + 0.5 + b) / (niveles - 1.0);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
