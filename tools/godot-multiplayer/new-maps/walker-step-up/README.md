# Exploration step-up feasibility — SOURCE ONLY, experimental v1

**Preferred route: a physics-swept step-up experiment for the exploration
controller. No production promotion.** New isolated branch
`astra/walker-step-up-source` from parent `d8822447`. No engines, imports,
renders, servers, subagents, queued work or heavy grant were used. Neither new
GDScript file has been engine-parsed. The original Walker and all movement
globals, JS authority, Fighting and network code remain unchanged.

## Decision and evidence

Z's native `accepted-civic-r035` group retained five downhill passes and five
uphill stalls, all on the first .15m civic tread. The capsule stopped at
`[lane,12.0166673660278,24.7000026702881]`, against the edge at Y12.15/Z25.
Its 51.15–51.31° contact normals exceed the original 46° floor setting. Z remains
a **failed** archive, not an acceptance waiver. Candidate civic/roof and .42
native movement were not run. All **253 Z, 600 X and 264 U files** were verified
unchanged by the explicit-root [preservation audit](preservation.json).

The JS strict <.25m snap / <.3m admission rules are useful comparison limits,
**not permission to query a centre height and teleport the native body**. The
proposal uses the live native body RID, its whole capsule and its actual shape
offset for every volume sweep. There is no authority `floorAt` lookup in the
candidate and no position/transform assignment.

An important feasibility constraint: at walk6 and 60Hz, one tick permits only
.1m forward motion. At Z's stall, that ends near Z24.8, still before the tread's
Z25 boundary. Requiring the body centre to be over the new tread would deadlock
the proposal; extending the horizontal move to reach Z25 would violate the
frame budget. Instead, require an actual downward **capsule** hit with a valid
floor normal, plus a continuous, sufficiently wide/deep supporting tread face
ahead of that contact. The centre is never advanced beyond its ordinary budget.

### Prototype files

- [`sweep_proposal.gd`](../../../../godot/tests/walker_step_up/sweep_proposal.gd):
  read-only intent/support checks and upward → forward → downward native volume
  sweep proposal. Returns evidence or a rejection reason; changes no node.
- [`candidate_walker.gd`](../../../../godot/tests/walker_step_up/candidate_walker.gd):
  **test-only subclass of the unchanged Walker**. After a complete accepted
  proposal, applies only the proved upward sweep using `move_and_collide`, then
  calls `super.step` exactly once with the original input/delta/sprint/jump.
  Parent `move_and_slide` owns forward motion, sliding and velocity, and its
  existing floor snap owns downward placement and ground state. Any disagreement
  sets `candidate_fault`; the future driver must immediately fail and archive it.

No production preload references these files. There is no global mode flag.
They are an explicit, conservative native experiment—not a replacement mover
or a claim of native-solver equivalence from Python tests.

## Proposed v1 contract

1. **Grounded intent only.** Require actual physics context, 60Hz, timeScale1,
   finite values, nonzero input, `is_on_floor`, near-zero vertical velocity,
   no jump request and no platform velocity. A short downward live-body query
   confirms current static capsule support because `is_on_floor` describes the
   previous `move_and_slide`, not an instantaneous floor query. Airborne and
   ascending/descending jump states retain the ordinary controller path.
2. **Exact profile.** One enabled capsule, radius .35 (or explicitly labelled
   .42 test envelope), height1.8, local offset `[0,.9,0]`, unit scale and yaw-only
   body rotation. Read actual PhysicsServer shape data. Keep safe margin.02,
   floor snap.3, floor angle46°, walk6/sprint10, gravity20 and jump6.5 unchanged.
   Reject extra shapes, disabled shapes, axis locks, scaling, transformed parents
   or altered heights. Parent Walker uses local `basis`; rejecting transformed
   parents avoids silently changing that convention.
3. **A real low riser, not just a steep normal.** Test this frame's intended
   horizontal motion. Non-floor blocking contacts must lie above the feet in
   the low band, oppose the input (`cos >= .98`) and identify the same static
   collider shape. Lateral corners/multiple obstacles fail closed. Determine
   the candidate top from its actual collider geometry. A vertical wall with
   a low contact does not become a step merely because its contact normal is
   steep. Saturated 32-contact results fail closed.
4. **Strict rise from physical base support.** A native downward ray identifies
   the current flat static support plane. Compare candidate top minus this
   plane—not top minus margin-raised feet. Require `rise + .0001 < .25` and
   `< .3`. Exactly .25, exactly .3 and greater heights reject. The .1mm guard
   makes the boundary more conservative; it never broadens a step limit.
5. **Continuous landing certificate.** Initial v1 supports a horizontal box top
   or a complete convex planar patch of at most 32 actual collision triangles.
   Use body/shape-owner transforms. Normalize triangle winding, require unique
   directed edges, cancel opposite interior edges, and require the remaining
   edges to cover each convex-hull side exactly once without gaps/overlaps.
   Reject arbitrary mesh patches, concave/holed support, scaled shapes or
   non-flat landings. No vertex welding, epsilon gap closure or area-only proof:
   two overlapping triangles sharing an outside edge can have the same total
   area as a quad while leaving a hole. Roof treads 10/11/13 have 4/5/3 triangles
   after clipping, which is why an initial two-triangle-only certificate was
   insufficient. Source tests explicitly convert those authority vertices to
   standard Godot float32 storage before checking topology; this is not an
   imported/native geometry readback. No geometry bytes were changed.
6. **Reject narrow ledges geometrically.** Four corners must lie inside that
   continuous convex face: full capsule diameter plus two existing margins
   across the input, and a strip of `radius + 2*margin` depth ahead of the
   contact. The strip starts at `margin + .0001`; with radius.35 it is .74m wide
   × .39m deep; with .42 it is .88m × .46m. Both fit the real .5m civic treads
   at the five approved lanes. Narrow shelves and gaps reject. This is a
   conservative support strip, **not a claim that the entire footprint is on
   the new tread**: finite-cap edge support is still required by the down sweep.
7. **Prove all three swept volumes before applying anything.** Requested lift
   is `topY - actualFootY + safe_margin + .0001`. For Z's foot/top this is about
   **.153433m**, not an arbitrary .25m vertical jump. The up sweep proves full
   head clearance; the raised forward sweep proves the entire raised path,
   including an overhang that an up-only test would miss; the down sweep must
   hit the certified static shape with **every reported normal <=46°**, within
   the existing .3m snap range and with positive net rise below the strict cap.
   Missing/different/steep/moving support or lateral recovery rejects the plan.
8. **Account for existing-margin recovery.** At Z's foot Y12.016667, the .02
   margin may generate a small upward recovery even before the up motion. The
   plan uses the returned `get_travel()` to place the next hypothetical query;
   it permits only upward recovery bounded by the unchanged margin. It rejects
   lateral recovery. The applied up call uses the original requested motion,
   **not** returned travel, so recovery is not counted twice. No new exclusion
   masks or colliders are inserted into body sweeps.
9. **One application per tick; original response remains authoritative.** Query
   motion consumes no horizontal displacement, so the parent still owns the
   whole remaining budget. Apply only the accepted up sweep, compare its actual
   end against the proof, then invoke `super.step` once. Never add a second
   forward move, manually set grounded/velocity, iterate lifts in one tick,
   rewind to a stored transform or retry a smaller height until it passes.
   Real response disagreement remains a diagnostic failure, not a rollback
   teleport or a synthetic successful landing.

The surface-relative cap and continuous support certificate prevent repeatedly
using low wall contacts or tiny stacked shelves to gain .25m every frame.
Ordinary valid stairs may naturally contain multiple legitimate low steps;
each later step needs a new physical support plane, top face and swept proof.

## API/source review — exact Godot 4.5.2

Official docs and engine source are stored read-only with URLs and SHA256 in
[`references/index.json`](references/index.json); these are source snapshots,
not an engine install or a runtime result.

- `PhysicsServer3D.body_test_motion(RID, PhysicsTestMotionParameters3D,
  PhysicsTestMotionResult3D)` returns whether the motion collides and does not
  move the node. `from` is the **global body Transform3D**. Live body shape
  transforms, capsule dimensions and offsets remain attached to its RID.
- Parameters explicitly set margin.02 and max_collisions32. Intent/up/forward
  use `recovery_as_collision=false`, `collide_separation_ray=false`; current
  support/down use both **true**, matching the floor-snap convention. This
  profile has no separation-ray shape; extra shape layouts reject.
- `get_travel` includes recovery; fractions alone are not a placement result.
  Results include points, normals, shape indices, collider velocity, safe/unsafe
  fractions and remainder. Validate finite/unit results, and retain the whole
  query chain in the future receipt.
- `PhysicsBody3D.move_and_collide(motion, test_only=false, safe_margin=.001,
  recovery_as_collision=false, max_collisions=1)` requires explicitly passing
  the existing .02 margin. The implementation may cancel perpendicular recovery;
  this proposal already rejects meaningful lateral recovery and verifies the
  committed result against the read-only proof.
- `CollisionObject3D.get_shape_owners()` actually returns **PackedInt32Array**,
  despite its prose saying “Array”; the prototype uses the documented type.
- `CharacterBody3D.move_and_slide` uses actual engine physics delta, remembers
  `was_on_floor`, clears/recomputes collision state, then snaps when previously
  grounded and not rising. `move_and_collide` alone does not replace that floor
  state. Therefore the candidate does not try to manufacture grounded flags or
  rely on `apply_floor_snap()` while `is_on_floor()` is already true.
- Godot's internal floor classification includes `FLOOR_ANGLE_THRESHOLD=.01`
  radians. The proposal deliberately checks down-support normals against the
  raw **46°** setting and does not enlarge that threshold. Z's 51° contact is
  above either threshold.

## What source checks establish—and what remains unproved

**16 source tests pass:** 13 independent geometry/policy cases and 3 API/plan
contract checks. The geometric oracle minimizes finite capsule-segment to
triangle distance along the whole translation; it is not a sampled centre ray
and not a canned “collision=true” mock. It includes capsule radius, height and
margin and covers:

- real Z .35 pose / .15 tread, full up-forward-down geometry;
- a separate analytic .42 starting pose (not falsely labelled native Z data);
- overhead collision during up; a different low overhang hit only along the
  raised forward path; a tall solid wall;
- .25/.3 strict boundaries measured from actual support, not elevated feet;
- unsupported pit, narrow width/depth, overlapping-triangle hole, sub-guard slit,
  internal hole, all **94 actual candidate tread faces × five lanes × two radii
  = 940 support-strip certificates**, stacked tiny
  shelves, >46° support, lateral approach, no input, air/jump/platform states
  and one-attempt-per-frame eligibility.

These tests establish geometric necessity and conservative policy behavior.
They **do not execute GDScript**, model Godot's recovery/manifold algorithm,
prove its collision normals, test parent floor-snap interaction or demonstrate
successful native traversal. The prototype remains **unparsed and unrun**.

```sh
python3 -B -m unittest discover -s tools/godot-multiplayer/new-maps/walker-step-up -p 'test_*.py'
```

`build_plan.py` generates a write-once source specification, not a Godot project
or a launch command. `verify_preservation.py Z_ROOT` requires the pinned Z
inventory and explicit X/U environment roots; it hashes the frozen files without
discovery or fallback. No frozen source receipt is repinned to candidate code.

## Exact future acceptance sequence — no grant or auto-start

[`acceptance-plan.json`](acceptance-plan.json) contains **7 future walk groups /
70 trials**, original endpoints/heights and fixed lanes. Each group is bounded
at180s; experimental groups retain internal170s and 60Hz/timeScale1. Preparation
of a versioned native driver remains subject to source review and explicit
authorization; there is no executable batch launcher in this proposal.

1. Native controlled rejection cases first: prove failed proposals never lift,
   mutate velocity or change ordinary response; test both capsule profiles and
   all geometric counterexamples. Record all actual motion-query inputs/results.
2. `reference-accepted-civic-r035`: original Walker, five up + five down. Keep
   its real failed outcome, compare against Z, and require explicit parent
   authorization to proceed from the known failed reference. **No expected
   failure exclusion turns this into an accepted traversal.**
3. `step-v1-accepted-civic-r035`: experimental subclass, same five up + five
   down. Require **10/10**, grounded landing, no reset/stall, no candidate fault,
   bounded whole-frame displacement and no horizontal budget overspend. Only
   after this profile's baseline civic ascent is demonstrated may the remaining
   groups proceed.
4. Then, individually and stop-on-first-failure:
   `step-v1-accepted-civic-r042`, `step-v1-candidate-civic-r035`,
   `step-v1-candidate-civic-r042`, `step-v1-candidate-roof-r035`,
   `step-v1-candidate-roof-r042` — ten walks each. .42 remains test-only.

Use a fresh `walker_step_up` attempt namespace, never Z's namespace. Bind both
exact accepted `6afe34…` and X `f859d4…` GLBs and corresponding authority/recipe
hashes using the reviewed explicit-art loader, UID-retaining precision/LOD policy
and actual imported readback. Preserve the production Walker hash
`3015de90c925eb86093bb41086fe0725c3f6be9dbb23e3abdfb8b5d43dc440d8`; add separate
candidate/helper hashes, never substitute them into Z's baseline pin.

The future driver must serialize transforms/vectors as numeric arrays and record
whole-frame before/after poses, input, shape RID data, all five potential query
stages (current support, intent, up, forward, down), support face vertices,
collider identity, floor normals, original velocity/real-velocity, reset counts,
accepted-lift count and candidate faults. Checks run on actual physics frames;
no timing warp or source centre-floor substitutions. The old **184 static
contacts remain failed separately**, irrespective of candidate traversal results.

## Production-promotion blockers and exploration impact matrix

The bounded candidate only assists **head-on, flat, continuous static treads**.
Diagonal/corner approaches, moving/rotating platforms, arbitrary mesh landings,
sloping landings, transformed parents and resized capsules fall back to original
movement. Manually animated static bodies with unreported velocity are outside
this static-world experiment; do not claim dynamic-platform correctness.

Before any global Walker change, separately compare both profiles on actual
production consumers `godot/aurora_basin/demo.gd` and
`godot/cinder_array/demo.gd`, including their existing authored route/height
tests. Extend the existing `tests/graphics_batch/walker.gd` controls suite for
flat/diagonal movement, walk/sprint speed, ramps up/down, wall sliding, jump arc,
landing, reset, focus/pointer release and spawn look. Keep all original tests
and hashes; instantiate the candidate in separate fixtures. Walker has **no
crouch implementation**: confirm that input/height behavior stays unchanged,
and reject altered-height capsules rather than introducing crouch behavior.

Two explicit unresolved integration issues block production promotion:

- A pre-lift occurs outside the parent's `move_and_slide` position accounting.
  `get_real_velocity()` / `get_position_delta()` omit that initial lift. The
  candidate records whole-frame delta separately; downstream interpolation,
  camera/animation consumers and reporting semantics need native review. This
  is not silently described as identical motion reporting.
- Read-only `body_test_motion` and the committed `move_and_collide`/parent snap
  can differ through recovery/manifold precision. The candidate halts on proof
  mismatch or invalid landing. Native counterexamples and actual before/after
  stair traces must establish that its conservative checks are usable, not only
  that the guards reject bad cases. Broader diagonal/platform support would be
  a separately reviewed change, not a relaxed check during a failed run.

### Brief alternative comparison

A map-local continuous ramp would require matching visual/collision geometry,
**urban-v4**, new hashes and route/support-height review. A naive civic 12→24
grade changes nav490 support from13.8 to13.772727…m. That is an architectural
change to solve a failure already demonstrated in the accepted exploration
controller. Prefer the bounded swept-controller experiment first; no ramp
geometry is proposed or generated here.
