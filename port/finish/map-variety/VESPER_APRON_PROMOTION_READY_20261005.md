# Vesper apron promotion-ready transaction (2026-10-05)

**Status: source-only promotion transaction; native acceptance pending.** Branch
`spacebunny/vesper-bevel-support-visible-20261005` (commits `f3583d6e` design,
`623736f4` main merge, `a12deb01` transaction, `2346c48d` fixture re-base).
`git diff feature/relay-campaign -- game/` is zero lines: the movement contract
stays byte-identical.

## Design (owner-accepted 2026-10-05)

A **walkable support-visible apron** in front of every stair riser, at
`atan(0.84) = 40.030259°` — inside Vesper's `terrain.maxSlope` of
`0.7 rad = 40.107°`, so the production support query can see it. Horizontal run
`= rise / 0.84`: 0.178571 m civic (80 treads), 0.170068 m roof (14 steps,
candidate-only). Purely additive: all 94 authored tread tops are byte-identical.

- Contact normal 40.030259°, 5.9697° under the 46° guard; cosine margin 8.6e-4
  over the slope budget (862,678× the tested epsilon).
- Rejected by measurement: shallow subtractive face (4 × 0.15 m support losses),
  tiered apron (324/354 contacts back over 46°), 45° chamfer + walkable shelf
  (0.043 m support loss). A 45° face can never be visible to this query.
- Owner-accepted cost: nav490 support 13.8 → 13.873636 m (+0.073636, the
  provable minimum for any admissible geometry) plus six raises at three
  locations, max +0.111818 m. Zero genuine support losses.

## Artifact re-derivation (Blender 4.5.14, `author_blender.py`)

| artifact | before | after |
|---|---|---|
| `art/worlds/vesper-viaduct.glb` bytes | 3,647,280 | 3,658,480 |
| GLB sha256 | `6afe34c8…c0bfd` | `51a5b576…b022d2` |
| GLB triangles | 54,804 | 54,964 (**+160** = 80 civic aprons × 2) |
| GLB embedded fingerprint | `1fbf980f…` | `690dfef2…` |
| `masters/vesper-viaduct.blend` sha256 | `e9068c9c…` | `59c490c9…` |

Element-by-element diff: meshes 11, primitives 11, images 16 unchanged and
byte-identical; only the civic apron triangles are added and the embedded
source fingerprint is refreshed. `vesper_h_inventory.json` records the new GLB
row.

## Receipt transaction

- New lane `tools/godot-package/vesper_apron_dependencies.mjs` (verifier +
  reverser, with shape guards for every section and sibling-receipt rules).
- All seven receipts carry `vesperApronAdvance`. Vesper additionally binds the
  aproned geometry (`world`, `dressingProfile`, `identityTable`) and owns
  `sourceChanged` (`recipe.mjs`), `exportsChanged` (GLB), `mastersChanged`
  (.blend), `fieldChanged` (`measuredGLBTriangles`), plus the shared `changed`
  (`profile.gd`, both world JSONs, `dressing_dependencies.mjs`,
  `production_resources.mjs`, H inventory) and `added` (the lane module).
- `dressing_dependencies.verifyDressingAdvance` reverses the newer apron lane
  before reconstructing dressing-era bytes; `production_resources` verifies the
  apron lane ahead of movement and resolves Parallax's runtime hook through the
  apron `runtimeChanged`.
- `production_requirements.json` pins refreshed. One-shot reconcilers used only
  against the branch: `/tmp/opencode/apron-advance.mjs`, `apron-repair.mjs`,
  `apron-inventory.mjs`.

## Verification

- Package suite on the branch: **294 pass / 5 fail**, all five environmental in
  the branch worktree (4 × missing `ws` node_modules, 1 × `GODOT_BIN`); the
  main checkout provides those.
- Apron lane tests 5/5; `production_resources` 4/4; receipt-history fixtures
  re-based (counts +1 helper input; source/artifact fields owned by the advance;
  H inventory GLB row exempted by the artifact advance; Stormglass protected-path
  drift excludes the additive grade-plan tooling).
- Dressing: `author --check`, `check.mjs` ×6, `negative.mjs` 9/9, headless
  `validate_profiles.gd` `DRESSING_HEADLESS_FAILURES=0` (Vesper rebound to the
  aproned `db20ce1f…` identity).
- Static census: civic 0/170 over 46° on both builds, max 40.030259°; the 2
  roof-terrace wall contacts persist (out of scope; separate proposal).
- Mover: 60/60 clean trials, 0 blocked frames, 0 airborne, 27,930 frames
  (baseline); `navConnectivity` 591/591 and urban-v2 857/857;
  `variety-source-check.mjs` exit 0 with 0 physical failures.
- Other tests: stair 71 Py, census 7, `builder-leg-literal` 11/11, movement
  2/2, urban-v2 variety 6/6, repair 7/7, correction 5/5; the `game/*` failure
  set is identical to baseline.

## Residual reds (explicit, none waived)

- Post-X Python suite: 6 red — `test_art_binding` ×3, `test_native_fixture` ×1,
  `test_contacts` ×1, `test_census_bevel` setUpClass ×1. These are the
  **native-fixture re-pin scope**: `art_binding.py` and
  `binding-followup-provenance.json` still pin the pre-apron accepted pair
  (`authority e273264a…`, `GLB 6afe34c8…`) and must be re-pinned to the aproned
  pair before `vesper-binding-02`. The `diagnose_contacts.py` `OverheadSide<n>`
  naming fix is already on the branch.
- The 2 wall contacts remain a separate roof-terrace proposal; the roof run is
  candidate-only (not in the accepted runtime world).

## Native ask

Run the six prepared groups as a fresh **`vesper-binding-02`** attempt against
the aproned accepted world with the re-pinned fixture; expected outcome is the
civic ascent stalls cleared with the mover-clean geometry, and every group
triaged without waivers. No promotion or release follows from this document on
its own.
