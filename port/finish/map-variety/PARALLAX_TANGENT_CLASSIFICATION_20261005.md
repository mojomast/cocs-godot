# Parallax tangent classification and appearance-preservation contract — 2026-10-05

Source-only work for queue item **Q1** of
`port/finish/map-variety/BLOCKERS_EFFICIENCY_20261005.md` §2. Branch
`spacebunny/parallax-tangent-classifier-20261005` from `feature/relay-campaign`.

Deliverables:

- `tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis/classify_records.py`
  (+ `classification.json`, `test_classify_records.py`)
- `tools/godot-multiplayer/new-maps/parallax-tangent-provenance/appearance_contract.py`
  (+ `appearance-contract.json`, `test_appearance_contract.py`)

**No artifact, GLB, master, receipt, registry or promotion state was changed. No
Godot or Blender process was started. Nothing was pushed, merged or rebased.**
The main checkout at `/home/mojo/.tmp-on-disk/cocs-relay-campaign-20260930` was
not touched; all work is in
`/home/mojo/.tmp-on-disk/cocs-walker-snap-compare-af`.

## What the 4,729 figure actually is

`4,729` is a **raw UV-derivative census class**, not a glTF conformance count.
glTF 2.0 §3.7.2.1 constrains a supplied `TANGENT` to a normalized XYZ and a
handedness sign in `w`; it states no per-record `dot(N, T) = 0` requirement, and
mirroring legitimately produces an opposite-handed basis. MikkTSpace is the
recommendation for *generated* tangents, not a validity test for supplied ones.
The classifier therefore separates three questions the blocker had merged:

| Question | Verdict rule |
| --- | --- |
| Is the record spec-valid? | non-finite, zero/non-unit `T.xyz`, `w ∉ {−1,+1}`, non-unit `N`, or the spec's own `cross(N,T)*w` collapsing to zero |
| Does it disagree with the raw exported-V derivative? | stored `w`, `dot(T, dP/du)` or `dot(cross(N,T), dP/dv)` compared against the UV-derived frame on full-rank faces |
| Is that disagreement an appearance defect? | requires the appearance contract below, not a derivative sign |

`classify_records.py` reuses `census.py`'s GLB parsing, vector helpers and
derivative definition rather than re-deriving them, and
`reconcile_with_census()` re-runs `census.source_faces` and asserts the
classifier's thresholds still reproduce the committed inventory key for key.
Reconciliation passed for **X** and **AA** over all eleven census keys.

## Classified counts

Three artifacts, each 39 primitives / 155,553 faces / **319,065** supplied
tangent records. X is the committed source GLB; **AA is re-derived from
committed X** by `districts-v4-tangent.contract.repair` and asserted to equal the
pinned failed-AA SHA-256 `95e9da98…`, so the classification is reproducible from
committed evidence rather than from an uncommitted external worktree; AC is the
committed artifact `0903dc4f…`.

| Category | X | AA | **AC** |
| --- | ---: | ---: | ---: |
| (a) spec-invalid | 17 | 16 | **0** |
| (b) spec-valid but derivative-disagreeing | 314,180 | 314,178 | **314,178** |
| (c) unaffected / other | 4,868 | 4,871 | **4,887** |
| stricter reading, (a) ∪ (c)-with-UV-rank-only | 4,804 | 4,803 | **4,803** |

Category (a) is exactly: **16** `N ∥ T` glyph records (`degenerateFrame`) plus,
in X only, **one** zero tangent at saltstone vertex 24049
(`zeroTangent+nonUnitTangent+degenerateFrame`). AC closes all of them.

Category (c) decomposes in AC as `uvRankFailureOnly` 4,803, `zeroAreaFaceOnly`
80, `derivativeAgreeing` 4.

Face/corner states are identical across all three: faces `fullRank` 150,686,
`uvRankFailure` 4,811, `zeroAreaFace` 56; corner occurrences `fullRank` 452,058,
`uvRankFailure` 14,433, `zeroAreaFace` 168.

The raw metrics reproduce the committed census exactly — X 452,053 / 5 / 452,050
and AA 452,050 / 5 / 452,048 for `wSignDisagrees` / `storedTangentOpposesDU` /
`storedBinormalOpposesDV`. AC equals AA because the glyph repair touched only
records whose faces are UV-rank-deficient. `nonorthogonalNT` is now an
**advisory**, not a verdict: 4,745 in X and AA, **4,729** in AC.

Record-level diffs: X→AA **3**, AA→AC **16**, X→AC **19** — matching the
reviewed 5-byte / 64-byte / 69-byte BIN boundaries independently.

Per-role category counts (AC), with the reviewed normal scale carried through:

| Role | Records | (b) | (c) | Advisory | glTF normal scale |
| --- | ---: | ---: | ---: | --- | ---: |
| ochre | 121,296 | 116,464 | 4,832 | nonorthogonalNT 4,676 | 0.3 |
| paving | 95,951 | 95,951 | 0 | — | 0.45 |
| metal | 38,273 | 38,273 | 0 | — | 0.3 |
| saltstone | 35,266 | 35,263 | 3 | — | 0.4 |
| mirror | 18,799 | 18,799 | 0 | — | 0.2 |
| parallax.trim | 4,088 | 4,057 | 31 | nonorthogonalNT 32 | 0.35 |
| parallax.etch | 1,384 | 1,380 | 4 | nonorthogonalNT 4 | 0.25 |
| parallax.optics | 1,016 | 1,016 | 0 | — | 0.2 |
| parallax.instrument-alloy | 952 | 943 | 9 | nonorthogonalNT 8 | 0.3 |
| cistern | 828 | 828 | 0 | — | 0.35 |
| parallax.stone | 576 | 568 | 8 | nonorthogonalNT 9 | 0.4 |
| parallax.enamel | 576 | 576 | 0 | — | 0.35 |
| parallax.glazing | 36 | 36 | 0 | — | 0.2 |
| sea | 24 | 24 | 0 | roleWithoutNormalTexture 24 | n/a |

`sea` has no `normalTexture`, so its derivative sign is not a normal-map
appearance claim for it; the contract reports that rather than scoring it.

## What the appearance contract establishes

`appearance_contract.py` implements the provenance README's "Preferred next
scope": at corresponding decoded PNG sample locations, compare authored and
supplied-basis world-space perturbations with explicit normal strength, image
origin, UV transform and material selection. Three quantities are kept separate
and none is assumed from another:

- **image addressing** — Blender's OpenImageIO negative row stride (bottom-up
  `ImBuf`) against glTF §3.9 (top-down), paired by the pinned exporter's
  `v_exported = 1 − v_authored`;
- **basis** — `B = w · cross(N,T)` per the pinned Blender normal-map shader and
  Godot's `binormal = normalize(cross(normal, tangent) * binormal_sign)`;
- **strength** — the same reviewed scalar, reached by two *different* formulas.

Materials are selected from committed source only: role → resource → declared
strength/density from `revisions/districts-v3/variety_bindings.json`, and image
bytes from the artifact's own embedded PNG. The salt-limestone normal map decodes
to SHA-256 `203df36b…`, byte-identical to
`assets/moth/map-variety-20261003/candidate-v2/textures/salt-limestone-normal.png`
and matching the manifest and the provenance pin. No runtime
`KHR_texture_transform` is present, so the only UV transform is the exporter's v
flip over an already density-scaled `MothLocal` UV with REPEAT wrap.

Results:

| Case | Result |
| --- | --- |
| Asymmetric full-rank synthetic fixture, 12 locations, 12 columns×rows, green straddling 128 | authored and supplied sides agree at **12/12** under both strength models |
| Solitary W flip | **rejected 12/12**; binormal reverses exactly **180.0°** |
| Solitary green flip | **rejected 12/12**; green contribution reverses exactly **180.0°** |
| Wrong image origin | **rejected 12/12** |
| Exhaustive address proof, every spec-valid corner on a full-rank face | **452,022 / 452,022** identical bilinear REPEAT samples across all 13 textured roles, **0** mismatches |
| Nearest-neighbour tie corners (reported, not hidden) | **1,851** of 452,022, exactly the UVs that land on a pixel edge where either answer is a tie-break; the declared LINEAR filter has no such tie |
| Per-role decoded sweep with worked examples | **36,156** locations, **13/13** textured roles pass, 0 texel-boundary hits, green genuinely non-neutral |
| Basis preservation X→AC | **19** records changed (saltstone 3, ochre 16); **319,046** byte-identical |

The exhaustive result is the load-bearing one: for every spec-valid corner on a
full-rank face, the exporter's v flip and Blender's bottom-up buffer select the
same 2×2 neighbourhood with the same weights under the filter both pinned
samplers declare, so the **sample location is identical everywhere**. Combined
with byte-identical basis records, world-space perturbation is *identity* for the
319,046 unchanged records — not a derivation from a derivative sign.

## What the contract answers about the reviewed edits

**The provenance report's open question is answered, and the answer is negative
for the saltstone edit.** Saltstone face 11823, `N=(0,1,0)`, real UVs, real
decoded salt-limestone samples, reviewed scale 0.4:

| Corner | Vertex | X basis | AA/AC basis | X→AA world-normal angle | Binormal / green angle |
| ---: | ---: | --- | --- | ---: | ---: |
| 0 | 24049 | `(0,0,0,+1)` | `(+1,0,0,−1)` | not comparable — X's zero tangent has no frame | — |
| 1 | 24050 | `(+1,0,0,+1)` | `(+1,0,0,−1)` | 4.898° (Blender) / 4.906° (Godot) | 180.0° |
| 2 | 24051 | `(+1,0,0,+1)` | `(+1,0,0,−1)` | 5.585° (Blender) / 5.585° (Godot) | 180.0° |

All three corners address the identical texel (`sameTexelEveryCorner: true`), so
the difference is the **basis**, not the image. `XvsAAgreenReversed` is **2 of
2 comparable corners**; `XAAPreserved` is **0 of 3**. The AA/AC sign change
matches the approved derivative-basis policy, but it does **not** preserve X's
authored appearance on those two corners, and on corner 0 it creates a frame
where X had none. This is the state of affairs
`PARALLAX_GLYPH_POLICY_REVIEW.md` already flagged as unresolved; it is now
quantified rather than left open, and it is **not** fixed by this work.

**The five U-reversed corners cannot be qualified source-only.** All five sit on
triangles whose narrowest UV edge is `5.96e-5` float32 ULPs — i.e. below float32
resolution — so `dP/du` reaches `4.7e12` and the derived `w` is a quotient of
cancellation noise, not a shading intent. Their stored bases are spec-valid and
sampleable at their real UVs (5/5 comparable). `unconditionalAppearsPreserved`
is **0/5**, deliberately: the contract reports the conditioning and declines to
convert a numerically meaningless derivative sign into an appearance verdict.
Their intended tangent direction remains unproven and needs an authored-intent
input or a render, not a sign flip.

**The sixteen singular glyph records changed appearance, necessarily.** Before
the AC repair all sixteen frames are degenerate: `cross(N,T)` is exactly zero, so
`B = 0` and the green channel contributes nothing at all. After, all sixteen are
unit, orthogonal and `w = −1`. `appearanceIdentical` is **0/16** because a
degenerate frame has no comparable world-space green contribution — the repair
makes the frame sampleable, which is a real shading change relative to the
singular input. This is the intended, reviewed effect of AC, and it is the
change that closed the only spec-invalid records.

**A shader-level divergence is quantified and is not a tangent defect.** The
same scalar reaches Blender as an `xy` scale with `z` mixed toward 1, and reaches
Godot as `normal_scale` → `NORMAL_MAP_DEPTH`, a `mix` depth applied after `z` is
rebuilt from `xy` and the stored blue is ignored. The two pinned expressions
differ by up to **15.06°** at the reviewed strengths, and they coincide only when
a texel's stored `z` already equals the reconstruction. That divergence is
identical in X, AA and AC, because the scalar is unchanged, so no reviewed edit
introduced it.

## What remains unproven

- Whether the saltstone face 11823 reversal is acceptable final art. It is
  measured, not blessed. A controlled render and manual material acceptance are
  still required, and a reviewer may reasonably conclude the three-corner sign
  should be reverted.
- The intended tangent direction for the five U-reversed corners.
- Which strength convention the accepted appearance refers to.
- MikkTSpace behaviour at smoothing seams and the native importer's world
  transforms. The contract is per record basis, mesh-local.
- Mip selection, anisotropic filtering, texture compression and sRGB handling of
  albedo — out of scope; normal maps are bound Non-Color and decoded as bytes.
- Blender's own authored UVs. The authored side is reconstructed as the inverse
  of the pinned exporter transform; Blender was not run to confirm it.

## Qualification statement a reviewer could adopt

The numbers support the following, verbatim:

> Parallax AC `0903dc4f…` has **0 spec-invalid supplied tangent records** of
> 319,065 under glTF 2.0 §3.7.2.1 (`T.xyz` normalized, `w ∈ {−1,+1}`, unit
> `N`, non-degenerate `cross(N,T)*w`); the 17 in X and 16 in AA were the 16
> singular `N ∥ T` glyph records plus X's single zero tangent, all closed by AC.
> The remaining **4,729** nonorthogonal entries and **314,178**
> spec-valid-but-derivative-disagreeing records are a raw exported-V derivative
> metric, qualified here by identity rather than by sign: **319,046 of 319,065**
> records keep their exact X tangent bytes, and at **452,022 of 452,022**
> spec-valid full-rank corners the exporter's v flip and Blender's bottom-up
> image addressing select the identical bilinear REPEAT sample, so world-space
> perturbation is unchanged. The **19** changed records are argued case by case:
> 3 saltstone corners whose `w` reversal **does not** preserve X appearance
> (green reversed 180°, world normal 4.90°/5.59°) and 16 glyph records whose
> degenerate frames had no green contribution at all and are now sampleable.
> **0 wholesale W flips and 0 green flips are authorized by this evidence.**
> The five U-reversed corners are spec-valid, sit on sub-float32 UV edges, and
> are **not** qualified here.
>
> This is a source-only qualification. It is not artifact approval, not
> authored-X appearance acceptance for the saltstone edit, not a render
> measurement, and not a promotion.

## Scope statement

- **No artifact change.** No GLB, master, texture, receipt, registry or
  promotion state was written or modified. `git status` shows six new files and
  no modifications to existing files.
- **No native or render proof.** No Godot, Blender, importer or renderer was
  executed. Everything here is static source arithmetic over the two pinned
  shader expressions and the committed bytes. It is not renderer equivalence.
- **No promotion or acceptance.** Nothing is promoted, catalogued or accepted.
  The withdrawn shading-defect inference of `8c43b112` is not revived; the
  near-global raw derivative disagreement is a measurement, not a defect.
- **Pinned bytes used.** All were present and hash-verified: X
  `6356cf89…`, AA `95e9da98…` (re-derived from committed X and hash-matched),
  AC `0903dc4f…`, salt-limestone normal `203df36b…` (embedded bytes, byte-
  identical to the committed Moth pack PNG). A missing source is reported by the
  code and its test, never fabricated — `test_missing_pinned_source_is_reported_not_fabricated`
  pins that behaviour by pointing the AC path at a nonexistent file and
  asserting the report blocks instead of inventing data.
- **Uncommitted external state.** The classifier records whether the frozen AA
  worktree copy at `/home/mojo/.tmp-on-disk/cocs-parallax-tangent-native-AA-20261003`
  is present and byte-equal to its own derivation. It is not required: AA is
  reproduced from committed X.

## Reproduction

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis/classify_records.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/godot-multiplayer/new-maps/parallax-tangent-provenance/appearance_contract.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/botanical-parallax-aa-diagnosis -p 'test_*.py' -v
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tools/godot-multiplayer/new-maps/parallax-tangent-provenance -p 'test_*.py' -v
```

## Tests

- `test_classify_records.py` — **29 tests**. Every category from a synthetic GLB
  built in memory: agreeing, **mirrored-UV spec-valid**, nonorthogonal-but-valid,
  non-unit `T`, `w ∉ {−1,+1}`, non-unit `N`, zero tangent, UV-rank failure,
  zero-area face, untextured role, plus the **known sixteen-singular-glyph
  shape** (16 records, `N=−X`, `T=+X`, `w=−1`, all `degenerateFrame`, all on
  rank-deficient faces) and the stricter-reading count. Also pins the census
  reconciliation and that a deliberately drifted census count is **rejected**
  rather than silently reclassified, determinism of repeated runs, bounded
  samples, the node-name collision guard, and the record-diff inventory guard.
  Six further tests run the real pinned X/AA/AC artifacts so every number in this
  document is asserted, not transcribed: the 17/16/0 spec-invalid counts, the
  census metrics, `nonorthogonalNT = 4,729` as an advisory only, the 3/16/19
  record diffs, the reviewed face-11823 and sixteen-record identities, and the
  per-role totals summing to 319,065.
- `test_appearance_contract.py` — **39 tests**. PNG decode round-trip across all
  five filter methods; the addressing pair and its three negative controls;
  bilinear REPEAT commuting with the v flip including at texel centres and pixel
  edges; hand-computed values for both pinned strength expressions; degenerate
  frames; real-source cases for saltstone 11823, the five U-reversed corners, the
  sixteen glyph records, every textured role, the exhaustive sweep and basis
  preservation; committed-source checks including that no runtime UV-transform
  extension exists; and the report's own scope, boundary and verdict blocks.
- Existing `test_provenance.py` (**1**) and `test_diagnosis.py` (**6**) still pass
  unchanged.

**35 passed** in `botanical-parallax-aa-diagnosis` (78.690 s), **40 passed** in
`parallax-tangent-provenance` (32.599 s). Zero failures, zero errors, zero
skips.