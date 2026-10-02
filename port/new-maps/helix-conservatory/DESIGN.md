# Helix Conservatory

Stable ID: `helix-conservatory`. Seed: `61002`. Source lock `515daf`; reviewed derivative `0326`.

Production update: see [PRODUCTION.md](PRODUCTION.md) for the inspected Blender/native art, final hash, five accepted native modes and separate source-only modes. The editable master now lives at `tools/godot-multiplayer/new-maps/helix-conservatory/masters/helix-conservatory.blend`, outside Godot's automatic import tree. Historical initial planning below is retained for traceability.

## Spatial design

A 240 m diameter research conservatory descends from a 24 m crown through 16 m canopy and 8 m archive terraces into an open zero-height lightwell. Ninety-six angular sectors give the landscape a curved silhouette. Sixteen articulated hexagonal-section greenhouse ribs scallop above the terraces, framing the open sky. Discontinuous planter crescents, ceramic lanterns, verdigris aqueducts and seed drawers articulate the ground plan.

Four rings, eight radial garden ramps, two curving ascending promenades and the lightwell axis form fifteen authored routes. Principal choices are the fast exposed lightwell, sheltered archive ring and longer canopy flank. Outer crown access provides a high overlook with eight counter-approaches. Ivory archive and copper/verdigris irrigation laboratory occupy opposite ends of the archive terrace, each with two open portals. The two aqueduct spans shelter lower routes.

**Frozen movement constraint:** `terrainSupportAt` selects the highest walkable triangle at X/Z, without actor reference height. Therefore this is a single-valued terraced landscape, not overlapping playable decks. Ribs, vault ceilings and overhead aqueducts are `walkable:false`; transparent glass and botanical leaves have `collision:none`. Aqueduct tops are decorative service infrastructure, not additional playable floors. Ramps rise 8 m over 18–20 m. No source movement changes are needed.

Team sockets face each other on the canopy band. The primary one-zone objective is the lightwell; two secondary domination sockets occupy north/south canopy. High-contrast ivory/verdigris/gold materials are prepared, but directional signs and native objective readability still require the art/engine pass.

## Artifact contract

- Recipe/authority: `port/native-multiplayer-worlds/worlds/helix-conservatory.json`
- Source-compatible derived wrapper: `godot/multiplayer_worlds/generated/helix-conservatory.json`
- Generator: `tools/godot-multiplayer/new-maps/helix-conservatory/recipe.mjs`
- Export: `node tools/godot-multiplayer/new-maps/helix-conservatory/build.mjs` (`--check` verifies bytes)
- Blender script: `tools/godot-multiplayer/new-maps/helix-conservatory/blender_author.py`
- Planned art: `res://multiplayer_worlds/art/helix-conservatory/helix-conservatory.glb`
- Editable master: same directory, `helix-conservatory.blend`
- Provenance: `port/new-maps/helix-conservatory/provenance.json`

The wrapper uses the existing catalog's `canonical(arena)` geometry hash convention. Recipe triangles are the art triangles, not a separate bounding-box approximation. The Blender script batches explicit meshes by material/authority class, retaining per-part vertex ranges in editable mesh metadata. Geometry is deterministic; binary Blender metadata may differ between tool builds.

## Parent integration

No shared files changed. Parent owns registry/WORLDS, routes, scenes, mode options, packaging and manifest verification. Import this derived wrapper directly; its terrain already contains every solid cap, underside and side triangle. Do not add walkable roof proxies, opaque glass collision, or convex whole-building colliders. Native generation must consume both `terrain.surfaces` and `terrain.walls` and use Y-up coordinates.

`modeBindings` is deliberately empty until native fixtures and hosted journeys pass. Candidate IDs are `deathmatch`, `teamdeathmatch`, `arsenal`, `juggernaut`, `ctf`, `domination`, `koth`; all seven exact source IDs passed controlled input-driven full-round fixtures recorded in `source-validation.json`. `arsenal` means Full Arsenal, not the separate `armsrace` mode. There are no gameplay rule additions. Autonomous bot objective behavior and native hosted DM/CTF/one-zone validation remain acceptance gates.
