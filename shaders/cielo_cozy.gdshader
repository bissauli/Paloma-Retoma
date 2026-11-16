shader_type sky;
// Cielo del estilo cozy: degradé cenit/horizonte, sol con halo y rayos suaves, luna con fase,
// estrellas y destello de relámpago. Lo maneja world/cielo.gd (hora del día y clima): acá no hay
// lógica de tiempo, sólo dibujo. Sin texturas: corre bien en web y teléfono.

uniform vec4 cenit : source_color = vec4(0.38, 0.68, 0.94, 1.0);
uniform vec4 horizonte : source_color = vec4(0.81, 0.91, 0.97, 1.0);
uniform vec4 suelo : source_color = vec4(0.6, 0.64, 0.66, 1.0);
// Qué tan baja empieza a subir el color del cenit (más alto = horizonte más ancho)
uniform float curva_degrade = 0.45;

uniform vec3 sol_dir = vec3(0.0, 0.7, -0.7);   // hacia el sol, normalizado
uniform vec4 sol_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float sol_visible : hint_range(0.0, 1.0) = 1.0;   // 0 detrás de las nubes / de noche
uniform float sol_tam = 0.045;                 // radio del disco en radianes
uniform float sol_halo : hint_range(0.0, 2.0) = 0.6;
uniform float sol_rayos : hint_range(0.0, 1.0) = 0.2;
// Resplandor del horizonte del lado del sol (amanecer y atardecer)
uniform vec4 resplandor_color : source_color = vec4(1.0, 0.6, 0.4, 1.0);
uniform float resplandor : hint_range(0.0, 1.0) = 0.0;

uniform vec3 luna_dir = vec3(0.0, 0.6, 0.8);
uniform float luna_visible : hint_range(0.0, 1.0) = 0.0;
uniform vec3 luna_sombra = vec3(0.02, 0.0, 0.0);  // corrimiento del disco de sombra (fase)
uniform float luna_tam = 0.04;

uniform float estrellas : hint_range(0.0, 1.0) = 0.0;
uniform float tiempo = 0.0;                    // segundos, para el titileo (lo pasa cielo.gd)
uniform float relampago : hint_range(0.0, 1.0) = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float disco(vec3 d, vec3 centro, float radio, float borde) {
	return smoothstep(cos(radio), cos(radio * borde), dot(d, centro));
}

void sky() {
	// En Compatibility EYEDIR no llega normalizado (se nota como un corte recto en el cielo)
	vec3 d = normalize(EYEDIR);
	float h = d.y;

	// Degradé: horizonte claro abajo, cenit saturado arriba; por debajo del horizonte, "suelo"
	float t = pow(clamp(h, 0.0, 1.0), curva_degrade);
	vec3 col = mix(horizonte.rgb, cenit.rgb, t);
	col = mix(col, suelo.rgb, smoothstep(0.0, -0.12, h));

	// Resplandor del amanecer/atardecer: banda baja que se enciende del lado del sol
	float hacia_sol = dot(normalize(vec3(d.x, 0.0, d.z) + 1e-5), normalize(vec3(sol_dir.x, 0.0, sol_dir.z) + 1e-5));
	float banda = exp(-abs(h) * 5.0) * (0.35 + 0.65 * pow(max(hacia_sol, 0.0), 2.0));
	col = mix(col, resplandor_color.rgb, clamp(banda * resplandor, 0.0, 1.0));

	// Estrellas: una por celda de una grilla sobre la esfera, sólo arriba del horizonte
	if (estrellas > 0.01 && h > 0.0) {
		vec3 p = d * 110.0;
		vec3 c = floor(p);
		float r = hash(c);
		if (r > 0.965) {
			vec3 centro = c + vec3(hash(c + 1.7), hash(c + 3.1), hash(c + 5.3));
			float brillo = smoothstep(0.18, 0.0, length(p - centro));
			brillo *= 0.65 + 0.35 * sin(tiempo * (1.5 + r * 3.0) + r * 60.0);
			col += vec3(1.0, 0.97, 0.9) * brillo * estrellas * smoothstep(0.0, 0.25, h);
		}
	}

	// Sol: halo ancho + disco blando + rayos que giran muy despacio
	float sd = dot(d, sol_dir);
	if (sol_visible > 0.001) {
		float halo = pow(max(sd, 0.0), 12.0) * 0.45 + pow(max(sd, 0.0), 160.0) * 0.6;
		vec3 a = normalize(abs(sol_dir.y) < 0.99 ? cross(sol_dir, vec3(0.0, 1.0, 0.0)) : vec3(1.0, 0.0, 0.0));
		vec3 b = cross(sol_dir, a);
		vec3 v = d - sol_dir * sd;
		float ang = atan(dot(v, b), dot(v, a));
		float rayos = pow(0.5 + 0.5 * sin(ang * 7.0 + tiempo * 0.03), 8.0)
				+ 0.6 * pow(0.5 + 0.5 * sin(ang * 13.0 - tiempo * 0.02 + 1.3), 10.0);
		rayos *= pow(max(sd, 0.0), 6.0) * (1.0 - pow(max(sd, 0.0), 400.0));
		col += sol_color.rgb * (halo * sol_halo + rayos * sol_rayos) * sol_visible;
		float disc = disco(d, sol_dir, sol_tam, 0.8);
		col = mix(col, mix(sol_color.rgb, vec3(1.0, 1.0, 0.96), 0.7), disc * sol_visible);
	}

	// Luna: disco crema menos un disco de sombra corrido (la fase), con un halo suave
	if (luna_visible > 0.001) {
		float dm = dot(d, luna_dir);
		float halo_l = pow(max(dm, 0.0), 90.0) * 0.25;
		float luz = disco(d, luna_dir, luna_tam, 0.85);
		float sombra = disco(d, normalize(luna_dir + luna_sombra), luna_tam * 1.02, 0.85);
		vec3 crema = vec3(1.0, 0.97, 0.86);
		col += crema * halo_l * luna_visible;
		col = mix(col, crema, luz * (1.0 - sombra * 0.94) * luna_visible);
	}

	col += vec3(0.75, 0.8, 1.0) * relampago * 0.6;
	COLOR = col;
}
