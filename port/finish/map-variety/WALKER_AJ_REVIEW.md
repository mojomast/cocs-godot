# Walker AJ — receipt-only native confirmation

Independent Astra `ses_efc89c2afffeKQvhqPUs4YwsaY` approved `bb403edf` +
`bfb32d4e`, integrated as **`d8e03668` / `0b420dc1`**. Parent passed **93 checks**
(80 Python, thirteen package) and all **23 inventory hashes/sizes**. The 4,842-byte
manifest matches SHA-256
`dc49cc762bb1eab492e480c429c3528d982154943f32332f9e0d35029d5a030f`.

## Verified native result

Independent read-only replay reproduces analysis and preservation reports. The
3,692-byte raw log contains exactly one result marker, a 3,605-byte JSON body,
and no recognized errors. Its parsed result matches the archive.

| Observation | Verified result |
|---|---|
| Original whole policy | false |
| Exact one-clause clone | true |
| Numeric/type controls | 15/15 agree |
| Whole-policy mutants | 7/7 rejected |
| Candidate records / membership failures | 678 / 678 |
| Collection / recomputed confirmation | true / true |

The helper measures case0/profile1/settle0, line139, FLOAT zero against INT zero/
one, with checks `[true,true,true,false,true,true]` and numericAlternative true.
This is an independently failing invariant, not a first-executed-branch trace.

## Binding and scope

The six-script closure, host pins, binary and fifteen production dependencies
match reviewed identities. Original predicates are unchanged. The Evidence clone
changes only membership to numeric inequality, retaining the finite-integer guard;
the Policy clone changes only its preload. AI validator-input hashes and frozen
receipt are distinct from AJ's execution grant/source.

Both policies receive the same parsed receipt and mutants use deep copies.
Immutability is source-assured; no pre/post serialization measurement is claimed.
No Walker/body/world construction or physics-query code occurs in the closure;
this is a source-scope assurance rather than engine-internal tracing.

Engine and supervisor exit 0. Parent verified release at 07:07:14.880139Z,
three measured empty audits/one group, no survivors and lock availability at
07:11:35.025158Z. No heavy grant is active.

## Next boundary

The exact campaign-validator correction is justified as a new reviewed source
change: `not up in [0,1]` → `(up != 0 and up != 1)`, preserving `not integer(up)`.
Updated pins and regression checks require review before a fresh campaign grant.
Source preparation is active; campaign behavior has not yet been changed.

Fresh negatives, inclined controls and positive admission must use new source/
grant bindings and ordered, reviewed prerequisites. Frozen AI receipts and AJ
confirmation cannot substitute. AI/AH failures and unknown internal counters stay
unchanged. Positive four pairs/eight profiles and sixty map journeys remain unrun;
production motion accounting remains unresolved.
