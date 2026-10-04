# P1 receipt-admission correction to 8de9d63a

Source-only follow-up on `astra/walker-parity-admission`. The independent review
blocked integration/readiness: aggregate counts, roles and success booleans did
not prove that the declared cases had recorded execution. This correction is
submitted for **the remaining full readiness review**, not an assertion that the
rest of the proposal has been approved. Parent documentation commit `95805b68`
tracks the task; it is not integration or execution authority.

## Canonical census and recorded evidence

`evidence.py` and `evidence.gd` apply the same data predicates from `successful()`.
The expected registry is code-owned, never read from receipt declarations:

* AB: frozen17 IDs in `controls_v2.gd` order, each radius.35 then.42 (34 pairs).
* AD: radius.35 then.42, each yaw−45° then+45°, incline47° (4 pairs).
* AE: identical radius/yaw order, incline0°, rise.15 (4 pairs).

Indices, exact spec keys/values, roles and outcomes must agree in order; no
deduplication/reordering can turn duplicates or substitutions into a pass.
Traversal specs retain start−1, goal1 and max240. Profile capsule radius/height,
offset, movement parameters and initial body yaw basis must match. Traversal
profiles now also serialize the existing fixture's target RID/shape/path,
world-baked faces, direction and normal. Validation matches the fixed geometry
and its geometry-ledger RID/name, including for blocked baselines.

AB requires20 settling records except airborne's1, plus one test response except
jumping's launch and test responses (2). These reflect the actual driver, not a
uniform fabricated count. Traversals require20 settling records and1–240 input
records. Each record requires returned=true, no candidate fault, correct intent,
60Hz/timeScale1/delta, consecutive frame numbers, finite state/delta operands,
resetCount1, and consistent whole-frame displacement. Baseline query snapshots
must agree; candidate ordinary/accepted paths, per-frame calls and cumulative
counters must agree. No empty trace or `never_executed` outcome passes.

AB's terminal reason must match the frozen fixture reason list, with an actual
recorded intent contact for the geometric riser cases. AD requires recorded
low-band head-on contacts on the identified slope, the exact rejection reasons,
and120 terminal stalls. AB and AD compare recorded baseline/candidate positions,
velocities and grounded flags across all recorded responses. The validators
check required operands; they do not rerun collision geometry or prove that a
hostile producer could not fabricate an entire consistent physics trace.

Positive blocked baselines require120 observed terminal stalls, a recorded fixed
target and position short of goal. Accepted candidate frames require physical UP
counts, actual UP snapshots/travel, unchanged query snapshots, completed parent
state and guard state, the guard's success reason/epsilon/endpoint/no-slide
operands, and its fresh support contacts linked through resolved numeric collider
identities. A standalone guard-pass boolean cannot count as a lift. Full-tread
arrival additionally checks fixed-target support contacts, exact final state
around the fresh query, footprint/plane/normal operands and at least three
consecutive ordinary grounded footprint responses. Cumulative verified/applied
counts and9/11 lift bounds remain enforced.

## Supervisor contradictions

Both dependency readers retain the native JSON hash cross-link and apply the
full current native campaign predicate. The selected predecessor supervisor
must also have matching phase/mode/group/source/grant/engine/native hash, scope,
returnCode0, exact boolean flags, and no stop, supervisor, invalid-native or
cleanup error. Owned pid=pgid and positive startTicks must be recorded; this is
receipt consistency, not a new retrospective OS ownership audit.

Exactly three measured=true, empty-member, error-free audits are required.
Each timestamp must parse in the actual helper's UTC microsecond format, round
trip as a valid calendar time, be strictly increasing/distinct, and lie between
the recorded lock acquisition and release-pending times. Duplicate timestamps,
invalid dates, nonmonotonic order, measured0, survivors and unknown ownership
reject individually. Integers and integral JSON floats are accepted where Godot
JSON uses doubles; booleans cannot substitute for numeric fields. Optional error
strings may be absent/null/empty; populated errors contradict success regardless
of the summary booleans. Innocuous extra receipt fields are not forbidden.

The supervisor checks its own final success receipt with the same predicate.
Clean release never overrides rejected native evidence. Each group remains a
separate manual invocation; hash binding and no-retry/no-autostart policies stay
in force.

## Verification and provenance

The original26 tests now use complete serialized operand fixtures rather than
bare pass summaries. Twelve additional tests exercise canonical substitutions,
empty/missing traces, clocks, outcomes, profile radius/yaw, negative witnesses,
paired states, fake lift/guard claims, target/support/arrival conditions and
independent supervisor contradictions. Two regressions use the real mocked-child
supervisor and file-based dependency path for the exact duplicated34-row attack
and a valid census with empty traces. The tests contain synthetic data only, not
native evidence or an authorization artifact.

GDScript parity tests are explicitly **structural**, checking shared frozen
registries, predicate functions/fields and actual call paths. New GDScript is
unparsed/unrun; these checks are not a runtime equivalence proof. A future
authorized native review must still establish parser and runtime behavior.

`review-pins.json` seals the current16-script closure and current host helpers.
`source-provenance.json` is retained byte-for-byte as the historical8de9d63a
report, including its historical test count and hashes. The additive
`p1-correction-receipt.json` records this correction's checks and current seals.
Candidate application/snapshot/up-contact methods, original guard/planners,
production Walker, frozen fixtures, prior phases, archives and all15 production
dependencies are unchanged. No engine/import/render/server/native attempt stage,
actual child job, grant or queue was created. Repeated native positivity remains
unknown, and no map or production acceptance is claimed.
