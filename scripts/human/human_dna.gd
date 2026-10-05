extends Resource
# HumanDNA: deterministic identity description for one cinematic human.
# Original faces only (no celebrity likeness). Seeded RNG gives villagers
# strong variation while hero characters stay art-directed and stable.
class_name HumanDNA

@export var seed: int = 1
@export var label: String = "villager"
@export var is_female: bool = false
@export var age_years: float = 28.0
# Body canon (meters, 7.5-head based). stature scales all bones uniformly.
@export var stature: float = 1.70
@export var build: float = 0.5 # 0 lean .. 1 heavy/stocky
@export var shoulder_width: float = 0.44
@export var hip_width: float = 0.34
@export var belly: float = 0.15 # 0 flat .. 1 prominent
@export var muscle: float = 0.55 # 0 soft .. 1 defined Kalari athlete
@export var posture_crouch: float = 0.0 # 0 upright .. 1 elder stoop
# Skin: Kerala brown range + variation. melanin drives shader albedo pick.
@export var melanin: float = 0.62 # 0 fair .. 1 deep brown
@export var skin_warm: float = 0.55
@export var skin_mottle: float = 0.35 # freckle/mole/patch amount
@export var scar_amount: float = 0.0
@export var wrinkle: float = 0.15 # 0 youth .. 1 elder
# Face identity params (-1..1 around population mean).
@export var jaw_width: float = 0.0
@export var jaw_angle: float = 0.0
@export var cheek_full: float = 0.0
@export var cheek_bone: float = 0.2
@export var brow_ridge: float = 0.2
@export var brow_angle: float = 0.0
@export var nose_length: float = 0.0
@export var nose_width: float = 0.2
@export var nose_tip: float = 0.1
@export var lip_full: float = 0.0
@export var chin_proj: float = 0.0
@export var eye_set: float = 0.0 # wide(-)..close(+)
@export var eye_depth: float = 0.1
@export var ear_size: float = 0.0
# Hair / facial hair.
@export var hair_style: int = 0 # 0 kuduma knot, 1 short crop, 2 headwrap, 3 long tie, 4 shaven, 5 bun+sari cover
@export var hair_grey: float = 0.0
@export var beard_style: int = 0 # 0 none, 1 stubble, 2 moustache, 3 full short, 4 full grey elder
@export var brow_thick: float = 0.6
# Garment + adornment.
@export var garment_set: int = 0 # 0 kalari kaccha, 1 veshti+angavastram, 2 lungi+sash, 3 sari, 4 kurta, 5 priest white
@export var cloth_primary: Color = Color(0.97, 0.95, 0.91, 1.0)
@export var cloth_accent: Color = Color(0.45, 0.10, 0.10, 1.0)
@export var cloth_wear: float = 0.3 # fading/patches
@export var cloth_dirt: float = 0.25 # hem dust
@export var jewellery: int = 0 # bitmask: 1 earring 2 necklace 4 bangle 8 anklet 16 thread
# Gait / posture character.
@export var gait_sway: float = 0.5
@export var gait_bounce: float = 0.5
@export var idle_energy: float = 0.5

static func _base(s: int, label_: String) -> HumanDNA:
	var d := HumanDNA.new()
	d.seed = s
	d.label = label_
	return d

static func player_dna() -> HumanDNA:
	var d := _base(101, "player")
	d.age_years = 22.0
	d.stature = 1.72
	d.build = 0.55
	d.shoulder_width = 0.46
	d.hip_width = 0.33
	d.belly = 0.05
	d.muscle = 0.78
	d.melanin = 0.60
	d.skin_warm = 0.58
	d.skin_mottle = 0.25
	d.scar_amount = 0.10
	d.wrinkle = 0.05
	d.jaw_width = 0.15
	d.jaw_angle = 0.20
	d.cheek_full = -0.10
	d.cheek_bone = 0.35
	d.brow_ridge = 0.30
	d.nose_length = 0.10
	d.nose_width = 0.15
	d.nose_tip = 0.15
	d.lip_full = -0.05
	d.chin_proj = 0.10
	d.hair_style = 0
	d.hair_grey = 0.0
	d.beard_style = 0
	d.brow_thick = 0.65
	d.garment_set = 0
	d.cloth_primary = Color(0.97, 0.95, 0.91, 1.0)
	d.cloth_accent = Color(0.45, 0.10, 0.10, 1.0)
	d.cloth_wear = 0.20
	d.cloth_dirt = 0.35
	d.jewellery = 0
	d.gait_sway = 0.35
	d.gait_bounce = 0.65
	d.idle_energy = 0.75
	return d

static func gurukkal_dna() -> HumanDNA:
	var d := _base(202, "gurukkal")
	d.age_years = 66.0
	d.stature = 1.68
	d.build = 0.38
	d.shoulder_width = 0.43
	d.hip_width = 0.34
	d.belly = 0.30
	d.muscle = 0.35
	d.posture_crouch = 0.35
	d.melanin = 0.64
	d.skin_warm = 0.50
	d.skin_mottle = 0.55
	d.scar_amount = 0.15
	d.wrinkle = 0.85
	d.jaw_width = -0.10
	d.cheek_full = -0.25
	d.cheek_bone = 0.45
	d.brow_ridge = 0.45
	d.brow_angle = 0.15
	d.nose_length = 0.25
	d.nose_width = 0.30
	d.lip_full = -0.30
	d.chin_proj = 0.05
	d.eye_depth = 0.25
	d.hair_style = 2
	d.hair_grey = 0.95
	d.beard_style = 4
	d.brow_thick = 0.80
	d.garment_set = 1
	d.cloth_primary = Color(0.96, 0.94, 0.89, 1.0)
	d.cloth_accent = Color(0.83, 0.63, 0.09, 1.0)
	d.cloth_wear = 0.15
	d.cloth_dirt = 0.15
	d.jewellery = 16 | 2
	d.gait_sway = 0.55
	d.gait_bounce = 0.25
	d.idle_energy = 0.30
	return d

static func bandit_dna(variant: int) -> HumanDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + variant
	var d := _base(300 + variant, "bandit_%d" % variant)
	d.age_years = rng.randf_range(28.0, 44.0)
	d.stature = rng.randf_range(1.70, 1.84)
	d.build = rng.randf_range(0.62, 0.92)
	d.shoulder_width = rng.randf_range(0.46, 0.52)
	d.hip_width = rng.randf_range(0.34, 0.38)
	d.belly = rng.randf_range(0.25, 0.60)
	d.muscle = rng.randf_range(0.55, 0.85)
	d.melanin = rng.randf_range(0.55, 0.75)
	d.skin_mottle = rng.randf_range(0.3, 0.6)
	d.scar_amount = rng.randf_range(0.35, 0.85)
	d.wrinkle = rng.randf_range(0.15, 0.45)
	d.jaw_width = rng.randf_range(0.1, 0.55)
	d.jaw_angle = rng.randf_range(0.0, 0.4)
	d.cheek_full = rng.randf_range(-0.1, 0.35)
	d.cheek_bone = rng.randf_range(0.1, 0.5)
	d.brow_ridge = rng.randf_range(0.3, 0.7)
	d.brow_angle = rng.randf_range(-0.35, -0.05)
	d.nose_length = rng.randf_range(-0.1, 0.35)
	d.nose_width = rng.randf_range(0.2, 0.6)
	d.lip_full = rng.randf_range(-0.2, 0.2)
	d.eye_set = rng.randf_range(-0.2, 0.2)
	d.hair_style = [1, 1, 3, 4][variant % 4]
	d.hair_grey = rng.randf_range(0.0, 0.25)
	d.beard_style = [2, 1, 3, 2][variant % 4]
	d.brow_thick = rng.randf_range(0.65, 0.95)
	d.garment_set = 2
	var palettes: Array = [
		[Color(0.25, 0.18, 0.14, 1.0), Color(0.45, 0.10, 0.10, 1.0)],
		[Color(0.20, 0.22, 0.18, 1.0), Color(0.55, 0.35, 0.12, 1.0)],
		[Color(0.30, 0.16, 0.12, 1.0), Color(0.15, 0.15, 0.15, 1.0)],
		[Color(0.22, 0.20, 0.26, 1.0), Color(0.45, 0.10, 0.10, 1.0)],
	]
	var pal: Array = palettes[variant % palettes.size()]
	d.cloth_primary = pal[0]
	d.cloth_accent = pal[1]
	d.cloth_wear = rng.randf_range(0.5, 0.85)
	d.cloth_dirt = rng.randf_range(0.5, 0.9)
	d.jewellery = 0
	d.gait_sway = rng.randf_range(0.55, 0.85)
	d.gait_bounce = rng.randf_range(0.45, 0.7)
	d.idle_energy = rng.randf_range(0.5, 0.8)
	return d

static func villager_dna(seed_: int) -> HumanDNA:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_
	var d := _base(1000 + seed_, "villager_%d" % seed_)
	d.is_female = (seed_ % 3 == 1)
	d.age_years = rng.randf_range(18.0, 68.0)
	var fem_scale := 0.94 if d.is_female else 1.0
	d.stature = rng.randf_range(1.55, 1.75) * fem_scale
	d.build = rng.randf_range(0.25, 0.75)
	d.shoulder_width = rng.randf_range(0.38, 0.48) * (0.88 if d.is_female else 1.0)
	d.hip_width = rng.randf_range(0.32, 0.40) * (1.12 if d.is_female else 1.0)
	d.belly = rng.randf_range(0.05, 0.55)
	d.muscle = rng.randf_range(0.2, 0.6)
	d.posture_crouch = clampf((d.age_years - 50.0) / 60.0, 0.0, 0.5)
	d.melanin = rng.randf_range(0.48, 0.74)
	d.skin_warm = rng.randf_range(0.45, 0.65)
	d.skin_mottle = rng.randf_range(0.2, 0.6)
	d.scar_amount = rng.randf_range(0.0, 0.3)
	d.wrinkle = clampf((d.age_years - 25.0) / 55.0, 0.0, 1.0)
	d.jaw_width = rng.randf_range(-0.4, 0.4)
	d.jaw_angle = rng.randf_range(-0.2, 0.3)
	d.cheek_full = rng.randf_range(-0.3, 0.4)
	d.cheek_bone = rng.randf_range(-0.1, 0.5)
	d.brow_ridge = rng.randf_range(-0.1, 0.5)
	d.nose_length = rng.randf_range(-0.3, 0.3)
	d.nose_width = rng.randf_range(-0.1, 0.5)
	d.nose_tip = rng.randf_range(-0.2, 0.3)
	d.lip_full = rng.randf_range(-0.2, 0.45) + (0.15 if d.is_female else 0.0)
	d.chin_proj = rng.randf_range(-0.2, 0.2)
	d.eye_set = rng.randf_range(-0.3, 0.3)
	d.eye_depth = rng.randf_range(-0.1, 0.3)
	d.ear_size = rng.randf_range(-0.2, 0.3)
	if d.is_female:
		d.hair_style = 5 if rng.randf() < 0.6 else 3
		d.beard_style = 0
	else:
		d.hair_style = [0, 1, 1, 3, 4][seed_ % 5]
		d.beard_style = [0, 0, 1, 2, 3][seed_ % 5]
	d.hair_grey = clampf((d.age_years - 40.0) / 40.0, 0.0, 1.0)
	d.brow_thick = rng.randf_range(0.4, 0.85)
	var gset := 3 if d.is_female else [1, 2, 2, 4, 1][seed_ % 5]
	# Elder priest figure for one seed.
	if seed_ == 0:
		gset = 5
	d.garment_set = gset
	var cloths: Array = [
		Color(0.97, 0.95, 0.91, 1.0), Color(0.85, 0.55, 0.20, 1.0),
		Color(0.20, 0.45, 0.35, 1.0), Color(0.55, 0.15, 0.35, 1.0),
		Color(0.25, 0.35, 0.65, 1.0), Color(0.80, 0.75, 0.60, 1.0),
	]
	d.cloth_primary = cloths[seed_ % cloths.size()]
	d.cloth_accent = cloths[(seed_ + 3) % cloths.size()]
	d.cloth_wear = rng.randf_range(0.2, 0.7)
	d.cloth_dirt = rng.randf_range(0.15, 0.6)
	var j := 0
	if d.is_female:
		j = 1 | 2 | 4 | 8
	elif seed_ % 4 == 0:
		j = 16
	d.jewellery = j
	d.gait_sway = rng.randf_range(0.3, 0.7)
	d.gait_bounce = rng.randf_range(0.25, 0.6)
	d.idle_energy = rng.randf_range(0.25, 0.6)
	return d
