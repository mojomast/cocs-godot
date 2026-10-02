# Pass-two world acceptance

Status: **NOT NATIVE ACCEPTED — engine grant pending**.
Evidence: `/home/mojo/.tmp-on-disk/cocs-pass-two-world-evidence-20261002`.

## Gates

1. Execute actual Three.js `wetSheenTexture`, `ArenaView._scheduleWeatherSplash` and `RipplePool` to produce checked-in oracle vectors. Run source environment/weather/graphics-fidelity tests now.
2. Native focused test: byte-exact seeded texture vectors, source ripple color/scale/fade and timing; shared material and shader isolation; original roughness textures/channels restored dry; replacement-owner safety; absent/raised/sloped support; caps and repeated map leases.
3. Godot 4.5.2, `LP_NUM_THREADS=1`, only after explicit grant. Parse/import first, then focused and first-pass lifecycle regressions. Preserve every failed log and capture.
4. Matched original/campaign/urban/sport views: dry versus wet under equal illumination; inspect rendered images. Record material/draw/triangle and resource counts and CPU timings (llvmpipe only if software).
5. Connected snapshots: weather transition, late join, camera movement, mute, reduced motion, quality, focus/stale, restart and map teardown. No injected gameplay weather for wire acceptance.

All native gates remain outstanding until the engine owner explicitly releases the slot and grants this lane execution. No Godot, Blender, import or rendering has run for this pass.

## Pre-engine results

- `node --test game/environment.test.mjs game/weather.test.mjs game/graphics-fidelity.test.mjs`: **66 passed**, no failures (`source-tests.tap`).
- `node scripts/world-weather-spatial-oracle.mjs --check`: **pass**. Three full 128² RGBA image hashes, 27 sampled pixels, 20 scheduling decisions, source linear contact color/position/delay, eight actual RipplePool update states. Also checks the three exact native shader anchors. Fixture: `godot/tests/world_weather/spatial_source.json`.
- `node scripts/world-weather-oracle.mjs --check`: **pass**, first-pass look/transition source fixture unchanged.
- `gdparse` (gdtoolkit, Python-only grammar parser): **pass** for the four changed/new ambience scripts and focused `spatial.gd`. This is not Godot type-checking or shader compilation. Parser install/logs are in the evidence directory.
- `git diff --check`: pass. Test fixtures remain under `godot/tests`, already excluded by the export preset's `tests/*` filter.

## Queued native commands — execute only after grant

```sh
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/world_weather/spatial.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/world_weather/unit.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/audio_new/weather_ownership.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/audio_new/standalone_lifecycle.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/campaign/environment.gd
```

Then reuse `world_weather/capture.gd` and `world_weather/styles.gd` for matched surface views. Their new look diagnostics expose texture/variant counts. Supplement with close ground-contact captures in actual weather sessions and a sports representative; existing high overview shots alone cannot accept the contact work. Reuse `scripts/world-weather-journey.mjs` for source-connected mute/settings/restart/late-join evidence, extending its receipts with `weather.contacts.diagnostics()` when the native lane resumes. The prior first-pass evidence aggregator assumes zero added draw calls and must not be used to certify the new contact pool unchanged.

Unmeasured: native pixel hashes, type/shader compilation, query timing, texture generation time, resource teardown under engine, matched images, connected contact visibility, draw/triangle deltas and GPU cost. **Ready for native testing, not ready for release acceptance.**
