# Foundry R6 — qualified staged source/artifact approval

## Current R7 disposition — source approved/integrated; Y production authorized

Focused independent re-review closed the material-equivalence P1 in `19daef32`.
Both real-R6 mutations reject, as do alpha/double-sided changes and unsupported
material/texture extensions. Equivalent remapped bindings pass; repeat defaults
are canonicalized without inventing unspecified filter defaults. Sixteen source
tests pass. Native recorded fields use sRGB color tolerance 5.1e-5 for four-decimal
strings (measured maximum 4.684997e-5), float32 scalar tolerance 1e-6, and exact
emission-enabled/roughness-channel checks. Unrecorded native sampler/alpha/occlusion
semantics remain explicitly outside that native-field claim.

Parent integrated both source commits as `8dbe9eb8` / **`10d9938f`**, reproducing
sixteen tests and strict shipping closure. Original R7 reports remain historical.
After verifying X's clean release, parent authorized **MOTH-BLENDER-20261003-Y**
for actual R7 production by Astra `ses_efd30e1f6ffeLbhHTPoh266kZW`. New actual
master/art identity, reopen and native proof remain pending; prior R6 native data
is not R7 acceptance. Earlier review states below record the corrective history.

## R7 source review follow-up — material gate correction required

**Corrective delivery `19daef32` is under focused independent re-review.** The
producer reports sixteen tests passing, including both real-R6 mutations below,
positive equivalence under remapped image/texture/sampler indices and negative
native material-field mutations. New `corrective-validation.json` records the
follow-up; original R7 reports and all 226 W hashes remain unchanged. Queue grant
and actual artifact hash remain null with autostart disabled. No source approval
or native acceptance is inferred from the producer report alone.

Independent review of `9fb0172e` supports its seven-entry tangent repair but
withholds full source approval for the editable-master equivalence gate.
`revision7/production.py:18–25,48–60` accepts both actual-R6 mutations:

1. Change `R6 / ground` base-color sampler to clamp-to-edge (`wrapS=wrapT=33071`).
2. Add `emissiveTexture: {index: 0}` to `GM / orange`.

Both incorrectly return zero geometry errors and `allMaterialPixelsAndPBRMatch`
true. Canonical output is then generated from frozen R6, discarding the editable
changes. Correction must compare effective sampler wrap/filter and texCoord state,
emissive texture bindings/pixels, and reject unsupported semantics. Existing
texture-transform rejection stays intact. Native proof must also compare recorded
material scalar/emission fields, not merely pixels. Astra owns these source-only
corrections; no R7 merge/build is approved yet.

The solver itself passed all eleven tests and independent NumPy UV-derivative
verification (maximum float32 direction difference 2.98e-8). Ground handedness is
−1; copper faces 2283/2303 are +1, the other four −1. Each repaired entry has one
incident corner; no splitting occurs. Exactly 59 BIN bytes differ within seven
16-byte records (112 permitted positions), with all other BIN bytes preserved.
Successor JSON asset/node metadata and container length change legitimately;
documentation must label the preservation claim BIN-only. Direction verification
has no zero-tangent waiver and rejects the previous fallback. W's qualified staged
approval below is unchanged; X remains the sole heavy owner.

**Tangent follow-up:** source-only R7 `9fb0172e` is delivered on `9c5eca6d` and
under independent review. It proposes exactly seven 16-byte tangent changes with
all other binary bytes preserved; actual incident corners require no vertex split.
Eleven source tests and unchanged 226-file W inventory are reported by the producer.
R7 production/reopen/native acceptance remains pending; this does not modify or
restamp R6 evidence. Botanical X retains sole heavy ownership.

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved `b5dfe08e` +
`fceaac00` on `e66fce84`, with seven invalid tangent bases retained as a staged
limitation. Parent integrated W as **`5641fec9`** and exact shipping exclusions
as **`9c5eca6d`** (`af648e8a`). No new blocking P1 was found. Final art, gameplay,
performance and public promotion remain pending.

## Actual artifact verification

- GLB: `945978699f7b7ee4519f6078b68a508177a75905541f463c1777bf10f5efc47c`.
- Master: `9922b7be04bbc64deda53f0082ec279a2b81f17d5e280d476e74d5b5d12252d8`.
- R5 authority: `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
- 87,566 triangles, 16 nodes, 32 primitives, 18 materials; 15,012,396 bytes.
- All 48 original position/normal/tangent accessor-and-view comparisons match R5.
  Oriented multiplicity, material assignment and planned UV scales pass. All seven
  new roles pass reviewed-pack color/normal/roughness checks; retained materials,
  including orange, remain exact.
- Native readback matches 87,566 position/UV/winding triangles and 51 material/
  channel pixels. Maximum normal error 0.0001078248; maximum **defined** tangent
  error 0.000166595. Seven substitutions are classified separately.
- Actual-W mutations for empty scene, removed root/orphan mesh and one-byte used
  index backing all reject. The former verifier P1s are closed against real art.
- Import UID `uid://dde1113y7kyh3` is retained; LOD generation is disabled and
  full mesh precision is pinned.

Fresh reopen matches all 87,566 assignments with zero position error and maximum
UV error `3.814697265625e-6`. Raw per-corner tolerance is `1e-5`; occurrences are
consumed and leftovers reject. Rounded lookup keys cannot discard duplicates or
missing assignments. Master: 16 editable export meshes, 270 hidden editable
references, 40 packed images.

The actual build ran the parent `author.py`. The later committed adjustment
separates `finish-plan-built.json` from the archival source plan; both have equal
parsed contents. This is a serialization correction, not a changed material plan.

## Seven real tangent defects — staged limitation

These are invalid zero bases on nondegenerate geometry with nonzero UV Jacobians,
not degenerate font triangles:

- Six `GM / copper` triangles, primitive-local faces 2283–2285 and 2303–2305,
  approximately 14.7825–14.7829 m² each, on two long members at Y34.1–34.204,
  spanning X approximately −122 to +122.
- One `R6 / ground` triangle, face 682, area 0.012753 m², from
  `(-192,7.270666,-21.585558)` toward almost coincident vertices near
  `(-186.583,12,-1.122)`.

Godot substitutes `(-0.0000305185,0,-1,+1)`: finite/unit-like but 90–106° from the
expected tangent-plane direction; two copper corners also change handedness.
The defect can affect interpolated shading across triangles. Copper retains R5's
geometry/UV/material; ground changes material and normal texture/strength from
approximately 0.35 to 0.12 with UV scale 1.0. Unchanged bytes do not prove unchanged
ground shading.

Review accepts this inventoried limitation for staging because it does not
demonstrate missing geometry, gameplay obstruction, broad basis corruption or a
new blocking regression in the supplied views. Inheritance alone is not the reason.
Astra producer `ses_efd30e1f6ffeLbhHTPoh266kZW` owns a **source-only tangent
successor**: derive directions/handedness from existing position/normal/UV data,
preserve geometry/material/authority, revise exact-tangent requirements for the
corrected entries, then obtain a new artifact/native proof under a later grant.
W evidence stays immutable; botanical X owns the current heavy slot.

## Native and visual scope

All 22 original images / eleven pairs were inspected; camera/target/FOV match.
**Before is staged R5.** Machinery/roof separation, bunker differentiation and
warm furnace/kiln landmarks improve; cooling lighting/guidance remains readable.
Broad pale surfaces, repetitive ribbing and sparse population still need manual
quality/readability acceptance.

The stage retains 37 panels, 20 signs, 32 motes and 18 materials. WeatherService
is bound without traversal capping, but captures are clear/dry with effects
suppressed. Off/Low/Full and Weather cleanup verify orange preservation, not
exhaustive weather-state acceptance. Eight fresh rays pass; 3,849 R5 capsules
remain prior same-geometry evidence, not a W rerun.

Warmed load 95.529 ms, median static frame 217.69 ms, 112–227 draw calls and
74.14 MB peak reported video memory are llvmpipe measurements, not gameplay/GPU
acceptance. Hosted modes, controller journeys, live team readability, broader
weather, manual art and public promotion remain pending.

## Parent checks and shipping separation

Parent passed **67 tests**: 55 Node staging/artifact/source-state/committed-Git
checks, three builder-function Python tests and nine R6 source tests. All **226 W
manifest hashes/sizes** match. Original `fceaac00` ancestry is preserved.

R6's 74 resource files / 19,007,243 bytes plus R5's unchanged inventory produce
137 exclusions / 35,918,999 bytes. Accepted native selection stays 2,494 files;
all seven production receipts are unchanged. The registry's review-pending label
records the exclusion transaction's original disposition; this approval does not
grant shipping promotion. See `FOUNDRY_R6_PACKAGE_STAGING.md`.

Gallery: <http://100.125.104.79:8796/foundry-r6/>.
