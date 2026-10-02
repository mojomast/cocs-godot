# GRAVEMILL FOUNDRY

Revision 3 architectural candidate: see [REVISION3.md](REVISION3.md). The description below records the preserved functional checkpoint; staged building-mass changes have source proof and await an explicit Blender/native grant.

Stable ID: `gravemill-foundry`. Seed: `0x47524156`. Authored map, not a procedural remix of another arena. Dimensions: **384 × 288 m**, **35 m terrain relief**. All distances are source metres.

## Architectural intent

The foundry is cut across oblique mineral strata (`q = z − 0.14x`). A procession of two horizontal crusher drums, five radial furnace/silo towers, six filter banks, two barrel-vaulted interior districts and a suspended conveyor lattice defines a geological amphitheatre. Pale mineral rock and soot-black structural metal dominate; oxidized copper vaults, brass machinery seams and small molten inspection ports supply hierarchy. The peripheral rock spurs extend the canyon beyond the playable rectangle.

Landmarks are useful bearings: **Crusher Throat** in the west, **Cooling Nave** at the middle terrace, **Furnace Apron** in the east, and the **Crown Gantry** above them. The two vaulted galleries are 52 m long, with distinct end portals, sheltered side bays and real window apertures. Machinery is static. Stopped cargo platforms are flush with the midlevel terrace. Four maintenance inclines are source-walkable routes, avoiding unsupported moving lifts or vertical decorative stairs presented as gameplay.

## Three macro routes

| Route | Elevation | Layout and purpose |
|---|---:|---|
| Ore procession + service return | 0 m | 363.60 m payload wayline; 18 m design corridor. The southern return forms a complete vehicle loop, with 20 m design corridor and broad freight bends. Source Puma footprint and actual steering are tested. |
| Cooling gallery | 0 → 12 → 0 m | About 497 m between bases through both vaulted districts. Four mid-map maintenance inclines crosslink to the ground and crown routes. Portal jambs, window sills and headers are separate solids. |
| Crown gantry | 12 → 24 → 12 m | About 401 m with counterflanks at both ends and four intermediate access gaps. Low segmented parapets provide partial cover rather than an uninterrupted dominant firing position. |

The fourth landform rises from the crown to 35 m, framing the upper skyline. Angled strata, inclined crosslinks and the freight route's alternating bends break the square-yard pattern. Spawns have multiple exits; the source fixture reaches every spawn, pickup, objective and vehicle pad in the same connected graph. The base-to-base ground shot is blocked by a deliberately placed mineral buttress. Vehicle and infantry objectives use the existing source fields and rules.

## Payload encounters

1. **Crusher approach:** the western bend exposes the cart to the crusher-side incline while keeping the southern vehicle return available as a reverse flank.
2. **Cooling underworks:** the route dips below the nave and crosses beneath the ore lattice. The midlevel route supplies a second approach without an overlapping walkable roof.
3. **Furnace approach:** the eastern bend opens a framed tower vista before the defended receiving apron. The final approach has both the northern gallery descent and the southern service-loop return.

Checkpoint distances are the exact source-derived equal thirds: 121.20, 242.40, 363.60 m. No bespoke scoring or checkpoint rule is introduced. Assault uses the authored three sectors; domination and combined arms use the same supported capture sockets.

## Collision contract and discovered source constraint

`terrainSupportAt` chooses the highest walkable surface at X/Z. The terrain is therefore a single continuous stratified support field; vaults, conveyors and machinery caps are explicitly **non-walkable**. Navigation remains height-aware on real inclines. Overlapping traversable tunnel/deck arrangements are not needed for this layout.

All authoritative shapes are authored in the recipe. Source geometry and Blender use those exact vertices. Circular shells have radial wall faces; windows and arches have no enclosing collision box. A source wall quad does **not** provide standing-height movement collision: movement inspects its perimeter edges, and its horizontal edges have no vertical span. Every wall polygon is consequently emitted as triangles, preserving the low-to-high diagonal required by movement as well as the ray triangles. The real continuous-input wall-contact test caught this before art generation; failed logs are retained.

The production Godot binder consumes the same terrain surfaces and wall triangles. GLB meshes remain presentation-only. The granted-slot production probe passes 908 standing capsules and support rays, wall-contact movement, open portals/windows, and blocking ceilings/headers; see `ACCEPTANCE.md` for the complete verified scope.

## Editable Blender deliverable

`tools/godot-multiplayer/new-maps/gravemill-foundry/blender.py` creates individually named source and detail collections, eight material batches at most, editable master, GLB, embedded recipe/geometry hashes, eight authored review cameras and measured budget/timing JSON. Architectural detailing includes barrel-vault ribs, crusher end ribs and hoops, radial silo seams, furnace sight ports, conveyor rollers/chords, crown sleepers, flush static lift decks and fractured exterior strata. Generator seed is committed in the recipe.

Budget gates: ≤8 exported mesh nodes/materials; <180,000 triangles. Final measured export: **8 batches/materials, 66,284 triangles, 6,441 editable pieces**. Ground-following roads and mineral seams are disjoint inlaid regions of the original planar support mesh, preventing depth shimmer without visual-only raised floors. CPU review uses one thread and 16 Cycles samples; production proof and timing are in `PRODUCTION.md`. No GPU or human-playtesting claim.
