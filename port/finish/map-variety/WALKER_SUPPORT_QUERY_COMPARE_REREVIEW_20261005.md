# Independent source re-review — bounded two-case Walker support-query comparison, condition C1

Reviewer session: independent source re-review (this document, an addendum).
Branch: `review/walker-support-query-rereview-20261005`, created at the fixed tip
**`8d4be734`** (producer branch `spacebunny/walker-support-query-20261005`).
Re-reviewed commits: **`88214d99`** (C1 implementation + C2/C3/C4 fixes),
**`f311f667`** (delivery hashes), **`8d4be734`** (line-count correction).
Original review re-reviewed: **`7733051a`** (APPROVE WITH CONDITIONS, no P1).
Worktree: `/home/mojo/.tmp-on-disk/cocs-walker-support-normal-diagnosis`, clean
before and after; the producer tip remains in `refs` and was not pushed, merged or
rebased.

---

## 0. Relationship to the original review

**The original review document is immutable and is not modified, superseded or
retracted by this one.**

`port/finish/map-variety/WALKER_SUPPORT_QUERY_COMPARE_REVIEW_20261005.md` exists
only on branch `review/walker-support-query-20261005` at `7733051a`, blob
`cad076cd6e6e5dc3ae593a68651651451e835ede`. It is not on the producer branch and was
not on this re-review branch's base, and nothing in this re-review touches it. This
document is a **separate addendum** at
`port/finish/map-variety/WALKER_SUPPORT_QUERY_COMPARE_REREVIEW_20261005.md`. Where
the two disagree, the disagreement is recorded below explicitly rather than by
rewriting the earlier text. The only file committed on this branch is this one.

---

## Verdict on C1 closure: **CLOSED**

C1 was: *"Correct the three sentences claiming the validator proves the guard's
request and the duplicate carry identical frozen constants — or, better, add the
missing cross-observation check so the claim becomes true. Required before any
`evidence.gd` mirror is derived."*

The producer took the second, better option: the missing check now exists, in three
layers, and I verified it with my own instruments rather than by reading. The three
published sentences are now true as written. **No P1 blocker. No new blocker.**
C2, C3 and C4 are closed. Four non-blocking observations are recorded in §6; one of
them (N1) is a real defect in the new code that must be decided before native
staging, and another (N2) is a gap in the *test* proof for the anchor — not in the
anchor, which I verified independently.

My verdict would have been the same had the suite carried the anchor's own proof,
because I established the anchor's load-bearing role by mutation and by forgery
rather than by trusting the suite. But a reviewer should know exactly which claims
the suite does and does not carry; §5 gives that line.

---

## 1. What was verified, and how

Four independent instruments, all read-only with respect to the review worktree:

1. **Reading** the whole `7733051a..88214d99` diff and the resulting 15 modules,
   with emphasis on `hook.py`, `evidence.py`, `history.py`, `prepare.py`,
   `driver.py`, `campaign.py`, `policy.py`.
2. **My own forger model** — 51 targeted edits to a valid receipt, each with
   `recordsSha256` **re-derived by the attacker's own code**, so only a structural
   predicate can refuse. Each forgery is additionally *preconditioned*: I assert
   that every per-observation predicate still passes before recording a refusal, so
   a refusal is attributable to the cross-observation layer rather than to the
   isolation checks it was meant to make redundant. That precondition matters — see
   §5.2, where it changes the attribution of a shipped test.
3. **Mutation testing** — 39 single-token source mutations plus **12
   shape-preserving variants** and **8 layered combinations**, each applied to a
   fresh copy of a shadow root (`/tmp/opencode/sqc-rereview/shadow`, 684 KB, built
   only from the files the package actually reads) with the shipped suite re-run
   **and my forger re-run against the mutated code**. A mutation is *KILLED* only if
   the shipped suite detects it; the forger column then says whether a survivor is
   load-bearing.
4. **Direct probes** for the three reviewed design notes, the derived-motion
   tolerance, the two history-provenance survivors, the deferred binding item, and
   the body-RID anchoring question.

Python 3 only. **No engine, no Blender, no native parser or import, no renderer,
no server, no child job, no native stage, no grant, no network, no subprocess
other than `python3 -m unittest` inside the shadow root.**

### 1.1 Test counts, exactly

| Suite / instrument | Result |
|---|---|
| `walker-support-query-compare` on the re-review branch | **`Ran 91 tests` — OK** |
| same suite on an independent shadow root | **`Ran 91 tests` — OK** |
| declared vs. executed | **91 `test_*` methods declared, 91 collected and run, 0 missing** |
| class distribution | Boundary 6, CaseSet 4, **FrozenOperand 12**, GuardPreservation 5, NoFurtherMovement 4, ObservationOrdering 9, Qualification 8, ReceiptValidator 18, Seal 10, Supervisor 10, ZeroMotion 5 = **91** |
| **my forger model** | **51 forgeries — 28 refused by the C1 layer, 18 refused but by a non-C1 predicate too, 5 accepted** (§4) |
| **my mutation testing** | **47 mutations — 39 KILLED, 8 survived, 0 errors**, plus **12 shape-preserving — 8 KILLED, 4 survived**, plus **8 layered combinations — 8 KILLED** |
| `walker-support-normal-diagnosis` | `Ran 8 tests` — OK |
| `walker-calibrated-admission` | `Ran 30 tests` — OK |
| `walker-parity-admission` | `Ran 49 tests` — OK |
| `walker-baseline-characterization` | `Ran 5 tests` — OK |
| `walker-parity-response` | `Ran 24 tests` — OK |
| `walker-policy-receipt-probe` | `Ran 26 tests` — **5 errors, pre-existing** |

The five `walker-policy-receipt-probe` errors are `test_probe.SourceTests.*`
(`test_actual_AI40_readonly_and_current_pins`,
`test_exact_one_clause_and_one_import_only`,
`test_minimal_closure_no_scene_controller_or_world`,
`test_missing_duplicate_or_modified_source_fails_closed`,
`test_virtual_stage_seals_reject_tampering_without_staging`) reading a
`cocs-walker-parity-admission-ai` root this worktree does not materialise. They are
the **same five** as in my original review, and
`git diff --name-only 62ed480e 8d4be734 | grep -c walker-policy-receipt-probe` is
**0** — the fix commits touched no file in that package.

The producer's numbers all reproduce.

---

## 2. The C1 claim, verified claim by claim

> `history.reference` → `amFrozenOperands` (derived from the SHA256-pinned AM guard request)

**CONFIRMED.** `history._am_frozen_operands` (`history.py:54-98`) projects the
pinned export's `fresh-guard-down32` `rawRequestResponse` down to `hook.CONSTANTS`,
refuses a missing operand by name rather than defaulting it, derives `motion` from
the *recorded* margin rather than copying the recorded motion, checks the recorded
motion against the derivation within `DERIVED_MOTION_EPSILON`, and finally runs the
result through `hook.frozen_tuple`. `history.load_export` verifies the export's
SHA256 **and its byte size** before any of that. Measured:

```
reference-035-015-neg45  recorded motion=[0.0, -0.0200999993830919, 0.0]
                         derived       =[0.0, -0.0200999995529652, 0.0]   gap=1.699e-10
failure-042-018-neg45    identical recorded motion and derived motion       gap=1.699e-10
DERIVED_MOTION_EPSILON = 1e-09, i.e. 5.9x the float32 rounding gap
```

A one-byte edit inside the pinned export is refused
(`HistoryError: approved diagnosis export drift`), and the anchor carries the
*derived* motion, so the anchor is exact rather than float32-shaped. That is the
right construction and it is documented.

> `prepare.contract` → `proposal.frozenOperandsByCase`

**CONFIRMED.** `prepare.py:118-119` reads it out of `frozen_history`, which is
`history.reference(...)` against the pinned root. The shape placeholder
`frozenConstants` still carries `body_rid=1` and says why, so the table, not the
placeholder, is the authoritative per-case set.

> `driver.run_case` refuses operands differing from that table and records the frozen tuple per case

**CONFIRMED, and stronger than claimed.** `driver.py:169-181` compares the live
plan's frozen operands against `historical['amFrozenOperands']` over
`DESIGN_FROZEN_CONSTANTS + DERIVED_FROZEN_CONSTANTS` **before anything executes**,
and `driver.py:324-337` records `frozenOperands` plus the record's own
`history.amFrozenOperands`. Dropping the live-side anchor is **KILLED** (both by
deletion and by the shape-preserving variant S-12, whose killer is
`test_the_driver_refuses_a_live_plan_whose_frozen_operands_were_re_tuned`).

> `campaign.compose` carries it into the receipt from the case records

**CONFIRMED.** `campaign.py:58` is a literal
`{row['caseId']: row['frozenOperands'] for row in records}` — a read, not a
recomputation, so `campaign.py` cannot substitute a different set. Dropping the
receipt-level table-vs-record comparison is **KILLED** (S-11, killed by
`test_a_re_tuned_or_malformed_frozen_tuple_is_refused`).

> `evidence._frozen_operands` enforces three layers, each fail-closed

**CONFIRMED for the well-formedness and the tuple/pairwise layers; implemented as
described for the anchor layer, but the anchor layer is untested** — see §5.

The constants really do partition, and I checked the partition:

```
CONSTANTS                 = motion, margin, maxCollisions, recoveryAsCollision,
                            collideSeparationRay, bodyRid, excludeBodies,
                            excludeObjects, testOnly                      (9)
DESIGN_FROZEN_CONSTANTS   = margin, maxCollisions, recoveryAsCollision,
                            collideSeparationRay, excludeBodies,
                            excludeObjects, testOnly                     (7)
DERIVED_FROZEN_CONSTANTS  = motion                                       (1)
RUN_FROZEN_CONSTANTS      = bodyRid                                      (1)
                                                     7 + 1 + 1 = 9, exact, disjoint
```

---

## 3. The three-layer validator predicate, layer by layer

### 3.1 Layer 1 — well-formedness (`hook.frozen_tuple`) — **genuinely covered**

Exact `CONSTANTS` key set, positive integer RID, margin yielding nonzero motion,
`motion == down_motion(margin)` **exactly**, contact cap 32, the two true flags
plus test-only, empty exclusions. Nothing repaired or defaulted; `HookError`
otherwise. Each of the seven checks is **KILLED** both by deletion
(WF-01…WF-07) and by the shape-preserving variant that keeps the expression but
neuters the refusal (S-09, S-10), both by
`test_the_predicates_are_reported_individually_and_never_repair`, which exercises
`frozen_tuple` and `operands_unchanged` **directly** rather than through a receipt.

One survivor here: **WF-03**, dropping the "margin must yield a nonzero motion"
refusal. It survives because `down_motion(margin)` refuses the same case anyway
(`margin + LIMIT <= 0`) and the derived-motion check then fails. Genuinely
redundant, and correctly so.

`frozen_tuple` also refuses every malformed shape I threw at it (empty dict,
`bodyRid` 0, `bodyRid` 1.5, `margin` −0.02, mismatched `motion`, dropped key,
`maxCollisions` 16, non-empty exclusions, extra key, `None`, `'frozen'`).

### 3.2 Layer 2 — the cross-observation comparison (`hook.operands_unchanged`) — **genuinely covered**

Checked two ways, as documented: each of the three requests against the recorded
tuple on **all nine** constants, and all three pairwise against each other.
Both halves are **KILLED** both ways (C1-02/C1-03 by deletion, S-07/S-08 by
neutering). Differences are reported as `request<i>:<key>` and `<i>~<j>:<key>`, and
`test_the_predicates_are_reported_individually_and_never_repair` asserts the exact
labels, so the reporting is not decorative.

### 3.3 Layer 3 — the anchors — **implemented, load-bearing, and untested**

Four anchors exist:

| anchor | site | deleting it | neutering it | my forger |
|---|---|---|---|---|
| design-frozen constants == the pinned AM guard's | `evidence.py:153-155` | KILLED (by a `co_names` assertion, see §5.1) | **SURVIVED (S-01)** | **a real forgery gets through** |
| record's own AM binding == the anchor, all nine constants | `evidence.py:161-163` | survived | **SURVIVED (S-02)** | nothing new |
| bound `bodyRid` == recorded tuple `bodyRid` | `evidence.py:166-167` | survived | **SURVIVED (S-03)** | nothing new |
| record-level history binding == `historical`, all nine constants | `evidence.py:335-338` | survived | **SURVIVED (S-05)** | nothing new |

Neutering any single anchor lets no forgery through, because the others hold. The
chain is genuinely deep. Neutering all four at once opens six of my forgeries
(F7, F8, F9, F10, F29, F30). Each *deletion* is caught by the next check down
except the design-frozen anchor, whose deletion is caught only by a source-shape
assertion. **This is the substance of N2.**

---

## 4. My forger model — 51 forgeries

Every edit re-derives `recordsSha256` with the attacker's own code. Every forgery
is preconditioned on `_plan`, `frozen_tuple` and `_observation` all still passing,
so a refusal is attributable to the C1 layer.

```
forgeries attempted:                       51
refused by the C1 layer (precondition ok): 28
refused, but a non-C1 predicate also fires: 18   (not counted as C1 kills)
ACCEPTED:                                   5
```

### 4.1 The producer's headline numbers reproduce

> *"a 12-edit forger model with re-derived `recordsSha256` → 12 refused / 0
> accepted"*

My equivalent (F1–F12) is **12 attempted, 12 refused, 0 accepted**. Eleven of them
(F1–F11) are C1 kills with the per-observation precondition intact — the anchor is
really what stops them. F12, a consistent `testOnly: False` re-tune, is refused one
layer earlier, by `frozen_tuple` itself, because such a tuple is malformed by
construction; I count it as a refusal but not as a C1 kill.

### 4.2 My original six re-tunings — all six refused, all six genuine

The six forgeries my original forger model accepted at `62ed480e`:

| # | forgery (digest re-derived) | at `62ed480e` | at `88214d99` | C1 layer |
|---|---|---|---|---|
| F1 | guard request margin 0.0200 → 0.0150, motion kept consistent | ACCEPTED | **REFUSED** | yes |
| F2 | guard request motion re-tuned, kept self-consistent | ACCEPTED | **REFUSED** | yes |
| F3 | guard request bodyRid re-tuned | ACCEPTED | **REFUSED** | yes |
| F4 | duplicate margin 0.0200 → 0.0150, motion kept consistent | ACCEPTED | **REFUSED** | yes |
| F5 | duplicate bodyRid re-tuned | ACCEPTED | **REFUSED** | yes |
| F6 | pre-UP request bodyRid re-tuned | ACCEPTED | **REFUSED** | yes |

Two honesty notes on this table. F1 and F2 are **the same edit expressed two ways**:
a self-consistent margin re-tune has to move `motion` with `margin`, so there is
only one hard forgery on the guard's request, and I ran it twice to be certain.
Likewise F4 is F1 against the duplicate and F6 is F3 against the pre-UP request, so
the six rows are three distinct attacks on three observations. I have not inflated
that into six independent findings.

Plus the harder shape the first review could not produce: **F8**, a *consistent*
re-tune of all three requests, the recorded tuple, the record's own AM binding and
the receipt's per-case table together — **REFUSED**, precondition intact. And
**F10**, the same across both cases simultaneously — **REFUSED**.

The root cause my original review located is genuinely gone. `evidence.record` no
longer validates observations in isolation; the receipt no longer lacks a tuple to
compare against; `prepare.py:106`'s `bodyRid: 1` placeholder is no longer the only
authoritative operand set. This is the fix the review asked for.

### 4.3 What I got through, and what each acceptance means

**F17 — a guard margin re-tuned by 5e-13, accepted. Not a forgery.**
`hook.operand_equal` compares numerics within `OPERAND_EPSILON = 1e-12`, which is
documented as "six orders of magnitude below the 1 µm guard budget, so it cannot
absorb any physical difference; it only absorbs double round-tripping". 5e-13 m is
one **picometre** on a 20 mm motion — 2.5e-11 relative, and six orders of magnitude
below the guard's own 1e-6 m numeric budget. At 1e-11 the same re-tune is refused
(F18). Loosening `OPERAND_EPSILON` to 1e-3 is **KILLED** (AN-04). I record the
boundary because it is the one place the tuple comparison is not exact equality,
and because a reviewer should be able to see it is deliberate and quantified.

**F33, F34 — a consistent re-tune accepted *when I also fabricate the `historical`
anchor I hand the validator*.** This is precisely the producer's declared deferred
item, and §6.3 shows the binding is real. **F35/F36 — a fabricated anchor with no
re-tune at all is accepted**, which is a no-op and shows nothing.

### 4.4 The methodological point that matters most in this document

My first forger pass reported 47/48 refused. It was wrong about *why*. In a real
record, observation 3 (the guard) has `request is result` — the validator even
asserts that identity — while observations 1 and 4 (pre-UP, duplicate) have
**distinct** `request` and `result` objects. So an edit to those requests leaves a
stale result behind, and `evidence._observation` refuses the forgery at
`evidence.py:76` and `:90-92` **before the C1 layer is ever reached**. I found this
by preconditioning every forgery, and it changed my attribution of 18 of 51 rows.
**The shipped suite has the same blind spot, in its most important test.** See §5.2.

---

## 5. Does the new `FrozenOperand` class actually exercise the checks?

Twelve tests, and the honest per-predicate answer is: **yes for the tuple, the
pairwise comparison and `frozen_tuple`; no at all for the four anchors.**

### 5.1 Which test kills which mutation

| mutation | killed | killer |
|---|---|---|
| C1-01 drop the `_frozen_operands` call | yes | `test_a_re_tuned_or_malformed_frozen_tuple_is_refused`, `test_the_reviewers_six_constant_retunings_are_all_refused` |
| C1-02 drop the tuple comparison | yes | `test_the_predicates_are_reported_individually_and_never_repair` |
| C1-03 drop the pairwise comparison | yes | `test_the_predicates_are_reported_individually_and_never_repair` |
| C1-04 drop the design-frozen anchor | yes | `test_no_source_in_this_package_claims_a_verdict_or_neutrality` — an **introspection** test asserting `DESIGN_FROZEN_CONSTANTS` appears in `evidence._frozen_operands.__code__.co_names` |
| C1-07 ignore `operands_unchanged`'s verdict | yes | `test_the_reviewers_six_constant_retunings_are_all_refused` |
| C1-09 drop the receipt-table comparison | yes | `test_a_re_tuned_or_malformed_frozen_tuple_is_refused` |
| **C1-05 / C1-06 / C1-08 drop one anchor** | **no** | none |

C1-10 (dropping the receipt table's key-set check) was also KILLED; I did not capture
its killer separately, so I make no claim about which test carries it.

The shape-preserving variants confirm the split. S-01 keeps
`hook.operand_equal(approved, frozen, keys=hook.DESIGN_FROZEN_CONSTANTS)` and the
docstring, and only neuters `if not equal:` — so the `co_names` assertion still
passes — and **the whole 91-test suite is green while a consistent re-tune of all
three requests plus the recorded tuple plus the receipt table is accepted.** My
forger confirms it directly: S-01's only new acceptance is F7.

Per-test measurement over all twelve `FrozenOperandTests`:

```
neuter the design-frozen anchor      carried by 0/12 FrozenOperandTests
neuter the binding anchor (inner)    carried by 0/12
neuter the bodyRid anchor            carried by 0/12
neuter the binding anchor (record)   carried by 0/12
```

**Zero.** For contrast, C1-01 and C1-07 — which remove the layer entirely — are
killed by real behavioural negative cases, so the tuple comparison *is* carried.

### 5.2 The specific test that does not carry the anchor

`test_retuning_all_three_requests_together_is_still_refused`
(`test_compare.py:386-406`) is the one test that exists to prove the design-frozen
AM anchor works. Its helper `retune` edits only `observation['request']`:

```python
for observation in row['observations']:
    self.retune(observation['request'], margin=0.0150)
```

For observation 3 that is enough, because `request is result`. For observations 1
and 4 it is **not**. I ran the producer's own edit through the validator and dumped
what it leaves behind:

```json
{ "baseline_validates": true,
  "their_forgery_refused": true,
  "pre_up request margin": 0.015,   "pre_up result margin": 0.0199999995529652,
  "guard  request margin": 0.015,   "guard  result margin": 0.015,
  "dup    request margin": 0.015,   "dup    result   margin": 0.0199999995529652,
  "frozenOperands margin": 0.015,
  "per_observation_intact": false }
```

`per_observation_intact: false` is the whole finding: the pre-UP and duplicate
observations no longer match their own results, so `evidence._observation` refuses
at the isolation predicate and `_frozen_operands` is never consulted. The test is
green at HEAD and **stays green with the design-frozen anchor neutered** — I ran
that single test under S-01 and it reports `OK`.

Mirroring the edit into each observation's own `result` (one extra line per
observation) makes it a genuine anchor test: my F7 is refused at HEAD and accepted
under S-01.

I note two mitigating facts, so this is stated fairly:

* the six re-tunings in `test_the_reviewers_six_constant_retunings_are_all_refused`
  **are** genuinely carried — C1-01 and C1-07 are killed by exactly that test, so at
  least some of its six reach the C1 layer;
* `test_the_predicates_are_reported_individually_and_never_repair` gives direct
  unit coverage of `frozen_tuple` and `operands_unchanged`, which is better than
  nothing and better than most packages manage.

This is a **test-methodology gap, not a hole**: the anchor is implemented, it is
enforced, and I proved its load-bearing role by neutering it and by forging. It is
P2-4 from my original review, in a new place.

### 5.3 Layered drops — the producer's claim is confirmed, and is stronger than claimed

> *"the 10 survivors are each redundant defence-in-depth, confirmed load-bearing by
> pairing each with the mutation it shields (dropping all four validator layers at
> once, or the tuple comparison plus any single anchor, is KILLED)"*

Confirmed, and I can be more specific than "KILLED":

| combination | shipped suite | my forger |
|---|---|---|
| L-01 tuple comparison + all three in-function anchors | **KILLED** | F7 accepted |
| L-02 tuple comparison + design-frozen anchor | **KILLED** | F7 accepted |
| L-03 tuple comparison + binding anchor (inner) | **KILLED** | nothing new |
| L-04 tuple comparison + bodyRid anchor | **KILLED** | nothing new |
| L-05 tuple comparison + the whole `_frozen_operands` call | **KILLED** | 6 new |
| L-06 pairwise comparison + design-frozen anchor | **KILLED** | F7 accepted |
| L-07 pairwise comparison + all three anchors | **KILLED** | F7 accepted |
| L-08 the `_frozen_operands` call + the record binding + the receipt table | **KILLED** | **13 of 14 accepted** |

L-03 and L-04 — "the tuple comparison plus any single anchor" — are the two the
producer did not name specifically, and they are killed. L-08 is worth a note: the
suite catches it through tests written for other purposes while nearly every forgery
in my model becomes possible, which is the signature of a defence-in-depth stack
whose parts are individually necessary and collectively sufficient.

My full ledger: **47 mutations, 39 KILLED, 8 survived, 0 no-match failures.** The
eight survivors and whether my forger gets through:

```
C1-05  binding==approved anchor (inner)      forger: nothing new   redundant
C1-06  bodyRid anchor                         forger: nothing new   redundant
C1-08  record-level binding comparison        forger: nothing new   redundant
WF-03  frozen_tuple nonzero-motion refusal    forger: nothing new   redundant
AN-01  history derived-motion near() check    forger: nothing new   see N3
AN-06  history missing-operand refusal        forger: nothing new   see N3
OLD-02 recorded-before/after-UP labels        forger: nothing new   inherited
OLD-03 event-log order predicate              forger: nothing new   inherited
```

`OLD-02` and `OLD-03` are the two survivors my original review already recorded
(its P2-4). They are unchanged, still honest, and still not gaps: I confirmed again
that both predicates are genuinely load-bearing under the forger model.

---

## 6. Non-blocking observations

### N1 — the validator pins the run-frozen body RID to the AM run's RID, contradicting the package's own documented rule

`hook.RUN_FROZEN_CONSTANTS` (`hook.py:56-64`) says:

> *"assigned by the engine for one run and frozen into the prepared record before
> execution. Provenance is the run itself, so these are pinned by being identical
> across the pre-UP request, the guard's own request and the duplicate, **not by
> comparison with the AM value**."*

`driver.py:175` honours that — its live-side anchor compares
`DESIGN_FROZEN_CONSTANTS + DERIVED_FROZEN_CONSTANTS` and deliberately excludes
`bodyRid`. **`evidence._frozen_operands` does not.** It compares
`historical['amFrozenOperands']` to the record's own binding on **all nine**
constants (`evidence.py:161-163`, `bodyRid` included) and then compares
`bound['bodyRid']` to `frozen['bodyRid']` (`evidence.py:166-167`). The validator
therefore anchors `bodyRid` to the AM run's RID, twice, against its own
documentation.

Demonstrated end to end with a genuinely per-run RID, used consistently by the plan
params and by the guard's own recorded request:

```
reference-035-015-neg45: driver ACCEPTS fresh per-run RID 777000333
    recorded tuple bodyRid        = 777000333
    record history binding bodyRid= 154618822659   (the AM run's)
    all three requests agree      = True
    per-observation predicates intact (_plan/_observation/frozen_tuple): True
    evidence.record               -> False
    evidence._frozen_operands     -> False
campaign.assert_receipt REFUSES the fresh-RID receipt:
    CompositionError: case record failed validation: reference-035-015-neg45
```

The suite can never surface this because `fixtures.PROFILES` copies the AM RIDs
verbatim (`154618822659`, `274877906947`) — as its own comment says, "taken
verbatim from the reviewed AM receipt so the synthetic fixture cannot drift into a
new shape".

**Direction of the defect.** This makes the check *stricter*, not looser, so it
opens no C1-class forgery and is not a C1 blocker. It is a correctness defect for
the next stage: the first real native run, where Godot assigns a fresh RID, would
produce a record the driver accepts and the validator refuses, and a GDScript mirror
would inherit the contradiction. **Decide it before staging**, either by pinning
the RID and correcting `hook.RUN_FROZEN_CONSTANTS` plus `driver.py:175` to say so,
or by removing the validator's two RID comparisons and keeping the documented
rule. Whichever is chosen, the prose and the code must agree — the whole point of
C1 was that they did not.

### N2 — the four anchors have zero behavioural test coverage

§5.1 and §5.2. The one-line fix is to mirror each observation's edit into its own
`result` in `test_retuning_all_three_requests_together_is_still_refused`, and to add
the same for the two `bodyRid` anchors and the record-level binding comparison.
Until then, a straight deletion of the design-frozen anchor is stopped by a
`co_names` introspection assertion, and a *neuter* of it is not stopped by anything.

### N3 — two history-provenance refusals survive and cannot be reached from a receipt

`AN-01` (the derived-motion `near()` check) and `AN-06` (the missing-operand
refusal) both survive the suite, and neither can be reached by editing a receipt —
they guard `history`'s reading of the SHA256-pinned export, which no receipt can
influence. Probed directly against the shipped code, both **do** work:

```
corrupt recorded motion (-0.9999) -> refused: recorded AM guard motion is not the
    derived down32 motion ...: [0.0, -0.9999, 0.0] vs [0.0, -0.0200999995529652, 0.0]
missing maxCollisions              -> refused: recorded AM guard request omits frozen
    operands for reference-035-015-neg45: maxCollisions
```

So they are untested, not broken. I record them so a future reviewer does not
re-derive them. They would become reachable if a future change ever let the export
path be parameterised by something other than the pinned root.

### N4 — cosmetic, carried forward from the original review

`prepare.py:17-19` now imports `hook` before `history`, which is correct
alphabetical order and closes the original P2-6 second half. The original P2-6
first half (the duplicated comment fragment above `PLANNED_ARGV_TEMPLATE`) is
merged into one docstring. Both closed. Nothing new to report here.

---

## 7. C2, C3, C4 — status

### C2 — delivery report self-description — **CLOSED**

* All **15** Files-table line counts now match `wc -l` exactly:
  README 201, `__init__` 6, `cli` 34, `policy` 161, `hook` 485, `driver` 363,
  `evidence` 480, `campaign` 87, `history` 182, `prepare` 261, `supervisor` 210,
  `invocation` 96, `seals` 125, `fixtures` 222, `test_compare` 1578. The four the
  original review found wrong (`prepare.py` 250→248, `supervisor.py` 207→211,
  `seals.py` 127→125, `test_compare.py` 1038→1174 at the old tip) are among the
  fifteen, and the last is now 1578.
* The report's own digest line is **gone**, replaced by prose that states why it
  cannot exist and names the two ordinary ways to verify the file
  (`git hash-object` on the committed blob, or `sha256sum` at the delivery commit
  named in the header). That is exactly what the original review asked for.
* **All 15 per-file sha256/byte pairs in the report verify against the committed
  blobs at `88214d99`** — 15/15 on both the digest and the byte count, checked by
  `git show 88214d99:<path> | sha256sum` rather than against the working tree.
* All pinned references verify: the five `godot/*.gd` files, the new
  `walker-calibrated-admission/evidence.py` pin, the design review, and both
  diagnosis artifacts.

### C3 — `policy.NATIVE_READINESS_BLOCKERS` pinned — **CLOSED**

`test_the_native_readiness_blockers_are_pinned_verbatim` compares the tuple against
**six literals**, plus a length check, plus a no-vacuous-entry check (every entry a
`str`, length ≥ 20, not one of `''`/`n/a`/`na`/`none`/`ready`/`.`, and starting with
`no `, `zero-motion` or `AM `), plus a receipt-side assertion that the six are
carried and that the validator requires them exactly. Comparing the list against
itself — the original defect — no longer happens anywhere in that test.

Verified by mutation, both ways:

| mutation | result |
|---|---|
| append ` (n/a)` to one blocker | **KILLED** |
| delete one blocker entry entirely | **KILLED** |

Both of these **survived** the original review.

### C4 — `numeric_budget` oracle pinned — **CLOSED**

`tools/godot-multiplayer/new-maps/walker-calibrated-admission/evidence.py` is now
in `prepare.REFERENCES` with SHA256
`d403a92438d36b904ee02beca8dc3ae0452334f24f65b505553f4ef64017c379`, which I
confirmed is that file's actual digest. `test_numeric_budget_matches_the_frozen_guard`
independently asserts `assertIn(name, prepare.REFERENCES)` and the digest equality
before loading the module, and then compares `hook.numeric_budget` to `budget` on
five domains including `nan` and the 1e6 refusal. The pin is load-bearing, not
decorative:

| mutation | result |
|---|---|
| corrupt the pinned hash by one character | **KILLED** |
| delete the pin from `REFERENCES` entirely | **KILLED** |

One naming note, for accuracy only: the commit message calls that file "the
`numeric_budget` oracle". `hook.numeric_budget` is this package's *port*; the
sibling module's function is `budget` (`evidence.py:31`). The pin covers the right
file and the test compares the right pair of functions. No defect.

---

## 8. The three reviewed design notes — all three unchanged and still correct

Measured on a clean reference run, not read.

**1 — zero-motion omitted, no epsilon substitution anywhere. CONFIRMED, unchanged.**
Both design zero-motion observations are omitted at ordinals 2 and 5 on both cases,
each with `executed: false`, `substitutedMotion: null`,
`substitutionRefused: true`, `requestedMotion: [0, 0, 0]` and the single reason
`exact_zero_motion_semantics_undefined`. All three executed observations carry
`motion [0, -0.0200999995529652, 0]`, `margin 0.0199999995529652`. Refused:
`requested_motion` of `[0,-1e-9,0]`, `[0,-0.0001,0]`, `[0,-1e-15,0]`,
`[0,1e-9,0]` — "only exact-zero motion may be omitted; epsilon substitution
refused" — and any `substituted_motion`, "epsilon substitution refused: an omission
carries no substituted motion". `hook.exact_zero([0,-1e-9,0])` is `False` while
`hook.zero([0,-1e-9,0])` is `True`, so the strict predicate is the one in use.
Mutation: relaxing `exact_zero` to `zero` — **KILLED**.

**2 — horizontal agreement required, vertical offset recorded. CONFIRMED, unchanged.**

| | `.35/.15/−45°` | `.42/.18/−45°` |
|---|---|---|
| `predictedEndpoint.y` | 0.172130957245827 | 0.20213095843792 |
| `expectedFinal.y` | 0.0877559557557106 | 0.0544746965169907 |
| **`verticalOffsetFromPredictedEndpoint`** | **−0.0843750014901164** | −0.1476562619209293 |
| `horizontalAgreementError` | 1.05367e-08 | 1.05367e-08 |
| `epsilon` (8 float32 ULPs) | 1e-06 | 1e-06 |

`.35` is exactly `−0.0843750014901164` and `.42` exactly `−0.1476562619209293`, both
by `==` against the reviewed values. The horizontal error is real and non-trivial —
1.05e-08 m, three orders of magnitude inside the budget — not a rounded zero.
The validator binds the recorded offset **by equality** to
`expectedFinal[1] - predictedEndpoint[1]`. Both directions are **KILLED**: forcing
`vertical_offset = 0.0` in the driver, and making the validator demand zero.

**3 — the validator does not apply the 46° predicate. CONFIRMED, unchanged.**
The recorded AM guard normal angles are 36.67732574092844° (inside) and
47.476992341452714° (outside). `evidence.receipt` and `evidence.record` have no
`floor_angle` parameter and reference none of `floor_angle`, `radians`, `cos` or
`degrees` in their own code objects. `hook.valid_result` — the only place a
`math.cos(floor_angle)` comparison exists — is never called by `evidence.py`.
Decisive test repeated: replacing the failure case's contact normal with a
unit-length `[0.6007, 0.7994, 0.0]` (53.13°) and re-deriving the digest, the
validator **accepts**. Mutation: adding the 46° predicate to `_observation` —
**KILLED**.

I also re-confirmed the two adjacent claims: the guard's result and fault are
preserved verbatim (`passed`/`reason`/`candidateFault` as returned, with
`preservedIntact: true`, and a fault that does not match the guard's own reason is
refused), and the receipt's `guardOutcomesAgreeWithHistory` must be *true to what
was recorded* rather than simply true.

---

## 9. The deferred item, judged honestly

The producer states it in `hook.py`, the README and the report rather than papering
over it: *"from a self-attested record the validator proves that the three requests
agree with each other and with one operand set anchored to the pinned AM history.
That the recorded tuple is the one the driver froze is the prepared source record's
role, bound by `sourceSha256`, and a GDScript `evidence.gd` mirror must carry all
three layers whole or the claim becomes false again in GDScript."*

**Is it documented where it must be?** Yes, in all three of the three places the
original C1 named, including the `hook.py` module docstring, which is the exact
sentence that was false before.

**Is the binding real?** Yes, and I verified each link rather than accepting it:

1. The prepared record's `proposal.frozenOperandsByCase` **equals** the SHA256-pinned
   AM anchor for both cases — checked, `True` for both. It is written before
   execution by `prepare.build`.
2. `prepare.validate_record` refuses a hand-edited record
   (`PrepareError: seal verification failed: seal tampering: source-record.json`),
   and it *additionally* recomputes `contract()` from the pinned root and requires
   equality, so re-sealing an edited record would fail the contract comparison too.
3. The pinned artifact is pinned: a **one-byte** edit inside
   `walker-support-normal-diagnosis/comparison.json` is refused with
   `HistoryError: approved diagnosis export drift`. I restored the file and
   confirmed the digest matches again.
4. **No shipped code path lets a receipt influence the anchor.**
   `evidence.receipt(value, *, source_hash, grant_hash, engine_hash, historical)`
   takes `historical` as an argument, and the only two call sites of
   `history.reference` are `prepare.py:109` and `supervisor.py:63`, both
   parameterised on the pinned `ROOT`. Nothing inside the receipt is ever used as
   the anchor.

**Does it leave any C1-class forgery open at the validator boundary?** No.

My F33/F34 are the sharpest form of the attack — a fully consistent re-tune of all
three requests, both recorded tuples, both AM bindings and both receipt table
entries, with the `historical` argument the validator is handed fabricated to match
— and they are accepted only because I fabricated the validator's *input*. That is
outside the receipt entirely, and no shipped path constructs such an input. Against
a validator handed the real anchor, F33/F34 are refused, as is the same forgery with
one case, with a tiny margin shift, and with both cases at once (F7–F11).

The residual is exactly what the producer says it is, and it is a *documented*
residual: from a self-attested record the validator cannot prove that the tuple is
the one the driver froze. It can prove that the three requests agree with each other
and with one tuple that is anchored to an independently pinned artifact. Since
`prepare.validate_record` seals and re-derives that tuple before execution and
`sourceSha256` binds the receipt to the record, the chain is complete on the
producer's side and the validator's job ends where it is honestly said to end. I
found no path by which the gap becomes a forgery.

**The one addition I would require** is the mirror discipline the producer already
states, restated as a gate: a GDScript `evidence.gd` must carry all three layers
whole, including the SHA256-pinned export read and the source-record binding, and
N1's RID contradiction must be settled before it is derived — a mirror that ports
the current `bodyRid` anchoring would refuse every genuine run, and a mirror that
"fixes" it would diverge from the Python validator it is supposed to agree with.
The original review's §8 requirement list is otherwise unchanged.

---

## 10. Scope statement

This is a **source-only independent re-review**. Explicitly:

* **Source only.** No engine, no native parser or import, no renderer, no server,
  no child job, no native stage, no grant was created, resolved, staged or
  executed. No Godot, no Blender, no native binary. The only processes I started
  were `python3 -m unittest` inside a shadow root under `/tmp/opencode`.
* **No native readiness is conferred.** `nativeReadiness.ready` remains `false`
  with the six verbatim blockers. Blocker 1 ("no independent source review of this
  package") is discharged *as a source review* by the original review at `7733051a`
  and reaffirmed here; **blockers 2–6 are untouched and unaddressed.** This
  re-review discharges no new blocker and softens no entry.
* **Integrating this package does not authorize an engine run.** It creates no
  grant, stages no GDScript, and adds no engine-invocation path. Doing any of those
  remains a separate, separately reviewed act, and would require changing
  `invocation.audit`'s forbidden sets as a deliberate change.
* **AM stays failed.** Whole calibrated positive admission remains FAIL; the
  `.42/.18/−45°` candidate had one applied lift and **zero** verified.
* **`.42/.18/+45°` stays unrun.** It is absent from the case set, and I re-confirmed
  in the first review that it cannot be added without breaking the suite. No new
  case exists.
* **The 60 map journeys, the 184 static Vesper failures and production accounting
  are untouched** and remain open. `candidateMapWalks` is 0.
* No test acceptance in this package is a native pass, and every "measurement" in
  the suite and in my probes comes from an in-memory fake answering from frozen AM
  operands. No claim in this document converts one into evidence.
* Zero-motion semantics remain undefined. The two omissions stay omitted until a
  source review establishes them; this re-review did not establish them.
* The AM qualifications are inherited unchanged: `backendImplementationVerified =
  false`, `parentInternalCallsTraced = false`, `physicalCallCounts = null`. This
  package adds no observation that would lift them, and its receipt requires them to
  stay false.
* **The original review document remains immutable.** Nothing in this addendum
  modifies, supersedes or retracts
  `WALKER_SUPPORT_QUERY_COMPARE_REVIEW_20261005.md` at `7733051a`
  (blob `cad076cd6e6e5dc3ae593a68651651451e835ede`). Where I disagree with it —
  §4.4's methodology, and the original P2-4's location now also having a second site
  — the disagreement is stated here, in a separate document.

---

## 11. What would be required before the mirror

Unchanged from my original review's §8, with two amendments from this document:

1. **C1 — discharged.** The check exists; the claim is true.
2. **N1 — settle the body-RID anchoring before the mirror is derived.** Either pin
   the per-run RID and correct `hook.RUN_FROZEN_CONSTANTS` and `driver.py:175`, or
   drop the validator's two RID comparisons and keep the documented rule. Whichever
   is chosen, prose and code must agree in both languages.
3. **N2 — one-line test correction.** Mirror each observation's edit into its own
   `result` in `test_retuning_all_three_requests_together_is_still_refused`, and add
   the equivalent for the two `bodyRid` anchors and the record-level binding
   comparison. Not a gate on the mirror, but the mirror's agreement test should not
   be modelled on a test that does not reach the layer it names.
4. C2, C3, C4 — discharged.
5. Unchanged from the producer's own list, and still required: staging and grant
   creation under a reviewed namespace; a real GDScript `LiveMeasurement` with the
   ordering enforced engine-side; a real supervisor with the reviewed lock,
   consume-before-launch marker, owned-group cleanup, post-exit log scan, measured
   release audits and a timeout; and a native smoke fixture.

---

## 12. Commands of record

```
git checkout -b review/walker-support-query-rereview-20261005   # at 8d4be734, clean
git diff --stat 7733051a 88214d99                               # 13 files, +944/-753
cd tools/godot-multiplayer/new-maps/walker-support-query-compare
python3 -m unittest test_compare                                 # Ran 91 tests ... OK
grep -c "    def test_" test_compare.py                          # 91
# shadow root, built from only the files the package reads
python3 -m unittest test_compare                                 # Ran 91 tests ... OK
python3 /tmp/opencode/sqc-rereview/forger2.py                    # 51 forgeries
python3 /tmp/opencode/sqc-rereview/mutate.py                     # 47 mutations
python3 /tmp/opencode/sqc-rereview/shape-mutants.py              # 12 shape-preserving
python3 /tmp/opencode/sqc-rereview/anchor-chain.py               # redundancy chain
python3 /tmp/opencode/sqc-rereview/per-test-coverage.py          # 0/12 per anchor
python3 /tmp/opencode/sqc-rereview/notes.py                      # 3 design notes
python3 /tmp/opencode/sqc-rereview/bodyrid.py                    # N1
python3 /tmp/opencode/sqc-rereview/deferred.py                   # §9
sh /tmp/opencode/sqc-rereview/verify-hashes.sh                   # 15/15 + 9 references
# surrounding suites, unchanged from the producer's table
walker-support-normal-diagnosis 8 OK · walker-calibrated-admission 30 OK
walker-parity-admission 49 OK · walker-baseline-characterization 5 OK
walker-parity-response 24 OK · walker-policy-receipt-probe 26, 5 pre-existing errors
```

---

*Re-review conducted read-only against `88214d99`/`f311f667`/`8d4be734`. Nothing was
pushed, merged or rebased. The delivery branch tip
`spacebunny/walker-support-query-20261005` remains in `refs`. Only this document is
committed, on `review/walker-support-query-rereview-20261005`. No file in the
delivery, in `godot/`, in any sibling walker package, or in the original review
document was modified. The one temporary artifact touched outside `/tmp` — the
pinned `comparison.json`, deliberately, to prove drift is refused — was restored and
its digest re-verified in the same run.*

---

# N1/N2 closure addendum

Dated section, appended after the body above. **Nothing above this line is
modified**: §§0–12 stand exactly as written at `39b8fe3f`. This addendum closes
the two pre-staging observations §6 N1 and §6 N2 recorded there, and is the only
change committed on this branch.

Reviewer session: independent source re-review, final short confirmation pass.
Branch: `review/walker-support-query-rereview-20261005`, continuing from **`39b8fe3f`**.
Producer branch: `spacebunny/walker-support-query-20261005`, tip **`85ace87b`**.
Producer commits re-reviewed: **`33809aad`** (N1 settlement + N2 anchor cargo),
**`b38dc12d`** (delivery hashes and re-review disposition), **`85ace87b`** (per-class
removal verification counts). N1/N2 semantic change: `8d4be734..85ace87b`.

Worktree: `/home/mojo/.tmp-on-disk/cocs-walker-support-normal-diagnosis`, clean
before and after; the producer tip remains in `refs`, was not pushed, merged or
rebased. All mutation work was done in throwaway copies under `/tmp/opencode`,
never in the delivery worktree.

## Verdict

| | status |
|---|---|
| **N1** — validator refused genuine per-run RIDs, contradicting the driver | **CLOSED** |
| **N2** — anchors lacked behavioural coverage | **CLOSED** |
| C1 / C2 / C3 / C4 | **remain closed**, re-verified below |

**No P1. No new blocker. No residual.** Both observations are closed on the
evidence, not on the producer's report of them. I re-derived every outcome from the
producer tip's own driver and validator code; where the shipped suite's own
methodology could have flattered the result I ran my own neuterings instead of its
`ANCHORS` table.

---

## 1. N1 — the run-frozen body RID. CLOSED.

### 1.1 What changed, and it is the documented rule that won

`8d4be734..85ace87b` on `evidence.py` changes the AM-value bodyRid comparison to the
run-frozen rule, which is what `hook.RUN_FROZEN_CONSTANTS` and `driver.py:175` already
said. Both of the AM-value comparisons my §6 N1 identified are gone, and the
design-frozen anchor and the binding anchor are untouched:

```
removed from evidence._frozen_operands:
    if bound['bodyRid'] != frozen['bodyRid']:      <- the second RID anchor
        return False
added, in the same place:
    equal, _ = hook.run_frozen_unchanged(frozen, *requests)
    if not equal:
        return False

untouched, byte for byte:
    equal, _ = hook.operand_equal(approved, frozen, keys=hook.DESIGN_FROZEN_CONSTANTS)
    if not equal:
        return False                              <- the SHA256-pinned AM guard anchor
    equal, _ = hook.operand_equal(approved, bound, keys=hook.CONSTANTS)
    if not equal:
        return False                              <- the record's own AM binding, all nine
```

I confirmed by reading the diff rather than by trusting the summary: `git diff
39b8fe3f..85ace87b -- '*evidence.py' '*hook.py' '*driver.py'` shows the design-frozen
anchor and the binding anchor unchanged, `driver.py` gaining only comments that now
cite `hook.run_frozen_unchanged`, and `hook.py` gaining the new predicate. My probe
then confirmed it mechanically:

```
"bound['bodyRid'] != frozen['bodyRid']" present in evidence.py : False
AM-value RID comparison anywhere in evidence.py                : False
run_frozen_unchanged called in evidence._frozen_operands       : True
design_frozen        called in evidence._frozen_operands       : True
CONSTANTS (all nine) still anchored in the binding anchor      : True
```

The `bodyRid` comparison is now *inside* `keys=hook.CONSTANTS` on the
`approved`-vs-`bound` pair — but both sides there are the AM run's **own** recorded
operands, so that comparison still says nothing about this run's RID. The new
`hook.run_frozen_unchanged` compares the run-frozen constants only, against the
record's own recorded tuple and pairwise across the requests. That is the documented
partition, and it is now the implemented one.

`driver.py` and the validator now agree, which is the whole point. `driver.run_case`
excluded `bodyRid` from its AM comparison before; the validator does too.

### 1.2 The three required outcomes, observed by me

Not read out of the test file — produced by the tip's own code.

**(1) A genuine fresh per-run RID is ACCEPTED.** Fresh RIDs `777000333` / `777000444`,
neither equal to the AM values `154618822659` / `274877906947`, used consistently by the
plan params, the fake live and the guard's own recorded request:

```
reference-035-015-neg45  driver status = stopped_after_duplicate_observation
    recorded tuple bodyRid = 777000333   (AM = 154618822659)
    request RIDs = [777000333, 777000333, 777000333]   results = [777000333, 777000333, 777000333]
    AM binding bodyRid      = 154618822659  (untouched)
    design-frozen anchor intact: True
failure-042-018-neg45   ... same, with 777000444 against AM 274877906947

campaign.assert_receipt  -> ACCEPTED (the whole receipt validated)
evidence.record accepts a single-case fresh-RID run, per case -> True, True
```

This is the case that was **refused** at `88214d99` with
`CompositionError: case record failed validation`. It is now accepted end to end, and
accepting it is a composition, not a return: `run_campaign` composes through
`campaign.assert_receipt`, so nothing above was taken on trust.

**(2) A per-request RID mismatch is REFUSED.** One observation's RID drifted by 1,
mirrored into its own `result` so the isolation predicates still pass, `recordsSha256`
re-derived by me:

```
precondition: _plan=True  frozen_tuple=True  all _observation=True   <- the layer is reached
design-frozen anchor still intact: True                             <- the AM anchor is not what refuses
run_frozen_unchanged -> (False, ['request2:bodyRid', '0~2:bodyRid', '1~2:bodyRid'])
operands_unchanged   -> (False, ['request2:bodyRid', '0~2:bodyRid', '1~2:bodyRid'])
evidence.receipt      -> REFUSED
```

Differing RIDs across two observations, the shipped test's shape, is refused with the
exact label set `['request0:bodyRid', 'request2:bodyRid', '0~1:bodyRid', '0~2:bodyRid',
'1~2:bodyRid']`. The refusal names which observation drifted and on which operand; it
is not a bare `False`.

**(3) An RID differing from the record's own binding is REFUSED.** The recorded tuple's
RID moved to `777000334`; the receipt's per-case table was made to follow it, so the
table-vs-record comparison cannot be what refuses:

```
recorded tuple bodyRid = 777000334  vs run requests [777000333, 777000333, 777000333]
design-frozen anchor intact : True
AM binding untouched        : True
run_frozen_unchanged -> (False, ['request0:bodyRid', 'request1:bodyRid', 'request2:bodyRid'])
evidence.receipt -> REFUSED
```

The pairwise half correctly stays silent — the three observations *do* agree with each
other, which is the whole shape of this forgery — and each is named as differing from
the record's own recorded binding. That is the right attribution.

### 1.3 Nothing was weakened

The settlement removed a comparison, so "nothing was weakened" needs evidence rather
than assurance. Three checks, all mine:

* **The six review re-tunings are still refused.** Each re-tuned into the
  observation's own `result`, digest re-derived by me:
  `guard margin / guard motion / guard bodyRid / duplicate margin / duplicate
  bodyRid / pre-UP bodyRid -> refused` (6 of 6).
* **The hard forgery is still refused.** A consistent re-tune of all three requests
  *and* the recorded tuple *and* the receipt's per-case table, with the precondition
  asserted rather than assumed (`_plan` ok, `operands_unchanged == (True, [])`) — so
  the only thing that can refuse it is the SHA256-pinned AM design-frozen anchor —
  **refused**.
* **Restoring the pre-N1 comparison is killed.** I re-inserted
  `if bound['bodyRid'] != frozen['bodyRid']: return False` ahead of the run-frozen
  call and re-ran the shipped suite: **FAILED (errors=4)** — all three run-frozen RID
  tests error out, including
  `test_a_genuine_fresh_per_run_body_rid_is_accepted_by_driver_and_validator`, because
  `run_campaign` now raises `CompositionError: case record failed validation`. The N1
  defect cannot come back unnoticed.

### 1.4 The docs now describe the implemented rule

Checked in all three places, since C1 was precisely a prose/code disagreement:

* `hook.py` module docstring and the `RUN_FROZEN_CONSTANTS` comment: pinned by this
  run's own agreement, *and by nothing from the AM run*, with the reason stated —
  "the AM run's RID is a fact about the AM run, and requiring the next run to reproduce
  it would refuse the very run this package exists to take".
* `evidence.py` module docstring gains a third named refusal beside its two existing
  ones, and `_frozen_operands` documents four anchors each pinned by the rule its own
  provenance allows.
* `README.md` and the delivery report both state it in the same words, and the report
  adds assumption 6, "**A body RID is assigned per run**", and states the mirror rule:
  port `run_frozen_unchanged` as implemented, not as the prose used to describe it.
* `fixtures.PROFILES` still copies the AM RIDs verbatim by default, so the ordinary
  fixture cannot drift; `params_for(body_rid=…)` and `FakeLive(run_rid=…)` are the
  opt-in that expresses a fresh RID rather than assuming it away.

No prose anywhere still claims the validator requires this run's RID to be the AM run's.
The one residual mention is the *deferred* GDScript mirror, and it is now written as a
requirement to port the implemented rule — which is what my §11 item 2 asked for.

### 1.5 Commands of record (N1)

```
git diff 39b8fe3f..85ace87b -- '*hook.py' '*evidence.py' '*driver.py' '*fixtures.py' '*prepare.py'
python3 /tmp/opencode/n12-verify/n1_probe.py <tip>/walker-support-query-compare
```

---

## 2. N2 — the anchors, carried behaviourally. CLOSED.

### 2.1 The methodology, and why it is now behavioural

§5.1/§5.2 recorded **0/12 `FrozenOperandTests` carried each anchor**: neutering any
anchor left the whole suite green, and a *deletion* was caught only by a `co_names`
introspection assertion — which cannot see a neuter, because the neutered form still
makes the call.

`FrozenOperandTests` now carries all four anchors. The mechanism is
`shadow_evidence(anchors)`: it copies `__init__.py`, `hook.py`, `policy.py` and
`evidence.py` to a temp directory, applies the anchor's **enforcement** removal — the
call, its operands and its docstring all stay — and imports the copy as its own hashed
package. That is the shape-preserving neuter my §5.2 said was needed, not a deletion.
Three states are distinguished so a neutered anchor cannot pass by being unremarkable:
the enforcing form present once is replaced; the already-neutered form present once is
left alone so the *behavioural* assertion reports the failure rather than a text
tripwire; neither present fails with "deleted, moved or rewritten". `hook` and
`policy` are copied byte for byte, so a forgery admitted by the copy can only have
been admitted by the code that was removed.

Each forgery is **preconditioned** — `per_observation_intact` asserts every isolation
predicate still passes, and each forgery asserts which *other* anchors still hold — so
"the shipped validator refuses it, the neutered copy admits it" is attributable to that
anchor rather than to a neighbour. This is the methodological correction my §4.4
identified, now applied to the shipped suite: five of the six re-tunings and the whole
consistent-re-tune test were previously passing without reaching the layer they name.

I read this code and agree with it. Then I checked it with my own instrument, because
the point of the N2 finding was that I had not trusted the suite in the first place.

### 2.2 My own neuterings, the shipped suite, and a direct admission probe

For each mutation I made a full copy of the package **plus exactly the files its own
pins name** (the six `prepare.REFERENCES`, the design review, the SHA256-pinned
diagnosis export and its source receipt — without those, `history.ROOT` does not
resolve and 77 of 100 tests error, which would make every count meaningless). I wrote
my own neuterings from reading `evidence.py` rather than importing the producer's
`ANCHORS` table, so the site text and the enforcement-removal shape are my own. Then I
ran the **shipped** `test_compare.py` in the copy, and separately handed the mutated
validator the forgery and asked whether it validates.

Baseline first, so the counts mean something: **unmutated shadow `Ran 100 tests` — OK.**

```
mutation                                     suite                admission probe
neuter design-frozen anchor                  FAILED (failures=4)  shipped=refuse  mutated=ACCEPT
DELETE design-frozen anchor                  FAILED (failures=5)  shipped=refuse  mutated=ACCEPT
neuter record-binding anchor (_frozen_operands)
                                            FAILED (failures=4)  shipped=refuse  mutated=refuse
neuter record-history-binding anchor (record)
                                            FAILED (failures=4)  shipped=refuse  mutated=refuse
neuter BOTH record-binding anchors           FAILED (failures=3)  shipped=refuse  mutated=ACCEPT
neuter run-frozen anchor                     FAILED (failures=4)  shipped=refuse  mutated=refuse
DELETE run-frozen anchor                     FAILED (failures=5)  shipped=refuse  mutated=refuse
neuter the whole-tuple comparison            FAILED (failures=4)  shipped=refuse  mutated=refuse
neuter run-frozen + whole-tuple comparison   FAILED (failures=10) shipped=refuse  mutated=ACCEPT
drop the whole _frozen_operands call         FAILED (failures=15) shipped=refuse  mutated=ACCEPT
restore the pre-N1 AM RID comparison         FAILED (errors=4)   the fresh RID is refused
```

**11 mutations, 11 killed, 0 survivors** — and, more to the point, the four
`mutated=ACCEPT` rows are the *behavioural* admission probes, not text assertions.

Failing tests per mutation, so "behaviourally" is visible rather than asserted:

| mutation | failing tests |
|---|---|
| neuter design-frozen | the anchor's own test; `test_retuning_all_three_requests_together_is_still_refused`; the run-frozen pairing test; the site inventory |
| DELETE design-frozen | the above plus `test_no_source_in_this_package_claims_a_verdict_or_neutrality` |
| neuter record-binding | its own test; the site inventory |
| neuter record-history-binding | its own test; the site inventory |
| neuter **both** record-binding | its own test; the site inventory |
| neuter run-frozen | its own test; the site inventory |
| DELETE run-frozen | the above plus the prose-claim test |
| neuter whole-tuple comparison | its own pairing test; the six-re-tunings test; the redundancy test; the inventory |
| neuter run-frozen **+** whole-tuple | all three run-frozen tests; the six-re-tunings test; the inventory |
| drop the whole `_frozen_operands` call | all four anchor tests plus three pre-existing ones |

The design-frozen row is the one my §5.2 said was the real gap. It is now killed by
`test_the_design_frozen_anchor_alone_refuses_a_consistent_retune`, whose failure I read
directly: `self.refuses(forged)` → `AssertionError: True is not false`. The shipped
validator, with the anchor neutered, **accepts** the consistent re-tune. That is the
behavioural kill, and it is the forgery my §4.2/§5.2 named.

### 2.3 The three outcomes the producer reported, confirmed

The brief asked for (a) the design-frozen anchor, (b) one member of each redundant
pair, and the producer's reported outcomes. All three confirmed, from my own runs:

* **Design-frozen alone → consistent re-tune admitted.** `shipped=refuse
  mutated=ACCEPT`. Nothing else covers it; this anchor is load-bearing on its own.
* **One member of the record-binding pair disabled → still refused by its sibling;
  both off → admitted.** Either member alone: `mutated=refuse`. Both:
  `mutated=ACCEPT`. My `_frozen_operands`-level probe, with the correct per-case
  `historical` the validator is actually handed, gives the same answer:
  `shipped _frozen_operands False / mutated True`, `shipped record False / mutated
  True`.
* **One member of the run-frozen pair disabled → still refused by its sibling; both
  off → admitted.** Either alone: `mutated=refuse`. Both: `mutated=ACCEPT`, with ten
  failing tests.

The producer reports the redundancy honestly rather than dressing it as single-anchor
kills — "neither can be shown load-bearing alone from the outside", and the tests
assert exactly that. That is the correct statement and I confirm it. The well-formedness
gate is measured as redundant defence-in-depth and its redundancy is asserted, not left
implicit; I probed it the same way and it behaves as reported.

One methodological note in the producer's favour, since it is the kind of thing that is
usually got wrong: `shadow_evidence` copies **four** modules, and `hook.py` and
`policy.py` byte for byte, while `evidence.py` carries the mutation. A copy that
drifted from what the package reads could otherwise admit a forgery for its own reasons.
I hit exactly that class of bug while building my own harness — my first probe keyed
the shadow package name on the leaf directory, so a second shadow was answered by the
first one's already-imported submodule and reported `refuse` for two mutations that
actually admit. Fixing the key to the full directory path flipped both to `ACCEPT`.
The shipped `shadow_evidence` hashes `str(directory)`, the full path, and does not have
that bug.

### 2.4 Commands of record (N2)

```
python3 /tmp/opencode/n12-verify/n2_probe.py /tmp/opencode/n12-tip
# baseline shadow (package + the 9 files its own pins name) : Ran 100 tests — OK
# 11 own neuterings/deletions : 11 killed, 0 survivors, 4 behavioural admission probes
```

---

## 3. Test counts, exactly

| suite | result |
|---|---|
| `walker-support-query-compare` at `85ace87b` | **`Ran 100 tests` — OK** |
| same suite in an independent shadow root | **`Ran 100 tests` — OK** |
| declared vs. executed | **100 `test_*` methods declared, 100 collected and run** |
| class distribution | Boundary 6, CaseSet 4, FrozenOperandTests 21, GuardPreservation 5, NoFurtherMovement 4, ObservationOrdering 9, Qualification 8, ReceiptValidator 18, Seal 10, Supervisor 10, ZeroMotion 5 = **100** |
| my N1 probe | 3 required outcomes observed + 6 re-tunings refused + 1 consistent re-tune refused |
| my anchor mutations | **11 mutations — 11 KILLED, 0 survivors**, 4 with a direct admission probe |
| `walker-support-normal-diagnosis` | `Ran 8 tests` — OK |
| `walker-calibrated-admission` | `Ran 30 tests` — OK |
| `walker-parity-admission` | `Ran 49 tests` — OK |
| `walker-baseline-characterization` | `Ran 5 tests` — OK |
| `walker-parity-response` | `Ran 24 tests` — OK |
| `walker-policy-receipt-probe` | `Ran 26 tests` — **5 errors, pre-existing** |

`FrozenOperandTests` is 21, up from 12: four for N1's RID semantics, four for N2's
anchor cargo, one for the anchor site inventory. The producer's numbers reproduce
exactly, including the four and one. The five `walker-policy-receipt-probe` errors are
the same five as in my original review and in §1.1 of the re-review, and
`git diff --name-only 39b8fe3f 85ace87b | grep -c walker-policy-receipt-probe` is
**0** — these commits touched no file in that package.

Python 3 only. **No engine, no Blender, no native parser or import, no renderer, no
server, no child job, no native stage, no grant, no network, no subprocess other than
`python3 -m unittest` and `git show` inside throwaway copies under `/tmp/opencode`.**
I did not touch the pinned `comparison.json` this time; the drift refusal was
re-confirmed at `33809aad`'s report and by the shadow copy carrying it by digest.

---

## 4. The previously closed conditions still hold

Re-verified against `85ace87b`, not carried on memory.

**C1 — the cross-observation proof. Still closed.** The three-layer structure is intact
and the anchor is now *also* carried by the suite, which was not true before. Dropping
the whole `_frozen_operands` call is **KILLED** (15 failures). The six review
re-tunings are still refused by my own forgeries, and so is the fully consistent
re-tune that only the SHA256-pinned design-frozen anchor can refuse. The `recordsSha256`
on the untouched default run is byte-identical to `88214d99`'s value.

**C2 — delivery self-description. Still closed.** All **15** Files-table line counts in
the report match `wc -l` exactly (README 230, `__init__` 6, `cli` 34, `policy` 161,
`hook` 534, `driver` 368, `evidence` 505, `campaign` 87, `history` 182, `prepare` 267,
`supervisor` 210, `invocation` 96, `seals` 125, `fixtures` 237, `test_compare` 2082),
checked against the files at `85ace87b`. The report still carries **no** digest line
for itself — the regex for one returns nothing, and its own row reads `—`. Both
delivery-hash blocks verify **15/15** on digest and byte count against
`git show 88214d99:<path>` and `git show 33809aad:<path>`, computed from the committed
blobs rather than the working tree, and the report says so.

**C3 — `policy.NATIVE_READINESS_BLOCKERS` pinned. Still closed.** Still six verbatim
entries in the receipt, still pinned against six literals. Both mutations that survived
the original review are still **KILLED**: appending ` (n/a)` to one blocker → `FAILED
(failures=1)`, `test_the_native_readiness_blockers_are_pinned_verbatim`; deleting one
blocker entry → `FAILED (failures=1)`, same killer. Not softened.

**C4 — `numeric_budget` oracle pinned. Still closed.**
`tools/godot-multiplayer/new-maps/walker-calibrated-admission/evidence.py` is still in
`prepare.REFERENCES` at `d403a924…c379`. Corrupting that pin by one character →
**KILLED** (`test_numeric_budget_matches_the_frozen_guard` among the failures); deleting
the pin entry entirely → **KILLED** (same test). Load-bearing, not decorative.

---

## 5. The three reviewed design notes — unchanged

Measured on a reference run at `85ace87b`, not read.

**1 — zero-motion omitted, no epsilon substitution anywhere. CONFIRMED, unchanged.**
Both design zero-motion observations omitted at ordinals **2 and 5 on both cases**,
four omissions in total, each `executed: false`, `substitutedMotion: null`,
`substitutionRefused: true`, `requestedMotion: [0.0, 0.0, 0.0]` and the single reason
`exact_zero_motion_semantics_undefined`. `acceptanceSubstitutions` is `0` on both cases.
All six executed observations carry `motion [0, -0.0200999995529652, 0]`, `margin
0.0199999995529652`. Refused: `requested_motion` of `[0,-1e-9,0]`, `[0,-0.0001,0]`,
`[0,-1e-15,0]`, `[0,1e-9,0]` — "only exact-zero motion may be omitted; epsilon
substitution refused" — and any `substituted_motion`, "an omission carries no
substituted motion". `hook.exact_zero([0,-1e-9,0])` is `False` while `hook.zero` is
`True`, so the strict predicate is the one in use. Mutation: relaxing `exact_zero` to
`zero` — **KILLED** (`test_hook_refuses_exact_zero_and_refuses_epsilon_pretending_to_be_zero`).

**2 — horizontal agreement required, vertical offset recorded. CONFIRMED, unchanged.**

| | `.35/.15/−45°` | `.42/.18/−45°` |
|---|---|---|
| `horizontalAgreementError` | 1.0536712127723509e−08 | 1.0536712127723509e−08 |
| `epsilon` (8 float32 ULPs) | 1e−06 | 1e−06 |
| **`verticalOffsetFromPredictedEndpoint`** | **−0.0843750014901164** | −0.1476562619209293 |

`.35` is exactly `−0.0843750014901164` on the record. The horizontal error is real and
non-trivial — 1.05e−08 m, two orders of magnitude inside the budget — not a rounded
zero. The validator binds the recorded offset **by equality** to
`expectedFinal[1] - predictedEndpoint[1]`, and both directions are still **KILLED**:
forcing `vertical_offset = 0.0` in the driver, and making the validator demand zero.

**3 — the validator does not apply the 46° predicate. CONFIRMED, unchanged.** The
recorded AM guard normal angles are 36.6773257409284° (inside) and 47.4769923414527°
(outside). `evidence.receipt`, `evidence.record`, `evidence._observation` and
`evidence._frozen_operands` reference none of `floor_angle`, `radians`, `cos` or
`degrees` in their code objects; `floor_angle` does not appear in `evidence.py` at all;
`evidence.receipt` and `evidence.record` have no `floor_angle` parameter.

Decisive test repeated, both directions. Replacing every recorded contact normal with
a unit vector **60.018° from vertical**, i.e. above the 46° threshold, and re-deriving
the digest:

```
SHIPPED validator accepts : True      <- no 46-degree predicate, as documented
MUTATED (46-degree predicate added to _observation) accepts : False
```

and adding a real `math.degrees(math.acos(...)) >= 46.0` refusal on the recorded contact
normal is **KILLED** (`FAILED (errors=49)`).

**`recordsSha256` byte-identical.** My own re-derivation from the untouched default
run at `85ace87b` is `67a3bf6c7a153043e32cebb1ce26869df423bab740b7f3505e9e71fa47fe6b4b`,
matching the report exactly. Nothing in the N1/N2 work perturbed the reference run.

---

## 6. Residuals

**None arising from N1 or N2.** §6 N3 (two `history`-provenance refusals, `AN-01` and
`AN-06`, that survive the suite and are unreachable from a receipt) is untouched by
these commits and remains what it was: untested, not broken. It needs nothing before
staging, since no receipt can influence the SHA256-pinned export read that those two
predicates guard. §6 N4 was already closed.

One thing I record for accuracy rather than as a defect. Removing the AM-value RID
comparison means a receipt's body RID is now pinned **only** by this run's own
agreement across its three requests and its recorded tuple — there is no external
anchor for it, because there is none to have. That is exactly the documented rule and
exactly what `driver.run_case` already did; it is also the same shape as the declared
deferred item in §9, that a self-attested record cannot prove which RID the engine
handed it. The remedy is the same and already stated: the prepared source record's seal
and `sourceSha256`, plus the mirror discipline. I raise it only so that nobody later
reads the RID as anchored when it is agreed.

---

## 7. Scope statement

Unchanged in force from §10 above, restated because this pass touched an engine-adjacent
topic. This remains a **source-only independent re-review**. Explicitly:

* **Source only.** No engine, no Blender, no native parser or import, no renderer, no
  server, no child job, no native stage, no grant was created, resolved, staged or
  executed. The only processes I started were `python3 -m unittest`, `git show`, and my
  own read-only Python, all inside throwaway copies under `/tmp/opencode`.
* **No native readiness is conferred.** `nativeReadiness.ready` remains `false` with the
  six verbatim blockers. Blocker 1 ("no independent source review of this package") is
  discharged *as a source review* by the original review at `7733051a`, reaffirmed at
  `39b8fe3f` and again here; **blockers 2–6 are untouched and unaddressed.** This
  addendum discharges no new blocker and softens no entry.
* **Integrating this package does not authorize an engine run.** It creates no grant,
  stages no GDScript, and adds no engine-invocation path. Doing any of those remains a
  separate, separately reviewed act. Settling N1 removes a contradiction that would have
  made the first real run's receipt fail validation; it is not an authorisation to take
  that run, and it does not make a GDScript mirror any closer to being approved than
  before.
* **AM stays failed.** Whole calibrated positive admission remains FAIL; the
  `.42/.18/−45°` candidate had one applied lift and **zero** verified.
* **`.42/.18/+45°` stays unrun.** Absent from the case set. No new case exists.
* **The 60 map journeys, the 184 static Vesper failures and production accounting are
  untouched** and remain open. `candidateMapWalks` is 0.
* No test acceptance in this package is a native pass, and every "measurement" in the
  suite and in my probes comes from an in-memory fake answering from frozen AM operands.
  The fresh RIDs in §1.2 exercise a per-run identifier, not a per-run engine.
* Zero-motion semantics remain undefined. The two omissions per case stay omitted; this
  pass did not establish them.
* The AM qualifications are inherited unchanged: `backendImplementationVerified = false`,
  `parentInternalCallsTraced = false`, `physicalCallCounts = null`.
* **The original review document remains immutable**, as does the body of this
  re-review document above this line. Nothing here modifies, supersedes or retracts
  `WALKER_SUPPORT_QUERY_COMPARE_REVIEW_20261005.md` at `7733051a` (blob
  `cad076cd6e6e5dc3ae593a68651651451e835ede`).
* **§11's requirement list is now discharged in full.** Item 1 (C1) was discharged at
  `39b8fe3f`; item 2 (settle the RID) is closed by §1 above, taking the producer's
  second option and keeping the documented rule; item 3 (the one-line test correction,
  plus the two `bodyRid` anchors and the record-level binding comparison) is closed by
  §2 above, with `per_observation_intact` asserting the precondition; item 4 (C2, C3, C4)
  is re-verified by §4. Items that remain from the producer's own list are unchanged and
  still required before any native staging: a real GDScript `LiveMeasurement` with the
  ordering enforced engine-side, a real supervisor with the reviewed lock and audits, a
  native smoke fixture, and staging plus grant creation under a reviewed namespace. The
  mirror must carry all four anchors **and** `run_frozen_unchanged` as implemented.

---

## 8. Commands of record (this pass)

```
cd /home/mojo/.tmp-on-disk/cocs-walker-support-normal-diagnosis
git status --short --branch                # clean, on spacebunny/walker-support-query-20261005 @ 85ace87b
git checkout review/walker-support-query-rereview-20261005
git diff --stat 39b8fe3f..85ace87b          # 9 files, +917/-908
git diff 39b8fe3f..85ace87b -- '*hook.py' '*evidence.py' '*driver.py' '*fixtures.py' '*prepare.py'
# independent worktree at the producer tip, so the review branch stayed clean
git worktree add --detach /tmp/opencode/n12-tip 85ace87b
cd tools/godot-multiplayer/new-maps/walker-support-query-compare
python3 -B -m unittest discover -s . -p 'test_*.py'    # Ran 100 tests ... OK
grep -c "    def test_" test_compare.py                # 100
python3 /tmp/opencode/n12-verify/n1_probe.py  <tip>/walker-support-query-compare
python3 /tmp/opencode/n12-verify/n2_probe.py  /tmp/opencode/n12-tip
python3 /tmp/opencode/n12-verify/notes_probe.py <tip>/walker-support-query-compare
python3 /tmp/opencode/n12-verify/c1234.py             # C1/C3/C4 re-verification
python3 /tmp/opencode/n12-verify/c2.py                # C2 line counts + 30/30 delivery hashes
# surrounding suites, unchanged from the producer's table
walker-support-normal-diagnosis 8 OK · walker-calibrated-admission 30 OK
walker-parity-admission 49 OK · walker-baseline-characterization 5 OK
walker-parity-response 24 OK · walker-policy-receipt-probe 26, 5 pre-existing errors
git worktree remove /tmp/opencode/n12-tip
```

---

*Final confirmation pass conducted read-only against `33809aad` / `b38dc12d` /
`85ace87b`. Nothing was pushed, merged or rebased. The delivery branch tip
`spacebunny/walker-support-query-20261005` remains in `refs` at `85ace87b`. The only
file committed on this branch is this document, and the only change to it is this
appended section. No file in the delivery, in `godot/`, in any sibling walker package,
or in any earlier review document was modified; every mutation was applied to a
throwaway copy under `/tmp/opencode`, which is removed.*
