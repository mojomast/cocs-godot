# Independent source review — bounded two-case Walker support-query comparison

Reviewer session: independent source review (this document).
Branch: `review/walker-support-query-20261005`, at the delivery commit
**`62ed480e`** ("Add bounded two-case Walker support-query comparison source
package"), base `feature/relay-campaign` `91b0b801`.
Approved design reviewed against:
`port/finish/map-variety/WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md` (integrated as
`d008a28b`, itself citing parent `7c1f196b`).
Worktree: `/home/mojo/.tmp-on-disk/cocs-walker-support-normal-diagnosis`, clean
throughout; the delivery branch tip `spacebunny/walker-support-query-20261005`
remains in `refs` and was not pushed, merged or rebased.

## Verdict: APPROVE WITH CONDITIONS

Every design-mandated property of the bounded sequence is implemented as approved
and survives independent attack. Nothing I found changes the two-case set, the
ordering, the omission discipline, the guard's preservation, the reported
divergence, or any scope boundary. The conditions below are all correctable
without touching the bounded contract, and none of them is a reason to hold the
source package out of integration — but **C1 is a hard gate on deriving a
GDScript `evidence.gd` mirror from `evidence.py`**, because it is a false claim
printed in three places (one of them a source docstring) in a campaign that is
otherwise scrupulous about not overclaiming. That asymmetry is why this is not a
plain APPROVE.

**No P1 blockers.**

Conditions, in priority order:

| # | Condition | Why it is not P1 |
|---|---|---|
| **C1** | Correct the three sentences claiming the *validator* proves the guard's request and the duplicate carry identical frozen constants (`hook.py:18-20`, `README.md:59-61`, report `:58-61`) — or, better, add the missing cross-observation check so the claim becomes true. **Required before any `evidence.gd` mirror is derived.** | The substantive requirement — a *predetermined* duplicate that cannot be re-tuned — is enforced at runtime by the driver and I verified that by mutation (F6/F7). Only the defense-in-depth claim about the offline validator is false, and no receipt exists to forge. |
| **C2** | Correct the delivery report's self-hash line and four line counts (report `:145-162`, `:315-316`). | All 15 per-file content hashes in the report verify exactly. The defect is confined to the report's own self-description. |
| **C3** | Pin the literal contents of `policy.NATIVE_READINESS_BLOCKERS` in a test. | The list is correct as shipped (I verified it by reading the module, the README and a written refusal record). Nothing *fails* if it is softened, though. |
| **C4** | Pin or relocate `test_numeric_budget_matches_the_frozen_guard`'s dependency on `walker-calibrated-admission/evidence.py`, which is outside the delivered package and absent from `prepare.REFERENCES`. | Test-only, and it currently passes. But it is an unpinned cross-package import. |

---

## 1. What was delivered, and that it is what it claims to be

`git diff --name-status 91b0b801 62ed480e` is **16 files added, 4091 insertions,
0 modifications and 0 deletions**. The delivery cannot have regressed anything:
every other suite in the repository is byte-identical on both sides of the commit.

All **15 per-file sha256/byte hashes printed in the report (`:298-313`) verify
against the committed bytes.** All frozen references verify:

```
godot/tests/walker_step_up/response_guard.gd     ff242f1c…281b0   ok
godot/tests/walker_step_up/sweep_proposal.gd     b2534648…538d41  ok
godot/tests/walker_parity_admission/candidate.gd 0aae2ac3…61314   ok
godot/tests/walker_parity_response/planner.gd    7dadd0a3…6b31    ok
godot/exploration/walker.gd                      3015de90…40d8    ok
WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md           647e9302…797d4   ok  (= prepare.DESIGN_REVIEW_SHA256)
walker-support-normal-diagnosis/comparison.json  b2a40dd2…6392    ok  (= history.DIAGNOSIS_EXPORT_SHA256)
walker-support-normal-diagnosis/source-receipt.json 25382b4d…2c40 ok  (= the identity the design review records)
comparison.json size 93728 bytes                 = DIAGNOSIS_EXPORT_BYTES
```

The report's "Tests and exact results" numbers reproduce exactly (below).

## 2. Verification method

I did not re-run only the producer's tests. Four independent instruments:

1. **Reading** every one of the 15 modules plus the report and the approved design.
2. **An 86-assertion adversarial probe** (`probe 1`) driving the real driver and
   validator with a clean reference run plus hostile inputs across eight groups:
   case set, zero-motion/epsilon, ordering and the state machine, predetermination,
   guard preservation and reported divergence, the predicted-endpoint contract,
   the fail-closed surfaces, and grant validation.
3. **A forger model** (`probe 2`): 17 targeted edits to a valid receipt, each with
   `recordsSha256` **re-derived** by the attacker's own code, so only structural
   predicates can refuse. This is the strongest thing an independent reviewer can
   do to a self-attested receipt and it is what separates real fail-closed
   behaviour from digest-masked tests.
4. **Mutation testing**: 38 single-token source mutations, each applied to a
   pristine copy in a shadow root (`/tmp/opencode/sqc-shadow`, 368 KB, built only
   from the files the package actually reads) and re-running both the shipped
   suite and my probes. A mutation is *KILLED* only if a test detects it.

No Godot, no Blender, no engine, no native execution, no network, no subprocess.
The shadow root exists so that no mutation touches the review worktree.

### Test counts, exactly

| Suite / instrument | Result |
|---|---|
| `walker-support-query-compare` on the review branch | **`Ran 78 tests` — OK** |
| same suite on an independent shadow root | **`Ran 78 tests` — OK** |
| declared vs. executed | 10 classes, **78 declared `test_*` methods, 78 collected and run, 0 missing** |
| class distribution vs. report `:180-183` | CaseSet 4, ZeroMotion 5, Ordering 9, GuardPreservation 5, NoFurtherMovement 4, Seals 10, Supervisor 10, ReceiptValidator 18, Qualification 7, Boundary 6 = **78 — identical** |
| **probe 1** (mine) | **86 assertions — 84 pass, 2 fail** (both the same finding, §5) |
| **probe 2** (mine, forger model) | **17 forged edits — 10 refused, 7 accepted** |
| **mutation testing** (mine) | **38 mutations — 21 KILLED, 17 survived** |
| `walker-support-normal-diagnosis` | `Ran 8 tests` — OK |
| `walker-calibrated-admission` | `Ran 30 tests` — OK |
| `walker-parity-admission` | `Ran 49 tests` — OK |
| `walker-baseline-characterization` | `Ran 5 tests` — OK |
| `walker-policy-receipt-probe` | `Ran 26 tests` — 5 errors, **pre-existing and unrelated** |

The five `walker-policy-receipt-probe` errors are all
`SourceTests.test_*` reading a `cocs-walker-parity-admission-ai` root this
worktree does not materialise. They are reproducible at `91b0b801`, the base of
this delivery, and no file in that package was touched.

### The mutation ledger, in full

`KILLED` = a shipped test detected the mutation. All 38 targets matched; there
were no misses.

| id | mutation | verdict |
|---|---|---|
| M1 | skip the pre-UP observation step | **KILLED** (fail 1, err 35) |
| M2 | issue the duplicate *before* the candidate response | **KILLED** (fail 1, err 35) |
| M3 | drop the terminal stop | **KILLED** (err 35) |
| M4 | widen the candidate-response check to `<=` budget+1 | survived — equivalent |
| M5 | drop the driver's frozen-constant check on the guard | survived — untested |
| M6 | relax `hook.omission`'s exact-zero rule to Godot's approximate zero | **KILLED** (fail 1) |
| M7 | inject `import subprocess` into `policy.py` | **KILLED** (fail 1, err 1) |
| M8 | inject a bare `import os` into `supervisor.py` | survived — allowed by design |
| M9 | inject `os.system('echo pwned')` into `supervisor.preflight` | **KILLED** (err 1) |
| M10 | add a third case to `policy.CASES` | **KILLED** (err 43) |
| M11 | validator stops requiring `retries == 0` | survived — untested |
| M12 | validator applies the 46° predicate | **KILLED** (err 35) |
| M13 | drop the second omission record | **KILLED** (err 35) |
| M14 | driver forces the vertical offset to zero | **KILLED** (err 35) |
| M15 | validator demands the vertical offset be zero | **KILLED** (err 35) |
| M16 | driver allows any eligible transition, not only the first | **KILLED** (fail 1) |
| M17 | `history.agree` always reports agreement | **KILLED** (fail 3) |
| M18 | allow a record under `godot/` | **KILLED** (fail 1) |
| M19 | make `write_once` overwrite instead of refusing | **KILLED** (fail 3) |
| M20 | validator stops checking the recorded-before/after-UP labels | survived — proven load-bearing by probe 1 |
| M21 | validator relaxes the duplicate pose to within epsilon | **KILLED** (err 1) |
| M22 | validator allows `nativeReadiness.ready = True` | **KILLED** (fail 1) |
| M23 | `policy` blanks the no-independent-review blocker | survived — see P2-3 |
| M24 | remove the `recordsSha256` comparison entirely | **KILLED** (fail 2 — see §3.7) |
| M25 | validator stops requiring duplicate pose == guard pose | **KILLED** (err 1) |
| M26 | driver stops requiring first == min(eligible) | survived — untested |
| M27 | `hook.omission` accepts any motion at all | **KILLED** (fail 1) |
| M28 | evidence no longer requires `queryStateEqual is True` | survived — untested |
| M29 | evidence stops requiring result `maxCollisions == 32` | survived — redundant with `evidence.py:64` |
| M30 | `policy` blanks the no-grant blocker | survived — see P2-3 |
| M31 | driver relaxes the duplicate pose to within epsilon | survived — untested |
| M32 | driver stops requiring the pre-UP request at the predicted endpoint | survived — untested |
| M33 | evidence stops requiring guard pose == `expectedFinal` | survived — untested |
| M34 | evidence stops requiring the event-log order | survived — see P2-4 |
| M35 | evidence stops requiring the counters == 1 | survived — untested |
| M36 | evidence stops requiring the guard request *is* the guard result | **KILLED** (fail 1) |
| M37 | evidence stops requiring an omission be exactly zero | survived — untested |
| M38 | evidence stops requiring the second omission ordinal | survived — untested |

I classify the 17 survivors as: **equivalent or policy-intended** (M4, M8, M29);
**defended by the delivery seal rather than by a test** (M23, M30); **load-bearing
but only digest-masked in the shipped suite** (M20, M34); and **not exercised in
isolation by the shipped suite, and not exercised by my probes either** (M5, M11,
M26, M28, M31, M32, M33, M35, M37, M38). The last group means the shipped suite
does not *prove those predicates are reachable*; it does not mean they are
unreachable, and I did not find any path by which the driver can violate them. I
record them so that a future reviewer inherits the list rather than re-deriving it.
The honest summary is: **the suite's 21 kills cover every property the approved
design names**, and the survivors are untested-in-isolation defense-in-depth
predicates rather than contract violations.

## 3. The nine required checks

### 3.1 The case set is exactly the two authorized cases — CONFIRMED

`policy.CASES` is the two-case tuple (`policy.py:22`), the canonical specs are
built from two hardcoded rows (`policy.py:94-99`), and `validate_case_set`
requires both the length *and* the exact order (`policy.py:129-137`).

Refused, each with a distinct message:

```
validate_case_set(3 cases)   -> PolicyError: exactly 2 cases are authorized; got 3
validate_case_set(reordered) -> PolicyError: canonical case set and order required
validate_case_set(dropped)   -> PolicyError: exactly 2 cases are authorized; got 1
case_allowed('.42/+45')      -> False
spec_for('.42/+45')          -> PolicyError: case not authorized
BoundedDriver('.42/+45')     -> PolicyError: case not authorized
driver.run(3 lives)          -> PolicyError: exactly 2 cases are authorized; got 3
driver.run(1 live)           -> PolicyError: exactly 2 cases are authorized; got 1
driver.run(reordered)        -> PolicyError: canonical case set and order required
grant with allowedCases + a third case -> PolicyError: exactly 2 cases are authorized
```

`driver.run` calls `validate_case_set` **before touching a single body**
(`driver.py:338-342`). No `.42/+45` spec exists in `policy.canonical()`; no
`.20` case exists.

**Mutation:** adding a third case to `policy.CASES` — **KILLED**, 43 test
errors. The allowlist cannot be widened silently.

### 3.2 Zero-motion handling — CONFIRMED, no epsilon substitute anywhere

Both design zero-motion observations are omitted at ordinals 2 and 5
(`hook.py:51-57`, `hook.py:240-241`), each with `executed: false`,
`substitutedMotion: null`, `substitutionRefused: true` and the
undefined-zero-semantics reason only.

`hook.exact_zero` (`hook.py:94-102`) is componentwise `x == 0` — **strictly
stricter** than `hook.zero`, which reproduces Godot's approximate `is_zero_approx`.
That is the right way round: the approximate predicate would let a small nonzero
motion be filed as an exact-zero omission. I confirmed `zero([0,-1e-9,0]) is
True` while `exact_zero([0,-1e-9,0]) is False`.

Refused:

```
omission(requested_motion=[0,-1e-9,0])   -> only exact-zero motion may be omitted; epsilon substitution refused
omission(requested_motion=[0,-0.0001,0]) -> (same)
omission(requested_motion=[0,-1e-15,0])  -> (same)
omission(requested_motion=[0, 1e-9,0])   -> (same)
omission(substituted_motion=[0,-1e-6,0]) -> epsilon substitution refused: an omission carries no substituted motion
omission(reason='because_i_said_so')     -> only the undefined-zero-semantics omission reason is recognized
down_motion(margin == -LIMIT)            -> ExactZeroMotionOmitted (not a generic HookError)
```

`down_motion` (`hook.py:147-152`) refuses a margin that would cancel `LIMIT`
exactly as an *undefined zero* rather than as an ordinary invalid margin. The
validator independently refuses an executed zero-motion observation
(`evidence.py:74-77`) — I forged one and it was rejected. `zeroMotionRequestsExecuted`
must be 0 and `epsilonSubstitutionUsed` must be false in the receipt
(`evidence.py:354`), and the omission reason string is pinned
(`evidence.py:136`).

No epsilon-substitution helper exists in any shipped module, and the only
epsilon-valued constant is `OPERAND_EPSILON = 1e-12` (`hook.py:48`), used solely
for double round-tripping — six orders of magnitude below the 1 µm budget.

**Mutations:** relaxing `exact_zero` to `zero` in `hook.omission` — **KILLED**.
Removing the rule entirely — **KILLED**.

### 3.3 Ordering and the state machine — CONFIRMED

Read directly (`driver.py:181-225`), the sequence is straight-line:

| step | code | note |
|---|---|---|
| 1 | `driver.py:182-189` | pre-UP down32 at `predictedEndpoint`, **before** `live.candidate_response` |
| 2 | `driver.py:192-198` | exactly one unchanged candidate response and guard |
| 3 | `driver.py:201-205` | the guard's own request, recorded verbatim (`issuedBy: unchanged_response_guard`) |
| 4 | `driver.py:208-219` | duplicate at the guard's actual final origin |
| 5 | `driver.py:222-223` | terminal stop |

`_advance` (`driver.py:124-128`) permits only `index + 1`; `state()` raises
`Stopped` after the terminal phase (`driver.py:118-122`); `run_case` refuses a
second entry (`driver.py:133-134`). `PHASES` is the six-state machine
`planned → pre_up_observed → candidate_responded → guard_observed →
duplicate_observed → stopped`.

Observed from *outside* the driver — `FakeLive.orders()` records the live call
sequence independently of the driver's own event log:

```
['test_motion:pre-up-predicted-endpoint-support',
 'candidate_response',
 'test_motion:duplicate-actual-final-support']     candidate_calls == 1
```

for both cases. Refused:

```
_advance() skipping a phase        -> BoundedContractError: illegal phase move planned -> duplicate_observed
_advance() backwards               -> BoundedContractError: illegal phase move planned -> planned
run_case(later transition index)   -> only the first eligible transition is authorized; got 200
run_case(transition_index=200)     -> (same)
state() after stop                 -> Stopped: body interaction after stop is not permitted
run_case() a second time           -> BoundedContractError: case already started: stopped
```

Validator-side, with the digest re-derived by me so only structural predicates
can act — **all refused**: reordered observations; pre-UP relabelled
`issuedAfterUpStep=True`; pre-UP relabelled `recordedBeforeUpStep=False`;
duplicate at a different pose; duplicate at the predicted endpoint; guard and
duplicate both moved off `expectedFinal`; pre-UP moved off the predicted
endpoint; reordered event log; a fourth observation appended.

**Mutations, all KILLED:** skip the pre-UP step; issue the duplicate *before* the
candidate response; drop the terminal stop; allow any eligible transition instead
of only the first.

**Note on two surviving mutations.** Widening the counter check from `==` to
`<=` budget+1 survives, and so does removing it entirely — but
`driver.run_case` calls `live.candidate_response` exactly once, textually, on a
straight-line path with no loop, so no reachable second response exists; these are
equivalent mutants, not gaps. The real defences are the single call site, the
phase machine, `appliedUpCount`/`parentResponseCount` (`driver.py:266-268`) and
the validator's `== 1` requirement (`evidence.py:210-212`).

### 3.4 Predetermination honesty — the pose claim is correct; the validator claim is an **overclaim**

This is the substantive finding, and it is exactly the point the review brief
asks about. The producer states it three times and it is **false in all three**:

> `hook.py:18-20` — "The validator then proves the guard's request and the
> duplicate both carry the frozen constants unchanged, which is what makes the
> duplicate a genuine duplicate rather than a re-tuned request."
> `README.md:59-61` — same claim, same words.
> report `:58-61` — "The driver and validator then prove …"

**What is true.** The *pose* half is honest and is stated honestly in all three
places: the pose genuinely cannot be predetermined, because "the actual final
state" is only known after the candidate response returns, and it is taken
verbatim from the guard's own recorded request. The code matches the prose
exactly — `driver.py:208-210` takes `actual_final = guard_observation['request']['from']`
and passes it to `hook.request_from(..., self.frozen)`; it never computes a pose.
`driver.py:167-168` builds `self.frozen` before anything executes. `F1/F2/F3`
confirm the produced duplicate carries **byte-identical** frozen constants
(`motion [0,-0.0200999995529652,0]`, `margin 0.0199999995529652`,
`maxCollisions 32`, `recoveryAsCollision`, `collideSeparationRay`,
`bodyRid 154618822659`, empty exclusions) and the guard's exact pose.

**What is false.** The validator does not prove that, and cannot as shipped.
Under my forger model, re-deriving `recordsSha256` after each edit:

```
ACCEPTED  the guard's own request margin re-tuned 0.0200 -> 0.0150, motion kept consistent
ACCEPTED  the guard's own request motion re-tuned but kept self-consistent
ACCEPTED  the guard's own request bodyRid re-tuned to a different RID
ACCEPTED  duplicate margin re-tuned 0.0200 -> 0.0150 (motion kept consistent)
ACCEPTED  duplicate bodyRid re-tuned to a different RID
ACCEPTED  pre-UP request bodyRid re-tuned to a different RID
```

**Root cause, precisely located.** `evidence.record` validates each observation
*in isolation* — `evidence.py:227`, `:236`, `:246` — and **never compares one
observation to another**. `evidence._observation` proves each request internally
self-consistent (`request↔result` on `MATCHED_OPERANDS` including `from`;
`motion[1] == -(margin + LIMIT)` at `:76`; `maxCollisions == 32` at `:64`/`:80`;
positive integer `bodyRid` at `:78`) — but nothing binds the three observations to
each other. And there is nothing authoritative for them to bind *to*: the receipt
carries no frozen-operand tuple (`policy.RECEIPT_KEYS`, `policy.py:36-45`), and
the source record's `proposal.frozenConstants` uses a **shape placeholder**
`bodyRid: 1` (`prepare.py:106`), not the real per-case RIDs
`154618822659`/`274877906947`. So the check the prose promises has nothing to
compare against and is simply absent.

**The runtime driver does enforce it**, and I verified that by mutation rather
than by reading: an engine that rewrites the guard's motion is refused
(`BoundedContractError: the engine changed frozen operands: motion`), and so is
one that rewrites the duplicate's operands. `driver.py:257-260` compares the
guard's request against `self.frozen` on `hook.GUARD_CONSTANTS` before accepting
it, and the duplicate is *built* from `self.frozen` rather than re-derived.

**Why this is not a P1.** The design's substantive requirement — record the
*predetermined* duplicate, never a re-tuned one — is met and enforced. Nothing
downstream consumes the validator's ability to detect a forged receipt, because
no receipt exists, no grant exists, and the package creates no authority
(`__init__.py:3`, `campaign.py:42` `'authority': 'none-source-only'`). The cost
is confined to a false sentence in a docstring, a README and a report.

**Why it is not a mere nit.** The docstring is *source*, and the report itself
plans a "`GDScript evidence.gd` mirror of `evidence.py`" (`:277-280`) plus "a test
asserting the mirror and the Python validator agree". A future implementer
reading `evidence.py` and its docstring would port the mirror without this check
and would carry the false claim into GDScript, where it would guard a real engine.
That is condition **C1**, and it is a hard gate on the mirror, not on this
integration.

The cheapest true fix is one predicate in `evidence.record`, after line 249:

```python
equal, differences = hook.operand_equal(observations[1]['request'],
                                       observations[2]['request'],
                                       keys=hook.CONSTANTS)
if not equal:
    return False
```

with the same for the pre-UP request. Failing that, reword all three sentences to
say the *driver* proves it at runtime and the validator only proves each request
internally self-consistent.

### 3.5 The validator does **not** apply the 46° predicate — CONFIRMED

The AM failure case's recorded fresh-guard normal is **47.476992341452714°**,
beyond the guard's 46° threshold, and the AM reference case's is
**36.67732574092844°**, inside it. Both are read from the pinned diagnosis export
(`history.py:88`), not retyped.

* `evidence.receipt` and `evidence.record` have no `floor_angle` parameter and no
  angle comparison anywhere in their code objects — verified by introspection.
* The single `math.cos(floor_angle)` comparison in the package is
  `hook.valid_result` (`hook.py:347`), an opt-in helper that is **never called by
  `evidence.py`** — it exists so an unqualified contact is *reported* rather than
  turned into a verdict (`hook.py:296-303`), and only the test suite calls it.
* **Decisive test:** I re-serialized a valid receipt with the failure case's
  contact normal replaced by a *unit-length* `[0.6007, …]` normal (53.13° from
  vertical) and re-derived the digest. **The validator accepts it.** A validator
  applying the 46° predicate would have rejected the very failure this campaign
  exists to re-observe.
* **Mutation:** adding the 46° predicate to `evidence._observation` — **KILLED**,
  35 errors.

The design's rationale is documented in place at `evidence.py:38-44` and
`history.py:116-123`, including the reason the comparison is on the guard's
*decision* and not on observed normals: "treating that as a divergence would
report the measurement's finding as a contract violation."

### 3.6 Predicted endpoint vs `expectedFinal` — CONFIRMED, the vertical offset is genuinely recorded

`predictedEndpoint = raised.origin + horizontalBudget` per `response_guard.gd:29`
(`driver.py:158`, `hook.py:233`), and the basis string is carried into every
record (`driver.py:309-311`). Measured on the reference run:

| | `.35/.15/−45°` | `.42/.18/−45°` |
|---|---|---|
| `predictedEndpoint.y` | 0.172130957245827 | 0.20213095843792 |
| `expectedFinal.y` | 0.0877559557557106 | 0.0544746965169907 |
| **`verticalOffsetFromPredictedEndpoint`** | **−0.0843750014901164** | −0.1476562619209293 |
| `horizontalAgreementError` | **1.053671e−08** | 1.053671e−08 |
| `epsilon` (8 float32 ULPs) | 1.0e−06 | 1.0e−06 |

The `.35` vertical offset is **−0.0843750014901164 m ≈ −0.0844 m**, matching the
expected value. The horizontal agreement is **not** exact (1.05e−08 m) but sits
three orders of magnitude inside the 1 µm budget — a real, non-trivial number
rather than a rounded zero, which is the right kind of honest.

The contract requires horizontal agreement within the guard's epsilon and records
the vertical offset; it never demands it to zero:

* `evidence.py:169-172` — the recorded `horizontalAgreementError` must *equal* the
  recomputed horizontal distance **and** be within `plan['epsilon']`.
* `evidence.py:173-175` — the recorded offset must *equal*
  `expectedFinal[1] - predictedEndpoint[1]`.
* `evidence.py:166-168` — `predictedEndpoint` itself must equal
  `raised.origin + horizontalBudget` within epsilon.
* `driver.py:169-175` computes both before execution and `_require`s the
  horizontal check at `driver.py:172-173`.

**Mutations, both KILLED:** forcing `vertical_offset = 0.0` in the driver (35
errors); making the validator demand the offset be zero (35 errors). Neither
side can be quietly collapsed.

### 3.7 Fail-closed surfaces — CONFIRMED

* **Write-once.** `seals.write_once` uses `path.open('x')` (`seals.py:59`).
  A rebuild raises `FileExistsError`. **Mutation:** changing `'x'` to `'w'` —
  **KILLED**, 3 failures.
* **Seals.** Every seal binds path + role + sha256 + bytes and is re-checked
  against the bytes on disk (`seals.py:94-117`). Tampering with
  `candidateResponseBudget` in a written record is refused. The manifest root and
  role are pinned against substitution (`prepare.py:187-190`), and an unexpected
  file or a symlink inside a record is refused (`prepare.py:172-178`).
* **Validator.** `evidence.receipt` and `evidence.record` return booleans and
  swallow `KeyError/TypeError/ValueError/IndexError/AttributeError/
  OverflowError/ArithmeticError`, so a validator call can never become a pass via
  an exception. Confirmed: `landingY` set to `nan`, `None` or `'x'` returns
  `False` and raises nothing.
* **Supervisor refusal.** `preflight` performs the full read-only preflight and
  then `refuse()` writes a 30-key sealed, write-once record. A second refusal is
  refused. `{engine}` and `{fixture}` stay literal:
  `['{engine}', '--headless', '--single-threaded-scene', '--path', '{fixture}', …]`.
  Grant validation is genuinely exercised, not decorative: I confirmed a
  well-formed grant *does* validate (so the refusals are refusals, not accidents),
  and that expired / unauthorized / wrong-engine / unbound-source grants and a
  third-case grant are each refused.
* **AST audit — I injected, as asked.** `invocation.audit()` reports
  `modulesAudited: 14, engineInvocationPaths: 0`.
  * `import subprocess` injected into `policy.py` → **KILLED**.
  * `os.system('echo pwned')` injected into `supervisor.py:preflight` → **KILLED**.
  * A bare `import os` injected into `supervisor.py` **survives** — and *should*:
    `invocation.py:21-25` deliberately restricts only the `os` **execution**
    surface, because filesystem and path work is legitimate here. `invocation.py:8-12`
    states this intent, and matching launch attributes only against a known
    spawning owner (`invocation.py:67`) is what keeps an unrelated `.run` from
    being a false positive.
* **Isolation between receipt-level and case-level predicates.** This was the
  most useful experiment I ran. **Removing the `recordsSha256` comparison
  entirely** (`evidence.py:386`) fails only **2 of 78** tests — and those two are
  exactly `test_specification_tampering_is_refused` and
  `test_tampered_contacts_and_predicates_are_refused`, i.e. the two tests that
  exist to test the digest. Every other structural predicate in the validator
  independently carries the suite. The digest is a backstop, not a crutch.

### 3.8 No `godot/` writes and no native/engine invocation — CONFIRMED

* Every write in the package is either `prepare.build`'s `dest.mkdir(parents=True)`
  (`prepare.py:160`) or `seals.write_once` (`seals.py:59`) — nothing else. Every
  `godot/` mention outside prose is a read-only SHA256-pinned reference
  (`prepare.py:32-41`). Both write paths are gated by `_reject_engine_tree`
  (`prepare.py:92-96`, called at `:156` and `:170`).
* I attempted to stage a record under `godot/tmp-review` and to validate `godot/`
  itself: both refused. **Mutation:** disabling `_reject_engine_tree` — **KILLED**.
* `policy.ENGINE` is never a path. It is only compared, validated and copied into
  records (`policy.py:142`, `prepare.py:135`, `supervisor.py:86`). No binary is
  resolved, executed or copied anywhere in the package.
* The README's two CLI commands, run verbatim, produce exactly three files under
  `/tmp/opencode/sqc-runs/…` — `source-record.json`, `seal-manifest.json`,
  `native-refusal.json` — and print `engine invocations: 0; native readiness: False`.

### 3.9 The stated limits are the real limits — CONFIRMED

`policy.NATIVE_READINESS_BLOCKERS` (`policy.py:64-71`) and the written refusal
record agree verbatim, and the receipt validator requires the list *exactly*
(`evidence.py:368`):

1. no independent source review of this package  ← **this review discharges it**
2. no heavy grant exists for phase `support-query-compare-v1`
3. no GDScript staging; the driver and hook exist only as offline Python
4. no engine-invocation path in this source package, by design
5. zero-motion support semantics remain undefined; those two stay omitted
6. AM whole positive admission remains failed and .42/.18/+45° remains unrun

The refusal record additionally carries `grantExists: false`,
`positiveAdmission: false`, `nativeStepAdmission: false`,
`productionPromotion: false`, `amWholePositiveFailed: true`,
`unrunPositiveCase: '.42/.18/+45'`, `candidateMapJourneysUnrun: 60`,
`staticVesperFailuresUnresolved: 184`, `productionAccountingOpen: true`, and the
source record re-asserts `preUpPredictedEndpointRecorded: false` for both cases —
the exact gap this campaign exists to fill (`history.py:73-74`).

`README.md:84-108` and report `:249-290` state the same six limits, `AM stays
failed`, `.42/+45° stays unrun`, `candidateMapWalks` 0, no `.20` fallback, no
guard widening, no retry, no epsilon tuning, no acceptance substitution, no
normal selection, and that the 60 journeys / 184 static Vesper failures /
production accounting remain untouched. I found nothing overstated in any of it.

## 4. The three producer design notes, judged explicitly

The brief asks for three. I judge the three load-bearing ones plus the two
adjacent claims the same report makes, because two of them interact with the
finding above.

| # | Producer note | Judgment |
|---|---|---|
| **1** | Both exact-zero observations are omitted because `godot_space_3d.cpp:698-699` divides motion by its length with no zero check; **epsilon motion is never substituted** (`hook.py:6-9`, report `:40-50`). | **CORRECT.** `exact_zero` is strictly componentwise; epsilon attempts at −1e−9, −0.0001, −1e−15 and +1e−9 are all refused; `substitutedMotion` must be `None`; the omission reason is pinned; the only reason string is the undefined-zero one; a margin that would cancel `LIMIT` is refused *as* an undefined zero. Two independent mutations that weaken any of this are KILLED. No epsilon substitute exists anywhere. |
| **2** | *The duplicate's pose cannot be predetermined and is taken verbatim from the guard's own recorded request rather than chosen* — **and the validator proves both carry the frozen constants unchanged** (`hook.py:11-20`, README `:52-61`, report `:52-62`). | **NEEDS CHANGE — first half CORRECT, second half OVERCLAIM.** The pose half is correct, honestly worded, and the code matches it exactly. The validator half is **false** in all three places: `evidence.record` validates observations in isolation and never compares them; six distinct constant re-tunings pass under the forger model; and the receipt carries no frozen-operand tuple to compare against. The *driver* does enforce it at runtime, verified by mutation. Fix per **C1**. This is the one note I would not let stand. |
| **3** | The predicted endpoint is `raised.origin + horizontalBudget` per `response_guard.gd:29`; because `apply_floor_snap` projects Y only, the contract requires **horizontal** agreement within the guard's epsilon and **records** the vertical offset instead of demanding it to zero (`driver.py:152-157`, `evidence.py:141-149`). | **CORRECT.** Measured horizontal error 1.053671e−08 m against a 1.0e−06 m budget; measured vertical offset −0.0843750014901164 m for `.35` and −0.1476562619209293 m for `.42`; the validator binds the recorded offset *by equality* to the recomputed difference. Forcing zero on either side is KILLED. The `apply_floor_snap` reasoning is stated as a source-level assumption, pinned by SHA256, and explicitly not a measured backend behaviour (report `:237-239`). |
| 4 | The guard's result and fault are preserved verbatim; divergence from frozen history is reported, never forced (report `:74-84`). | **CORRECT.** `driver.py:285-286` records `passed`/`reason`/`candidateFault` as returned with `preservedIntact: true`; `driver.py:271-272` refuses a fault that does not match the guard's own reason. A flipped guard on both cases produced `unexpectedChangedOutcomes: [both]` with the historical value kept beside the observed one; a receipt claiming agreement while reporting divergence is refused; a receipt claiming divergence silently is refused; a receipt softening the blocker list is refused. **Mutation** making `history.agree` always return True — **KILLED**. |
| 5 | The validator does not apply the strict 46° predicate (report `:96-97`, README `:79-82`). | **CORRECT.** A 53.13° unit normal passes; the 46° predicate exists only in the never-called opt-in `hook.valid_result`; **mutation** adding it to the validator is KILLED. |

## 5. P1 blockers

**None.**

## 6. Non-blocking observations

**P2-1 — the false validator claim (§3.4).** The single substantive defect. Six
forgeries accepted under the forger model; `evidence.record` validates
observations in isolation (`evidence.py:227`, `:236`, `:246`); no frozen-operand
tuple exists in the receipt (`policy.py:36-45`); the source record's placeholder
is `bodyRid: 1` (`prepare.py:106`). Condition **C1**. Highest-value fix in this
review: it is one predicate, and it makes three published sentences true.

**P2-2 — the delivery report misdescribes itself.** Report `:315-316` claims
`This report: cb80def40f70b91cbdee0de61fd14526475c220b434a72ee725c154c9a046cde
(18338 bytes)`. At commit `62ed480e` the file is
`194ead87b1ccb95dc88717e1270e118fc2175a4bbd83ec7ad9a88f6ea80f6412`, **21083
bytes**. I could not reconstruct the claimed digest from any variant of the file
(text before the claim: `5490ef5c…`, 19815 bytes; claim paragraph removed:
`0d5a2d03…`, 20987 bytes). A self-digest is in any case not a well-defined claim,
since a file cannot contain its own hash — the line should name the attempt or be
dropped. Four line counts in the Files table (`:145-162`) are also wrong:
`prepare.py` 250→**248**, `supervisor.py` 207→**211**, `seals.py` 127→**125**,
`test_compare.py` 1038→**1174**. The other eleven counts are exact, and — this is
what matters — **all 15 per-file content hashes verify exactly.** Condition
**C2**.

**P2-3 — the blocker list is pinned by no test.** Blanking one entry of
`policy.NATIVE_READINESS_BLOCKERS` **survives** the suite. Every assertion
compares the receipt against `policy.NATIVE_READINESS_BLOCKERS` *itself*
(`test_compare.py:595`, `:1000-1001`), so both sides move together. The list is
correct as shipped — I verified it against the README, the report and a written
refusal record — but nothing would fail if it were softened, which is exactly the
kind of claim that should be pinned. One `assertEqual(list(...), [...six
literals...])` closes it. Condition **C3**.

**P2-4 — one validator predicate is only reachable through a digest-masked
mutation in the shipped suite.** `ReceiptValidatorTests.mutate`
(`test_compare.py:720-726`) never re-derives `recordsSha256`, so a refusal it
observes may be the digest rather than the predicate under test. Disabling the
event-log-order predicate (`evidence.py:204-205`) **survives** the suite, even
though `test_reordered_observations_are_refused` edits `eventLog` — because that
test also reorders the observations themselves, which is caught structurally
first. I confirmed under the forger model that the predicate is genuinely
load-bearing: with it removed, a reordered event log becomes **accepted**. So
this is a test-methodology observation, not a validator gap. It is largely
mitigated already: removing the digest entirely fails only 2 of 78 tests. The
sibling duplicate-pose predicate (`evidence.py:246-249`) *is* killed when
disabled, so the masking is specific rather than systemic.

**P2-5 — an unpinned cross-package test dependency.**
`test_numeric_budget_matches_the_frozen_guard` (`test_compare.py:1040-1049`)
loads `walker-calibrated-admission/evidence.py`, which is outside the delivered
package and absent from `prepare.REFERENCES` (`prepare.py:31-42`). In a shadow
root containing only the files the package reads, the suite errors on this one
test. Harmless today, and a good guard-port fidelity check — but it should be
pinned alongside the other references or the ported `budget` could drift with
nothing failing. Condition **C4**.

**P2-6 — two cosmetic merge artifacts.** `supervisor.py:27-32` carries a
duplicated comment fragment ("Recorded so a reviewer can see exactly what would
have been attempted. This is a description, not a command: nothing here is
executed.") immediately above the real docstring for `PLANNED_ARGV_TEMPLATE` — a
leftover from an edit. `prepare.py:17-20` imports `history` before `hook`,
breaking the alphabetical order used by every other module in the package.

**P2-7 — surviving mutations that are equivalent, recorded so a future reviewer
does not re-litigate them.** Widening the candidate-response counter check from
`==` to `<=` budget+1 (M4) and removing that check entirely (M35) both survive,
because `driver.run_case` calls `live.candidate_response` exactly once on a
straight-line path with no loop — the real defences are the single call site, the
phase machine, the `appliedUpCount`/`parentResponseCount` checks
(`driver.py:266-268`) and the validator's `== 1` requirement. Injecting a bare
`import os` (M8) survives *by design*: `invocation.py:21-25` deliberately
restricts only the `os` **execution** surface, because filesystem and path work is
legitimate here. Removing the result-side `maxCollisions == 32` check (M29)
survives because `evidence.py:64` already requires it on the request side.
None of the three is a gap.

**P2-8 — a property the package correctly does not claim.** A forged guard
outcome that already *matches* history is undetectable by any local validator,
because the design mandates "report, never enforce". This is inherent to the
approved design and is not claimed anywhere; I note it only so that no future
reader mistakes the divergence machinery for bidirectional protection.

## 7. Scope statement

This is a **source-only independent review**. Explicitly:

* **Source only.** No engine, no native parser or import, no renderer, no server,
  no child job, no native stage, no grant was created, resolved, staged or
  executed. No Godot, no Blender, no native binary.
* **No native readiness is conferred.** `nativeReadiness.ready` remains `false`
  with the six verbatim blockers. Blocker 1 (this review) is now discharged as a
  *source* review; blockers 2-6 are untouched and unaddressed.
* **Integrating this package does not authorize an engine run.** It creates no
  grant, stages no GDScript, and adds no engine-invocation path. Doing any of
  those remains a separate, separately reviewed act, and would require updating
  `invocation.audit`'s forbidden sets as a deliberate change
  (`invocation.py:10-12`).
* **AM stays failed.** Whole calibrated positive admission remains FAIL; the
  `.42/.18/−45°` candidate had one applied lift and **zero** verified.
* **`.42/.18/+45°` stays unrun.** It is absent from the case set, and I verified it
  cannot be added without breaking the suite.
* **The 60 map journeys, the 184 static Vesper failures and production accounting
  are untouched** and remain open. `candidateMapWalks` is 0.
* No test acceptance in this package is a native pass, and every "measurement"
  in the suite comes from an in-memory fake answering from frozen AM operands
  (`fixtures.py:1-13`). No claim in this review converts one into evidence.
* Zero-motion semantics remain undefined. The two omissions stay omitted until a
  source review establishes them; this review did not establish them.
* The AM qualifications are inherited unchanged: `backendImplementationVerified =
  false`, `parentInternalCallsTraced = false`, `physicalCallCounts = null`. This
  package adds no observation that would lift them, and its receipt requires them
  to stay false (`evidence.py:356-362`).

## 8. What I would require before the mirror

1. **C1**, and then re-run the 78 tests plus a new test asserting that a duplicate
   whose frozen constants differ from the guard's is refused. Only then derive
   `evidence.gd` from `evidence.py`.
2. Fix the report's self-hash and line counts (**C2**) so the delivery record is
   accurate; the package hashes are already right.
3. Pin the blocker list (**C3**) and the `numeric_budget` dependency (**C4**).
4. Unchanged from the producer's own list, and still required: staging and grant
   creation under a reviewed namespace; a real GDScript `LiveMeasurement` with
   the ordering enforced engine-side; a real supervisor with the reviewed lock,
   consume-before-launch marker, owned-group cleanup, post-exit log scan, measured
   release audits and a timeout; and a native smoke fixture.

---

*Review conducted read-only against `62ed480e`. Nothing was pushed, merged or
rebased. The delivery branch tip `spacebunny/walker-support-query-20261005`
remains in `refs`. Only this document is committed, on
`review/walker-support-query-20261005`. No file in the delivery, in `godot/`, or
in any sibling walker package was modified.*