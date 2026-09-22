# Material application pass — the material language on real game geometry

Application half of the asset-coverage pass. The library half
(`godot/material_language/**`, `godot/moth/**`, `tools/godot-moth/**`) is owned
by the parallel lane; this lane consumes `res://material_language/library.gd`
through the frozen interface and never edits library files.

## What this pass did

Puts the published material families onto the surfaces the game actually
renders, by surface role, without changing geometry, collision, spawns,
pickups, navigation or any packaged asset:

| Where | File (owned) | Change |
|---|---|---|
| nine locked maps (viewer presentation) | `godot/world/environment_style.gd`, `godot/world/viewer.gd` | every block kind resolves to a role → family; the map's authored colour is the tint; terrain keeps its DEPTH-priority shader and gains the baked normal that reads for its kind; trim/accent detail batches and tree crowns are family surfaces; the scene records its family plan as metadata |
| Prism Foundry, Aurora Basin, Cinder Array | `godot/native_arenas/maps/{prism-foundry,aurora-basin,cinder-array}.gd` | `_make_materials()` override calls the pre-pass builder then swaps the named surface entries for shared family materials, keeping each arena's authored tint and per-key options |
| three identity maps | `godot/identity_maps/map.gd` | the six shared materials per map come from the recipe palette + published families; the texture-budget metric is recomputed from the materials actually bound |
| scenery props | `godot/moth_scenery/scenery.gd`, `panel.gdshader` | plate normals resolved through `MaterialLanguage.normal_map()` (baked first, derived fallback) with a per-kind normal depth; the shared panel/mote shaders stay the only scenery shaders |
| atmosphere | `godot/graphics_atmosphere/atmosphere.gd`, `distant_ground.gdshader` | distant-ground grain from the derived data bucket, one sampler, faded before the sky blend |

Interface calls used: `families()`, `describe()`/`variants()` via validation,
`material(family, options)`, `normal_map(key)`, `derived(key)`, `budget()`,
`coverage()`, `cache_stats()`, `set_clock()` (capture determinism) and
`DEFAULT_FAMILIES` indirectly through `families()`. `apply_to()` is not used:
materials here are assigned to named roles, not to whole subtrees, so the
one-material-per-role assignment is explicit and countable.

Family assignment, tiling and the identity/exposure policy: **ROLES.md**.

## Bounded cost (measured, not asserted)

* **Shared materials.** The library cache held **64 materials / cap 96 with 0
  rejections** after a census that builds all 15 compositions in one process
  (`evidence/census-after.json`). No per-surface material, no per-surface
  shader.
* **Draw calls unchanged: +0 on all 84 matched views.** Materials were swapped
  in place; no batch, MultiMesh or node was added or split. Primitives and node
  counts are identical per view.
* **Texture growth is small and bounded.** Per map (Moth baked planes at first
  report, honest per-map count with the cache cleared between maps):

  | map | Moth planes before → after | derived planes after (cap 64) | unique bound texture bytes after |
  |---|---:|---:|---:|
  | prism-foundry | 17 → 27 | 8 | 307 KB |
  | aurora-basin | 11 → 16 | 9 | 143 KB |
  | cinder-array | 11 → 22 | 12 | 190 KB |
  | lacuna-court | 13 → 20 | 14 | 219 KB |
  | vermilion-fold | 13 → 16 | 16 | 173 KB |
  | nacre-engine | 15 → 20 | 16 | 205 KB |
  | meridian-exchange | 18 → 33 | 18 | 362 KB |
  | ember-crucible | 25 → 31 | 20 | 333 KB |
  | ion-speedway | 23 → 36 | 20 | 260 KB |
  | aurora-stadium | 20 → 32 | 20 | 289 KB |

  The library's own coverage accounting (`coverage()` in the same census):
  **8 families, 25/31 textures, 13/13 baked normals, 5/5 LUTs, 28 derived
  planes, 11 unused keys** left (was: all 13 normals and most textures unused).
* **Cadence.** Software-GL medians over 40 frames per view are in
  `evidence/cost-table.md`; most views got faster because the family shader
  writes no `DEPTH` (early-Z returns on arena/identity/presentation surfaces),
  while Cinder (+6 ms mean) and Prism (+16 ms) pay for the added data/normal
  fetches on large surfaces. These numbers run on a shared llvmpipe host, so
  treat them as directional; the deterministic costs (draw calls, materials,
  bytes) are the hard evidence.
* **Glow.** Core look holds with glow off; the glow-on A/B
  (`evidence/review/glow-ab-1280x800.jpg`) only adds bloom on the LUT accents.

## Render-only proof

`node --test port/native-arenas/tests/actual-maps.mjs` re-run after the pass —
identical geometry hashes (`evidence/gates/geometry-hashes.json`):

```
prism-foundry  c727d8ca82f761c710af0c535c8502ccfbbaed2299ace1f9923cb74e3b3e9c13
aurora-basin   94f1c30664dfcf058c005a7aa2dea296e8528b1acf772b4f04e66421d243382d
cinder-array   f372c98c4172b7885218748031c9eed7f7a087dc9f347491ac04bb558ac10cca
```

No arena compiler was run; no source, terrain, collision, spawn, pickup or nav
data was touched.

## Gates re-run after the pass (all green)

| Gate | Result |
|---|---|
| `graphics-terrain` | `GRAPHICS_TERRAIN_RESULT passed=true checks=51583 maps=9` |
| `graphics-atmosphere` | `ATMOSPHERE_VERIFY maps=9 ... failures=0` |
| `graphics-fx` | `MOTH_VFX_REGRESSION failures=0` |
| `moth-scenery` | `MOTH_SCENERY_VERIFY ... failures=0` (geometry hash unchanged) |
| `moth-resources` | `MOTH_VALIDATION planes=101` (101-plane inventory unchanged) |
| `shader-lab` | `SHADER_LAB_CONTRACT_OK checks=68` |
| `identity-maps contract` | `IDENTITY_CONTRACT assertions=105 failures=[]` |
| `aurora-traversal` | `AURORA_VALIDATION checks=593 failures=[]` |
| `cinder-traversal` | `CINDER_VERIFY assertions=1246 failures=[]` |
| `viewer-smoke` | `PORT_VIEWER_SMOKE_OK maps=9 cycles=2 unknown=rejected` |
| `actual-maps` (node) | 3/3 pass, geometry hashes unchanged |

## Evidence

* `evidence/{960x640,1280x800}/{before,after}/` — fixed-camera PNGs and the
  per-view manifest (cadence, draw calls, primitives, video memory, unique
  materials/shaders/textures, Moth cache). 42 views × 2 sizes per phase.
* `evidence/review/*.jpg` — labelled before/after sheets per playable map and
  per locked map, plus two composites (`six-playable-1280x800.jpg`,
  `all-nine-locked-1280x800.jpg`) and `glow-ab-1280x800.jpg`.
* `evidence/cost-table.{json,md}` — the cost table with per-view deltas.
* `evidence/census-after.json` — per-map materials/textures/caches and the
  library coverage/budget snapshot.
* `evidence/gates/` — the post-pass gate logs and the geometry hashes.

The 1280×800 PNGs for the seven locked maps that are not the two featured in
the report (`meridian-exchange`, `ember-crucible`) are pruned from the commit to
keep it ~83 MB instead of ~102 MB; their review sheets are already built from the
full set, and re-running `run.py` regenerates every PNG in about three minutes.

Re-run (private Xvfb, private temp, staged copy of `godot/`; the shared
`.godot` cache is never touched):

```
python3 port/native-material-apply/run.py --phase after --census     # capture + census
python3 port/native-material-apply/run.py --phase after --glow --maps=ember-crucible --size=1280x800
/home/mojo/.hermes/releases/hermes-agent-*/venv/bin/python port/native-material-apply/review.py
```

## Honest notes — what is worse or unfinished

1. **The locked maps' `street` camera is not a good framing on every map.**
   `aurora-stadium`'s street pose sits inside a solid block: the frame is a
   magnified material close-up, useless as a composition reference. `meridian`
   and `ember` street views are the ones to read; all nine `authored`
   (arrival-pose) views are good. The pose is frozen in the manifest, so the
   before/after pair is still valid for the pixel comparison.
2. **Aurora Basin's plaza ice density is the largest single appearance change.**
   The plaza now reads as fine cracked ice at 0.26 tiles/m. It is honest bump on
   real ice, but if the owner prefers the near-smooth pre-pass plaza, set
   `snow.texture_strength`/`normal_strength` to 0 in `environment_style.gd`
   (one role, one line).
3. **Standalone exploration demos keep the pre-pass materials.** The game's
   native mode composes Prism/Aurora/Cinder from
   `native_arenas/maps/*.gd` (upgraded), but the standalone
   `showcase/demo.tscn`, `aurora_basin/demo.gd` and `cinder_array/demo.gd`
   entry points build from `showcase/demo.gd` / `aurora_basin/map.gd` /
   `cinder_array/map.gd`, which are not in this lane's ownership. Fixing that
   is a three-line `_make_materials()` override in those files, for the lane
   that owns them; `aurora-traversal` and `cinder-traversal` therefore still
   measure the pre-pass material set (and stayed green).
4. **Terrain still runs `moth/surface.gdshader`, not the family shader.** The
   locked support surfaces rely on its `DEPTH = FRAGCOORD.z + UV.x·1e-6`
   priority tie-break (`viewer.gd` writes priority into UV.x). The family
   shader has no DEPTH write; moving terrain onto it would change the
   coincident-surface tie-break and lose an inherited contract this lane does
   not own. Reported to lead as a possible future unification; the terrain
   still gets the family normals, which was the requested part.
5. **Scenery props are limited to normals.** `tests/moth_scenery/verify.gd`
   asserts every scenery child's `material_override.shader` is the shared panel
   or mote shader, so the pass could not move plate materials onto the family
   shader. The plates now resolve their normal through the material language
   (including the derived bucket) and carry a per-kind normal depth, and the
   shader count stays at two by design. A family-material scenery pass needs the
   shared test to allow the family shader — not weakened here, reported instead.
6. **Structural LUT sheen is deliberately small.** The library's cold sheen
   (`entanglement`) reads as a cyan moiré on long continuous metal at grazing
   angles, so rails/props/grates carry `lut_gain 0.0` and only hazard,
   machinery, display and organic roles keep an accent. If the owner wants more
   of the library's accent language on structure, that is a one-number change
   per role.
7. **Cadence noise.** The software-GL cadence numbers were captured on a shared
   host with other lanes running; the median moved by tens of ms between runs
   on identical sources in earlier probes. Trust the draw-call/texel/byte
   columns, not the millisecond deltas.
8. **Not covered at all:** projectiles, actors, weapons, UI and effects keep
   their own material languages; this pass is world surfaces only. The
   `explosion`/`heal`/`teleport`/`capture-ring`/`weather-snow`/`quantum-rift`/
   `qrc-glyphs` effect planes are the effects lane's scope, not this one.
