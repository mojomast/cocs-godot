# Parallax AA static tangent diagnosis — separate, unapproved remedy proposal

Base `1120a016`; branch `astra/parallax-aa-diagnosis`. Reads frozen producer
`b9c53e82` in `cocs-parallax-tangent-native-AA-20261003`. **No engine, import,
render, server, child agent, new GLB/master or native proof was produced.**
No AA/X/R7/Vesper history is edited. The original three-corner contract is not
expanded by this diagnostic commit.

## Measured full-face result

The actual AA artifact is
`95e9da98a45565ca2aae90858a9e5027d9123e4ffd1347da98d5de8573141cd5`.
AA03 and AA04 native JSON and stream files are **byte-identical**, not merely
equivalent summaries; exact hashes are in `summary.json`.

| Metric, each frozen readback | Count |
|---|---:|
| Oriented incident faces matched by node/material/position/UV | 155,553 |
| Strict normal/UV/tangent/handedness-equivalent faces | 155,521 |
| Handedness-mismatched faces | 32 |
| Mismatched used corner occurrences | 48 |
| Distinct affected accessor/vertex records | 16 |
| Position / normal / UV / tangent-direction mismatches | 0 / 0 / 0 / 0 |
| Duplicate geometry groups handled as multisets | 228 |
| Missing geometry groups / unresolved basis ambiguity | 0 / 0 |

All mismatches are **source `w=-1` → native `w=+1`**, on `wayfinding-2` and
`wayfinding-3` (16 faces / 24 corner occurrences / 8 unique vertices each).
Source positions and UVs match exactly. Strictly matching faces have maximum
normal error `0.00010138750076293945` and tangent error `0.0001799166202545166`.
The mismatched corners have the same near-+X direction, within the unchanged
`0.0002` component tolerance; the sign component differs by 2.

The producer's original AA_REVIEW first-error description is incorrect and is
left intact. Actual native `wayfinding-2` face 963 maps to source face 965:
canonical-order native signs **`[+1,-1,-1]`**, source **`[-1,-1,-1]`**.
That is **one bad corner**, consistent with the independent reviewer correction.
Source vertices 1026/1027 are not exchanged with identical local geometry on
`wayfinding-3`.

### Complete pinned entry set

TANGENT accessor **165** (`wayfinding-2`, node/mesh 33) and **170**
(`wayfinding-3`, node/mesh 34), each at vertices:

`1026, 1027, 1038, 1039, 1050, 1051, 1062, 1063`.

Each occurs in three incident faces. Affected source faces, on each node:
`964–967, 976–979, 988–991, 1000–1003`.
`AA03-census.json` and `AA04-census.json` retain every source node/mesh/primitive/
face/accessor/corner/vertex and native surface/face/corner/vertex mapping, vectors,
area/Jacobian and comparison classification.

## Root cause: singular source frame, deterministic importer sign reconstruction

**High confidence for all 48 observed mismatches.** Every affected source entry
has **N = ±X, T.xyz = +X, w = -1**. Thus `cross(N,T) = 0`: these are unit-length
tangent vectors that are not tangent to their normals. The source binormal is
exactly zero, so there is no physically meaningful source binormal direction to
preserve. A zero-vector or tangent-length-only census misses this defect.

The associated triangles have nonzero areas
`0.0003989585160965766–0.0005361038048996075 m²`, but **zero UV Jacobian**.
These are small extruded glyph-side surfaces with collapsed UVs. Their material
is **ochre, with a normal texture present**. They are not zero-area triangles and
are not the repaired saltstone triangle. Small extent is a scope observation,
not a basis waiver or visual-acceptance claim.

Pinned Godot `4.5.2-stable` source explains the exact result:

1. `modules/gltf/gltf_document.cpp:3611–3622` always creates/indexes a
   `SurfaceTool` and commits its arrays. `ensure_tangents=false` does not bypass
   this supplied-tangent path.
2. `scene/resources/surface_tool.cpp:886` reconstructs
   `binormal = normal.cross(tangent).normalized() * d`.
3. `surface_tool.cpp:487–488` reconstructs `w` with
   `binormal.dot(normal.cross(tangent)) < 0 ? -1 : +1`.
   For the singular frame, the dot product is zero and the result is **+1**.
4. Even without attribute compression, `rendering_server.cpp:627–653` uses
   16-bit octahedral tangent storage. That explains the observed tiny -Z
   component; it is not the cause of this sign change. The native cross product
   remains tiny (at most `3.051804378628731e-5` here), not an equivalent valid frame.

`godot-source/` contains line-numbered excerpts, pinned source URLs and full-file
SHA-256 hashes. `simulate_surface_sign()` reproduces the sign reconstruction
from the actual source vectors; tests cover the corrected first failure and
every proposed entry. This is source-code/math corroboration, not a new engine run.

All source leaf scale determinants are +1. The affected leaf rotations are proper
rotations, not reflections. Native node transforms were **not recorded**, so no
new native world-transform claim is made. Node transforms are also unnecessary
to explain a mismatch already present in the recorded mesh-local arrays.

### Verifier diagnosis

The strict verifier is right to reject AA. Its material/local-position lookup
pools identical geometry across wayfinding nodes, making source-choice reporting
ambiguous. This census keys node identity as well as material and exact oriented
position/UV. Godot's dot-to-underscore node-name sanitization is explicit and
checked for collisions. Tangents never select the geometry correspondence.

Within duplicate geometry groups, an augmenting-path bipartite multiset comparison
checks a full attribute bijection and exact multiplicity. It does not greedily
pick a convenient sign. If different source basis classes prevent per-corner
attribution, the entire source/native multiset is reported unresolved. None of the
actual mismatches has that ambiguity. Wrong-handedness and duplicate-count tests
still reject. A node-scoped verifier improvement alone **does not make AA pass**.

## Additional source census limits

X has one zero/nonunit tangent; AA has **zero zero/nonunit tangents**. X has 17
parallel-normal/tangent entries including that zero; AA retains the 16 above.
Both have 4,745 entries with `abs(dot(N,T)) > 0.001` and no normals outside the
`0.001` unit-length tolerance. Detailed records are in `source-census.json`.

The raw conventional glTF UV derivative audit also exposes a much broader
inherited issue: on AA's 150,686 full-rank/nonzero-area faces, 452,050 corner `w`
values disagree with the sign derived using `dP/du`, and 452,048 stored binormals
oppose increasing `dP/dv`. Five stored tangent directions oppose `dP/du`.
These are **separate raw mathematical observations**, not additional native
source/readback mismatches or an authorized global repair set. Normal-map green
channel provenance, exporter conventions and smoothing need separate review
before deciding their shading consequence. This bounded task does not silently
flip hundreds of thousands of corners or claim all inherited source bases valid.

## Recommended separately reviewed remedy

For the **specific strict-native blocker**, review an explicit 16-entry
**rank-one UV fallback policy** in addition to the already-approved saltstone
three-corner repair. `proposal.py` demonstrates it only in memory:

- Use each actual incident triangle's nonzero geometric edge with **zero UV
  change** as the glyph-extrusion axis. That is ±Y for these entries.
- Retain `w=-1`; orient T so `B=cross(N,T)*w` agrees with the observable increasing
  V direction. Result: **T=+Y for N=-X, T=-Y for N=+X**.
- Require all three incident faces to agree, unit/orthogonal N/T and positive V
  alignment. Reject a full-rank UV map, zero area, absent/conflicting extrusion,
  unknown entries or changed source identity. No arbitrary first-face choice.
- Preserve positions, normals, UVs, indices, material/normal-map payloads, scene
  and all other BIN bytes. No vertex split is needed for the pinned set.

This is **not a unique UV-derivative/Mikk solution**: the UV Jacobian is singular,
so dP/du cannot be recovered uniquely. It is a new, explicit geometric fallback
shading policy requiring approval. The in-memory experiment changes **64 BIN
bytes within 256 allowed positions** (16 × 16-byte records), starting from AA.
It preserves the existing three saltstone corrections. `proposal.json` records
the all-incident mapping; actual successor identity/grant remain null and
autostart false. No hypothetical GLB or master is written.

The mathematical SurfaceTool model predicts the repaired nonzero frames retain
`w=-1`. **The old native readback correctly fails against this proposal** on all
48 occurrences (direction and sign), so this does not manufacture a native pass.
Source-to-native equality elsewhere is preserved; full physical validity of all
other inherited bases is not established by that equality.

Alternatives requiring broader scope: regenerate/unfold degenerate glyph UVs and
their tangents (changes UV/material sampling), or perform a separately reviewed
whole-source basis/normal-map convention correction. A sign-only edit to match
Godot +1 leaves `N || T` invalid and is not recommended. There is no evidence here
requiring an engine-level runtime mesh rewrite for valid input frames.

### Before any future production grant

Approve the additional exact entry set and rank-one policy; keep AA's original
3-record contract and 141-file archive immutable. Prepare a new successor
namespace/identity and packed-master deterministic recipe. Then, under a new
explicit grant, require fresh build/reopen audits, all-face node-scoped native
direction/handedness proof without waivers, actual material readback, targeted
glyph-side imagery and the previously blocked staged lifecycle/captures. Record
native transforms if world-space parity is to be claimed. Review the broader
source-basis observations separately before claiming release polish.

## Reproduction and tests

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis/census.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis/proposal.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis -p 'test_*.py' -v
```

Tests use frozen real GLB/readback vectors, exact first-failure mapping, duplicate
multisets, wrong-w rejection, all-incident consistency, hypothetical BIN bounds,
and rejection of old native data against the proposed repair. No engine imports.
`validation.json` records tests and preservation of all 141 AA manifest files.
