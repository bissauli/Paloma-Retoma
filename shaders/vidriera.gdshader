shader_type spatial;
render_mode unshaded, cull_back;
// El interior de un local visto por su vidriera (ver world/vidrieras.gd), sin geometría: el plano de la
// vidriera calcula por dónde sale el rayo de la cámara de una caja (el local) que está DETRÁS del vidrio
// y pinta lo que toca: el piso, el cielorraso con su luz, las paredes con los estantes y la mercadería
// del rubro, y un mostrador. Así tiene profundidad de verdad (se ve distinto desde cada ángulo) y no
// hace falta ahuecar los edificios del kit.
// El tamaño sale del propio plano (un QuadMesh centrado): cada vértice está en una esquina.

uniform vec3 pared : source_color = vec3(0.95, 0.92, 0.85);
uniform vec3 piso : source_color = vec3(0.75, 0.72, 0.68);
uniform vec3 mueble : source_color = vec3(0.55, 0.36, 0.22);
uniform vec3 c1 : source_color = vec3(0.85, 0.25, 0.2);
uniform vec3 c2 : source_color = vec3(0.95, 0.8, 0.25);
uniform vec3 c3 : source_color = vec3(0.25, 0.5, 0.85);
uniform vec3 c4 : source_color = vec3(0.3, 0.7, 0.35);
// 0 cajas, 1 redondos, 2 ropa colgada, 3 botellas, 4 libros, 5 lavarropas, 6 cuadros/espejos
uniform int forma = 0;
uniform float filas = 4.0;      // Cuántos estantes
uniform float celda = 0.3;      // Ancho de cada cosa del estante
uniform float fondo = 3.2;      // Profundidad del local
uniform float bajo = 0.5;       // Del borde de abajo del vidrio al piso del local

varying vec3 pos_l;
varying vec3 cam_l;
varying vec2 medio;   // Medio ancho y medio alto del vidrio
varying float semilla;

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

// Una pared con estantes: "u" a lo largo de la pared, "v" la altura sobre el piso
vec3 estantes(float u, float v, float lado, float sem) {
	vec3 col = pared;
	if (v < 0.12) {
		return mueble * 0.6;   // Zócalo
	}
	if (forma == 6) {   // Cuadros (o espejos) colgados, uno al lado del otro
		float cw = 1.5;
		float fu = fract(u / cw);
		float h = azar(vec3(floor(u / cw), lado, sem));
		if (fu > 0.12 && fu < 0.88 && v > 1.05 && v < 2.15) {
			if (fu < 0.16 || fu > 0.84 || v < 1.1 || v > 2.1) {
				return mueble;
			}
			return color_de(h) * (0.9 + 0.1 * v);
		}
		if (v < 0.9 && fu > 0.08 && fu < 0.92) {   // Mueble bajo
			return v > 0.84 ? mueble * 1.15 : mueble * (fract(u / 0.75) < 0.03 ? 0.7 : 0.95);
		}
		return col;
	}
	bool ropa = forma == 2;
	bool lava = forma == 5;
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
	if (!ropa && !lava && fract(u / 1.2) < 0.025) {
		return mueble * 0.75;   // Parantes
	}
	if (!ropa && !lava && fv < 0.07) {
		return mueble * 0.9;    // Tabla del estante
	}
	float ci = floor(u / celda);
	float fu = fract(u / celda);
	float h = azar(vec3(ci, r + lado * 7.0, sem));
	float h2 = azar(vec3(ci + 31.0, r, sem + lado));
	if (h2 < 0.12 && !lava) {
		return col;   // Un hueco en el estante
	}
	vec3 cosa = color_de(h) * (0.85 + 0.25 * h2);
	if (forma == 0) {   // Cajas y paquetes
		if (fu > 0.07 && fu < 0.93 && fv < 0.07 + (0.45 + 0.45 * h2) * 0.85) {
			return fv > 0.07 + (0.45 + 0.45 * h2) * 0.6 ? cosa * 1.15 : cosa;
		}
	} else if (forma == 1) {   // Frutas, panes, flores, ovillos (de a dos, uno arriba del otro)
		float rad = celda * 0.42;
		vec2 d = vec2((fu - 0.5) * celda, (fv - 0.07) * rh - rad);
		vec2 d2 = vec2((fract(u / celda + 0.5) - 0.5) * celda, (fv - 0.07) * rh - rad * 2.6);
		if (length(d) < rad) {
			return cosa * (1.05 - 0.4 * length(d) / rad);
		}
		if (length(d2) < rad * 0.9) {
			vec3 o = color_de(azar(vec3(ci + 5.0, r, sem)));
			return o * (1.0 - 0.35 * length(d2) / rad);
		}
	} else if (ropa) {   // Percheros con ropa colgada
		if (fv > 0.88 && fv < 0.91) {
			return vec3(0.6);
		}
		float largo = 0.4 + 0.35 * h2;
		if (fu > 0.12 && fu < 0.88 && fv < 0.88 && fv > 0.88 - largo) {
			bool manga = fv > 0.88 - 0.18 && (fu < 0.2 || fu > 0.8);
			return manga ? cosa * 0.85 : cosa;
		}
	} else if (forma == 3) {   // Botellas y frascos
		if ((fu > 0.28 && fu < 0.72 && fv > 0.07 && fv < 0.62) || (fu > 0.43 && fu < 0.57 && fv < 0.82)) {
			return cosa * (fu > 0.36 && fu < 0.44 ? 1.4 : 1.0);
		}
	} else if (forma == 4) {   // Libros, carpetas o discos de canto
		if (fu > 0.05 && fu < 0.95 && fv < 0.07 + 0.55 + 0.33 * h2) {
			return cosa;
		}
	} else if (lava) {   // Lavarropas en fila, con la puerta redonda
		vec2 d = vec2((fu - 0.5) * celda, fv * rh - rh * 0.48);
		if (fu > 0.05 && fu < 0.95 && fv < 0.92) {
			float lr = length(d);
			if (lr < celda * 0.3) {
				return lr > celda * 0.24 ? vec3(0.55) : vec3(0.35, 0.45, 0.55) + 0.25 * h;
			}
			return c1 * (fv > 0.82 ? 0.85 : 1.0);
		}
	}
	return col;
}

vec3 interior(vec3 pos, vec3 cam, vec2 med, float sem) {
	vec3 ro = pos;
	vec3 rd = normalize(pos - cam);
	rd.z = min(rd.z, -0.0005);
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
		col = estantes(p.x + hx, p.y - y0, 0.0, sem);
		luz = 0.95;
	} else if (t == tm.x) {   // Paredes de los costados
		col = estantes(-p.z, p.y - y0, sign(p.x), sem);
		luz = 0.8;
	} else if (rd.y < 0.0) {   // Piso de baldosas
		float k = mod(floor(p.x / 0.5) + floor(p.z / 0.5), 2.0);
		col = piso * (k > 0.5 ? 1.0 : 0.88);
		luz = 0.78;
	} else {   // Cielorraso con una fila de luces
		bool tubo = abs(p.x) < 0.12 && fract(p.z / 1.1) < 0.7;
		col = tubo ? vec3(1.6, 1.55, 1.4) : pared * 0.95;
		luz = 1.0;
	}
	// El mostrador: una caja baja contra un costado, cerca del vidrio
	float mw = min(1.9, med.x * 0.9);
	float lado_m = sem < 0.5 ? -1.0 : 1.0;
	vec3 mlo = vec3(lado_m < 0.0 ? -hx + 0.25 : hx - 0.25 - mw, y0, -1.55);
	vec3 mhi = vec3(lado_m < 0.0 ? -hx + 0.25 + mw : hx - 0.25, y0 + 0.95, -0.95);
	vec3 ma = (mlo - ro) / rd;
	vec3 mb = (mhi - ro) / rd;
	vec3 mn = min(ma, mb);
	vec3 mx = max(ma, mb);
	float te = max(max(mn.x, mn.y), mn.z);
	float ts = min(min(mx.x, mx.y), mx.z);
	if (te < ts && te > 0.0 && te < t) {
		t = te;
		if (te == mn.y) {
			col = mueble * 1.25;   // La tapa
			luz = 1.0;
		} else {
			col = mueble * (te == mn.z ? 1.0 : 0.8);
			p = ro + rd * te;
			if (p.y - y0 > 0.86) {
				col = mueble * 1.2;   // El borde de la tapa
			}
			luz = 0.9;
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
