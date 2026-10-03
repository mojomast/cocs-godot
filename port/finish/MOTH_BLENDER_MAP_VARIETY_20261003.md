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

## Owners and completed preparation

Source foundation: `55edd9f2`. All work is isolated from the live P candidate.

| Work | Agent/session | Current responsibility |
|---|---|---|
| New Moth resources + mothbake | Astra `ses_efdbb8a90ffeBrpRZAFfraUSXv` | Authenticated live catalog/schema discovery, actual new API jobs, recorded outputs, deterministic material bakes, generic tool updates and handoff manifest |
| Industrial/coastal variety | Flash `ses_efdbb1dfeffebxsWuzs9jbjzJv` | Audit completed; blueprint in `MAP_VARIETY_REVISION_BLUEPRINT_20261003.md`; application not started |
| Botanical/urban variety | Flash `ses_efdbaaa61ffesiVbXI7pmlS04Q` | Audit completed; findings summarized below; application not started |
| Blender production integration | Sol `ses_efdba38e9ffeManqAN9zWiJ3va` | Initial receipt `c6db6393` delivered, not integrated; resumed for review corrections and source-only Blender modeling helpers |

Flash/Sol application follows Astra's usable resource delivery and parent review.
The current audit/preparation work does not substitute for actual asset production.
Parent must assign the implementation lanes and the next explicit Blender/native
slot once the dependency and ownership boundaries are ready.

## Audit results and parent review

Both Flash audits completed without engine or Blender execution. Material requests
from both were relayed to Astra. Their asset counts and budgets are design targets,
not produced inventory or measured runtime performance.

| Map | Observed repetition | Proposed Blender forms and layout work |
|---|---|---|
| Helix | Flat terrace ribbons, blank archive walls, thin greenhouse framing | Stepped soil/retaining masses, botanical grotto, root forms, curved greenhouse ribs, differentiated archive bays |
| Parallax | Repeated window bands, empty connective interiors, uniform archive racks | Distinct instrument halls and towers, stepped courts, lightwells, differentiated scientific-room equipment |
| Vesper | Similar building boxes, blank brick facades, repeated windows/doors | Multiple architectural facade/roof families, market arcades, canal/viaduct masonry, stair/retaining terraces |
| Foundry | Repeated hoppers/bins/filter banks; missing embedded texture finish | Gantries, furnace batteries, rail/loading structures, varied ore clusters, crusher machinery and real Moth texture integration |
| Abyssal | Repeated vessel shells, gallery forms and reef spacing | District-specific pressure vessels, pipe manifolds/bridges, observation blisters, reef/escarpment forms |
| Stormglass | Repeated road shoulders, modules, gates and coastal structures | Varied retaining walls, cliff terraces, gatehouses, grandstands, lighthouse and quay cranes |

Parent independently inspected Foundry's current GLB: **8 meshes, 8 materials,
0 textures, 0 images**. Its new finish integration is part of this pass.

The botanical audit flagged Vesper's historical `6917cffc…` identity in
`ASSET_PRODUCTION.md`. Parent recomputed the current full canonical arena hash
from both runtime wrapper and source arena: both equal
`27c71cc8895eab2ca3a0b5cae3c2b8f96ed9afd75db3deec4a5c96bd2f395ea7`.
The older document records an earlier admission stage; it is not a second current
runtime identity. The export path is `art/worlds/vesper-viaduct.glb` (the audit's
`vester` spelling was a typo). Future revisions must use current source identities.

Implementation corrections to the proposed blueprints:

- Detailed new asset forms must actually be constructed in Blender with editable
  source collections. Merely importing recipe triangles and re-exporting them does
  not fulfill the requested modeling pass. Authority proxies remain separately
  authored and must agree with visible walkable/blocking forms.
- For revised Helix geometry, compare optimized and reference navigation on the
  **same new geometry**. Its graph need not equal the old graph after deliberate
  layout changes. Preserve the broadphase optimization and measure new performance;
  the audit's suggested 1.5-second bound is not an adopted acceptance threshold.
- Stormglass's current race code uses flat support, Y=0 spawn/reset positions and
  fixed gate-height bounds. Real road grades require a coordinated versioned
  terrain/race/vehicle revision. Coastal scenery alone does not remove the existing
  zero-drivable-relief concession. No such runtime change has been made here.
- Sol's initial receipt needs stronger texture-reference, normal-source and
  source-to-packed-image checks before adoption. The parent requested focused
  rejection tests and genuine Blender modeling helpers; no built/native pass is
  implied by `c6db6393`.

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
