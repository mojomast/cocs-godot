# Vesper corrected-binding native batch (2026-10-05)

Fresh attempt `vesper-binding-01`. Six groups x ten walk-only direct
`Walker.step` journeys (60 walks), corrected art binding (accepted + candidate
X), radii .35/.42. **Diagnostics only.** No gate is waived: the 184 failed
static contacts remain failed and positive admission is not established.

## Policy note (parent judgment, recorded)

The user-approved policy was "calibrate, then batch": `accepted-civic-r035`
first, fail-closed as the binding calibration. That group exited 1 (5/10
reached) **but** both binding flags are true
(`bindingReady`, `bothVariantsRuntimeVerified`) and the result reproduces the
archived `vesper-Z-01` baseline exactly (same 5/10, same 410/127 frame counts,
same stall flag). The calibration's purpose -- prove the corrected binding
machinery works end-to-end -- is satisfied; the 5/10 is the genuine geometry
phenomenon under study (the runbook explicitly keeps expected stair stalls as
failures). The remaining five groups were therefore run as designed, and every
failure below is preserved unwaived. The strict alternative ("any failed group
stops the sequence") was offered and not chosen.

## Results

| case | reached | binding | failing trials and stall contact |
|---|---|---|---|
| accepted-civic-r035 | 5/10 | true | 1,3,5,7,9 `civic-stair-0` z24.70 51.1-51.3 deg |
| accepted-civic-r042 | 6/10 | true | 3,5 `civic-stair-0` z24.60 46.6 deg; 7,9 `civic-stair-1` z25.11 46.6 deg |
| candidate-civic-r035 | 5/10 | true | 1,3,5,7,9 `civic-stair-0` z24.70 51.1-51.3 deg |
| candidate-civic-r042 | 5/10 | true | 1 `civic-stair-69` z59.10 46.6 deg; 3,5 `civic-stair-0` z24.60 46.6 deg; 7,9 `civic-stair-1` z25.11 46.6 deg |
| candidate-roof-r035 | 5/10 | true | 1,3,5,7,9 `roof-ramp-step-0` z52.70 49.8 deg |
| candidate-roof-r042 | 8/10 | true | 7 `roof-ramp-step-11` z62.06 45.1 deg; 9 `roof-ramp-step-10` z61.24 45.1 deg |

Every failed walk ends stationary (velocity zero) against a stair ascent edge
after 120 stalled frames at `is_on_floor` false or unsupported. All six
binding receipts report `bindingReady` and `bothVariantsRuntimeVerified` true.

## Findings

1. **The correction is verified.** The earlier two-pass import policy (UID
   retained, compression and LOD generation disabled) and both-variant runtime
   verification hold for all six groups; the Z baseline is reproduced
   deterministically.
2. **Candidate X art does not change collision behavior.** candidate-civic-r035
   is trial-identical to accepted-civic-r035; candidate-civic-r042 differs only
   in one trial (stair-69). The stall is an authority/collision property, not a
   finish/art property.
3. **Contact normals sit just at or over the 46 deg floor guard.** r035 stalls
   at 49.8-51.3 deg (first tread of each run); r042 stalls at 45.1-46.6 deg.
   The .42 envelope advances further (accepted-civic 6/10, candidate-roof 8/10)
   but is test-only and still fails.
4. **The normal-angle predicate is not the only blocker.** candidate-roof-r042
   stalls on 45.1 deg contacts -- under the 46 deg guard. This matches the bevel
   proposal's explicit caveat that collider identity, `colliderVelocity`,
   contact Y vs `landingY` and the no-slide branch remain unproven. A pure
   normal-angle fix may not clear every r042 walk.
5. **Real stalls, confirmed.** The reviewed 45 deg ascent-edge chamfer (94
   treads: 80 civic + 14 roof, leg 0.043438 m, height-preserving) is the
   standard-practice remedy identified in
   `VESPER_STAIR_COLLISION_PROPOSAL_20261005.md`; whether it must be
   accompanied by a step-height/no-slide adjustment is now the open question.

## Evidence

- Attempt: `godot/tests/new_maps/botanical_post_x/vesper-binding-01/`
  (source.json, import-policy.json, variant JSON/GLB copies, import sidecars,
  46 extracted PNGs, six binding receipts, six journey receipts, 60 trial
  parameter receipts).
- Harness: `/tmp/opencode/vesper-batch-01/` (bounded owned-runner emulation,
  per-step logs, triage matrix).
- No runtime file, receipt layer, or movement-contract byte was modified by
  this batch.

## Next

Rebuild path (per the approved blocker plan): apply the reviewed bevel patch,
re-run the static census and the 59 Py + 11 Node tests, then a fresh
`vesper-binding-02` native attempt. That second heavy grant, and any runtime
promotion of the beveled authority, need explicit approval.
