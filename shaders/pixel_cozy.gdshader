shader_type canvas_item;
// Pixel cozy (inspirado en A Short Hike), sobre el 3D ya dibujado. Va en una capa por DEBAJO del HUD
// (ver autoload/filtros.gd).
//
// 1. Grilla de pixeles cuadrados de un tamaño ENTERO de pixeles reales (todas las celdas iguales en
//    cualquier resolucion).
// 2. Cada celda toma uno de 4 colores reales de adentro (el que mas se parece a los otros tres), no el
//    promedio: bordes nitidos, sin colores intermedios embarrados.
// 3. El brillo se parte en pocas bandas conservando el color. El tramado solo aparece donde hay un
//    degrade de verdad (una pared plana queda lisa, nunca con "mosquitero").
// 4. Las sombras corren el tono hacia violeta y ganan saturacion (nunca gris sucio); las luces se doran.
// 5. Contorno de 1 pixel del lado oscuro de cada borde, del mismo tono pero mas oscuro y frio
//    (selout), detectado por diferencia de color, no solo de brillo.

uniform sampler2D pantalla : hint_screen_texture, filter_nearest, repeat_disable;
// Alto aproximado de la imagen en pixeles "virtuales". El tamaño de celda se redondea a un entero.
uniform float alto_virtual : hint_range(120.0, 1080.0) = 340.0;
// Bandas de brillo. Menos = mas pintado; mas = mas suave.
uniform float bandas : hint_range(3.0, 16.0) = 6.0;
// Tramado en el limite entre dos bandas (solo sobre degrades). 0 = bandas duras.
uniform float dither : hint_range(0.0, 1.0) = 0.0;
uniform float saturacion : hint_range(0.0, 2.0) = 1.1;
// Tono hacia el que van las sombras y cuanto.
uniform vec3 color_sombra : source_color = vec3(0.50, 0.32, 0.60);
uniform float fuerza_sombra : hint_range(0.0, 1.0) = 0.3;
// Tono de las luces y cuanto.
uniform vec3 color_luz : source_color = vec3(1.0, 0.88, 0.62);
uniform float fuerza_luz : hint_range(0.0, 1.0) = 0.4;
// Contorno: cuanto oscurece y desde que diferencia de color aparece.
uniform float contorno : hint_range(0.0, 1.0) = 0.3;
uniform float umbral_contorno : hint_range(0.02, 0.5) = 0.18;
uniform float vineta : hint_range(0.0, 1.0) = 0.25;
// Tono general de tarde: todo un poco mas calido y las sombras levantadas hacia color_sombra
// (como en A Short Hike: nada queda gris ni negro, las zonas oscuras son violeta-rojizas).
uniform float calidez : hint_range(0.0, 1.0) = 0.5;
uniform float levante : hint_range(0.0, 0.3) = 0.1;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float brillo(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Distancia entre colores con algo mas de peso al verde (el ojo lo nota mas).
float dist(vec3 a, vec3 b) {
	vec3 d = (a - b) * vec3(0.8, 1.0, 0.6);
	return length(d);
}

vec3 muestra(vec2 px, vec2 tam_inv) {
	return texture(pantalla, px * tam_inv).rgb;
}

void fragment() {
	vec2 tam_inv = SCREEN_PIXEL_SIZE;
	vec2 tam = 1.0 / tam_inv;
	float lado = max(1.0, floor(tam.y / alto_virtual + 0.5));
	// Grilla centrada en la pantalla: el recorte de la ultima fila/columna se reparte en los dos bordes.
	vec2 origen = floor(mod(tam, lado) * 0.5);
	vec2 celda = floor((SCREEN_UV * tam - origen) / lado);
	vec2 base = origen + celda * lado;

	// 4 muestras en el centro de cada cuarto de la celda (centros de texel exactos).
	float a = floor(lado * 0.25) + 0.5;
	float b = floor(lado * 0.75) + 0.5;
	vec3 m0 = muestra(base + vec2(a, a), tam_inv);
	vec3 m1 = muestra(base + vec2(b, a), tam_inv);
	vec3 m2 = muestra(base + vec2(a, b), tam_inv);
	vec3 m3 = muestra(base + vec2(b, b), tam_inv);
	// Medoide: la muestra mas parecida a las otras tres.
	float d01 = dist(m0, m1), d02 = dist(m0, m2), d03 = dist(m0, m3);
	float d12 = dist(m1, m2), d13 = dist(m1, m3), d23 = dist(m2, m3);
	float s0 = d01 + d02 + d03, s1 = d01 + d12 + d13, s2 = d02 + d12 + d23, s3 = d03 + d13 + d23;
	vec3 c = m0;
	float mejor = s0;
	if (s1 < mejor) { c = m1; mejor = s1; }
	if (s2 < mejor) { c = m2; mejor = s2; }
	if (s3 < mejor) { c = m3; }
	float l = brillo(c);

	// Vecinos (centro de las celdas de arriba, abajo, izquierda y derecha).
	vec2 cen = base + floor(lado * 0.5) + 0.5;
	vec3 vn = muestra(cen - vec2(0.0, lado), tam_inv);
	vec3 vs = muestra(cen + vec2(0.0, lado), tam_inv);
	vec3 vo = muestra(cen - vec2(lado, 0.0), tam_inv);
	vec3 ve = muestra(cen + vec2(lado, 0.0), tam_inv);
	float ln = brillo(vn), ls = brillo(vs), lo = brillo(vo), le = brillo(ve);

	// Contorno: solo del lado oscuro de un borde (un vecino distinto y mas claro), asi queda de 1 pixel.
	float e = max(max(dist(c, vn) * step(l + 0.01, ln), dist(c, vs) * step(l + 0.01, ls)),
		max(dist(c, vo) * step(l + 0.01, lo), dist(c, ve) * step(l + 0.01, le)));
	float borde = smoothstep(umbral_contorno, umbral_contorno + 0.08, e);

	// Degrade local: cuanto cambia el brillo hacia los vecinos. En superficies planas no hay tramado.
	float grad = max(max(abs(ln - l), abs(ls - l)), max(abs(lo - l), abs(le - l)));
	// (y en un borde fuerte tampoco).
	float tramado = dither * smoothstep(0.004, 0.015, grad) * (1.0 - smoothstep(0.08, 0.2, grad)) * (1.0 - borde);

	// Saturacion y bandas de brillo conservando el color.
	c = mix(vec3(l), c, saturacion);
	int i = int(mod(celda.x, 4.0)) + 4 * int(mod(celda.y, 4.0));
	float bay = (BAYER[i] + 0.5) / 16.0 - 0.5;
	// La banda se elige con un brillo suavizado (la celda y sus vecinas): la textura fina que cae
	// justo en el limite entre dos bandas no salta de una a otra celda por celda (ruido "sal y
	// pimienta"). El detalle propio de la celda se conserva relativo a ese brillo suave.
	float lm = (brillo(m0) + brillo(m1) + brillo(m2) + brillo(m3)) * 0.25;
	float lsuave = (lm * 4.0 + ln + ls + lo + le) / 8.0;
	lsuave = mix(lsuave, lm, step(0.08, grad)); // en un borde fuerte, sin mezclar con el otro lado
	float lb = clamp(floor(lsuave * bandas + 0.5 + bay * tramado) / bandas, 0.0, 1.0);
	c *= (lb + 0.03) / (lsuave + 0.03);

	// Sombras: el tono va hacia color_sombra (con el brillo propio) y gana saturacion.
	float sombra = (1.0 - smoothstep(0.2, 0.65, lb)) * fuerza_sombra;
	vec3 tinte_s = color_sombra / max(brillo(color_sombra), 0.01);
	vec3 cs = c * tinte_s;
	cs = mix(vec3(brillo(cs)), cs, 1.15);
	c = mix(c, cs, sombra);
	// Sombras levantadas hacia el violeta-rojizo (nunca negro puro).
	c = c * (1.0 - levante) + color_sombra * levante * (1.0 - lb);
	// Luces doradas.
	vec3 tinte_l = color_luz / max(brillo(color_luz), 0.01);
	c = mix(c, c * tinte_l, smoothstep(0.55, 0.95, lb) * fuerza_luz);
	// Tono general de tarde (sube rojo, baja azul, sin cambiar el brillo).
	c = mix(c, c * vec3(1.07, 1.0, 0.86) / 0.995, calidez * 0.5);

	// Contorno: mismo tono, mas oscuro y calido (marron-violeta, no negro).
	vec3 oscuro = c * vec3(0.62, 0.48, 0.56);
	c = mix(c, oscuro, borde * contorno);

	// Viñeta calida, por celdas (no rompe la grilla).
	vec2 uv_celda = (base + lado * 0.5) * tam_inv;
	float d = length((uv_celda - 0.5) * vec2(1.0, 0.8));
	c = mix(c, c * vec3(0.82, 0.72, 0.84), smoothstep(0.4, 0.85, d) * vineta);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
