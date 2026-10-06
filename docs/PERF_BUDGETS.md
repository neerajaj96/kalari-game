# Performance Budgets (ARM64 / Mobile renderer binding)

Measured analytically (see `tools/human_audit.py` §9); re-measure on device
with the PerfHUD benchmark (`Perf` settings button → 7 ksetra stations →
`user://benchmark.json`) before any release tag.

## Characters (cinematic pipeline)

| LOD | Tri budget | Notes |
|-----|-----------|-------|
| Hero | ≤ 18,000 (~10,000 current) | Caps, nails, lids, jewellery; shadows ON |
| Mid | ≤ 7,000 (~3,000 current) | Mitten hands, no jewellery; shadows ON |
| Far | ≤ 1,500 (~900 current) | Stubs; shadows OFF |

- LOD switch: 9 m / 22 m with 1 m hysteresis (`human_lod.gd`).
- Draws per character: ~20 visible segments (only active LOD draws).
- Mesh/material cache shared by DNA (`HumanFactory._mesh_cache`,
  `HumanMaterials._cache`): 14 DNA variants max, persists across world loads.
- Joint caps: Hero only (10 balls). Do NOT add caps to Mid/Far.

## Worlds

| Item | Budget | Current |
|------|--------|---------|
| Omni lights, village | ≤ 8, no shadows | 7, shadows explicitly off |
| Foliage village | 210 instances, 45 m cull | 150+30+20+10, culled |
| Ksetra instancing | one draw per set | via `_mmi` |
| Rain (mobile) | 80–150 particles | capped in `lighting_preset.gd` |
| Render scale (mobile) | 0.8 bilinear | `graphics_director.gd` |
| MSAA 3D | 2× (revisit if fill-bound) | `project.godot` |

## Audio (synth, no binaries)

- Beds: 8 kHz mono loops (~32 KB each). One-shots ≤ 1.5 s. No Music/SFX bus
  split yet — adding buses is runtime-gated (silence risk without device test).

## Rules for future work

1. No new per-frame `load()` (cache or preload; `sway_leaf`/`water_fx` writes
   reuse the loaded resource).
2. No `amount` reallocs per frame (rain uses step compare).
3. No transparency additions on mobile paths without a device fps check
   (water `blend_mix` + glow + MSAA2x already dominate fill-rate).
4. Lighting writes stay 2 Hz throttled (`lighting_preset.gd`).
