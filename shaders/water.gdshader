// Backwater: 3-wave ripple, flow color, fresnel sheen, dual sparkle.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.16, 0.48, 0.55, 0.94);
uniform vec4 deep : source_color = vec4(0.025, 0.16, 0.24, 0.96);
uniform float wave_speed = 0.7;
uniform float wave_height = 0.035;
uniform float fresnel_strength = 0.65;

void vertex() {
	float t = TIME * wave_speed;
	float wave_a = sin(VERTEX.x * 2.1 + t) * wave_height;
	float wave_b = cos(VERTEX.z * 2.7 + t * 1.23) * wave_height * 0.7;
	float wave_c = sin((VERTEX.x + VERTEX.z) * 1.15 + t * 0.55) * wave_height * 0.45;
	VERTEX.y += wave_a + wave_b + wave_c;
}

void fragment() {
	float flow = 0.5 + 0.5 * sin(UV.x * 45.0 + TIME * 0.8);
	float sparkle = smoothstep(0.88, 1.0,
		sin(UV.x * 95.0 + TIME * 1.7) * sin(UV.y * 67.0 - TIME * 1.1));
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 5.0);
	vec3 water_color = mix(deep.rgb, shallow.rgb, flow);
	ALBEDO = water_color + vec3(0.05, 0.07, 0.08) * fresnel;
	EMISSION = vec3(0.55, 0.75, 0.85) * (sparkle * 0.22 + fresnel * fresnel_strength);
	ROUGHNESS = 0.12;
	METALLIC = 0.15;
	SPECULAR = 0.9;
	ALPHA = 0.92;
}
