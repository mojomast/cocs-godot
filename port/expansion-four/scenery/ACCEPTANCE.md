# Scenery source checkpoint

**READY FOR BLENDER. No Blender, Godot, import, rendering, baking, video or nested
agent ran.** No heavy slot is requested implicitly by this handoff.

## Actual checks

- Six focused Node tests passed, including deterministic recipe/catalog output,
  12 distinct role-bound assets, triangle validity, bounds, strict lower-detail
  LODs, <=4 materials, original GLB/source byte preservation and real imported
  facade/baked-oracle agreement.
- All **8,337** inflated-block route-segment comparisons passed. This is a
  conservative clearance proof for the exact prospective geometry within each
  envelope, over all authored main/flank/workshop routes. All **2,827** authored
  route points were clear in the actual source `obstructed` oracle.
- **10,117** previously visible approach rays from source route feet/eye positions
  to objectives, workshop interaction/alignment targets and spawns remained clear
  against the new recipe's actual triangles. Baseline-blocked rays are recorded
  separately. Eight clear real-map Rootfall side/roof edge probes remain clear.
  Inserted-triangle and swept-block negative controls detect obstruction.
- Existing source regressions passed **30/30**: imported facade bytes and actual
  fire/plasma cover (4); workshop ordinary-input walks/rewards/refusals (6);
  all-chapter source terrain, every critical/flank movement segment, navigation
  metrics, handoffs and guardian deployment (20).
- Python AST parsing passed for `build.py` and `reopen.py`. No `bpy` import was
  executed. GDScript has not been parsed/typechecked by Godot. `gdtoolkit` is not
  installed in this environment; no grammar claim is made.

| Chapter | Swept comparisons | Clear source points | Visible rays preserved |
|---|---:|---:|---:|
| Rootfall | 1845 | 627 | 2761 |
| Siltwake | 2055 | 697 | 2530 |
| Emberline | 2220 | 752 | 2198 |
| Crown | 2217 | 751 | 2628 |

Focused log and actual-result summary:
`/home/mojo/.tmp-on-disk/cocs-expansion-four-scenery-evidence-20261002/source/`.
The 30-case regression's full output is in this agent session; `checks.json`
records its actual command/result. These source checks do not prove new imported
assets, arbitrary-ray equivalence, native play, human readability or GPU cost.

## Runnable source checks

```sh
node tools/godot-biomes/expansion/compile.mjs --check
node --test godot/tests/biome_assets/source.test.mjs
node --test port/edge-effects/edges.test.mjs port/native-campaign/interludes.test.mjs tools/godot-campaign/terrain.test.mjs
```

## Explicit grant required: build, reopen, import, inspect

Run serially from this worktree after Parallax releases the slot and parent grants
it. Verify toolchain binaries exist first. Preserve each attempt's logs, even when
it fails. Source generation is already committed; regenerate only after an
intentional recipe revision and rerun matching checks.

```sh
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-biomes/expansion/build.py
LP_NUM_THREADS=1 /home/mojo/.tmp-on-disk/cocs-blender-toolchain/blender-4.5.14-linux-x64/blender -b -t 1 --python tools/godot-biomes/expansion/reopen.py
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot --editor --import --quit
LP_NUM_THREADS=1 /home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 --headless --path godot -s res://tests/biome_assets/imported_geometry.gd
node godot/tests/biome_assets/run_inspection.mjs --granted
```

Masters will be written to `tools/godot-biomes/expansion/masters/` **outside Godot**.
Runtime GLBs/import presets go to `godot/biomes/expansion/art/`. Neither exists yet.
Reopen checks validate named editable objects. Import checks compare the complete
transformed triangle multiset of all 24 exports to the actual recipe at 0.1 mm
normalized quantization, plus opaque materials and mesh/surface budgets.

`run_inspection.mjs` owns an ordinary production `createAuthority` and loads
**`campaign/demo.tscn`** separately for every chapter, serially at 1280×800/UI100
and 760×520/UI150. It uses no synthetic substitute map or authority mutation.
`native_inspection.gd` stages supported approach/eye cameras in the actual full
production viewport with real HUD, workshop scenery, terrain and atmosphere.
Matched old/new/reduced stills hold scene clocks constant. It records original
collider instance IDs/geometry/transforms before and after, imported counts,
render counters, timestamped captures, source-camera return and teardown/rebuild.
Output uses fresh timestamp directories and preserves failures. No screenshot or
performance result has been produced by this runner yet.

## Remaining gates after initial inspection

1. Native parse/type/API corrections if required; independently reopen masters
   and GLBs, check import axes, scale, normals, parts, bounds and LOD transitions.
2. Inspect full-viewport paired images and all four hero eye-level forms. Inspect
   the editable art panel as a supplement. Revise if the retained facade hides
   the added form, a motif reads as a thin stretched ornament, the static wheel
   competes with the functional wheel, or old/new joins undermine depth.
3. Ordinary connected native walk/shot journeys on each affected chapter,
   objective marker/player/robot silhouette readability, actual facade edges,
   workshop approach/aim/interaction and source/native collision agreement.
   The prepared camera-staged inspection is **not** that gameplay proof.
4. Measured reduced-detail cost, draw/material/resource lifecycle, compact HUD,
   original-material restoration after wetness toggles, source-camera returns,
   and no leaked resources across chapter retries/teardown.
5. Capture a representative continuous native walk/shot sequence. Record each
   captured timestamp and actual cadence; still-image capture spans or a higher
   encoder FPS are not full-motion native capture evidence.
6. Parent owns shared bindings, settings quality-hook review, canonical inventory,
   package closure, builds, release publication and final art acceptance.
