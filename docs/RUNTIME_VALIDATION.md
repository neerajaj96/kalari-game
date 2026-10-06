# Runtime Validation: STATIC → HEADLESS → PC RUNTIME → ANDROID RUNTIME

Hero baseline: commit `7bff612` (procedural cinematic pipeline). Static audits
prove construction. NOTHING below claims the hero looks right — visual proof
requires the PC and Android tiers in `docs/HERO_RUNTIME_AUDIT_PENDING.md`.

## Tier 0 — STATIC (no Godot, runs anywhere)

```sh
python3 tools/check.py        # fail-fast pre-export checks (must print CHECK OK)
python3 tools/human_audit.py  # pipeline audit: DNA, anatomy, rig, LOD budgets
python3 tools/balance.py      # economy sanity (ranks land in minutes)
```

## Tier 1 — HEADLESS (Godot 4.6.3, no renderer)

```sh
godot --headless --editor --quit          # import + class cache (as in CI)
godot --headless --path . -s res://tools/hero_audit_headless.gd   # expect exit 0 + OK lines
godot --headless --path . res://scenes/hero_audit.tscn -- --audit-quit  # 30s self-cycle log, then quits
```

Expected: `[HERO_AUDIT_HEADLESS] OK` and a `[HERO_AUDIT] ready headless=true`
line followed by view/pose/expression lines. Any `SCRIPT ERROR` fails the tier.

## Tier 2 — PC RUNTIME (native, Forward+)

```sh
godot --path . res://scenes/hero_audit.tscn
```

- Scene uses the same sun-rig values, env grade and `fov = 55.0` as the
  village/school gameplay baseline, so the audit happens under gameplay lighting.
- Work the checklist in `docs/HERO_RUNTIME_AUDIT_PENDING.md`: front,
  three-quarter, profile × all combat poses × all 8 expressions × march.
  Press `L` to pin Hero/Mid/Far LODs when inspecting silhouette pops.
- Screenshots (`S`/`F12`) save to `user://hero_audit_*.png`.
- For every visible defect: OBSERVE → IDENTIFY WEAKEST DEFECT → FIX → RUN →
  COMPARE → KEEP ONLY IF BETTER → REPEAT.

## Tier 3 — ANDROID RUNTIME (ARM64 device, Mobile renderer)

1. Build the debug APK from a tag release (CI: `.github/workflows/android_debug.yml`,
   `arm64-v8a`, `etc2`, landscape) and install on the device.
2. The audit scene is NOT the launch scene (launch stays `res://scenes/main.tscn`
   so the shipped game is unaffected). To validate the hero on device, build a
   one-off audit APK:
   - temporarily set `run/main_scene="res://scenes/hero_audit.tscn"` in
     `project.godot`, tag `audit-*` (does NOT match the `v*` deploy workflow —
     run the workflow manually via workflow_dispatch), install, validate,
     then revert the swap. Never commit the swap.
3. On device: tap advances view, two-finger tap screenshots (auto-cycle covers
   poses/expressions with zero input). Check fps on the overlay, thermals, and
   the full pending checklist under the Mobile renderer.
4. Copy `user://hero_audit_*.png` off the device for before/after comparison.

## Tier separation contract

- Static green ≠ looks right. Headless green ≠ looks right.
- Only signed-off PC + Android checklist lines in the pending doc count as validation.
- If runtime remains unavailable, say so in the pending doc and work the next
  game-wide bottleneck instead of inventing visual micro-edits.
