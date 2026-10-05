# Bounded two-case Walker support-query comparison — source only

Implements the approved design in
`port/finish/map-variety/WALKER_SUPPORT_QUERY_DESIGN_REVIEW.md` (integrated as
`d008a28b`) as a deterministic, offline Python package. Branch
`spacebunny/walker-support-query-20261005`, base `feature/relay-campaign`
`91b0b801`.

**This package contains no engine invocation and produces no native evidence.**
Every "measurement" in its test suite comes from an in-memory fake that answers
from the frozen AM operands. Nothing here is a grant, a fixture, a staged
project or a result.

## What it implements

Two fixed finite-motion cases, and only two:

| Case id | Radius/rise/yaw | Role |
|---|---|---|
| `reference-035-015-neg45` | .35/.15/−45° | passing reference |
| `failure-042-018-neg45` | .42/.18/−45° | failure comparison |

At the **first eligible transition** of each case, the driver runs exactly one
sequence and then stops:

1. **`pre_up_observation`** — a down32 request at the live plan's predicted
   endpoint, *before* the UP step;
2. **`candidate_response`** — one unchanged candidate response and guard;
3. **`guard_observation`** — the guard's own actual-final-state down32, recorded
   verbatim and preserved as primary;
4. **`duplicate_observation`** — the predetermined duplicate down32 at that same
   actual final state;
5. **`stop`** — terminal. No further movement, no retry.

The predicted endpoint is `raised.origin + horizontalBudget`, the same quantity
`response_guard.gd:29` builds. Its height legitimately differs from
`expectedFinal` because `apply_floor_snap` projects Y only, so the package
requires horizontal agreement within the guard's epsilon and *records* the
vertical offset instead of demanding it to zero.

### Exact-zero requests are omitted, not substituted

`godot_space_3d.cpp:698–699` divides motion by its length with no zero check, so
exact-zero semantics are not established for this build. Both zero-motion
observations from the reviewed design are therefore **omitted** from the
executable proposal and recorded as omissions (ordinals 2 and 5) carrying
`executed: false` and `substitutedMotion: null`. Epsilon motion is never
substituted: `hook.omission` refuses any requested motion that is not *exactly*
zero, refuses any substituted motion, and recognizes only the
undefined-zero-semantics reason.

### Predetermination, stated precisely

Everything knowable before execution is frozen first by `hook.frozen_operands`:
motion, margin, max contacts, recovery-as-collision, separation-ray, body RID,
exclusions, test-only. The one field that cannot be predetermined is the pose —
"the actual final state" is by definition known only after the candidate response
returns — so it is taken verbatim from the guard's own recorded request and never
chosen.

The frozen constants are recorded as one explicit tuple, and the validator checks
all three executed requests against it:

| Where | What |
|---|---|
| `history.reference` → `amFrozenOperands` | the AM guard's own operand tuple, read from the SHA256-pinned export (per case) |
| `prepare.contract` → `proposal.frozenOperandsByCase` | the same per-case table, sealed in the prepared record **before** execution |
| `driver._record` → `frozenOperands` | the tuple the driver actually froze for that case |
| `campaign.compose` → `frozenOperands` | the same tuple, per case, carried into the receipt |

`evidence._frozen_operands` then requires all three of:

1. the recorded tuple is well formed (`hook.frozen_tuple`: exact `CONSTANTS` key
   set, positive integer RID, margin that yields a nonzero motion, motion equal to
   the *derived* `-UP * (margin + LIMIT)`, 32 contacts, the two true flags, empty
   exclusions, test-only);
2. it is **anchored on the design-frozen constants** — those equal the pinned AM
   guard's, so the tuple cannot be re-tuned inside a receipt — and the record's own AM
   binding is the very tuple the validator was handed, on every constant, so a receipt
   cannot substitute one approved set for another;
3. the run-frozen body RID is **pinned by this run's own agreement**
   (`hook.run_frozen_unchanged`): identical in the record's own recorded tuple and in
   all three executed requests. It is deliberately *not* compared with the AM run's
   RID — see below;
4. the pre-UP request, the guard's own recorded request and the duplicate request
   each carry exactly that tuple on every constant, **and** agree with each other
   pairwise (`hook.operands_unchanged`, which checks both).

Which constant is pinned how is enumerated rather than implied — the three groups
partition `CONSTANTS` exactly (`hook.DESIGN_FROZEN_CONSTANTS`,
`hook.DERIVED_FROZEN_CONSTANTS`, `hook.RUN_FROZEN_CONSTANTS`):

| Group | Constants | Provenance | Pinned by |
|---|---|---|---|
| design-frozen | margin, max collisions, recovery-as-collision, separation-ray, exclusions, test-only | reviewed `sweep_proposal.gd` / `response_guard.gd`, recorded in the pinned AM request | equality with the SHA256-pinned AM guard request |
| derived | motion | computed from the frozen margin; the AM request records a float32 rounding of it, so the anchor derives rather than copies | re-derivation from the frozen margin (`hook.frozen_tuple`) |
| run-frozen | body RID | assigned by the engine for one run | identity across the record's own tuple and all three requests (`hook.run_frozen_unchanged`) |

**This run's body RID is not required to be the AM run's body RID.** A RID is
assigned by the engine for one run, so a fresh one is what a genuine next run
produces; requiring the AM value would refuse the first real run's receipt, and
`driver.run_case` does not compare it either. `prepare.contract`'s
`frozenOperandsByCase` carries the AM run's `bodyRid` as *provenance of the anchor*,
not as a prediction of the next run's RID — which is why the table's authority is
over the design-frozen and derived constants.

`tests` reproduce the independent review's six re-tunings (guard margin, guard
motion, guard bodyRid, duplicate margin, duplicate bodyRid, pre-UP bodyRId) as
negative cases with `recordsSha256` **re-derived by the forger**, so only a
structural predicate can refuse; all six are refused, as is a *consistent* re-tune
of all three requests plus the recorded tuple plus the receipt table. Every such
forgery is **preconditioned**: each observation is still internally consistent (the
edit is mirrored into its own `result`), so the refusal is attributable to the
cross-observation layer rather than to the isolation predicates it makes redundant.

The anchors are carried **behaviourally**, not by source shape alone.
`FrozenOperandTests` loads a copy of the validator with one anchor's *enforcement*
removed — the call, its operands and its docstring all kept, which is the mutation a
`co_names` assertion cannot see — and requires the forgery that anchor is responsible
for to be admitted by the copy. Mutating the shipped validator is therefore a test
failure: neutering the design-frozen anchor, either record-binding anchor, the
run-frozen anchor, or the whole-tuple comparison each fails, as does deleting any of
them. Measured, and stated rather than implied: the well-formedness gate
(`hook.frozen_tuple`) is *redundant* — every malformed tuple it refuses is also refused
by one of the four anchors — so it is kept as defence-in-depth and its redundancy is
asserted, not left implicit.

What the check does not claim: that the recorded tuple is the one the driver froze.
That is the prepared source record's job, and the receipt's `sourceSha256` binds the
two. From a self-attested record alone the validator proves that the three requests
agree with each other and with one operand set whose design-frozen constants are
anchored to the pinned AM history.

### Guard outcomes are preserved and history is reported, never enforced

The guard's pass flag, reason and candidate fault are recorded exactly as
returned. Divergence from the frozen AM history is *reported* in
`unexpectedChangedOutcomes` and `unexpectedOutcome`, with the historical value
kept alongside. Nothing is rewritten to match history, and a receipt that reports
a divergence while claiming agreement — or claims divergence silently — is
rejected.

### No overclaiming

Every recorded observation carries the qualification that equal recorded body
state does not prove caches, broadphase or other hidden state were unaffected.
The receipt requires `operationalNeutralityProven`,
`hiddenStateUnaffectedProven`, `queryStateEqualityProvesCacheNeutrality`,
`backendImplementationVerified` and `parentInternalCallsTraced` to be explicitly
false, and `physicalCallCounts` to be null. The validator deliberately does **not**
apply the strict 46° predicate: this package measures a normal, it does not judge
one, and applying the guard's threshold would make the validator reject the very
failure the campaign exists to re-observe.

## Boundaries

* **Source-only.** No engine, no native parser/import, no renderer, no server,
  no child job, no native stage, no grant. `invocation.audit()` parses every
  module in the package and verifies via the AST that nothing imports
  `subprocess`, `multiprocessing`, `shutil` or `pty`, and that no module
  references `os.system`, `os.popen`, `os.exec*`, `os.fork`, `os.spawn*` or a
  launch method on a spawning owner.
* **The supervisor refuses.** `supervisor.preflight()` performs the complete
  fail-closed preflight a real supervisor would perform — namespace, record
  contract, seals, frozen references, AM history, grant schema, hash binding,
  expiry — and then `refuse()` writes a sealed, write-once record of why the
  campaign cannot run. It is a written refusal, not a dry run and not a stub. The
  `{engine}` and `{fixture}` argv slots stay literal placeholders because
  resolving either would imply a stage exists.
* **The blocker list is pinned.** `NATIVE_READINESS_BLOCKERS` is asserted against
  six literals in the suite, not only against itself, so softening or blanking an
  entry fails.
* **No GDScript staging.** The bounded driver and hook exist as offline Python.
  `prepare.build` refuses to place a record anywhere under `godot/`.
* **AM stays failed.** Whole calibrated positive admission remains FAIL; the
  .42/.18/−45 candidate had one applied lift, zero verified.
* **.42/.18/+45° stays unrun.** It is absent from the case set, and a test
  asserts that.
* **60 map journeys, 184 static Vesper failures and production accounting remain
  untouched.** `candidateMapWalks` is 0.
* No `.20` fallback, no guard widening, no epsilon tuning, no acceptance
  substitution, no normal selection.

## Files

| File | Role |
|---|---|
| `policy.py` | phase/mode/case allowlist, canonical cases, schemas, grant validation |
| `hook.py` | observational hook: frozen down32 operands, zero-motion omission, result checks |
| `driver.py` | bounded driver state machine and the `LiveMeasurement` boundary |
| `evidence.py` | fail-closed receipt validator |
| `campaign.py` | receipt composition |
| `history.py` | frozen AM reference and the derived per-case frozen-operand anchor |
| `prepare.py` | write-once offline source record, seal manifest, validation |
| `supervisor.py` | source-only supervisor that records a refusal |
| `invocation.py` | AST audit proving no engine-invocation path exists |
| `seals.py` | write-once JSON, seals, path safety |
| `fixtures.py` | deterministic in-memory `LiveMeasurement` for tests only |
| `cli.py` | isolated package loader and single-operation CLI |

## Running the tests

```sh
python3 -B -m unittest discover \
  -s tools/godot-multiplayer/new-maps/walker-support-query-compare -p 'test_*.py'
```

**91 offline tests pass.** No native execution. The suite covers: the case set is
exactly two; zero-motion requests are omitted with no epsilon substitution;
observation ordering including the pre-UP predicted-endpoint request, one
candidate response plus guard, the post-hoc actual-endpoint duplicate and the
stop; the frozen down32 operand tuple being recorded, anchored to the pinned AM
history and proven unchanged across all three requests; guard result and fault
preservation and reported divergence; seals and the validator rejecting tampering
and unexpected outcomes; the native-readiness blocker list being pinned verbatim;
that no third case, second candidate response, later eligible transition or
post-stop movement is reachable; and that the package never claims cache
neutrality, backend verification or a verdict on a support normal.

Optional CLI exercise (offline; writes a record and a refusal, still no engine):

```sh
python3 -B tools/godot-multiplayer/new-maps/walker-support-query-compare/cli.py \
  prepare build support-query-compare-review-only --parent /tmp/opencode/sqc-runs
python3 -B tools/godot-multiplayer/new-maps/walker-support-query-compare/cli.py \
  supervisor --record /tmp/opencode/sqc-runs/support-query-compare-review-only
```

No test acceptance in this package is represented as a native pass, and none of
these commands can become one.
