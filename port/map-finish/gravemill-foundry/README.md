# GRAVEMILL FOUNDRY rev3 — source-ready production finish

## Apply / reproduce

Cherry-pick this lane's commit and use the shared dressing binder with
`gravemill-foundry` and geometry hash
`8ebb148f209aca14c54246517f7332a18e5fbb5c68f7b607d980f5664fcde25f`.
The profile uses CONTRACT.md v1 plus shared optional feathered-wear fields,
documented in `port/map-finish/shared/README.md`.

Run `python3 port/map-finish/gravemill-foundry/author.py` from the repository.
This deterministically writes the map profile and `source-validation.json`.
It uses Python's standard library and Node to evaluate the existing rev3 recipe;
it never invokes Godot or Blender. No new image assets or imports are needed.

The accepted GLB's eight exact material names were parsed from its JSON chunk.
It contains **zero embedded textures**. Runtime family assignments below bind
real existing Moth PNG albedo, normal, and derived `data--` maps. These are not
claims that the source GLB has acquired texture images. The library's
`_shape()` binds these maps and `family.gdshader` projects them triplanarly.
Derived data drives roughness variation; `normal_strength=0.32` is nonzero.
Every map material disables LUT glow and temporal pulse. Low-resolution Moth
tiles remain 48–64px; densities are 0.55–1 tiles/m, not photographic detail.

| Exact source | Family / variant | Real base + normal | Story |
| --- | --- | --- | --- |
| GM / soot | brushed-alloy / plate | diamond_plate / baked diamond_plate | Readable grey working steel, not uniformly black walls |
| GM / mineral | regolith / scoured | rock / baked rock | Desaturated mineral ground and stratified rock masses |
| GM / copper | oxidised-copper / default | metal-oxide / derived normal--metal-oxide | Verdigris process piping and vessel shells |
| GM / brass | oxidised-copper / riveted | riveted_armor / derived normal--riveted_armor | Warmer tarnished structural trim |
| GM / ore | oxidised-copper / scorched | riveted_armor-scorched / derived normal | Heat-distressed kiln casing and iron-rich strata accents |
| GM / orange | hazard-industrial / default | hazard_stripes / baked hazard_stripes | Existing machine hazard accents, without additional glow |
| GM / chalk | enamel-glaze / default | hex_paneling / baked holographic_grid | Clean maintenance/inspection stock |
| GM / cooling-floor | enamel-glaze / damp | weathered_concrete-damp / derived normal | Cooler damp concrete with roughness 0.46 for floor readability |

Coverage is 8/8, with no preserved exclusions. All selector roles are necessarily
shared because the accepted export batches geometry into eight material meshes.
Localized panels establish additional district differences without replacing
architecture, rebuilding UVs, or altering those batches.

Shared integration follow-up: 16 authored grease, soot, waterline and kiln-heat
patches now explicitly serialize `wear_mask=dust-field`, `feather=0.15`, bounded
opacity (grease 0.28, soot 0.24, waterline 0.22, heat 0.26), and stable per-panel
seeds `610024 + panel index`. Abrasion/access plates, grates, enamel and hazard
strips remain opaque physical insets. The author generator and resource receipt
include the new fields; no runtime ID guessing or stale hand-edited profile.
Rendered alpha/normal/roughness response remains pending native review.

## District finish and placement proof

Coordinates use world-local Godot metres, Y up; source q converts to
`z = q + 0.14*x`. Standard q wall fronts rotate -7.96961 degrees about Y;
reverse fronts add 180 degrees. The transfer wall uses its actual diagonal
`dz/dx = .14 + 11/53`. All quad fronts are local +Z.

- **Crusher C1:** measured beds at (-72,q=-7) and (-48,q=0). Base heights
  are 2.4m and 4.08m, respectively. Metal abrasion/access plates attach to their
  south faces; grease-dark oxide bands to rear base faces. Pinch/isolation
  labels and hazard strips are on these actual machine bodies. Back wall has
  bounded scorched patches, not a whole-map brown noise overlay.
- **Cooling C2:** four closed recess-bank faces at x=-84/-48 carry damp chalk
  waterlines at y=12.8 and grating access panels at y=14.6. Circuit labels sit
  above the panels. The sector sign uses the closed x=-76.3..-70 wall segment,
  not a window. Oxide piping remains the existing copper mesh.
- **Assay A3:** cleaner enamel inspection surrounds on six actual lintels at
  q=32/40, y=19, with sample station IDs. Their bottom edge is y=18, clear of
  existing authored instrument plates near y=16.8. Window apertures remain
  empty. The exterior district sign uses the closed x=70..76.3 segment.
- **Furnace F4:** heat-distressed panels and hazard strips on three actual kiln
  buttresses, rear wall soot patches, and rear-wall hot-stock warning.
  No warning signs are suspended in the arch openings.
- **Transfer T0 / service return / crown:** transfer identifier follows the
  diagonal south wall. Service-loop labels attach to existing hopper bodies
  at x=-132/+134,q=-98. Crown gets the same real steel/mineral/copper surface
  finish; its existing gantry parapets are preserved.

Panels clear backing by 45mm. Signs clear it by 65mm, including labels over
panels, so the two layers do not occupy the same plane. `source-validation.json`
records every support ID, exact point, normal, size and offset. The validator
tests 25 points per footprint against the UNION of recipe wall triangles and
checks each center against the actual exported GLB triangles. Its resource
receipt hashes every resolved PNG, including family LUTs and the hazard mask.

Moth pockets are local: 12 ore-dust motes above the receiving hopper at
(-72,25.3,-17.08), 12 ash motes above the furnace stack at (64,33,.96), and
8 vent motes above a cooling bank at (-84,18,18.74). They are outside
player-eye-height routes; no full-map fog volume is authored.

## Missing-detail disposition

The finish supplies grating/access faces, localized wear, circuit identifiers,
sample inspection labels and actual machine hazard markings. Existing drums,
trusses, pipe networks, kiln courses, instrument plates, bins and crown
parapets are already present in the accepted author and baseline views.
Additional loose clutter would add occlusion on the maintenance aisles.

Optional future map-local recipe proposals, **not part of this profile**:

- Add visual-only bolt heads on the crown's existing solid parapet top:
  x=-100..-46,q=104/114,y=25.12, 0.04m radius, 6m spacing. Their footprint stays
  on the 0.4m existing parapet. No new handrail across a gantry opening.
- Small 0.18m valve handles on existing cooling bank grating faces at
  x=-84/-48,q=29.4/42.6,y=14.6, maximum projection 0.10m. This is detail on
  an already solid bank, not free-standing collisionless machinery.

These are bounded detail recipes only; no new floors, ceiling, collision,
route layout or architecture is requested. The existing 767.64m Puma service
loop has no new obstruction from the attached profile quads.

## Native before/after review handoff — pending

Baseline evidence inspected (not regenerated):
`/home/mojo/.tmp-on-disk/cocs-new-map-foundry-evidence-20261002/revision3-production/`
`native-final-views/{overview,crusher-maintenance,cooling-eye,assay-inspection,furnace-eye}.png`
and `native-centered-views/{cooling-cross-aisle,assay-room-centered}.png`.
These expose the original flat steel/black faces and unlabeled process bays.

Under the integrator's exclusive FINISH-COMBINED-NATIVE-20261002-A grant,
repeat the existing final and centered camera suite with identical camera
transform, FOV, environment, viewport and timestep, once Off and once Full.
Use the original native suite for exact baseline framing; do not substitute
Blender framing. Additional targeted review cameras (eye / target in metres):

| District | Eye | Target | Review |
| --- | --- | --- | --- |
| Crusher maintenance | [-88,5.01,-20.32] | [-72,5.9,-25.08] | Base abrasion/grease, warning legibility, drum silhouette |
| Cooling recess | [-84,13.65,13.24] | [-84,14.3,17.64] | Waterline, grating, oxide pipe contrast |
| Assay central aisle | [66,13.65,45.24] | [66,19,41.24] | Clean enamel/label and open inspection window |
| Furnace apron | [80,1.65,-18.8] | [80,6,-10.3] | Heat wear, actual buttress hazard backing |
| Transfer | [0,1.65,-88] | [0,6,-77.81132] | Diagonal wall label orientation |
| Crown | [0,25.65,109] | [64,25.5,117.96] | Ground/gantry steel density and skyline |

Native gate also includes normal play, compact UI, service loop visibility,
Off/Low/Full, teardown/reload and actual cadence/renderer receipts. Existing
baseline logs use llvmpipe: elapsed capture time is not GPU FPS. Source checks
establish backing, coverage, resource existence and budgets, **not** native
image quality or performance. First integration should inspect sign readability,
grating scale, roughness contrast and panel seams at oblique angles.
