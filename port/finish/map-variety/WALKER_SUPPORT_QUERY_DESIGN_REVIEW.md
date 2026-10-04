# Walker support-query diagnosis — approved finite-motion comparison design

Independent Astra `ses_efc89c2afffeKQvhqPUs4YwsaY` approved `7c1f196b`, integrated
as **`d008a28b`**. Parent passed **21 checks** (eight offline, thirteen package),
nine delivery hashes, seven local references and source-receipt identity
`25382b4dd0d51b1e671a97a1478bb8bee5daaf0fff305ea024016d2c94082c40`.

## Verified interpretation

Comparison/CSV/preservation replay exactly. AM frame550 records original DOWN32
and parity short32 normal45.776894°, modeled full4 and returned floor45.646724°,
and fresh guard47.476992°. Both .35 controls retain distinct parent/full4
34.910213° versus fresh36.677326°. Normal-length errors below4.7e−8 do not explain
the discrepancy. Identity passes, velocity is zero, normal fails; the plane guard
is unreached. Pre-UP query at predicted endpoint is unrecorded.

Pinned GodotPhysics source supports conditional arithmetic:

```text
recovery residual = travel − safeFraction × motion
rest-sample origin = request origin + residual + unsafeFraction × motion
```

These reconstruct the reported recovery/rest-sample values and permit recovery
contacts at fractions1/1. They are implementation-conditioned calculations, not
measured internal transforms or proof of the active backend. A rejected finite-
motion normal does not alone prove current physical support unwalkable.

## Executable design refinement: omit exact-zero requests

The inspected `godot_space_3d.cpp:698–699` divides motion by its length without a
zero check; Vector3 division directly divides components, and the direction reaches
collision-distance solving. Exact-zero semantics are therefore not established.
**Omit zero-motion observations from the executable proposal.** Do not substitute
epsilon motion. The original contingent design document remains immutable.

## Accepted fixed finite-motion design

Two cases: .35/.15/−45° reference and .42/.18/−45° failure comparison. At the
first eligible transition, observe a down32 request from the live plan's predicted
endpoint before UP; execute one unchanged candidate response and guard; record
the predetermined duplicate down32 from actual final state afterward, then stop.
No normal selection, acceptance substitution or subsequent movement is allowed.

The candidate guard result/fault stays intact. Unexpected changed outcomes are
reported rather than forced to history. Query-state equality cannot prove caches
or other hidden state were unaffected. A future conservative preflight may avoid
an unverified lift if measurements support it; that is not proof of traversal.

A new bounded driver, observational hook, seals, validator and supervisor are
assigned source-only for independent review. No native readiness or grant exists.
AM remains failed; .42/+45° stays unrun, and sixty map journeys, 184 static failures
and production accounting remain unresolved.
