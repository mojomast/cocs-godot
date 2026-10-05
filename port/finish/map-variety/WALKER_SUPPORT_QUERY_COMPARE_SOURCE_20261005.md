# Bounded Walker support-query comparison — source-only implementation

Branch `spacebunny/walker-support-query-20261005`, base `feature/relay-campaign`
`91b0b801`. Implements the approved design
`map-variety/WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md` (integrated as `d008a28b`,
parent `721bddd5`) as a deterministic offline Python package.

**No native claim. No grant. No engine invocation. AM stays failed, .42/+45°
stays unrun, and 60 map journeys / 184 static failures / production accounting are
untouched.**

## What was implemented

A single new source package,
`tools/godot-multiplayer/new-maps/walker-support-query-compare/`, containing the
five artefacts the design called for — bounded driver, observational hook, seals,
validator, supervisor — plus the supporting policy, history, composition and
invocation-audit modules.

### The bounded sequence

Two fixed finite-motion cases and only two: `.35/.15/−45°`
(`reference-035-015-neg45`) and `.42/.18/−45°` (`failure-042-018-neg45`). At the
first eligible transition of each, `driver.BoundedDriver.run_case` walks a
six-state machine (`planned → pre_up_observed → candidate_responded →
guard_observed → duplicate_observed → stopped`) that permits only forward
transitions and refuses everything else:

1. down32 at the live plan's predicted endpoint, **before** the UP step;
2. exactly one unchanged candidate response and guard;
3. the guard's own actual-final-state down32, recorded verbatim as primary;
4. the predetermined duplicate down32 at that same actual final state;
5. terminal stop.

The live call order is asserted from outside the driver, not just from its own
event log: `FakeLive.orders()` must read
`[test_motion:pre-up-predicted-endpoint-support, candidate_response,
test_motion:duplicate-actual-final-support]`, and `candidate_calls == 1`.

### Zero-motion omission

`hook.omission` is the only way to record a skipped observation. It requires the
requested motion to be **exactly** zero via `hook.exact_zero` (stricter than
Godot's approximate `is_zero_approx`, which would otherwise let a small nonzero
motion be filed as an omission), refuses any `substituted_motion`, and
recognizes only `OMISSION_REASON`. Both design zero-motion observations
(ordinals 2 and 5) are recorded as omitted with `executed: false` and
`substitutedMotion: null`. Tests reject epsilon attempts at −1e−9, −0.0001 and
−1e−15, and a fake that answers a duplicate with zero motion is refused by the
driver.

### Predetermination

`hook.frozen_operands` freezes motion, margin, max contacts,
recovery-as-collision, separation-ray, body RID, exclusions and test-only before
anything executes. The duplicate's pose cannot be predetermined — the actual
final state is by definition known only after the candidate response — so it is
taken verbatim from the guard's own recorded request and never chosen.

**The frozen constants are recorded as one explicit tuple and checked against all
three executed requests.** That is what makes the duplicate a duplicate rather than
a re-tuned request, and it is now enforced rather than asserted:

* `history.reference` derives `amFrozenOperands` per case from the AM guard's own
  recorded request in the SHA256-pinned export, so the anchor is read, not retyped;
* `prepare.contract` seals the same per-case table in the prepared record, before
  execution;
* the driver refuses to run at all if the live plan's frozen operands differ from
  that table, and records the tuple it froze in each case record;
* `campaign.compose` carries that tuple into the receipt per case.

`evidence._frozen_operands` then requires: the recorded tuple is well formed
(`hook.frozen_tuple`); it is anchored, in that its design-frozen constants equal
the pinned AM guard's and its body RID equals the record's own AM binding; and the
pre-UP request, the guard's own recorded request and the duplicate request each
carry exactly that tuple on every constant *and* agree with each other pairwise
(`hook.operands_unchanged`, which performs both comparisons so the guarantee does
not rest on the tuple anchor alone).

How each constant is pinned is enumerated, and the three groups partition
`CONSTANTS` exactly: design-frozen (margin, contact cap, the two flags, exclusions,
test-only) from reviewed source and the pinned AM request; derived (motion) from
the frozen margin — the AM request records a *float32 rounding* of the derivation,
`-0.0200999993830919` against `-0.0200999995529652`, so the anchor derives motion
rather than copying it; and run-frozen (body RID) by being identical across all
three requests, since a RID is assigned per run and cannot be compared with the AM
value.

`FrozenOperandTests` reproduces the independent review's six re-tunings as negative
cases with `recordsSha256` **re-derived by the forger**, so only a structural
predicate can act: guard margin, guard motion, guard bodyRid, duplicate margin,
duplicate bodyRid and pre-UP bodyRid are all refused, as is a *consistent* re-tune
of all three requests together with the recorded tuple, the record's AM binding and
the receipt's per-case table. The driver refuses the same re-tunes on the live side
of the boundary, before any duplicate is issued.

`OPERAND_EPSILON` is 1e−12, six orders of magnitude below the 1 µm guard budget, and
exists only for double round-tripping. `DERIVED_MOTION_EPSILON` is 1e−9 and is used
for exactly one thing: comparing a *recorded engine* motion against the derivation,
because the guard computes it in float32. It is a thousand times a double epsilon
and a million times below the guard's own numeric budget, so it cannot absorb a
re-tuned motion.

**What this does not claim.** The validator cannot prove from a self-attested record
that the recorded tuple is the tuple the driver froze; that is the prepared source
record's role, bound by the receipt's `sourceSha256`. What it does prove is that the
three executed requests agree with each other and with one operand set anchored to
the SHA256-pinned AM history.

### Predicted endpoint

`predictedEndpoint = raised.origin + horizontalBudget`, matching
`response_guard.gd:29`. Because `apply_floor_snap` projects Y only, its height
legitimately differs from `expectedFinal`, so the contract requires **horizontal**
agreement within the guard's epsilon and records
`verticalOffsetFromPredictedEndpoint` explicitly. A test asserts the recorded
offset equals `expectedFinal.y − predictedEndpoint.y` and that a hidden horizontal
or vertical disagreement is rejected.

### Guard preservation and reported divergence

The guard's `passed`, `reason` and `candidateFault` are recorded exactly as
returned, with `preservedIntact: true`. `history.agree` compares only the guard's
*decision*, deliberately not observed normals — treating a differing normal as a
divergence would report the measurement's finding as a contract violation.
Divergence surfaces in `history.agreesWithHistory`, `unexpectedOutcome` (with
the historical value kept beside the observed one) and the receipt's
`unexpectedChangedOutcomes`. Tests cover a single divergent case not relabelling
the other, a receipt that reports divergence while claiming agreement being
rejected, and a divergence claim being rejected when absent.

### Fail-closed validation

`evidence.receipt` returns a boolean and swallows malformed input, so a validator
call can never become a pass via an exception. It checks: exact schemas; hash
bindings; every counter (`candidateResponses`/`appliedUpCount`/
`parentResponseCount` == 1; `retries`/`normalSelections`/
`acceptanceSubstitutions`/`subsequentMovementResponses` == 0); the five-event log;
per-observation ordinals `[1, 3, 4]` and `recordedBeforeUpStep`/`issuedAfterUpStep`
consistency; the guard observation being the guard's own request by object
identity rather than a reissue; the duplicate being at exactly the guard's pose;
both omission records; guard/history consistency; and all negative-authority
fields.

`recordsSha256` closes the gap the per-field predicates leave open: it binds
every recorded byte of both cases, including fields whose value is legitimately
free, so editing an observed normal is detected. Canonical sorted-key,
no-insignificant-whitespace, `allow_nan=False` JSON.

### Write-once seals

`seals.write_once` uses exclusive create. `prepare.build` writes a deterministic
source record plus a `seal-manifest.json` binding it by size and SHA256.
`validate_record` re-verifies the seals, then compares the record against a
recomputed `contract()` and names the first differing top-level key.
`supervisor.refuse` is also write-once. Refusing to place a record under `godot/`
is enforced by `_reject_engine_tree`.

### The supervisor refuses

`supervisor.preflight` performs the complete fail-closed preflight a real
supervisor would perform — namespace, record contract, seals, six frozen source
references plus the approved design review, AM history, grant schema, hash
binding, expiry — and then `refuse` writes a sealed, write-once record of why the
campaign cannot run. `{engine}` and `{fixture}` argv slots stay literal, and a
positive check fails the build if either is ever resolved.

`invocation.audit` parses every module and walks the AST, so "no engine
invocation" is a verified property rather than a promise. It refuses
`subprocess`/`multiprocessing`/`shutil`/`pty`/`popen2`/`commands` imports, the
`os` execution surface (`system`, `popen`, `execl*`, `execv*`, `fork`, `spawn*`,
`posix_spawn*`), launch methods on spawning owners, and any `shell=` keyword.
Launch attributes are matched only against a known spawning owner, so an
unrelated local `.run` is not a false positive, while prose merely *mentioning*
`subprocess` does not trip it. A test feeds the auditor thirteen real engine-path
snippets (`import subprocess; subprocess.run(...)`, `os.system`, `os.execv`,
`os.spawnv`, `os.fork`, `from os import system`, `shell=True`, …) and requires
every one to be caught.

### Frozen history

`history.reference` derives the AM reference from the approved diagnosis export
`comparison.json` (pinned by SHA256 and size, plus its source receipt
`25382b4d…`, matching the review's recorded identity) rather than retyping
numbers, so drift is a pin failure instead of a silent re-baseline. It re-asserts
`backendImplementationVerified is False`, `physicalCallCounts is None` and that
`preflightAtPredictedEndpointRecorded` is False — the gap this campaign fills.

## Files

| Path | Lines | Role |
|---|---:|---|
| `tools/…/walker-support-query-compare/README.md` | 196 | purpose, boundaries, how to run |
| `…/__init__.py` | 6 | importing grants no authority |
| `…/cli.py` | 34 | isolated hashed package loader, single-operation CLI |
| `…/policy.py` | 161 | phase/case allowlist, canonical cases, schemas, grant validation |
| `…/hook.py` | 485 | observational hook, frozen operands + tuple, omission, result checks |
| `…/driver.py` | 363 | bounded state machine, `LiveMeasurement` boundary |
| `…/evidence.py` | 480 | fail-closed receipt validator, cross-observation proof, records digest |
| `…/campaign.py` | 87 | receipt composition |
| `…/history.py` | 182 | frozen AM reference, derived frozen-operand anchor |
| `…/prepare.py` | 261 | write-once record, seals, validation, CLI |
| `…/supervisor.py` | 210 | source-only supervisor that records a refusal |
| `…/invocation.py` | 96 | AST audit of engine-invocation paths |
| `…/seals.py` | 125 | write-once JSON, seals, path safety |
| `…/fixtures.py` | 222 | deterministic in-memory live measurement (tests only) |
| `…/test_compare.py` | 1578 | the test suite |
| `port/finish/map-variety/WALKER_SUPPORT_QUERY_COMPARE_SOURCE_20261005.md` | — | this report |

Line counts are exact at the delivery commit; the previous delivery's table had
four wrong counts, which the independent review caught.

## Tests and exact results

```sh
python3 -B -m unittest discover \
  -s tools/godot-multiplayer/new-maps/walker-support-query-compare -p 'test_*.py'
```

**Result: `Ran 91 tests` — `OK`.** No native execution, no network, no subprocess.
Three verification passes were run beyond the suite itself:

* All **91 declared** `test_*` methods were confirmed to be collected and run
  (declared vs. executed names compared; zero missing).
* Each of the **11 test classes** was removed in turn and the remainder re-run:
  every case reported `OK`, so no class is dead weight and no test depends on
  another class's execution.
* A **forger model** and **mutation testing** were run against the new
  frozen-operand checks specifically, as described under *Independent
  re-verification of the C1 fix* below.

Distribution: `CaseSetTests` 4, `ZeroMotionOmissionTests` 5,
`ObservationOrderingTests` 9, `FrozenOperandTests` 12, `GuardPreservationTests` 5,
`NoFurtherMovementTests` 4, `SealTests` 10, `SupervisorTests` 10,
`ReceiptValidatorTests` 18, `QualificationTests` 8, `BoundaryTests` 6 = **91**
(78 before this delivery, +13 new: 12 `FrozenOperandTests` and the pinned
`test_the_native_readiness_blockers_are_pinned_verbatim`).

The deliverable requirements map to tests as follows:

| Requirement | Tests |
|---|---|
| Case set exactly two | `test_case_set_is_exactly_the_two_authorized_finite_motion_cases`, `test_phase_allowlist_rejects_a_third_case_and_reordering`, `test_campaign_runner_refuses_extra_missing_or_reordered_lives`, `test_no_020_fallback_and_no_inclined_case_exists` |
| Zero-motion requests omitted | `test_two_exact_zero_observations_are_omitted_from_the_executable_proposal`, `test_omission_records_are_not_observations`, `test_no_executed_observation_carries_zero_or_epsilon_motion`, `test_hook_refuses_exact_zero_and_refuses_epsilon_pretending_to_be_zero`, `test_a_zero_motion_duplicate_is_refused_by_the_driver`, `test_removed_or_edited_omissions_are_refused` |
| Observation ordering | `test_event_order_is_exactly_the_five_authorized_events`, `test_pre_up_request_is_asked_at_the_predicted_endpoint_before_the_up_step`, `test_duplicate_is_posthoc_at_the_actual_final_state`, `test_live_call_order_places_the_observation_before_the_candidate_response`, `test_guard_observation_is_the_guard_own_recorded_request_not_a_reissue`, `test_only_the_first_eligible_transition_is_authorized`, `test_engine_changing_frozen_operands_is_refused`, `test_observation_that_mutates_recorded_state_is_refused`, `test_unaccepted_live_plan_is_refused_before_any_observation`, `test_reordered_observations_are_refused`, `test_a_pre_up_observation_relabelled_as_posthoc_is_refused`, `test_a_duplicate_asked_at_another_pose_is_refused`, `test_a_reissued_guard_request_is_refused` |
| Guard result/fault preservation | `test_guard_result_and_fault_are_preserved_for_both_cases`, `test_guard_result_is_not_relabelled_to_history_when_it_changes`, `test_one_divergent_case_does_not_relabel_the_other`, `test_history_is_reported_never_forced_and_the_receipt_still_validates`, `test_history_records_the_frozen_AM_facts_and_still_shows_the_gap`, `test_history_is_declared_read_only_and_not_a_substitute`, `test_guard_field_tampering_is_refused`, `test_an_unreported_divergence_is_refused` |
| Seals/validator reject tampering and unexpected outcomes | 10 `SealTests`, `test_tampered_contacts_and_predicates_are_refused`, `test_a_third_record_is_refused`, `test_a_records_digest_binds_every_recorded_byte`, `test_hash_and_schema_binding_is_refused`, `test_overclaiming_fields_are_refused`, `test_specification_tampering_is_refused`, `test_a_nonfinite_plan_coordinate_is_refused`, `test_a_query_state_equality_claim_that_is_false_is_refused`, `test_a_malformed_value_never_raises` |
| **Frozen operands unchanged across all three requests (C1)** | 12 `FrozenOperandTests`, incl. `test_the_unaltered_receipt_carries_one_frozen_tuple_shared_by_all_three_requests`, `test_the_reviewers_six_constant_retunings_are_all_refused`, `test_retuning_all_three_requests_together_is_still_refused`, `test_other_frozen_constants_are_covered_too_not_just_margin_and_rid`, `test_a_re_tuned_or_malformed_frozen_tuple_is_refused`, `test_a_case_cannot_borrow_the_other_cases_frozen_operands`, `test_the_driver_refuses_a_re_tuned_guard_request_on_the_live_side`, `test_the_driver_refuses_a_live_plan_whose_frozen_operands_were_re_tuned`, `test_the_frozen_tuple_is_recorded_in_the_prepared_source_record`, `test_the_predicates_are_reported_individually_and_never_repair`, `test_the_operand_groups_partition_the_constants_and_say_what_they_pin`, `test_the_recorded_am_motion_is_the_derivation_not_a_rounding` |
| No overclaiming | 8 `QualificationTests`, incl. the pinned blocker list |
| No third case or subsequent movement | `test_phase_allowlist_rejects_a_third_case_and_reordering`, `test_exactly_one_candidate_response_and_no_further_movement`, `test_driver_is_terminal_after_stop`, `test_second_candidate_response_is_unreachable`, `test_a_second_lift_or_parent_call_is_refused`, `test_extra_candidate_response_or_movement_is_refused` |

## Independent re-verification of the C1 fix

The fix was attacked the way the independent review attacked it, not merely tested.

**Forger model.** Twelve targeted edits to a valid receipt, each with
`recordsSha256` **re-derived by the forger**, so only structural predicates can
refuse. Result: **12 refused, 0 accepted.** They are the reviewer's six re-tunings
(guard margin, guard motion, guard bodyRid, duplicate margin, duplicate bodyRid,
pre-UP bodyRid), plus pre-UP margin, duplicate motion, guard `maxCollisions`, a
*consistent* re-tune of all three requests together with the recorded tuple and the
receipt table, and the same with the record's AM binding re-tuned as well. The same
twelve cases ship as `FrozenOperandTests`, and the driver-side equivalents ship too.

**Mutation testing.** 26 single- and paired-token source mutations, each applied to
a pristine copy and re-running the whole suite: **16 KILLED, 10 survived.** The
survivors are redundant defence-in-depth, each of which I confirmed is genuinely
load-bearing by pairing it with the mutation it shields and observing a kill:

| Survived | Why | Confirmed by |
|---|---|---|
| drop the record's AM binding check | shielded by the tuple-vs-AM anchor | killed in combination |
| drop the bodyRid anchor | shielded by the tuple-vs-AM anchor and the binding | killed in combination |
| record history binding no longer pinned to AM | shielded by the validator's own AM anchor | — |
| driver drops its bodyRid check | shielded by `hook.frozen_operands`' own positive-RID rule | — |
| `operand_equal` stops reporting missing keys | `frozen_tuple` requires the exact key set first | — |
| AM anchor stops requiring the recorded operands | `hook.frozen_tuple` requires them next | — |
| AM anchor stops checking the derived motion | `frozen_tuple` re-derives and rejects it next | — |
| AM anchor stops requiring test-only | the guard path requires it, and `frozen_tuple` requires `testOnly is True` | — |

Dropping **all four** validator layers at once is **KILLED**, as is dropping the
tuple comparison together with any single one of the three anchors. So the
guarantee is not resting on one predicate: it survives any one removal and fails on
the second.

Reference run of the two cases (fully synthetic; **not** native results) shows the
contract produces the intended shape — pre-UP observation at the flat
`[0, 1, 0]` normal before the lift, then the guard's own 36.677326° (.35) /
47.476992° (.42) query and its duplicate at the identical pose, two omissions,
`unexpectedChangedOutcomes: []`, and both cases sharing one recorded frozen-operand
tuple apart from the body RID (`margin 0.0199999995529652`, `motion
[0, -0.0200999995529652, 0]`, `maxCollisions 32`), `recordsSha256
67a3bf6c7a153043e32cebb1ce26869df423bab740b7f3505e9e71fa47fe6b4b`. Horizontal
agreement error 1.0536712e−08 m against the guard's 1e−06 m epsilon; vertical
offsets recorded, not forced: **−0.0843750014901164 m** (.35) and
−0.1476562619209293 m (.42).

## Assumptions and dependencies on Godot internals

Everything below is a **source-level assumption**, pinned by SHA256 in
`prepare.REFERENCES` and re-verified by `verify_references`. None is a measured
backend behaviour, and none is a claim about the active physics backend.

1. **`response_guard.gd` line semantics are unchanged.** The driver reads
   `raised`, `horizontalBudget`, `expectedFinal`, `upMotion`, `landingY`,
   `supportRid`, `supportShape` from the live plan and computes
   `predictedEndpoint = raised.origin + horizontalBudget` the way
   `response_guard.gd:29` does. If that line changes, the contract is stale and
   the pin fails.
2. **The guard's support sweep uses the reviewed down32 operand set.** From
   `sweep_proposal.gd`: margin `safe_margin`, max 32 contacts,
   `recovery_as_collision` and `collide_separation_ray` both true, empty
   exclusions, `test_only` absent-or-true. `hook.GUARD_CONSTANTS` encodes exactly
   this; a divergence is refused rather than tolerated.
3. **The guard asks at the actual final state.** `Proposal.sweep(body,
   body.global_transform, …)` uses the live transform, so the guard's recorded
   `from` is the post-response pose. The driver takes the duplicate's pose from
   that recorded request rather than computing one, precisely so this assumption
   cannot be violated by a wrong recomputation.
4. **`safe_margin` is float32-sourced.** Motion is `-UP * (margin + LIMIT)` with
   `LIMIT = 1e-4`, giving `[0, −0.0200999995529652, 0]` for the recorded margin.
   The AM request itself records `[0, −0.0200999993830919, 0]` — a float32 rounding
   of that derivation, 1.7e−10 away — which is why the derived-motion check uses
   `DERIVED_MOTION_EPSILON` (1e−9) against a *recorded engine* value while the frozen
   tuple itself must carry the exact derivation. `hook.numeric_budget` is a direct
   port of `response_guard.gd` (eight float32 ULPs, capped by domain refusal) and is
   asserted equal to the frozen calibrated `evidence.budget` over five point sets
   including the refusal case; that frozen module is now itself pinned in
   `prepare.REFERENCES`, so the port and its oracle cannot drift together (C4).
5. **`collision_local_shape == 0` and `collider_shape == 0`** for the intended
   tread, as in the guard's identity checks.
6. **`godot_space_3d.cpp:698–699` has no zero-length guard.** Taken from the
   approved design review. This is the whole reason the two zero-motion
   observations are omitted; if a future engine revision establishes zero-motion
   semantics, these omissions are the first thing to revisit.
7. **`apply_floor_snap` projects Y only**, which is why the predicted endpoint's
   height legitimately differs from `expectedFinal`. Recorded rather than
   demanded away.
8. **RIDs, velocities and contact points in `fixtures.py` are copied from the
   frozen AM receipt** purely so the offline tests have plausible numbers. They
   are test inputs, not observations.

Also inherited and unchanged: the AM `backendImplementationVerified = false`,
`parentInternalCallsTraced = false` and `physicalCallCounts = null`
qualifications. This package adds no observation that would lift them, and its
receipt requires them to stay false.

## What remains before native readiness

The six blockers are recorded verbatim in `policy.NATIVE_READINESS_BLOCKERS` and
in every refusal record, and the receipt requires `nativeReadiness.ready` to be
false with that exact list. The literal six strings are now also pinned in
`test_the_native_readiness_blockers_are_pinned_verbatim`: comparing the list
against itself moves both sides together, which is how the review showed an entry
could be blanked with nothing failing (C3).

1. **No independent source review of this package.** Required before anything
   else. One has now been carried out and returned **APPROVE WITH CONDITIONS** with
   no P1 and a single substantive finding (C1, now closed in this delivery) plus
   three non-blocking conditions (C2 line counts and the report's self-description,
   C3 the unpinned blocker list, C4 an unpinned cross-package test dependency) —
   all closed here except the deferred GDScript mirror. It conferred no native
   readiness: blockers 2–6 are untouched and this blocker stays in the list,
   because a review of *this* source does not review a *mirror* of it.
2. **No grant.** No heavy grant exists for phase `support-query-compare-v1`.
3. **No GDScript.** The driver and hook exist only as offline Python. A native
   run needs `driver.gd`, an observation hook in GDScript, `policy.gd` and
   `evidence.gd` mirroring these contracts, plus a derivation step in the style of
   `walker-calibrated-admission/derive_sources.py` that asserts every
   replacement's occurrence count. Not attempted here.
4. **No engine-invocation path.** By design; would be added only under a grant,
   and `invocation.audit` would have to be updated as a deliberate act.
5. **Zero-motion semantics remain undefined.** The two omitted observations stay
   omitted until a source review establishes the semantics.
6. **AM remains failed and .42/+45° remains unrun.**

Additional work a future native implementation must do, not attempted here:

* **Stage and grant creation** under a reviewed namespace, with
  `validate_stage`-equivalent namespace confinement and hash binding.
* **A real `LiveMeasurement` in GDScript** bridging the frozen `candidate.gd`,
  `planner.gd` and `response_guard.gd` to this contract's six-state machine, with
  the ordering enforced on the engine side too.
* **A real supervisor** with the reviewed lock, consume-before-launch marker,
  owned-group cleanup, post-exit log scan, measured release audits and a timeout.
* **A GDScript `evidence.gd` mirror** of `evidence.py` for prelaunch checks, and
  a test asserting the mirror and the Python validator agree — the pattern used by
  the calibrated packages. **The mirror must carry `evidence._frozen_operands`
  whole**: the tuple-shape check, the AM anchor and the cross-observation comparison
  are three separate layers, and omitting any one of them re-opens exactly the six
  re-tunings the review demonstrated. Porting `evidence.py` without them would make
  the claim false in GDScript, which is what condition C1 was a gate on.
* **Deferred, source-only by nature.** The validator cannot prove from a self-attested
  record that the recorded tuple is the one the driver froze; only the prepared
  source record can, bound by `sourceSha256`. In a native staging the record is
  written and sealed by a real supervisor, so the mirror inherits the same two-step
  structure. Nothing about the cross-observation comparison itself is deferred.
* **A native smoke fixture**, which is out of scope for this source-only
  deliverable.

## Unchanged boundaries

AM whole positive admission **FAIL**; .42 verified lifts **0**; .35 individual
passes; .42/+45° **unrun** and absent from the case set; all **60 map journeys**,
**184 static Vesper failures** and production accounting **open**; `candidateMapWalks`
**0**; `.20` is not a fallback; no guard widening, retry or epsilon tuning. No
test acceptance in this package is represented as a native pass.

## Delivery hashes

Package `tools/godot-multiplayer/new-maps/walker-support-query-compare/` at
commit time (sha256, bytes):

```
README.md        HASH_README                                                                    
__init__.py      HASH_INIT                                                                      
campaign.py      HASH_CAMPAIGN                                                                  
cli.py           HASH_CLI                                                                       
driver.py        HASH_DRIVER                                                                     
evidence.py      HASH_EVIDENCE                                                                  
fixtures.py      HASH_FIXTURES                                                                  
history.py       HASH_HISTORY                                                                  
hook.py          HASH_HOOK                                                                       
invocation.py    HASH_INVOCATION                                                                 
policy.py        HASH_POLICY                                                                     
prepare.py       HASH_PREPARE                                                                    
seals.py         HASH_SEALS                                                                      
supervisor.py    HASH_SUPERVISOR                                                                 
test_compare.py  HASH_TEST                                                                       
```

**This report's own digest is deliberately not printed here.** A file cannot contain
its own SHA256, so any such line is unverifiable by construction; the previous
delivery's (`cb80def4…`, 18338 bytes, against an actual 21083) was wrong, and the
review was right that the line should name the attempt rather than assert a number.
Verify this file the ordinary way: `git hash-object` on the committed blob, or
`sha256sum port/finish/map-variety/WALKER_SUPPORT_QUERY_COMPARE_SOURCE_20261005.md`
at the delivery commit named in the header.

Frozen references re-verified unchanged at commit time: `response_guard.gd`,
`sweep_proposal.gd`, `candidate.gd`, `planner.gd`, `walker.gd`,
`walker-calibrated-admission/evidence.py` (the `numeric_budget` oracle, C4), the
approved design review, the diagnosis `comparison.json` and its `source-receipt.json`
(`25382b4d…`, the identity recorded by the design review).

## Local verification

Surrounding suites re-run on this branch to confirm nothing regressed:

| Suite | Result |
|---|---|
| `walker-support-query-compare` (new) | `Ran 91 tests` — **OK** |
| `walker-support-normal-diagnosis` | `Ran 8 tests` — **OK** |
| `walker-calibrated-admission` | `Ran 30 tests` — **OK** |
| `walker-parity-admission` | `Ran 49 tests` — **OK** |
| `walker-baseline-characterization` | `Ran 5 tests` — **OK** |
| `walker-policy-receipt-probe` | `Ran 26 tests` — 5 errors, **pre-existing** |

The five `walker-policy-receipt-probe` errors are pre-existing on this branch's
base and unrelated to this work: they fail identically with this package's
changes stashed, because that package's `verify_host` and `sources` read a
`cocs-walker-parity-admission-ai` root that this worktree does not materialize.
No file in that package was touched here.
