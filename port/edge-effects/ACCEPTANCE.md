# Edge-effects acceptance and parent handoff

Evidence root: `/home/mojo/.tmp-on-disk/cocs-edge-effects-evidence-20261001/`.
Engine: Godot 4.5.2, serialized `LP_NUM_THREADS=1`, Compatibility OpenGL via private
Xvfb / Mesa llvmpipe for images. No Blender process was used.

## Passing evidence

* `node-accepted.log`: **52/52** campaign + edge tests, including source generator
  provenance, targeting, movement authority and interludes. Includes **11,952**
  native-fixture source targeting fire/damage checks. `source-final.log`: the four
  dedicated edge tests rerun with ordinary-size supported targets and the actual
  campaign fast-projectile hook, including 138m/s plasma. Eight before/after fire
  cases cover side air, roof air and two solid-wall heights, plus the separate
  blocked camera-candidate case. Source events/IDs and unchanged damage outcomes
  are recorded in `source-events-final.json`.
* `edge_effects-maps-suite.log`: **1,041/1,041** real-map structural-face native /
  source distances, all four campaigns, with explicit inside-rock visibility
  checks. 33/68/101/111 facade placements; total map bodies 244/339/374/403.
* `edge_effects-contracts-verified.log`: **77** checks, including source short
  muzzle-cover event, incoming normal, exact edge / outside epsilon, both slab
  faces, roof/underside, real slope normals, semantic wall occlusion, no false
  nearby-air impact, same-plane footprint guard and 1,000-mark reuse/reset.
* `edge_effects-weapons-accepted.log`: **239** checks over all ten source-event
  identities at both enabled quality levels, launch versus hitscan, duplicate
  events, finite retirement, reduced motion, 1,000 primary explosions, caps and
  reset. The earlier `-second.log` records the same 239-count run before the final
  low-quality secondary-arc restriction; the accepted run covers that restriction.
* `render-proof.log`: **366** checks, **72 pixel-mask cases** (two surface values,
  wall/floor/ceiling, near/far, frontal/grazing, three mark kinds), exact unchanged
  transparent-corner pixels, full-image through-cover and backface comparisons,
  real source wall-pock placement and short muzzle-cover cue. All new shaders
  compile in Compatibility, including the production campaign light binding.
  `render-proof/` contains paired square/round cards, source before/after facade
  shots, source-confirmed close wall cue and persistent pock, ten weapon frames,
  three primary blasts and a production beacon capture. `review-final.png` is the
  inspected contact sheet (refresh it from `render-proof/` after regenerating).
* Existing native weapon lifecycle, rig integration, muzzle path, projectile
  flight and alt fire tests pass in `weapon_effects-*-second.log`. Both physics
  animation suites pass, including exact casing gravity (`animation-*-second.log`).
  Campaign terrain and structure-art tests pass; the latter now checks actual
  facade collider types/transforms and rock-box count, with the workshop-era art
  batch ceiling updated from stale 240 to 320 (observed maximum 272).
* Shared combat composition contracts pass (`combat_integration-contracts-accepted.log`).
  Existing urban source audit and native physics pass (`urban-source.log`,
  `urban-native.log`): 8 sealed ceilings, 32 slab sides, 72 doorway sweep points,
  5 roofs and 5 ramps across the two urban maps.

`measure-structural.log` measures 2,000 CPU ray queries per map at approximately
17.34 / 26.32 / 38.66 / 40.83ms on this host. This is a bounded CPU microbenchmark,
**not GPU frame rate**. Prototype bake: 20 GLBs, 47,022 raw triangles, 46,974 above
the source degenerate threshold; JSON artifact is 8,728,402 bytes. No extra FX pool
budget was introduced: marks 20/44/72, material bursts 6/12/20, weapon slots 64,
lines 128, barrel lights 2. Native facade collider storage is built once per map.

## Reproduce

Set `E` to a fresh evidence directory and `GODOT` to the executable above. Import
the worktree first and prepare the normal semantic catalog required by existing
tests (`godot/content/generated/`, using the project's normal content exporter).

```sh
node port/edge-effects/bake-structures.mjs --check
node port/native-campaign/generate-core.mjs --check
node --test port/native-campaign/*.test.mjs port/edge-effects/edges.test.mjs
EDGE_SOURCE_EVENTS="$E/source-events-final.json" node --test port/edge-effects/edges.test.mjs
EDGE_MAP_CASES="$E/map-cases.json" node port/edge-effects/measure.mjs
EDGE_MAP_CASES="$E/map-cases.json" LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/edge_effects/maps.gd
EDGE_SOURCE_EVENTS="$E/source-events-final.json" LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/edge_effects/contracts.gd
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/edge_effects/weapons.gd
EDGE_SOURCE_EVENTS="$E/source-events-final.json" EDGE_RENDER_OUT="$E/render-proof" LP_NUM_THREADS=1 python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/edge_effects/render.gd
```

## Failed attempts retained

* Initial native marks runs lacked the worktree's ignored semantic catalog. The
  parent-generated catalog was copied into the correct `content/generated` path;
  the resulting marks/impacts tests pass. First failure logs remain.
* Initial plasma drill let an airborne target fall below the ray. The final drill
  uses source support blocks and ordinary actor hit regions; an intermediate
  enlarged fixture was removed. Production hit regions were never changed.
* Native map comparison caught nonuniform scaled collision-shape discrepancies;
  baking transforms into collision vertices repaired structural faces. The later
  microscopic-bevel mismatch investigation is retained in `maps-*.log` and
  `receiver-imported.json`; the limitation is explicit in DIAGNOSIS.md.
* A `primary` Variant inference error caused the first weapon lifecycle process
  to reach its harness timeout. An explicit bool fixed compilation; later suites
  pass. The timeout killed that engine process before the next engine run.
* The real muzzle-cover replay exposed the pre-existing 60cm cue cutoff, now
  fixed. Structure-art's old 240 batch budget predated workshop additions; its
  draw code is unchanged and the observed peak is 272.
* The first image run attempted system ALSA and fell back to Dummy. Final runs
  explicitly select Dummy; their only renderer warning is unsupported VSync on
  llvmpipe. The Pillow contact-sheet attempt lacked that Python dependency;
  installed Node `sharp` produced the reviewed sheets instead.

## Parent integration / package closure

Cherry-pick only this lane's implementation commit(s), **not** local `f087e830`
(the cherry-pick of PhysicsSol's `cd15d7b3`, already supplied to the parent).

New server runtime closure:

* `port/edge-effects/structure-rays.mjs`
* `port/edge-effects/structure-faces.json` (required next to the module)

New Godot runtime resources, picked up by tracked-script/resource inventory:

* `player_fx/burst.gdshader`
* `weapon_effects/{trail,discharge,conduit}.gdshader`

`match.mjs` has the campaign ray/visibility adapter; generator + generated core
and its independent inverse test contain the event-only classification fix.
Terrain/structure-art changes add exact facade collision and the selected light
shader. No shared `world/combat_feedback.gd`, first-person, melee, interlude,
vehicle, robot-motion or actor-volume production file was edited. No public
package/export was made. Parent owns dependency whitelist updates, canonical
gates, combined gameplay acceptance and release.
