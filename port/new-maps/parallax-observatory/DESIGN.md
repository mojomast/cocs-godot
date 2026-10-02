# Parallax Observatory

Stable ID: `parallax-observatory`. Source anchor: `4ae4e5b786e6de0e3b1bc18e785e202e6cb95ad8`.
Authoring branch: `maps/observatory-20261002`. Seed: `20261002`.

## Playable architecture

A fractured coastal astronomical institute, with chalk footings descending to a moonlit tidal chasm. Saltstone terraces, dark instrument metal, silver-violet mirrors and ochre calibration marks distinguish it from green Helix and rust Gravemill. The silhouette is two tilted, broken-petal parabolic dishes, three intersecting armillary rings, slit observatory domes and curved northern/southern circulation.

The public western arrival district has a twelve-sided plaza and ephemeris archive. The eastern instrument district uses an octagonal metal apron and overhead service gallery. The central faceted lens dais is contested from three directions. Two through-interiors have open arch mouths, equipment against the side walls, precise ceilings and exits at both ends. The cistern's eastern exit deliberately stays straight through the jamb before bending up the cliff.

Three major routes and three crosslinks:

| Route | Purpose | Elevation |
|---|---|---|
| Meridian lens | Fast objective contest, archive interior, gallery underpass | 12 m |
| Armillary arc | Long high flank, marksman pickup, two descending retreat options | 12 → 24 → 12 m |
| Tidal cistern | Lower return loop, pump vault, plasma/health | 12 → 0 → 12 m |
| West calibration | Diagonal side transfer through all tiers | 24 → 12 → 0 m |
| East instrument | Opposite transfer, cabinet cover | 24 → 12 → 0 m |
| Polar crosslink | Central objective-to-objective transfer | 24 → 12 → 0 m |

Configured bounds are 320 × 256 m; actual supported architecture is approximately 256 × 180 m. Relief is 24 m. Walkable slopes rise at most 1:4, with flat bands at each tier. All six route centerlines are exercised forward and backward by source movement. Terrain-edge parapets are generated only on outward edges lacking neighboring support; this preserves route joins. The water lies below the source void threshold.

## Highest-floor authority decision

`terrainSupportAt` selects the highest walkable triangle at an XZ coordinate. Every playable surface therefore uses one common piecewise height function, including overlapping route joins. There are no stacked walkable floors, new traversal mechanics, teleporters or lifts. The service bridge is an inaccessible overhead maintenance gallery. Its underside/top/sides are source surfaces/walls, both surfaces nonwalkable. The two vault roofs follow the same pattern. These are real walk-under spaces, not full-height collision boxes.

Visuals read the same generated arena: exact terrain polygons, walls and block extents are emitted into Blender. Craft geometry is attached to source-solid cabinet surfaces, below floor footings, above head clearance, or outside reachable parapets. Native authority must stay in the source match; GLB colliders must not become a second authority.

## Reproducibility and ownership contract

Generator: `tools/godot-multiplayer/new-maps/parallax-observatory/generate.mjs`.

Outputs:
- `port/native-multiplayer-worlds/worlds/parallax-observatory.json`: machine-readable arena + routes + artistic recipe.
- `godot/multiplayer_worlds/generated/parallax-observatory.json`: exact source arena, canonical `geometryHash`, byte-level `recipeHash`, supported spawnPoints, 3D routes and art recipe.
- Granted Blender output: `godot/multiplayer_worlds/art/parallax-observatory/parallax-observatory.glb` and `asset-manifest.json`.
- Editable master: `tools/godot-multiplayer/new-maps/parallax-observatory/parallax-observatory.blend`.

Blender script: `tools/godot-multiplayer/new-maps/parallax-observatory/blender_author.py`. It refuses execution without `--slot-granted`, exports seven material batches with geometry/recipe metadata, retains individually named editable craft objects, and enforces 160,000 triangles / 16,000,000 GLB bytes / seven materials. These are limits, not measurements until Blender runs.

Parent integration contract:
1. Register ID/name and `deathmatch`, `teamdeathmatch`, `ctf`, `koth`, `uplink`, `holdout` in shared catalog/options.
2. Invoke this standalone generator rather than feeding this recipe through the older overhead-expansion loop: all three slabs already have complete source surfaces and walls. Do not double-add slabs or hash art/routes into `arena`.
3. Register all six generated routes using their existing `{id,width,points:[{x,y,z}]}` shape; main cross-map routes are the first three.
4. Scene generator consumes the nested GLB path above. Native collision/debug source surfaces must use `data.arena` and keep exact geometryHash.
5. Add recipe, generated JSON, GLB, asset manifest and editable master to package dependency closure as appropriate. No shared registry edits are included in this workstream commit.

## Balance measurements

Mean shortest source-nav path distances from each team's four spawns:

| Objective | West | East |
|---|---:|---:|
| Lens | 114.39 m | 114.04 m |
| Armillary | 151.23 m | 150.88 m |
| Cistern | 148.02 m | 150.72 m |

These graph measurements include the asymmetric cistern exit. They are not a combat-balance claim. Complete per-spawn distances are in the evidence JSON. Unladen source centerline journeys: middle 25.52 s, upper 34.18 s, lower 34.20 s. Upper/lower flag-carrier return journeys are about 38.1 s. Long centerline sightlines and flank counterplay still require native combat/visual inspection.
