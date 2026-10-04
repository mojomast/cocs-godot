# Serialized support/guard operands — follow-up to db144f7a

Source-only correction on the same isolated branch. Independent review closed
the original census/empty-trace and contradictory-supervisor P1s, then found
that support request operands and mandatory guard operands could contradict
their success summaries. This is a **serialized-validation gap**, not a change
to the physical response guard or a downgrade of AG's verified one response.
Focused independent readiness review remains required. No native authority is
created by this correction.

## Exact support binding

Both `response_guard.gd:41` and `observe.gd`'s arrival sweep request
`-UP * (body.safe_margin + .0001)`. This is approximately **−.0201m**, not the
parent snap's .3m and not snap+margin. Validators now require:

* Query `from.origin` **and all three basis columns** agree with the recorded
  actual post-parent/after-guard transform (guard support), or the identical
  before/after fresh-arrival snapshots (arrival support), within the unchanged
  numeric budget. Cached/hypothetical starting transforms cannot substitute.
* Motion is the reviewed downward vector; margin is actual profile safe margin;
  maxCollisions is32; recoveryAsCollision and collideSeparationRay are exact true.
* Query bodyRid agrees with the profile's live bodyRid, independent of target RID.
  Positive response records also capture the live bodyRid and actual
  floorConstantSpeed value. Exclusion lists are explicitly empty; they cannot
  select a desired target. The fresh pinned sweep helper leaves these parameter
  defaults untouched. `body_test_motion` is intrinsically read-only; if a
  `testOnly` annotation is supplied it may not contradict that API semantic.
* Travel/remainder and fractions are finite; `0 <= safe <= unsafe <= 1`.
  Contact array count is1–31, and an explicit count, if supplied, must agree.
  No invented travel-length or travel+remainder equality rule is imposed:
  recovery travel, including AG's lateral support-query travel, remains valid.
* Every contact has a finite point, finite unit normal within the unchanged
  sweep `.0001` unit-length validity tolerance, finite nonnegative depth, normal
  dotUP at least cos(actual46° limit), stationary velocity, target RID/shape0/
  local0, and point on the certified plane within the guard numeric budget.
  Stationary checks mirror Godot's componentwise `is_zero_approx` (`abs < 1e-5`),
  rather than incorrectly treating endpoint epsilon as a velocity threshold.

The driver and arrival observer add **serialization only**: current body RID,
floorConstantSpeed, and explicit pinned empty-exclusion defaults. Existing body
snapshots already contain complete global transforms. Neither candidate method,
guard, proposal, motion application nor physics request is altered. Target IDs
are never chosen from whichever contact happens to pass.

## Guard and candidate operands

The validators mirror `response_guard.gd`'s numeric-budget computation and
mandatory operands: actual/expected endpoint agreement, zero parent slides,
zero platform linear/angular motion, constant-speed false, finite actual parent
lastMotion equal to the proposed horizontal vector, agreement of that getter
with the guard's lastMotion witness, final pose on the proved raised+horizontal
down-axis, grounded state and valid floor normal, and the freshly bound support
query/identities/plane. The horizontal vector is also checked against recorded
input, initial basis, walk speed and delta, as the original proposal computes it.

Physical UP serialization must bind the request to the pre-response transform,
same body, unchanged margin/max32/non-test/non-recovery flags, proposed vertical
UP vector and modeled raised pose. Requested lift and returned recovery obey
the original bounds. Returned raised pose matches the proof within the same
budget. Existing candidate postconditions are checked from operands: bounded
horizontal displacement, forward progress, positive net rise strictly below
`.25 - .0001`, grounded vertical velocity within `.0001`, and consistent whole
frame, actual velocity and parent accounting snapshots.

Whole-frame displacement is **not equated** to parent position delta or parent
real velocity. These are checked against their corresponding recorded getters,
so AG's positive whole-frame rise and negative parent Y displacement/velocity
remain a passing one-response example. This does not resolve production motion
accounting or establish repeated/full-tread admission.

## Tests and evidence qualification

Eleven new test methods (many isolated mutation subcases) cover each bad query
origin/basis/parameter/flag/fraction/contact independently, separately for guard
support and final arrival. They also exercise contradictory lastMotion/budget,
endpoint/down-axis, slides, platforms, constant speed, floor state, UP request/
travel, velocity, epsilon and accounting operands with pass summaries intact.
Two tests run the actual mocked-child positive supervisor with successful bound
prerequisites: bad guard motion and bad support request both exit1 and emit
failed=true/positiveAdmission=false. There is no invented successor to the last
group; existing shared native-success and dependency predicates remain in use.

The immutable, manifest-checked AG actual guard/support snapshot passes the
offline **one-response** validator. An adapter adds only the new body-RID/default
serialization fields from already recorded identity and pinned source defaults.
It does not rewrite archived values or call AG a full campaign. The synthetic
full-positive test fixture uses AG's real query format/request parameters as its
template and explicitly synthetic flat-support results, bounded.1m advances,
and sustained ordinary full-footprint arrival. Those arrays are test operands,
not collected native evidence.

Offline compatibility tests verify all34 historical AB baseline stage predicates
and all4 historical AD inclined baseline witnesses against hash-checked immutable
receipts. The existing38 tests remain passing. Python/GDScript parity checks are
source-structural only; GDScript remains unparsed/unrun. No test claims source
math or synthesized traces prove actual physics.

`support-correction-receipt.json` seals current checks and current review pins.
Both earlier source/correction receipts remain byte-identical historical records.
All frozen guards/planners, AG candidate application/snapshot/contact method
copies, archives and15 production dependencies remain unchanged. No engine,
import, render, server, native attempt staging, actual child job or execution
grant was used. Full remaining readiness review is withheld pending parent review.
