# Snap-query parity — bounded source diagnosis and experimental proposal

New branch `astra/walker-snap-parity` from parent `f86f5a7f`. **Source only: no
engine, parsing, import, rendering, server, staging, subagent or queued job.**
AE is read only at `/home/mojo/.tmp-on-disk/cocs-walker-admission-ae`.

## Finding and preferred next experiment

The short planner query is not the parent snap query. Match the parent request
and post-processing in a new test-only planner, keeping the **original endpoint
tolerance and response guard unchanged**. First obtain paired read-only query
results at the same predicted pose/body/frame while the original candidate
still runs. Parent review of that evidence precedes testing the parity planner.
No unique backend cause, engine defect or successful correction is established.

AE's first positive case (.35, −45°) physically applied one UP move, then failed
at candidate input8 / physics frame176. Original baseline:127 responses/120
stalls. Combined positive attempt:135 input +40 settling responses. The
21.845102µm Y difference exceeds the unchanged1µm budget; it remains a failure.

`AE-witness.json` preserves a verbatim excerpt with original full-result SHA256:

| Quantity | AE value |
|---|---:|
| Raised body Y | .172130957245827 |
| Short DOWN length / contact capacity | .175564289093018 /32 |
| Short DOWN safe fraction | .48046875 |
| Short DOWN travelY | −.0843531563878059 |
| Predicted finalY | .0877778008580208 |
| Actual finalY | .0877559557557106 |
| Parent displacement from raisedY | −.0843750014901164 |
| Parent floor snap length / contact capacity | .300000011920929 /4 |

Float32 addition of the recorded short-query origin and travel reproduces the
recorded expected endpoint. Float32 addition of raised origin and parent
position-delta reproduces the actual endpoint. This is not a JSON-decimal
rounding discrepancy, and replacing double arithmetic in a source analyzer
does not erase the failure. The full-length/full-capacity query result was **not
recorded in AE** and cannot be recovered by multiplying a guessed safe fraction.

## Exact pinned call path

References are the existing hash-pinned official `4.5.2-stable` files under
`../walker-step-up/references/`; new tests verify their index hashes.

1. `godot/exploration/walker.gd:87–100`: real grounded state selects vertical
   velocity0 when jump=false; horizontal velocity comes from local basis ×
   bounded axes × speed. It calls `move_and_slide()` once. No gravity impulse
   occurs in this grounded response.
2. `character_body_3d.cpp:55–119`: platform velocity can add an earlier move.
   The experiment admits only static/no-platform state. `was_on_floor` is
   retained, collision state reset and motion-results cleared before grounded
   movement. The separate prior UP move does not create synthetic floor flags.
3. `:137–170`: motion=`velocity * actual physics delta`, from current global
   transform, existing margin, max_collisions6, recovery_as_collision=true,
   separation ray defaultfalse. With floor_stop_on_slope=true, the first move
   enables `p_cancel_sliding`. The old raised-forward query instead used
   capacity32 and recovery_as_collision=false.
4. `physics_body_3d.cpp:108–159`: the body RID is passed to PhysicsServer's
   `body_test_motion`. Cancellation may remove perpendicular recovery; locked
   axes zero travel components. Original planner already rejects axis locks.
   `p_test_only=false` applies `from.origin + result.travel` for forward movement.
5. `character_body_3d.cpp:382–397`: the clear/no-collision branch exits the
   movement loop, then `_snap_on_floor(was_on_floor,velocity_facing_up)` runs.
   It returns if already classified as floor, previously airborne, or rising.
   Existing candidate/guard restrictions exclude slide/platform/constant-speed
   alternatives; a general internal path reconstruction is not claimed.
6. `:456–498`: `apply_floor_snap` returns if already on floor. Otherwise:

| Field | Parent snap | Old planner down | New proposal |
|---|---|---|---|
| Body | live RID | same live RID | same live RID |
| From | actual global transform after forward | predicted raised + tested forward travel | same predicted pose, explicitly labelled unobserved |
| Motion | `-up * max(floor_snap_length,margin)` | `-UP * (upTravelY+margin+.0001)` | parent expression |
| Margin | existing body margin | existing body margin | unchanged |
| Max collisions |4 |32 |4 |
| Recovery as collision |true |true |true |
| Collide separation ray |true |true |true |
| Explicit excludes |none |none |none |
| Masks, exceptions, shape offset | live body/shape | live body/shape | unchanged and recorded |
| Move wrapper | test_only=true, cancel_sliding=false | raw PhysicsServer query | raw PhysicsServer query + explicit snap processing |
| Travel application | project on UP if raw length>margin, else zero | add raw travel | parent projection/zero rule |

`apply_floor_snap` calls `_set_collision_direction` for floor classification.
At `:537–550` Godot admits floor angles≤floor_max_angle+.01 radians and selects
the deepest qualifying floor contact. This prototype deliberately preserves
its **stricter ≤46°** checks for every reported contact, all matching the same
certified static target. It does not inherit the engine's additional angle
allowance. Saturated4-contact results reject conservatively.

The parent first calls PhysicsServer with the full query, then projects travel
onto UP only when `result.travel.length()>margin`; smaller travel becomes zero.
The new planner reproduces this rule. It rejects significant lateral recovery
rather than treating projection as proof that an arbitrary sideways path was
safe. It requires positive bounded net rise and the same original surface-rise
cap, geometry certificate and strict endpoint/floor-support guard.

### Origin and arithmetic caveat

AE records before, raised proof, last horizontal motion, parent delta and final
pose. It does not expose the internal pre-snap transform. Given zero parent
slides, static state and horizontal velocity, the pinned clear branch implies
raised position plus one forward move, followed by a vertical snap. AE's X/Z
endpoints agree; its parent last-motion differs from the planner vector by about
7.45nm per horizontal axis because multiplication/addition order can differ.
The new comparator labels its origin **predicted**, not directly sampled from
the internal solver. A native parity test must still pass the unchanged actual
UP endpoint check and final guard. Matching request parameters is a necessary
experiment, not proof of identical internal state or backend behavior.

AE's backend implementation was not independently identified. An earlier
`DEFAULT` setting is not a licence to relabel it GodotPhysics or Jolt. Future
receipts record the configured setting, engine version and
`backendImplementationVerified:false`. No backend-specific search algorithm is
asserted here.

## Rounded-edge support interpretation

Predicted footY.0877778 is below treadY.15, consistent with finite rounded-cap
edge contact. The planned down normal is about34.863° from up, within46°.
The continuous support strip certifies terrain ahead of the contact; it does
**not** require the body centre/full footprint already to be on the tread.
At .1m per tick the centre remains before the edge. This is an intermediate
edge-supported pose, not completed tread landing and not independently a new
geometry-policy defect.

Actual support remains **unqualified in AE** because the endpoint guard returned
before its final live capsule query. `is_on_floor` and the centre ray hitting
`AdmissionBaseFloor` cannot replace that missing identity check. The new planner
also cannot turn its predicted support into evidence of actual final support.
Whole-frame minus parent displacement reproduces the applied pre-lift; no pose
correction or parent velocity overwrite is proposed.

## New source files and conservative contract

- `godot/tests/walker_snap_parity/query_pair.gd`: read-only short32/full4 requests
  at identical from/body/frame, plus a parent-policy forward6 request. Records
  raw travel, fractions, contact normals/points/RIDs/shape indices, actual shape
  data/RID/transform, mask, exclusions, margin and flags. Checks body transform
  and velocity remain unchanged. Read-only calls do not spend motion budget.
- `planner.gd`: starts with the **complete original accepted proof**. Original
  rejection never becomes acceptance through a fallback. It adds clear-forward
  parent-policy equivalence, conservative full-snap contacts and projection.
  Only then selects the parent-policy expected endpoint. Original expected
  endpoint and both raw queries stay in `queryParity` evidence.
- `candidate.gd`: isolated candidate application copy with new planner binding;
  source test confirms every application/decision statement remains the same
  except post-decision numeric slide diagnostics. It preloads the **unchanged
  original response guard**, calls original Walker once, and never assigns pose,
  velocity or ground flags. No production mode flag.
- `diagnostic.gd`: source-only single-case driver, .35/−45° flat fixture from the
  unchanged v4 geometry.20 settles, at most40 input responses; stop on the first
  eligible response. Original-query observation retains any original guard
  failure as failed. Parity success would mean only **one response matched**,
  never completed positive admission or a map walk. Every candidate fault stops.
- `prepare.py`: future write-once source receipt, verifies all46 AE inventory
  files against `c0761dbe` and all15 production pins. Not invoked. No grant or
  launcher is created. An external bounded ownership supervisor still needs
  review/wiring before this experiment is execution-ready.

`experiment-plan.json` has `grant:null`, `autoStart:false`, `queued:false`. Only
`original-query-observation` and `snap-parity-candidate` are valid diagnostic
groups. Unknown/map/reference groups and continuation permissions are denied.
The driver binds a future explicit grant to its source hash and expiry; it does
not authorize itself. Parent review of the read-only comparison precedes any
separate parity-candidate invocation. No new native authorization is requested
implicitly by supplying source.

If matching queries still fail the existing endpoint/support guard, retain that
failure. A revised numerical contract would require separately reviewed bounds
and finite-volume safety evidence; substituting10µm or a fraction of the margin
is not this proposal. Full negative controls, inclined rejection, mirrored and
both-radius positive admission still precede any future map-walk request.

## Source validation

Seven new tests cover exact AE float32 endpoints, unknown full-query outcome,
projection/zero threshold, edge support interpretation, unchanged P1 vector and
support-identity counterexamples, pinned source parameters, and statement-level
candidate application equivalence. Existing39 source tests remain applicable.
New GDScript remains **unparsed/unrun**, and positive admission remains unproved.
All historical manifests/receipts are preserved; production accounting and
promotion remain blocked, and all60 candidate map walks remain unrun.
