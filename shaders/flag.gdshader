// Temple flag: wave grows toward the free edge. Defaults match the
// village TempleFlag (z extent +/-0.7); override per-flag via uniforms.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(0.66, 0.2, 0.15, 1.0);
uniform int edge_axis = 2;
uniform float edge_min = -0.7;
uniform float edge_span = 1.4;

void vertex() {
	float coord = VERTEX.z;
	if (edge_axis == 0) {
		coord = VERTEX.x;
	} else if (edge_axis == 1) {
		coord = VERTEX.y;
	}
	float edge = clamp((coord - edge_min) / edge_span, 0.0, 1.0);
	VERTEX.y += sin(TIME * 6.0 + coord * 4.0) * 0.16 * edge;
	VERTEX.x += cos(TIME * 4.0 + coord * 3.0) * 0.07 * edge;
}

void fragment() {
	ALBEDO = tint.rgb;
}
