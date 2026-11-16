// Parte común del estilo cozy: cel suave, tinte de sombra, rim y la función light().
// La usan estilo_cozy.gdshader y paloma_zonas.gdshader. Uso, al final de fragment(), con ALBEDO
// ya escrito:
//     COZY_FRAGMENT;
// y no definir otra light() en el shader. Ver shaders/README_estilo_cozy.md.
//
// Con una luz blanca de energía 1:  color ≈ mix(ALBEDO * shadow_tint, ALBEDO, luz) + ambiente + rim
// - El "piso" ALBEDO * shadow_tint va en EMISSION: existe aunque no haya ninguna luz, así lo que
//   no recibe luz directa queda teñido y conserva su color, nunca negro.
// - light() corre una vez por luz y suma sólo lo que falta para llegar al color pleno. No suma
//   piso, así dos luces no duplican el tinte. ATTENUATION entra en el factor de luz, por eso las
//   sombras proyectadas tienen el mismo tinte que el lado oscuro del objeto.

group_uniforms iluminacion;
uniform float umbral_sombra : hint_range(-1.0, 1.0) = 0.0;
uniform float ancho_transicion : hint_range(0.001, 1.0) = 0.15;

group_uniforms sombra;
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.42, 0.62, 1.0);
uniform float intensidad_tinte : hint_range(0.0, 1.0) = 1.0;

group_uniforms rim;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);
uniform float rim_intensidad : hint_range(0.0, 1.0) = 0.25;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

group_uniforms avanzado;
// Sólo GL Compatibility: true si el sol (luz direccional) tiene sombras. Ver light().
uniform bool compat_sol_con_sombras = true;
group_uniforms;

// Luz del cielo para todo el mundo (la maneja world/cielo.gd: blanco de día, azul oscuro de noche,
// gris con lluvia). Multiplica el piso teñido y el rim, que si no quedarían igual de claros de noche.
global uniform vec4 cozy_cielo;

// Tinte de sombra efectivo (shadow_tint * intensidad * cielo), de fragment() a light().
varying vec3 tinte;

// Piso teñido + rim: lo que va en EMISSION.
vec3 cozy_emision(vec3 albedo, vec3 normal, vec3 view) {
	// Rim / Fresnel sutil (NORMAL y VIEW están en espacio de vista).
	float fres = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), rim_power);
	return albedo * shadow_tint.rgb * intensidad_tinte * cozy_cielo.rgb
			+ rim_color.rgb * fres * rim_intensidad * cozy_cielo.rgb;
}

// Un varying no se puede escribir dentro de una función: por eso es una macro.
#define COZY_FRAGMENT tinte = shadow_tint.rgb * intensidad_tinte * cozy_cielo.rgb; EMISSION = cozy_emision(ALBEDO, NORMAL, VIEW)

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	float luz = smoothstep(umbral_sombra - ancho_transicion, umbral_sombra + ancho_transicion, ndotl);
	float f = luz * ATTENUATION;
	vec3 resto = max(vec3(1.0) - tinte, vec3(0.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// En Compatibility ALBEDO, EMISSION y los source_color se manejan en sRGB y el motor los pasa
	// a lineal al final; DIFFUSE_LIGHT sí es lineal. Además, una luz direccional con sombras se
	// dibuja en un pase aparte que se suma en sRGB al pase base (donde está el piso). Para que
	// piso + luz den exactamente ALBEDO (medido en 4.7.2):
	if (compat_sol_con_sombras && LIGHT_IS_DIRECTIONAL) {
		// Suma en sRGB: se lleva a lineal lo que tiene que aparecer en pantalla.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * pow(resto * f, vec3(2.2));
	} else {
		// Suma en lineal: lo que falta es 1 - tinte en lineal.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * f * max(vec3(1.0) - pow(tinte, vec3(2.2)), vec3(0.0));
	}
#else
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * f * resto;
#endif
}
