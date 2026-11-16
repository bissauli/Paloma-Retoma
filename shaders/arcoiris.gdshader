shader_type spatial;
// Arcoíris: arco armado en world/cielo.gd. UV.y va de adentro (0) a afuera (1) de la banda y
// UV.x de una punta a la otra. Colores del violeta al rojo, bordes suaves y puntas que se pierden.

render_mode unshaded, fog_disabled, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float opacidad : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float t = UV.y;
	// Del violeta (adentro) al rojo (afuera)
	vec3 c = clamp(abs(fract(vec3(0.78 - t * 0.78) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	c = mix(c, vec3(1.0), 0.25);
	float banda = sin(t * PI);
	float puntas = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	ALBEDO = c;
	ALPHA = banda * banda * puntas * opacidad;
}
