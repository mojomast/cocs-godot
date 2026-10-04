# Baseline characterization v1 — source review package

Base **5d8c2b94**, branch `astra/walker-baseline-characterization-run`.
This is an additive implementation for review. **GDScript remains unparsed and
unexecuted. No stage, grant, engine invocation or actual child job was created.**
The approved `walker-baseline-characterization/` design and its original receipt
hashes remain immutable. This package creates no execution authority or readiness
claim; independent review is required before any separately authorized preparation
and invocation.

## Fixed contract

Phase `baseline-characterization-v1`, mode `baseline-only`, sole group
`radius-rise`. Neither native nor host CLI accepts height, radius, yaw or debug
overrides. Exactly these eight profiles, in order:

| Index | Radius | Rise | Yaw |
|---:|---:|---:|---:|
|0|.35|.15|−45°|
|1|.35|.15|+45°|
|2|.42|.15|−45°|
|3|.42|.15|+45°|
|4|.42|.18|−45°|
|5|.42|.18|+45°|
|6|.42|.20|−45°|
|7|.42|.20|+45°|

One fresh **unchanged production Walker** per profile; previous world is freed
before the next. Twenty settling responses, then one to 240 input responses:
maximum **2,080 ordinary returned responses**, with an internal 170-second timer
and external 180-second deadline. There are no retries, adaptive heights,
candidate bodies, UP/lookahead queries, map journeys, automatic height selection
or candidate continuation. The seven-script transitive closure is Walker, its
two UI access helpers, and four dedicated scripts under
`godot/tests/walker_baseline_characterization/`.

The new fixture preserves the frozen flat fixture's base box, world-baked triangle
winding/backface setting, width 4, depth 3, start along −1 at Y .05, and goal along
1. All six target vertices, actual shape readback, AABB and support plane derive
from each case's rise. The original .15 fixture/helper files are not edited or
loaded. Actual capsule radius/height, offset/basis, body and shape RIDs, collision
layers/masks/exceptions, platform settings, slope/wall/ceiling flags, margin .02,
snap .3, floor angle 46°, walk speed 6 and all other pinned Walker parameters are
recorded and checked before and throughout each profile. No motion is applied
after reset except `Walker.step`, called once per response.

## Evidence and classifications

`observe.gd` captures pre/post full transforms and state, requested horizontal
motion, whole-frame displacement, parent displacement/real velocity/last motion,
all ordinary slide contacts and their identities, and **one observational
downward support query per returned response**, including settling. That query
uses the actual live body RID and transform, motion `(0,-(safe_margin+.0001),0)`,
max32 contacts, recovery and separation-ray flags true, empty exclusions, and
the body's recorded collision mask. Its complete before/after state must agree.
No node or velocity is changed by observation.

Python `policy.py` and native `policy.gd` independently replay the encoded
operands, rather than trusting outcome labels or streak counters. Both require
consecutive 60Hz ticks, timeScale1, increasing microsecond clocks, one reset,
state continuity, canonical basis/centerline, no jump/sprint, finite unit contact
normals, nonnegative depth, exact static target/base identities/local shape,
bounded geometry certificates and query fractions, and ordinary displacement
agreement. Vector tolerance is 1µm; parent real velocity reconstruction uses
1e−5m/s for the float32 division path. Last motion is retained as a distinct
sub-motion and is not substituted for whole-frame displacement.

The contact cap is 32; a saturated or missing support result cannot qualify
support. All contacts remain in the receipt. Invalid/nonfinite/foreign-identity
operands are faults; a valid query that cannot prove the required support simply
does not advance a qualifying streak.

* **arrived:** at least three consecutive continued-input, ordinary grounded
  responses with full capsule footprint inside the target patch and body Y
  within margin+.0001 of that case's rise; fresh support exclusively on the actual
  target RID/shape/local shape, static velocity, points on its actual plane within
  1µm and normals within explicit **46°**. Goal along≥1 is additionally required
  at termination. As in the frozen criterion, the qualifying landing streak may
  start before crossing the goal, provided the full footprint is already inside.
* **blocked_with_target_witness:** 120 **consecutive** continued-input responses
  before the goal with whole-displacement length<.0001m (the original v4 stall
  metric), grounded state, fresh qualified base support, and an actual ordinary
  target-edge slide contact on **every** response. The target witness must be
  at 0<Y<.25, oppose horizontal intent with dot≥.98, and exceed the diagnostic
  engine floor cutoff 46°+.01rad. It cannot be an ancient contact, a wrong wall,
  an empty input, or an unsupported stall.
* **unresolved_at_cap:** all 240 inputs returned without either qualified outcome.
  Missing/saturated/nonqualifying support does not become fabricated blocked
  evidence. A failure to establish grounded base support after the 20 settling
  responses is instead `not_settled`, a fault.
* **fault:** stop the entire invocation, retain available/inflight evidence, mark
  later profiles `unrun_after_fault`, and exit nonzero. Stable fault categories
  cover clock, parameters, state, query mutation, settling, geometry, timeout and
  receipt validation. Unknown outcomes cannot be successful collections.

### Mixed base/target contacts

Base support is **not** “every query contact must be base.” Every walkable contact
under the pinned engine diagnostic cutoff **46°+.01rad** must be on the static
base plane with UP normal; at least one such base contact must exist. Steep,
non-floor target-edge contacts may coexist and remain recorded. An additional
walkable target contact prevents base qualification. The engine cutoff is used
only to separate ordinary-contact evidence here: the controller's field stays
46°, and arrival support stays explicitly 46°. Aggregate grounded state does
not identify which internal collision branch ran. In particular, AK's first .42
response has mixed base-floor contacts; the .01 allowance is consistent with
the observation, not a unique causal trace of its target contact branch.

Read-only tests confirm AK's last120 .35 baseline rows satisfy the actual ordinary
stall/target-obstruction portion of the new predicate. AK did **not** record this
new per-frame baseline downward query, so base-support compatibility of a future
run is unproved. Synthetic complete test receipts exercise that part of the
validator and are explicitly not native evidence.

## Collection versus later selection

`completedCharacterization=true` requires all eight profiles to finish as arrived,
blocked or unresolved with full operand replay. Arrival is legitimate data, even
if a .35 reference unexpectedly arrives. `referenceAgreement` reports only whether
both .35 references blocked and .42/.15/−45 arrived. No expected outcome is imposed
on the unmeasured .42/.15/+45 reference. Contradictions are retained for review,
not turned into physics faults or hidden through retries.

`selectedHeight=null`, `selectionQualified=false`, `candidateAdmission=false`,
`nativeStepAdmission=false` and `productionPromotion=false` always. A later
independent reviewer may consider the smallest of .18/.20 with both yaws qualified
blocked and no unexplained reference contradiction. Neither height is guaranteed
to block or admit a candidate. Both satisfy only the old planner's strict scalar
rise limit (<.2499); the planner itself is absent from this closure. Later assist
admission requires a separate source contract/grant and fresh34 negative/4 inclined
protections and positive prerequisites. Original .42/.15 ordinary-capable behavior
is a non-discriminating control, never an assisted-positive count.

## Future sealing and lifecycle (not invoked here)

`prepare.py` provides explicit write-once preparation; it is never imported with
side effects that create a stage. `baseline-characterization-al-01` is only a
future namespace example. It binds all staged/host inputs, the 15 production
dependencies, approved design bytes, minimal project recipe and AK51 inventory.
`--ak-root` is mandatory and read-only. AK's frozen failed positive receipt is
mandatory **lineage**, not a required successful admission predecessor. There are
no native admission predecessors. `review-pins.json` has exact-byte seals; it
does not repin or reinterpret any historical tool.

There is no grant creator. A future grant has exactly eight keys: `phase`, `mode`,
`allowedGroups`, `grantId`, `authorized`, `expiresUnix`, `sourceSha256`,
`engineSha256`. Only `["radius-rise"]` is accepted; expiry is strict and numeric;
source and the pinned nonsymlink absolute Godot4.5.2 binary must match. Preparation
does not grant or start anything. The native entry also rechecks source files,
matrix, lineage, grant, dependency receipt and binary hashes before world creation.
Pre-world failures emit bounded `ADMISSION_FAILURE` codes; they identify admission
gates, not engine-internal predicates.

`supervisor.py` is a manual, one-invocation wrapper with no queue. It revalidates
under the shared heavy lock, writes dependency and start/consumption receipts
**before Popen**, and holds the lock through cleanup and supervisor receipt I/O.
Old corrected AG identity/release helpers are reused through isolated imports and
exact source pins; old launch/build functions are never called. PID/PGID/startTicks
ownership, ESRCH races, PID reuse, unknown/permission errors, three measured final
group audits and signal-handler restoration retain their fail-closed behavior.

Both polling and post-exit scans examine raw logs for script/parse/admission
markers. Logs are retained byte-for-byte (4MiB cap); results are capped at64MiB,
comfortably above the bounded 2,080-response schema. Fatal/absent receipts preserve
unknown counters. `releasedCleanly` describes measured process cleanup independently
of workload failure; even a cleanly released script error is failed. No receipt
claims total internal physical calls: `physicalCallCounts=null` always. Write
failure remains failure, with best-effort stderr reporting and lock release.

## Offline verification

Run only the Python source/evidence checks (no native parser, stage or child):

```sh
python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/walker-baseline-characterization-run -p 'test_*.py'
python3 -B tools/godot-multiplayer/new-maps/walker-baseline-characterization-run/verify_preservation.py
```

Tests cover complete mixed/reference-contradicting eight-profile records, all-JSON-
double replay, matrix/height/plane/identity/clock/intent/streak mutations, grant
constraints, source closure and immutable pins. Supervisor tests mock every Popen,
signal and ownership operation, including timeout, fast-exit markers, ESRCH,
permission failure, PID reuse, launch/write failures, consumption and no retry.
They create only temporary synthetic log/JSON test files, never a native project.
Native/Python semantic parity is source-reviewed, **not native-tested**; a future
authorized parser/runtime may honestly fail and must stop without an automatic fix.

Preservation replay covers AK51, AJ23, AI40, AH42, AG29, AF24, AE46, AD45, AB140,
Z253, X600, U264, AA141, AC265, all15 production dependencies, original current
campaign pins and historical provenance. AK positive remains FAIL. Production
whole-frame accounting remains open; all60 candidate map journeys remain unrun
and the184 static Vesper failures remain unresolved.
