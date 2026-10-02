# New-map integration requirements

Parent review at Helix `0eb5401b` and Parallax `408ed002`. Map branches are isolated;
these notes describe required implementation and acceptance, not completed wiring.

## Native asset binding

`godot/multiplayer_worlds/map.gd` currently selects urban `art/<id>.glb` or legacy
`art/worlds/<id>.glb` from the presence of `recipeHash`. New maps plan
`art/<id>/<id>.glb`, so they require explicit reviewed art-path metadata/mapping.
Validate that the imported asset is present; do not silently claim a complete map
when only collision-derived fallback planes are visible.

Legacy art coverage detection requires `arena.art.ground`. Helix instead stores
`arena.art.meshes/palette`; Parallax stores top-level `art`. Introduce explicit
surface-coverage metadata for the new assets, keeping every authoritative terrain
and wall collider while preventing coplanar duplicate native floor rendering.
Check glass and foliage collision separately from solid architecture.

## Geometry generation and registration

**Confirmed movement constraint:** `terrainWallSegments` uses polygon perimeter
edges and drops edges with zero X/Z length. For a tall vertical quad, its remaining
horizontal edges can both lie outside a standing actor's vertical span. Such a
quad can block rays/native physics yet permit authoritative actor movement.
Foundry uses individual wall triangles, whose diagonals provide full-height
blocking spans; Helix/Parallax are auditing this before export. Verify solid-wall
contact through continuous player movement from both sides, on multiple tiers,
as well as clear portals. Do not use shot checks as a substitute for movement
checks, and do not silently modify locked source geometry behavior.

- Both standalone generators already deliver complete authority triangles.
  Parallax retains three `overhead` descriptions **and their generated slabs**;
  rerunning the legacy overhead-expansion loop would duplicate those surfaces.
  Invoke each standalone generator and its deterministic `--check` directly.
- Keep `canonical(arena)` geometry identity, committed recipe hashes and exact
  native/source agreement. Envelope art metadata is also committed build input.
- Extend the source `WORLDS`, native catalog and launcher capability catalogs only
  for accepted pairs. Prove that new map IDs pass the existing derived Room/Match
  routing. Helix's proposed Arsenal/Juggernaut pairs also require the new mode HUD
  and source-state projections on the multiplayer-world scene.
- Preserve existing seven-world geometry hashes and all 43 published pairs.
  Current source-feature work separately adds eight original-map mode pairs.

## Packaging and acceptance

- Extend discovery, builder data allowlists and committed-object manifest closure
  checks for accepted new recipes; keep older-artifact validation working.
- Retain the editable Blender masters and generators in provenance. Production
  exports need only the runtime GLB/material resources and required JSON data.
- Extend extracted Windows/Linux coverage from the accepted catalog, recording
  the new total explicitly and keeping previous cases. Verify actual PCK assets,
  source geometry identities, native objectives and advancing snapshots.
- Run map-specific source full rounds and native input journeys in addition to
  startup cases. Review overview and eye-level imagery, traversal footage,
  collision openings/ceilings, bots and wide/compact HUD layouts.

Each map's design/source evidence remains distinct from Blender output, native
acceptance, natural match balance and hardware performance measurements.
