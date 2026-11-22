shader_type canvas_item;
// "Policial negro" (black noir). El grano es de "Film Grain Shader" de mujtaba-io, godotshaders.com
// (https://godotshaders.com/shader/film-grain-shader/, licencia CC0). Agregado aca: blanco y negro con
// mucho contraste, el rojo que sobrevive (como en las peliculas noir con un solo color), grano que se
// mueve y viñeta fuerte.
uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.07;
uniform float grain_size : hint_range(0.1, 10.0) = 1.0;
uniform float contraste : hint_range(0.5, 3.0) = 1.6;
uniform bool rojo_vivo = true;

void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Medios tonos hacia abajo (de noche, con sombras duras) y despues el contraste.
	l = pow(l, 1.8);
	l = clamp((l - 0.4) * contraste + 0.4, 0.0, 1.0);
	l = l * l * (3.0 - 2.0 * l);
	vec3 o = vec3(l);
	if (rojo_vivo) {
		float rojo = smoothstep(0.25, 0.45, c.r - max(c.g, c.b));
		o = mix(o, vec3(min(1.0, l * 1.6 + 0.2), l * 0.15, l * 0.15), rojo);
	}
	float noise = (fract(sin(dot(SCREEN_UV + fract(TIME * 0.37), vec2(12.9898, 78.233))) * 43758.5453) - 0.5) * 2.0;
	o += noise * grain_amount * grain_size;
	float d = length((SCREEN_UV - 0.5) * vec2(1.0, 0.75));
	o *= 1.0 - smoothstep(0.3, 0.75, d) * 0.85;
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
