shader_type spatial;
// Recolorea la paloma por zonas conservando el sombreado pixel-art de la textura.
// "zonas" es una máscara de un canal (ver tools/generar_mascara_paloma.gd): el valor * 255 es el
// índice de zona (0 = sin zona, 1 cuerpo, 2 alas, 3 cabeza, 4 cola, 5 pico, 6 patas).
// "paleta" tiene el color de cada zona (en lineal) y "luz_base" la luminancia media original de la zona:
// el texel se escala por (su luminancia / la media de su zona), así las plumas claras y oscuras siguen
// siéndolo. Una sola lectura extra de textura, sin discard ni ramas caras: va bien en web y teléfono.

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D zonas : filter_nearest, repeat_disable;
uniform vec3 paleta[7];
uniform float luz_base[7];
uniform float activa[7];   // 1.0 = la zona usa su color; 0.0 = conserva el original
// Pintura libre del modo avanzado: misma grilla que la textura, alfa 0 = sin pintar.
// Va encima del color de zona, texel por texel (filter_nearest: sigue siendo pixel-art).
uniform sampler2D pintura : source_color, filter_nearest, repeat_disable;

// Luz cozy (cel suave, sombra teñida y rim), la misma del resto del mundo.
#include "res://shaders/estilo_cozy_luz.gdshaderinc"

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	int z = int(texture(zonas, UV).r * 255.0 + 0.5);
	z = clamp(z, 0, 6);
	float l = dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 tono = clamp(paleta[z] * (l / max(luz_base[z], 0.001)), 0.0, 1.0);
	vec4 p = texture(pintura, UV);
	ALBEDO = mix(mix(base, tono, activa[z]), p.rgb, p.a);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	COZY_FRAGMENT;
}
