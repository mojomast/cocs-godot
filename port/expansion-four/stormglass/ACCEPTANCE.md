# Source checkpoint and queued production

**Historical source checkpoint below.** Actual grant-J production, native outcomes,
retained failures and explicit slot release are now recorded in
[PRODUCTION-J.md](PRODUCTION-J.md). Public registration remains closed.

**READY FOR BLENDER — source-only.** No Blender/Godot/import/render/capture ran.
Parallax retains the exclusive slot. No `.blend`/GLB exists for Stormglass yet.

## Actual checks

Nine focused Node tests pass:

1. Schema, 1,191 m ribbon, grid support, triangulated walls and absolute gate-height
   refusal; off-route ocean has no floor.
2. Single mounted ordinary-input lap: 105.306422 s source finish, 1,188.262 m
   continuously driven; zero collision refusals, zero reset samples, largest
   1/60-second displacement .235266 m.
3. Four stock autonomous racers: winner finishes at 64.386828 s, zero reset samples,
   largest displacement .401165 m. Remaining racers have passed every non-start
   gate and are on the closing sector. Source ends at first finish; this does not
   claim all four finished. Initial actor 0 is explicitly given bot state; thereafter
   empty per-actor input dispatch invokes actual source botControls for all seats.
4. Two ordinary-input source competitors: finish at 104.607842 s; source countdown
   holds positions, standings place both competitors, results stop simulation.
5. Reverse, skipped, repeated and airborne gate controls; ordinary reset preserves
   earned gate state and cannot award a lap. Gate-only negatives are isolated unit
   fixtures and are not counted as driven completion.
6. Forty-two physical road faces each withstand 180 ticks of infantry body input,
   180 ticks of Puma throttle contact, and a blocked horizontal shot.
7. Six overhead samples block upward shots while floor stays at Y=0.
8. All 215 source navigation nodes / 225 undirected edges form one connected circuit.
9. Actual source Puma acceleration/braking/steering calibration.

Existing `game/race.test.mjs` + `game/race-match.test.mjs`: **31 pass, one existing
slow eight-bot test skipped**. Focused candidate checks: **9/9 pass**. Combined first
run exposed an overly strict calibration equality against asymptotic 20 m/s;
corrected test checks measured >19.9 and ≤20. Retained failed log is `source-final.tap`;
accepted candidate log is `source-accepted.tap`.

Other actual checks: standalone generator freshness, Blender Python AST syntax,
unchanged frozen `game/` / source lock / Sirocco baseline against `e9d784a7`.
Core SHA-256 is still
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
Frozen `515daf07589150dd3241f4ae1425cc1b093912f5` and reviewed derivative
`0326b435a2fdd88e6e7a01b8a7325feccc4d15cb` are not edited.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-expansion-four-stormglass-evidence-20261002/`.
Contains accepted TAP, failed TAP and a development-failure record. Source fixtures
use controlled initial arena installation, then actual `Match.step` inputs at
1/60 simulation steps with accelerated wall time. No post-setup actor positions,
race score, gate progress or finish writes in the driven fixtures. Teleport-sized
displacements and reset waits are explicitly checked.

## Reproduce source work

```sh
node tools/godot-multiplayer/new-maps/stormglass-causeway/build.mjs --check
node --test godot/tests/new_maps/stormglass_causeway/source.test.mjs
node --test game/race.test.mjs game/race-match.test.mjs
```

## After an explicit heavy-slot grant

Run serially from this worktree:

```sh
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-multiplayer/new-maps/stormglass-causeway/blender_export.py
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 tools/godot-multiplayer/new-maps/stormglass-causeway/stormglass-causeway.blend --python tools/godot-multiplayer/new-maps/stormglass-causeway/blender_export.py -- --verify-only
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --script res://tests/new_maps/stormglass_causeway/route_probe.gd
```

These commands are prepared, unexecuted. The native probe requires exported art
and checks 441 route-support rays plus six overheads. It is not a hosted journey.

Then inspect overview and eye-level terminal/bore/quay/gate architecture, compare
GLB vertices against authority geometry, measure actual batches/import cost and
revise architectural deficiencies before acceptance. Inspect chase camera at
corners, ceilings, road contacts and wheel placement using the existing Puma.

Parent integration needed: authority/catalog allowlist and manifest entry, sports
scene generator's map/mode selection, world viewer/catalog registration, package
closure. The standalone generator writes only the three Stormglass JSON files;
it never rewrites old maps or shared manifests. Test map installation does not
prove production catalog routing.

Hosted acceptance after those hooks: two **native** players, countdown, ordinary
steering/braking, a complete source-scored race and standings, wrong-way cues,
checkpoint reset, restart and Home; inspect 1280×800 and 760×520/UI150 results.
Capture ≥20 seconds of continuous actual driving with measured acquisition cadence,
not encoded-rate claims. Autonomous source proof is separate from native/human
feel and real-GPU performance. Publication remains blocked on these gates and the
explicit road-relief concession described in DESIGN.md.
