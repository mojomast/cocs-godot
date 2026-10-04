# Bounded synthetic parity admission — source proposal

Fresh branch `astra/walker-parity-admission` from `5ac4dcb3`. **Source only: no
engine, parser/import, rendering, native attempt staging, server, child job,
grant or automatic launch.** New GDScript remains unparsed/unrun. AG established
one completed guarded response only; repeated positivity and the full synthetic
matrix remain unknown and may fail early. Parent independent review precedes any
new heavy grant. All60 candidate map journeys remain unrun.

## Separate phase and manual sequence

Phase `parity-admission-synthetic-v1`, mode `synthetic-controls`, only:

| Ordered group | Matrix | Native profiles |
|---|---|---:|
| `negative-controls` | AB17 fixtures ×2 radii =34 pairs |68 |
| `inclined-landing-rejections` | AD47° slope, ±45° yaw ×2 radii =4 pairs |8 |
| `positive-step-admission` | AE.15m flat step, ±45° yaw ×2 radii =4 pairs |8 |

Each group is one **separate manual supervisor invocation** under the same sealed
source/grant/binary bindings. No code queues or invokes the next group. Allowed
groups may be a canonical nonempty subset. Negative-only authorization does not
authorize later groups; a newly issued grant/source cannot reuse passes under
old hashes, so fresh prerequisite runs may be required.

Before each later group, both Python and GDScript require every earlier group's
native result to be passed/failed=false, complete exact pair/profile counts,
no failed/interrupted/unrun entries, correct roles and bound phase/source/grant/
engine hashes. Its supervisor must also be successful, bind the native receipt
hash, and show three measured empty release audits. A write-once per-invocation
dependency receipt seals native and supervisor hashes; its hash is passed to
Godot and recorded in the current result. Historical AB/AD/AE/AF/AG receipts do
not substitute for these new-controller runs. No map/reference/sprint/continuation
mode or permissive debug override exists.

## Frozen geometry and controls

Runtime directly preloads the unchanged `controls_v2.gd` and `fixtures_v4.gd`.
AB's overhang frontZ.08, all17 mechanisms and original allowed rejection reasons
are retained. Airborne uses its original one settling frame; the other negative
profiles use20. The jumping fixture retains its intentional single jump launch;
this does not add a jumping/sprinting admission mode.

AD/AE profiles retain20 settles, max240 input responses and120-stall stop. The
actual frozen v4 goal is **localZ1.0**, not1.5. No geometry or goal is changed:
the tread spans X[-2,2], Z[0,3], so the goal already has ample clearance for both
.35 and.42 radii plus existing.02 margin. Rotated geometry remains world-baked,
with identity collider transforms. Native shape data, transforms, RIDs and static
body velocities are recorded for each freshly constructed fixture.

## Repeated-response controller lifecycle

One continuous body per profile; no respawn or replacement midway. Baseline
factory constructs the original Walker, candidate factory the new adapter. Each
profile receives one initial set_spawn; resetCount must remain1. All physics
responses must be consecutive60Hz/timeScale1 with actual delta1/60.

The adapter extends original Walker directly. Its `apply_single_response`,
`state` and `up_contacts` bodies are exact source copies of AG's approved methods;
tests compare them verbatim (only the application method name changes). Planner
binding points to the **unchanged AG planner**, which retains complete original
clearance proof, exact-clear modeled forward6, certified full4 support/projection,
unchanged response guard/epsilon and original postconditions. No planner change
is proposed. Direct Walker inheritance permits the frozen AB jump control to
call the actual original Walker.step, rather than copying movement equations or
using AG's ordinary helper, which fixes jump=false.

For each response:

1. Reject duplicate physics-frame calls or any call after a sticky fault.
2. Reset only per-response instrumentation, never pose/velocity/floor state or
   cumulative counters. Run the original proof read-only and compare state.
3. Original rejection calls **original Walker.step once**, with recorded intent.
   Negative witnesses must match their frozen fixture's exact reasons. Negative
   and inclined groups reject any original eligibility before any assist.
4. Positive original eligibility must certify the fixed tread RID/shape0/plane
   and have remaining profile lift budget. Then execute AG's exact single-response
   method: fresh parity queries → at most one physical UP → actual raised-pose
   check → one original parent response → unchanged guard/postconditions.
5. A parity-policy rejection after original eligibility is terminal failure,
   with zero UP/parent calls for that attempted response. It does not freeze and
   continue, fall back to an old assist, silently ordinary-step, or fake a pass.
6. Recheck the returned parity certificate against the fixed target. A changed
   certificate or any guard/postcondition/height fault stops without rollback.
   No attempt is made to select a desired contact from an unexpected support set.

The profile lift budget is `ceil(2*radius / (6/60)) + 2`: **9** calls for.35,
**11** for.42. A guarded assist proves a full.1m forward vector; a capsule-diameter
edge-contact interval therefore spans at most7/9 such nominal advances, with two
boundary responses reserved. This is a conservative diagnostic failure bound,
not proof that every physical profile will succeed within it. Exceeding it fails;
it never changes speed, geometry or solver tolerances.

All positive grounded post-response poses, including ordinary responses, are
capped at the fixed tread plane +existing safe margin+.0001 (the original v4
arrival allowance). The intermediate raised pose may be higher: AG's raisedY
.17213 must not be wrongly rejected by a post-response cap. Sum of UP travel can
exceed net rise because each parent snap descends; cumulative UP is not capped as
if it were net height. Every individual assist retains the original proof caps.

Counters distinguish per-frame attempts/applied calls/parent calls/guard result
from cumulative attempts/applied/fully verified lifts. A verified lift requires
the guard, candidate postconditions and phase certificate/height checks all to
pass. Physical-call counters increment after return; script/native fatality can
make partial/default counts unknown. Inflight snapshots are retained. The
independent `audit.py` ledger checker applies only to completed error-free traces;
it cannot prove physics or infer absence of calls after a fatality.

## Group outcomes and full-tread arrival

AB compares baseline/candidate ordinary position, velocity and grounded flag
within unchanged numeric budget across settling, optional jump and test
responses, and requires the exact frozen mechanism at the final probe. AD retains
the physical low-band head-on47° intent-contact witness, allowed reasons,120
stalls and paired ordinary-response comparison. No new parity fallback may mask
an unexpected original admission in either negative group.

For each positive pair, the baseline must actually remain blocked with120 stalls.
If the .42 capsule natively rounds the riser and arrives, that is a legitimate
**unexpected-baseline failure**, not permission to modify the fixture or force a
blocked classification. Candidate success requires:

- At least one applied lift fully verified, with every attempted accepted
  response and every postcondition passing; applied count equals verified count.
- Arrival at unchanged localZ1, grounded and within existing height allowance.
- Entire horizontal radius+margin footprint inside the frozen4×3 tread rectangle.
- At least three consecutive ordinary grounded input responses in that
  full-footprint/height region, not merely another edge-supported assist.
- A fresh read-only capsule support query at arrival, state unchanged across it,
  with every contact on the same static tread RID/shape0/local0, strict46° normal,
  and certified plane within the unchanged response numeric budget. Returned query
  travel is recorded but never applied. Base floor or another support cannot pass.

`positiveAdmission:true` is emitted only after all4 positive pairs and successful
bound prior groups, always with `scope:"synthetic-admission"`.
`nativeStepAdmission:false`, `productionPromotion:false`, `candidateMapWalks:0`
remain invariant. A single guard pass is not a completed profile/pair/group.

Completed pair/profile counters include normally terminated failures; passed and
failed counts are separate. Interrupted entries are separate from completed, and
never-started entries remain unrun. A pair comparison can fail after both profiles
completed. Any fault stops the group and preserves completed, failed, inflight and
unrun records. A missing/partial native file or script error makes supervisor
failure explicit; clean process release cannot override that failure.

## Telemetry and retained limits

Records preserve actual pre/post body state, whole-frame delta, parent position
delta/real velocity, original and parity proofs, actual UP poses/travel, all
modeled query origins/parameters/fractions, numeric shape indices and slide
subcontacts, response guard/fresh support results, cumulative/per-frame counters,
frame and microsecond timestamps. Existing numeric slide telemetry is reused.
Model queries remain hypothetical; cancellation wrapper/internal parent calls
are not observed. `DEFAULT` is a configured value, not a backend identification.

AG's one passing endpoint and support query do not establish later frames. A
subsequent full4 query or actual guard support may fail or select another target;
that must remain failure. Whole-frame/pre-lift/parent accounting stays separate.
Original get_position_delta/get_real_velocity still omit the pre-lift from the
later parent response: the production reporting blocker remains unchanged.

## Preparation and host lifecycle

Future write-once `parity-admission-…` preparation requires explicit frozen AG29
(`362803a8`) and AF24 (`b80273a7`) roots and verifies every hash/size. It verifies
all15 production dependencies, all15 staged script inputs, new host code and
pinned reused AG host modules before writing. Minimal scripts/project only: no
world GLBs, autoloads, engine copies, grants, queue or launch jobs. Symlinks,
noncanonical/uppercase namespaces, existing attempts and unknown staged files
reject. Source receipt binds all hashes and has `grant:null`, `autoStart:false`,
`queueIdentity:null`, `queued:false`.

`frozen.py` imports AG file/hash and ownership helpers in isolated module
namespaces, temporarily restoring standard import names afterwards and disabling
bytecode writes while loading old modules. It never edits old files or calls old
main/build/phase validation. New host pins include those reused sources. Owned
PID/PGID/startTicks checks, ESRCH race handling and three fresh release audits are
the exact approved helper functions. The new orchestration uses group-specific
write-once filenames, predecessor seals and synthetic outcome checks.

Each future invocation requires an explicit absolute nonsymlink binary, matching
source/engine/grant hashes, finite expiry, canonical allowed subset and exact
schema. Duplicate JSON keys are rejected by Python; GDScript consumes the
supervisor-validated sealed files and repeats phase/count/hash predicates. CLI
duplicates, abbreviations, unknown arguments and bypass flags reject.
Nonwaiting `/tmp/opencode/cocs-finish-acceptance.lock`, thread1 defaults,170/180s
internal/external bounds, final fast-exit error-log scan, ownership-only cleanup,
handler restoration and best-effort receipt handling remain. Lock is held through
receipt writing. Permission errors, unknown audits, survivors, reused identity or
receipt-write failure cannot become success. No automatic next-group action.

## Source verification

Portable tests cover actual preparation against temporary synthetic29/24-file
inventories, source/lineage tamper and symlink rejection, grant/CLI/schema and
partial predecessor rejection, lifecycle sequence/cumulative budgets, exact AG
application copy, frozen guards/planners/fixtures, real goal footprint clearance,
old endpoint4cm/wrong-support counterexamples and all cleanup/deadline/lock/error
regressions with mocked child creation/signals. No runnable native attempt was
staged. These tests do not parse GDScript or establish repeated native success.

Historical AG29/AF24/AE46/AD45/AB140/Z253/X600/U264/AA141/AC265 and all prior
source/evidence phases remain immutable. Source provenance records preservation
and current seals. Independent source review is the next prerequisite; no heavy
authorization is requested implicitly by providing this package.
