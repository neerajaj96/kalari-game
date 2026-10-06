# Validation Run — v0.30.0-cinematic baseline

Started: 2026-10-06 (UTC). Validator: build agent, sandbox without GPU.
Baseline commit: `v0.30.0-cinematic` tag on `main`.

## Tier 0 — STATIC: PASS

- `tools/check.py`: CHECK OK (only known WARN: x86_64 preset off).
- `tools/human_audit.py`: HUMAN AUDIT OK (hero ~10020 / mid ~3050 / far ~910).
- `tools/balance.py`: BALANCE OK (rank pacing intact).
- All `data/*.json` parse.
- Headless-script/API cross-check: every static called by
  `tools/hero_audit_headless.gd` exists; every mesh builder used by
  `human_factory.gd` exists; every runtime `load()` target exists.
- Audit-harness timeline simulated: 40 s auto-quit provably visits all
  3 views, 8 poses, 8 expressions and LOD pins auto/hero/mid/far.
- No `//` comments, no CRLF/BOM, no missing trailing newlines (54 GD files).

Static proves CONSTRUCTION ONLY. No visual claim.

## Tier 1 — HEADLESS: PASS (with fixes)

- `Godot_v4.6.3-stable_linux.arm64` installed locally (official 4.6.3).
- `--editor --quit` and `--import` SEGFAULT in this container (proot
  environment); editor import unavailable, so no `.godot` class cache.
  CI (GitHub runners) is unaffected — this is a sandbox limitation.
- Game-mode headless (`--headless --path . --quit`) WORKS and became the
  real GDScript compiler. Full boot (main → school → player → HUD) is
  error-free.
- `tools/hero_audit_headless.gd` (`-s`): DNA, 42 bones, 25 meshes — OK.
- Audit scene 40 s self-cycle: all views/poses/expressions/LOD-pins — OK.

### Defects found by real engine parsing (all fixed, commit `125f6e9`)

| ID | Severity | Defect | Fix |
|----|----------|--------|-----|
| H1 | P0 | `Array.reversed()` does not exist → dialogue briefings failed to parse (quest briefings dead) | `duplicate()` + `reverse()` |
| H2 | P0 | `mesh_builder.gd` indent corruption from an earlier edit: `noisy_ground` tri calls outside loop (`a/b/c` undeclared) → ground visuals broken | re-indented |
| H3 | P0 | `:=` inferred from Variant treated as error (drill latch, avatar inst, ped variant, ped DayNight node, dna `gset`) | explicit types |
| H4 | P0 | Cross-file `class_name` types unresolvable without editor class cache (`HumanDNA` in factory + materials, self-ref in human_dna) | `preload` consts in all 7 human modules; DNA self-construct via runtime `load()` |
| H5 | P0 | Duplicate `skin` var + duplicate `iris_material` in human_materials (edit collisions) | removed dupes |
| H6 | P0 | `add_child` during parent setup rejected (`HumanFactory.build` from child `_ready`) → cinematic bodies never attached | deferred attach |
| H7 | P1 | Save `get_value(..., null)` errors on missing keys (old/partial saves) | `has_section_key` guard |
| H8 | P1 | `iris_material` lost its `browns` palette (all irises one color) | restored |

Static audits could catch NONE of H1–H8 (all passed throughout).

- Environment: ARM64 host, no system Godot, no GPU (`/dev/dri` denied).
- Correct binary for host: `Godot_v4.6.3-stable_linux.arm64.zip` (~60 MB).
- Release CDN throttled (~50 KB/s with aborts); resumable background fetch
  running (`/tmp/godotbin/fetch.sh`, 60 attempts, zip-integrity gated).
- Pending once binary lands: `--editor --quit` import, class-cache assert,
  `-s hero_audit_headless.gd`, audit scene `-- --audit-quit`.

## Tier 2 — PC RUNTIME: PARTIAL (software GL, Compatibility)

- No GPU/X in sandbox; installed `xvfb` + Mesa `swrast`/`softpipe`.
  `llvmpipe` SIGILLs here — `GALLIUM_DRIVER=softpipe` renders correctly.
- Command: `Xvfb :99`, then Godot `--rendering-driver opengl3` on X +
  `LIBGL_ALWAYS_SOFTWARE=1`. Audio drivers absent (dummy fallback, fine).
- Audit scene full 40 s cycle: ZERO script/shader errors. All 3 custom
  shaders (skin/cloth/hair) compile on real GL.
- 320×180 screenshots captured (`user://hero_audit_auto_*.png`): hero
  renders (hair/wrap/limbs visible) but too small to judge anatomy.
- Re-running at 640×360 with closer camera (1.5 m) + neutral gray ground
  for the real close-up audit. Forward+ (device renderer) still uncovered.

### Visual defects from first screenshots (all P-status pending re-shoot)

| ID | Severity | Observation |
|----|----------|-------------|
| V1 | P0? | Head reads all-hair, no face visible — verify at 640px before grading |
| V2 | P0? | White wrap mass dominates torso — verify proportion at 640px |
| V3 | P1 | Audit ground was blown-out white (no material) — fixed: stage gray |
| V4 | P1 | Anomaly: first frame dark sky, then light blue — watch in re-shoot |

- Rendered run needs Vulkan/GL + display; sandbox has neither.
- Headless dummy drivers cannot produce screenshots or lighting reads.
- Owner action: run `godot --path . res://scenes/hero_audit.tscn` on a real
  PC and work `docs/HERO_RUNTIME_AUDIT_PENDING.md`.

## Tier 3 — ANDROID RUNTIME: BLOCKED (no device)

- No ADB device, no `adb`, no KVM (`/dev/kvm` absent) — TCG ARM emulation
  infeasible here (multi-GB downloads over throttled link + unusable speed).
- Emulator explicitly optional per brief; skipped as non-viable, not attempted.
- Owner action: install the `v0.30.0-cinematic` release APK (CI-built,
  arm64-v8a) on a real device; audit-APK procedure is in
  `docs/RUNTIME_VALIDATION.md`.

## Defects found this run

| ID | Tier | Severity | Status |
|----|------|----------|--------|
| — | — | — | (none yet; static green) |
