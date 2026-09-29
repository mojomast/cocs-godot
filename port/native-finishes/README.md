# Source-owned weapon finishes · native viewmodel

The source renderer in `game/view.mjs` resolves `game/cosmetics.mjs` finishes as **dark = secondary**, **light = accent**, **glow = primary**. Its generic helper `applyFinishToColor` is not used for weapon materials. The deterministic generator `tools/godot-weapons/finishes.mjs` reads the source catalog, emits `godot/first_person/generated/finishes.gd` and records SHA-256 of both `game/cosmetics.mjs` and the renderer `game/view.mjs`. `linear` oracle values are calculated by Three.js `Color(hex)` from each source color: source sRGB hex → linear PBR channels. Native `StandardMaterial3D` receives **sRGB `Color(hex)`** in precisely those three imported mesh roles. Its albedo/emission `source_color` uniforms convert that to shader-linear values. Supplying already-linear values double-converts and darkens the finish. The Node oracle checks source roles and Three.js channels; Godot tests compare the **effective** shader-linear channels (`material.albedo_color.srgb_to_linear()` and glow emission) against this oracle, and check that stock materials are restored exactly.

The rig binds private, already-duplicated imported surface overrides once per weapon selection. It updates only their albedo, and the glow role's emission. Imported trim, cavity, sights, arms, forearms, effects and muzzle flash stay independent. Original stock albedo/emission are retained and restored on null, missing, unknown or malformed source actor finishes, hidden/dead/vehicle/spectator state, actor changes and reset. Every material is reused across changes; profile selection alone never changes the viewmodel. The fixture covers all ten imported weapon role maps and two isolated rigs. Native third-person `world/actor_visual.gd` has a generic carbine rather than these source weapon meshes, so this role binder is scoped to the actual imported first-person weapon presentation.

## Reproduction

From the repository root (Godot 4.5.2, `godot/` imported):

```sh
node tools/godot-weapons/finishes.mjs
node tools/godot-weapons/finishes.mjs --check
node --test tools/godot-weapons/finishes.test.mjs
godot --headless --path godot --script res://tests/first_person/finishes.gd
godot --headless --path godot --script res://tests/first_person/lifecycle.gd
xvfb-run -a godot --path godot --audio-driver Dummy --script res://tests/first_person/finishes_capture.gd -- --evidence-out="$PWD/port/native-finishes/evidence"
node tools/godot-weapons/finish-journey.mjs --output="$PWD/.port-runtime/finish-source-journey.json"
godot --headless --path godot --script res://tests/first_person/finishes_source.gd -- --source-journey="$PWD/.port-runtime/finish-source-journey.json"
```

The original rendered contact sheet and individual PNGs are preserved under `evidence/historical-double-conversion/` as **FAILED/HISTORICAL** evidence of the double-conversion color bug. They do not depict the corrected material colors. The capture harness will regenerate stock and six finishes at identical hip pose, light and camera (640×400 per column), with metrics requiring at least 100 pixels changed from stock, when the local rendering slot is available.

`evidence/source-journey.json` (earlier capture; pending replay with sequence-checked source rounds) records real WebSocket protocol v3 source actor snapshots: stock → profile saved with Ion but *current actor still stock* → new match actor Ion. The runner accepts `--output=PATH`, the Godot replay accepts `--source-journey=PATH`, and the runner now requires snapshots after the corresponding START/profile ACK and later source ticks. **CONTROLLED GRANT FIXTURE:** `ProgressionStore.awardOwned` is given a simulated completed source match with 200 credited frags, reaching level 4. This is a source-authoritative test reward, not a claim of natural eligible play. The source `gear` wire selects the unlocked finish; the source `start` rematch applies it. The Godot journey replays those public actor fields into the shipping rig and checks its shader-linear material channels; no credentials are written to the report. Natural players must reach source level 4 before Ion is eligible.

The earlier capture initially had a GDScript `Color.distance_to` parse error; this was corrected to channel-wise comparison before capture. Browser preview was unavailable in this agent session; the PNG was visually inspected via local image read. The subsequent color-space review identified its double-conversion bug; the failed image is explicitly archived, and the corrected capture is pending the serial render slot.
