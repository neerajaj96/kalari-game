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

## Tier 1 — HEADLESS: IN PROGRESS

- Environment: ARM64 host, no system Godot, no GPU (`/dev/dri` denied).
- Correct binary for host: `Godot_v4.6.3-stable_linux.arm64.zip` (~60 MB).
- Release CDN throttled (~50 KB/s with aborts); resumable background fetch
  running (`/tmp/godotbin/fetch.sh`, 60 attempts, zip-integrity gated).
- Pending once binary lands: `--editor --quit` import, class-cache assert,
  `-s hero_audit_headless.gd`, audit scene `-- --audit-quit`.

## Tier 2 — PC RUNTIME: BLOCKED (no GPU)

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
