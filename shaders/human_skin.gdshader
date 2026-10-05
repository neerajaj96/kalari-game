// Cinematic skin: PBR base + wrapped diffuse (soft wrap light) +
// fresnel SSS approximation into EMISSION + procedural pores/wrinkle
// detail normal perturb + cavity from vertex COLOR + sweat/sheen zones.
// Compatibility-safe: no custom light() function, works Forward+/Mobile.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.55, 0.35, 0.22, 1.0);
uniform vec4 albedo_deep : source_color = vec4(0.30, 0.18, 0.12, 1.0);
uniform float roughness_base = 0.55;
uniform float roughness_var = 0.25;
uniform vec4 sss_color : source_color = vec4(0.85, 0.35, 0.22, 1.0);
uniform float sss_strength = 0.35;
uniform float wrap_light = 0.45;
uniform float pore_strength = 0.35;
uniform float wrinkle_strength = 0.5;
uniform float melanin = 0.62;
uniform float age_wrinkle = 0.2;
uniform float scar_amount = 0.0;
uniform float mottle = 0.3;
uniform float stubble = 0.0;
uniform vec2 uv_scale = vec2(6.0, 6.0);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	// Large-scale tone variation (mottle, sun variation, age spots).
	float blotch = fbm(uv * 0.35);
	float fine = fbm(uv * 2.5);
	float pores = vnoise(uv * 14.0);
	vec3 alb = mix(albedo.rgb, albedo_deep.rgb, melanin * 0.45);
	alb *= 0.92 + blotch * 0.16;
	alb *= 1.0 - mottle * smoothstep(0.6, 0.9, fine) * 0.18;
	// Scar lightening streaks.
	float scar = smoothstep(0.75, 0.95, vnoise(vec2(uv.x * 0.5, uv.y * 3.0))) * scar_amount;
	alb = mix(alb, vec3(0.75, 0.6, 0.5), scar * 0.5);
	// Stubble shadow on jaw/upper-lip (head UV v ~0.65-0.95, all around).
	float jaw_zone = smoothstep(0.55, 0.75, UV.y) * (1.0 - smoothstep(0.96, 1.0, UV.y));
	float stub_n = vnoise(uv * 9.0);
	alb = mix(alb, alb * vec3(0.72, 0.70, 0.70), jaw_zone * stubble * (0.45 + stub_n * 0.55));
	ALBEDO = alb;
	// Roughness: T-zone/oily vs dry + pores + age + stubble.
	float rough = roughness_base + (fine - 0.5) * roughness_var;
	rough += (pores - 0.5) * 0.12 * pore_strength;
	rough += jaw_zone * stubble * 0.18;
	rough = clamp(rough, 0.25, 0.9);
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	// Detail normal: pores + fine wrinkles (forehead/crowfeet direction).
	vec3 n = normalize(NORMAL);
	float wr = (vnoise(vec2(uv.x * 3.0, uv.y * 9.0)) - 0.5) * wrinkle_strength * age_wrinkle;
	float po = (pores - 0.5) * pore_strength * 0.6;
	n.xz += vec2(wr + po, po * 0.7);
	NORMAL = normalize(n);
	// Cavity from vertex color (sculpt darkens creases) + AO.
	float cavity = clamp(COLOR.r * 1.15, 0.35, 1.0);
	AO = cavity;
	ALBEDO *= mix(0.72, 1.0, cavity);
	// Wrapped SSS approximation: fresnel rim in warm blood tone.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = sss_color.rgb * fres * sss_strength * (0.5 + wrap_light * 0.5);
}
