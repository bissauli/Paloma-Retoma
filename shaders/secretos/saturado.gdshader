shader_type canvas_item;
// "Colores de cancha" (Color convolve): una matriz de color que satura y separa los tonos, como una
// tele con el color al maximo.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float saturacion : hint_range(0.0, 4.0) = 2.2;
uniform float contraste : hint_range(0.5, 2.0) = 1.25;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	mat3 m = mat3(vec3(1.1, -0.05, -0.05), vec3(-0.1, 1.15, -0.05), vec3(-0.05, -0.1, 1.2));
	c = m * c;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturacion);
	c = (c - 0.5) * contraste + 0.5;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
