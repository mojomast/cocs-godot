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

`evidence._frozen_operands` then requires the recorded tuple to be well formed
(`hook.frozen_tuple`), and then four independent anchors to hold, each pinned by the
rule its own provenance allows:

1. **design-frozen** — the tuple's design-frozen constants equal the SHA256-pinned AM
   guard request's, so the tuple cannot be re-tuned inside a receipt;
2. **binding** — the record's own AM binding is the very tuple the validator was
   handed, on every constant. Both sides are the AM run's *own* recorded operands, so
   this binds a receipt to one approved set and makes no claim about this run's RID;
3. **run-frozen** — the run-frozen body RID is identical in the record's own recorded
   tuple and in all three executed requests (`hook.run_frozen_unchanged`);
4. **cross-observation** — all three executed requests carry exactly the whole tuple
   and agree with each other pairwise (`hook.operands_unchanged` performs both, so
   the guarantee does not rest on the tuple anchor alone).

How each constant is pinned is enumerated, and the three groups partition
`CONSTANTS` exactly: design-frozen (margin, contact cap, the two flags, exclusions,
test-only) from reviewed source and the pinned AM request, pinned by equality with
it; derived (motion) from the frozen margin — the AM request records a *float32
rounding* of the derivation, `-0.0200999993830919` against `-0.0200999995529652`, so
the anchor derives motion rather than copying it, and the check is re-derivation;
and run-frozen (body RID) by identity across this run's own three requests, since a
RID is assigned per run.

**N1, settled: this run's body RID is not required to be the AM run's body RID.** The
re-review demonstrated that `evidence._frozen_operands` pinned the run-frozen body RID
to the AM run's RID twice — once by comparing the AM binding to the recorded tuple, once
against the tuple's own anchor — while `hook.RUN_FROZEN_CONSTANTS` and
`driver.run_case:175` both said the opposite. A genuine per-run RID was therefore
accepted by the driver and refused by the validator, which would have failed the first
real native run's receipt and been inherited by any GDScript mirror. The second of the
re-review's two options was taken: the AM-value comparison is gone and the documented
rule is now the implemented one, via `hook.run_frozen_unchanged`. `driver.run_case`
already excluded `bodyRid` from its AM comparison, so driver and validator now agree;
`prepare.contract`'s per-case table keeps the AM RID as *provenance of the anchor*, and
says so. Three tests carry it: a genuine fresh per-run RID (`777000333` / `777000444`,
neither the AM value) is **accepted** by both driver and validator; a RID that disagrees
across the observations is refused and named as `request<i>:bodyRid` / `<i>~<j>:bodyRid`;
and a recorded binding RID that differs from the run's own three requests is refused and
named as differing from the binding while the pairwise half correctly stays silent. The
run-frozen rule is empty-safe: no executed requests is `(False,
['no_executed_request'])`, not a vacuous pass.

`FrozenOperandTests` reproduces the independent review's six re-tunings as negative
cases with `recordsSha256` **re-derived by the forger**, so only a structural
predicate can act: guard margin, guard motion, guard bodyRid, duplicate margin,
duplicate bodyRid and pre-UP bodyRid are all refused, as is a *consistent* re-tune
of all three requests together with the recorded tuple, the record's AM binding and
the receipt's per-case table. The driver refuses the same re-tunes on the live side
of the boundary, before any duplicate is issued.

**Every one of those forgeries is preconditioned.** The re-review's methodological
finding — that editing only an observation's `request` leaves observations 1 and 4
disagreeing with their own `result`, so `evidence._observation` refuses first and the
cross-observation layer is never reached — applied to the shipped suite as well: five
of the six re-tunings, and the whole consistent-re-tune test, were passing without
proving what they named. The edits are now mirrored into each observation's own
`result`, and `per_observation_intact` asserts the precondition rather than assuming it.
The one that cannot be made self-consistent — a guard motion disagreeing with its own
margin — is *not* mirrored, and the test says why: it is refused by the derivation
predicate one layer earlier, which is the stronger of the two statements.

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
| `tools/…/walker-support-query-compare/README.md` | 230 | purpose, boundaries, how to run |
| `…/__init__.py` | 6 | importing grants no authority |
| `…/cli.py` | 34 | isolated hashed package loader, single-operation CLI |
| `…/policy.py` | 161 | phase/case allowlist, canonical cases, schemas, grant validation |
| `…/hook.py` | 534 | observational hook, frozen operands + tuple, run-frozen rule, omission, result checks |
| `…/driver.py` | 368 | bounded state machine, `LiveMeasurement` boundary |
| `…/evidence.py` | 505 | fail-closed receipt validator, cross-observation proof, records digest |
| `…/campaign.py` | 87 | receipt composition |
| `…/history.py` | 182 | frozen AM reference, derived frozen-operand anchor |
| `…/prepare.py` | 267 | write-once record, seals, validation, CLI |
| `…/supervisor.py` | 210 | source-only supervisor that records a refusal |
| `…/invocation.py` | 96 | AST audit of engine-invocation paths |
| `…/seals.py` | 125 | write-once JSON, seals, path safety |
| `…/fixtures.py` | 237 | deterministic in-memory live measurement, per-run RID override (tests only) |
| `…/test_compare.py` | 2082 | the test suite |
| `port/finish/map-variety/WALKER_SUPPORT_QUERY_COMPARE_SOURCE_20261005.md` | — | this report |

Line counts are exact at the delivery commit; the previous delivery's table had
four wrong counts, which the independent review caught.

## Tests and exact results

```sh
python3 -B -m unittest discover \
  -s tools/godot-multiplayer/new-maps/walker-support-query-compare -p 'test_*.py'
```

**Result: `Ran 100 tests` — `OK`.** No native execution, no network, no subprocess.
Four verification passes were run beyond the suite itself:

* All **100 declared** `test_*` methods were confirmed to be collected and run
  (declared vs. executed names compared; zero missing).
* Each of the **11 test classes** was removed in turn and the remainder re-run:
  every case reported `OK`, so no class is dead weight and no test depends on
  another class's execution.
* A **forger model** and **mutation testing** were run against the frozen-operand
  checks specifically, as described under *Independent re-verification of the C1 fix*
  below.
* **13 anchor mutations** were run against this delivery's suite — neutering or
  deleting each of the four anchors, the whole-tuple comparison, the well-formedness
  gate and the whole `_frozen_operands` call, plus restoring the pre-N1 AM RID
  comparison: **13 killed, 0 survivors**, with a direct admission probe for each. See
  *N2: the anchors, now carried behaviourally* below.

Distribution: `CaseSetTests` 4, `ZeroMotionOmissionTests` 5,
`ObservationOrderingTests` 9, `FrozenOperandTests` 21, `GuardPreservationTests` 5,
`NoFurtherMovementTests` 4, `SealTests` 10, `SupervisorTests` 10,
`ReceiptValidatorTests` 18, `QualificationTests` 8, `BoundaryTests` 6 = **100**
(91 at the previous delivery, +9 new, all in `FrozenOperandTests`: four for N1's RID
semantics, four for N2's anchor cargo, one for the anchor site inventory).

The deliverable requirements map to tests as follows:

| Requirement | Tests |
|---|---|
| Case set exactly two | `test_case_set_is_exactly_the_two_authorized_finite_motion_cases`, `test_phase_allowlist_rejects_a_third_case_and_reordering`, `test_campaign_runner_refuses_extra_missing_or_reordered_lives`, `test_no_020_fallback_and_no_inclined_case_exists` |
| Zero-motion requests omitted | `test_two_exact_zero_observations_are_omitted_from_the_executable_proposal`, `test_omission_records_are_not_observations`, `test_no_executed_observation_carries_zero_or_epsilon_motion`, `test_hook_refuses_exact_zero_and_refuses_epsilon_pretending_to_be_zero`, `test_a_zero_motion_duplicate_is_refused_by_the_driver`, `test_removed_or_edited_omissions_are_refused` |
| Observation ordering | `test_event_order_is_exactly_the_five_authorized_events`, `test_pre_up_request_is_asked_at_the_predicted_endpoint_before_the_up_step`, `test_duplicate_is_posthoc_at_the_actual_final_state`, `test_live_call_order_places_the_observation_before_the_candidate_response`, `test_guard_observation_is_the_guard_own_recorded_request_not_a_reissue`, `test_only_the_first_eligible_transition_is_authorized`, `test_engine_changing_frozen_operands_is_refused`, `test_observation_that_mutates_recorded_state_is_refused`, `test_unaccepted_live_plan_is_refused_before_any_observation`, `test_reordered_observations_are_refused`, `test_a_pre_up_observation_relabelled_as_posthoc_is_refused`, `test_a_duplicate_asked_at_another_pose_is_refused`, `test_a_reissued_guard_request_is_refused` |
| Guard result/fault preservation | `test_guard_result_and_fault_are_preserved_for_both_cases`, `test_guard_result_is_not_relabelled_to_history_when_it_changes`, `test_one_divergent_case_does_not_relabel_the_other`, `test_history_is_reported_never_forced_and_the_receipt_still_validates`, `test_history_records_the_frozen_AM_facts_and_still_shows_the_gap`, `test_history_is_declared_read_only_and_not_a_substitute`, `test_guard_field_tampering_is_refused`, `test_an_unreported_divergence_is_refused` |
| Seals/validator reject tampering and unexpected outcomes | 10 `SealTests`, `test_tampered_contacts_and_predicates_are_refused`, `test_a_third_record_is_refused`, `test_a_records_digest_binds_every_recorded_byte`, `test_hash_and_schema_binding_is_refused`, `test_overclaiming_fields_are_refused`, `test_specification_tampering_is_refused`, `test_a_nonfinite_plan_coordinate_is_refused`, `test_a_query_state_equality_claim_that_is_false_is_refused`, `test_a_malformed_value_never_raises` |
| **Frozen operands unchanged across all three requests (C1)** | 21 `FrozenOperandTests`, incl. `test_the_unaltered_receipt_carries_one_frozen_tuple_shared_by_all_three_requests`, `test_the_reviewers_six_constant_retunings_are_all_refused`, `test_retuning_all_three_requests_together_is_still_refused`, `test_other_frozen_constants_are_covered_too_not_just_margin_and_rid`, `test_a_re_tuned_or_malformed_frozen_tuple_is_refused`, `test_a_case_cannot_borrow_the_other_cases_frozen_operands`, `test_the_driver_refuses_a_re_tuned_guard_request_on_the_live_side`, `test_the_driver_refuses_a_live_plan_whose_frozen_operands_were_re_tuned`, `test_the_frozen_tuple_is_recorded_in_the_prepared_source_record`, `test_the_predicates_are_reported_individually_and_never_repair`, `test_the_operand_groups_partition_the_constants_and_say_what_they_pin`, `test_the_recorded_am_motion_is_the_derivation_not_a_rounding` |
| **Run-frozen RID is this run's own (N1)** | `test_a_genuine_fresh_per_run_body_rid_is_accepted_by_driver_and_validator`, `test_a_body_rid_that_disagrees_across_the_observations_is_refused`, `test_a_recorded_body_rid_that_differs_from_the_runs_own_requests_is_refused`, `test_the_run_frozen_rule_is_empty_safe_and_reports_individually` |
| **Every anchor carried behaviourally (N2)** | `test_every_anchor_site_exists_exactly_once_in_the_validator`, `test_the_design_frozen_anchor_alone_refuses_a_consistent_retune`, `test_the_record_binding_anchors_are_jointly_necessary`, `test_the_run_frozen_anchor_is_jointly_necessary_with_the_whole_tuple_comparison`, `test_the_well_formedness_gate_is_redundant_but_still_present` |
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

### N2: the anchors, now carried behaviourally

The re-review's §5.2 finding stands and is the reason for this section: of the four
anchors, **zero** were carried by the suite. Neutering any one left all 91 tests
green, and a deletion was caught only by a `co_names` introspection assertion —
which cannot see a *neuter*, since the neutered form still makes the call. The shipped
consistent-re-tune test also never reached the anchor it named.

`FrozenOperandTests` now carries all four behaviourally. `shadow_evidence` writes a
copy of `__init__.py`, `hook.py`, `policy.py` and `evidence.py` to a temporary
directory, applies the anchor's **enforcement** removal — keeping the call, its
operands and its docstring — and imports the copy as its own hashed package. The three
states are distinguished, so a neutered anchor cannot pass by being unremarkable: the
enforcing form present once is replaced; the already-neutered form present once is
left alone so the *behavioural* assertion reports the failure rather than a text
tripwire; neither present fails with "deleted, moved or rewritten". `hook` and `policy`
are copied byte for byte, so a forgery admitted by the copy can only have been admitted
by the code that was removed.

Each test preconditions its forgery — `per_observation_intact` asserts every isolation
predicate still passes, and each forgery asserts which *other* anchors still hold — so
"the shipped validator refuses it, the neutered copy admits it" is attributable to that
anchor rather than to a neighbour.

| Anchor | Forgery | Neutralising it alone | Disabling it with its sibling |
|---|---|---|---|
| design-frozen | consistent re-tune of all three requests + tuple + table (internally consistent, `operands_unchanged` passes) | **admitted** — nothing else covers it | — |
| record binding (`_frozen_operands`) | record's own AM binding re-tuned, nothing else | still refused by the record-level anchor | **both disabled → admitted** |
| record history binding (`record`) | same forgery | still refused by the inner anchor | **both disabled → admitted** |
| run-frozen + whole-tuple comparison | one observation's RID disagrees (built on a fresh per-run RID, so the AM anchor cannot act) | still refused by the sibling | **both disabled → admitted** |

The two redundant pairs are reported honestly rather than as single-anchor kills: each
member is caught by the other, so neither can be shown load-bearing alone from the
outside, and the tests assert exactly that — disabling one still refuses, disabling both
admits. The well-formedness gate is a third case, and the test says so: **every**
malformed tuple it refuses is also refused by one of the four anchors, so it is
redundant defence-in-depth, kept because it refuses for the right stated reason, and its
redundancy is asserted rather than left implicit.

**Verification of this pass, by mutation against the shipped suite** (13 mutants, each
a real copy of the package plus exactly the 9 files its own pins name, so a copy cannot
drift from what the package reads):

| Mutation | Suite verdict | Failing tests |
|---|---|---|
| neuter design-frozen anchor | FAILED (4) | the anchor's own test, `retuning_all_three_requests_together_is_still_refused`, the run-frozen pairing test, the site inventory |
| **delete** design-frozen anchor | FAILED (5) | the above plus the prose-claim test |
| neuter record-binding anchor | FAILED (2) | its own test, the site inventory |
| neuter record-history-binding anchor | FAILED (2) | its own test, the site inventory |
| neuter **both** record-binding anchors | FAILED (2) | its own test, the site inventory |
| neuter run-frozen anchor | FAILED (2) | its own test, the site inventory |
| **delete** run-frozen anchor | FAILED (3) | the above plus the prose-claim test |
| neuter run-frozen + whole-tuple comparison | FAILED (6) | all three run-frozen tests, the six-re-tunings test, the inventory |
| neuter the whole-tuple comparison | FAILED (4) | its own pairing test, the six-re-tunings test, the redundancy test, the inventory |
| drop the whole `_frozen_operands` call | FAILED (9) | all four anchor tests plus three pre-existing ones |
| neuter the well-formedness gate | FAILED (2) | the redundancy test, the site inventory |
| restore the run-frozen vacuous pass | FAILED (1) | the empty-safety test |
| **restore the AM RID comparison (pre-N1)** | FAILED (4) | all three run-frozen tests, including the fresh-per-run-RID acceptance |

**13 mutations, 13 killed, 0 survivors.** Each was additionally probed for *admission*
rather than only for a red suite: the mutated validator was handed the forgery directly
and asked whether it validates. Design-frozen neutered → the consistent re-tune is
**ACCEPTED**; both record-binding anchors neutered → the binding re-tune is **ACCEPTED**;
run-frozen + whole-tuple neutered → the RID mismatch is **ACCEPTED**; pre-N1 AM RID
comparison restored → the genuine fresh per-run RID is **REFUSED**. So each new test
fails for the behavioural reason, not incidentally.

**What is still redundant, measured.** The well-formedness gate, as above. Nothing else
in the frozen-operand stack is redundant by this measurement, which is a change from the
previous delivery, where three of the four anchors were reported as shielded with no
behavioural killer available.

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
6. **A body RID is assigned per run.** This is the assumption N1 rests on. A RID is
   the engine's own identifier for the body under test and is not predictable before
   the run, which is why `driver.run_case` excludes it from its AM comparison and the
   validator pins it by this run's own agreement instead. The assumption is *not* that
   any particular RID will be observed — only that the same one is carried by the
   pre-UP request, the guard's own recorded request and the duplicate, and equals the
   record's own recorded binding. The prepared record's per-case table still carries
   the AM run's RID, as provenance of the anchor rather than as a prediction.
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

   The independent source re-review of the C1 fix (at `8d4be734`) returned **C1
   CLOSED, no P1**, with two non-blocking observations that had to be settled before
   native staging. Both are settled here:

   * **N1 — the run-frozen body RID.** Settled by taking the re-review's second
     option: the validator no longer requires this run's RID to be the AM run's, and
     `hook.run_frozen_unchanged` enforces the rule the documentation already stated.
     Driver and validator now agree, and three tests carry it.
   * **N2 — the anchors' test coverage.** All four anchors now carry behavioural
     tests. The re-review measured **0/12** per anchor; 13 anchor mutations are now
     killed, 0 surviving, with a direct admission probe for each.

   The re-review's N3 (two `history`-provenance refusals unreachable from a receipt)
   and N4 (cosmetic) need nothing here: N4 was already closed at the previous
   delivery, and N3's two predicates guard the SHA256-pinned export read, which no
   receipt can influence. They remain untested rather than broken, as recorded there.
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
  whole**: the tuple-shape check, the design-frozen AM anchor, the record's binding
  anchor, the run-frozen rule and the cross-observation comparison are separate layers,
  and omitting any one of them re-opens exactly the six re-tunings the review
  demonstrated. Porting `evidence.py` without them would make the claim false in
  GDScript, which is what condition C1 was a gate on.
* **The mirror must port the RID rule as implemented, not as previously described.**
  N1 is settled, so there is no longer a contradiction to resolve at mirror time: the
  validator does **not** compare this run's body RID with the AM run's, and a mirror
  that did would refuse every genuine run, while a mirror that compared it "the way the
  prose used to say" would diverge from the Python validator it must agree with. Port
  `hook.run_frozen_unchanged` as it is — identity across the record's own tuple and the
  three requests — and carry the *anchor grouping* with it, so the three groups are
  each enforced by their own rule rather than uniformly against the AM table.
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
commit time (sha256, bytes). The `88214d99` block is retained as the record of the
C1 delivery; the block below it is this pass's, and both are verifiable with
`git show <commit>:<path> | sha256sum` rather than against the working tree.

At commit `88214d99` (the C1 delivery, superseded here but not withdrawn):

```
README.md        aa2776266283856bf5dd54180feb3c7e813bd0df2124bde6cecea1b9e2d38cfd  10993
__init__.py      80459abcb5a78a0e00ed507dcc3448996aa843686fbc710146bf11351312c07e   301
campaign.py      a4c63dee93ebfc077c6e0dc59322860dcfc665ddcd3632515443fc5100c20379  4049
cli.py           c627fbc736dcfd1bb90d07f3764a195ea251dce9ce6e93148b93df703cfca015  1238
driver.py        b31de4072d2da805905c297b38c58968db7bdec5728c3fbb280d8ea665a39b92 19613
evidence.py      91b64a40639f1bc2b5f583a23a72333113c93bfc237eacf64a3b30ddb16a3972 22991
fixtures.py      e05eaa22cbdda7d2c7c50d83b54360815f70f2ea5bff517b60c9dfa89d3b9e9c 11451
history.py       0c462cae44ae7013ac7ff93cbdb813319374833a0b0ea9956fb9af334e93b6cf  9543
hook.py          476aaff44e9b88c4b413c7553b022cb667b0b3d3fa0e16ff36ef9ceaa6da64c4 24586
invocation.py    513b397fddd2acd1d6dc36bc034edfb9995a32d3f53426c597e3ffeb752b0ac7  4639
policy.py        125a451dcfecc6bb2adbcfc47bdce25edb69acabe14b6b1b9b8e3bb7d5a9b78f  8387
prepare.py       dff31c1b03e30a5818afc8429c32faf88cdf54ee91c2e1331ba7e95569f204d1 12597
seals.py         a204d17e477584dd930d1ee423a54fa95568c8d62cc730509bf0867192d4a625  4738
supervisor.py    78430d40dee7993910444dc559cafc9380512f907a30009b1e8fb2fac5a8cfb0  9805
test_compare.py  83cddcd2a73cd472cf82fea99653ec5afc7132f352b33417f84c79e3346f6dc0 91219
```

At commit `DELIVERY_COMMIT` (N1 + N2):

```
DELIVERY_HASHES
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
| `walker-support-query-compare` (new) | `Ran 100 tests` — **OK** |
| `walker-support-normal-diagnosis` | `Ran 8 tests` — **OK** |
| `walker-calibrated-admission` | `Ran 30 tests` — **OK** |
| `walker-parity-admission` | `Ran 49 tests` — **OK** |
| `walker-baseline-characterization` | `Ran 5 tests` — **OK** |
| `walker-parity-response` | `Ran 24 tests` — **OK** |
| `walker-policy-receipt-probe` | `Ran 26 tests` — 5 errors, **pre-existing** |

The five `walker-policy-receipt-probe` errors are pre-existing on this branch's
base and unrelated to this work: they fail identically with this package's
changes stashed, because that package's `verify_host` and `sources` read a
`cocs-walker-parity-admission-ai` root that this worktree does not materialize.
No file in that package was touched here.
