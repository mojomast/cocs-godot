# Helix Conservatory surface finish — source lane

Status: source-ready profile; shared binder integration and native appearance review pending.
Base: `3d2a4901`, branch `map-finish/helix-20261002`. Authoring seed: `610022`.

## Implementation and coverage

`godot/multiplayer_worlds/dressing/profiles/helix-conservatory.json` uses the
contract's original v1 fields. Nine unique exact source-material assignments,
46 supported texture insets/weather patches, 13 district/route/service signs,
four plant-local pollen pockets (48 motes). Ceilings: 12 material variants,
64 panels, 20 signs, 72 motes. These are authoring limits, not measured frame cost.

| Accepted GLB source | Real family / variant | Treatment |
|---|---|---|
| verdigris | oxidised-copper / default | Patinated irrigation, structure and central metal; very restrained LUT sheen |
| soil | regolith / default | Brown granular growing medium, high roughness |
| stone | regolith / mossy | Moss-damp terrace and retaining stone |
| ceramic | pearl-ceramic / polished | Cleaner pearl archive/pavilion and ring paving |
| brick | pearl-ceramic / worn | Rough warm mineral terrace/archival masonry |
| gold | brushed-alloy / default | Muted champagne maintenance stock and archival drawer frames |
| solar | brushed-alloy / circuit | Dark blue etched opaque technical panel, not glass or neon |
| leaflight | regolith / verdant | Lighter grass-derived leaf surface; no pulse/glow |
| botanical | regolith / verdant | Darker grass-derived foliage, same authored silhouette |
| glass | explicitly preserved | Existing BLEND, alpha 0.08, double-sided; no paint mounts |

Every accepted material is accounted for; unmatched selectors **zero**. Binary
inspection confirms foliage is opaque and double-sided, not cutout/BLEND;
`family.gdshader` is cull-disabled and opaque, preserving that intent. Glass
remains its imported transparent material. Solar remains opaque and a separate
technical assignment. Exact source selectors necessarily affect all instances
of that material; gold includes archival stacks, root brackets and inlays, so
its palette is deliberately warm rather than cold maintenance grey.

The native family binder resolves base PNG, packed AO/roughness/detail PNG,
normal PNG, optional etched circuit mask, and LUT through the existing Moth
registry. `source-proof.json` lists **32 actual PNG paths with hashes**, including
baked and derived normal families. No GLB re-UV/export or new embedded texture
claim. Family world-space triplanar is the surface projection solution.

## Grounded detail and shared-owner request

Existing revision-2 geometry already contains 16 articulated fronds per garden
bed and 32 at the central specimen, with multi-segment vertices, double-sided
opaque leaves and no leaf collision. The inspected overview and player views
show this real authored foliage. Additional geometry is not necessary to repair
an absence of foliage; source recipe/master stays intact.

Deterministic weather placements are small lower-wall/planter-foot patches:
damp concrete on archive stone, oxide at filtration feet, worn mineral at the
pavilion plinth, moss/root stains on seeded botanical bed faces. Pump access
insets are supported by actual machinery faces; nine short vessel-base oxide
waterlines are bounded to actual individual cylinder facets. No quad covers glass, routes,
doors or foliage. Signs use real district names and existing route names, plus
pump isolation records. They do not promise gameplay objectives. Motes occupy
existing fern crowns, not map-wide fog.

**Request to shared Sol:** the initial schema can render real texture patches,
but has no blend-mask controls. Please add/document a backwards-compatible panel
extension for `wear_mask` (existing Moth texture key, suggested `dust-field`),
`opacity` (0..1), `feather` (0..0.5 panel UV edge width), and `seed` (stable integer
UV offset). Wear panels should multiply texture mask luminance by edge feather
and opacity; service insets remain opaque. Proposed local treatment: archive/
pavilion patches opacity 0.22, planter moss 0.30, filtration oxide 0.18, feather
0.15; seed `610022 + placement index`. Reject missing mask resources and bound
inputs. This profile intentionally uses only the documented original schema
until the shared owner publishes supported fields. **Soft blended wear masks
are therefore a remaining integration request, not a completed visual claim.**
The textured base families already use their real packed data maps and circuit
mask; these should not be confused with a localized wear-alpha mask.

## Source verification

Run from repository root:

```sh
python3 port/map-finish/helix-conservatory/finish.py
python3 port/map-finish/helix-conservatory/finish.py --self-test
```

The script parses the accepted GLB JSON and BIN accessors without an engine;
checks its exact SHA-256; verifies support triangles by material against the
decoded binary; checks all four quad corners against real planar source faces;
checks +Z face yaw, 18mm clearance, text fit, human-scale placement, bounds and
budgets; parses actual family/variant and library option bounds; checks PNG
existence/signature/dimensions and records hashes. Generation is repeatable with
`--write`. The profile contains no collision/physics resources.

Geometry identity: `f068d1abe262907659f1f02205e2bf56b7c5dbe298191f66d008b420965fa9b2`.
Accepted GLB SHA-256:
`0c462ffa475f02aa388101c38339d6d81eb3df9549a7d664ca65ec390c802d88`.
Prior authority, accepted master, source collision and GLB are unchanged.

## Evidence inspected and future native jobs

Read the accepted revision-2 `FINAL.md`, actual recipe, decoded GLB materials,
and these existing images under
`/home/mojo/.tmp-on-disk/cocs-new-map-conservatory-evidence-20261002/revision-2-final/`:
`overview.png`, `archive-eye.png`, `irrigation-eye.png`, `pavilion-eye.png`,
`lightwell-eye.png`. They establish distinct vaulted archive, stepped filtration,
glazed pavilion, articulated central specimen and planted terrace forms. Plain
untextured expanses and uniform peripheral plant species remain visible in
these **before** images; this lane has not rendered an after image.

`native-jobs.json` plans an overview and 1.65m eye-height closeup for each of five
districts: archive, irrigation, pavilion, lightwell and botanical terraces. Eye
elevations come from identified actual walkable source triangles. Native owner
must check sightlines and tune framing, then capture comparable before/after,
normal gameplay, compact HUD, Low/Full/Off and reload/cleanup; record actual
renderer, material matches/resources, node counts and measured frame cadence.
Specifically review patch blending, narrow-facet sign legibility, grass-derived
leaf normals, dark circuit solar roof readability and ceramic brightness.

No Godot, Blender, import, rendering, audio or encoding tools were run. The
exclusive combined native grant remains with integration Astra. No new visual,
FPS, nine-fight, human-balance or final acceptance claim follows from this proof.
