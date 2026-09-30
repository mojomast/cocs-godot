# The Quiet Relay — world implementation

## Interfaces and ownership

- `port/native-campaign/maps.mjs` exports the frozen, ordered `CAMPAIGN_MAP_IDS`,
  `loadCampaignMap(id)`, `parseCampaignMap(input, expectedId?)`, and the exact
  single-sheet helper `campaignSupportAt(arena, x, z)`.
- `loadCampaignMap` rejects unknown IDs before constructing a filename and returns
  an independent validated envelope. Arena geometry is source-compatible; no
  multiplayer registry or validator was changed. Geometry hashes use the existing
  recursively canonical SHA-256 convention.
- `godot/campaign/terrain.gd` extends `Node3D` and provides `build(id) -> bool`,
  `recipe`, `height_at(x,z)`, `get_arena_id()`, `get_spawn_points()`, and
  `visible_cost()`. Same-ID builds are idempotent; another valid ID rebuilds.
  Invalid IDs return false and retain the current map.
- All envelope points/anchors are **feet coordinates**, directly suitable for
  source actor spawn/mission logic. The renderer does not offset actors.
- `height_at` interpolates the exact emitted diagonal, with bounds read from the
  map and a reviewed 4 m grid. Out-of-bounds height queries return `NAN`; source
  helper queries return null. Steep triangles remain visible/collidable, but the
  source helper only returns support within the arena's 0.65-radian slope limit.
- Each chapter has the required five encounter anchors, start, exit, six routes
  (ordered critical route plus one complete local combat loop per encounter),
  21 spawn positions, and 17 pickups. Spawn zero is the player arrival; the next
  twenty are four supported deployment positions per encounter. **Authority
  chooses deployment/checkpoint positions; these are not automatic enemy waves.**

## Geometry and measured authored budget

Generated using `node tools/godot-campaign/compile.mjs`.

| Map | Footprint | Area vs 96×80 arena | Ordered route | Walkable arrival → exit | Terrain triangles | Terrain chunks | Authored art instances |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rootfall Verge | 320×224 m | 9.33× | 1,047.5 m | 4 → 18 m | 8,960 | 180 | 929 |
| Siltwake Crossing | 352×256 m | 11.73× | 1,204.1 m | 18 → 36 m | 11,264 | 240 | 903 |
| Emberline Ascent | 384×256 m | 12.80× | 1,332.0 m | 36 → 62 m | 12,288 | 262 | 864 |
| Crown Array | 416×288 m | 15.60× | 1,489.3 m | 62 → 72 m | 14,976 | 278 | 1,041 |

Measured mandatory-gate walking estimates (4 m grid, all seven gate disks in
order) are **958.2, 1,121.4, 1,241.5, 1,401.5 m**, respectively: **91.5–94.1%**
of the authored route budget. These account for legal corner cutting inside the
corridors; they exclude jumping and are not a formal speedrun lower bound.

Nearest ordered-route chainages of encounters 1–5 (metres):

- Rootfall: **87.9, 379.4, 597.9, 726.6, 959.6**.
- Siltwake: **101.1, 437.0, 687.8, 834.8, 1,103.1**.
- Emberline: **112.0, 483.3, 756.8, 925.7, 1,220.0**.
- Crown: **125.2, 541.1, 847.2, 1,034.3, 1,364.1**.

The longer travel intervals contain a saddle/bridge vista and intermediate
beacons at 42 m intervals. Local supply loops are ~125 m long, reconnect at
both ends of the combat field, and place health, armor, and ammunition away from
the direct firing lane. Encounters 2 and 4 add scatter/rocket pickups. Four
staggered physical cover pieces surround each 8 m clear central deployment disk.
The mandatory route passes within 6 m of each 12 m objective disk.

**These lengths are not a duration claim.** At 8 m/s, authored travel alone is
131–186 seconds; sprinting is faster. The 300–600 second target requires the
authority's combat/interaction pacing and first-playthrough human measurement.
There are no world-imposed timers or artificial traversal waits.

## Geography, tactical structure and identity

Every chapter follows four inhabited terraces around three long rock spines.
Each spine has a **solid, source-authoritative block barrier**, rising at least
5 m above its sampled crest, terminating at alternating authored saddles.
Steep triangulated ridge shoulders accompany these barriers. Thus the long route
is a corridor imposed by geography, not a painted serpentine on open ground.
Combat clearings widen the terrain around the five objectives; the route narrows
again before its next landmark. The player's central entry lane, inner cover,
and outer supply loop support different tactical positions rather than one
doorway firing position.

- **Rootfall**: moss/fern-coloured ravine, asymmetric faceted trees on the
  shoulders, fallen lattice relay, archive receiver and stone relay ruins.
  Vegetation fades out over the final fifth toward Siltwake's exposed geology.
- **Siltwake**: ochre sandstone, exposed crags, riverworks receivers and a metal
  bridge deck over a sculpted dry gully at the first saddle. The bridge has real
  parapets and towers. Its support is the terrain sheet
  itself: there is deliberately no second hidden floor or walkable underpass.
- **Emberline**: charcoal basalt, rising service terraces and column groups,
  metal switching infrastructure and a 22 m uplink receiver silhouette.
- **Crown**: pale industrial stone and returning highland canopy; seven varying
  crown fins and a 30 m receiver overlook the guardian court. The five encounter
  fields preserve space for multi-legged robots and readable attack motion.

Arrival/departure pylons reuse the same proportions and mint guidance colour.
Adjacent chapter exit/start feet heights agree **exactly** (18, 36, 62 m).
Rootfall's final sandstone reach becomes Siltwake; the riverworks lift leads to
basalt terraces; the uplink's pass opens into Crown woodland. Chapters have local
coordinate origins and load through the authority's transition, not continuous
simultaneous streaming of four maps.

## Shared collision, bounded presentation and parsing

- Terrain is a single, continuous triangulated support sheet. Compiler feet
  heights, source support and Godot interpolation use the same cell vertices and
  diagonal, including the two different triangle halves. No analytic render-only
  floor is substituted at runtime.
- Terrain material/chunk groups cover at most a 32×32 m region. Godot emits exact
  local-coordinate meshes and concave collision per group. Terrain is never
  range-hidden. All block `baseY` values are zero, matching source spatial
  movement/rays' actual `[0,h]` solid convention and Godot box shapes exactly.
  Source ignores nonzero `baseY`: an initially authored bridge crossbeam was
  caught by the actual movement test, removed, and the suite rerun successfully.
  Raised decorative receivers/mast lattice are explicitly presentation-only;
  there are no overhead authoritative block underpasses.
- Scenery is deterministic and bounded: 1,100 tree/crag scatter attempts plus
  2,400 small fern/scrub attempts per map, rejected near central routes/clearings,
  plus authored landmark/guidance props. Ridge scatter trees/crags are
  presentation-only and stand outside traversable clearings. Accessible shoulder
  trees have authoritative narrow grounded trunk blocks.
  Architectural cover, pillars, bridge rails, ridge barriers and pylons are
  authoritative blocks.
- Props and blocks use spatially grouped MultiMeshes. Their origins are the
  local 32 m cell, not world zero. Every custom AABB is the union of transformed
  mesh bounds, including crown overhangs and tall receiver ornaments. Tree/crag
  batches have a 650 m visibility range (preserving overview silhouettes), and
  small ferns/scrub use 140 m; physical solids, receivers, and beacons are
  retained. Full geometry, including boundary block meshes, has
  correct extended cull bounds rather than being clipped to its nominal cell.
- The strict campaign parser caps file size, recursive JSON complexity, field
  sets, array sizes, map IDs/order, finite coordinates and reviewed dimensions
  up to 512 m. It validates complete non-overlapping regular cell coverage,
  shared-vertex seams, exact triangle winding/indices, source hash, spawn/anchor
  support, ordered gates, route grades, swept route clearance and block overlap.
  Existing multiplayer bounds remain unchanged at their original limits.

## Research applied

The shared `RESEARCH.md`/`CONTRACT.md` were read before implementation. Source
pages consulted directly:

- [Level Design Book: encounters](https://book.leveldesignbook.com/process/combat/encounter)
  — entry footholds, deliberate before/during/after structure, readable combat
  fronts, and reasons to leave the doorway. Applied through open entry lanes,
  distributed cover, optional loops, reward placement and distinct landmarks.
- [Godot: MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
  — a MultiMesh is all-or-nothing for instance culling. Applied through spatial
  batches, local origins and explicit transformed bounds instead of one giant
  forest batch. The current web page identifies itself as 4.7 documentation;
  implementation uses existing project-compatible Godot 4.x APIs.

## Verification and remaining evidence

Completed in the worlds lane (all heavy invocations serialized with
`LP_NUM_THREADS=1`):

- Lightweight compiler generation and strict parse for all four maps.
- Node syntax checks for parser and terrain tests; `git diff --check`.
- Explicit authored route, triangle/chunk/prop, chainage, handoff and hash metrics.
- **13/13 Node tests passed**, including actual source movement on every
  critical route and all twenty flank loops, independent source triangle support,
  gate-route metrics and parser rejection checks.
- Godot **4.5.2.stable.official.6ce3de25a** headless physics/terrain test:
  `CAMPAIGN_TERRAIN failures=0` for all four maps.
- Real GL compatibility run under Xvfb/llvmpipe: `failures=0`, including querying
  real renderer MultiMesh instance transforms for cull bounds. In dummy headless
  mode Godot returns identity instance transforms; the headless test uses the
  bounded CPU transform mirror instead.
- **Twelve 1280×720 PNG captures**: one overview and two player-height views per
  map. Reviewed all twelve in `worlds-contact-sheet.png`; the final visual pass
  repaired coplanar housing/pier faces, added shoulder vegetation and low scrub,
  retained forest silhouettes in vistas, and broke up the perimeter skyline.

Reproduction:

```sh
LP_NUM_THREADS=1 node --test tools/godot-campaign/terrain.test.mjs
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/campaign/terrain.gd
LP_NUM_THREADS=1 xvfb-run -a "$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/campaign/terrain.gd -- --render="$EVIDENCE"
```

The Node suite compares deterministic generated content, independently checks
feet against `game/terrain.mjs`, drives **actual source `moveActor` through every
segment of the critical route and all five loops**, and rejects malformed map
geometry/metadata. This catches the source 0.3 m per-move rise rejection rather
than treating endpoint support as movement proof.

It also prints a 4 m-grid, walking-only shortest-route estimate through the
mandatory encounter disks. Graph edges sample swept terrain/cover clearance;
multi-source distances carry the actual arrival state through successive gates.
It asserts the estimated required travel remains >78% of the authored route and
>800 m. Final measured values are reported above.
The metric excludes jumping and is not a formal speedrun lower bound. Human
shortcut/flow review is still needed.

The Godot suite checks every chapter's route feet against real physics ray hits,
both terrain/interpolation agreement and MultiMesh bounds, invalid-ID behavior,
and bounded geometry/scenery counts. It requires engine import/physics work.

Evidence retained outside the worktree at
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/worlds/`:

- `compiler-final.log`, `node-terrain-final.log`, `godot-terrain-final.log`,
  `godot-render-final.log` and twelve map/view PNGs plus contact sheet.
- Initial failure/diagnostic logs are retained. The first editor import crashed
  during audio asset import; the single incremental retry exited successfully.
  The first source movement failure documents the unsupported overhead block
  assumption; the final run passes after correcting the geometry.

Not yet established: real hardware performance (renders used llvmpipe), human
5–10 minute timings, encounter balance, robot-versus-cover readability, or
end-to-end chapter transitions with the other lanes. The four maps deliberately
share a power-corridor terrace macro-layout; biome geology, ascent, vegetation,
bridge gully and receiver/crown silhouettes provide their differences. This is
not four unrelated open-world layouts. The worlds lane did not edit the launcher,
authority, client, robot models, or locked source gameplay.

Final geometry hashes:

```text
rootfall-verge      e80dd423ac730db881aefe308683c94f62cfbf756a4dff56d9e4ea2624969dd0
siltwake-crossing   398500b3bc89ae1ad8b29bf7bd4c8c305a251bd1f543eef3a0ac919b530f3945
emberline-ascent    b746300f0ebb834bb4dc8b4b4d1de5ed2cdfa973d0b05b6438a440f3a8b62207
crown-array        47245c9a95cb2e8485f9ba66a0adf32423aa08023abdcec3ced4220440bdf9fd
```
