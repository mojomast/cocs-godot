# New Moth resources and Blender-authored map variety

## User directive and order of work

The user explicitly requested Flash/Sol subagents to populate the newer maps with
Moth assets, reduce monotony/repetition, and add varied terrain, structures and
layouts. A dedicated Astra must first create **new resources through the actual
Moth API and update mothbake**, before application agents use the results.
The user authorizes as many API requests as useful and specifically requires
**Blender-built new map assets** with polished detail and editable masters.

This is a new production pass, not a claim that earlier maps already meet the
new variety goal. Primary scope is Helix Conservatory, Gravemill Foundry, Parallax
Observatory, Vesper Viaduct, Abyssal Pressureworks and Stormglass Causeway.

## Active owners

Source foundation: `55edd9f2`. All work is isolated from the live P candidate.

| Work | Agent/session | Current responsibility |
|---|---|---|
| New Moth resources + mothbake | Astra `ses_efdbb8a90ffeBrpRZAFfraUSXv` | Authenticated live catalog/schema discovery, actual new API jobs, recorded outputs, deterministic material bakes, generic tool updates and handoff manifest |
| Industrial/coastal variety | Flash `ses_efdbb1dfeffebxsWuzs9jbjzJv` | Foundry/Abyssal/Stormglass source and visual audit; concrete Blender asset families, placement and terrain/layout revision design |
| Botanical/urban variety | Flash `ses_efdbaaa61ffesiVbXI7pmlS04Q` | Helix/Parallax/Vesper source and visual audit; concrete Blender asset families, placement and terrain/layout revision design |
| Blender production integration | Sol `ses_efdba38e9ffeManqAN9zWiJ3va` | Material/trim-sheet handoff, editable master/export pipeline, bounded batching and collision/navigation validation preparation |

Flash/Sol application follows Astra's usable resource delivery and parent review.
The current audit/preparation work does not substitute for actual asset production.
Parent must assign the implementation lanes and the next explicit Blender/native
slot once the dependency and ownership boundaries are ready.

## Required production qualities

- Distinct map districts, landmark silhouettes and architecture with meaningful
  large/medium/small forms, rather than only tint changes or repeated prop scatter.
- Blender-authored modular and hero assets with `.blend` masters, intentional
  bevels/normals, stable UVs/texel density, and actual Moth-derived material inputs.
- Terrain variety includes explicitly reviewed traversable grades, terraces and
  elevated routes where appropriate. Decorative cliffs do not prove playable
  relief. Preserve truthful reporting of Stormglass's previous flat-road concession.
- New walkable terrain/layout changes require matching authoritative geometry,
  support/collision/navigation and objective/spawn/checkpoint validation. Preserve
  existing mode support and vehicle/headroom clearances without weakening checks.
- Retain each map's identity, team/objective readability and useful sightlines.
  Bound repeated alpha overdraw, material batches, triangle counts and collision
  complexity; native screenshots and performance measurements remain later gates.
- Record new provider outputs as new Moth provenance. Local recolors or fabricated
  fixtures must not be described as API-generated results. Keep job IDs, source
  seeds/masks, parameters, schema/tool revisions and downloaded-byte hashes.
- Offline rebakes from recorded outputs must be reproducible. Preserve existing
  resource registries and import policies; publish reviewed additions atomically.

## Tooling, storage and resource ownership

The old `/home/mojo/projects/mothbake` path is absent. Existing checkouts include
`/home/mojo/.tmp-on-disk/mothbake-lattice-20260925` (read its `AGENTS.md`) and
`/tmp/opencode/mothbake-repo`. Astra checks their actual revisions and working-tree
state before use. An existing authoring credential file was located; secrets are
loaded into process environment only, never printed or committed. Authentication
and actual API job success are not yet established by this parent checkpoint.

Free storage was approximately **1.17 GB** at launch. Use sparse source worktrees
and bounded candidate outputs; do not duplicate all imported assets or delete
historical evidence/unfamiliar files to recover space. Report a concrete capacity
block if one occurs. The authorization for remote API requests is not permission
to consume unbounded local storage.

**P remains the only local heavy owner** (`RELEASE-MATRIX-20261003-P`,
`ses_f0292f089ffeq9MnxeAHN0yrKb`). New lanes may perform source work, remote Moth
jobs and bounded low-resource image baking; no local Blender/Godot imports,
rendering, encoding, servers or native benchmarks until a new explicit slot.
The pinned Blender is the existing 4.5.14 toolchain. Actual Blender production is
mandatory in the next phase, not replaced by a source-only generator claim.

P was told to finish its current candidate independently. New resources and map
revisions require fresh visual/native acceptance and exact package reconciliation;
existing P/K/L/O results do not validate the new artwork or terrain.
