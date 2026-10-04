# Single parity response — separately sealed source proposal

Branch `astra/walker-parity-response`, parent `278f9dd2`. **Source only. No grant,
native stage, parsing/import, engine, render, server, subagent or queued work.**
The new GDScript remains unparsed/unrun and awaits independent source review.
AF's phase, driver, nine-script closure, grants and evidence remain immutable.

## Exact proposed scope

New namespace `walker_parity_response`; phase `parity-response-only-v1`, mode
`single-response`, singleton group `parity-response`. A separately reviewed and
issued grant is required. AF authorization does not transfer to this phase.

Use unchanged `.35` radius, −45° yaw, .15m flat synthetic fixture from
`walker_admission/fixtures_v4.gd`:20 settling frames, at most40 input frames.
Stop at the **first eligible original proof**. At most one physical UP call and
one subsequent ordinary parent response may execute. Never run to a goal,
attempt a second lift, expand profiles/geometry, or invoke positive/map/reference
groups. All60 candidate map journeys remain unrun.

One body is instantiated, only after phase/mode/source/grant validation: the new
instrumented candidate derived directly from original Walker. Before the trigger,
`ordinary_step` calls **unchanged Walker.step**, without candidate planning or
application. Original eligibility probes are read-only. No second baseline body,
body replacement, latent controller or competing physics process is created.
The driver disables automatic physics processing and owns consecutive60Hz steps.
After the first trigger it always finishes, including parity-policy rejection.

## Source proof and factory review

1. Driver obtains a read-only original proposal and checks exact actual body
   state before/after it. Ineligible frames get one ordinary parent response.
2. First eligibility calls new candidate.step once. It recomputes a live proposal
   through the frozen `walker_snap_parity/planner.gd`, which first demands the
   **complete original UP/FORWARD/DOWN clearance and support proof**. Original
   rejection cannot become acceptance through a parity fallback.
3. Frozen parity planner adds live modeled forward6 (recovery=true, rays=false)
   and full snap4 (recovery=true, rays=true). Forward must be clear/equivalent;
   full snap must hit, be unsaturated, and every contact must match the original
   certified static target RID/shape/local index, landing plane and strict46°
   normal. Unexpected contacts are rejected, never filtered to a desired corner.
4. Parent snap processing uses UP projection only if raw travel length exceeds
   margin, otherwise zero. Nonpositive/excessive drop, lateral recovery and net
   rise outside the original cap are rejected. Expected final comes from **live
   query travel**, not any cached AF/AE coordinate. GDScript Vector3 operations
   retain the pinned float32 arithmetic; no new epsilon or angle allowance.
5. New planner wrapper further requires modeled forward travel **exactly equal
   to motion** and no contacts. The raw query does not execute the parent's
   cancellation wrapper. Even with no backend-reported recovery, normalization
   and projection can introduce roundoff. The request is explicitly labeled
   `cancellationWrapperExecuted:false`; actual response must pass the guard.
6. New candidate preserves accepted-path ordering from the WIP candidate:
   numeric-budget check → physical UP `move_and_collide` once → actual raised
   pose/collision check → one original Walker.step → **unchanged original
   response_guard.gd** → all original candidate postconditions. Any fault stops;
   no rollback, pose correction, velocity rewriting or tolerance widening.

The only intentional application-path difference on rejection is termination:
the frozen WIP candidate would call an ordinary parent step after planner
rejection; this bounded driver records that rejection and stops without spending
an additional response. Accepted-path movement calls and postconditions remain
the same. The wrapper adds the stricter exact-forward condition above.

### Known limitations remain

AF showed clear forward6 and a full4 projected endpoint matching AE's historical
actual endpoint at float32. Short32 matched AE's original predicted endpoint;
the original body pre-query pose matched AE pre-lift. AF's actual baseline had
zero net movement, with nonzero lastMotion retained separately. This supports
request-policy mismatch as plausible; length and contact capacity changed
together and no internal parent call was traced. It is not unique causation.

The actual applied UP pose may differ from the modeled raised pose within the
unchanged guard budget. That can still make subsequent results differ. In
particular, the live final-support query may hit another shape or return a
contact off the certified plane; that must remain a failure. A below-tread foot
can be rounded-edge support, not a full-tread landing. No outcome of this single
response qualifies completed positive admission.

The original guard performs endpoint/path checks before its final support query.
Receipts mark whether that query was reached; missing support is never inferred
from is_on_floor or another ray. Parent get_position_delta/get_real_velocity omit
the pre-lift. Telemetry preserves them alongside actual UP and whole-frame delta;
that production accounting limitation is not corrected here.

## Telemetry and terminal outcomes

Receipt fields are independent: `candidateResponseCollected`,
`responseGuardPassed`, `candidateAttempts`, `appliedUpCount`,
`parentResponseCount`, `positiveAdmission:false`, `nativeStepAdmission:false`.
Parent count refers to the candidate attempt, excluding prior ordinary frames.
Applied-UP count counts actual move calls even if faulted/zero travel; it is not
a verified-lift counter. Policy rejection is a collected attempt with zero UP
and false guard result. Post-guard candidate failure can retain guardPassed=true
but must still have failed=true. `experiment-plan.json` specifies each outcome.

Each frame records actual state/clock/input and original proof. The trigger
additionally records both proposal sets, actual before/after-planning state,
actual UP before/after transform and travel, requested UP parameters, hypothetical
raised/edge origins, raw query travel/fractions/contacts, body/shape RIDs,
dimensions/offset, mask/layer, and actual parent/guard state. Kinematic collision
telemetry uses Godot4.5.2 `get_collider_shape_index` and loops over every subcontact.
KinematicCollision3D does not expose query safe/unsafe fractions; those are
available for the read-only PhysicsServer queries, not invented for the physical
UP result. Motion depth is labeled separately from per-contact normals/points.
Final-support RID telemetry is resolved from the guard's recorded collider IDs,
without a second support query or alteration to guard decisions.

Configured physics-engine setting is recorded as returned; `DEFAULT` does not
identify a backend. Modeled parent requests are not internal move_and_slide traces.

## Separate preparation, pins and bounded supervisor

Future `prepare.py` requires an explicit frozen AF root and verifies all24 files
against the manifest pinned to `b80273a7`. It verifies all15 production pins,
all13 staged script dependencies, host preparation/policy/supervisor hashes and
the minimal project recipe before writing once. Namespace is lowercase
`parity-response-…`, max64 characters; symlinks, escape paths and existing attempts
reject. No AF witness or expected endpoint is staged. No world GLBs, autoloads,
game scenes, engines, grants or launch jobs are copied/created.

The grant schema remains exactly phase/mode/allowedGroups/grantId/authorized/
expiresUnix/sourceSha256/engineSha256. Unknown/missing fields, duplicate group
entries, wrong phase/mode, hash drift and expired/nonfinite expiry reject in
Python and GDScript. Python rejects duplicate JSON keys; GDScript relies on the
supervisor's validated JSON because its parser cannot detect duplicate keys.
CLI duplicates, abbreviations, unknown modes and debug/simulation flags reject.
Unit-only injected roots/pins are not CLI overrides.

The new supervisor is an isolated source copy of corrected AF lifecycle code.
Old AF files are not modified or monkey-patched. Its semantic changes are:
new namespace/phase/group/driver, AF24 lineage replacing AE46 at preparation,
new response receipt/strict one-UP-one-parent-one-guard success predicate, and a
post-exit log scan to catch a script error that occurs before the polling loop.
PID/PGID/startTicks helpers and release auditing are AST-identical to corrected
AF source and retain the existing deadline/nonwaiting-lock/race tests.

Explicit nonsymlink binary/hash required; no PATH fallback or version-probe
launch. Nonwaiting `/tmp/opencode/cocs-finish-acceptance.lock`, one new owned
process group, thread1 defaults,170s internal/180s external execution bounds.
Only owned identities may be signaled. ESRCH still requires three actual empty
audits; permissions/reuse/unknown audits/survivors fail. Handler restoration and
best-effort receipt writing survive cleanup errors. Empty cleanup never overrides
a failed native outcome. No retry or automatic continuation exists.

## Verification boundary

Portable Python tests execute strict policy/preparation against disposable
synthetic24-file fixtures and supervisor control flow with mocked children and
signals. They cover deadline, held lock, ESRCH race, permission/survivor/audit/reuse
failures, receipt-write failure, fast-exit script errors, source/manifest drift,
namespace/CLI rejection, receipt semantics,13-versus9 closure, exact original
guard postconditions, official numeric shape API, and AF float32/AE failed-guard
counterexamples (including4cm vector and wrong-support cases).

No actual native preparation or engine invocation is performed by these tests.
Python/source tests cannot establish GDScript parsing, runtime correctness or
native response success. Independent source review precedes any separate native
grant; any future evidence requires another review before further work.
