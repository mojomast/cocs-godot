# Driver v2 — source prepared, native readiness withheld pending review

This adds executable source; **nothing here has been staged, engine-parsed,
imported or run natively**. No grant exists, no work is queued. The historical
v1 plan/provenance remain byte-preserved. Source admission is not native success.

## Entry points

- `godot/tests/walker_step_up/driver_v2.gd`: explicit original/candidate factories,
  one bounded group per invocation, 170s internal deadline, full numeric traces.
- `controls_v2.gd`: real native collision fixtures; baseline and candidate run
  sequentially in separately destroyed worlds. Pure queries must not change
  transform or velocity. Rejected candidate responses must match baseline.
- `prepare_v2.py prepare walker-step-EXPLICIT-FRESH-ID`: write-once source staging
  with reviewed exact-art preflight, original15 dependency checks, explicit
  source and art hashes. This command has **not** been invoked.
- `prepare_v2.py pin-import PATH`: future post-import UID-preserving precision/
  LOD policy change. Requires real sidecars; does not run an import. Future
  separately authorized imports and reimport remain necessary. Runtime uses the
  unchanged reviewed `art_binding.gd`, pinned against `525b9fbe` at preparation.
- `run_group_v2.py`: future single-group supervisor, nonwaiting lifetime lock,
  180s outer bound, dedicated process group/start-ticks receipt, no batch loop
  or retry, three explicit empty-group release audits. No broad cleanup.

The future authorizer supplies `grant.json`, with `authorized:true`, exact
`grantId`, `expiresUnix`, `engineSha256`, explicit `groups` and optional
`continueAfterKnownBaselineFailure:true`. Every invocation requires matching
`--grant-id` and `--grant-sha256`. The runner is not an authorization issuer.
Source preparation records `grant:null`, `autoStart:false`, `queued:false`.
Import jobs require their own future ownership supervisor/grant; this runner
only handles one diagnostic group. No current command starts an engine.

## Sequence and truthful failure handling

1. `controls`: 17 fixtures × two radii, each comparing original and candidate.
   Low ceiling, forward overhang, .25/.3/.31 and guarded boundary, narrow width/
   depth, hole, pit, lateral approach, zero input, actual falling and jumping,
   tilted body, transformed parent and moving floor. Rejection reasons are
   constrained per fixture: an incidental early rejection is a failure, not a
   blanket accepted control. Settling uses ordinary steps; no floor flags or
   velocities are forged. Transform negatives intentionally change transforms
   as fixture setup, not as step correction. The pit control checks rejection
   of unsupported intent; it does not claim to exercise every down-query branch.
2. Ten unchanged accepted-civic .35 reference walks. Exactly five downhill
   landings and five uphill genuine 120-frame stalls at the historical pose,
   with `civic-stair-0Collider`, are required for `referenceExpected:true`.
   Result remains `failed:true` and process exit1. Unexpected reference outcomes
   stop; no-failure reference cannot silently unlock candidate work.
3. Explicit CLI **and** receipt permission required to continue after that
   known failed reference. Experimental accepted-civic .35 requires10/10 before
   accepted .42, candidate civic .35/.42 and roof .35/.42, in that exact order.
   Each predecessor must match source and grant identity. The original case
   lanes/endpoints are taken unchanged from the historical acceptance plan.

On any experimental fault, reset, stall or identity/clock failure, stop the group
immediately. Preserve attempted/passed/failed/unrun counts and accumulated
records. No finishing the remaining unsafe cases, excluding baseline or warping
to a success. Physical .42 dimensions are changed only in the explicit factory
and verified by actual PhysicsServer shape data. Each walk records parameters,
20 settling responses, consecutive native frame IDs, inputs, whole-frame delta,
parent position_delta/real_velocity, slide contacts, proposals, response guards
and reset counts. Whole-frame reporting remains distinct from parent reporting.

## Remaining review/native blockers

All GDScript is unparsed. Real fixture contacts/rejection reasons, exact baseline
stall reproducibility, engine assert behavior, query recovery and parent
clear-forward branch admission must be established under a future grant. The
eight-ULP response budget is conservative source policy, not observed native
error statistics. A parent slide record after a planned step **fails**, even if
its endpoint looks correct. No complete internal motion trace is claimed.

The driver deliberately does not claim full regression coverage: ordinary-world
impact tests, arbitrary dynamic supports and finite-flight clearance remain
outside these groups. The steep-normal guard and rotated-heading numeric policy
have source tests; separate native inclined-landing and rotated successful-step
fixtures remain a readiness gap before claiming comprehensive native controls.
This gap is explicit; v2 is submitted for focused source review, **not declared
grant-ready**. Production promotion and Vesper's184 static contacts stay withheld.
