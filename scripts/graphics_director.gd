extends Node
# Central graphics brain. Every _put() write goes through renderer allowlists,
# so Forward+-only properties can never Invalid-set-index on Mobile/Compat.
# lighting_preset.gd owns sun/ambient/fog-density values for the day-night
# cycle; this owns tone mapping, grading, glow, fog shape, sky, and
# renderer-appropriate extras (SSAO/SSIL/SSR/SDFGI/volumetric tiers).
class_name GraphicsDirector

enum Preset { AUTO, ULTRA, HIGH, MOBILE }

@export var preset: Preset = Preset.AUTO

var _last_world_env: WorldEnvironment = null
var _last_renderer := ""

func _ready() -> void:
	# First-frame values arrive via _process on the first world scan.
	pass

func _process(_delta: float) -> void:
	var env_node := _find_world_environment()
	var renderer := ""
	if RenderingServer.has_method("get_current_rendering_method"):
		renderer = RenderingServer.get_current_rendering_method()
	if env_node != _last_world_env or renderer != _last_renderer:
		_last_world_env = env_node
		_last_renderer = renderer
		_apply(env_node, renderer)

func _find_world_environment() -> WorldEnvironment:
	var loader = get_tree().get_first_node_in_group("world")
	if loader == null or loader.get("current") == null:
		return null
	return loader.current.find_child("WorldEnv", true, false) as WorldEnvironment

func _put(env: Environment, prop: String, value) -> void:
	# Guarded write: only touches properties valid for the active renderer,
	# decided by explicit allowlists (never by probing the object).
	if prop in _always_ok():
		env.set(prop, value)
		return
	if _last_renderer == "forward_plus" and prop in _forward_only():
		env.set(prop, value)

static func _always_ok() -> Array:
	return ["tonemap_mode", "tonemap_exposure", "adjustment_enabled",
		"adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
		"glow_enabled", "glow_intensity", "glow_bloom", "glow_hdr_threshold",
		"glow_hdr_scale", "glow_strength", "glow_blend_mode", "fog_enabled",
		"fog_depth_begin", "fog_depth_end", "fog_aerial_perspective",
		"fog_sky_affect"]

static func _forward_only() -> Array:
	return ["tonemap_agx_contrast", "tonemap_agx_white",
		"ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_power",
		"ssao_detail", "ssao_sharpness",
		"ssil_enabled", "ssil_radius", "ssil_intensity", "ssil_sharpness",
		"ssr_enabled", "ssr_max_steps", "ssr_fade_in", "ssr_fade_out",
		"ssr_depth_tolerance",
		"sdfgi_enabled", "sdfgi_cascades", "sdfgi_max_distance",
		"sdfgi_energy", "sdfgi_normal_bias", "sdfgi_probe_bias",
		"sdfgi_use_occlusion", "sdfgi_read_sky_light",
		"volumetric_fog_enabled", "volumetric_fog_density",
		"volumetric_fog_albedo", "volumetric_fog_anisotropy",
		"volumetric_fog_length", "volumetric_fog_sky_affect",
		"volumetric_fog_temporal_reprojection_enabled",
		"volumetric_fog_temporal_reprojection_amount"]

func _apply(world_env: WorldEnvironment, renderer: String) -> void:
	if world_env == null:
		return
	var env: Environment = world_env.environment
	if env == null:
		return
	var forward_plus := renderer == "forward_plus"
	var mobile := renderer == "mobile"
	var ultra := false
	var high := false
	match preset:
		Preset.AUTO:
			ultra = forward_plus
			high = forward_plus
		Preset.ULTRA:
			ultra = forward_plus
		Preset.HIGH:
			high = forward_plus
		Preset.MOBILE:
			pass
	_ensure_sky(env)
	# Tonemapping (FILMIC baseline everywhere; AgX params Forward+-only).
	if forward_plus and ultra:
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		_put(env, "tonemap_agx_contrast", 1.15)
		_put(env, "tonemap_agx_white", 16.29)
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_put(env, "tonemap_exposure", 1.0)
	# Color grading.
	_put(env, "adjustment_enabled", true)
	_put(env, "adjustment_brightness", 1.0)
	_put(env, "adjustment_contrast", 1.08)
	_put(env, "adjustment_saturation", 1.05)
	# Glow (kept on all tiers, incl. Mobile).
	_put(env, "glow_enabled", true)
	_put(env, "glow_intensity", 0.65)
	_put(env, "glow_bloom", 0.08)
	_put(env, "glow_hdr_threshold", 1.4)
	_put(env, "glow_hdr_scale", 1.5)
	_put(env, "glow_strength", 0.85)
	_put(env, "glow_blend_mode", Environment.GLOW_BLEND_MODE_SCREEN)
	# Fog shape here; density/color stay owned by lighting_preset.gd.
	_put(env, "fog_enabled", true)
	_put(env, "fog_depth_begin", 18.0)
	_put(env, "fog_depth_end", 70.0)
	_put(env, "fog_aerial_perspective", 0.65)
	_put(env, "fog_sky_affect", 0.25)
	# Tiered extras: Ultra all-on; High SSAO+SSR; Mobile none.
	if forward_plus and (ultra or high):
		_put(env, "ssao_enabled", true)
		_put(env, "ssao_radius", 1.2)
		_put(env, "ssao_intensity", 1.45)
		_put(env, "ssao_power", 1.35)
		_put(env, "ssao_detail", 0.45)
		_put(env, "ssao_sharpness", 0.95)
		_put(env, "ssr_enabled", true)
		_put(env, "ssr_max_steps", 64)
		_put(env, "ssr_fade_in", 0.12)
		_put(env, "ssr_fade_out", 2.5)
		_put(env, "ssr_depth_tolerance", 0.35)
	if forward_plus and ultra:
		_put(env, "ssil_enabled", true)
		_put(env, "ssil_radius", 4.0)
		_put(env, "ssil_intensity", 0.8)
		_put(env, "ssil_sharpness", 0.95)
		_put(env, "sdfgi_enabled", true)
		_put(env, "sdfgi_cascades", 4)
		_put(env, "sdfgi_max_distance", 96.0)
		_put(env, "sdfgi_energy", 1.15)
		_put(env, "sdfgi_normal_bias", 1.05)
		_put(env, "sdfgi_probe_bias", 1.05)
		_put(env, "sdfgi_use_occlusion", true)
		_put(env, "sdfgi_read_sky_light", true)
		_put(env, "volumetric_fog_enabled", true)
		_put(env, "volumetric_fog_density", 0.006)
		_put(env, "volumetric_fog_albedo", Color(0.65, 0.72, 0.80))
		_put(env, "volumetric_fog_anisotropy", 0.15)
		_put(env, "volumetric_fog_length", 48.0)
		_put(env, "volumetric_fog_sky_affect", 0.8)
		_put(env, "volumetric_fog_temporal_reprojection_enabled", true)
		_put(env, "volumetric_fog_temporal_reprojection_amount", 0.85)
	if mobile:
		_put(env, "ssao_enabled", false)
		_put(env, "ssil_enabled", false)
		_put(env, "ssr_enabled", false)
		_put(env, "sdfgi_enabled", false)
		_put(env, "volumetric_fog_enabled", false)

func _ensure_sky(env: Environment) -> void:
	if env.sky != null:
		return
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.08, 0.25, 0.48)
	sky_material.sky_horizon_color = Color(0.75, 0.82, 0.92)
	sky_material.ground_bottom_color = Color(0.04, 0.035, 0.025)
	sky_material.ground_horizon_color = Color(0.43, 0.35, 0.27)
	sky_material.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	# NOTE: ambient_light_source intentionally untouched — lighting_preset.gd
	# owns ambient color/energy for the day-night cycle. Sky drives the
	# background (and reflections where supported) only.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
