# Vesper stair traversal: native solver reproduction and movement proposal (2026-10-05)

**Research only.** Branch `research/vesper-stair-traversal-20261005` from
`feature/relay-campaign`. No production controller, game source, authority world,
receipt, import, or promotion was changed. The scratch project, script and raw logs
are at `/tmp/opencode/stair-repro/` (outside Git). The actual Vesper apron remains
**nativeChecks: pending**: its `vesper-binding-02` calibration was 5/10.

## 1. Minimal engine reproduction

Run Godot **4.5.2** with `--headless --path /tmp/opencode/stair-repro --script
res://repro.gd -- phase=0.02`; `python3 /tmp/opencode/stair-repro/run_matrix.py`
collects one-variable runs into `matrix.txt` and individual `*.log` files. The
script creates a flat ground, 20 repeated .15 m rises spaced .5 m apart, each
with a walkable triangular apron running `.15/.84 = .17857143` m, and flat
triangular tread sheets. The body is CharacterBody3D with one capsule r=.35,
h=1.8 at offset Y=.9, 46° floor, snap .3, stop-on-slope true, margin .02,
grounded mode, default wall blocking, `step()`-equivalent 6 m/s horizontal
intent / 20 m/s² gravity / `move_and_slide()` at actual 60 Hz. The foot settles
for 20 physics frames; five start offsets sample motion phase. The sheets' face
winding is significant: a first scratch draft with backwards triangles did
**not** instantiate a valid supporting ramp and is not counted as evidence.

**Reproduced the mechanism, not the exact production pass rate.** At phase .02,
the first jam occurs at z=-.38 with a collision against `apron_0_0`, normal
`(0,.765705,-.643192)` (**40.03°**); `is_on_floor=true`, `is_on_wall=true`,
`velocity=(0,0,0)`, and position unchanged, while the apron is a floor-classified
face. This matches the production normal reported in
`VESPER_APRON_NATIVE_FINDING_20261005.md`, though the scratch scene's simpler
surroundings do not reproduce production's 5/10 reach count. Four of the five
scratch phases spend 120 consecutive frames stationary; the fifth makes partial
progress but fails to reach within 150 movement frames. The main scene's 5/10
result and its exact imports remain authoritative.

### Single-variable matrix (all five start phases; reach z≥4.5 in 150 frames)

| change from baseline | reached | interpretation |
|---|---:|---|
| baseline | 0/5 | apron contact is floor **and** wall state |
| `floor_stop_on_slope=false` | 0/5 | stop-on-slope is not the enabling cause |
| `floor_snap_length=0` / `1` | 0/5 / 0/5 | snap cannot supply ascent motion |
| floating `motion_mode` | 0/5 | no floor response; does not climb |
| `up_direction=(.01,1,0).normalized()` | 0/5 | sideways tilt does not clear it |
| capsule radius .42 | 0/5 | larger test envelope still jams |
| capsule height 1.4, offset updated to h/2 | 0/5 | lower sphere/radius dominates, not headroom |
| `safe_margin=.001` | **5/5** | recovery/contact phase is margin-sensitive; changing collision margin globally is high risk |
| apron subdivided into 4 individually collidable strips | 0/5 | extra seams do not cure it |
| passed `step` delta 1/120 (physics server still 60 Hz) | 0/5 | not an actual 120-Hz test; shorter motion also fails |
| **`floor_block_on_wall=false`** | **5/5** | smallest isolated flag change that clears this scratch course |

The same flag with **radius .42** also reaches **5/5** sampled phases (separate
`no_wall_block_r042-p*.log`), whereas .42 with default wall blocking reaches
0/5. This strengthens the test-envelope hypothesis without proving Vesper.

Raw observations are in `matrix.txt` and e.g. `baseline-p0.02.log` and
`no_wall_block-p0.02.log`. At phase .02, disabling wall blocking advances to
z=-.283906 on the first apron contact where baseline cancels the move at
z=-.38; it later reaches the fifth-meter marker. Its `velocity` can still be
zeroed transiently by collision response but new horizontal intent is supplied
on the next tick. No result here establishes that disabling this flag clears
the imported Vesper world or the .42 native group.

### What the 4.5 solver actually does

The repo carries a pinned Godot source snapshot at
`tools/godot-multiplayer/new-maps/walker-step-up/references/character_body_3d.cpp`
(provenance/URLs/hashes in `references/index.json`). Its grounded solver
(`_move_and_slide_grounded`, lines 137–390) tests motion and recovery, records
**all** returned collisions, and calls `_set_collision_direction` on their
normals. That classification (lines 528–604) marks a normal within
`floor_max_angle + FLOOR_ANGLE_THRESHOLD` as floor, but can also mark **another
normal** wall in the same movement; floor status does not guarantee ascent. The
first reported apron face at 40.03° is floor; `is_on_wall=true` in the scratch
trace shows another contact/state participates. The logs do not expose every
internal manifold normal or prove precisely which second contact generated wall
state. With `floor_block_on_wall=true` (the CharacterBody3D default), its wall
branch (lines 215–294) cancels forward travel when the body was grounded and
motion opposes a wall, projects horizontal velocity away from that wall and can
zero **all** motion after repeated wall hits. The grounded body can therefore
report a valid floor normal and still fail to climb. Disabling that branch in
the scratch run is a causal intervention; treating the floor-normal test as the
only collision predicate was the earlier analytical error.

Capsule contact is finite-volume: the lower hemisphere can encounter the
approaching ramp/tread seam while the centre and feet are still over lower flat
support. The per-collision normal depends on that rounded surface and seam,
not only on the ramp's geometric face normal; the face hit logged here does not
exclude additional lower-sphere edge/manifold contacts. Godot does not compute
an automatic upward step displacement from a floor-classified contact.
`_snap_on_floor` (lines 493–498) only attempts **downward** motion when previously
on floor and not moving upward. `floor_stop_on_slope` (lines 193–203) addresses
nearly pure downward velocity on a floor; in this experiment horizontal intent
is present. These are source-based statements, not a claim that Godot always
zeroes velocity on any 40° slope.

## 2. Project-aware option survey

| approach | addresses / evidence | contract cost | regression risk and WIP coverage |
|---|---|---|---|
| **Disable `floor_block_on_wall` on Walker** | scratch 5/5 for .35 **and** .42; keeps apron and source support query intact; must validate actual .35 and .42 native walks | one changed `walker.gd` setting, movement-lane advance and new native receipts; `game/*.mjs` unchanged | changes grounded wall behavior globally (sliding into walls, corners, overhangs, diagonals); WIP `sweep_proposal.gd:156` currently assumes only mode/angle/margin/snap, so explicitly review its eligibility/guards |
| Physics-swept pre-move step-up | bounds rise, checks actual shape with `PhysicsServer3D.body_test_motion` for up/forward/down, then applies swept lift | much larger `walker.gd` movement change, movement-lane advance, updated candidate/guard tests and motion ledger | moving platforms, overheads, narrow ledges, body reporting; `e8f0a16b` WIP has three sweeps, static flat patch certificate, .25/.3 strict caps and explicit pre-lift `get_real_velocity` caveat; its current `propose` **rejects floor-classified apron obstruction** (`ordinary_walkable_contact`, lines 200–204), so cannot just promote it for this jam |
| Change snap/stop-on-slope | helps descending/floor adherence or stopping on slopes | Walker movement advance | 0/5 in scratch each; snap is down-only; ineffective ascent cure and affects ledges and jumps |
| Change safe margin | .001 reaches 5/5 scratch | Walker movement advance | global recovery, grounding, wall clearance, penetration and contact stability; do not promote a 19 mm margin reduction from one scratch scene |
| Rounded lips / more apron strips | soften convex edges or reduce face angle | authored world geometry + recipe/hash/art binding, route/support audit, new native imports; no JS byte changes | 45° bevel previously invisible to source `maxSlope=.7`; support-visible 40.03° apron is census-clean yet 5/10 native; four strips 0/5 scratch; no basis for another unproven geometry rebuild |
| Continuous navigation collision ramp, visual steps separate | smooth predictable collision on conventional stairs | geometry/authority/art binding and nav support-height contract; `game/*.mjs` byte lock constrains mover | naive nav490 drops .02727 m; additive apron raises .07364 m; cannot assert nav preservation; existing apron is already a local example and still jams |
| Project velocity along slope / force upward component | could push capsule over face | Walker advance, explicit slope semantics and velocity accounting | may exceed per-frame speed/rise, force through walls, break jump/airborne and source parity; floor projection in Godot exists after a floor collision (source lines 314–330), but wall-block branch can cancel first; not supported by current WIP |

`436e4b43` records integration of the guarded step-up WIP; `e8f0a16b`
introduces its bounded source proposal. `godot/tests/walker_step_up/` and
`tools/godot-multiplayer/new-maps/walker-step-up/README.md` explicitly distinguish
source geometric checks from unproved native solver response. Existing
`godot/tests/walker_parity_admission/*/tests/walker_step_up/response_guard.gd`
checks final support, collision velocity and response; it is not a traversal
gate for a contact classified as floor while a second wall blocks motion.

## 3. Recommended movement-lane experiment and exact proof

First stage a **test-only Walker subclass** with `floor_block_on_wall=false`,
all other settings and aproned accepted/candidate authority unchanged. Run
scratch .35/.42 across phase/lane/approach variants, then the actual native
`controller_journey.gd` with a **fresh** fixture namespace and pinned imported
art, ten walks per group: accepted-civic-r035/r042, candidate-civic-r035/r042,
candidate-roof-r035/r042. Require **10/10 in every group**, actual grounded
landing within original height tolerance, 0 stall/reset/fault and no new
roof-wall/overhead failure. Log all slide collisions and normals, wall/floor
flags, input and resulting velocity, whole-frame displacement, snap and support
identity; compare the old 5/10 accepted-civic-r035 on the same imported apron.
Test flat walls and corners, diagonal wall slide, narrow ledges, descents,
jumps/landings, moving platforms, sprint and unchanged-source maps (at least
Aurora Basin and Cinder Array), plus response guard / Walker parity suites.
Validate .42 **explicitly as test-only envelope**, not a production radius change.

Only if all that passes, review the single-setting production Walker change.
The change still **violates the former plan §1.3 assumption that the controller
profile stays fixed**; explicitly authorize a new movement lane rather than
portraying it as collision-only. Freeze before/after hashes for `walker.gd`,
update the source-lock dependency graph with a **new** movement inventory and
new explicit predecessor→successor supporting-input/history advance in the
dependency verifier (the existing `movement_f61_inventory.json` and its pinned
hash are historical inputs and must not be overwritten), and advance affected production package receipts via
their existing full-predecessor/fingerprint checks, never by reusing archived
accepted receipts. Re-run `movement_dependencies.test.mjs`, source-lock and
production package-verifier tests, and the native test/receipt chain; keep
`game/*.mjs` byte-identical and verify that with SHA-256/diff. Existing frozen
walker-parity fixtures pin the old Walker SHA; preserve them as baseline,
create a **new** versioned candidate namespace/hash and review the final
response guard rather than silently repinning old evidence. The precise
production receipt dependencies must be read from the then-current graph at
the advance, not guessed from this source-only document.

If the real-world flag experiment fails, proceed to the bounded swept step-up
WIP, extending its trigger to recognize the **floor+wall** apron response with
positive shape-sweep proof; the current `ordinary_walkable_contact` rejection
would otherwise make it inert. This is a substantially larger controller cost
and requires the same movement advance plus headroom, platform, ledge, ceiling,
per-frame motion-accounting and native response-mismatch admission. Raising
`terrain.maxSlope` cannot fix the native floor+wall solver branch, and raising
Godot `floor_max_angle` cannot help a contact already at 40.03° under 46°.

No tooling was added under `tools/`, so no tooling logic tests were added. This
research's executable verification is the scratch Godot matrix above; raw
artifacts are intentionally outside the repository.
