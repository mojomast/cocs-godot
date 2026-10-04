# AK corrected-source synthetic campaign — stopped on baseline arrival, released

Base `8a355e98`; branch `astra/walker-parity-admission-ak`. Read-only helper
commits `4b83de0b` and `c2e83163`. Grant `MOTH-BLENDER-20261004-AK` is **released**.
Exactly three separately supervised invocations ran in the authorized order,
with saved owner checkpoints between them. No retry or native source correction.

## Results and exact accounting

| Group | Godot/supervisor | Native pair counts | Native profile counts |
|---|---|---|---|
| Negative |0/0 |34 attempted/completed/passed;0 failed/interrupted/unrun |68 attempted/completed;0 failed/interrupted/unrun |
| Inclined |0/0 |4 attempted/completed/passed;0 failed/interrupted/unrun |8 attempted/completed;0 failed/interrupted/unrun |
| Positive |1/1 |3 attempted/completed;2 passed,1 failed,0 interrupted,1 unrun |5 attempted/completed;1 failed,0 interrupted,3 unrun |

The positive receipt's `completed` includes the failed baseline profile/pair.
Four positive profiles completed successfully in the first two pairs. The
radius.42/yaw−45 candidate and both radius.42/yaw+45 profiles were never invoked.
Overall **positiveAdmission=false, nativeStepAdmission=false, promotion=false**.
All60 candidate map journeys remain unrun and production accounting remains open.

All three native result files exist. There was no missing/fatal native-result
path here, and all supervisors report partialCountersMayBeUnknown=false. These
are instrumented post-return census values, not an engine-internal physical-call
trace. Historical AH/AI unknown counts remain unchanged.

## Passing prerequisites and owner decisions

Negative: exact17 fixtures x2 radii,34 pairs/68 profiles;1,284 settling records,
72 input records including jump launches,678 candidate ordinary responses,
zero assists and exact paired position/velocity/grounded states. Actual ceiling
UP obstruction, overhang clear-UP/blocked-forward geometry and other expected
mechanisms were inspected. Radius.42 positive ordinary Y was not counted as an
assist. Strict current native/supervisor host replay and fresh inclined dependency
replay passed before the timestamped owner review authorized the next invocation.

Inclined: all4 pairs/8 profiles on47° targets passed. Every profile recorded120
qualifying target head-on low-band witnesses,120 terminal stalled responses and
zero assists. Candidate/baseline states matched exactly. Input counts per profile
were127,127,126,126 by canonical case, totaling1,012 records plus160 settles;
candidate ordinary responses586. Strict receipt replay, raw inspection and fresh
two-predecessor dependency replay passed before the positive owner checkpoint.

Both checkpoint/owner-review hash chains and timing after prior group release,
before the next lock acquisition, are preserved. No AH/AI/AJ receipt served as a
fresh predecessor. The actual corrected16-script source, source/grant/engine
bindings and each supervisor's native hash link were verified.

## First positive failure: expected blocked baseline instead arrived

Native outcome **`unexpected_baseline_arrival`**, driver line286:

* Case2, radius.42, yaw−45°, baseline profile0, input record20/frame418.
* Expected baseline: reached=false and120 stalled responses.
* Actual: reached=true, stallCount0, ordinaryLandingStreak6, appliedUpCount0,
  verifiedLifts0, no candidate fault.
* Final position `[-0.71285080909729, 0.165543973445892, 0.712849497795105]`.
  Host reconstruction of the along coordinate is **1.0081223549433544**, beyond
  goal1.0. The native branch outcome establishes that the arrival gate was reached;
  the reconstructed scalar is not a separately logged native scalar.
* Fresh arrival-support query was reached and **passed**; full footprint inside,
  grounded, finalSupport epsilon1µm. Its sole contact was PositiveTread RID
  **236223201282**, collider/local shape0, normal `[0,1,0]`, pointY
  `0.150000005960464`, zero collider velocity. Query/body state remained equal
  across the test-only support check.

This is **not a candidate guard failure**. Candidate application guard operands
are inapplicable to that baseline profile; its required blocked-baseline condition
failed after successful fresh arrival-support qualification. The radius.42
candidate was not attempted. No criterion was relaxed or error turned into pass.

## Two individually completed radius.35 candidate traversals

These results qualify individual profiles, not the failed whole positive group:

| Yaw | Last frame | Final along (host reconstruction) | Applied/verified | Ordinary landing streak |
|---|---:|---:|---:|---:|
|−45° |189 |1.0652300702701605 |1/1 |7 |
|+45° |377 |1.0651912108758332 |1/1 |7 |

Their baselines were blocked with120 stalled responses. Each candidate had20
settles and21 input responses, one guarded application (frame176 or364), no fault,
at most one UP/parent call per frame, and the unchanged9-lift cap. Both application
endpoint errors were **0.0 against1µm epsilon**, final support was reached, and
strict serialized guard/profile replay passed. Each finished beyond goal with
full footprint, at least three consecutive ordinary grounded continued-input
responses and fresh support exclusively on its certified target: RID146028888066
or206158430210, shape0, flat normal, zero collider velocity.

Net displacement from the serialized initial spawn state:
`[-1.460338294506073, .1179805211722849, 1.460338056087493]` and
`[1.4603103995323181, .1179408840835099, 1.460310995578765]`.
On each application frame the **whole-frame pre-lift Y displacement was
.0710892900824547**, while the **parent-only Y displacement was
−.0843750014901161**, and parent real Y velocity was−5.0625. Those distinct
operands are preserved; they do not resolve production pre-lift accounting.

`evidence/positive-detail.json` retains exact guard requests/results, expected and
actual endpoints, tolerances, support identities/contacts, final-support records,
last-three-response states and the failed baseline comparison. It references the
unchanged full raw native receipt rather than manufacturing successful census.

## Release, archive and preservation

All raw logs contain only the official4.5.2 banner and blank line. There were no
SCRIPT ERROR, Parse Error, ADMISSION_FAILURE or inappropriate probe markers.
Failure stayed failed despite releasedCleanly=true. Exact commands, kernel
identities, environment and hash links are in `evidence/execution-record.json`.

The three owned groups were PID/PGID3250966/startTicks628195976 (negative),
3255760/628205156 (inclined),3260758/628214435 (positive). All were measured empty
in three final audits. Lock available `2026-10-04T07:30:40.504985Z`; explicit AK
release **`2026-10-04T07:30:40.505018Z`**. No queued work or engine after release.

Verified AJ23, AI40, AH42, AG29, AF24, AE46, AD45, AB140, Z253, X600, U264,
AA141, AC265,15 production dependencies and historical receipts. Viewer
PID2598700/PGID2598689/startTicks522477875 and seven displays were unchanged.
All27,195 preexisting sidecars were preserved; no new sidecars or cleanup.
The exact-byte archive includes staged source, sealed source/grant, all native
and supervisor receipts/logs, checkpoints, owner reviews and release; its
inventory self-excludes only the manifest. Raw trailing blank lines are retained.

143 current portable Python tests passed after release (5+49+24+18+8+7+32),
separately from native observations. Historical probe/diagnosis tools were not
rebound or run against incompatible corrected pins. Independent archive review
is required before further work; no additional native authority remains.
