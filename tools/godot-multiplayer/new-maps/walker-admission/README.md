# V4 admission controls — source proposal, no native execution

Isolated branch `astra/walker-admission-source` from parent `672f3377`.
AB lineage is pinned to evidence commit `5fb9ae68` without merging its artifacts
or modifying the producer worktree. No preparation command, engine, import,
render, server, subagent or queued native job was executed. AC remains the sole
heavy owner. New GDScript is **unparsed and unrun**.

## Two restricted groups, eight paired cases

`inclined-landing-rejections` runs first; `positive-step-admission` requires its
passing, same-source/same-grant receipt. Each group has four cases: radii .35/.42
at yaw −45°/+45°, each running a fresh original Walker and candidate separately.
Thus there are eight paired cases / sixteen profiles planned, not map walks.

### Physical inclined landing

The actual `ConcavePolygonShape3D` top comprises two triangles with leading edge
Y.15, local Z0, width4m and depth3m. Its back edge rises by `3*tan(47°)`.
Vertices are baked into world space at ±45°. StaticBody and shape transforms
remain identity. The base floor is a native static box. There is no rotated
body-up vector, platform motion, fabricated floor state or mock motion result.

The expected planner rejection is **`no_continuous_flat_landing`**: the current
planner rejects nonplanar-in-Y landing vertices before running its down sweep.
This is a physical steep-surface test of the conservative **flat-landing policy**,
not proof that the down-sweep 46° normal branch was exercised. The actual triangle
normal is47° from up. An intent-query contact on this exact target, shape0, in
the low band and opposing input must witness that policy rejection. Ordinary
`no_bounded_riser` is allowed only while approaching; it cannot satisfy the test.
Other rejection reasons fail immediately. Both profiles must produce120 stalled
responses, at least one qualified policy witness and equivalent per-frame
position, velocity and ground state under the unchanged numeric budget.

### Positive rotated step admission

The same top is flat atY.15, width4m, depth3m, represented as a continuous native
two-triangle collider. As in the civic authority treads, the finite top edge is
the capsule obstacle; no extra vertical collider is added to fabricate a
different support identity. The base plane remainsY0. The control starts at
localZ−1, footY.05, settles for20 ordinary frames, then drives local input
`Vector2(0,-1)` through actual Walker yaw±45°. Local goalZ1 lies a full metre
beyond the edge. Input direction is fixed; there is no waypoint steering around
the obstacle or extended per-frame travel. All collider vertices are world-baked.

Expected baseline outcome: blocked,120 stalled responses; **not** a successful
landing. Expected candidate outcome: grounded on the actual target beyond goal,
with **at least one accepted, applied and postguard-verified lift**, exact target
RID/shape0, no candidate fault/reset, and a fresh finite-capsule support query
confirming final target identity and floor normal. Mere arrival or ordinary
rounded-capsule upward movement does not pass. AB's .42 ordinary response moved
upward without assist; this driver never labels that movement an assisted lift.

Both directions use the same real local-to-world input convention. The driver
checks centreline lateral drift≤.0001 and records all applied-step proofs and
whole-frame deltas. The immutable response guard still enforces eight float32
ULPs (≤.0001 domain cap), vector/endpoint agreement, no parent slide records and
fresh finite-body support identity. It may truthfully reject these experiments.
There is no adjustment to recovery, margin, speed, snap, floor angle or guard.

**Native feasibility remains unknown.** In particular, .42 may progress under
ordinary movement, and real parent snap may differ from the proposed endpoint.
An unexpected baseline success, no proved lift, recovery mismatch or conservative
guard failure stops and preserves the failed attempt; it is not a reason to
change the expected result or loosen a tolerance during a grant.

## Telemetry correction without historical edits

The official4.5.2 `KinematicCollision3D.xml` is included with SHA256/URL.
`get_collider_shape(collision_index=0)` returns **Object**;
`get_collider_shape_index(collision_index=0)` returns **int**.

New `slide_telemetry.gd` captures each slide/contact with numerical
`colliderShapeIndex`, collider RID, and a separate immediate string
`shapeObjectDescription`. Both the new driver and candidate diagnostic adapter
use it. The adapter calls original candidate `step` exactly once, then replaces
only `responseGuard.observedSlides` diagnostic metadata. It changes no decisions,
faults, position or velocity. PhysicsTestMotion shape-index APIs stay untouched.

The original candidate, response guard, v2 driver and AB raw receipts are byte-
preserved. AB's Object/freed-Object fields are not retroactively relabelled.
New samples include capsule RID, body RID, actual PhysicsServer shape data,
body transform, parent real-velocity/position-delta, whole-frame displacement,
input, native frame, reset count and proposal/response guard. Known pre-lift
omission from parent velocity reporting remains a production blocker.

## Preparation and future manual execution contract

Preparation verifies **all140 AB inventory entries** against the manifest bytes
from `5fb9ae68`, both AB outcome receipts, their common source and grant identity,
and the15 unchanged production hashes. It copies the original AB source/outcome
receipts verbatim into a fresh write-once namespace for runtime lineage checks.
It creates a source receipt with `grant:null`, `autoStart:false`, `queued:false`.
It neither imports anything nor emits an authorization receipt.

Future command shapes, not executed:

```sh
python3 -B tools/godot-multiplayer/new-maps/walker-admission/prepare.py \
  admission-fresh-id --ab-root VERIFIED_AB_PRODUCER

python3 -B tools/godot-multiplayer/new-maps/walker-admission/run_group.py \
  --fixture FRESH_PREPARED_PATH --engine REVIEWED_GODOT_BINARY \
  --ab-root VERIFIED_AB_PRODUCER --grant-id NEW_AUTHORIZED_ID \
  --grant-sha256 EXACT_RECEIPT_SHA --group inclined-landing-rejections

# Separate manual invocation only after inspecting the first group's result:
python3 -B tools/godot-multiplayer/new-maps/walker-admission/run_group.py \
  --fixture FRESH_PREPARED_PATH --engine REVIEWED_GODOT_BINARY \
  --ab-root VERIFIED_AB_PRODUCER --grant-id NEW_AUTHORIZED_ID \
  --grant-sha256 EXACT_RECEIPT_SHA --group positive-step-admission
```

Future grant must bind exact `sourceSha256`, `engineSha256`, ID, expiry,
`authorized:true`, `phase:"admission-controls-only-v4"`, and explicit
`allowedGroups` subset of those two names. Driver and supervisor deny unknown,
duplicate, reference or map groups. Legacy `groups` and any
`continueAfterKnownBaselineFailure` field are rejected. No continuation CLI
option exists. The supervisor re-verifies AB before every invocation, owns one
nonwaiting lock/process group, bounds execution at180s (driver170s), and records
three empty-group audits. No batch loop, imports, cleanup or retry is included.

Failure immediately retains attempted/passed/failed/unrun case counts and
separate baseline/candidate profile success counts. Baseline success here means
the expected **blocked control outcome**, not traversal acceptance. All traces
up to the first disagreement are retained; no remaining unsafe cases are run.

## Source checks and remaining acceptance

Seven new tests cover finite capsule sweeps and down-support existence at an
explicitly analytic edge witness for both radii and mirrored headings; actual
float32 baked triangulation/whole support strip; physical47° geometry versus
the flat-patch certificate; rotated-vector/wrong-support guard policy; official
numeric API and both telemetry consumers; phase parity/map denial; and Python
source compilation. Analytic witness positions are **never** supplied as native
controller state: the driver reaches its own contact by ordinary input.

These source checks do not predict backend manifolds or claim GDScript parsing.
Independent source review, a separate future grant after AC release, successful
native admission evidence and its independent review are all still required
before requesting any candidate-map authorization. **All60 candidate map walks
remain unrun.** Original184 static failures, full-map acceptance, ordinary-world
impact coverage, material lifecycle and production promotion remain separate.
