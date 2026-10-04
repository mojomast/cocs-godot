# AD — physical inclined-landing rejection passed, positive admission unrun

**4/4 paired cases passed across8 completed profiles.** This is evidence for
the existing flat-landing rejection policy on real47° geometry, not positive
step-up admission or map traversal acceptance.

Grant `MOTH-BLENDER-20261004-AD` ran in fresh branch `astra/walker-admission-ad`
from parent `8d5641fc`, write-once attempt `admission-AD-01`. Source tooling
commit **`2b1ff4d9`** contains only the exact attempt-name allowance and read-only
trace verifier. No GDScript, fixture geometry, controller or response guard was
changed. All scripts parsed and the group completed on the first attempt.

## Actual authorized execution

- Phase `admission-controls-only-v4`, allowedGroups exactly
  `["inclined-landing-rejections"]`. No continuation fields or positive group
  permission appeared in the grant.
- Preparation verified all140 AB inventory files against `5fb9ae68`, copied only
  original AB JSON lineage receipts, and pinned the actual execution sources.
- **No imports were necessary or run.** The headless script used synthetic
  physics fixtures directly. No GLB was copied into this attempt or instantiated
  in its world. No frozen external evidence tree was imported.
- Reviewed `walker-admission/run_group.py` ran one manually selected group,
  under its nonwaiting lifetime lock and180s supervisor/170s internal bounds.
- Godot4.5.2 official `6ce3de25a`; `LP_NUM_THREADS=1`, `OMP_NUM_THREADS=1`,
  actual60Hz physics frames, timeScale1. No Xvfb, screenshot or render job.
- Owned PID/PGID **1932258**, kernel startTicks **625989396**. Supervisor duration
 20.822s, exit0. The log contains the engine banner and no parser/runtime errors.

Executed source receipt SHA256:
`7fbb6b836d9e6b2b31653e672d4811bfab596b09e6965a3aeb6bf33dac531886`.
Grant receipt SHA256:
`ddbba1e5b4ce88d8c6501391fdebdc3e90a3b5febe0dda0998d1700e7020f339`.
The full argv, binary/source/grant identities, times and process audits are
retained in the attempt receipts. `evidence/trace-analysis.json` is a separate,
read-only verification; original native results are never restamped.

## Actual geometry and results

The physical target is a two-triangle `ConcavePolygonShape3D`, width4m,
depth3m, frontY.15, with its rear rising by `3*tan(47°)`. ±45° course rotations
are baked into world vertices; target body/shape transforms remain identity.
The native float32 fixture vertex arrays give both triangle angles
**47.000000649284°**. These are the live fixture's submitted geometry arrays,
not a claim of an independently exported mesh readback. The native physics
queries and slide contacts independently identify that target.

| Radius | Yaw | Responses per profile | Exact rejection witnesses per profile | Consecutive stalled responses |
|---|---:|---:|---:|---:|
| .35 | −45° | 127 | 120 | 120 |
| .35 | +45° | 127 | 120 | 120 |
| .42 | −45° | 126 | 120 | 120 |
| .42 | +45° | 126 | 120 | 120 |

Each row ran a fresh ordinary Walker and a fresh diagnostic candidate. Aggregate:

- **1,012 input responses +160 settling responses** across8 profiles.
- **960** exact `no_continuous_flat_landing` witnesses;52 approach-only
  `no_bounded_riser` responses. No alternative rejection was counted as success.
- Every witness included a real INTENT-query contact on `InclinedLanding`,
  numeric collider shape0/local capsule shape0, low contact band and head-on
  horizontal contact opposition. The actual response's target RID and shape0
  also matched the fixture's target RID.
- .35 contactY **.150000005960464**, rounded-capsule normal angle
  **51.306894800367°** from up.
- .42 contactY **.152396738529205**, native normal angle
  **46.999999220180°** from up.
- **2,108 numeric slide/contact records** verified: integer shape indices, body
  RIDs and immediate `CollisionShape3D` descriptions. No legacy Object/freed-
  Object shape label was introduced into these records.
- Body RID, capsule RID and actual PhysicsServer dimensions were recorded in
  every response. Real radii were approximately.3499999940/.4199999869,
  height1.7999999523, offsetY.8999999762 and safe margin.0199999996. Original
  floor46°, walk6, sprint10 unused, gravity20 and jump6.5 were unchanged.

All profiles settled on actual floor before driving. Clocks were consecutive
through settling and input, resets stayed at the initial spawn count1, and
there were **zero accepted proposals, applied lifts or candidate faults**.

Baseline/candidate pairs matched **exactly** on every compared settling and
input response: before/after positions, velocity, whole-frame delta, parent
position-delta/real-velocity, input, ground state, resets and sprint/jump flags.
This is equality of those recorded fields, **not all internal solver paths**.

Final positions mirrored as expected:

- .35: X=±.212131947279, Y=.016666663811, Z=−.212131947279.
- .42: X=±.282842636108, Y=.016666663811, Z=−.282842636108.

Receipt counts: attempted4, passed4, failedTrials0, unrun0;
baselinePassed4/candidatePassed4 describe the expected **blocked control**
outcome, not successful climbing. `nativeStepAdmission:false`,
`productionPromotion:false`, `candidateMapWalks:0` remain explicit.

## Scope and next boundary

The planner rejects the nonhorizontal target at `flat_patch` before an
up/forward/down proposal is admitted. This run therefore does **not** exercise
the later down-sweep floor-angle rejection or the post-response guard on an
applied lift. Numeric slide telemetry was exercised in the driver; the
candidate adapter's applied-response diagnostic branch remains unexercised.

Positive-step-admission was **not authorized and not run**. All60 candidate map
walks, reference reruns and sprint journeys remain unrun under AD. A separate
parent review and new grant are required for any positive invocation. The
original pre-lift whole-frame velocity-reporting issue, production promotion,
ordinary-world impact matrix and184 static contacts remain unresolved/separate.

## Preservation and release

Read-only verification preserved **AB140, Z253, X600, U264, AA141 and AC265**, all15
production dependencies and historical v1/v2/v3/v4 provenance. Every other
parent-tracked byte remained unchanged. The prior source hashes describe their
historical states; actual AD execution is bound by its new source receipt.

All **1,597 baseline `.uid`/`.import` sidecars** remained byte-identical. No new
sidecars were created and none were deleted; no cleanup or import-cache archive
was needed. The preexisting viewer PID2598700 / PGID2598689 /
startTicks522477875 and all recorded display processes remained unchanged.

Final empty audits of the sole owned group:

- `2026-10-04T01:20:05.043192Z`
- `2026-10-04T01:20:05.262888Z`
- `2026-10-04T01:20:05.482958Z`

**Explicit AD release: `2026-10-04T01:20:05.706110Z`.** Lock availability verified
at `01:20:05.706177Z`. No queued heavy work and no engine invocation after release.

Post-run source checks: **7 admission +32 existing Python tests passed**.
The full raw native trace, supervisor log/receipt, grant, pinned source/AB
lineage, initial source snapshot, trace analysis and preservation/release
receipts are retained for independent review.
