shader_type spatial;
// Nubes low-poly (mallas del pack Low Poly Skies Free, ver modelos/cielo/). Sombreado plano por
// facetas: la cara al sol y la de arriba se ven claras, la de abajo toma el color de sombra. Sin
// luces ni niebla (están lejos, en el cielo). Van en un MultiMesh: el dato propio de cada instancia
// trae el brillo (rgb) y cuánto se ve (a), que aparece y desaparece con un tramado.

render_mode unshaded, fog_disabled, cull_back, shadows_disabled;

uniform vec4 nube_luz : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 nube_sombra : source_color = vec4(0.72, 0.78, 0.88, 1.0);
uniform vec3 sol_dir = vec3(0.0, 0.7, -0.7);   // hacia el sol (o la luna), en el mundo
uniform float relampago = 0.0;

varying vec3 n_mundo;
varying vec4 dato;

void vertex() {
	n_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	dato = INSTANCE_CUSTOM;
}

// Umbral de un tramado 4x4 (Bayer), para el fundido sin transparencia
float bayer(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int k = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[k] + 0.5) / 16.0;
}

void fragment() {
	if (dato.a < bayer(FRAGCOORD.xy)) {
		discard;
	}
	float arriba = n_mundo.y * 0.5 + 0.5;
	float al_sol = dot(n_mundo, normalize(sol_dir)) * 0.5 + 0.5;
	float l = smoothstep(0.25, 0.85, arriba * 0.55 + al_sol * 0.6 - 0.05);
	vec3 c = mix(nube_sombra.rgb, nube_luz.rgb, l) * dato.rgb;
	ALBEDO = c + vec3(0.8, 0.85, 1.0) * relampago * 0.5;
}
