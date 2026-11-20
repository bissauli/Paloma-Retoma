shader_type spatial;
// Contorno de tinta del modo cómic (Inverted Hull). Lo pone autoload/estilo_comic.gd en el
// material_overlay de cada malla opaca: dibuja las caras de atrás del mesh infladas hacia afuera en
// pantalla, en color tinta, y lo que asoma alrededor del objeto es la línea.
// - Grosor constante en píxeles (escala con la resolución) que se afina de lejos.
// - Las mallas fusionadas (Construir.combinar) traen en CUSTOM0 normales suavizadas: en las
//   esquinas de las cajas todas las copias del vértice se inflan para el mismo lado y la línea no
//   se corta. Sin CUSTOM0 se usa NORMAL. En las mallas con esqueleto (palomas) CUSTOM0 trae el
//   centro de la malla con w = 2 y se infla desde ahí (ver EstiloComic._suavizar()).
// - Se empuja un poco hacia atrás (lejos de la cámara): así no asoma sobre el piso o la pared
//   que está pegada (las rayas entre losas de pasto o de vereda vecinas), sólo contra lo de atrás.
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled;

uniform vec4 color_tinta : source_color = vec4(0.07, 0.05, 0.12, 1.0);
// Grosor en píxeles a 1080 de alto.
uniform float grosor_px : hint_range(0.0, 8.0) = 2.6;
// Desde qué distancia se empieza a afinar y a cuál llega al mínimo.
uniform float afinar_desde = 25.0;
uniform float afinar_hasta = 160.0;
uniform float grosor_lejos : hint_range(0.0, 1.0) = 0.35;
// Cuánto se empuja hacia atrás, en fracción de la distancia a la cámara.
uniform float empuje : hint_range(0.0, 0.05) = 0.01;

global uniform float comic_activo;
global uniform vec4 cozy_cielo;

void vertex() {
	vec3 dir_obj = NORMAL;
	if (CUSTOM0.w > 1.5) {
		dir_obj = VERTEX - CUSTOM0.xyz;
	} else if (dot(CUSTOM0.xyz, CUSTOM0.xyz) > 0.01) {
		dir_obj = CUSTOM0.xyz;
	}
	vec3 pos_v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(pos_v);
	pos_v += pos_v / max(dist, 0.001) * dist * empuje;
	vec4 clip = PROJECTION_MATRIX * vec4(pos_v, 1.0);
	vec3 dir_v = mat3(MODELVIEW_MATRIX) * dir_obj;
	vec2 dir_clip = (PROJECTION_MATRIX * vec4(dir_v, 0.0)).xy;
	float largo = length(dir_clip);
	vec2 dir = largo > 1e-5 ? dir_clip / largo : vec2(0.0);
	float lejos = smoothstep(afinar_desde, afinar_hasta, dist);
	float px = grosor_px * VIEWPORT_SIZE.y / 1080.0 * mix(1.0, grosor_lejos, lejos) * comic_activo;
	// px en pantalla -> en clip (x2 porque NDC va de -1 a 1), por w para que no dependa de la distancia
	clip.xy += dir * px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	// De noche la tinta se aclara un poco hacia el color del cielo para no quedar como un agujero
	ALBEDO = color_tinta.rgb * mix(vec3(1.0), cozy_cielo.rgb, 0.5);
}
