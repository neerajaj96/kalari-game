// Hair: anisotropic-look strand shading via tangent-combed highlight,
// grey blend by age, root-dark / tip-light gradient, alpha-friendly.
// Opaque shells (no transparency sorting issues on Mobile).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_dark : source_color = vec4(0.09, 0.07, 0.06, 1.0);
uniform vec4 albedo_grey : source_color = vec4(0.75, 0.75, 0.78, 1.0);
uniform float grey_amount = 0.0;
uniform float roughness_base = 0.55;
uniform float strand_strength = 0.6;
uniform vec2 strand_scale = vec2(40.0, 8.0);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	// Combed strand streaks along V.
	float s = sin((UV.x * strand_scale.x + UV.y * strand_scale.y) * 6.2831);
	float streak = s * 0.5 + 0.5;
	float jitter = hash21(floor(UV * strand_scale) + 1.0);
	vec3 alb = mix(albedo_dark.rgb, albedo_grey.rgb, grey_amount * (0.5 + jitter * 0.5));
	// Root darker, tip lighter.
	alb *= mix(0.75, 1.15, UV.y);
	ALBEDO = alb;
	float rough = roughness_base + (streak - 0.5) * 0.25 * strand_strength;
	ROUGHNESS = clamp(rough, 0.3, 0.9);
	SPECULAR = 0.6;
	// Anisotropic-style highlight band.
	vec3 n = normalize(NORMAL);
	n.x += (streak - 0.5) * 0.35 * strand_strength;
	NORMAL = normalize(n);
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.5);
	EMISSION = vec3(0.9, 0.85, 0.75) * fres * 0.12;
}
