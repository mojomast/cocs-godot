# AI Policy.successful — source-only diagnosis

Base `4ff538fe`, branch `astra/walker-policy-source-diagnosis`. Frozen AI is read
only from `/home/mojo/.tmp-on-disk/cocs-walker-parity-admission-ai`.

## Finding: concrete source-model type mismatch

`evidence.gd:139` contains `not up in [0,1]`. `up` is a Variant read from the
parsed receipt. The literal array contains INT values. Pinned Godot4.5.2 sources
show that JSON numeric tokens become FLOAT, while Array membership uses
type-sensitive `hash_compare`, not the cross-type numeric equality used by Python
membership. The string comparator exception covers String/StringName only.

Thus **FLOAT0.0 is not a member of the untyped INT array [0,1]** in this source
model. This is a concrete discrepancy from the host check, which accepts
`0.0 in [0,1]`. Parsing every JSON number as a Python float does not model Godot
Array membership and therefore did not expose this discrepancy in the earlier
host replay. `references.json` pins the entire upstream call chain by SHA256 and
line numbers, including both normal and validated operator evaluation.

First actual AI witness:

| Item | Value |
|---|---|
| Receipt SHA256 | `708fda878f694b46c0ae1968aca653a206ac7b39e9f3af61e0807154cf2922f4` |
| JSON pointer | `/records/0/profiles/1/settle/0/appliedUpCount` |
| Case / role | ceiling-up radius.35 / experimental |
| Serialized number / modeled parsed type | 0 / FLOAT |
| Allowed literal elements | 0 INT, 1 INT |
| Source-model membership | false |
| Python membership | true |

The same mismatch is modeled for **all678 candidate ordinary-response records**.
AI40 exact hashes/byte sizes are verified before replay. Both ordinary Python
JSON and all-numbers-as-double host policy replay pass; all68 host profiles pass.
Largest integer-valued JSON token magnitude is2,181,843,386,370, below2^53.

**Measured native evidence still identifies only `predecessor.native_policy`.**
The source model predicts a specific failing invariant, but does not measure the
first executed internal rejection. No additional engine or GDScript parser ran.
This finding does not retroactively identify AH's executed native branch.

## Branch-by-branch comparison

Line numbers refer to byte-identical AI staged `policy.gd` and `evidence.gd`.
“Host passes” is a Python/data fact, not a native branch trace.

| Predicate branches | Actual data / source comparison |
|---|---|
| Policy29–31 group, phase/mode/scope, hash bindings | Host passes actual AI identities; no reconstructed hash serialization |
| Policy32–34 flag values/types | Actual JSON booleans; host passes, not numeric booleans |
| Policy35–40 counters, positive flag, record census |34/68 exact finite integer-valued counts; direct numeric comparisons accept INT/FLOAT; negative positiveAdmission=false |
| Policy41–49 case/status/profile/role/zero assists | All34x2 records pass host checks; numeric zero checks use `number`, not Array membership |
| Policy50–53 positive-only clauses | Not reached for negative group |
| Policy54 → Evidence233–240 outcome/spec/profile | Canonical34 specs and68 profile shapes pass host; profile body remains the key native family |
| Evidence96–104 outcome/reached/parameters/geometry | Negative expected outcome, false reached, parameter comparisons with tolerance; target() skipped |
| Evidence105–116 settle/basis/input census |20 settles except airborne1; jumping2 frames otherwise1; basis comparisons pass host |
| Evidence125–128 returned/fault/input/frame/clock | All1,356 records satisfy host state/input/clock checks |
| Evidence129–134 state/delta/proposal | Numeric arrays and booleans; no Vector3 reconstruction here. Delta residual tolerance passes host |
| Evidence130 positive-only bodyRID/floor clause | Skipped for negative group; not a candidate explanation |
| Evidence139 candidate lifecycle | Six conjunctive requirements; `up in [0,1]` has a pinned C++ type-semantic discrepancy. Original acceptance unchanged |
| Evidence140–155 ordinary/accepted/parent/totals | Candidate ordinary true, original accepted false, zero up, one parent call; host passes. Positive guarded path skipped |
| Evidence156 baseline afterQueries equality | Parsed dictionaries compare to parsed dictionaries, both with numeric FLOAT leaves; host exact equality passes. No INT literal structure is introduced here |
| Evidence165–170 summary/reasons/witness/negative stages | Host passes totals and reasons; witness present where required; exact mechanism families verified |
| Evidence199–222 stage names, operands, fractions, floor/head-on | Host passes all applicable terminal plans; schema vectors are arrays; not a Vector3 downcast |
| Evidence241–246 paired state agreement | All paired origins/velocities/grounded match in host data |
| Evidence308–339 supervisor timestamps | Not inside Policy.successful; follows its success at driver106. Irrelevant to the observed earlier gate |

The policy/evidence validation path uses numeric arrays and scalar arithmetic;
it does not reconstruct Vector3 state. Most parameter comparisons use tolerance,
including margin. This investigation found a direct type-membership discrepancy
without needing a speculative float32 transform or fractional-time theory.

`driver.gd:62–80` writes the completed receipt without calling Policy.successful.
Its successful negative completion therefore did **not** establish in-memory
native Policy.successful acceptance. The native call at line105 occurs on parsed
predecessor JSON, in the subsequent invocation. No in-memory/native parsed
equivalence claim is warranted.

## Reviewable bounded diagnostic proposal

`diagnostic.gd` is an **unwired, unparsed/unrun** pure receipt helper. Original
driver/policy/evidence and review pins are byte-identical. There is no entrypoint,
native stage, runner, grant, file output, global diagnostic state or physics API.

A future caller first gets the unchanged Policy.successful result. On failure,
the helper searches original Evidence.profile evaluations in canonical order.
For the first failing profile it reports a bounded case/profile/record location
and the six booleans at line139, operand Variant types, numeric value, and the
INT literal operands. It reports `undetermined` when it cannot localize this
family. It explicitly labels an independently failing invariant, not the first
executed branch. Successful original evaluation is reported as such but never
authorizes anything. Output is fixed metadata and finite numeric operands only;
no arbitrary receipt strings, paths, arrays or full records are copied. The
single record is comfortably below8KiB. It retains unknown physical counters.

This targeted helper avoids copying/refactoring all acceptance branches. It can
confirm the identified discrepancy in one future read-only receipt probe rather
than issuing one native campaign per field. A full first-branch tracer is not
claimed. Existing admission stderr classification remains unchanged.

### Proposed fix contract — not applied

Replace only membership with explicit numeric equality, retaining `integer(up)`:
`(up!=0 and up!=1)` in place of `not up in [0,1]`. The already-present finite
integer guard rejects booleans, fractions and nonfinite values. This would accept
both integer and parsed-float encodings of exactly0 or1 without changing the
value-domain contract. Tests exercise this proposed contract only; no runtime
predicate, guard, epsilon, planner, source pin or historical receipt is edited.
Parent review and native diagnostic confirmation remain appropriate before any
acceptance change. Fresh campaign bindings/prerequisites are still required after
a reviewed fix; the frozen AI receipt cannot become campaign authorization.

## Optional future receipt-probe contract (design only)

No executable launcher/stager is included. Parent may separately authorize one
hash-bound, minimal headless invocation loading **this immutable AI negative
receipt** and unchanged pinned Policy/Evidence plus the helper. The future source
must enforce a diagnostic-only phase, fixed receipt SHA and binary/source hashes,
new grant/expiry, one invocation, nonwaiting lock,170/180 deadlines, one-thread
limits, fast-exit log scan and measured group release. It must create no game
body/world and perform no physics query. No campaign dependency file is emitted.
Its result must distinguish `probeCollected` from `originalPolicyResult:false`;
probe completion never means native campaign acceptance. Diagnostics are bounded
stderr captured by the supervisor, not paths derived from CLI arguments. The
existing campaign supervisor must not be silently reused with relaxed schema.
That wrapper and its exact authorization schema require review before execution.

No grant exists for this task. Positive4/8 and all60 candidate map journeys remain
unrun; production accounting remains open. AI inclined counters remain unknown.
