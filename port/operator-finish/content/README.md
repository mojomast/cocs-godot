# Nine authored operator finishes — source-only delivery

## Delivery and API

All nine Profile v1 JSONs live in `godot/source_operators/moth_finish/profiles/`.
`godot/source_operators/moth_finish/manifest.json` publishes 63 finish IDs, 116
unique 256×256 PNG maps (~1.08 MB compressed), and full derivation provenance.
Each identity has shell, trim, rubber, precision, panel, board and vent finishes.
Trim/rubber/precision pixels are shared across identities; the nine shell layouts
and 27 overlay layouts are individually authored. No character hue is baked in.

Each profile binds four verified material names and declares all six remaining
unique names preserved. Duplicate `sourceTeamIvory` glTF materials are intentionally
covered by one name-level preservation rule. Every emitted finish uses the exact
contract map/scalar fields and `albedo_mode: "modulate"`. `textures` is a top-level
manifest audit table, not an additional runtime finish option: runtime readers
consume `finishes`, ignore `textures`, and may expose provenance for diagnostics.
No extra profile or finish-level fields need special handling.

**Runtime handoff:** resolve by original `resource_name`, before applying local
overrides. Keep vertex color multiplication for precision assemblies. Roughness
is an L8 texture: sample **R**, use `roughness_gain=1`; the PNG already supplies
the perceptual roughness value. Normal PNG is linear RGB8 tangent-space data.
Albedo is opaque neutral RGB8 sRGB modulation. Overlay border sample `(0.015,
0.015)` remains near bare paint, matching the existing side/bevel UV rule.
No emission, transparency, UV transform, weapon finish or team marker replacement
is requested by these profiles. Team armor remains explicitly bound, with neutral
modulation so the binder can preserve its declared team tint independently.

## Art decisions grounded in existing models

Primary references: `game/operator-anatomy.mjs` design declarations and actual
GLB geometry; `game/operator-detail.mjs` service architecture; `game/data.mjs`
palette; current native armor overlays. The finish stories below are **art
interpretations of those existing model designs**, not new canonical lore.

| Identity | Existing design | Authored layout and finish |
|---|---|---|
| ChatGPT | Split-cage survey instrument | Split service rails, interrupted upper cage, calibration ticks; restrained ceramic shell, passive instrument bus |
| Claude | Ceramic warding chassis | Broad shield enamel, inset chevron and inspection bar; protected center, small outer-corner chips |
| Grok | Asymmetric industrial outrider | Offset repair bay, stepped panel perimeter and service direction arrow; brushed metal retaining its dark armor palette |
| Meta | Twin-turbine heavy chassis | Thick bolted rectangular bays, paired load rails, heavier roughness and selected impact corners |
| Gemini | Bifurcated ceramic anatomy | Two petal lobes, separate circular service sockets and central split; enamel with restrained seam relief |
| DeepSeek | Pressure-vessel salvage frame | Pressure collar, drain recess and repair inspection stripe; mechanically worn alloy with recessed grime |
| Mistral | Swept aerofoil interceptor | Swept polygon, diagonal leading-edge wear and grain, lighter brushed roughness; no heavy bolted bay |
| Kimi | Orbital gimbal reactor | Concentric service collars, sparse radial ticks and ring-compatible quiet center; ceramic around mechanical interfaces |
| Qwen | Lamellar mechanical sentinel | Three keyed overlapping courses, off-center maintenance tabs; layered alloy with course-edge wear |

All maps have sparse macro seams and marks rather than random all-over noise.
Wear is localized to selected panel corners: polished scuff plus a displaced
undercoat chip; broad grime follows the recessed seam masks. Manufacturing marks
are geometric service/inspection symbols, not unreadable microtext or fictional
manufacturer names. Boards carry three passive service buses and identity-specific
face architecture; vents vary slot count, body boundary and Mistral's slot slope.
Rubber has high roughness and subdued baked carbon microstructure; precision
assemblies stay quiet because their recesses, metal, rubber and bolts already have
actual geometry and vertex colors. A scalar material cannot correctly remetalize
individual precision vertex colors, so their existing metallic 0.62 is retained.

## Material and UV inspection

`coverage.json` records the actual GLB SHA-256, catalog team material, full original
material records, material indices, node names and ancestry, and **all 1,014**
primitives. For every primitive it records actual UV1 availability/ranges,
geometry bounds, signed UV triangle counts, degenerate counts, positional seam
duplicates and eight-bin UV-edge rotation histograms. These inspect real indexed
accessor bytes rather than trusting glTF min/max metadata.

All 1,014 primitives have UV1 (`TEXCOORD_0`), bounded to 0..1 within floating-point
epsilon. 162 precision primitives carry `COLOR_0`. All carry normals; none exports
`TANGENT`. Native import tangent generation and moving-light normal orientation
therefore remain explicit integration checks. `uv-geometry-2d.png` juxtaposes real
UV triangle wireframes with local XY geometry projections for a representative
bound primitive of each role on all nine models. This is source geometry evidence,
not an engine rendering or global atlas packing claim.

The matte hand/rubber primitives specifically use U=0.455..0.545 and
V=0.45..0.55, with 192 UV-degenerate triangles in each higher-detail hand batch
and 64 in the lower-detail batch. Their normal map is **omitted** (strength 0),
while the albedo/roughness remain quiet near the sampled center. This is not a
claim that merely having a UV accessor makes every triangle suitable for normals.

These UVs are overlapping **per-primitive local UV domains**, not an exclusive
whole-actor atlas. Contour seams, plate face UVs, tube/cable directions and mirrored
triangles coexist in joined batches. A source material alone cannot uniquely label
the chest without also labeling a limb. Consequently source shell identity layouts
are low-contrast, seam-safe treatments without labels, and source metal/rubber/
precision maps are restrained. The stronger panel/board/vent masks target the
existing overlay helper's proven front-face UV square. Native inspection must
still approve attachment/readability of every representative source role.

| Identity | Team armor name | Bound source primitives / total |
|---|---|---:|
| ChatGPT | sourceMaterial5 | 59 / 111 |
| Claude | sourceMaterial4 | 61 / 117 |
| Grok | sourceMaterial5 | 59 / 110 |
| Meta | sourceMaterial4 | 59 / 117 |
| Gemini | sourceMaterial5 | 60 / 110 |
| DeepSeek | sourceMaterial4 | 60 / 116 |
| Mistral | sourceMaterial5 | 60 / 109 |
| Kimi | sourceMaterial5 | 59 / 111 |
| Qwen | sourceMaterial5 | 61 / 113 |

Total: **538 bound primitives; 476 intentionally preserved primitives**. The
preserved materials include `sourceTeamIvory`, all existing emission, the dark
`sourceMaterial2` shared with the visor lens, and weapon-only/shared materials.
There are no unclassified real source material names. Four bindings cover team
armor, colored body trim, matte hand/rubber material and vertex-colored precision
assemblies. Numbered roles are selected from the individual actual material and
catalog, never a blanket `sourceMaterial0=armor` assumption.

## Provenance and deterministic rebuild

Real baked Moth input keys: `textures/brushed_metal`, `textures/carbon_fiber`,
`textures/circuit_board-etch`, `textures/hex_paneling`, `textures/metal_grating`,
`textures/riveted_armor`. Each input PNG's encoded SHA, decoded RGBA SHA, dimensions
and registry color-space metadata are recorded and checked against the existing
Moth manifest. The original `game/moth-baked.mjs`, both catalog manifests, nine
frozen GLBs, authoring generator and art reference source files are hashed.

`tools/operator-finish/content/build.py:masks` contains the authored UV layouts;
`pixels` composes one bilinearly enlarged real Moth sample with the seam, wear and
mark masks. Baked luminance is centered and strongly attenuated in albedo, so the
Moth source is actually sampled while the macro design dominates. Mistral's shell
and panel brushing is rotated to match the swept design. Source pixels remain
unaltered. Each output's encoded/pixel hashes, dimensions, channels, color-space,
data meaning, source keys and recipe inputs are in the manifest.

Normals are **authored-height-derived**, not direct Moth normal-map copies:
height = centered baked luminance relief + authored recessed seams/chips/marks.
The implementation computes `normalize(-2*dH/dU, -2*dH/dV, 1)` before RGB8
quantization. +V follows PNG rows and glTF fitted UV V; these are +Y tangent maps,
not DirectX -Y maps. Decoded quantized vectors are checked within 0.012 of unit
length. Runtime strength is restrained (0.32–0.55). This mathematical convention
does not claim native lighting certification.

```sh
python3 -m venv /tmp/opencode/operator-content-venv
/tmp/opencode/operator-content-venv/bin/pip install -r tools/operator-finish/content/requirements.txt
/tmp/opencode/operator-content-venv/bin/python tools/operator-finish/content/build.py
/tmp/opencode/operator-content-venv/bin/python tools/operator-finish/content/validate.py
/tmp/opencode/operator-content-venv/bin/python tools/operator-finish/content/build.py --check
```

`--check` rebuilds into a separate temporary directory and compares **all** generated
JSON and PNG bytes (including the evidence sheets), while verifying frozen GLB and
real Moth hashes. `validate.py` checks actual coverage/protected materials, resource
resolution and hash/pixel agreement, neutral luminance and bevel samples, roughness
variation, normal vectors, unique untinted patterns and the bounded map budget.
`validation.json` captures its source-only result.

## Reviewed 2D evidence and pending native work

`review-2d.png` shows all nine original flat source armor palette samples alongside
new shell/panel/board/vent modulation samples, panel normals and panel roughness.
The palette multiplication is deliberately a flat 2D study, not simulated engine
shading or a native before/after claim. Both evidence sheets have been inspected
as images. Their interpretation: distinct architecture is visible at macro scale,
palettes remain recognizable, Meta's heavy bay and Mistral's swept treatment differ,
and Grok deliberately remains the darker silhouette rather than becoming recolored.

**Native pending, integration owner Astra:** use the exclusive
`FINISH-COMBINED-NATIVE-20261002-A` grant for before/after nine-operator galleries
and closeups; moving-light normal/tangent orientation; Meta/Mistral first fighting
slice then all nine; rest/locomotion/pair animations to verify fitted attachment;
LOD 0/1/2 switches; simultaneous opposite teams; same-operator team changes;
identity switches; repeated configure/rebind/free; visor/emission/alpha/weapon
comparisons; texture/cache bound measurements. Human-view roughness/wear and source
UV repeat readability must be approved there. Source checks and 2D sheets do not
certify those native outcomes. This lane ran no engine, import, Blender, render,
audio or encoding tasks.
