# AE — inclined checkpoint passed; positive admission FAILED at first endpoint guard

**Fresh inclined rejection passed4/4 pairs. Positive-step admission failed its
first pair (`.35`, −45°) with `endpoint_differs_from_proof`. Three positive pairs
remain unrun. No map walks ran.** Grant AE is released.

New isolated branch `astra/walker-admission-ae` from parent `5e0b373d`, attempt
`admission-ae-01`, grant `MOTH-BLENDER-20261004-AE`. Existing lowercase namespace
validation was used unchanged. No production, fixture, driver, candidate,
response-guard, API or tolerance edit occurred. No parser errors, retries or
imports occurred. Read-only checkpoint/failure tools are separate commit
**`4ede40dc`**; raw traces and evidence are delivered separately.

## Actual execution and delegated checkpoint

Godot4.5.2 official `6ce3de25a`, headless, LP_NUM_THREADS=1 / OMP_NUM_THREADS=1.
Each manually selected invocation used the reviewed `run_group.py` supervisor,
nonwaiting shared lock,180s outer bound and170s internal deadline. The exclusive
grant covered the gap for evidence review. No outer nested lock or automatic
batch execution was used. Synthetic fixtures required **zero import jobs**.

| Group | Start UTC | Duration | Exit | PGID / startTicks |
|---|---|---:|---:|---|
| inclined-landing-rejections | 01:35:47.831712 | 20.820s | 0 | 2011504 / 626089179 |
| positive-step-admission | 01:37:29.867997 | 4.087s | **1** | 2017672 / 626099383 |

The same sealed AE grant and source receipt were used for both invocations:

- Grant SHA256 `7bf49c2ab3ecb5e1178dbcd1b6d2414a7d19b13567642eccdefb2882bf719a93`.
- Source SHA256 `3250c5bc6b967a63ea9ccbf62e50f2ed725b628ff75ee5dd5f7d107b1989e2f4`.
- Phase `admission-controls-only-v4`; allowedGroups exactly the two rows above.
  No legacy or continuation fields, map/reference/sprint permissions.

After the inclined invocation returned, its log and JSON were inspected, then
the unchanged AD physical/count/clock/shape/response assertions were replayed
against the **new AE trace**. Adaptations changed only the input/output routing
and the expected grant metadata from AD's one group to AE's two groups. No
physical check or tolerance changed. `evidence/inclined-checkpoint.json`, sealed
at **01:37:06.043286Z**, records this review before the positive start.

Checkpoint evidence:

- 4 passed pairs /8 completed profiles,1,012 input responses +160 settles.
- 960 exact `no_continuous_flat_landing` target shape0 low-band/head-on witnesses;
  all profiles ended with120 stalled responses.
- Native47° geometry, numeric body/capsule RIDs and2,108 numeric slide contacts.
- No accepted proposal, applied lift, fault or extra reset. Actual consecutive
 60Hz responses, timeScale1. Compared baseline/candidate input, position,
  velocity, ground and displacement fields agreed exactly.
- Log contained only the engine banner. AB140 lineage and actual AE grant/source
  identities verified. Positive result did not yet exist at checkpoint time.

The original AD grant, results and45-file inventory were not used as an AE
predecessor or modified. Original AB JSON lineage copies remain labelled AB.

## Positive attempt: precise failure and truthful partial counts

Planned4 pairs /8 profiles. Actual:

- Attempted1 pair; passed0; failed1; **unrun3 pairs /6 profiles**.
- Baseline `.35`, −45° completed its expected blocked control:127 responses,
  120 stalled responses. It did not reach the target.
- Candidate of that pair stopped on response8 (native physics frame176).
  Candidate profile failed mid-run; no successful candidate profile or landing.
- Total135 input responses +40 settling responses. Both profiles settled
  normally and retained initial resetCount1. Clocks were consecutive60Hz.
- One proposal was accepted and its **UP sweep was physically applied and
  checked against the raised proof**. The later response guard failed.
  `appliedVerifiedLifts:0` counts fully guard-verified lifts; it does **not** mean
  that no upward movement was applied. There was1 applied up sweep and0 fully
  verified lifts.

The raw receipt remains `failed:true`, `failedTrials:1`,
`status:"native_candidate_or_reset_fault"`, `nativeStepAdmission:false`,
`productionPromotion:false`. The specific candidate fault is
**`endpoint_differs_from_proof`**, not a reset.

### Endpoint comparison

| Quantity | Value |
|---|---|
| Before | `[.212131947278976, .0166666638106108, -.212131947278976]` |
| Raised proof origin | `[.212131947278976, .172130957245827, -.212131947278976]` |
| Expected final | `[.141421258449554, .0877778008580208, -.141421258449554]` |
| Actual final | `[.141421258449554, .0877559557557106, -.141421258449554]` |
| Actual minus expected | `[0, -.0000218451023101945, 0]` |
| Active endpoint budget | **.000001m =1µm** |
| Error / budget | **21.8451023×** |
| Parent slide records | **0** |

X/Z agree exactly. The Y discrepancy is **21.845µm**, not a centimetre-scale
path excursion; it nevertheless exceeds the unchanged reviewed1µm budget and
is a genuine diagnostic failure. No tolerance was widened to admit it.

The recorded parent last-motion vector is
`[-.070710688829422,0,.070710688829422]`, versus planned horizontal budget
`[-.0707106813788414,0,.0707106813788414]`. It is retained as an observation;
the guard returned at the earlier endpoint check and did not complete its later
vector/final-support checks.

### Query evidence and support boundary

UP and raised FORWARD queries returned clear. DOWN returned a finite-capsule
hit on `PositiveTread`, collider shape0 / local capsule shape0, with normal
`[.404189735651016,.820524990558624,-.404189735651016]`.
Planned support RID was **104372000260098**, matching the fixture's target RID.

- Requested UP motionY: .153433352708817.
- Returned/applied UP travelY: approximately .155464291572571, including bounded
  original-margin recovery.
- Planned DOWN motionY: **−.175564289093018**, max_collisions32.
- Planned DOWN safe fraction: .48046875; travelY **−.0843531563878059**.
- Observed parent downward displacement from raised origin:
  **−.0843750014901164**.
- Unchanged parent floor_snap_length: **.300000011920929**.

The pinned Godot4.5.2 `CharacterBody3D::apply_floor_snap` source uses
`max(floor_snap_length,margin)` and max_collisions4. Therefore the planner's
shorter downward lookahead and the parent's actual snap request are **not the
same query**. This is a concrete source difference consistent with the differing
endpoints. This run does not isolate the exact contributions of contact search,
recovery or numerical discretization; no unique backend root cause is claimed.

**Actual final finite-capsule support identity was not verified:** the response
guard returned before its live support query. `is_on_floor` was true, but that
does not establish its collider identity. The ordinary centre ray hit
`AdmissionBaseFloor`; that ray is not proof of the capsule's rounded-edge
support and must not be substituted for the missing final capsule query.

### Whole-frame versus parent accounting

Recorded whole-frame displacement:
`[-.070710688829422, +.0710892900824547, +.070710688829422]`.

Recorded parent position-delta:
`[-.070710688829422, -.0843750014901161, +.070710688829422]`.

Recorded parent real velocity:
`[-4.24264097213745, -5.0625, +4.24264097213745]`.

Ordinary velocity after movement was
`[-4.24264049530029,0,+4.24264049530029]`; grounded was true. The difference
between whole-frame and parent-only Y accounting contains the pre-lift. These
native readings are preserved, not manually overwritten. The known production
accounting blocker remains open.

## Scope, preservation and release

The new positive run demonstrates a successful lookahead/up-application followed
by a **failed post-response endpoint check**, not successful positive admission.
No later candidate/positive case, `.42` positive baseline, reference or map group
was run. All60 candidate map walks remain unrun. Original184 static failures
and production promotion remain separate. Any remedy requires a future reviewed
source task; AE supplies no retry or geometry/guard-change authorization.

Verified unchanged: **AB140, Z253, X600, U264, AA141, AC265, AD45**, all15
production dependencies and every parent-tracked byte. All1,651 preexisting
sidecars remained identical; no new sidecars or cleanup. Viewer
PID2598700 / PGID2598689 / startTicks522477875 and recorded displays unchanged.
Source/dependency snapshots include unchanged JS files solely as pinned
dependencies; no JS movement execution is claimed by this native experiment.

Three final empty audits covered **both owned groups**:

- `2026-10-04T01:38:06.667173Z`
- `2026-10-04T01:38:06.909830Z`
- `2026-10-04T01:38:07.149985Z`

**AE released `2026-10-04T01:38:07.391307Z`; lock available
`01:38:07.391380Z`.** No engine invocation after release, no queued heavy work.
Post-run source checks:7 admission +32 existing Python tests passed. The raw
failed trace is preserved in full along with the checkpoint, supervisor
receipts/logs, exact grant/source identities and read-only analyses.
