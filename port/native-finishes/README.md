# Source-owned weapon finishes · native viewmodel

The source renderer in `game/view.mjs` resolves `game/cosmetics.mjs` finishes as **dark = secondary**, **light = accent**, **glow = primary**. Its generic helper `applyFinishToColor` is not used for weapon materials. The deterministic generator `tools/godot-weapons/finishes.mjs` reads the source catalog, emits `godot/first_person/generated/finishes.gd` and records SHA-256 of `game/cosmetics.mjs`. `linear` values are calculated by Three.js `Color(hex)` from each source color: source sRGB hex → linear PBR channels. Native `StandardMaterial3D` gets `Color(hex).srgb_to_linear()` in precisely those three imported mesh roles. The Node oracle checks the generated roles and numeric Three.js channels; the Godot tests compare all six finishes against those independently generated source values.

The rig binds private, already-duplicated imported surface overrides once per weapon selection. It updates only their albedo, and the glow role's emission. Imported trim, cavity, sights, arms, forearms, effects and muzzle flash stay independent. Original stock albedo/emission are retained and restored on null, missing, unknown or malformed source actor finishes, hidden/dead/vehicle/spectator state, actor changes and reset. Every material is reused across changes; profile selection alone never changes the viewmodel. The fixture covers all ten imported weapon role maps and two isolated rigs. Native third-person `world/actor_visual.gd` has a generic carbine rather than these source weapon meshes, so this role binder is scoped to the actual imported first-person weapon presentation.

## Reproduction

From the repository root (Godot 4.5.2, `godot/` imported):

```sh
node tools/godot-weapons/finishes.mjs
node --test tools/godot-weapons/finishes.test.mjs
godot --headless --path godot --script res://tests/first_person/finishes.gd
godot --headless --path godot --script res://tests/first_person/lifecycle.gd
xvfb-run -a godot --path godot --audio-driver Dummy --script res://tests/first_person/finishes_capture.gd -- --evidence-out="$PWD/port/native-finishes/evidence"
node tools/godot-weapons/finish-journey.mjs
godot --headless --path godot --script res://tests/first_person/finishes_source.gd
```

`evidence/contact-sheet.png` contains stock and all six finishes at identical hip pose, light and camera, 640×400 per column; `metrics.json` samples the actual rendered viewport and requires at least 100 pixels changed from stock for each finish (measured: 1,740–2,391). The corresponding individual PNGs are retained for inspection.

`evidence/source-journey.json` records real WebSocket protocol v3 source actor snapshots: stock → profile saved with Ion but *current actor still stock* → new match actor Ion. **CONTROLLED GRANT FIXTURE:** `ProgressionStore.awardOwned` is given a simulated completed source match with 200 credited frags, reaching level 4. This is a source-authoritative test reward, not a claim of natural eligible play. The source `gear` wire selects the unlocked finish; the source `start` rematch applies it. The Godot journey replays those public actor fields into the shipping rig and checks its actual material channels; no credentials are written to the report. Natural players must reach source level 4 before Ion is eligible.

The rendered capture initially had a GDScript `Color.distance_to` parse error; this was corrected to channel-wise comparison before the successful capture. Browser preview was unavailable in this agent session; the PNG was visually inspected via local image read.
