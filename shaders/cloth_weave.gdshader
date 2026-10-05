// Production cloth: woven thread normal, sheen, hem dust, wear fade,
// seam piping darkening via UV edges, sweat darkening under load.
// Compatibility-safe PBR, works Forward+/Mobile.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(0.97, 0.95, 0.91, 1.0);
uniform vec4 accent : source_color = vec4(0.45, 0.10, 0.10, 1.0);
uniform float roughness_base = 0.85;
uniform float sheen_strength = 0.25;
uniform vec4 sheen_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float wear_amount = 0.3;
uniform float dirt_amount = 0.25;
uniform float border_accent = 0.0;
uniform vec2 weave_scale = vec2(28.0, 28.0);
uniform float sway_amount = 0.012;
uniform float sway_speed = 1.6;

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

void vertex() {
	// Believable cloth behavior: hem sway grows toward UV bottom (hem),
	// gentle wind + walk bob. Bone motion drives gross drape; this adds life.
	float hem_w = 1.0 - smoothstep(0.0, 0.85, UV.y);
	float sway = sin(TIME * sway_speed + VERTEX.x * 8.0 + VERTEX.z * 6.0) * sway_amount * hem_w;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
}

void fragment() {
	vec2 wuv = UV * weave_scale;
	// Plain-weave thread pattern.
	float thread_x = sin(wuv.x * 6.2831) * 0.5 + 0.5;
	float thread_y = sin(wuv.y * 6.2831) * 0.5 + 0.5;
	float weave = (thread_x * 0.5 + thread_y * 0.5 - 0.5);
	vec3 alb = albedo.rgb;
	// Border accent stripe near UV v edge (veshti kara / sash edge).
	if (border_accent > 0.01) {
		float edge = smoothstep(0.0, 0.06, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
		float stripe = (1.0 - edge);
		alb = mix(alb, accent.rgb, stripe * border_accent);
	}
	// Wear fade + patch variation.
	float wear_n = vnoise(UV * 7.0);
	alb = mix(alb, alb * 1.08 + vec3(0.03), wear_amount * wear_n * 0.6);
	// Hem dust: lower UV rows pick up laterite dust.
	float hem = (1.0 - smoothstep(0.0, 0.45, UV.y)) * dirt_amount;
	alb = mix(alb, vec3(0.45, 0.30, 0.18), hem * 0.55);
	// Sweat darkening in patches.
	float sweat = smoothstep(0.55, 0.9, vnoise(UV * 3.0 + 7.0)) * 0.25;
	alb *= 1.0 - sweat * 0.3;
	ALBEDO = alb;
	ROUGHNESS = clamp(roughness_base + weave * 0.08 - sweat * 0.2, 0.4, 1.0);
	SPECULAR = 0.35;
	vec3 n = normalize(NORMAL);
	n.xz += vec2(weave * 0.12, weave * 0.10);
	NORMAL = normalize(n);
	// Fabric sheen rim.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	EMISSION = sheen_color.rgb * fres * sheen_strength * 0.35;
	// Seam AO from vertex color.
	float seam_ao = clamp(COLOR.r * 1.1, 0.55, 1.0);
	AO = seam_ao;
	ALBEDO *= mix(0.8, 1.0, seam_ao);
}
