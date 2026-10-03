# Botanical/urban source review — corrective source approved

## Post-U successor review in progress

The source approval below led to actual U builds, which exposed three assembly/
geometry failures; it does not establish approval of those artifacts. The latest
successors are `f358e497` / `3002a9ba` / `da2e53eb` and remain unmerged pending
independent review by `ses_efc89c2afffeKQvhqPUs4YwsaY`:

- **Helix revision-4:** five detailed radial arches on ten terrace-grounded posts,
  connected by two eaves and a ridge; intended full-bearing/attachment tests and
  49,553 reported finite-capsule source samples. All 5,240 decorations retained.
- **Parallax districts-v4:** a supported entry landing, retaining-wall aperture
  cut and graded upper-terrace connection; original portal probes/endpoints and
  lightwell descent retained.
- **Vesper urban-v3:** six legacy parapet ends replaced by Kit and 54 retained
  with canonical render/collision boundaries, checked before suppressing duplicate
  craft geometry. No blanket tolerance change.

Reported checks: 13 corrective Python / five Node, 27 existing Python / eight U
fixture Python / 25 existing Node, standalone Kit checks and deterministic
generation. Frozen U failures are reproduced from their actual GLBs; all 264 U
hashes remain unchanged. A narrow follow-up is making archival inputs explicit
without merging rejected U artifacts. No successor has a built master/GLB or
native acceptance yet. W owns the heavy slot for Foundry R6.

Successor source identities:

| Map | Geometry hash |
|---|---|
| Helix | `f5a3d0d7b2872fa7c7fa6bb2727ee31915a717ffbc160343acf491fe3b9bc49e` |
| Parallax | `3a5800e89876ebcc741381802def24415d5050651c0d3b831ea8b9ec3b77b4f9` |
| Vesper | `fd8e7134c8933e908336d7b0409c66bdc90f4adc03fcfc6e596d5b4579f1c740` |

## Pre-U source disposition: integrated, superseded by actual build findings

Independent Astra `ses_efd0e4deaffeke8j2rdXdxtbbn` approved corrective commit
`6f6b990fafd486c0f4d8960359049a3e4ff2ae22`: all three remaining P1 findings are
closed. Parent merged the complete repair series as **`32eba401`** and reproduced
**25 Node tests, 27 Python tests and standalone Kit checks**.

- Parallax accepted-author material areas agree within `1.3e-11 m²`; 5,253
  float32 interior samples have zero height/material-ownership mismatches.
  Candidate union contains 1,145 triangles / 18,435.838328 m², with zero discarded
  subprecision area. Physics authority remains byte-identical to `dd05f50c`.
- Vesper has exactly two slate terrace triangles / 352 m² at Y=22. All 26 routes
  pass and 857/857 nav nodes connect. Candidate hash is
  `c044bc54cfd96e99e3b29d61c5bc66bc9c470f8f3823176c063d2fe6ee9474ad`.
- Both malformed GLB counterexamples reject. Build/reopen audit paths also bind
  evaluated triangle totals and used-material sets to scene-backed geometry.
  The backed 160,001-triangle fixture passes with its advisory overage.

This is source approval only. Actual Blender evaluation/export, packed-master
reopen, exported pixel checks, screenshots and native gameplay remain pending.
The repair owner is preparing source-only native staging/capture fixtures; coastal
T retains the sole heavy grant. Earlier findings and review transitions below are
historical evidence, superseded by this disposition.

## Historical corrective delivery and review

### Three-blocker follow-up delivered

Astra delivered **`6f6b990f`**, reporting candidate-aware coplanar floor clipping
with material/coverage lineage, one supported slate Vesper terrace, and nonempty
scene-referenced/binary-backed GLB validation. The triangle policy stays advisory,
including a real binary-backed 160,001-triangle fixture.

Reported checks: 25 Node, 17 Python repair and ten correction tests, standalone
Kit checks, Vesper generation and both affected plans. Source triangle estimates
are Helix 147,026 / Parallax 144,321 / Vesper 40,686. Independent reviewer
`ses_efd0e4deaffeke8j2rdXdxtbbn` has the follow-up for focused verification of the
three previous findings. No parent merge or engine acceptance is claimed yet.

### Independent corrective review: three blockers remain

Reviewer `ses_efd0e4deaffeke8j2rdXdxtbbn` completed review of `f6687255`,
`4e2b83bc` and `dd05f50c`. Most original repairs are independently supported,
but source approval remains withheld for these specific defects:

1. **Parallax floor composition:** `shell_plan()` emits overlapping authority
   floors while captured base craft excludes the accepted floor-union pass.
   `armillary-arc-joint-0--12` (saltstone) and `tidal-cistern-joint-0--12`
   (cistern) share ten identical triangles at Y=12; their opposite-side pair
   repeats the issue. Twenty exact duplicates have conflicting materials.
   Restore candidate-aware union/material priority, also resolving partial
   coplanar overlaps while retaining the new lightwell openings.
2. **Vesper roof duplication:** `roof-terrace-block-cap` (brick) and
   `roof-terrace-deck` (slate) both render the entire 22×16 m face at Y=22,
   X=7..29/Z=37..53. Select one slate visual surface while retaining support
   and the actual playable terrace.
3. **Invalid export acceptance:** `audit_glb()` accepts JSON-only containers
   with zero meshes or a single count-only accessor without positions, buffers,
   scene nodes or materials. Empty material loops produce no evidence yet pass.
   Require nonempty scene-referenced backed geometry, valid accessors/indices/
   bounds/materials and required pixel evidence. Triangle totals stay advisory.

Original Astra repair owner is correcting these three on its isolated branch.
No Blender/native execution or shared helper edits are authorized for that lane;
S retains the sole heavy slot. The repaired branch remains unmerged.

Independent positive evidence includes actual nine-part compound capture,
coordinate/heading fixes, source chunking, complete Helix decoration and pinned
base craft, physically checked Parallax descent and Vesper roof access, working
portal normalization, winding handling, PBR/preserved material split, packing,
pixel-verification hooks and restored cameras. All 25 Node / 16 baseline repair
tests passed; a float32 scan found no emitted polygons below the Kit area limit.
Those checks cover pre-bevel/source geometry, not evaluated native acceptance.
The reviewer explicitly approved the **advisory triangle policy**.

Astra returned `f6687255` and `4e2b83bc` on
`astra/map-variety-botanical-repair`, reporting all 13 repairs with regenerated
authority, physical-route probes, complete art composition and adapter/export
checks. Reported verification: 25 Node, 16 Python repair checks, standalone Kit
checks, three generators and three plans. A separate Astra reviewer
`ses_efd0e4deaffeke8j2rdXdxtbbn` is evaluating those commits; no Blender or native
acceptance is claimed and they remain unmerged.

The user's subsequent triangle guidance makes global totals advisory. The repair
owner is updating that policy separately; source-mesh chunking and export-validity
checks remain strict. The historical findings below describe the rejected Flash
candidate, not an assertion that the corrective commits still contain each defect.

Independent reviewer: Astra `ses_efd55fd04ffedSQ6q14ztgmqaa`.
Reviewed commits: `8cff03b0`, `ddf8c70d`, `0351e1d1`, foundation `190fa2a2`.
The reviewer reproduced 18 passing Node tests using source-only probes. No Blender,
Godot, import, render or server ran. The passing tests do not establish buildability
or traversability. Following the user's escalation instruction, Astra reviewer
`ses_efd55fd04ffedSQ6q14ztgmqaa` now owns corrective implementation in a fresh
isolated worktree. Original Flash owner `ses_efdbaaa61ffesiVbXI7pmlS04Q` stopped
at `0351e1d1`, preserving one unverified partial edit to `kit_expander.py` in its
own worktree. That incomplete patch is not an accepted correction.

Paths below are relative to `tools/godot-multiplayer/new-maps/`, except the shared
Kit at `tools/map-variety-pipeline/blender_kit.py`.

## Blocking findings

1. **Compound-object placement:** `map_variety/kit_build.py:29–31,117–119`
   treats `Kit.framed_bay()` as a single object, although it returns a list of two
   jambs and creates additional unreturned objects. Placement must transform the
   entire created assembly; iterating just the returned jambs is insufficient.
2. **Invalid pipe profile:** `kit_expander.py:268–269` requests six-sided stall
   posts; the real Kit requires 8–24 sides and raises `Invalid manifold profile`.
3. **Oversized source mesh:** Helix's verdigris surface bucket has 27,504 triangles,
   exceeding the Kit's 24,000-triangle single-mesh limit before batching. Split
   authority buckets into bounded source meshes before export batching.
4. **Mixed coordinate conventions:** conversion to `(x,-z,y)` precedes compound
   handlers that still add heights to Y. A tower with source origin `[48,12,-48]`
   and height 40 produces Blender center `[48,68,12]` instead of `[48,48,32]`.
   Child offsets also ignore directive heading. Helix ridge world-space paths are
   treated as local paths. Use explicit local geometry and a single rigid transform.
5. **Incorrect box height:** `kit_expander.py:433–444` translates centered boxes
   by `min_y`, rather than the interval midpoint. Parallax's collider interval
   `[12,34]` renders as `[1,23]`. Verify emitted vertex bounds against authority.
6. **Incomplete map composition:** 5,240 Helix non-colliding art meshes, including
   clerestory panes and the new grotto pool, are omitted. Vesper clock/tram forms
   also lack handlers. Compose all supported representations, deduplicating actual
   terrain-backed geometry rather than dropping decorative categories.
7. **Covered Parallax descent:** the court floor at height 12 covers the proposed
   well floor at 8 and its descending steps. Actual support at `(34,-34)`,
   `(32,-34)` and `(28,-34)` remains 12. Cut the higher floor and construct a
   physically continuous, reachable descent with head clearance.
8. **Invalid portal probes:** recipes supply two-component directions while the
   probe reads a third component, producing NaNs and silent passes. A solid-wall
   fixture reports zero failures with `[1,0]`, six with `[1,0,0]`. Normalize valid
   2D directions and reject malformed/non-finite inputs; test blocked portals.
9. **Insufficient route/stacking checks:** proximity-based connectivity ignores
   edge blockers/support; stacking checks overwrite intended heights with highest
   support; Vesper/Parallax omit preserved-route auditing and disable congruence.
   Vesper's new roof-access step at `(31,52.5)` claims 15.5 but actual support is
   20.4 from `civic-stair-55`. Preserve intended heights and probe continuous old
   and new route edges, support, blockers, head clearance and actual entry transitions.
10. **Contradictory material contract:** `ADAPTER_CONTRACT.md` requires linear
    source albedo bytes, correct sRGB GLB output and identical source/export hashes.
    These cannot generally all hold. Preserve original provider files and record
    separate hashes for correctly encoded export images. Sol owns the adapter.

## Additional required corrections

11. **Shared curved-rib winding:** actual Kit geometry yields signed volume
    approximately −4.69894 for a semicircular rib whose expected volume is positive
    (approximately +4.71239). Sol, the exclusive R/shared-Kit owner, is assigned
    verification and correction; Flash must not concurrently edit that helper.
12. **Incomplete budgets:** counts omit evaluated bevels, compound trim and full
    scene geometry. Label source estimates honestly and enforce evaluated/export
    triangle and primitive counts, rather than merely recording intended caps.
13. **Missing review cameras:** preserved Parallax/Vesper camera definitions are
    never instantiated after scene deletion. Recreate their positions and target
    orientations with the same explicit coordinate convention.

## Positive evidence and disposition

The simple shell transform and glTF Y-up export are mutually correct. Shells use
triangle indices, and source probes found unchanged support at preserved ordinary
and team spawns and objectives. Those positives do not resolve the blockers.

**All three candidate revisions remain unmerged and unapproved for Blender
execution.** Foundry production continues independently under R. Corrective source
tests must exercise the concrete failures above; actual master/export/render and
gameplay acceptance follow independently reviewed source correction.
