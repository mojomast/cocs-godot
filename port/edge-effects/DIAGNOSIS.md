# Edge collision, round impacts and weapon shaders — 2026-10-01

## Confirmed causes

1. **Campaign building hit boxes enclosed visible air.** `terrain.gd` built every
   recipe block as a full box. `structure_art.gd` fitted narrower imported facades
   inside it: for example, the outpost body is 0.82 of the recipe width and its
   roof is pitched. Source `spatial.mjs` also intersected the entire containing
   box. A four-metre cabin stopped a ray at x=1.96, y=2, z=2 although the visible
   body ends at x=1.64. At x=1.6, y=3.85 it similarly stopped a ray above the
   sloping roof. Real source fire reproduced zero damage before and damage after
   the repair, with standard-size targets supported on real source blocks.
2. **Camera candidates were mislabelled as actor contacts behind muzzle cover.**
   Source primary/alt fire correctly withheld damage when the muzzle path hit
   cover, but still emitted the camera candidate in `shot.hit`. The impact
   consumer therefore suppressed the actual wall contact. Reproduction: eye
   x=-1.7, y=2, z=2.3 beside that cabin; muzzle (-1.46,1.76,1.88), wall endpoint
   approximately (-1.464569,1.764569,1.700000), zero damage, old `hit:1`. Campaign
   now publishes `hit:false` for the same blocked shot. The old **60cm minimum
   impact ray length** independently suppressed this legitimate 18cm contact;
   the consumer now accepts finite segments of at least 1mm.
3. **The square border was the transient dust card over the round pock.** Its
   StandardMaterial alpha was uniform over an untextured QuadMesh. Native paired
   rendering reproduces the square and demonstrates its removal. The persistent
   pock already had radial coverage; all mark kinds now also have an explicit
   outer circular cutoff, including late expanding rings and irregular scorch.
4. **Impact queries could pick or invent the wrong plane.** Native probes ran
   inside→outside, with `hit_from_inside` producing zero normals on solid boxes.
   Their fallback invented a plane even on a query miss. Semantic terrain code
   expected an array/vector although `TriangleMesh.intersect_segment()` returns
   a Dictionary. Box normals were guessed from normalized distance to the box
   centre rather than the first entered slab. Corner guards sampled axis tips,
   not the quad corners, could accept a different plane behind the mark, and
   tested a rotated shrink footprint different from the one actually rendered.

## Implemented geometry contract

`port/edge-effects/structure-rays.mjs` is a **campaign-only adapter** wired in
`CampaignMatch.rayWorld` and `visible`. Frozen `game/*`, multiplayer source,
source movement/navigation, actor regions, weapon balance, shot spread, source
eye/muzzle convergence and swept projectile stepping are not rewritten.

* Retain source terrain and rock-box intersection. Intersect building facades
  against their committed LOD0 GLB triangle positions, transformed by the exact
  same style, fitted base, story segmentation and scale as the native renderer.
* `bake-structures.mjs` reads POSITION/indices and node rotations directly from
  GLB bytes, without an engine. The checked-in JSON records SHA-256 provenance
  for all 20 prototypes: 47,022 triangles, 46,974 nondegenerate at the source
  triangle-area threshold. The runtime loads JSON and builds cached source BVHs;
  it does **not** load GLBs from the exported game or spawn an art tool.
* Campaign source visibility uses this geometry with the existing 8cm visibility
  endpoint tolerance. Direct shots retain the existing clear/damage algorithm.
* Native facade collision uses imported mesh faces. Nonuniform rotated shape
  transforms initially disagreed with the render meshes; acceptance caught this.
  Collision now bakes the complete visual transform into vertex positions and
  uses identity CollisionShape transforms. This produces 1,041 agreeing native /
  source structural-face queries over all four real maps (2mm tolerance).
* `generate-core.mjs` adds one reviewed event-classification transformation at
  the two primary/alt emit sites: `hit:clear?(candidate):false`. It does not
  change the damage decision. Independent inverse provenance comparison restores
  every frozen source byte outside the four inventoried adapter differences.

The source standing/walking collision bounds remain conservative recipe boxes.
This is a weapon-cover repair, not a movement/ledge-navigation redesign. The
native collider is read-only presentation geometry for the source-owned actors.

## Round marks and contact queries

`combat_occlusion.contact()` provides actual first-contact positions/normals for
native colliders, semantic slabs, support triangles and wall triangles. Queries
run in incoming-ray order, select only map-owned bodies, and return empty on a
miss. Semantic closed-boundary tests follow source parallel-axis tolerance.

Impact search reach (6cm) is separate from endpoint acceptance (6mm). A ray that
ends in air near a wall cannot scar a nearby face. Blast floor queries use one
continuous downward segment instead of gapped 25cm samples. The footprint guard
checks the centre, corners and edge midpoints on the same plane and normal, then
shrinks once or omits the mark. Rings use this guard too. Offset is reduced from
2cm + size term to 3mm + 0.1% of size; cull-back and ordinary depth testing prevent
reverse-face and through-wall rendering. Pools, TTL, quality caps and dedup stay
finite; there are no new persistent allocations per shot after pool warmup.

## Four new production shader families / weapon coverage

|Family|Production binding / effect|
|---|---|
|Material impact burst|`player_fx/burst.gdshader`: transparent radial dust; metal spark spokes, ice fracture accents, stone/ground dust; source-confirmed impact/blast only. No texture alpha or mip borders.|
|Weapon trail|`weapon_effects/trail.gdshader`: soft strip edges with correct per-vertex alpha; Rail induction bands and Shock ion knots, all seven hitscan primaries retain their authored profiles.|
|Energy discharge|`weapon_effects/discharge.gdshader`: finite muzzle arcs on Pulse/Rail/Plasma/Shock at high quality; plasma explosion shell at the actual source explosion.|
|World conduit|`weapon_effects/conduit.gdshader`: etched emissive/Fresnel treatment on the authored campaign `light` material only: 31/40/60/46 beacon instances across four maps. Static, opaque, no geometry displacement or full-screen effect. Imported facade materials remain authored.|

Rocket additionally has a compact combustion burst and rising smoke; Grenade has
bounded short-lived fragments and smoke. Scattergun/Flak/Marksman/SMG preserve
their muzzle/casing identities and gain the soft-edged trail and material-contact
treatment. These use existing 64 effect / 128 line / 2 light caps. Primary bursts
are event-triggered, not guessed from projectile proximity; launch still creates
travel cues without an instant projectile hit tracer.

F9 Low retains primary flash/trail, suppresses material dust and secondary energy
muzzle arcs, and halves primary grenade fragments. `attach_rig` reads the actual
rig's reduced-motion setting: secondary muzzle arcs/smoke/casings are suppressed,
new grenade fragments suppressed, new primary smoke drift/expansion and energy
shell expansion held still; trails retain fading without travelling shader knots.
World conduit etching is static at every setting. Existing pause/expiry/reset
ownership stays in the combat composition.

## Audit outcome / remaining limits

* Robot silhouettes were audited against `TARGETING.md` and `ACTORS.md`; their
  current-snapshot pose, 6cm allowance and bounded chassis/sensor animation remain
  intact. This lane found no additional robot hit-volume defect. The source
  targeting suite still passes 11,952 real fire checks; the earlier 73,872 animated
  actor checks belong to the ActorSol evidence, not a new claim by this lane.
* Source point-segment projectile sweeps remain world-first. Fast campaign plasma
  at 138m/s is included in the real-source edge drill. No spherical magnet region
  or damage marker is fabricated.
* Urban recipe builders use explicit roof surfaces, sealed underside/side walls,
  baseY blocks, ramps and doorway gaps. Existing urban source audit and native
  ceiling/roof/side/doorway clearance tests pass. Campaign imported shutters are
  visibly sealed, not shoot-through windows. Legacy source bridge blocks remain
  ground-to-height by their original contract. No claim is made that every
  arbitrary stair/window edge in every map was exhaustively playtested.
* Godot import quantizes very fine bevel vertices, and native ray tests have a
  larger tiny-triangle epsilon than source doubles. The full-map comparison
  deliberately tests structural faces with edges >=2.5cm, not subpixel bevels.
  A bevel lacking a native contact within 6mm gets no scar, rather than projecting
  a false scar onto a deeper face. LOD0 remains source cover; distant LOD1 omits
  some cosmetic fine fittings. Neither is a broad invisible AABB.
* These are native Compatibility/llvmpipe acceptance captures and actual-source
  event replays, not a human combat playtest, GPU FPS benchmark or packaged
  Windows acceptance. Parent owns final integrated play/release validation.

Primary API reference read: [Godot 4.5 TriangleMesh](https://docs.godotengine.org/en/4.5/classes/class_trianglemesh.html)
documents `intersect_segment` returning `{position, normal, face_index}` or an
empty Dictionary. Runtime mesh decals use ordinary Compatibility spatial shaders,
not a Forward+-only Decal node.
