# Foundry R7 — qualified staged approval; seven tangent defects closed

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved **`26da91b3` +
`f3b51b2c`** for staged source/artifact integration. All seven invalid tangent
bases are corrected in the actual GLB and actual Godot readback. No blocking P1
was found. **R7 does not require R6's bounded tangent exception.** Parent merged
Y as **`dd76b82a`**, preserving original ancestry, and integrated package-only
`0f108974` as **`dd6bc7c3`**.

## Approved identities

- GLB: `6325fdf0003813c5cb5a59aca3626f6756998fb53f8aaa143d9f3043f3caa44f`,
  15,012,592 bytes.
- Packed master: `96314db722902c12c8b5866edfd0d12844db3a99527eb746c58f61376dc09472`,
  6,352,538 bytes.
- Authority: `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`, unchanged.

## Actual geometry, tangent and material proof

Read-only strict artifact/native replays pass: 87,566 triangles, 16 nodes,
32 primitives and 18 materials. Exactly 59 BIN bytes change within seven records
(112 permitted positions); all other BIN bytes, including geometry, valid tangents,
UVs, indices and images, match R6. Successor JSON/container changes are separate.

Native positions, UVs and oriented multiplicity match exactly. Maximum normal
error is 0.0001078248 and all-corner tangent error 0.000166595, with handedness
checked and **zero undefined-tangent waivers**. Eighteen material-field sets and
51 decoded image-channel comparisons pass.

The reviewer independently matched complete oriented position/UV triangle triples
before reading tangent values. Neither tangent direction nor handedness selected
the matches; all seven incidents have exactly one native triangle:

| Entries | Native handedness | Maximum component error |
|---|---:|---:|
| Ground, accessor 48 / vertex 3244 | −1 | 7.25665e-5 |
| Copper vertices 5151 / 5207 | +1 | 6.33283e-6 |
| Other four copper entries | −1 | ≤4.57785e-5 |

Mappings agree with `seven-corner-native-map.json`, including the reordered native
ground face. None uses the old fallback. The initial collector's vertex-only
ambiguity was resolved by complete incident matching, not proof filtering.

## Editable master and fresh reopen

Both committed intermediates, `editable-export.glb` and `reopen-export.glb`, pass
all 87,566 oriented assignments and semantic material comparisons. Position/normal
errors are zero; maximum UV error is 4.76837158203125e-7. Receipts bind reviewed
production/repair/material-contract source hashes. The master has sixteen editable
export meshes, 270 hidden editable references and forty packed images; persisted
recipe/compiler hashes agree.

Actual editable meshes are exported and audited before the canonical baseline
receives the deterministic patch. A fresh process repeats the audit and requires
canonical output equality. The original clamp-sampler and orange-emissive-texture
counterexamples still reject in the full audit.

## Native stage and image review

All 26 original PNGs were inspected: eleven standard and two targeted pairs.
Standard views show no broad visual regression; copper shows a subtle local shading
change. The tiny ground triangle is not visually isolated; its closure rests on
exact geometry and native basis proof. Pale surfaces, repetition and population/
polish concerns still need manual art review.

Before images are fresh staged R6. All thirteen pairs match camera, target, FOV,
authority, capture-script identity and weather state. The stage retains 37 panels,
20 signs, 32 motes and eighteen materials. Off/Low/Full emission and Weather cleanup
assertions pass without traversal capping. Captures are clear/dry with weather
effects suppressed. Import UID `uid://co3ptxsbq46fl` is retained; generated LODs
are disabled and full precision is forced.

Eight fresh authority rays pass. The 3,849 R5 capsules are prior same-geometry
evidence, not a Y rerun. Audio/V-Sync warnings do not negate these completed checks.

## Parent checks and remaining acceptance

Parent verified all 237 Y manifest hashes/sizes and three empty release audits
covering sixteen groups, no current survivors and lock availability. After merge,
all 237 hashes still match and **78 checks pass**: 59 Node packaging/committed-Git,
three Python builder fixtures and sixteen R7 source tests. No heavy grant is active.

Exact R7 exclusion covers 74 files / 19,007,438 bytes. Combined R5/R6/R7 exclusion
is 211 files / 54,926,437 bytes, leaving 2,494 accepted native paths and all seven
production receipts unchanged. Original artifact ancestry activates each pinned
manifest; unknown/tampered/missing candidates and production-reference bypasses
reject. Registry review-pending labels preserve transaction history, not current
approval or shipping promotion. See `FOUNDRY_R7_PACKAGE_STAGING.md`.

Hosted/controller journeys, live readability, broader weather, manual final art
and shipping/public promotion remain pending. Native sampler/alpha/occlusion state
is not read back; its current proof is source semantic equivalence. Warmed load
97.901 ms and median static frame 212.426 ms are llvmpipe measurements, not gameplay
FPS or evidence of a performance improvement.

Gallery: <http://100.125.104.79:8796/foundry-r7/>.
