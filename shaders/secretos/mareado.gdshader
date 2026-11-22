shader_type canvas_item;
// "Despues del fernet" (Wobble): la imagen ondula, se balancea y se ve un poco doble.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float fuerza : hint_range(0.0, 0.05) = 0.012;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 9.0 + TIME * 2.1) * fuerza;
	uv.y += sin(uv.x * 7.0 + TIME * 1.7) * fuerza;
	uv = (uv - 0.5) * (1.0 - fuerza * 2.0) + 0.5;
	vec3 c = texture(pantalla, uv).rgb;
	vec3 doble = texture(pantalla, uv + vec2(sin(TIME) * fuerza, 0.0)).rgb;
	COLOR = vec4(mix(c, doble, 0.35), 1.0);
}
