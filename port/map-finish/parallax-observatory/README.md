# Parallax Observatory — source-ready surface and environment finish

Runtime profile: `godot/multiplayer_worlds/dressing/profiles/parallax-observatory.json`.
This is **profile v1 source, not native visual acceptance**. The shared binder is
owned by Sol `ses_f022e500bffebtq1Cb9LHX7oqY`; native execution belongs to Astra's
`FINISH-COMBINED-NATIVE-20261002-A` grant.

## Baseline and identity

Inspected branch history: `cb224bcb` contract, `3e9bf9e5` source-only interiors-v2,
`277f379e` six-mode hooks, `9a6372b4` accepted prototype production.

- Geometry hash: `906be2ae3df33f54f779df3963a5985376ac96bb75bda94578ca4d3deb6d4554`.
- Accepted GLB SHA-256: `b3ea4ec57f57f6db83e1acab40dc95135562347ef884cc8f33ba067af8521bb1`.
- Accepted master SHA-256: `fcd7f284443c45d08177837a23af530b1667deb106bddb8822d507f5655ca090`.
- Actual GLB inspection: seven identity-transform batch nodes, seven exact named
  material slots, no images or textures. The original materials are opaque and
  double-sided. **`mirror` is opaque optical alloy, not glass**; no glass slot
  exists in this accepted asset. `sea` is the sole intentional exclusion because
  it is distant tidal scenery below the lethal void. Unmatched selectors: zero.

The pending interiors-v2 candidate is not production and has not been rebuilt for
this finish. Its source retains the same seven material names, so the global
family selectors remain compatible. Its recessed equipment replaces accepted
cabinet faces: **panel/sign backing checks must be repeated and placements
rebased after candidate promotion**. The validator intentionally pins the accepted
GLB; it will fail on a substituted candidate rather than silently certify it.

## Surface/material story

| Exact GLB selector | Existing family / variant | Treatment |
| --- | --- | --- |
| `saltstone` | `pearl-ceramic / cast` | Desaturated exposed concrete, restrained normals, rough salt-weathered mineral grain |
| `cistern` | `enamel-glaze / damp` | Blue-grey damp mineral paving in the lower tidal district |
| `metal` | `brushed-alloy / default` | Matte brushed instrument housings, roofs and trusses |
| `mirror` | `brushed-alloy / default` | Finer, smoother calibrated optical alloy; restrained glare and normal strength |
| `paving` | `regolith / scoured` | Cut-stone survey inlays and coastal strata with a coarse rock texture |
| `ochre` | `oxidised-copper / default` | Weathered calibration stock with low-saturation oxidation and roughness breakup |
| `sea` | preserved original | Intentional below-void scenery exclusion |

These are real baked/derived Moth resource bindings through the existing material
language. All six bind a base texture, exact baked/derived normal and packed
AO/roughness/detail map. `source-check.json` lists the resolved resource paths and
SHA-256 checks. Existing world-space triplanar projection needs no UV or tangent
assumption. Density is 0.65–1.1 tiles/metre; no displacement or collision changes.
All surface LUT gains and pulse speeds/depths are zero to keep scientific
architecture glare-controlled and prevent emissive wall/floor noise.

## Grounded district detail

Existing overview, archive and pump images were opened from
`/home/mojo/.tmp-on-disk/cocs-new-map-observatory-evidence-20261002/native-review/`.
The archive/pump share the same long box, panel rows, piers and ceiling rhythm;
colour alone does not solve that architectural repetition. The queued interiors-v2
equipment anatomy addresses the larger issue. This profile adds distinct surface
function and legible storytelling to the **currently accepted** geometry:

- **Archive:** 18 small clean ceramic cabinet-edge inserts leave cassette slots
  visible; four restrained row/retrieval indices occupy the clear band above the
  cabinet tops. Two entry plaques name the plate archive on actual portal jambs.
  One four-mote shelf pocket is bounded to a quiet wall-adjacent corner.
- **Pump:** eight damp mineral backing films distinguish the low hydraulic
  equipment from archive storage. Six narrow oxidation bands sit below the wall
  dado and avoid the pressure risers. Four supply/return labels identify service
  runs, with two T3 entry plaques and two eight-mote header vent/mist pockets.
- **Polar hall:** four localized cold upper-wall frost patches, four small
  holographic calibration readouts inside real spectrometer hubs, two low sector
  labels and two six-mote cold-wall vent pockets. Frost avoids all playable floor
  and portal surfaces; it is not a frozen-everywhere re-theme.
- **Calibration/optical routes:** eight diagnostic holographic/circuit faces on
  the blank inward faces of source-solid calibration pedestals. They do not cover
  telescope petals, star-chart geometry or any open view aperture.
- **Coastal institute/arrival:** four small salt-weathered footing strips along
  actual exposed wing facades, two arrival district/altitude plaques and two
  north/south tier signs. Survey inlays and silhouettes stay legible.

There are 52 panels, 18 signs, five pockets and 32 motes. Budgets are source
ceilings (6 material variants / 64 panels / 24 signs / 40 motes), not measured
draw-call or frame-cost claims. Mounted wear films use existing Moth texture keys;
no new image assets or provenance claims are introduced.

## Placement proof and shared integration

`author.py` deterministically authors the profile and `mounts.json` (host + story
for each plaque). `validate.py` independently reads binary GLB positions/indices,
verifies exact selector coverage and every resolved PNG hash, checks family option
keys/bounds against the actual existing tables, and samples a 5×5 grid behind
each panel/sign against accepted triangles. All 1,750 samples find solid backing
within 0.004–0.1 m. Each rectangle fits entirely within a named source-solid
block face silhouette. Coplanar plaque overlaps fail. Pocket spawn envelopes are
checked against accepted block collision, and plaque aspect ratios bound text.
This source proof does not establish rendered text layout or visual quality.

Actual exported GLB normals are also inspected and their signs recorded per
mount. Some accepted box backings have inward-facing exported normals; those
hits are accepted only on the existing double-sided material. Mount front +Z is
chosen from the verified host's corridor/exterior direction, not blindly copied
from a flipped box normal. The existing family shader retains `cull_disabled`
and its `FRONT_FACING` normal correction.

Fronts are local **+Z**. Yaws are 0° (+Z), 180° (-Z), +90° (+X), and -90° (-X).
Archive and pump approach signs face outward from the end jambs; interior panels
face into the corridor from the side walls. Full-width door/aperture overlays and
fake walkable decorative geometry are absent.

**Required new shared schema fields: none.** The profile uses the exact contract
v1 fields. Please keep non-diagnostic texture panels lit/non-emissive; six global
material options explicitly disable glow gain. Only `holographic_grid` and
`circuit_board-etch` panels are diagnostic equipment accents. No dependency on a
future spatial material selector or custom-resource panel field is introduced.
The binder should resolve `tint` through its normal JSON-to-Color conversion and
honestly return missing-resource diagnostics. This lane changes no shared loader,
shader, catalog or mode code.

## Reproduce source checks

From the map worktree or a parent checkout containing the accepted production:

```sh
python3 port/map-finish/parallax-observatory/author.py --write
python3 port/map-finish/parallax-observatory/validate.py --write-report
git diff --check
```

The checked-in profile is the output of the author; validation rejects drift.
`source-check.json` is the actual passing source receipt. The validator requires
no third-party Python modules. Generated `.pyc` files are ignored locally.

## Native handoff

See `REVIEW.md` for exact comparable cameras and close-up pairs. Godot parsing,
resource import, rendered before/after inspection, normal gameplay, compact UI,
Off/Low/Full counts, idempotent reapply, teardown/reload and actual renderer/frame
cadence remain **pending**. No Godot, Blender, audio or encoding job was run here.
