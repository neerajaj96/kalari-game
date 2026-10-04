// Animated backwater: vertex ripple + travelling sparkle. Alpha blended.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

uniform vec4 shallow : source_color = vec4(0.16, 0.42, 0.5, 0.88);
uniform vec4 deep : source_color = vec4(0.05, 0.2, 0.3, 0.9);
uniform float wave_speed = 1.2;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 2.0 + TIME * wave_speed) * 0.03
		+ cos(VERTEX.z * 2.5 + TIME * wave_speed * 1.3) * 0.03;
}

void fragment() {
	float sparkle = smoothstep(0.75, 1.0,
		sin(UV.x * 40.0 + TIME * 2.0) * sin(UV.y * 40.0 - TIME * 1.7));
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.5 + 0.5 * UV.x);
	EMISSION = vec3(0.9, 0.95, 1.0) * sparkle * 0.4;
	ALPHA = 0.88;
}
