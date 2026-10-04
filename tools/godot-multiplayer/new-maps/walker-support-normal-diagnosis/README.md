# AM support-normal diagnosis — source only

Base `fb377b21` (approved calibrated source parent `3dcdbb27`), branch
`astra/walker-support-normal-diagnosis`. AM archive review remains independently
active; this is an additive diagnosis, not archive approval or a correction.
Frozen AM root: `/home/mojo/.tmp-on-disk/cocs-walker-calibrated-admission-am`.
No engine, native parser/import, renderer, server, child job, native stage or
grant. No controller, planner, fixture, guard or epsilon changes.

## Conclusion

**AM's first .42/.18/−45 candidate failed its strict live support-normal guard,
not its endpoint budget.** The fresh query's normal is47.476992°, its velocity
is zero; explicit46° is required. The returned body remained grounded, with
floor normal45.646724°. This does **not** establish that the actual current
physical support is unsafe or unwalkable. It establishes failure of the reviewed
candidate acceptance contract, whose fresh finite-motion support test differs
from the parent floor observation.

The query request/pose difference is measured; backend normal-generation cause
is not uniquely traced. A read-only fixed query comparison is the preferred next
measurement design, described in `DESIGN.md`; it is neither implemented nor
authorized here. A conservative endpoint preflight could prevent applying this
class of rejected proposal, but cannot turn rejection into a responsive step.

## Actual operands, not interchangeable normals

All rows below refer to **frame550**, target RID266287972354, collider
ID114957485456, target shape0/local shape0, body RID274877906947, shape
RID283467841538. Actual capsule radius .419999986887, height1.799999952316,
offsetY.899999976158. Input horizontal budget length≈.1m, one60Hz response.
Original/short/full start at XZ `[.212131947279,−.212131947279]` with Y.202130958438;
the guard starts at that same XZ but actual/predicted endpointY.054474696517.
All share the recorded yaw basis and margin .019999999553.

| Observation | MotionY | Max contacts | Safe / unsafe | TravelY | Normal angle from UP |
|---|---:|---:|---|---:|---:|
| Original proof DOWN32 |−.205564290285|32|.7265625 / .73046875|−.149355307221|45.776894°|
| Repeated parity short32 |−.205564290285|32|.7265625 / .73046875|−.149355307221|45.776894°|
| Modeled parity full4 |−.300000011921|4|.4921875 / .49609375|−.147656261921|45.646724°|
| Actual returned parent |Internal request unrecorded|Unrecorded|Unrecorded|Parent deltaY−.147656261921|45.646724° floor API|
| Fresh guard down32 |−.020099999383|32|1 / 1|−.008744077757|**47.476992°**|

All four recorded queries use recoveryAsCollision=true and
collideSeparationRay=true. Full request transforms/bases, flags, margins, fractions,
travel/remainder and ordered unmodified contacts are in `comparison.json` and
`operands.csv`. Body/mask/shape context is separate from fields actually serialized
on a legacy query; missing legacy RID fields are not filled in as native facts.
Full4 directly records targetRID; fresh guard identity is separately recorded in
`finalSupportIdentities` (resolved RID, shape/local index0). Original DOWN32 lacks
a direct RID field but its colliderId matches the bound parity contact. All
contacts have static zero velocity and pointY=.180000007152557.

Full4 is a **read-only modeled request**, not a captured internal parent snap
request. Its normal and projected travel happen to match the returned parent
floor normal and vertical delta exactly. The actual internal start transform,
call counts and branch execution are not observed. Source modeling is not tracing.

The original proof endpointY=.052775651217 differs from the selected parity
endpointY=.054474696517; the latter exactly equals the actual returned endpoint.
Fresh guard `from` equals the full actual transform. Its result travel is
`[.008180424571,−.008744077757,−.008180618286]` despite a pure−Y request; no part
of this observer travel was applied to the body. The actual before/after guard
state remains unchanged. Treating the query normal as a direct current-pose
surface normal is therefore not justified by its name alone.

### Normal normalization and pass controls

Raw vector lengths differ from1 by less than4.7e−8 for all recorded support
normals. Normalized angle versus raw `acos(normal.y)` differs by less than1e−5°.
The guard compares the raw dot with `cos(floor_max_angle)`; the normalized
diagnostic does not change that predicate or explain its failure.

| AM candidate | Full4 = returned floor angle | Fresh guard angle | Outcome |
|---|---:|---:|---|
|.35/.15/−45, frame176|34.910213°|36.677326°|Guard pass|
|.35/.15/+45, frame364|34.910213°|36.677326°|Guard pass|
|.42/.18/−45, frame550|45.646724°|47.476992°|Guard fail|

Each comparison is within the same profile/body/target, not a claim that RIDs
are shared across profiles. The .35 proof DOWN32 angle is34.862618°. The later
short query has a different pose and travel even in successful cases. This is
evidence of differing observations, not authorization to replace a normal.

## Which guard checks actually executed?

Unchanged `response_guard.gd:31–50`, matched to frozen AM:

1. Numeric domain and epsilon budget: passed (1µm).
2. Actual expected endpoint: passed, exact zero error.
3. No returned slide collisions, no platform velocity/angular velocity,
   floor_constant_speed=false: passed.
4. Exact forward vector within epsilon and down-axis endpoint: passed.
5. Aggregate grounded state and body floor-normal strict46° test: passed.
6. Fresh query valid, positive hit, nonempty/unsaturated contact count: passed.
7. Intended support RID/shape and local shape0: passed.
8. **Normal-or-velocity disjunction: failed on normal**, velocity zero.
9. Contact plane predicate: **not reached**. Measured pointY differs from
   canonical.18 by≈7.153nm, and equals plan landingY. This is offline arithmetic,
   not `GUARD_PLANE_PASS`.
10. Final guard pass/path qualification: not reached. Applied lift1, verified0.

The1µm budget is not this failure's cause; neither epsilon tuning nor internal
floor-angle slack addresses it. The internal46°+.01rad cutoff≈46.573° is a
source fact about classification, not guard authority.47.477° is beyond even
that cutoff;45.65° is a different observation, not a tolerance-adjusted47.477°.

## Pinned source semantics and limits

`engine-references.json` contains SHA-bound excerpts from exact engine revision
`6ce3de25aa58466e14ef354703ba8d9791a417da` (the AM4.5.2 build identity).
CharacterBody source SHA matches the earlier approved reference.

* `character_body_3d.cpp:456–488`: apply_floor_snap uses current transform,
  max(snap,margin), max4, recovery and separation flags; direction classification
  precedes Y-only projection of travel, and small travel may be zeroed. The
  resulting normal need not be recomputed at the final projected body pose.
* `:537–550`: floor classification includes.01rad and selects a floor normal
  based on collision depth. No internal call trace exists in AM.
* `godot_space_3d.cpp:690–709,766–795`: GodotPhysics transforms body AABB to the
  provided hypothetical transform, applies margin, and may recover a temporary
  body transform before casting. This is not a caller-body teleport.
* `:865–902`: finite eight-step cast search chooses safe/unsafe fractions. Changing
  motion length/start can change samples. This is no justification for searching
  until a desired answer appears.
* `:927–976`: if recovery-as-collision reports recovery or safe<1, rest contacts
  are generated by a static solve at **recovered transform + motion×unsafe**,
  with margin. Even safe=unsafe=1 can accompany recovery contacts.
* `:454–510,988–1007`: callback pointB/normal become contact point/normal; returned
  travel equals safe×motion plus recovery displacement. A recovery/rest normal
  is not necessarily a face normal or a contact at the original query pose.

**Conditional arithmetic, not backend observation:** applying that implementation's
travel equation to fresh guard yields a recovery residual
`[.008180424571,+.011355921626,−.008180618286]` and a rest-sample body origin
`[.220312371850,.045730618760,−.220312565565]`. This is not merely the original
pose minus.0201: lateral recovery and upward residual matter. Full4's conditional
rest originY≈.053302821470 is also not its safe finalY≈.054474696517.

Thus a lower, later rest query sampling the rounded edge can plausibly yield a
steeper normal; **the actual backend is unverified**, and numerical agreement
does not uniquely prove its internal contact-generation branch or caches.
AM's `backendImplementationVerified=false`, `parentInternalCallsTraced=false`
qualification remains. Physical-call totals are null.

### Ideal geometry heuristic, not a physics oracle

With capsule lower hemisphere radius≈.42, endpoint distance before tread edge≈.3,
and lower sphere centerY≈endpointY+.42, the ideal edge-to-center radial angle is
`atan2(.3, .0544747+.42−.18)`≈45.5325°. Applying the same heuristic at the
conditional rest-sample position gives≈47.476985°, close to the query normal.
This is consistency evidence, not proof of backend implementation. Margin,
recovery, concave triangles and discretized casting are not an ideal sphere model.
Ideal radius×sin46°≈.302123 is similarly not an admission bound.

The first slice only moves the center from along≈−.4 to−.3; it cannot place the
entire radius.42 footprint on the tread. Rounded-edge support, if provable, must
carry the transition over successive frames. More pre-lift at the same XZ may
still snap back to similar support, with small cast-grid differences; no height
tuning, bisection, hidden horizontal boost or full-tread teleport is warranted.
Whether this guarded first slice is achievable under the current budget remains
unproved. If it cannot be proved, the next step is architecture review, not a
fixture or tolerance change to force a pass.

## Delivery and verification

`analyze.py` reads frozen AM only and writes local derived tables. `test_diagnosis.py`
checks full AM60 hashes, current controlled pins, raw-unit angles, failing/reached
predicates, endpoint/plane arithmetic, support identities, .35 comparisons,
conditional recovery arithmetic and reproducible export. No receipt is rewritten.
`prior-preservation.json` records the existing read-only inventory verifier's
AL33/AK51/etc and15 production dependency checks; `preservation.json` adds AM60.

**8 focused offline tests passed**, with no native execution. Run:
`python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/walker-support-normal-diagnosis -p 'test_*.py'`.
`source-receipt.json` seals derived delivery files and the unchanged local source
references. No test acceptance is represented as a native pass.

AM whole positive FAIL, .42 verified lifts0, .35 individual passes, .42/+45 unrun
remain unchanged. No admission or production promotion; .20 is not a fallback.
All60 map journeys,184 static Vesper failures and production accounting remain open.
