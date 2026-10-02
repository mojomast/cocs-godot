# World lane acceptance

## Completed without engine access

- `node --test game/environment.test.mjs game/weather.test.mjs`: **46 passed, 0 failed**.
- `node scripts/world-weather-oracle.mjs` and `--check`: **6 source looks, 60 source replay steps, 4 luminance cases** (plus 8 sheen clamp samples).
- Evidence: `/home/mojo/.tmp-on-disk/cocs-port-world-evidence-20261001/source-tests.tap` and `source-oracle.log`.
- Oracle review caught a missing renderer exposure property in the fixture harness; corrected and regenerated before the passing check.

## Queued — not accepted yet

No Godot, Blender, or import process has been started by this lane. Awaiting parent grant.

After explicit grant, use the pinned Godot binary, `LP_NUM_THREADS=1`, serial processes:

1. Parse/import required resources, then run `res://tests/world_weather/unit.gd` and the existing `res://tests/audio_new/weather_ownership.gd`.
2. Run `res://tests/world_weather/capture.gd -- <existing-output-dir>` graphically. It records all nine original map identities, at a fixed camera/FOV, in before / wet-only / weather states. Wet-only restores identical illumination to isolate material response. Inspect the resulting images, not just file existence.
3. Review representative campaign and multiplayer GLB worlds through their production sessions, including contrasting snow/volcanic/orbital or urban styles. Check that generated stage scenery is bound before the AV start seam.
4. Record at least three actual-wire player journeys: storm/rain world movement with stale/focus recovery; campaign snow/ash progression and respawn; LATTICE or MP spectator/reconnect/map restart. Assert authoritative actor positions/colliders unchanged and verify settings disable/reduced-motion/quality gates.
5. Capture material/node counts and measured native draw calls. `capture.gd` reports map bind CPU microseconds only (not frame time or FPS). Inspect any cap hits before acceptance.

## Integration dependencies

- Parent owns `world/session.gd`; retain the one-line `bind_presentation(world, environment, sun)` hook after AV binding when resolving integration conflicts.
- EXPERIENCE owns `audio/av_service.gd`; this lane does not modify it. Its existing bind/snapshot/tick/focus lifecycle remains the input contract.
- No asset import/rebake is required by this patch itself. Native tests/captures still require the existing project assets and imports.
- Source pins 515/core58ff/explicit-derived provenance are untouched.

## Slot status

**READY FOR ENGINE** after code commit. No slot acquired or used; native visual acceptance and real-player evidence remain outstanding. This is an engine-queue checkpoint, not release approval or final native acceptance.
