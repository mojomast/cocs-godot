# Parallax singular-glyph policy — source approved, production contract pending

## Convention-report correction — integration withheld

**Corrective delivery `8c43b112` is under focused re-review.** The revised report
describes raw exported-UV derivative disagreement, adds Blender image-row/basis
semantics, and retains AA's authored-appearance uncertainty. Its source-only
asymmetric image regression reports passing; new source hashes and the command
are recorded in `provenance-sources.json`. Original `4fe3df4e` remains historical.
No engine execution or artifact change occurred, and neither provenance commit
is integrated yet.

Independent review of `4fe3df4e` rejects its inference that the UV-V flip with
retained handedness establishes a high-confidence shading-convention defect.
The exporter/pixel facts and sampled derivative arithmetic are supported, but
the complete image/basis conversion can preserve the authored perturbation.

Blender's OpenImageIO reader uses a negative destination row stride; its normal-map
shader applies positive green along `w * cross(N,T)`. Exporting `1-v` to glTF's
upper-left texture origin can select the same unchanged PNG location while
retaining that supplied binormal in Godot. No green inversion follows merely from
changing the texture-address V coordinate. Moth's OpenGL +Y / rows-down, UV-up
declaration is compatible with this path.

For a Blender plane P(u,v)=(u,v,0), N=+Z, T=+X and w=+1, exported v'=1-v yields
dP/dv'=−Y while supplied B stays +Y. The raw derivative test flags disagreement,
yet corresponding positive-green samples perturb toward +Y in both pipelines.
Flipping only w would reverse that perturbation. This defeats the report's broad
defect inference without proving every actual source basis valid.

Sol is correcting the report and preparing a source-only asymmetric-sample contract
test before re-review. Unchanged PNG pixels prove absence of a channel rewrite,
not an incorrect basis. AA's three saltstone corners match the selected derivative-
basis policy; that alone is **not proof of authored appearance preservation**.
The singular N/T glyph policy remains separately approved. Nonorthogonal, reversed-U
and native-conversion findings remain distinct. No global W/green flip is authorized.

**Convention investigation delivery:** `4fe3df4e` is under separate independent
source review. It traces Blender's exported V flip, retained loop handedness,
OpenGL +Y pack declaration, unchanged saltstone normal pixels and Godot shader
binormal use. The report proposes a convention-mismatch explanation for the broad
raw derivative disagreement. This is not yet an independently accepted diagnosis
of rendered shading, and neither a global sign nor texture flip is authorized.

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved census/root-cause
`8f166beb` and its bounded sixteen-entry geometric fallback as **source policy**.
Parent integrated it as **`1c661b95`**, reproduced six source tests and strict
committed-Git shipping closure, and verified all 141 frozen AA files unchanged.
AA artifact approval remains withheld; no new native acceptance or grant follows.

## Independently supported census and importer mechanism

AA03/AA04 native JSON and streams are byte-identical. Node/material/oriented
position/UV correspondence covers all 155,553 faces: 155,521 equivalent, 32 with
handedness mismatch, 48 affected corner occurrences, sixteen distinct entries.
No missing geometry or unresolved basis groups. Duplicate multisets preserve
multiplicity rather than choosing convenient handedness. First mismatch remains
native `[+1,-1,-1]` versus canonical `[-1,-1,-1]`.

The reviewer independently fetched pinned Godot 4.5.2 files and verified all four
full-file hashes. The actual supplied-tangent path passes through SurfaceTool
array construction, indexing and commit. Reconstructing binormal from cross(N,T)
and then handedness from its dot product yields +1 for these parallel N/T vectors,
regardless of `ensure_tangents`. Octahedral encoding explains the small direction
perturbation, not the sign change. Proper source leaf rotations do not explain
away this already mesh-local discrepancy.

## Exact approved fallback policy

Accessors **165 and 170**, each at vertices **1026, 1027, 1038, 1039, 1050,
1051, 1062, 1063**. Across all 48 incidents:

- Geometry area is nonzero, UV Jacobian is zero.
- The constant-UV geometric edge supplies the extrusion axis.
- Unit/orthogonal tangent is +Y for N=−X, −Y for N=+X.
- Retain w=−1 so binormal aligns with observable increasing V (dot about 2.0).
- All three incident faces agree; stored/geometric normal dots are 0.98886–0.99432.

The in-memory proposal changes 64 BIN bytes within 256 permitted positions,
preserving every other byte and AA's original saltstone repair. Changed inputs
reject; old AA readback correctly fails against the proposal on all 48 occurrences.
This is an **explicit geometric fallback for rank-one UVs**, not a unique UV-
derivative/MikkTSpace result. No sign-only imitation of Godot or global regeneration
is approved.

## Broader limitations remain unresolved

Independent census confirms 4,745 used nonorthogonal entries across 4,809 nonzero-
area faces, all on normal-textured materials:

| Material | Entries | Incident faces |
|---|---:|---:|
| ochre | 4,692 | 4,752 |
| parallax.trim | 32 | 34 |
| parallax.stone | 9 | 10 |
| parallax.instrument-alloy | 8 | 8 |
| parallax.etch | 4 | 5 |

Face areas range from 5.759e-6 to 2.254 m²; 289 entries have abs(dot(N,T)) > .999.
Exactly sixteen are fully parallel, all w=−1; there is no hidden fully parallel
w=+1 set. This repair leaves **4,729 nonorthogonal entries**.

On 150,686 full-rank/nonzero-area faces, raw conventional derivatives show 452,050
handedness disagreements, 452,048 stored binormals opposing increasing V and five
tangents opposing increasing U. Their complete rendered consequences require
normal-map channel/exporter/smoothing review. Sol is investigating those conventions
separately. A future all-face source/native equality pass proves **faithful import,
not universal source-basis validity or final-art correction**.

## Next source contract

Astra `ses_efd30e1f6ffeLbhHTPoh266kZW` is preparing a new, separate successor
contract pinned to AA and these exact sixteen entries. It must preserve the
three-record compiler/archive, persist the expanded recipe in a new master,
repeat editable geometry/material audits on fresh reopen, enforce exact out-of-
scope preservation and require fresh complete node-scoped native basis proof
without waivers, material readback and staged lifecycle/captures. Broader basis
findings remain acceptance limitations. Contract review and a new explicit grant
are required before production. All current work is source/static only.
