shader_type spatial;
// El agua de las fuentes y los charcos: un color translúcido que sigue la luz del cielo. Sin luz del
// motor a propósito: cada material iluminado distinto son segundos de compilación de shaders en la web.
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back;

uniform vec4 color : source_color = vec4(0.4, 0.78, 0.93, 0.62);
uniform vec3 brillo : source_color = vec3(0.04, 0.1, 0.14);   // Para que no se apague en la sombra

// Luz del cielo (la maneja world/cielo.gd): de noche el agua también se oscurece
global uniform vec4 cozy_cielo;

void fragment() {
	ALBEDO = (color.rgb + brillo) * cozy_cielo.rgb;
	ALPHA = color.a;
}
