# Preferred next measurement — design only, no runnable probe

## Question and scope

Does the reviewed finite downward support query measure a different contact
configuration from an otherwise identity-qualified current-pose observation,
and would the same finite query at the predicted endpoint before application
agree with its post-parent counterpart? AM contains no such paired preflight.
Identical requested transforms do not establish identical results across
different body poses, temporal state, broadphase/caches or query ordering.

Recommend a **small separately reviewed observer-only comparison**, rather than
changing the planner or guard now. Implementation requires a new source review
and explicit native grant. No current grant is usable; no probe was staged here.

## Fixed prospective matrix, no best-normal selection

Freeze requests and order before execution. Use only the already studied first
candidate transition of .35/.15/−45 (passing reference) and .42/.18/−45 (expected
guard failure); these are proposed measurement cases, not new admission scope.
Keep all movement and original proof/parity/guard bytes pinned. Record full body,
shape and target identity, transforms/bases, motion, flags, max count, margin,
fractions, travel/remainder and all raw ordered contact operands. Snapshot body
pose, velocity, floor state and clocks before/after every observer operation.

At the pre-UP planning point, only after original proof/full4 produce an endpoint:

1. Hypothetical endpoint **down margin+.0001**, max32, recovery=true,
   separation=true: same request operands as the existing guard would use there.
2. Hypothetical endpoint **zero motion**, same margin/max32/flags, to investigate
   current-pose/recovery semantics. This is not presumed a better or valid support
   certificate. Source review must explicitly address zero motion handling
   (`godot_space_3d.cpp:698–699` forms motion/length); finite-results validation
   is mandatory. If a reviewed API cannot give defined zero-motion semantics,
   record this limitation and revise the design before granting execution.

After the single unchanged candidate response returns, at its actual endpoint:

3. Preserve the **original guard's existing down32 result and fault** as primary.
4. One predetermined duplicate down32 observation to detect repeat/order effects.
5. One zero-motion same-parameter observation, subject to the above source review.

Pre-UP observations themselves can perturb invisible caches: native comparison
cannot promise they are operationally neutral simply because body state is
unchanged. Retain the existing AM trace as an external reference and explicitly
report changes in proposal, parent endpoint or guard outcome. Do not infer that
post-query equivalence validates all unseen internal state. Additional independent
ordering controls require review, not automatic repeat runs.

The future driver may need an explicitly authorized **diagnostic stop hook**:
after the first candidate guard fault, stop all movement/continuation, preserve
the fault and failed admission status, collect the fixed read-only observations,
then exit. Current AM already exited; do not resume it. The design is not permission
to clear a fault or continue to a landing. Exact endpoint replication requires a
fresh native response under its own grant; synthetic replay cannot supply results.

All query misses, nonfinite operands, saturation, identity ambiguity, mixed
colliders, moving support or state mutation remain unqualified. No alternate
normal is chosen to relabel the original failed guard. A zero-motion contact may
itself include margin recovery and still not be a current physical contact;
compare source semantics rather than naming it authoritative.

## Conservative preflight option (later, separate change)

The existing query helper accepts a body RID plus hypothetical full transform;
therefore a **bounded read-only preflight at predictedFinal is expressible before
UP** without moving the body. Full4 currently predicts endpoint/floor behavior
from the raised edge; it does not test guard-down32 from that endpoint.

If eventually implemented, require the same positive query validity, max32
unsaturated count, empty exclusions, exact targetRID/shape/local shape, finite
ordered fractions, zero support velocity, strict46° normals and1µm landing plane
as the original guard. Preserve shape/mask/transform bindings and verify no state
mutation. An ineligible result prevents application; it must not silently fall
back or manufacture a verified response. Exact failure semantics need review.
Keep the **post-parent original guard** even when preflight passes: predictions
are not observations of actual returned state. Endpoint/forward/platform checks
also remain necessary and cannot be guaranteed by a support preflight alone.

AM's post-query47.477° cannot be assigned to a nonexistent preflight receipt.
If measured matching, a preflight could conservatively avoid the applied-but-
unverified lift. This is correctness improvement only, not positive feasibility,
landing, or a solution for a walker that merely rejects forever.

## Semantic or movement alternatives require architecture review

A future support-contract semantic correction could retain46° but assess a
properly justified current-pose support observation rather than a finite-motion
rest normal. That is a new guard design, **not approved by this diagnosis**.
It requires static target identity, plane/footprint qualification, collision
safety, known miss/failure handling and fresh34 negative/4 inclined protections
plus all positive prerequisites. Aggregate on_floor alone has no sufficient
exclusive target identity; snap collisions are not necessarily exposed in the
returned slide list (AM slideCount0). No floor-normal replacement is justified.

Any alternate motion path must respect one-frame horizontal budget, bounded
UP/FWD/DOWN collision proofs, the same physical guard and no hidden movement
boost. With the current first slice ending before the tread edge, moving the
full footprint onto the tread would exceed the permitted budget. A larger lift
with unchanged forward XZ may land at the same rounded support; cast-grid Y
changes are not a reason to tune until pass. If a guarded responsive transition
cannot be established, escalate an explicit architecture question rather than
changing fixture rise, time step, normals, epsilon or goal. .20 is not a fallback.

This document recommends measurement before either option. It supplies no native
fixture, launch helper, grant template, staging recipe or controller modification.
