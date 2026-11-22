shader_type spatial;
render_mode unshaded, cull_back;
// El interior de un local visto por su vidriera (ver world/vidrieras.gd), sin geometría: el plano de la
// vidriera calcula por dónde sale el rayo de la cámara de una caja (el local) que está DETRÁS del vidrio
// y pinta lo que toca: el piso, el cielorraso con su luz, las paredes con lo que tiene el rubro
// (estantes con mercadería ordenada por tramos, espejos, cuadros, boiserie) y los muebles del medio
// (un mostrador, los sillones de la peluquería, la línea de cajas del banco, escritorios...). Así tiene
// profundidad de verdad (se ve distinto desde cada ángulo) y no hace falta ahuecar los edificios del kit.
// El tamaño sale del propio plano (un QuadMesh centrado): cada vértice está en una esquina.

uniform vec3 pared : source_color = vec3(0.95, 0.92, 0.85);
uniform vec3 piso : source_color = vec3(0.75, 0.72, 0.68);
uniform vec3 mueble : source_color = vec3(0.55, 0.36, 0.22);
uniform vec3 c1 : source_color = vec3(0.85, 0.25, 0.2);
uniform vec3 c2 : source_color = vec3(0.95, 0.8, 0.25);
uniform vec3 c3 : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 c4 : source_color = vec3(0.3, 0.7, 0.35);
// Las paredes: 0 cajas, 1 redondos, 2 ropa colgada, 3 botellas, 4 libros, 5 lavarropas, 6 cuadros,
// 7 espejos de peluquería, 8 boiserie con carteles (banco), 9 pizarrón (escuela), 10 anteojos,
// 11 local de comida (menú en el pizarrón y mostrador vidriado con bandejas al fondo; a los costados,
// estantes con bandejas de comida), 12 bicis colgadas, 13 heladería (vitrina con baldes de helado)
uniform int forma = 0;
// Lo del medio: 0 mostrador a un costado, 1 nada, 2 banco para sentarse (galería), 3 sillones de
// peluquería frente a los espejos, 4 línea de cajas con vidrio y fila con cordones (banco),
// 5 escritorios con computadora, 6 la parrilla con brasas y su campana (y el mostrador)
uniform int muebles = 0;
uniform float damero = 0.0;     // 0 baldosas parejas, 1 blancas y negras
uniform float filas = 4.0;      // Cuántos estantes
uniform float celda = 0.3;      // Ancho de cada cosa del estante
uniform float fondo = 3.2;      // Profundidad del local
uniform float bajo = 0.5;       // Del borde de abajo del vidrio al piso del local

varying vec3 pos_l;
varying vec3 cam_l;
varying vec2 medio;   // Medio ancho y medio alto del vidrio
varying float semilla;

const float TRAMO = 1.2;   // Cada tramo de estante tiene una sola mercadería (así se ve ordenado)

float azar(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	pos_l = VERTEX;
	medio = abs(VERTEX.xy);
	cam_l = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	semilla = fract(dot(MODEL_MATRIX[3].xyz, vec3(0.137, 0.0, 0.291)));
}

vec3 color_de(float h) {
	return h < 0.25 ? c1 : (h < 0.5 ? c2 : (h < 0.75 ? c3 : c4));
}

// Un rectángulo con marco: devuelve 0 afuera, 1 en el marco y 2 adentro
float marco(vec2 p, vec2 lo, vec2 hi, float borde) {
	if (p.x < lo.x || p.x > hi.x || p.y < lo.y || p.y > hi.y) {
		return 0.0;
	}
	return (p.x < lo.x + borde || p.x > hi.x - borde || p.y < lo.y + borde || p.y > hi.y - borde) ? 1.0 : 2.0;
}

// Distancia de "p" al segmento a-b
float segmento(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float k = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length(p - a - ab * k);
}

// El menú escrito en tiza (renglones con el plato a la izquierda y el precio a la derecha)
vec3 menu(vec2 q, vec2 lo, vec2 hi, float sem) {
	float m = marco(q, lo, hi, 0.05);
	if (m == 1.0) {
		return mueble * 1.2;
	}
	float renglon = floor((q.y - lo.y - 0.08) / 0.13);
	float fr = fract((q.y - lo.y - 0.08) / 0.13);
	float x = (q.x - lo.x) / (hi.x - lo.x);
	bool letra = fr > 0.45 && fr < 0.62 && renglon >= 0.0 && renglon < 5.0
		&& ((x > 0.08 && x < 0.35 + 0.3 * azar(vec3(renglon, sem, 3.0))) || (x > 0.8 && x < 0.92));
	return letra ? (x > 0.78 ? c2 * 1.2 : vec3(0.9)) : vec3(0.14, 0.16, 0.15);
}

// Una cosa de comer sobre una bandeja, de perfil: media luna (empanada), redonda o alargada según "h"
bool comida(vec2 q, float ancho, float h) {
	vec2 d = vec2(q.x / (ancho * 0.45), q.y / (ancho * (h < 0.5 ? 0.28 : 0.38)));
	return q.y >= 0.0 && length(d) < 1.0;
}

// Una pared: "u" a lo largo de la pared, "v" la altura sobre el piso, "lado" -1/1 los costados y 0 el
// fondo, "f" lo que tiene (ver "forma")
vec3 estantes(float u, float v, float lado, float sem, int f) {
	vec3 col = pared;
	if (v < 0.12) {
		return mueble * 0.6;   // Zócalo
	}
	if (f == 11 || f == 13) {   // Comida o helados: al fondo, el menú arriba y el mostrador vidriado abajo
		if (lado == 0.0) {
			if (v > 1.3 && v < 2.15) {
				float cw = 2.2;
				float fu = fract(u / cw) * cw;
				if (fu > 0.3 && fu < 1.9) {
					return menu(vec2(fu, v), vec2(0.3, 1.3), vec2(1.9, 2.15), sem + floor(u / cw));
				}
				return col;
			}
			if (v < 0.4) {
				return mueble * (fract(u / 0.9) < 0.02 ? 0.7 : 0.9);
			}
			if (v < 1.02) {   // El vidrio del mostrador, con lo que hay adentro
				if (v > 0.97 || fract(u / 1.8) < 0.015) {
					return vec3(0.72, 0.74, 0.76);   // Marco de aluminio
				}
				vec3 adentro = vec3(0.9, 0.92, 0.9);
				if (f == 13) {   // Baldes de helado en fila, cada uno de un gusto
					float bw = 0.34;
					float fb = fract(u / bw);
					float gusto = azar(vec3(floor(u / bw), sem, 5.0));
					if (fb > 0.08 && fb < 0.92 && v > 0.5 && v < 0.84) {
						float copete = 0.78 + 0.05 * sin(fb * 9.0 + gusto * 6.0);
						adentro = v < 0.62 ? vec3(0.75, 0.77, 0.8) : (v < copete ? mix(color_de(gusto), vec3(1.0), 0.35) : adentro);
					}
				} else {         // Dos bandejas, una arriba de la otra, con la comida
					for (int k = 0; k < 2; k++) {
						float base = 0.5 + float(k) * 0.24;
						if (v > base - 0.02 && v < base) {
							return mueble * 1.3;
						}
						float iw = celda;
						float fi = fract(u / iw);
						float h = azar(vec3(floor(u / TRAMO), float(k), sem));
						if (comida(vec2((fi - 0.5) * iw, v - base), iw, h)) {
							adentro = color_de(h) * (0.85 + 0.25 * (v - base) / 0.12);
						}
					}
				}
				return mix(adentro, vec3(0.75, 0.85, 0.9), 0.15);
			}
			return col;
		}
		if (f == 13) {   // A los costados de la heladería: cuadros de cucuruchos y un mueble bajo
			f = 6;
		} else {         // A los costados: estantes con bandejas de comida
			float rh = 0.42;
			float r = floor((v - 0.5) / rh);
			if (v < 0.5) {
				return mueble * 0.85;
			}
			if (r >= 3.0) {
				return col;
			}
			float fv = fract((v - 0.5) / rh) * rh;
			if (fv < 0.03) {
				return mueble * 0.9;
			}
			if (fv < 0.05) {
				return vec3(0.78, 0.8, 0.82);   // La bandeja
			}
			float h = azar(vec3(floor(u / TRAMO), r + lado * 7.0, sem));
			float fi = fract(u / celda);
			if (comida(vec2((fi - 0.5) * celda, fv - 0.05), celda, h)) {
				return color_de(h) * (0.85 + 0.6 * (fv - 0.05));
			}
			return col;
		}
	}
	if (f == 12) {   // Bicicletería: bicis colgadas en las paredes, cada una de un color; abajo, cascos
		if (v < 0.75) {
			if (v > 0.68) {
				return mueble * 1.1;
			}
			float fu = fract(u / 0.45);
			vec2 d = vec2((fu - 0.5) * 0.45, v - 0.42);
			if (length(d * vec2(1.0, 1.4)) < 0.15 && v > 0.42) {
				return color_de(azar(vec3(floor(u / 0.45), lado, sem)));   // Un casco
			}
			return mueble * 0.85;
		}
		float cw = 1.4;
		float fu = fract(u / cw) * cw;
		vec2 q = vec2(fu, v);
		vec3 cuadro = color_de(azar(vec3(floor(u / cw), lado, sem)));
		vec2 rueda_a = vec2(0.33, 1.3);
		vec2 rueda_b = vec2(1.07, 1.3);
		float ra = abs(length(q - rueda_a) - 0.27);
		float rb = abs(length(q - rueda_b) - 0.27);
		if (ra < 0.025 || rb < 0.025) {
			return vec3(0.12);   // Cubiertas
		}
		if (length(q - rueda_a) < 0.03 || length(q - rueda_b) < 0.03) {
			return vec3(0.6);    // Mazas
		}
		vec2 eje = vec2(0.62, 1.3);
		vec2 asiento = vec2(0.55, 1.62);
		vec2 manubrio = vec2(0.98, 1.64);
		float cuadro_d = min(min(segmento(q, rueda_a, eje), segmento(q, eje, asiento)),
			min(min(segmento(q, asiento, manubrio), segmento(q, eje, manubrio)),
				min(segmento(q, manubrio, rueda_b), segmento(q, rueda_a, asiento))));
		if (cuadro_d < 0.022) {
			return cuadro;
		}
		if (segmento(q, asiento + vec2(-0.07, 0.03), asiento + vec2(0.07, 0.03)) < 0.025
				|| segmento(q, manubrio + vec2(-0.05, 0.04), manubrio + vec2(0.06, 0.06)) < 0.02) {
			return vec3(0.15);   // Asiento y manubrio
		}
		if (segmento(q, vec2(0.55, 1.95), vec2(0.55, 1.68)) < 0.012 || segmento(q, vec2(0.98, 1.95), vec2(0.98, 1.7)) < 0.012) {
			return vec3(0.45);   // Los ganchos de donde cuelga
		}
		return col;
	}
	if (f == 7) {   // Peluquería: espejos grandes a los costados con su repisa; al fondo, productos
		if (lado == 0.0) {
			f = 3;
		} else {
			float cw = 1.1;
			float fu = fract(u / cw);
			float m = marco(vec2(fu, v), vec2(0.1, 0.95), vec2(0.9, 2.05), 0.035);
			if (m == 1.0) {
				return mueble * 1.3;
			}
			if (m == 2.0) {   // El espejo: refleja el local, más claro, con un brillo en diagonal
				float brillo = smoothstep(0.06, 0.0, abs(fract(fu * 1.3 + v * 0.45) - 0.5));
				return mix(pared * 0.82, vec3(0.78, 0.86, 0.92), 0.55) + brillo * 0.12;
			}
			if (v > 0.82 && v < 0.92 && fu > 0.06 && fu < 0.94) {
				return mueble * 1.1;   // La repisa
			}
			if (v > 0.92 && v < 0.95 && fu > 0.3 && fu < 0.4) {
				return c2;   // Un frasco sobre la repisa
			}
			return v < 0.82 ? pared * 0.9 : col;
		}
	}
	if (f == 9) {   // Escuela: el pizarrón al fondo (con lo escrito en tiza) y afiches a los costados
		if (lado != 0.0) {
			f = 6;
		} else {
			float m = marco(vec2(u, v), vec2(0.6, 0.95), vec2(2.0 * fondo, 2.15), 0.06);
			if (m == 1.0) {
				return mueble * 1.2;
			}
			if (m == 2.0) {
				float renglon = floor((v - 1.0) / 0.16);
				float palabra = floor(u / 0.35);
				bool tiza = fract((v - 1.0) / 0.16) > 0.55 && fract((v - 1.0) / 0.16) < 0.7
					&& fract(u / 0.35) < 0.75 && azar(vec3(palabra, renglon, sem)) > 0.35 && renglon < 6.0;
				return tiza ? vec3(0.85) : vec3(0.16, 0.32, 0.24);
			}
			return col;
		}
	}
	if (f == 10) {   // Óptica: repisas finitas con anteojos (cada tramo, un color de armazón)
		float rv = (v - 0.9) / 0.3;
		if (v < 0.9 || rv >= 4.0) {
			return v < 0.9 ? mueble * 0.9 : col;
		}
		float fv = fract(rv);
		if (fv < 0.06) {
			return mueble * 1.1;   // La repisa
		}
		float fu = fract(u / 0.32);
		vec3 armazon = color_de(azar(vec3(floor(u / TRAMO), floor(rv), sem + lado)));
		vec2 q = vec2(fu * 0.32, fv * 0.3);
		float d1 = length(q - vec2(0.105, 0.14));
		float d2 = length(q - vec2(0.215, 0.14));
		if (abs(d1 - 0.045) < 0.009 || abs(d2 - 0.045) < 0.009 || (q.y > 0.15 && q.y < 0.16 && q.x > 0.145 && q.x < 0.175)) {
			return armazon;
		}
		return col;
	}
	if (f == 8) {   // Banco: boiserie de madera abajo, carteles arriba; al fondo, el logo
		if (v < 1.1) {
			return mueble * (fract(u / 0.6) < 0.02 ? 0.7 : 1.0) * (v > 1.04 ? 1.2 : 1.0);
		}
		if (lado == 0.0) {
			float m = marco(vec2(u, v), vec2(0.0, 1.55), vec2(100.0, 2.45), 0.0);
			float centro = abs(fract(u / 4.0) - 0.5) * 4.0;
			if (v > 1.55 && v < 2.45 && centro < 1.0) {
				return v > 2.1 ? c2 : c1;   // El cartel con el logo del banco
			}
			return col;
		}
		float fu = fract(u / 1.6);
		float m = marco(vec2(fu, v), vec2(0.2, 1.4), vec2(0.8, 2.3), 0.02);
		if (m == 1.0) {
			return mueble;
		}
		if (m == 2.0) {   // Afiches de créditos y tarjetas
			float h = azar(vec3(floor(u / 1.6), lado, sem));
			return v > 1.9 ? color_de(h) : (v > 1.6 ? vec3(0.95) : color_de(fract(h + 0.5)) * 0.9);
		}
		return col;
	}
	if (f == 6) {   // Cuadros (o afiches) colgados, uno al lado del otro
		float cw = 1.5;
		float fu = fract(u / cw);
		float h = azar(vec3(floor(u / cw), lado, sem));
		float m = marco(vec2(fu, v), vec2(0.12, 1.05), vec2(0.88, 2.15), 0.04);
		if (m == 1.0) {
			return mueble;
		}
		if (m == 2.0) {   // Un paisaje simple: cielo, horizonte y tierra (o mar)
			return v > 1.55 + 0.2 * h ? mix(color_de(h), vec3(0.95), 0.35) : color_de(fract(h + 0.37)) * 0.85;
		}
		if (v < 0.9 && fu > 0.08 && fu < 0.92) {   // Mueble bajo
			return v > 0.84 ? mueble * 1.15 : mueble * (fract(u / 0.75) < 0.03 ? 0.7 : 0.95);
		}
		return col;
	}
	bool ropa = f == 2;
	bool lava = f == 5;
	float v0 = lava ? 0.12 : 0.45;
	float rh = ropa ? 0.95 : (lava ? 0.8 : 0.5);
	float r = floor((v - v0) / rh);
	if (r < 0.0) {   // Mueble debajo de los estantes
		return lava ? col : mueble * (fract(u / 0.6) < 0.04 ? 0.65 : 0.85);
	}
	if (r >= filas) {
		return col;
	}
	float fv = fract((v - v0) / rh);
	if (!ropa && !lava && fract(u / TRAMO) < 0.025) {
		return mueble * 0.75;   // Parantes
	}
	if (!ropa && !lava && fv < 0.07) {
		return mueble * 0.9;    // Tabla del estante
	}
	// Cada tramo de cada estante tiene UNA mercadería (un color y un tamaño), como en un local de
	// verdad; cosa por cosa varía apenas el tono
	float tramo = floor(u / TRAMO);
	float ht = azar(vec3(tramo, r + lado * 7.0, sem));
	float tam_t = azar(vec3(tramo + 13.0, r, sem + lado));
	float ci = floor(u / celda);
	float fu = fract(u / celda);
	float h2 = azar(vec3(ci + 31.0, r, sem + lado));
	if (h2 < 0.04 && !lava) {
		return col;   // Muy de vez en cuando falta una
	}
	vec3 cosa = color_de(ht) * (0.92 + 0.12 * h2);
	if (f == 0) {   // Cajas y paquetes
		float alto = 0.07 + (0.5 + 0.4 * tam_t) * 0.85;
		if (fu > 0.07 && fu < 0.93 && fv < alto) {
			return fv > alto - 0.12 ? cosa * 1.15 : cosa;
		}
	} else if (f == 1) {   // Frutas, panes, flores, ovillos (de a dos, uno arriba del otro)
		float rad = celda * 0.42;
		vec2 d = vec2((fu - 0.5) * celda, (fv - 0.07) * rh - rad);
		vec2 d2 = vec2((fract(u / celda + 0.5) - 0.5) * celda, (fv - 0.07) * rh - rad * 2.6);
		if (length(d) < rad) {
			return cosa * (1.05 - 0.4 * length(d) / rad);
		}
		if (length(d2) < rad * 0.9) {
			return cosa * (0.95 - 0.35 * length(d2) / rad);
		}
	} else if (ropa) {   // Percheros con ropa colgada (cada perchero, de una gama)
		if (fv > 0.88 && fv < 0.91) {
			return vec3(0.6);
		}
		float largo = 0.45 + 0.3 * tam_t;
		vec3 prenda = color_de(fract(ht + 0.25 * floor(h2 * 2.0)));
		if (fu > 0.12 && fu < 0.88 && fv < 0.88 && fv > 0.88 - largo) {
			bool manga = fv > 0.88 - 0.18 && (fu < 0.2 || fu > 0.8);
			return manga ? prenda * 0.85 : prenda;
		}
	} else if (f == 3) {   // Botellas y frascos
		if ((fu > 0.28 && fu < 0.72 && fv > 0.07 && fv < 0.62) || (fu > 0.43 && fu < 0.57 && fv < 0.82)) {
			return cosa * (fu > 0.36 && fu < 0.44 ? 1.4 : 1.0);
		}
	} else if (f == 4) {   // Libros, carpetas o discos de canto (cada tramo, una colección)
		if (fu > 0.05 && fu < 0.95 && fv < 0.07 + 0.6 + 0.25 * tam_t) {
			return color_de(fract(ht + 0.25 * floor(h2 * 2.0))) * (0.85 + 0.2 * h2);
		}
	} else if (lava) {   // Lavarropas en fila, con la puerta redonda
		vec2 d = vec2((fu - 0.5) * celda, fv * rh - rh * 0.48);
		if (fu > 0.05 && fu < 0.95 && fv < 0.92) {
			float lr = length(d);
			if (lr < celda * 0.3) {
				return lr > celda * 0.24 ? vec3(0.55) : vec3(0.35, 0.45, 0.55) + 0.25 * h2;
			}
			return c1 * (fv > 0.82 ? 0.85 : 1.0);
		}
	}
	return col;
}

// El rayo contra una caja (lo-hi): si la toca antes de "t", deja ahí el color (sombreado según la
// cara) y devuelve el nuevo t
float caja(vec3 ro, vec3 rd, vec3 lo, vec3 hi, float t, vec3 color, inout vec3 col) {
	vec3 a = (lo - ro) / rd;
	vec3 b = (hi - ro) / rd;
	vec3 mn = min(a, b);
	vec3 mx = max(a, b);
	float te = max(max(mn.x, mn.y), mn.z);
	float ts = min(min(mx.x, mx.y), mx.z);
	if (te >= ts || te <= 0.0 || te >= t) {
		return t;
	}
	col = color * (te == mn.y ? 1.15 : (te == mn.z ? 1.0 : 0.8));
	return te;
}

vec3 interior(vec3 pos, vec3 cam, vec2 med, float sem) {
	vec3 ro = pos;
	vec3 rd = normalize(pos - cam);
	rd.z = min(rd.z, -0.0005);
	if (abs(rd.x) < 0.0001) {
		rd.x = 0.0001;
	}
	if (abs(rd.y) < 0.0001) {
		rd.y = 0.0001;
	}
	// La caja del local: un poco más ancha y alta que el vidrio
	float hx = med.x + 0.45;
	float y0 = -med.y - bajo;
	float y1 = med.y + 0.45;
	vec3 lo = vec3(-hx, y0, -fondo);
	vec3 hi = vec3(hx, y1, 0.5);
	vec3 ta = (lo - ro) / rd;
	vec3 tb = (hi - ro) / rd;
	vec3 tm = max(ta, tb);
	float t = min(min(tm.x, tm.y), tm.z);
	vec3 p = ro + rd * t;
	vec3 col;
	float luz;
	if (t == tm.z) {   // Pared del fondo
		col = estantes(p.x + hx, p.y - y0, 0.0, sem, forma);
		luz = 0.95;
	} else if (t == tm.x) {   // Paredes de los costados
		col = estantes(-p.z, p.y - y0, sign(p.x), sem, forma);
		luz = 0.8;
	} else if (rd.y < 0.0) {   // Piso de baldosas (o damero blanco y negro)
		float k = mod(floor(p.x / 0.5) + floor(p.z / 0.5), 2.0);
		col = k > 0.5 ? piso : mix(piso * 0.88, vec3(0.92, 0.91, 0.88), damero);
		luz = 0.78;
	} else {   // Cielorraso con una fila de luces
		bool tubo = abs(p.x) < 0.12 && fract(p.z / 1.1) < 0.7;
		col = tubo ? vec3(1.6, 1.55, 1.4) : pared * 0.95;
		luz = 1.0;
	}
	float t0 = t;
	vec3 cm = col;
	// --- Los muebles del medio
	float lado_m = sem < 0.5 ? -1.0 : 1.0;
	if (muebles == 0) {   // Un mostrador contra un costado, cerca del vidrio
		float mw = min(1.9, med.x * 0.9);
		float xa = lado_m < 0.0 ? -hx + 0.25 : hx - 0.25 - mw;
		t = caja(ro, rd, vec3(xa, y0, -1.55), vec3(xa + mw, y0 + 0.88, -0.95), t, mueble, cm);
		t = caja(ro, rd, vec3(xa - 0.04, y0 + 0.88, -1.6), vec3(xa + mw + 0.04, y0 + 0.95, -0.9), t, mueble * 1.2, cm);
	} else if (muebles == 6) {   // La parrilla: de ladrillo, con la grilla sobre las brasas y la campana arriba
		float pw = min(1.6, med.x * 0.8);
		float xa = lado_m < 0.0 ? -hx + 0.2 : hx - 0.2 - pw;
		float z0 = -fondo + 0.15;
		float z1 = -fondo + 1.05;
		t = caja(ro, rd, vec3(xa, y0, z0), vec3(xa + pw, y0 + 0.82, z1), t, vec3(0.62, 0.3, 0.22), cm);
		t = caja(ro, rd, vec3(xa + 0.08, y0 + 0.82, z0 + 0.08), vec3(xa + pw - 0.08, y0 + 0.86, z1 - 0.08), t, vec3(1.5, 0.55, 0.15), cm);
		for (int i = 0; i < 4; i++) {   // Los cortes sobre la grilla
			float cx = xa + 0.2 + float(i) * (pw - 0.4) / 3.0;
			t = caja(ro, rd, vec3(cx - 0.13, y0 + 0.86, z0 + 0.25), vec3(cx + 0.13, y0 + 0.92, z1 - 0.25), t, c1, cm);
		}
		t = caja(ro, rd, vec3(xa - 0.05, y0 + 1.75, z0), vec3(xa + pw + 0.05, y0 + 1.95, z1 + 0.1), t, vec3(0.55, 0.56, 0.58), cm);
		// Y el mostrador del otro lado, cerca del vidrio
		float mw = min(1.6, med.x * 0.8);
		float xm = lado_m < 0.0 ? hx - 0.25 - mw : -hx + 0.25;
		t = caja(ro, rd, vec3(xm, y0, -1.55), vec3(xm + mw, y0 + 0.88, -0.95), t, mueble, cm);
		t = caja(ro, rd, vec3(xm - 0.04, y0 + 0.88, -1.6), vec3(xm + mw + 0.04, y0 + 0.95, -0.9), t, mueble * 1.2, cm);
	} else if (muebles == 2) {   // Un banco largo en el medio, para mirar los cuadros
		t = caja(ro, rd, vec3(-0.8, y0 + 0.38, -1.9), vec3(0.8, y0 + 0.46, -1.45), t, mueble * 1.1, cm);
		t = caja(ro, rd, vec3(-0.7, y0, -1.8), vec3(-0.6, y0 + 0.38, -1.55), t, mueble * 0.7, cm);
		t = caja(ro, rd, vec3(0.6, y0, -1.8), vec3(0.7, y0 + 0.38, -1.55), t, mueble * 0.7, cm);
	} else if (muebles == 3) {   // Sillones de barbero frente a los espejos (de los dos lados)
		for (int i = 0; i < 4; i++) {
			float s = i < 2 ? -1.0 : 1.0;
			float cz = -0.95 - 1.1 * float(i % 2) - (s > 0.0 ? 0.55 : 0.0);
			float cx = s * (hx - 0.85);
			t = caja(ro, rd, vec3(cx - 0.08, y0, cz - 0.08), vec3(cx + 0.08, y0 + 0.42, cz + 0.08), t, vec3(0.55, 0.57, 0.6), cm);
			t = caja(ro, rd, vec3(cx - 0.28, y0 + 0.42, cz - 0.28), vec3(cx + 0.28, y0 + 0.56, cz + 0.28), t, c1, cm);
			t = caja(ro, rd, vec3(cx + s * 0.22 - 0.06, y0 + 0.56, cz - 0.27), vec3(cx + s * 0.22 + 0.06, y0 + 1.25, cz + 0.27), t, c1 * 0.85, cm);
			t = caja(ro, rd, vec3(cx - 0.3, y0 + 0.56, cz - 0.3), vec3(cx + 0.3, y0 + 0.66, cz - 0.24), t, c1 * 0.7, cm);
			t = caja(ro, rd, vec3(cx - 0.3, y0 + 0.56, cz + 0.24), vec3(cx + 0.3, y0 + 0.66, cz + 0.3), t, c1 * 0.7, cm);
		}
	} else if (muebles == 4) {   // Banco: la línea de cajas al fondo y la fila con cordones
		float zc = -fondo + 1.0;
		t = caja(ro, rd, vec3(-hx, y0, zc - 0.25), vec3(hx, y0 + 1.05, zc + 0.25), t, mueble, cm);
		t = caja(ro, rd, vec3(-hx, y0 + 1.05, zc - 0.3), vec3(hx, y0 + 1.12, zc + 0.3), t, mueble * 1.3, cm);
		for (int i = 0; i < 3; i++) {
			float px = -0.9 + 0.9 * float(i);
			t = caja(ro, rd, vec3(px - 0.03, y0, -1.25), vec3(px + 0.03, y0 + 0.95, -1.19), t, c2, cm);
		}
		t = caja(ro, rd, vec3(-0.9, y0 + 0.8, -1.235), vec3(0.9, y0 + 0.84, -1.205), t, c1 * 0.8, cm);
	} else if (muebles == 5) {   // Dos escritorios con su computadora y su silla
		for (int i = 0; i < 2; i++) {
			float cx = (float(i) - 0.5) * hx;
			float cz = -1.7;
			t = caja(ro, rd, vec3(cx - 0.6, y0 + 0.72, cz - 0.32), vec3(cx + 0.6, y0 + 0.78, cz + 0.32), t, mueble * 1.15, cm);
			t = caja(ro, rd, vec3(cx - 0.58, y0, cz - 0.3), vec3(cx - 0.5, y0 + 0.72, cz + 0.3), t, mueble * 0.8, cm);
			t = caja(ro, rd, vec3(cx + 0.5, y0, cz - 0.3), vec3(cx + 0.58, y0 + 0.72, cz + 0.3), t, mueble * 0.8, cm);
			t = caja(ro, rd, vec3(cx - 0.25, y0 + 0.82, cz - 0.15), vec3(cx + 0.25, y0 + 1.15, cz - 0.11), t, c3 * 1.2, cm);
			t = caja(ro, rd, vec3(cx - 0.04, y0 + 0.78, cz - 0.12), vec3(cx + 0.04, y0 + 0.84, cz - 0.08), t, vec3(0.2), cm);
			t = caja(ro, rd, vec3(cx - 0.22, y0 + 0.42, cz + 0.45), vec3(cx + 0.22, y0 + 0.5, cz + 0.85), t, vec3(0.18, 0.19, 0.22), cm);
			t = caja(ro, rd, vec3(cx - 0.22, y0 + 0.5, cz + 0.8), vec3(cx + 0.22, y0 + 0.98, cz + 0.86), t, vec3(0.18, 0.19, 0.22), cm);
		}
	}
	if (t < t0) {
		col = cm;
		luz = 0.95;
	}
	// El banco: un vidrio arriba de las cajas, con parantes, que tiñe lo de atrás
	if (muebles == 4) {
		float zg = -fondo + 1.0;
		float tg = (zg - ro.z) / rd.z;
		vec3 pg = ro + rd * tg;
		if (tg > 0.0 && tg < t && pg.y > y0 + 1.12 && pg.y < y0 + 2.1) {
			col = fract((pg.x + hx) / 1.3) < 0.03 || pg.y > y0 + 2.05 ? mueble * 0.8 : mix(col, vec3(0.8, 0.9, 0.95), 0.3);
		}
	}
	// Más oscuro al fondo, y un reflejo leve del vidrio (más fuerte de costado)
	col *= luz * mix(1.0, 0.72, clamp((t * abs(rd.z)) / fondo, 0.0, 1.0));
	float refl = 0.1 + 0.35 * pow(1.0 - abs(rd.z), 4.0);
	return mix(col, vec3(0.62, 0.72, 0.82), refl);
}

void fragment() {
	// Los parantes de hierro de la vidriera (como los del kit, que quedan detrás de este plano junto
	// con la persiana: los locales con interior están abiertos)
	float al = 2.0 * medio.x + 0.2;
	float paso = al / max(2.0, floor(al / 1.6));
	float dp = mod(pos_l.x + al * 0.5 + 0.035, paso);
	ALBEDO = dp < 0.07 ? vec3(0.2, 0.21, 0.23) : interior(pos_l, cam_l, medio, semilla);
}
