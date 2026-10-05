# Kalari Kerala — Bhadrakali Temple Slice (Loop 1 + Temple arc T1–T8)

Real Kerala Kalaripayattu solo RPG + Kolathiri Bhadrakali temple build.
Sources: Chirakkal T. Sreedharan Nair (Arappukkai) + Meru Tantra Vol 1 (8 prakashas indexed).

## What this APK is
- `42x21ft kuzhi-kalari` school (Poothara 5-tier, Gurukkal NPC, lamp flicker) + Kerala village (Pancha-prakara temple complex, market, backwater, hermitage).
- Combat: 5 moves, vadivu poses, kettukari/cheruvadi with swing, slash-arc flash, hit-stop (0.08s marma), lunge, marma back-stabs, dust + spark VFX, dodge ribbon, combat FOV kicks, follow camera with shake.
- Systems: kalari ranks 1-3 (+4-6 locked), 5 nitya sevas, breath sadhana (kalari/temple/forest), 7-phase temple plot, 18+ symbolic Marga track (default OFF), 14-tab encyclopedia (+ user-text slots).
- Godot 4.6.3-stable, Forward+ (desktop) / Mobile (Android) renderer, arm64-v8a, debug signed.

## Build APK from Termux (no local SDK needed)
```sh
pkg install git gh
git init && git add . && git commit -m "kalari temple slice"
gh repo create kalari-game --public --source=. --push
git tag v0.1.0 && git push origin v0.1.0
# Actions -> Release -> download kalari-debug.apk -> Allow unknown apps -> Install
```

## Test logic in Termux first
```sh
python3 tools/balance.py
python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('data/*.json')]; print('JSON OK')"
```

## Controls
- Left joystick: move (PC: WASD). Right: Attack / Block / Dodge / Breathe.
- Bottom bar: Village / School / Rain / Seva / Sadhana / Tabs / Plot / Marga.
- Seva: fetch at stall → bell (Attack) at sanctum door in 6s. Sadhana: 11 breaths via Breathe.
- Plot: temple quest status. Marga: 18+ symbolic track toggle (Rank 3 + 3 sevas to progress).

## Filing Kularnava / Tantrasamuchaya
Paste excerpts as `{id, name_en, name_ml, what, how_in_game, philosophy, sources}` objects
into `data/user_texts.json` `tabs` array — ancient verses verbatim (PD), modern commentary summarized.
They appear in the Tabs panel after the 14 Meru tabs automatically.
