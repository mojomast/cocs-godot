# Walker receipt policy — numeric-membership source diagnosis approved

Independent Astra `ses_efc89c2afffeKQvhqPUs4YwsaY` approved additive diagnosis
`707e2fe6`, integrated as **`609e0ca8`**. Parent passed **67 checks**: five targeted,
49 admission and thirteen package tests. No campaign predicate is changed.

## Verified source semantics

The reviewer independently fetched five pinned Godot 4.5.2 files and verified their
hashes. JSON numbers become Variant FLOAT, including integer-looking zero.
Numeric Array membership uses `OperatorEvaluatorInArrayFind` → `Array.find` →
`Variant::hash_compare`, which rejects INT/FLOAT type differences. Its exception
for String/StringName does not cover numeric types.

Parser precedence, array analysis and bytecode preserve `not (up in [0,1])` with
an untyped literal containing INTs and a parsed Variant operand. No implicit
cross-type numeric equality is substituted. Direct equality/inequality instead
has registered INT/FLOAT numeric operators.

The first AI witness, `/records/0/profiles/1/settle/0/appliedUpCount`, produces
modeled checks `[true,true,true,false,true,true]`. Membership is the failing
invariant. The source model finds the same discrepancy in all 678 candidate
ordinary records. No second numeric-literal membership test was found in the
current acceptance predicates.

This establishes a source-semantic mismatch, **not the first executed internal
native rejection**. AI still directly proves only `predecessor.native_policy`;
AH remains internally untraced. Negative completion writes its receipt without
native `Policy.successful`, so it did not test the parsed-predecessor path.

## Approved narrow correction intent

Replacing the membership clause with `(up != 0 and up != 1)` is approved as
source intent **only while retaining the preceding finite `integer(up)` guard**.
That guard excludes booleans, strings, fractions and nonfinite values; no added
guard is required for this substitution. The correction is documented, not applied.
It removes the modeled discrepancy without proving complete native policy success.

The unwired helper has no entrypoint, file writes or physics calls. It reports
bounded locations/types/checks and an `undetermined` fallback, not a traced first
branch; physical counters remain unknown. Stage/host pins and fifteen production
dependencies remain unchanged.

## Next scope

A separately reviewed receipt-only probe is being prepared to run original and
one-clause-clone predicates on the same hash-bound parsed AI JSON, with integer/
float zero/one and invalid-value controls. It must construct no campaign world
or body and perform no physics queries. Collection and policy acceptance are
separate outcomes; old AI receipts cannot become fresh campaign prerequisites.
The wrapper requires source review and new explicit authorization. No heavy grant
is active; positive four pairs/eight profiles and all sixty map journeys remain
unrun. Production motion accounting stays unresolved.
