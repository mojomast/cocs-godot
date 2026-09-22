# Orchestrator handoff — identity trilogy: collision cost fixed, materials and effects delivered

Not a playable-release delivery. Direct research, a source-tested renderable prototype and now the
art/performance pass are in place. Shared production integration, final visual acceptance, the
existing-playable-map pixel review and every release gate remain open. Do not publish these maps as
finished.

## Ownership and baseline

Branch `port/godot-destinations`, working tree at `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
(HEAD includes merged prototype `f1f77347`). This pass touched only the lane's owned paths:
`godot/identity_maps/**`, `tools/godot-identity-maps/**`, `godot/tests/identity_maps/**`,
`port/native-identity-maps/**`. Nothing in `godot/source_operators/**`, `godot/world/presentation.gd`,
`tools/godot-operators/**`, `port/native-source-operators/**`, `port/native-arena-review/**`,
`godot/tests/native_arena_review/**`, `port/native-arenas/**` (read-only imports only),
`godot/native_arenas/**`, `tools/godot-dev/**`, `tools/godot-package/**`, `game/**`, `server/**` or
any shared document was modified. The arena lane's `schema.mjs`/`catalog.mjs` are consumed read-only.

## Read in this order

DESIGN.md (routes, material boards, effect boards, collision model) → PERFORMANCE.md (cost, cadence,
baseline, budgets, what is unproven) → PLAY.md (exact commands) → `evidence/README.md` (what each
artifact is, which failures are kept on purpose) → RESEARCH.md (three research tracks; the collision
risk it raised is now closed).

## What this pass delivered

1. **Collision cost (blocking issue from the previous milestone) — fixed.** Cold
   `createIdentityMatch` went from 6,059 / 2,950 / 14,828 ms to **27.4 / 19.4 / 39.2 ms** (target
   ≤1,500 ms, ceiling 3,000 ms). Ground-level solids are exact source boxes; visible masses that need
   rays AND movement use authored planar quads, end trapezoids, caps and two-point movement fences
   (20 / 0 / 168 wall entries, 40 / 0 / 504 segments). Render geometry stays exact in `recipe.art[]`
   and owns no physics. `arena.nextGen` (the existing source navigation mode the native DM arenas
   already use) replaces the O(n²) edge build. `graybox.test.mjs` now gates cold time, segment
   budget and a ≥10× speed-up versus the prototype baseline on every run.
2. **Parity proven where it matters, not asserted.** `ray-oracle.mjs` rebuilt the prototype's
   one-wall-per-art-triangle representation from the same visible triangles and compares it against
   the shipped arena: 19,976 rays, **0 classification mismatches, 0 `visible()` mismatches, 0
   reachable-visible-mass misses**, with 448 knife-edge rays flagged and their 104 divergences
   counted separately. `rays.gd` re-answers every fixture in Godot physics: **0 failures, max hit
   delta 2.1e-6 m**.
3. **Materials/shaders.** Six shared materials per map built from the Moth registry
   (`moth/surfaces.gd`, world-space triplanar, Compatibility-safe), one shader-backed material per
   semantic key, no per-surface instances, palette colors authoritative in the generated JSON.
   Texture allocation is 106,496 / 100,352 / 99,328 bytes per map — three orders of magnitude under
   the 32 MiB budget. Trim/bevel detail is a render-only MultiMesh layer (≤52 instances, 2 draw
   batches, ≤5 cm proud) and never owns collision or changes silhouette.
4. **Bounded signature effects.** One pool per map, one shared draw shader/material per map, fixed
   seeds, `visibility_aabb`, 4 Hz distance gate, focus-loss and pause suspension, `reset()` for round
   boundaries, no per-frame allocation, no gameplay authority: High 3,360 / 1,080 / 3,830 and Low
   880 / 320 / 1,090 against the 32,768 / 8,192 budgets.
5. **Evidence.** 45 PNGs across three asserted resolutions, a before/after cost table, a shipped
   native DM baseline under the same harness, cold/warm builds, draw calls, texture accounting, and
   the intermediate failures that drove the geometry changes.

## Generated-content contract (unchanged shape, new hashes)

The envelope is unchanged: `{schemaVersion, id, name, mode, geometryHash, arena{id,name,bounds,spawns,
pickups,navNodes,blocks,terrain{maxSlope,surfaces,walls},voidY,ceilingY?,raised?,nextGen?}, palette,
art[], routes, cameras, landmarks, grayboxHash, spawnPoints, colliderSources, provenance}` plus
`artNotes[]` (new, additive: per-form collision rationale). All three recipes pass the arena lane's
strict `parseIdentityArena` unchanged.

**geometryHash changed for two maps.** Report these to the lead before any consumer caches them:

| Map | geometryHash |
|---|---|
| lacuna-court | `a87f8e7a95e56b30d896d70078431152f46160e2d2639c97493b14f68915cfa9` |
| vermilion-fold | `6253164eed12dc961af30535d2aaf9dafea34558742bb9a8cb66446faeb6bf2a` (unchanged: art-only edit) |
| nacre-engine | `b3636effceec400a84a59107386f531d627d72c353391f66d51c18776179feb4` |

`arena.blocks` gained two exact Nacre boxes (the amber service organs, previously art without
collision) and `arena.terrain.walls` is now the authored collision set instead of triangle soup.
`objectiveZones` (3, Vermilion), `teamSpawns` (west/east), spawns, pickups, routes, cameras and
landmarks are unchanged.

## Integration seams this lane now provides (still needing lead approval to wire)

1. `godot/identity_maps/map.gd`: `build(id, graybox)`, `get_arena_id()`, `get_spawn_points()`,
   `metrics_snapshot()`, `set_fx_quality("Low"|"High")`, `reset_fx()`. Render and collision are
   separated inside it; a session composition should use it as the environment and call `reset_fx()`
   on round boundaries.
2. `godot/identity_maps/style.gd`: `create(map_id, palette)` (materials),
   `configure_environment(map_id, world_environment, sun)` (sky/light/fog; reuses the atmosphere
   lane's `horizon.gdshader` read-only) and `decorate(...)` (render-only horizon/skyline). A viewer
   that owns its own environment can skip 2 and keep 1.
3. `godot/identity_maps/signature_fx.gd`: `configure(recipe, camera)`, `set_quality`, `set_paused`,
   `reset`, `snapshot`.
4. The DM/Domination/Horde authority hooks, launcher/menu/package routes and the production
   client map-loading seam remain parent-owned and untouched.

**Packaging note for the package lane.** `identity_maps/map.gd` now preloads
`identity_maps/style.gd` (which preloads `moth/surfaces.gd` + `moth/library.gd` and reads
`res://moth/generated/manifest.json` plus the referenced 48-64 px tiles),
`identity_maps/signature_fx.gd` (which preloads `identity_maps/signature_particle.gdshader`) and,
through `style.gd`'s environment helper, `graphics_atmosphere/horizon.gdshader`. The capture and
inspection scenes additionally use `style.decorate`. Any Godot resource closure for these maps must
include those files and the Moth manifest/tiles, or the packaged maps will fail to load with a
missing preload rather than a visible error. The native-arena composition already installs its own
environment for identity maps (`native_arenas/identity_environment.gd`) and treats `map.gd` as
geometry-only, which matches this builder: `map.gd` itself adds no light and no WorldEnvironment.

## Retained failures and fixes (this pass)

1. Nacre vault-foot proxies first used non-planar fan quads: the source fans a quad from `v0`, so a
   non-planar quad creases and the intended face is not covered (246 reachable-mass probe misses,
   224 classification mismatches). Fixed with planar face quads + end trapezoids + caps + fences.
2. Nacre's joint band was radially inset but z-offset from the main rib, so one proxy could not
   follow both without over-covering the inner face. Fixed by centring the joint band on the same z
   and following its ellipse.
3. A 0.3 m amber service fin proud of the housing face was art with no collision: a source ray
   stopped at the housing face where the prototype stopped at the fin. Converted to an exact block.
4. `colliderSources` initially emitted entries for two-point movement fences, which have no Godot
   collider and which the strict parser rejects (`vertexCount >= 3`). Fences are now excluded.
5. First `capture.gd` rig used `BG_COLOR` and a bare rig; the horizon/panorama looked like a smog
   dome. Replaced with a map-styled sky (shared horizon shader + Moth panorama), linear fog and a
   render-only distant ground/skyline.
6. First dust/pulse effect pass read as ground smudges (0.16-1.6 m soft discs, permanent emission).
   Now: ≤0.1 m motes, one-shot pressure bursts with a scale curve, and one shared draw material per
   map.
7. `map.gd` briefly set `Mesh.ARRAY_NORMALS`, which does not exist (parse error). Caught by the
   headless contract test, not by inspection.

## Blocking work remaining before integration acceptance

* Human pixel review of the delivered renders; this lane only checked gross defects.
* Existing-playable-map baseline at 1920×1080 and a representative-GPU cadence pass; llvmpipe
  numbers do not certify the hardware target.
* Lightmap/AO decision (no bake attempted), occlusion/LOD comparisons.
* Live actor/operator/ADS readability at 10/25 m, Horde peak load, and the ten-wave/boss/endless
  behaviours that the prototype never proved.
* Packaged Windows/Linux runs after the parent wires the route, launcher and session composition.
