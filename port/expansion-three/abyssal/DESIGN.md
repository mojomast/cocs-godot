# Abyssal Pressureworks — source-ready architectural recipe

Stable ID: `abyssal-pressureworks`. Lane branch: `expansion-three/abyssal`.
Base: `27cfaa14`. Stage: **READY FOR BLENDER**, awaiting the parent's exclusive slot.

## Spatial design

A dry research/energy habitat sits in an escarpment rather than an outdoor
industrial yard. The 240 × 220 m authority bounds contain twelve chamfered
pressure chambers and seventeen enclosed, angled gallery volumes. Staggered
chamber positions, separate roof profiles, and descending laboratory floors
break up the massing. There are three four-room districts:

| District | Rooms | Deck levels / silhouette |
|---|---|---|
| Terraced laboratories | Intake quarantine, Spectrometry, Reef observation, Sample archive | 6, 4, 2, 0 m; broad splayed observation vaults |
| Pump / energy | Freight lock, Pump cathedral, Equalizer atrium, Distribution hall | 10 m; tall faceted vessels, a 24 m atrium wall and towering offset equalizer |
| Residential / operations | Residential commons, Medical operations, Mission control, Emergency refuge | 20 m; low compact pressure shells |

Three continuous alternatives connect the ends: a 14 m broad pump/freight spine,
a 10 m operations gallery, and a 10 m low maintenance/laboratory bypass. Eight
crosslinks climb between districts. Each primary route contains three connecting
gallery segments. Route points include chamber centers and both portal centers;
they are movement fixtures and navigation seeds, not teleports.

Every chamber has consoles and side-bay equipment, opaque cover, segmented
pressure seals, structural ribs and a faceted ceiling. Cover leaves central axes
and openings clear. The upper control approach affords a >5 m height advantage
into the reactor district, with tested reciprocal counterfire rays. Reactor
equipment is offset from the route and objective center.

## Source and native geometry

- 20 m total walkable relief; twenty-nine walkable polygons have no sampled
  interior overlaps. Ramps join portal edges exactly. There is no stacked deck
  beneath another walkable deck.
- All crowns, roof facets and gallery ceilings are explicitly non-walkable.
  The source compiler does not append a second set of overhead slabs.
- Vertical shell faces are emitted as **individual triangles**, including
  gallery sides and portal jambs/lintels. They are the native collider input too.
- Observation panes explicitly declare transparency and nonblocking shots/actor
  physics. Their 1.2 m sill is a source wall; the ocean beyond has no support.
  The GLB supplies alpha glazing and no collision bodies.
- Node remains gameplay authority; ordinary gravity and movement apply.
- Candidate modes: DM, TDM, CTF, KOTH, Domination, Holdout. Publication depends on
  parent registration and native acceptance.

## Deferred Blender authoring

`tools/godot-multiplayer/new-maps/abyssal-pressureworks/blender_author.py` emits
the exact source walls, roofs, decks and solid equipment, plus layered locking
dogs, pressure seals, overhead service pipes, console controls, vent faces,
district floor markings, transparent windows and bounded branching reef support
scenery. The exterior reef is static and nonphysical.

Deep navy / coral ceramic / ivory seals / copper hardware use seven materials,
including restrained amber and cyan cues plus glazing. The editable master keeps
named components; the GLB uses one batch per material. Budgets are ≤100,000
triangles and ≤48 draw calls, with seven intended material batches. These are
limits, **not measured Blender/native results** or minimum triangle targets.

Master output: `tools/godot-multiplayer/new-maps/abyssal-pressureworks/masters/abyssal-pressureworks.blend`.
Runtime art output: `godot/multiplayer_worlds/art/worlds/abyssal-pressureworks.glb`.
Neither has been produced at this stage. The future script records measured
triangles, batches, byte size, recipe/GLB hashes and Blender version in
`provenance.json` beside itself.
