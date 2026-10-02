# Campaign biome architecture pack — source candidate

Status: **READY FOR BLENDER; awaiting explicit parent grant.** Assigned base
`e9d784a7`, branch `expansion-four/scenery`. Parallax retains the heavy slot.

## Actual-source audit before design

- `tools/godot-campaign/compile.mjs:14–17` and the four committed
  `godot/campaign/generated/*.json` define distinct route footprints, terrain,
  encounter anchors, workshops and chapter handoffs. The pack reads these actual
  files. It does not create substitute test maps.
- `godot/campaign/structure_art.gd:10–14,23–44` already selects eight Blender
  facade families, fitted to the terrain and original named blocks. Rootfall is
  a single cabin/relay shell; other chapters split tall structures into <=5 m
  profiles. The older structural README's box-collision description is stale:
  **current** `terrain.gd:194–210` makes boxes only for rock. Non-rock native
  weapon collision uses LOD0 facade triangles (`structure_art.gd:68–83`).
- `port/edge-effects/structure-rays.mjs` uses the same old GLBs and baked triangle
  oracle. Movement still uses source block bounds. Empty side/roof space inside
  an AABB is intentional shot clearance, covered by `edges.test.mjs`.
- `terrain.gd:230–249` already binds the bespoke fallen relay and Crown receiver.
  Their source/master generation stays intact. Existing ground flora already
  includes forks/roots/ferns, reeds/cobbles, basalt/scrub and highland planting
  (`tools/godot-campaign/environment-art/README.md`). Broad scattering would add
  clutter rather than fill an actual architectural gap.
- `port/native-campaign/interlude-definitions.mjs` and
  `godot/campaign/interlude_director.gd` own eight optional workshops, their
  controls, restored wheel/rotors, choice racks, cables and source eligibility.
  The robot lane owns enemy bodies and six small workshop props. This pack adds
  architectural/natural structure reliefs on reviewed supports, not new controls.

## Authored assemblies

All twelve are original named additive meshes. Existing frames, roofs, foliage,
landmarks and workshop machinery stay present. No old asset is overwritten or
silently hidden. Each master retains separately named editable components;
runtime export joins components into one mesh with at most four opaque material
surfaces per LOD. The approach is intentionally bounded to the existing structure
envelopes: no new playable room, platform, portal, terrain or collider is implied.

| Chapter | Asset ID | Role / form | Exact original block | Recipe triangles near/far |
|---|---|---|---|---:|
| Rootfall | `rootfall-canopy-relay` | Hero; four splayed root buttresses, folded canopy panels and split copper relay spine | `interlude-canopy-nursery-rib-2` | 404 / 324 |
| Rootfall | `rootfall-root-archive` | Coursed bark archive relief and copper lashings | `landmark-2-Root archive` | 608 / 488 |
| Rootfall | `rootfall-root-buttress` | Unequal fork structure and relay collar | `interlude-nursery-nursery-rib-1` | 484 / 404 |
| Siltwake | `siltwake-strata-wheelhouse` | Hero; seven recessed stone courses, open mill rims, ten spokes and bucket fittings per face | `interlude-waterwheel-wheel-house` | 1776 / 1132 |
| Siltwake | `siltwake-sluice-bank` | Layered bank, closed sluice louvers and channel guides | `interlude-waterwheel-dry-berth-left` | 684 / 600 |
| Siltwake | `siltwake-flood-abutment` | Inclined flood supports, coursed bank and bevelled capstone | `interlude-waterwheel-dry-berth-right` | 544 / 460 |
| Emberline | `emberline-heatshield-tower` | Hero; fractured hex basalt, folded copper shields and return spines | `interlude-condenser-cooling-fin-2` | 576 / 408 |
| Emberline | `emberline-basalt-terrace` | Unequal basalt terraces with recessed shielding | `basalt-uplink-0-3` | 440 / 272 |
| Emberline | `emberline-ceramic-exhaust` | Three unequal exhaust stacks, shield bank and basalt supports | `interlude-foundry-cooling-fin-3` | 588 / 420 |
| Crown | `crown-faceted-antenna` | Hero; tapered ceramic pilasters and nested six-sided antenna reliefs | `interlude-choir-choir-pier-2` | 548 / 508 |
| Crown | `crown-ceramic-lightwell` | Deep ceramic reveals and optical core on a closed facade | `interlude-garden-choir-pier-2` | 436 / 396 |
| Crown | `crown-folio-archive` | Folio fins, ceramic lintels and indexed pediment | `court-buttress-2--1` | 580 / 372 |

The Siltwake architectural wheel relief is static and separate from the existing
source-restored rotating workshop wheel. Its vertical aspect is corrected for
the reviewed 8 × 14.48338471015 × 5 m fitted house. Crown's lightwell is a recessed
architectural relief on a closed support, not a falsely traversable entrance.

## Geometry, placement and materials

`tools/godot-biomes/expansion/recipe.mjs` emits triangulated lofts, splayed beams,
bevelled stone courses, open annuli and folded plates. Geometry, not a shader or
palette swap, creates the forms. Fixed seed `20261002`; no unseeded scatter.
`compile.mjs` fits the actual original source block using the existing
`structurePlacements()` terrain sampler. Runtime `catalog.json` records exact
origin, scale, block ID, chapter file SHA and canonical geometry hash.

All authored vertices lie inside local X/Z ±0.5, Y 0–1. Every full fitted volume
passes conservative swept player-route clearance. No collision objects are
exported or created; the adapter rejects them. There is no additional ground
decoration. The eight `biome4_*` StandardMaterial names are explicitly allowlisted
in the catalog: bark, moss, sandstone, silt, basalt, copper, ceramic, iron.
They are rough opaque PBR materials (roughness >=.67), with no emission,
transparency, custom shader or ambient/weather hook. World may enroll only these
new materials in its restoration mechanism; original resources are not mutated.

Each LOD is independently exported. Far LOD removes lashings, buckets, datum marks,
fasteners or archive indices, retaining the architectural form. Near/far switch
is 85 m; reduced-detail mode shows only far meshes. Three placements/chapter mean
<=12 visible base material surfaces, <=24 loaded across both LODs. Shadow passes,
occlusion, actual rendered prominence and cost still require native measurement.

## Provenance and integration boundary

New mesh recipe SHA-256:
`e8aea379d5d12de3b2566f2af5b5a0312bcc5db3f4847c258c19294a93a8f577`.
This is **new pack provenance**, not a changed campaign canonical hash.
All four campaign JSON files, old art bytes, source compiler, facade ray adapter,
baked facade triangles and generated campaign core are unchanged against assigned
base. The six focused tests enforce that fact. Any future authority/recipe change
requires parent review and matching source checks; this checkpoint cannot cover it.

The adapter is `godot/biomes/expansion/scenery_pack.gd`. It atomically loads a whole
chapter's six LOD files, checks chapter/hash identity, rejects collider nodes, and
has explicit reduced-detail and teardown APIs. Missing unbuilt GLBs leave the
original production art intact. A tiny terrain composition hook is isolated in a
separate commit for parent review; no shared catalog/settings/package edits occur.

This source candidate does not establish that every new surface is visually
prominent outside the retained facade. Native old/new review must reject hidden
work, repetitive reliefs, bad joins or an insufficient hero silhouette and revise
the authored pack before acceptance. Counts are budgets, not art approval.
