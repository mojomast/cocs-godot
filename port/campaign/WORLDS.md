# The Quiet Relay — authored worlds, revision 2

The first worlds revision proved collision, scale and interfaces but repeated a
parallel-trench macro-layout. Parent visual review rejected that repetition.
This revision replaces the footprints, landmark kits and presentation while
preserving the integration interfaces and source-grounded collision semantics.

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
| Rootfall Verge | 320×224 m | 9.33× | 1,009.5 m | 920.8 m | 4 → 18 m |
| Siltwake Crossing | 352×256 m | 11.73× | 1,207.7 m | 1,019.2 m | 18 → 36 m |
| Emberline Ascent | 384×256 m | 12.80× | 1,382.6 m | 1,164.9 m | 36 → 62 m |
| Crown Array | 416×288 m | 15.60× | 1,360.1 m | 1,264.2 m | 62 → 72 m |

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
| Rootfall | 8,960 | 181 | 112 | 933 | 351 | 287 |
| Siltwake | 11,264 | 215 | 104 | 909 | 404 | 322 |
| Emberline | 12,288 | 237 | 96 | 942 | 497 | 350 |
| Crown | 14,976 | 259 | 144 | 1,016 | 450 | 348 |

Scenery/solid MultiMesh instance totals including the horizon are respectively
1,461 / 1,486 / 1,615 / 1,626. These are bounded allocated counts, not measured
on-screen draw calls. Terrain material groups occupy at most 32×32 m; scenery
batches use local 32 m origins. The horizon uses 64 m groups.

**Length does not prove duration.** Travel alone takes about 126–173 seconds at
8 m/s, less when sprinting. The 300–600 second first-playthrough target still
requires encounter/interaction pacing and human timing. No forced waiting or
world-imposed match timer is used.

## Original biome presentation restored

The renderer reuses the actual existing assets from `godot/biomes/map.gd`:
branching trunks, asymmetric lobed crowns, fern blades and faceted cliff meshes.
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

- **14/14 Node tests pass**, including actual source `moveActor` through every
  mandatory path segment and all twenty local loops, independent source triangle
  support checks, mandatory gate metrics, strict parser rejection, independent
  footprint checks and exact chapter handoffs.
- Godot headless test: **`CAMPAIGN_TERRAIN failures=0`** across all four maps.
  Checks compare feet/interpolation with real physics ray hits, verify cull
  bounds, foliage colours, and bounded terrain/horizon/instance counts.
- GL compatibility test under Xvfb/llvmpipe: **zero failures**, including reading
  real renderer MultiMesh transforms. Dummy/headless uses the bounded CPU mirror
  because that server returns identity instance transforms.
- **Twelve final 1280×720 captures** cover all four vistas and two player-height
  views per chapter. Cameras now follow the actual approach tangent. All twelve
  were reviewed in the final contact sheet.

Final revised evidence:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/revised-worlds/`

Start with `worlds-contact-sheet.png`. Final logs are `compiler-final.log`,
`node-terrain-final.log`, `godot-terrain-final.log`, `godot-render-final.log`.
Intermediate diagnostic logs remain in the same folder. Original first-revision
captures, movement failure, importer crash/retry and successful proof logs remain
untouched under the sibling `worlds/` directory.

```sh
node tools/godot-campaign/compile.mjs
LP_NUM_THREADS=1 node --test tools/godot-campaign/terrain.test.mjs
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/campaign/terrain.gd
LP_NUM_THREADS=1 xvfb-run -a "$GODOT" --path godot --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/campaign/terrain.gd -- --render="$EVIDENCE"
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
rootfall-verge      81a5b2bf0dc508be76b35ef268b51ed4d676102c939673f06982feffcc7272a0
siltwake-crossing   24c647a5e4755a2c30a111f716ed33e23792a8d17e11d72ef286171c8847a02f
emberline-ascent    122459c3015108408a8d07f69d826a281b14ca05183214b7ebc43c5edf0791ce
crown-array        b7350e8d6ebcdc08cad66ee2631017352557ffb7d8792872957628851efb0744
```
