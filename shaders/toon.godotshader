// Cel/toon core shared by fighters. Compatibility-safe: built-in toon
// lighting + fresnel rim into EMISSION. No custom light() tricks.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(0.58, 0.37, 0.24, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.45;

void fragment() {
	ALBEDO = albedo.rgb;
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fres * rim_strength;
}
