# Additive P1 response-guard correction

Original `161f5e9e` evidence and `acceptance-plan.json` remain historical. Changed
experimental source hashes are recorded separately. No engine has parsed or
executed this correction; production remains unchanged.

The guard now compares the actual final global position with `expectedFinal`,
the full parent `get_last_motion()` vector with the proved horizontal vector,
and the final horizontal coordinates with the proved downward axis. Equal
travel length or positive progress cannot substitute for these comparisons.
The review counterexample `[.04,.10,.08]` versus `[0,.12,.10]` rejects.

Numerical policy: eight float32 ULPs at the maximum absolute world coordinate
of the proof/response (minimum1µm). Refuse coordinates needing more than0.1mm;
also refuse a budget greater than 1% of existing collision margin. There is no
safe-margin-sized endpoint allowance. At Vesper's coordinate scale the budget
is tens of micrometres, not centimetres. This accounts for a short chain of
float32 transform/travel additions; it is a proposed conservative identity
budget requiring native confirmation, not a claim about all backend errors.
Both proofs and actual motion keep the original .02m margin. Physical-capsule
path claims are conditional on that margin and this tiny bounded roundoff.

Endpoint agreement alone is insufficient. The guard **rejects every parent
slide collision** after a planned lift and records its travel/remainder for
diagnosis. It does not pretend that `get_slide_collision()` reconstructs all
internal motion. With pinned `character_body_3d.cpp`, no platform motion,
`floor_constant_speed=false`, zero slide records and exact last-motion-vector
agreement, the admitted branch is a single clear forward motion followed by
the existing floor snap's Y-only projection. Any other branch is unproved and
fails. This intentionally may reject usable native motion; that is a blocker,
not permission to relax the guard during a run.

A fresh, **test-only downward live-body capsule query from the actual final
transform** must report positive support. Every returned contact must have the
certified RID and collider shape index, local capsule shape0, finite results,
normal≤46°, zero collider velocity and contact Y on the certified landing plane
within the numeric budget. Source height equality and `get_floor_normal()` do
not establish support identity. The planner now retains the exact support RID
and shape. Mismatch sets `candidate_fault`; no rewind, retry or warp.

The independent source support oracle also checks `range(len(hull))`; triangle
and pentagon tests cover the omitted fifth-edge counterexample. Existing 940
actual-tread strip checks remain passing. **21 source tests pass** (original16
plus five response/non-quad regressions). These remain source geometry/policy
and API checks, not GDScript execution.
