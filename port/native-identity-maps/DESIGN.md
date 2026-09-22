# Visual identity trilogy — design, materials, effects, collision model

Units metres; X east, Z south, Y up. Graybox owns source surfaces/blocks; presentation consumes the
same geometry, and decorative skyline can never become invisible source cover. Layouts and budgets
below are authored intent; PERFORMANCE.md holds what was actually measured.

## Shared contracts

* One JSON recipe per map, deterministic Node compiler (`tools/godot-identity-maps/compile.mjs`),
  canonical arena hash, exact render triangles in `art[]`, authored collision in
  `arena.terrain.walls`, per-form collision rationale in `artNotes[]`.
* **Render and collision are different products.** `art[]` is never simplified and owns no physics.
  Blocks, floors and authored walls are the collision, and they are also rendered, so Godot's static
  world equals the source's ray triangles and obstruction segments.
* Three detail scales per map: mass (blocks), form (art), construction detail (render-only MultiMesh
  trim: ≤5 cm proud, no collider, never changes silhouette).
* One material per semantic key per map, six keys, shared by every surface. Palette colours are
  authored in the JSON; `style.gd` maps them onto baked Moth tiles.
* Fixed cameras per map: entrance (spawn eye → landmark); landmark oblique; combat at 1.6 m;
  objective/pickup at eye level; worst-sector elevated overview. Capture at 960×640, 1280×800,
  1920×1080 with asserted PNG dimensions.
* Effects are bounded, gated, non-authoritative and never resemble pickups, projectiles, capture
  markers or doors.

## Collision model (deliverable 1)

| Primitive | Rays | Movement | Used for |
|---|---|---|---|
| `arena.blocks` box | box hit | block BVH | every ground-level solid mass |
| polygon wall (planar quad / trapezoid / cap) | fan triangles | outline edges only | visible faces of authored masses |
| two-point fence `{a,b}` | none | one XZ segment with a Y span | closing a foot volume the quads cannot |
| walkable surface | terrain triangles | floor lattice | floors, ramps, terraces |

A wall segment blocks an actor when the body `[y, y+1.8]` overlaps the segment's `[minY, maxY]`.
Consequences the authoring uses: a vertical rectangle needs an explicit fence (its own outline edges
are top/bottom only); a *planar* quad's fan stays in the quad's plane, a non-planar one creases away
from it; alternating low/high vertices turn outline edges into full-height barriers.

Per map: Lacuna 20 wall entries / 40 segments (terrace skirts plus two coarse quads per resonator
band end), Vermilion 0 (every visible form is ≥3.7 m and the reachable eye ceiling is 2.97 m),
Nacre 168 / 504 (14 vault-foot volumes: planar face quads, end trapezoids, caps, fences).

## Lacuna Court / Deathmatch

Playable footprint 56×48, X ±28, Z ±24. Four protected cardinal/quadrant spawn pockets and two
intersecting loops around split acoustic masses. Central open court ~14×12, 8–20 m typical
engagement. Two 1.5 m terraces reached by broad 1:6 ramps. Cover heights 2.6–4.5 m, most routes
≥4 m wide. Rocket and health opposite sides, armor at flank.

Landmark: two separated thick stone arcs on 5×9×4.5 m cut-stone plinths, indigo receivers, copper
radial inlays, a pale bevel cap; a distant acoustic sail outside the boundary. The arc band above
the plinths is covered by two coarse quads per resonator (4.45–6.0 m) and is otherwise open, because
the arch opening is real.

Materials (6): `floor` warm chalk sand · `shell` pale cut stone · `cut` weathered cut stone ·
`enamel` deep indigo panelling (hex, low roughness, faint void-LUT sheen) · `accent` copper
metal-oxide · `trim` dark brushed hardware.
Effect: copper seam shimmer along both resonators plus localised dust in the four quiet lanes.

## Vermilion Fold / Domination

Playable footprint 64×56. Mirror-balanced travel geometry, asymmetric pavilion silhouettes. Team
spawns west/east, paired heights. Three capture sites north/centre/south at (0,−17), (0,0), (0,17),
radius 3.5, ≥3 radial entrances each, opaque offset retainers. One human plus five bots (3v3).

Landmark: a five-fold ribbon crown at centre, a nine-blade fan with jade under-ribs over alpha, six
serial pleats at charlie, twelve ivory tension members with hardware inner ribs and keystones.
Sheets are smooth cosine folds with a folded rim — the prototype's 8-strip sawtooth silhouette
(named as jagged) is gone.

Materials (6): `floor` sun-warmed ochre sand · `shell` ivory tension stone · `cut` weathered
secondary · `enamel` jade hex panelling · `accent` vermilion concrete (ribbon body) · `trim` dark
riveted hardware, plus bolt trim on the retainers.
Effect: light sheets drifting *inside* the opaque crown/fan/pleat volumes (all ≥6 m) and a faint
tension-member breathe. No ground-level effect anywhere.

## Nacre Engine / Horde

Playable footprint 60×52. Four broad approach mouths, connected outer retreat ring, two cross-links
around a nonwalkable central memory housing, recovery alcoves with two exits. Minimum wave approach
width 6 m. Static nested arches overhead are decorative/nonwalkable. Largest NPC display clearance
≥3.2 m at route mouths; production actor/boss tests remain required.

Landmark: seven nested pearl vault ribs each with a radially inset joint band, a horizontal
segmented memory drum with amber service rings inside the housing, amber louvres and two amber
service organs on the housing faces.

Materials (6): `floor` pearl concrete · `shell` weathered pearl shell with a faint arcane-LUT sheen ·
`cut` metal grating for joints · `enamel` ultramarine panelling · `accent` amber metal-oxide ·
`trim` cool brushed hardware.
Effect: sparse suspended vault motes plus two one-shot bounded pressure pulses around the drum.

## Budgets (authored intent, measured values in PERFORMANCE.md)

≤120 visible material cells per map · ≤150k visible triangles · ≤32 MiB unique texture per map ·
one shadowed directional key and no required local lights · glow off by default and never required ·
effects High ≤32k / Low ≤8k particles per map · no per-prop process, no per-frame mesh rebuild, no
per-frame allocation in the effect pool · deterministic build from a Node script with no timestamps.

## Open design questions for the lead

1. Whether the folded sheets should become cover again (they were exact-triangle collision in the
   prototype). Restoring them needs coarse quads above 6 m and would cost wall segments and load
   time again; the parity audit currently proves no reachable eye ray is affected by their absence.
2. Whether the resonator band above the plinth should be collision above 6 m (1.55 m above the
   reachable eye ceiling).
3. Whether the horizon/skyline decoration belongs in the map builder (`style.decorate`) or the
   session's presentation layer. It is render-only either way.
