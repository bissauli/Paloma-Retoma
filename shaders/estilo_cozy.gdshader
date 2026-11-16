shader_type spatial;
// Estilo cozy de caricatura limpia: cel suave, sombras teñidas (no grises), rim sutil y
// degradado vertical opcional. Sirve para personajes, edificios, árboles y props.
// Pensado para GL Compatibility (web y teléfono): sin ramas caras y como mucho una lectura de
// textura (opcional). La luz, el tinte y el rim están en estilo_cozy_luz.gdshaderinc.
// Ver shaders/README_estilo_cozy.md.

render_mode blend_mix, depth_draw_opaque, cull_back;

group_uniforms estilo;
uniform vec4 color_base : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Opcional: si no se asigna vale blanco y no cambia nada. Una sola lectura.
uniform sampler2D textura_albedo : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Atlas de colores (la paleta del Kit): filtro lineal simple, sin mipmaps ni anisotrópico, para que
// las celdas vecinas no se mezclen de lejos. Si usar_paleta está activo se lee esta en vez de
// textura_albedo (sigue siendo una sola lectura).
uniform bool usar_paleta = false;
uniform sampler2D textura_paleta : source_color, hint_default_white, filter_linear, repeat_disable;
// Emisión por textura (faroles, faros y semáforos del Kit). Apagada no se lee.
uniform bool usar_textura_emision = false;
uniform sampler2D textura_emision : source_color, hint_default_black, filter_linear, repeat_enable;
uniform float emision_energia = 1.0;
// Multiplica por el color de los vértices (mallas fusionadas, personas, autos).
uniform bool usar_color_vertices = false;
// La textura se proyecta con la posición en el mundo (en el plano que más mira la cara), en vez
// de usar las UV del mesh: baldosas que siguen de una pieza a otra. Sigue siendo una lectura.
uniform bool usar_uv_mundo = false;
uniform vec2 escala_uv_mundo = vec2(1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.1;

group_uniforms degradado;
uniform bool usar_degradado = false;
uniform vec4 degradado_arriba : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform vec4 degradado_abajo : source_color = vec4(0.74, 0.72, 0.86, 1.0);
uniform float degradado_altura_min = 0.0;
uniform float degradado_altura_max = 2.0;
uniform bool usar_altura_mundial = false;
uniform float degradado_fuerza : hint_range(0.0, 1.0) = 0.6;
group_uniforms;

#include "res://shaders/estilo_cozy_luz.gdshaderinc"

varying vec3 pos_mundo;
varying vec3 pos_local;
varying vec3 normal_mundo;

void vertex() {
	pos_local = VERTEX;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	if (usar_uv_mundo) {
		vec3 n = abs(normal_mundo);
		vec2 plano = n.y >= max(n.x, n.z) ? pos_mundo.xz : (n.x >= n.z ? pos_mundo.zy : pos_mundo.xy);
		uv = plano * escala_uv_mundo;
	}
	vec3 tex = usar_paleta ? texture(textura_paleta, uv).rgb : texture(textura_albedo, uv).rgb;
	vec3 albedo = color_base.rgb * tex;

	if (usar_color_vertices) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		// En Compatibility ALBEDO va en sRGB, igual que los colores de vértice que arma el juego.
		albedo *= COLOR.rgb;
#else
		albedo *= pow(COLOR.rgb, vec3(2.2));
#endif
	}

	if (usar_degradado) {
		float h = usar_altura_mundial ? pos_mundo.y : pos_local.y;
		float rango = max(degradado_altura_max - degradado_altura_min, 0.0001);
		float t = clamp((h - degradado_altura_min) / rango, 0.0, 1.0);
		vec3 grad = mix(degradado_abajo.rgb, degradado_arriba.rgb, t);
		// Multiplicativo: el degradado matiza el color del objeto sin reemplazarlo.
		albedo = mix(albedo, albedo * grad, degradado_fuerza);
	}

	ALBEDO = albedo;
	METALLIC = 0.0;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	COZY_FRAGMENT;
	if (usar_textura_emision) {
		EMISSION += texture(textura_emision, uv).rgb * emision_energia;
	}
}
