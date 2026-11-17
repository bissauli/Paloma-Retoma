shader_type spatial;
// Luces falsas de la noche (faroles, ventanas, faros de autos): quads aditivos sin luz real, sin sombras y
// sin lecturas de pantalla. "luces_noche" (0 de día, 1 de noche) la pone LucesNoche.poner_noche en todos
// los materiales, según la hora de world/cielo.gd. Modos: 0 = destello que mira a la cámara, 1 = ventana
// encendida, 2 = charco de luz en el piso o haz de los faros.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float luces_noche = 0.0;
uniform int modo = 0;
uniform float intensidad = 1.0;
uniform vec4 tinte : source_color = vec4(1.0);

varying vec4 col;

void vertex() {
	col = COLOR;
	if (modo == 0) {
		mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		m = m * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a;
	if (modo == 1) {
		vec2 q = abs(p);
		a = smoothstep(1.0, 0.7, max(q.x, q.y)) * 0.85;
	} else if (modo == 0) {
		a = pow(clamp(1.0 - length(p), 0.0, 1.0), 2.2);
	} else {
		a = pow(clamp(1.0 - length(p), 0.0, 1.0), 1.5);
	}
	ALBEDO = col.rgb * tinte.rgb * a * col.a * tinte.a * luces_noche * intensidad;
}
