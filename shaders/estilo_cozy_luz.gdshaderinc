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

// Modo cómic (Halftone Toon Shade): 0 = cozy de siempre, 1 = cel duro + semitono en las sombras.
// El contorno de tinta es otro material (contorno_tinta.gdshader) en el next_pass.
global uniform float comic_activo;
// Tamaño de la celda de puntos en píxeles, medido a 1080 de alto (escala con la resolución).
global uniform float comic_celda;

group_uniforms comic;
// Qué tan oscura es la tinta de los puntos respecto del color de sombra (0 = negro).
uniform float comic_tinta : hint_range(0.0, 1.0) = 0.62;
// Radio de los puntos en la sombra plena (1 = tocan el borde de la celda).
uniform float comic_radio_max : hint_range(0.0, 1.5) = 0.78;
// Qué tan opacos son los puntos (1 = tinta plena; menos = más diluidos).
uniform float comic_opacidad : hint_range(0.0, 1.0) = 0.7;
// Desde qué distancia a cámara (m) los puntos empiezan a diluirse, y en cuántos metros desaparecen
// casi del todo: evita el ruido de los edificios lejanos.
uniform float comic_lejania_ini : hint_range(0.0, 200.0) = 12.0;
uniform float comic_lejania_largo : hint_range(1.0, 300.0) = 70.0;
group_uniforms;

// 0 cerca, 1 lejos (se calcula en fragment() con la macro COZY_FRAGMENT).
varying float lejania;

// Distancia al centro del punto más cercano de la trama (en pantalla, girada 45°), 0 en el centro y
// 1 en el borde de la celda. aa = medio píxel en esas unidades, para el antialias del borde.
float comic_dist(vec2 frag, vec2 vp, out float aa) {
	float celda = max(comic_celda * vp.y / 1080.0, 3.0);
	vec2 p = frag / celda;
	p = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
	vec2 g = fract(p) - 0.5;
	aa = 3.0 / celda; // borde blando, los puntos se ven difuminados
	return length(g) * 2.0;
}

// Cuánto del píxel cae dentro de un punto de radio r.
float comic_cobertura(float d, float r, float aa) {
	float c = r <= 0.001 ? 0.0 : 1.0 - smoothstep(r - aa, r + aa, d);
	return c * comic_opacidad * (1.0 - 0.85 * lejania);
}

// Piso (lo que hay sin luz) como multiplicador del albedo: en modo cómic, los puntos de radio
// máximo ya están en tinta y la luz "los borra" donde corresponde (ver light()).
vec3 comic_piso(vec3 t, vec2 frag, vec2 vp) {
	if (comic_activo <= 0.0) {
		return t;
	}
	float aa;
	float d = comic_dist(frag, vp, aa);
	return mix(t, t * comic_tinta, comic_cobertura(d, comic_radio_max * comic_activo, aa));
}

// Tinte de sombra efectivo (shadow_tint * intensidad * cielo), de fragment() a light().
varying vec3 tinte;

// Piso teñido + rim: lo que va en EMISSION.
vec3 cozy_emision(vec3 albedo, vec3 normal, vec3 view, vec2 frag, vec2 vp) {
	// Rim / Fresnel sutil (NORMAL y VIEW están en espacio de vista). En modo cómic lo reemplaza
	// el contorno de tinta.
	float fres = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), rim_power);
	vec3 t = shadow_tint.rgb * intensidad_tinte * cozy_cielo.rgb;
	return albedo * comic_piso(t, frag, vp)
			+ rim_color.rgb * fres * rim_intensidad * cozy_cielo.rgb * (1.0 - comic_activo);
}

// Un varying no se puede escribir dentro de una función: por eso es una macro.
#define COZY_FRAGMENT lejania = clamp((-VERTEX.z - comic_lejania_ini) / comic_lejania_largo, 0.0, 1.0); tinte = shadow_tint.rgb * intensidad_tinte * cozy_cielo.rgb; EMISSION = cozy_emision(ALBEDO, NORMAL, VIEW, FRAGCOORD.xy, VIEWPORT_SIZE)

void light() {
	float ndotl = dot(NORMAL, LIGHT);
	// Cel: en modo cómic el borde luz/sombra queda duro (bloques planos).
	float ancho = mix(ancho_transicion, 0.025, comic_activo);
	float luz = smoothstep(umbral_sombra - ancho, umbral_sombra + ancho, ndotl);
	float f = luz * ATTENUATION;
	vec3 resto = max(vec3(1.0) - tinte, vec3(0.0));
	// Todo como multiplicador del albedo (en sRGB): piso = lo que ya puso fragment() en EMISSION,
	// deseado = lo que tiene que verse con esta luz.
	vec3 piso = tinte;
	vec3 deseado = tinte + resto * f;
	if (comic_activo > 0.0) {
		float aa;
		float d = comic_dist(FRAGCOORD.xy, VIEWPORT_SIZE, aa);
		vec3 tinta = tinte * comic_tinta;
		float r_max = comic_radio_max * comic_activo;
		piso = mix(tinte, tinta, comic_cobertura(d, r_max, aa));
		if (LIGHT_IS_DIRECTIONAL) {
			// Semitono: los puntos crecen cuanto menos luz recibe la cara (y bajo una sombra
			// proyectada quedan al máximo). Pasan un poco al lado iluminado para el degradé pop-art.
			float osc = 1.0 - smoothstep(umbral_sombra - 0.02, umbral_sombra + 0.3, ndotl) * ATTENUATION;
			deseado = mix(deseado, tinta, comic_cobertura(d, r_max * osc, aa));
		} else {
			// Faroles y luces de los locales: iluminan también los puntos.
			deseado = piso + resto * f;
		}
	}
	vec3 suma = max(deseado - piso, vec3(0.0));
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// En Compatibility ALBEDO, EMISSION y los source_color se manejan en sRGB y el motor los pasa
	// a lineal al final; DIFFUSE_LIGHT sí es lineal. Además, una luz direccional con sombras se
	// dibuja en un pase aparte que se suma en sRGB al pase base (donde está el piso). Para que
	// piso + luz den exactamente ALBEDO (medido en 4.7.2):
	if (compat_sol_con_sombras && LIGHT_IS_DIRECTIONAL) {
		// Suma en sRGB: se lleva a lineal lo que tiene que aparecer en pantalla.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * pow(suma, vec3(2.2));
	} else if (LIGHT_IS_DIRECTIONAL) {
		// Suma en lineal: la diferencia entre lo deseado y el piso, ambos en lineal.
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * max(pow(deseado, vec3(2.2)) - pow(piso, vec3(2.2)), vec3(0.0));
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * f * max(vec3(1.0) - pow(tinte, vec3(2.2)), vec3(0.0));
	}
#else
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * suma;
#endif
}
