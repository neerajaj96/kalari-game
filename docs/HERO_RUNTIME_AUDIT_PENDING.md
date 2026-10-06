# HERO RUNTIME AUDIT — PENDING (NOT VALIDATED)

Baseline: commit `7bff612`. Status of every line below: **[ ] PENDING**.
Static (`tools/check.py`, `tools/human_audit.py`) and headless tiers pass;
those prove the pipeline CONSTRUCTS. No line here may be marked done without a
real PC (Tier 2) and Android ARM64 (Tier 3) close-up observation per
`docs/RUNTIME_VALIDATION.md`.

## Views × lighting (gameplay lighting, audit scene sun/env parity)

- [ ] PENDING — Front view, noon key: face likeness reads as one person
- [ ] PENDING — Three-quarter view: nose bridge/tip, cheek, jaw transition
- [ ] PENDING — Profile view: forehead→nose→lips→chin line, no shelf artifacts
- [ ] PENDING — Dusk + storm keys: skin SSS rim sane, no glowing ears/nose

## Eyes (all views)

- [ ] PENDING — Catchlights present, iris/pupil discs sit on cornea (no float/sink)
- [ ] PENDING — Blink: lids (not just balls) close every few seconds
- [ ] PENDING — Gaze saccades visible during idle, no crosseyed look

## Face (all 8 expressions: neutral/focus/anger/fear/pain/surprise/effort/recovery)

- [ ] PENDING — Jaw opens with mouth cavity dark (teeth inside, not pasted on)
- [ ] PENDING — Brows + cheeks move per expression, micro-expression alive
- [ ] PENDING — Wrinkle/stubble shader zones read at close-up, no tiling

## Deformation (shoulder/elbow/wrist/hip/knee/ankle)

- [ ] PENDING — STRIKE lunge: shoulder caps hide seams, no gaps
- [ ] PENDING — Unified 2-bone skinning (torso/head/wrap) lands only after the
  rigid + joint-cap baseline passes this audit (too risky to ship blind)
- [ ] PENDING — BLOCK guard: hands reach targets (IK assist), no interpenetration
- [ ] PENDING — DODGE/HIT/DOWN: joint balls track, feet stay planted
- [ ] PENDING — MARCH: gait sway/bounce reads per DNA, feet plant without slide

## Body / costume

- [ ] PENDING — Hands: knuckles + nails read at close-up
- [ ] PENDING — Feet + toenails, kaccha thigh wraps follow thighs
- [ ] PENDING — Hairline irregular, kuduma knot + tie band + sideburns, no scalp gap
- [ ] PENDING — Sash/cloth hem sway subtle (no clipping during combat)

## Performance (Mobile renderer, ARM64)

- [ ] PENDING — Overlay fps stable vs village baseline, Hero LOD switches at 9m/22m
  (pin LODs with `L` in the audit scene when inspecting silhouette pops)

## Defect loop (per defect)

`OBSERVE → IDENTIFY WEAKEST DEFECT → FIX → RUN → COMPARE → KEEP ONLY IF BETTER → REPEAT`
Log each observation with screenshot names (`user://hero_audit_*.png`) and the
commit that fixed it. After the hero passes, apply this same standard to
Gurukkal, enemies and NPCs before any further hero micro-edits.
