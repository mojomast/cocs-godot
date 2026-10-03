# Foundry R5 — qualified staged integration approval

Independent Astra reviewer `ses_efd0e4deaffeke8j2rdXdxtbbn` reviewed worker
`4a2f1201` plus shared receipt fix `77d3d16c`. **No P1 correctness blocker found.**
Parent integrated reviewed shared sources as `bce5b834`, then selected R5 as
**`7ae3f2f5`** without merging rejected R4 art.

## Actual identity

- Geometry: `61bf7574860285223dd110fec9a8a3ec239b1b3d7102887020009e24d4ae0879`.
- GLB: `237dcc9d1b339116915d824f9896e6ee7daa57b0c13bab08c58da8d51445c9c8`.
- 87,566 triangles, 16 mesh/primitives, 11 materials, 30 embedded images.
- 12,394,520 GLB bytes; design guidelines are not rejection ceilings.
- 235 final-manifest files independently checked, zero hash/size mismatches.

## Independent correctness findings

- Fresh shape generation and authority generation match committed outputs.
- All 270 new components match actual GLB triangles with multiplicity; no
  unaccounted new triangles. Both directions of visual/collision-shell sampling
  give maximum boundary distance **0.021746 m**, within the authored bevels and
  the 4 cm probe tolerance. Upper bodies and caps are included.
- All 62 drums pass actual exported face and corner-normal outward checks.
  Struts use local-zero placement and headframes interpolate real roof anchors.
- All **69,870 accepted baseline triangles** remain with matching multiplicity;
  baseline walking surfaces, routes, nav, spawns, teams and objectives remain
  unchanged. Source differences are restricted to `terrain` and `art`.
- The old bunker and tipple ray counterexamples now match within approximately
  one micrometre. The old unsheared conveyor location is clear in art/authority;
  the correctly sheared conveyor is hit at 0.8 m in both. Portal apertures are clear.
- An independent **27,185-position route scan at ≤0.1 m spacing** found no new
  intrusion in its tested central body band at 0.37 m clearance. This supplements
  rather than replaces controller-driven traversal.
- Recorded **3,849 native capsule checks and eight rays** match successful logs.
  The documented float32 floor-seam case retains its four 5 mm support neighbors.
- Exact staged schema/profile identity rejects the accepted old Foundry hash.
  Production WorldMap, Binder and WeatherService are exercised without modifying
  accepted production identities. Material overrides are instance-owned.
- Actual exported `GM / orange` matches accepted PBR/emission fields within
  `1e-6`, including lifecycle binding/restoration checks.
- All 22 screenshot hashes match. Twenty are from the full capture run; the final
  tipple pair is from the retained targeted reframe. Earlier attempts remain.
- Packed-master reopen has matching master hash and a successful retained native
  receipt; the independent reviewer did not rerun Blender.

## Parent integration checks

On `7ae3f2f5`, parent reproduced the **235-file hash/size verification**, authority
generator `--check`, built material-pack receipt and independent committed-Git
seven-unit strict inventory test. No engine rerun was performed during integration;
coastal T owns that slot.

## Acceptance boundary and next work

Approval covers staged source/artifact integration. Hosted six-mode journeys,
controller-driven traversal, manual visual approval and public promotion remain
pending. The inspected images retain broad pale surfaces and repetitive treatment;
this is not completion of the user's final polished-art goal. Static llvmpipe
167–315 ms/view-frame means (median 214 ms) are not GPU/gameplay acceptance.

Astra's producer now owns a **source-only revision-6 finish pass** to improve
intentional district/material variation while preserving corrected geometry and
R5 evidence. Actual new visuals require a later serial grant.

Package owner is checking explicit exclusion of staged candidate resources: the
current native-file collector includes the new `art/revisions` directory, so
passing the existing seven-unit inventory alone does not establish that an
unpromoted candidate stays out of a future export. No release build is authorized
until that shipping policy is reconciled.

Gallery: <http://100.125.104.79:8796/foundry-r5/>.
