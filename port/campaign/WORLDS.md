# The Quiet Relay — authored worlds, terrain-variety revision

The first worlds revision proved collision, scale and interfaces but repeated a
parallel-trench macro-layout. Parent visual review rejected that repetition.
Revision 2 replaced those footprints. The user then rejected its repeated
sawtooth ridges. This revision preserves the four footprints and interfaces but
replaces the ridge construction, rock massings and skyline distribution.

## User-requested terrain variety

The teeth had several causes: a near-uniform 8 m ridge rise on a 4 m grid,
nearest-route-segment floor discontinuities propagating into crests, periodic
vertex detail, dense tall-prism scatter, flat per-triangle normals and whole-cell
material boundaries that drew bright triangular fringes along slopes.

The replacement is actual shared terrain geometry, complemented by appropriate
shading rather than a colour-only change:

- Low-frequency, unequal 35–100 m landforms establish independent upland heights.
  Weighted surrounding road elevations avoid nearest-segment height jumps.
- Irregular rise/setback profiles form weathered fans, benches, shelves and
  plateaus. Four unequal Rootfall island noses preserve required ravine bends
  while intervening shoulders can open out. Combat floors are coherent shallow
  planes across their entire flank circuits.
- Two compact antialiasing passes affect exposed transitions only, protecting
  walkable floors and retaining broad authored landforms. Shared vertex normals
  and interpolated soil/gravel/rock transitions remove grid-frequency shading
  fringes without changing collision triangles.
- Rootfall uses softer vegetated shoulders and weathered boulders; Siltwake uses
  layered bluffs, benches and spurs; Emberline uses massive planar basalt shelves
  and slab breaks; Crown uses broad highland shoulders and selected hero crags.
- Four different rock solids replace the repeated prism: weathered boulder,
  layered mesa, basalt slab and leaning broken spur. Scale, orientation and
  cluster density vary. Bases are sunk using footprint terrain samples.
- Distant rocks form a few unequal clusters with large gaps, rather than a
  uniformly populated perimeter. The collar has non-periodic large landforms.

The final meshes retain the original **4 m resolution and triangle counts**.
A verified 2 m experiment quadrupled triangles and increased this machine's full
Node suite from about 25 s to 186 s; it was rejected. The broad landforms and
edge treatment also worked at 4 m. Parser/height indexing can decode the two
reviewed resolutions, but all committed recipes use 4 m.

## Four distinct footprints

- **Rootfall Verge — winding forest ravine.** Three off-axis sweeps curve around
  irregular wooded ridge islands, with variable 10–12.5 m half-widths, rolling
  ravine floors and widened combat clearings. Fallen lattice equipment, low stone
  archive ruins and small receivers replace the repeated entrance columns.
  Vegetation fades into exposed geology near the Siltwake handoff.
- **Siltwake Crossing — riverbank/causeway circuit.** The route alternates banks,
  overlooks and two river crossings, then turns inward along the opposite bank.
  A separately carved low river channel and bounded water strips appear below
  the single-sheet causeways. Paired pump pipes, receiver installations and
  bridge towers give this chapter its own industrial silhouette.
- **Emberline Ascent — angular highland switchbacks.** Orthogonal service cuts,
  diagonal ascents and projecting basalt terraces form an irregular stepped
  circuit. Five authored elevation terraces concentrate climbing into broad
  ramps rather than one imperceptibly sloped floor. Column groups and tall
  radiator/uplink banks replace the forest/canyon landmark kits.
- **Crown Array — perimeter into nested service courts.** An outer highland
  approach contracts into an inner octagonal/spiral circuit and the guardian
  court. The walkable floor rises and dips between courts. Pale buttresses,
  receivers and seven crown fins frame the final 30 m dish.

Every encounter has a widened clearing, four staggered physical cover pieces,
an 8 m clear central deployment disk, and a complete local supply loop. Loops
and cover are oriented to each encounter's local approach, not world-axis rows.
Health/armor/ammunition sit on the side circuits; encounters 2 and 4 add
scatter/rocket pickups. Guidance beacons follow route shoulders every 42 m.

Grounded, buried cliff cores follow the actual ridge contours. Each core's top
is below **all nine terrain vertices across its 8×8 m footprint**, ensuring the
box remains inside the rock volume rather than appearing as a rectangular wall.
These cores and steep terrain shoulders prevent the long route from becoming a
painted serpentine on otherwise open ground. There are no visible rectangular
perimeter walls.

## Measured route and geometry budget

Generated with `node tools/godot-campaign/compile.mjs`.

| Map | Footprint | Area vs 96×80 arena | Ordered route | Mandatory-gate walking estimate | Arrival → exit feet |
|---|---:|---:|---:|---:|---:|
| Rootfall Verge | 320×224 m | 9.33× | 1,010.0 m | 904.8 m | 4 → 18 m |
| Siltwake Crossing | 352×256 m | 11.73× | 1,208.0 m | 950.2 m | 18 → 36 m |
| Emberline Ascent | 384×256 m | 12.80× | 1,383.5 m | 1,098.6 m | 36 → 62 m |
| Crown Array | 416×288 m | 15.60× | 1,360.4 m | 1,084.8 m | 62 → 72 m |

Mandatory estimates are 4 m-grid walking routes through all seven gate disks in
order. Edges sample swept terrain/cover clearance; the same arrival state is
carried through each successive gate. They account for legal corner cutting,
exclude jumping, and are not formal speedrun lower bounds. Tests require **over
900 m** and over 78% of the authored route budget. All four pass.

The normalized critical-route occupancy is also compared pairwise on a 20×20
grid. Jaccard overlap must stay below 55%; this catches a regression back to
resized copies of the same footprint. Exact adjacent handoff heights (18, 36,
62 m) are tested independently.

| Map | Terrain triangles | Terrain groups | Horizon groups | Recipe art props | Source blocks | Nav nodes |
|---|---:|---:|---:|---:|---:|---:|
| Rootfall | 8,960 | 179 | 112 | 893 | 353 | 287 |
| Siltwake | 11,264 | 215 | 104 | 562 | 404 | 322 |
| Emberline | 12,288 | 237 | 96 | 607 | 497 | 350 |
| Crown | 14,976 | 279 | 144 | 842 | 444 | 348 |

Scenery/solid MultiMesh instance totals including the horizon are respectively
1,360 / 984 / 1,115 / 1,371. These are bounded allocated counts, not measured
on-screen draw calls. Terrain material groups occupy at most 32×32 m; scenery
batches use local 32 m origins. The horizon uses 64 m groups.

**Length does not prove duration.** Travel alone takes about 126–173 seconds at
8 m/s, less when sprinting. The 300–600 second first-playthrough target still
requires encounter/interaction pacing and human timing. No forced waiting or
world-imposed match timer is used.

## Original biome presentation restored

The renderer reuses the actual existing assets from `godot/biomes/map.gd`:
branching trunks, asymmetric lobed crowns and fern blades. Rock meshes now use
the four distinct geological solids described above.
Their vertex colours and normals are retained while normalizing the assets for
metre-based recipe scaling. It also directly reuses:

- `res://biomes/surface.gdshader`: world-space coarse/grain detail and rock seams,
  with distinct moss/soil, gravel, rock, stone and metal materials.
- `res://biomes/foliage.gdshader`: original leaf/bark treatment and subtle wind.

Unused MultiMesh custom-data streams are deliberately disabled: enabling them
in this compatibility-render path blackened the original foliage. The final
rendered leaf colours were visually reviewed; the mesh colour contract is also
tested. Vegetation AABBs include a conservative 2 m wind margin.

Gentle forest/highland ridge tops use ground/moss material, while steep faces
remain rock. A **192 m stitched scenery collar** samples the exact map boundary
heights and blends into irregular surrounding hills. Bounded outer trees and
cliffs complete the skyline, avoiding a floating rectangular diorama. The collar
is presentation-only outside authoritative bounds, never substitute gameplay
support. It adds no source navigation or collision.

Large vegetation/crags retain a 650 m range for vistas; small ferns/scrub use
140 m. Physical solids, landmarks and beacons are retained. All cull boxes are
unions of transformed mesh bounds, not arbitrary cell-sized boxes.

## Integration contract (unchanged)

- `port/native-campaign/maps.mjs` exports ordered/frozen `CAMPAIGN_MAP_IDS`,
  `loadCampaignMap(id)`, `parseCampaignMap(input, expectedId?)`, and
  `campaignSupportAt(arena,x,z)`.
- Loading rejects unknown IDs before filename construction and returns an
  independent strictly validated envelope. No multiplayer registry/schema was
  loosened. Canonical hashes retain the existing recursive SHA-256 convention.
- `godot/campaign/terrain.gd` is `Node3D` with `build(id) -> bool`, `recipe`,
  `height_at(x,z)`, `get_arena_id()`, `get_spawn_points()`, and `visible_cost()`.
  Same-ID builds are idempotent; a different valid ID rebuilds; invalid IDs retain
  the current map and return false.
- Envelope coordinates are **source feet heights**, without actor visual offsets.
  Each map retains five encounter anchors plus start/exit, six routes, 21 spawn
  points, and 17 pickups. Spawn zero is arrival; the next twenty provide four
  deployment points per encounter. Authority owns actual deployment/checkpoints.
- Heights interpolate the exact 4 m cell diagonal used by source triangles.
  Godot out-of-bounds queries return `NAN`; source helper queries return null.
  Steep terrain is rendered/collidable but only slopes ≤0.65 radians provide
  source walkable support. Source and Godot consume identical terrain triangles.
- All blocks use grounded `[0,h]` geometry. Source movement/rays ignore nonzero
  `baseY`; revision 1 caught an overhead bridge beam blocking actual movement.
  It was removed. No authoritative overhead block underpass is used here.
- Campaign validation checks bounded JSON, exact field sets/order/IDs, finite
  geometry, complete regular cell coverage, shared seams, triangle winding,
  supported feet, ordered anchors, route continuity/clearance, and geometry hash.
  Campaign blocks are bounded at 1,024; dimensions remain reviewed up to 512 m.
  Multiplayer's original 160 m limit remains unchanged.

The new renderer preloads the existing biome map script and both shaders. Release
resource closure must include these existing resources and their static script
dependencies. No original biome file was edited.

## Verification and retained evidence

All heavy work ran serially with `LP_NUM_THREADS=1` and the pinned Godot
`4.5.2.stable.official.6ce3de25a`.

- **20/20 Node tests pass**, including actual source `moveActor` through every
  mandatory path segment and all twenty local loops, independent source triangle
  support checks, mandatory gate metrics, strict parser rejection, independent
  footprint checks and exact chapter handoffs. At least three of Crown's four
  authored guardian spawn points also pass a **1.65 m radius** footprint check,
  with 16 supported perimeter samples and grounded-block clearance.
- Godot headless test: **`CAMPAIGN_TERRAIN failures=0`** across all four maps.
  Checks compare feet/interpolation with real physics ray hits, verify cull
  bounds, foliage colours, and bounded terrain/horizon/instance counts.
- GL compatibility test under Xvfb/llvmpipe: **zero failures**, including reading
  real renderer MultiMesh transforms. Dummy/headless uses the bounded CPU mirror
  because that server returns identity instance transforms.
- **Twenty final 1280×720 captures**: all twelve original vistas/route views plus
  two additional supported player-height ridge views per chapter. All were
  reviewed in the final two contact sheets. The original twelve use the exact
  camera recipe from `9df627d4` via the fixture's `--camera-reference` option;
  camera transforms are retained in `after/cameras.json`. Inspection lighting
  remains unchanged; the parent's persistent daylight component was not edited.

The new geometry-profile detector samples 31–54 non-combat route-side profiles
per map, independently of generator parameters. It combines discrete curvature
with prominent alternating-slope frequency, permitting isolated bench breaks
but rejecting repeated sawteeth. Synthetic repeated teeth, irregular broad
relief and an isolated step independently exercise the detector. It also requires
more than 12 m of variation in sampled ridge clearance, rejecting a constant
trench or featureless mound. Before/after 90th-percentile curvature ratios:

| Map | Before | After | Ridge-clearance spread, before → after |
|---|---:|---:|---:|
| Rootfall | 0.961 | 0.476 | 19.0 → 21.6 m |
| Siltwake | 0.866 | 0.482 | 29.4 → 32.4 m |
| Emberline | 1.026 | 0.576 | 25.7 → 28.7 m |
| Crown | 1.025 | 0.393 | 21.0 → 23.3 m |

These are geometry regression diagnostics, not a substitute for the user's
visual approval. Remaining occasional hero crags and angular breaks are
intentional; the goal was varied landforms rather than eliminating all edges.

Final revised evidence:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/terrain-variety/`

Start with `before-after-player-height.png`. Each `<map-id>-comparison.png`
contains all three original before/after camera pairs. Full final galleries are
`after/worlds-contact-sheet.png` and `after/ridge-contact-sheet.png`.
Final logs are `compiler-final.log`,
`node-terrain-final.log`, `godot-terrain-final.log`, `godot-render-final.log`.
Intermediate failures/diagnostics, including the rejected 2 m experiment, remain
in the same folder. Original gallery PNGs and recipes are copied under `before/`;
the sibling `revised-worlds/` evidence is untouched. Original first-revision
captures, movement failure, importer crash/retry and successful proof logs remain
untouched under the sibling `worlds/` directory.

```sh
node tools/godot-campaign/compile.mjs
LP_NUM_THREADS=1 CAMPAIGN_TERRAIN_BASELINE="$BEFORE" node --test tools/godot-campaign/terrain.test.mjs
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/campaign/terrain.gd
LP_NUM_THREADS=1 xvfb-run -a "$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/campaign/terrain.gd -- --render="$EVIDENCE/after" --camera-reference="$BEFORE"
```

The Godot fixture additionally accepts `--map=<campaign-id>` for focused visual
diagnostics. Remaining integration evidence: revised-map authority/client smoke,
human pacing/combat/shortcut review and real-GPU performance. Parent's initial
all-four authority/client smoke passed before this layout revision; this lane
does not claim that earlier run verifies the revised hashes or placements.

## Research applied

The shared research/contract and independent source-movement clarification were
followed. Directly consulted sources:

- [Level Design Book: encounters](https://book.leveldesignbook.com/process/combat/encounter)
  — entry footholds, readable combat fronts and incentives to leave the doorway.
  Applied through varied approaches, central clearance, cover and supply loops.
- [Godot: MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
  — per-instance culling limitations motivate bounded spatial groups, local
  origins and transformed bounds. The web page currently identifies itself as
  4.7; implementation uses the project's verified Godot 4.5.2 APIs.

Final geometry hashes:

```text
rootfall-verge      dbd85402b89e277389a28e3d91b2efaf8b21207c565010a06d3042c0b751a446
siltwake-crossing   581eac2c45b050676766dc8d137fb4c162d8f6c30e91fe31019fe30ed41959e2
emberline-ascent    d5fac0852937dae2332d1e4d16e3c4e4828d8d5298a8de238aeb6c5c0ad66b32
crown-array        779e0dc63fe7475ad843f1afe5c99cddd99da8a178d3d4ca8de404085b38c89b
```
