// Vegetation sway: wind wobble weighted upward. Stylized, cheap.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 tint : source_color = vec4(0.13, 0.42, 0.16, 1.0);
uniform float strength = 0.08;
uniform float speed = 1.8;
uniform sampler2D card_tex;
uniform bool use_card = false;

void vertex() {
	float w = clamp(VERTEX.y * 2.0 + 0.5, 0.0, 1.0);
	float sway = sin(TIME * speed + VERTEX.x * 0.5 + VERTEX.z * 0.5);
	VERTEX.x += sway * strength * w;
	VERTEX.z += cos(TIME * speed * 0.7 + VERTEX.x) * strength * 0.5 * w;
}

void fragment() {
	if (use_card) {
		vec4 c = texture(card_tex, UV);
		ALBEDO = c.rgb;
		ALPHA = c.a;
	} else {
		ALBEDO = tint.rgb;
	}
}
