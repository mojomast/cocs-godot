# Astra botanical/urban source repair — 2026-10-03

Implementation branch: `astra/map-variety-botanical-repair`, based on
`0351e1d1d9c285cfbdc0d112914f4fe5ce1737d8`. Work was isolated in
`/home/mojo/.tmp-on-disk/cocs-map-variety-botanical-astra`. Flash's dirty worktree
was not adopted or edited. No Blender, Godot, native import, rendering, server,
or child-agent execution occurred.

Implementation and regenerated candidate authorities: commit `f6687255`.

## Closure of the thirteen source findings

1. **Compound Kit return API:** `create_assembly()` captures every object created
   by the actual Kit call. All nine framed-bay parts receive the same rigid
   transform, not just its two returned jambs.
2. **Pipe compatibility:** stall posts use eight sides; every candidate operation
   is exercised against the committed Kit's pure construction methods.
3. **Oversized source mesh:** authority, decorative and accepted-craft buckets
   are split by face into <=24000-triangle source meshes before Kit batching.
   Helix's 27504-triangle verdigris surface no longer enters as one object.
4. **Coordinates:** compound offsets are assembled about zero in source Y-up,
   converted once to `(x,-z,y)`, then rigidly headed. Primitive vertices remain
   local Blender Z-up. Greenhouse path control points are truly local; the
   regression round-trips them to `[-11,30.2,84]`, `[0,30.6,87]`, `[11,30.2,84]`.
5. **Box midpoint:** block/overhead render extrema equal `[baseY,h]` and
   `[minY,maxY]` exactly.
6. **Composition:** all 5240 noncollision Helix meshes (100874 triangles), pool,
   Vesper clock/hands/rails, labels and base pieces are retained. Further source
   inspection found procedural accepted craft outside those arrays.
   `base_craft.py` captures the pinned authors' geometry-only AST sections:
   Parallax's actual tilted dish petals, domes, armillary, cliffs, instrument
   galleries, inscriptions and sea; Vesper's reveals, full facades, trusses,
   clock courses and stair details. Imports, bpy, scene/export/render/file code
   are excluded. Full-file SHA pins fail closed if the capture boundary changes.
   Candidate cutouts remove only craft that would refill Parallax's new openings.
7. **Genuine lightwell:** the covering court floor is replaced in the well/ramp
   footprint. Highest support is 12 at x44, 10 at x40 and 8 at x36/x34/x32,
   z=-34. Reintroducing the old cover fails the intended-height regression.
8. **Portal rays:** two-component directions normalize to `[dx,0,dz]`; malformed,
   zero, nonfinite and invalid dimension inputs fail. The solid-wall fixture
   that previously returned zero failures now detects the obstruction.
9. **Physical routes:** old and new paths are sampled at <=0.25 m against support,
   0.42 m capsule clearance, 1.8 m headroom, boxes and height-clipped wall faces.
   Graph edges use the same physical trace. Authored heights are preserved at
   waypoints rather than replaced with highest support. New kit solids have
   conservative pre-bevel collision triangles captured from the exact same
   Kit operations; `renderSource: kit` avoids rendering those triangles twice.
   This exposed and fixed garden-ramp shell crossings, quay-rail bridge closures,
   market-stall cross-street obstructions and instrument tower/pump conflicts.
   Vesper's roof replaces one explicitly identified closed building and connects
   to the upper district with 1/7 m treads away from the accepted x32 stair.
10. **Canonical materials:** normalization targets Sol's committed `6ff4079e`
    PBR-only API. Preserved palette/BRDF materials are map-owned and never sent
    as `preserve` to that adapter. Images are packed into the master, source and
    converted hashes are distinct, and reopen-export rejects external image
    dependencies. Actual GLB albedo, normal and roughness pixels are verified.
    See `ADAPTER_CONTRACT.md` for the precise integration contract.
11. **Rib normals:** a consumer-side closed-shell signed-volume guard fixes
    inward winding without editing the Sol-owned shared Kit. It is idempotent
    when the independently fixed shared Kit is integrated. Open sheets retain
    their intended winding; fern tops are explicitly outward/upward.
12. **Budgets:** source estimates include complete base craft, structures,
    decorative meshes, kit and infrastructure. Helix and Parallax use explicit
    one-segment edge chamfers and no redundant bevel on already rounded profiles.
    Total triangles now use the user's 150000 advisory target; actual evaluated
    scene and GLB counts report their measured total and overage without failing
    solely for exceeding it. Review status stays pending performance/visual
    review. The 24000 per-source/batch constraints and 64-primitive limit remain
    strict, as do topology and material/pixel validation. No geometry was removed
    or threshold raised for this policy follow-up.
13. **Cameras:** authored Parallax/Vesper views and explicit Helix inspection
    views are restored with correctly transformed eyes/targets. Editable source
    and evaluated export collections coexist without duplicate rendering.

The audit also caught a new hash issue introduced by ground replacement:
`stampTerrainFloor` attaches a function that disappears during JSON serialization.
Candidate composition now removes that callback before hashing. Stored authority
hashes are verified again after reading the serialized files.

## Source evidence

All three generation/audit commands pass. Physical route reports have zero new
failures and zero baseline defects; every authored nav node is connected:

| Candidate | Connected nodes | Full unmodified source triangles* | Geometry hash |
|---|---:|---:|---|
| Helix revision-3 | 2506 / 2506 | 147026 | `5755ec9fba17d4b88d99d90e1717d86ce5ae9983a5c2bc290a93b5b366585140` |
| Parallax districts-v3 | 532 / 532 | 143782 | `abaea5a6f13cca985f380d9c2f98c856ae5264325e219303219328ee47ab900c` |
| Vesper urban-v2 | 857 / 857 | 40688 | `01ddc671cb0e8471da390d93a1b4dfbba507551ed29a588b249fe761af1a7ef7` |

*These are source estimates, excluding font tessellation and evaluated modifiers.
They are not exported triangle measurements or native acceptance claims.

Passing regressions: **25 Node tests** (18 existing + 7 new), **16 Python repair
tests**, and the standalone kit-source checks. All three Python `asset_author.py
plan` entrypoints were exercised; source estimates now include accepted craft.
Spawn/team-spawn/flag/objective support heights remain unchanged, and standing
clearance is checked at those locations.

```sh
node tools/godot-multiplayer/new-maps/helix-conservatory/variety-source-check.mjs
node tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/variety-source-check.mjs
node tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/variety-source-check.mjs
python3 -B tools/godot-multiplayer/new-maps/map_variety/test_repair.py
python3 -B tools/godot-multiplayer/new-maps/map_variety/test_kit_source.py
node --test tools/godot-multiplayer/new-maps/map_variety/repair.test.mjs tools/godot-multiplayer/new-maps/helix-conservatory/variety.test.mjs tools/godot-multiplayer/new-maps/parallax-observatory/revisions/districts-v3/variety.test.mjs tools/godot-multiplayer/new-maps/vesper-viaduct/revisions/urban-v2/variety.test.mjs
```

## Serial production integration

Parent review/integration should include the canonical committed Sol adapter and
its owner-approved fixes. This branch does not copy or edit those shared files.
The actual build/reopen-export entrypoints remain:

- `helix-conservatory/asset_author.py`
- `parallax-observatory/revisions/districts-v3/asset_author.py`
- `vesper-viaduct/revisions/urban-v2/asset_author.py`

Each exposes `build --adapter material_adapter` and `reopen-export`, writes its
revision-local editable master/GLB/report, packs material images, and performs
strict export/pixel gates and advisory total-triangle reporting. Only the heavy
owner executes those steps after integration. Evaluated bevel/font counts,
GLB verification, portable reopen,
camera renders and native movement/mode acceptance remain pending that run.
Accepted masters, registered/runtime worlds, game core and physics are unchanged.

## User-directed triangle-policy follow-up

The 150000 total-triangle target is advisory at every measurement stage. A
synthetic 160001-triangle GLB regression now completes its audit and reports
`totalTriangles: 160001`, `overageTriangles: 10001`, `overTarget: true` and
`status: pending-performance-visual-review`. This fixture is not a native map
measurement. Unknown/invalid counts and malformed triangle topology still fail.

Only five affected Python regressions and the standalone kit-source checks were
run for this follow-up: advisory overage/count validation, pending-review status,
unchanged source chunking, complete-source estimate reporting, and strict albedo
pixel validation. All passed. Geometry, generated authorities and shared Kit
files were not changed, and no heavy/native execution occurred.
