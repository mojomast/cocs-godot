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

**User-directed escalation rule:** when Flash implementation fails review, resume
the repair with Sol or Astra rather than returning corrective implementation to
Flash. Both Flash map workers have now stopped and preserved their partial edits.
Astra reviewer `ses_efd55fd04ffedSQ6q14ztgmqaa` owns botanical/urban repairs in a
new isolated worktree from `0351e1d1`; Sol reviewer
`ses_efd55bb5cffeJRWNA4xZq8O6cE` owns coastal repairs in a new isolated worktree
from `7a7ce64e`. Partial Flash edits are unverified reference material, not accepted
fixes. These repair assignments are source-only; R retains the sole heavy slot.

Source foundation: `55edd9f2`. All work is isolated from the live P candidate.

| Work | Agent/session | Current responsibility |
|---|---|---|
| New Moth resources + mothbake | Astra `ses_efdbb8a90ffeBrpRZAFfraUSXv` | Complete through `9dc08e53`, parent-integrated; generic tool `69c62d7c`; base + multi-engine overlay reviewed for Blender application |
| Abyssal/coastal variety | Sol `ses_efd55bb5cffeJRWNA4xZq8O6cE` | Corrective source implementation after failed Flash delivery; original Flash worker stopped |
| Botanical/urban variety | Astra `ses_efd55fd04ffedSQ6q14ztgmqaa` | Corrective source implementation after failed Flash delivery; original Flash worker stopped |
| Blender production integration + Foundry | Sol `ses_efdba38e9ffeManqAN9zWiJ3va` | Sole heavy owner R: actual material adapter/Blender toolkit execution, Foundry revision-4 modeling, masters/GLB/reopen/render checks |

Flash/Sol application has now been assigned after Astra's resource delivery and
parent review. Foundation is `190fa2a2`, including the resource merge and Q report.
Flash lanes author source only; Sol executes Blender serially under R, starting
with Foundry. The other five maps require later serial execution of their builders.
No revised map master, export or rendered acceptance is claimed at this checkpoint.

### Source-delivery review checkpoint

- Botanical/urban source delivered as `8cff03b0`, `ddf8c70d`, `0351e1d1`, with
  18 reported Node passes and a Python source suite. Independent Astra review
  `ses_efd55fd04ffedSQ6q14ztgmqaa` reproduced the Node passes but **rejected all
  three revisions** for deterministic build failures, misplaced/omitted geometry,
  invalid traversal probes, a covered lightwell and inconsistent export contracts.
  Complete corrective scope: `map-variety/BOTANICAL_SOURCE_REVIEW.md`. Original
  Astra reviewer now owns corrective implementation; Sol R owns the inherited
  Kit rib-winding fix. The original Flash owner has stopped.
- Coastal initial source `6675a2ce` was rejected by parent for incorrect coordinate
  conversion, invalid mesh faces/arch dimensions and incomplete full-map assembly.
  Corrective `7a7ce64e` reports full authority composition and 37 source checks.
  Independent Sol review `ses_efd55bb5cffeJRWNA4xZq8O6cE` reproduced all 37 checks
  but found further blockers: 61 vertices from 25 Stormglass parts enter road
  polygons; terrain/art duplicates include all 137 terrain surfaces; 21 labels
  are created after batching and omitted from GLB selection; Abyssal top caps
  face downward and nine original reef forms are omitted. Repairs are
  now escalated to Sol reviewer for full-mesh placement, render deduplication, export membership,
  outward winding and reef composition, with regression coverage. The revision
  remains rejected pending review. Neither map-source delivery is integrated yet.
- R continues Foundry production. The shared adapter must preserve original
  linear provider images while producing correctly sRGB-encoded GLB base-color
  images; botanical wording prohibiting all byte re-encoding is not acceptance
  of incorrectly encoded exports.
- Movement package reconciliation `4cd806fa` passes 111/113 parent checks; two
  reject this newly added authoring-resource inventory. Package owner is adding
  exact hash-bound source reconciliation, without treating the maps as produced.

## Reviewed resource delivery and real concurrency

- Initial pack: 30 base families, six derived finishes, 181 lossless PNG channels.
- Multi-engine comparison: all 32 contracts inspected; 31 additional completed
  jobs across image Blur, Deep Fryer, Teleblur, Tessa, Qpixl and Entanglement Shader.
- Selected additive overlay: four image-derived finishes / 20 PNGs, two measured
  coverage masks and two LUT/shader companion sets. Unhelpful/noisy/byte-identical
  variants remain comparison evidence rather than inflated delivered inventory.
- Parent inspected actual comparison and overlay contact sheets and independently
  verified all **201 texture hashes, byte lengths, dimensions and linear color
  declarations**, auxiliary hashes and immutable base-manifest linkage.
- Recorded two- and four-job batches both accepted and completed every job with
  overlapping POST intervals and zero 429 responses. Multiple outstanding jobs
  work; worker execution overlap and maximum concurrency are not established.
- Source pack is approved for **Blender application and review**, not native/world
  visual acceptance. Scalar/image material channels are linear, including albedo;
  the GLB exporter must encode base-color images to sRGB correctly.

Exact comparisons, request evidence and limitations:
`map-variety/MOTH_ENGINE_REVIEW.md`; adapter contract:
`map-variety/MOTH_RESOURCES.md`. Sol `ses_eff6a3d9cffeTi9iQPn43laxo1` published
**11 original PNG comparison/contact sheets** at
<http://100.125.104.79:8796/moth-map-materials/> with **17 HTTP/hash checks passed**.
The downloadable manifest records original paths and SHA-256. These are flat
resource previews, not Blender map renders or native acceptance. K/L/movie bytes
were verified intact. Publication used static files, separate from heavy production.

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
0 textures, 0 images**. This describes embedded GLB content, not absence of runtime
dressing. Its new Blender-embedded finish integration is part of this pass.

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

### Completed source-tool review

Sol subsequently delivered `fb198d07` (referenced color/normal hashes, bounded
GLB texture/accessor inspection, hashed builder-reported lineage and editable
Blender modeling helpers) and `add8a2e5` (open portal perimeter geometry, robust
pipe-frame construction and rigid linked instances). Parent ran all five toolkit
tests successfully, including aperture rays, pipe ring geometry and rejected
texture/normal lineage. Blender API behavior, modifiers, GLB exports, Moth
appearance and native clearance remain unverified until actual production.

Despite the isolation instruction and worker reports, Git history shows these
three source-tool commits were authored directly on `feature/relay-campaign`.
Parent preserved and reviewed those changes rather than overwriting them.
Future application owners must verify their actual worktree and branch before
editing; only parent integrates into the shared branch.

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

**P completed and released** (`RELEASE-MATRIX-20261003-P`,
`ses_f0292f089ffeq9MnxeAHN0yrKb`) at `2026-10-03T15:04:52.013061Z`.
Parent inspected its three empty cleanup audits covering 239 owned process groups.
**Q completed and released** at `2026-10-03T16:24:10.116424Z`; parent inspected
three empty audits of four groups and identical before/after input manifests.
**`MOTH-BLENDER-20261003-R` now owns the sole heavy slot**, owner
`ses_efdba38e9ffeManqAN9zWiJ3va`. Scope: shared material adapter/toolkit validation,
actual Foundry Blender production/reopen/export, bounded native material/physics
review and real captures. Other map lanes remain source-only. No package export,
cinematic encoding or full acceptance matrix is authorized. R must explicitly
release after three empty ownership audits before another heavy producer.
The pinned Blender is the existing 4.5.14 toolchain. Actual Blender production is
mandatory in the next phase, not replaced by a source-only generator claim.

The user-requested broader engine evaluation and concurrent-generation test are
complete, as recorded above. User cleanup subsequently freed 91 GiB on disk;
the original 1.17 GB/late low-space figures above are historical.

P finished its frozen candidate independently: 89 passed, 22 failed, 31 unrun;
release readiness remains false. New resources and map
revisions require fresh visual/native acceptance and exact package reconciliation;
existing P/K/L/O results do not validate the new artwork or terrain.
