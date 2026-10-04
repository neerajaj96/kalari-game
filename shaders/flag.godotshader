// Temple flag: wave grows toward the free edge. Box z extent +/-0.7.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 tint : source_color = vec4(0.66, 0.2, 0.15, 1.0);

void vertex() {
	float edge = clamp((VERTEX.z + 0.7) / 1.4, 0.0, 1.0);
	VERTEX.y += sin(TIME * 6.0 + VERTEX.z * 4.0) * 0.12 * edge;
	VERTEX.x += cos(TIME * 4.0 + VERTEX.z * 3.0) * 0.05 * edge;
}

void fragment() {
	ALBEDO = tint.rgb;
}
