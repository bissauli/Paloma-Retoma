shader_type canvas_item;
// "Domingo nublado" (Desaturate): casi sin color, un poco frio.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float color_que_queda : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, color_que_queda) * vec3(0.96, 0.99, 1.04);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
