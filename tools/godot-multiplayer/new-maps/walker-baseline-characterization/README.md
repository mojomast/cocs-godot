# AK ordinary radius.42 arrival: source diagnosis and fixed-control design

Base `a59804c3`, branch `astra/walker-baseline-characterization-design`.
**Source analysis/docs/tests only.** No runtime/controller/guard/policy/fixture
edits, native stage, engine/parser/import/render/server/child job or grant.
AK's independent archive review is pending; its frozen bytes are read only.

## What the actual trace establishes

The radius.42/−45° baseline advanced over the .15m tread with the unchanged
production Walker, not the experimental candidate. `Walker.step` sets horizontal
velocity to6m/s, resets vertical velocity to0 while grounded, then calls
`move_and_slide` (`walker.gd:87–98`). There is no virtual step/rise application in
that path. AK's baseline driver did run the old **read-only proposal queries**
before each ordinary step, sometimes including UP queries; it asserted
afterQueries==before and did not apply their proposed transforms. The offline
replay verifies equality for every baseline record. Zero assists does not mean
zero physics queries, and a baseline proposalAccepted flag is not an applied step.

All profiles use margin≈.02, snap≈.3, floor_max_angle≈46°, walk6, capsule height1.8,
offsetY.9, consecutive60Hz ticks, timeScale1, continued `[0,-1]` input, no jump or
sprint, one reset. The actual parameter values and all317 input-response rows
(including both candidates) are in `comparison.json` and `frames.csv`, bound to
AK51 and positive receipt SHA
`76130effe1da05bfc800fa8e14bea5b0382b87b130899a3cc1b52e2dab9bb6d7`.
Angles/along coordinates below are offline reconstruction from recorded vectors.

| Profile | First target slide | Target normals from UP | Recorded response |
|---|---:|---|---|
|.35/−45 baseline |frame29, input7 |51.306892° |wall=true; grounded on base, floorNormal UP; whole/parent delta0; velocity0 |
|.35/+45 baseline |frame217, input7 |51.306892° |same blocked behavior; both finish120 stalls, along≈−.3 |
|.42/−45 baseline |frame404, input6 |46.552733°,46.229696° |wall=false, grounded=true, Y rises.012704486m; floor normal selects second contact |

The .35 target-slide angle min/max is51.306892° throughout both blocked tails.
The .42 target-slide range is0°–46.552733°. Its edge transition is:

| Frame | Body Y | ΔY | Target-slide angles (degrees) |
|---:|---:|---:|---|
|404 |.029371150 |.012704486 |46.5527,46.2297 |
|405 |.0822997 |.0529286 |43.7957,41.8183,36.5233 |
|406 |.1257550 |.0434553 |32.3407,28.6696,25.1887 |
|407 |.1423332 |.0165781 |19.0036,12.5616 |
|408 |.165543973 |.0232108 |0,0 |
|409–418 |.165543973 |0 |0 |

At frame404 the returned velocity still has Y0 and horizontal magnitude6, but
parent real velocity is `[-3.71208048,.76226914,3.71207166]`: actual motion rose
and slowed horizontally. Parent displacement equals the baseline whole-frame
displacement; lastMotion is only `[.005251907,.012704486,-.005252041]`, not that
whole displacement. In the blocked .35 case lastMotion remains a nonzero contact
travel even though the final whole/parent displacement is zero. Neither velocity
nor the last sub-motion alone is a complete movement account.

The .42 baseline ultimately reached along≈1.00812235 at frame418 with six ordinary
landing responses, full footprint and fresh exclusive target support. That
**violated AK's required blocked baseline**, so the positive group remains FAIL.
Radius.42/+45 baseline and both .42 candidates were UNRUN; symmetry is not inferred.
Earlier AB radius.42 ordinary positive-Y evidence was a warning against equating
upward motion with an assist, not authorization to reclassify AK as a pass.

## Why a nominal46° limit permits these recorded edge contacts

Pinned Godot4.5.2 `CharacterBody3D` source adds **0.01rad** to floor_max_angle when
classifying contacts: the effective comparison is approximately **46.572957°**
for the recorded setting. Both first .42 normals are outside strict46° but inside
that engine comparison. The recorded floor=true/wall=false state and subsequent
shallower edge normals are consistent with ordinary floor/slope motion. Both .35
normals are outside either comparison. `references.json` pins the C++ file/hash
and relevant classification, wall and snap lines.

This is a strongly supported contact-classification distinction, not a unique
backend causal proof. We did not trace each internal recovery/slide/snap branch
or isolate how the rounded-capsule solver generated the initial normals. Margin,
contact sampling, recovery, finite response length and geometry influence that
generation. The .3 snap parameter is not a virtual .3 climb, and snap execution
is not individually logged. **Candidate and fresh-support explicit46° checks are
unchanged**; engine classification tolerance is not a proposed guard relaxation.

The two .35 candidates retain their individual native success: frames176/364
apply exactly one guard-verified lift, followed by ordinary responses through
seven sustained landing responses and goal arrival. The frame chart preserves
all21 input responses per candidate. It does not reduce those traversals to a
single successful frame or upgrade the failed whole group. Their whole pre-lift
delta versus parent-only motion remains distinct; production accounting is open.

## Height heuristic, not a native prediction

For an ideal lower spherical cap of radius r, bottom clearance b above the base,
and sharp tread edge at height h, the contact normal's vertical component is
`(b+r-h)/r` at exact sphere/edge contact. A floor-compatible ideal normal requires
`h <= b + r*(1-cos(theta))`. This assumes the contact lies on that cap and omits
engine recovery/margin/sampling. It is not a general step-climb bound.

Using AK's pre-edge bottom clearance≈.016666664m gives:

| Radius | Ideal threshold at46° | At46°+.01rad |
|---|---:|---:|
|.35 |.123536m |.126066m |
|.42 |.144910m |.147946m |

The .15 case is near the .42 heuristic boundary but well above the .35 boundary.
Its actual .42 arrival despite being above the ideal estimate demonstrates why
the formula is only a design aid. Treating margin as an inflated radius while
holding the sphere center fixed would instead give `b+r-(r+m)*cos(theta)`;
subtracting `m*cos(theta)` blindly ignores the simultaneous ground-clearance and
recovery changes. We do not use either expression as an acceptance guarantee.

Original planner `STEP_LIMIT=.25`, `ADMISSION_LIMIT=.3`, `GUARD=.0001`;
`rise+GUARD>=STEP_LIMIT` rejects (`sweep_proposal.gd:4–6,205,214–218`). Thus the
strict surface-rise domain is below.2499m, not.3m, with further unchanged net-rise,
head-on, support and sweep requirements. **.18m and.20m** are two predeclared
study heights inside this scalar domain and above the near-boundary .15 control.
Neither is promised to block ordinary motion or admit a native candidate.

## Proposed next characterization — design only

`design.json` predeclares **eight baseline profiles** in fixed order: two
.35/.15 references at±45°, then radius.42 at heights.15,.18,.20 and both yaws.
There are only two new heights; no adaptive in-run tuning, retry, selected-case
extension or candidate body. The .42/.15/−45 case is a historical
**ordinary-capable/non-discriminating control**, never an assisted-positive count.
Its +45 counterpart remains an unmeasured control until a separately authorized run.

Use a separately versioned fixture, preserving width4/depth3, flat static geometry,
centerline, base plane, start along−1, goal+1, capsule and controller settings.
Only rise changes. Derive all face vertices, goal height, support certificate and
fresh-support plane from that actual case rise: current helpers hard-code .15 in
geometry/landing/census and **cannot be reused unchanged or silently substituted**.
The future source package must pin the new geometry and validator as its own
characterization contract. This task supplies no runner, preparation or fixture edit.

Twenty settling plus at most240 input responses per profile caps the matrix at
2,080 responses (34.667 simulated seconds at60Hz). A future wrapper needs its own
reviewed wall deadline, grant, ownership audits, fixed matrix census and no retry.
Use baseline Walker plus observation of its ordinary contacts/states; do not call
the step-up proposal or issue UP/lookahead candidate queries. Only explicitly
scoped, test-only downward support/arrival observations are proposed. Preserve
raw ordinary collision contacts, clocks, shape/parameter/target identities,
transforms, velocities, whole/parent/last motion and query-before/after equality.

Classify every fixed case as:

* **arrived:** goal≥1, full footprint, three ordinary grounded continued-input
  responses inside the target region, and fresh exclusive support at its actual
  plane, target RID/shape and unchanged normal/epsilon bounds;
* **blocked_with_target_witness:**120 consecutive responses below.0001m net motion,
  before goal, grounded on qualified base, with recorded intended-target edge
  contact obstructing forward intent (low band below.25, head-on≥.98), not a missing
  collider, wrong obstacle, zero input, parameter drift or clock failure;
* **unresolved_at_cap:** neither qualified arrival nor blocked witness by240;
* **fault**, then remaining cases **unrun_after_fault**: stop on control/physics,
  clock, identity, query mutation, out-of-domain or nonfinite error. Never convert
  a fault or incomplete matrix into a completed characterization.

Arrival is legitimate characterization data, not a blocked-required admission
pass. Complete collection may include unresolved cases, but they are ineligible
for discrimination. A collection cannot rewrite AK's original criterion.

**After independent review only**, among.18/.20 choose the smallest height for
which both yaws are qualified blocked and reference controls show no unexplained
contradiction. Select none if neither qualifies; do not tune within the grant.
Candidate feasibility at that selected height is still unproved. A later assist
campaign needs separately reviewed height-aware positive witnesses/census, new
source/grant, and fresh34 negative/4 inclined protections and positive prerequisites.
Do not continue automatically or reuse old passes. Any radius.42/.15 candidate
comparison would be separate nonregression evidence, never a discriminating assist
pass. Real-map baselines need not all block; this design concerns artificial
discriminating guard controls only.

## Verification and boundaries

Five offline tests verify AK51 byte bindings, current-versus-staged source hashes,
actual contact/clock/domain distinctions, no baseline applications, sustained
candidate tails, reproducible317-row chart and strict proposed height limits.
No GDScript was parsed. Preservation checks cover prior inventories and15 production
dependencies; original runtime/policy/fixture sources and historical receipts stay
unchanged. The two partial synthetic candidate passes do not resolve the184 static
Vesper failures, any of the60 unrun candidate map journeys, or production motion
accounting. AK positive FAIL and historical unknown counts remain unchanged.
