# Foundry R6 — actual W production

Grant: **MOTH-BLENDER-20261003-W**, from parent `e66fce84`, isolated branch
`astra/foundry-finish-W`. Source attempt `54caaed9`, P1 correction `90dd354a`, their
old source reports/manifests, and the original S release remain historical evidence.
No R4/R5 artifacts or production package policies are changed.

## Actual artifact identity

- Art: `godot/multiplayer_worlds/art/revisions/gravemill-foundry-r6.glb`
- Art SHA-256: `945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c`
- **87,566 triangles; 16 mesh nodes; 32 material primitives; 15,012,396 bytes.**
- 18 materials (seven new finish roles); 36 embedded PNGs.
- Master: `gravemill-foundry-revision6.blend`, **6,346,401 bytes**, SHA-256
  `9922b7be04bbc64deda53f0082ec279a2b81f17d5e280d476e74d5b5d12252d8`.
- Fresh reopen: 270 editable geometry references hidden from render, 16 editable
  export mesh objects, 40 packed images. All 87,566 material/UV/position triangle
  assignments match: **zero position error**, maximum UV error `3.814697265625e-6`.
- R5 authority remains `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
  R6 has a distinct actual `artHash`; native stage asserts both identities.

`evidence/W/production-report.json` collects actual verification, per-stream hashes,
native readback, extracted-image hashes, all 22 screenshot hashes, timings and scope.
`built-verification.json` is the actual GLB proof, not the synthetic-library test.

## Structural / pixel checks and the tangent limitation

The shared strict container/scene/accessor gate passes on the actual composed GLB.
Original R5 POSITION/NORMAL/TANGENT buffer bytes remain identical, including oriented
triangle multiplicity. All seven new materials pass actual reviewed-pack sRGB,
normal and roughness-channel pixel checks; retained R5 materials including orange
are exactly unchanged. All 36 Godot-extracted PNG files match their GLB payloads.

Native import is pinned to full-precision positions and disabled generated LODs,
retaining the actual Godot-generated UID. Native readback confirms exact position,
UV and clockwise triangle multiplicity and **51 decoded material/channel image
matches**. Normal error is at most `0.0001078248`; defined tangent error is at most
`0.000166595`, from Godot's native direction encoding.

**Seven inherited R5 tangent corners have zero direction**: six on retained copper,
one now assigned the ground role. Their source bytes remain unchanged in R6.
Godot decodes them to `(-0.0000305185, 0, -1, +1)`; this is a substitution, not
direction preservation. Every corner/source/native value is recorded in
`evidence/W/native-proof.json`. They are not silently omitted or claimed approved.
Independent review must decide whether this inherited limitation is acceptable or
authorize a separately scoped tangent-only correction; such a correction would
change the exact-R5-tangent requirement. The defined-direction checks remain strict.

Eight targeted native rays were freshly run in the exact R6 stage and pass.
The 3,849-capsule R5 receipt remains **prior same-geometry evidence**, not a W rerun.

## Eleven native pairs examined

`evidence/native/` contains 22 original 1280×720 engine PNGs. Before means **staged
R5**, not the pre-R5 accepted runtime. Every pair uses identical camera, FOV and
production weather/dressing setup. No edited/composited evidence images are supplied.

| View | Actual R6 observation against R5 |
|---|---|
| overview | Warm kiln district and grey crusher roof distinguish building functions; large pale exterior ground remains |
| crusher-roofline | Ribbed steel roof separates from the retained copper cooling roof; large wall infill remains restrained |
| crusher-eye | Dark rotating machinery reads separately from pale cast foundations and walls |
| crusher-maintenance | Cylinder ribs are visible at player height; contrast improves, though the repeated steel texture is still noticeable |
| bunker-player | Brown/rust surge shell, dark cap and cast base read as separate functional parts |
| furnace-eye | Warm masonry separates from retained green furnace vessels; orange inspection strip survives |
| furnace-skyline | Warm furnace shell is a distinct landmark; broad pale ground/roof repetition remains an art-review concern |
| kiln-eye | Refractory framing and dark service metal are clearer than the previous pale treatment |
| cooling-eye | Copper vault, fixture lighting and circulation guidance remain readable |
| transfer-eye | Warm district provides a stronger destination cue; the long pale side wall remains plain |
| tipple-player | Masonry arch contrasts with dark canopy and green vessel; aperture stays clear |

The full set was opened and inspected. This is a visible functional-material
improvement, **not a claim that the user's final polish/population goal is accepted**.
Some pale broad surfaces and repetitive ribbing remain visible. No additional
geometry, camera lighting tricks, palette adjustments or ad-hoc cosmetic props were
introduced after source approval. User/manual visual acceptance remains pending.

All captures passed Off/Low/Full dressing/emission preservation and production
WeatherService binding/restoration. Weather traversal was uncapped for both variants.
Existing cooling lights and operator/team resources remain unchanged; these empty
static views do not establish live team readability.

## Performance / limits

Pinned Blender **4.5.14** and Godot **4.5.2**, one LP/OMP thread, serial owned process
groups. R6 headless warmed-cache load/instantiate measured **95.529 ms**. Initial
isolated project import included other project assets and is not a map-only cold-load
benchmark. The native import log and full command timings are retained.

| Software Compatibility backend | R5 | R6 |
|---|---:|---:|
| Static-view mean frame min / median / max, ms | 119.54 / 234.85 / 330.81 | 124.25 / 217.69 / 330.62 |
| Reported draw calls, range | 94–147 | 112–227 |
| Peak reported video memory, bytes | 66,969,327 | 74,140,225 |
| Peak reported static memory, bytes | 120,796,320 | 121,319,152 |

These eight-frame samples use **Mesa llvmpipe (LLVM 20.1.8)** and include settle
costs. They are neither dedicated-GPU FPS nor hosted gameplay cadence, and the
median difference is not evidence of a performance improvement. No full six-mode
hosted matrix or platform package export was run.

GLB exceeds the 7 MB design target by **8,012,396 bytes**. Original float32 streams
are retained alongside material-specific indices/UV accessors and lossless textures.
No detail was stripped to chase bytes or the advisory 150k triangle guideline.

## Retained failures and narrow source corrections

Two initial fresh-reopen attempts failed a rounded-decimal Counter comparison.
The diagnostic shows 74 triangles straddling a rounding boundary, not changed
geometry. Matching now retains multiplicity and checks **raw per-corner errors at
1e-5**, stricter than the former nominal 1e-4 precision. Fresh reopen then passed.

Two native-direction checks flagged inherited zero tangents. Their logs and the
full pre-classification diagnostic are retained. Final reporting separates defined
direction preservation from the seven inventoried substitutions; there is no blanket
native-tangent pass. No mesh bytes were changed to mask these failures.

The exporter now retains its actual serialized plan under
`evidence/W/finish-plan-built.json`: its dictionary key order differed from the old
source plan, but parsed contents are equal. The old source-plan bytes are preserved.
The built master's plan hash identifies the retained actual build input.

All command receipts include source hashes, exact leader PID/PGID/kernel start ticks,
timestamps and remaining-group audits. The actual Blender material-library export
is archived under `evidence/W/attempts/`. Import-sidecar inventories and owned-only
cleanup record every removed generated unrelated sidecar.

`evidence/W/release-receipt.json` records W's final three empty owned-group audits,
manager exit, lock availability and unchanged preexisting viewer/displays. S is not
reopened or restamped. R6 remains staged: a future explicit parent shipping inventory
transaction, independent review, the tangent decision and user art acceptance are
still required before promotion.
