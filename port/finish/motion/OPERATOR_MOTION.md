# Third-person operator motion — source implementation

Date: 2026-10-03. Base: `94d4f5e6`. Branch: `feature/motion-astra-operators`.

**Status: implemented and source-verified; native execution and visual acceptance pending an assigned heavy-work slot.** No engine, Blender, imports, renderer, server, package build, or benchmark was run for this change. No generated GLB or finish asset was edited.

## Root cause, measured anatomy, and ownership

The FPS route uses `world/presentation.gd` → `source_operators/operator_visual.gd`. This is a rigid imported-pivot rig, not an AnimationTree or the fighting rig. The source GLBs contain no baked animation clips blocking a procedural fix. A Blender recipe/rebake is unnecessary.

The previous operator path:

* Solved/applied a pose in `rig.update`, then solved/applied another in locomotion.
* Advanced phase from snapshot velocity with a fixed 1.05 m cycle (0.70 m crouched), irrespective of rendered/interpolated travel.
* Multiplied the **entire** contact path by `speedNorm`. Although the contact equation's stance velocity was correct, that extra horizontal scale made the foot move too slowly relative to the world at ordinary walking speeds.
* Zeroed the hips in the contact pose, removed breathing from root height, and used partially weighted leg yaw to approximate strafing. This removed coordinated weight transfer and caused sideways scuffing.
* Sampled floor beneath fixed hip-width positions, not beneath the actual step; missing support and a zero-height real floor were indistinguishable.

The source-only gate parses all nine actual GLBs. Both legs in every operator have a **0.34 m thigh**, **0.35 m shin**, and **0.0935 m ankle-to-sole offset**. The translated `rigPivot6/7` sits between upper and lower joints: reading only `legLower.position` would incorrectly measure a zero-length thigh. The lowest foot accessor bounds meet the authored zero-height sole plane within 1e-7 m. Runtime configuration measures these vectors/anchors from the imported hierarchy rather than hard-coding the lengths.

## Chosen practices and implementation

Research reviewed:

* [Daniel Holden, Inverse Kinematics and Foot Locking (2026)](https://theorangeduck.com/page/inverse-kinematics-foot-locking): velocity preservation, actual contact support, bounded extension, stable knee planes, and smooth release. In particular, avoid lowering the hips excessively merely to satisfy a foot pin.
* [Spring-It-On / Spring Roll Call](https://theorangeduck.com/page/spring-roll-call): exact exponential damping and analytic critically damped springs; no frame-scaled Euler lerp.
* Parent research also identifies [Valve's The Right Foot in the Wrong Place](https://valvearchive.com/Presentations/SIGGRAPH%202021/2021-Talks-Heuvel_The-Right-Foot-in-the-Wrong-Place.pdf) and [Godot animation blending documentation](https://docs.godotengine.org/en/4.5/tutorials/animation/animation_tree.html). This rig is kept in its existing rigid-pivot representation.

### Single gait owner and travel consistency

`rig.update(state, false)` advances channels without applying a pose. Locomotion performs the single solve/application. Standalone callers of `rig.update(state)` retain the original default API and source pose solver.

Live actors with `x/z` animate from the **actual visual wrapper's planar displacement**, including remote interpolation. Distance advances phase; a 12/s exponential filter on measured velocity stabilizes stride parameters and acceleration response under snapshot stepping. It never advances world movement. Coordinate-free gallery callers retain the existing velocity-driven treadmill API.

`Motion.gait` varies cycle length, support fraction and clearance with speed. Running has shorter support and higher clearance; stance reach is capped at half the measured leg length to avoid deep squat compensation. The horizontal path is full length above 0.45 m/s, with a small rest blend below that speed. `stride_contact` matches stance velocity at both swing boundaries using localized endpoint tangents. The legacy three-argument `Motion.contact` remains behaviorally unchanged for robots and the puppy.

### Coordinated body and transitions

* Support-side pelvis translation and roll, pelvis/chest counter-yaw, and subtle head stabilization share the same phase. Negative X is the left supporting side at quarter-cycle.
* Velocity-change impulses produce bounded lateral/forward lean; exact critical springs provide acceleration and braking recovery.
* Turn-in-place uses actual body yaw change, rotational lag and alternating foot lift. Planted foot orientation remains world-fixed until its release.
* Stops finish with alternating 0.22 s recovery steps instead of retaining an indefinite split stance.
* Crouch lowers the visible body while ankle IK compensates. Slide blends back to the source sliding leg pose rather than overriding it with walking IK.
* Air freezes the gait clock and blends into the source tucked-leg pose. Descending legs extend in anticipation only if a real static-surface ray finds nearby ground. Landing injects a bounded spring impulse from downward speed, with chest/head recovery; no new authoritative jump timing is invented.
* Idle chest breathing has deterministic, subtle identity-dependent phase/frequency. It uses no random noise. Reduced motion keeps essential gait and foot contact while suppressing body sway/breathing.

### Feet and weapon constraints

The new `Ground.sample` distinguishes missing support from real support, returns position/normal/collider identity, rejects non-static support, steep normals and offsets beyond 0.12 m. Existing `Ground.offset` retains its legacy clamped-height behavior for robot callers.

Targets are sampled under each actual ankle step. IK solves authored thigh/shin vectors with knees facing anatomical forward (-Z), including lateral abduction and backwards movement. It compensates the whole moving pelvis hierarchy rather than twisting the complete knee chain by a partially weighted travel yaw. World pins require a confirmed support query and stance phase, retain sole orientation, release on missing support/air/slide/over-extension, and inertialize release correction. Unlock corrections are not applied to planted world pins. The sole aligns to supported ground normals. The rigid foot has no separate toe joint; this preserves its existing anatomy instead of adding an incompatible toe chain.

`locomotion.contacts.L/R` exposes support/stance/plant state, target, actual ankle/knee/hip positions, target error and reach-clamp residual for quantitative review. No contact keys or imported skeleton joints are removed or compressed.

Weapon mount aim/recoil/handling still runs after the pose. `HandGrips.align` remains the final arm/hand placement pass. Its code and grip marker contracts are unchanged. Gameplay collision, root-world position, eye position, operator statistics, body geometry, material slots, colors, nine operator identities and the 63-finish asset set are not edited.

### Discontinuities and replay

Reset clears stride phase, spring velocities, landing history, pins, unlock offsets, turn history, stop recovery, filtered travel, breathing clock and handling/recoil. Resets occur on actor identity/vehicle lifecycle change, live-after-dead, optional spawn/respawn/replay epoch changes, snapshot teleports over 3 m, rendered-root corrections over a speed-aware bound, or live-frame gaps over 0.25 s. Ordinary 0.1–0.25 s frames use the analytic damping path. Dead/collapsing actors are not resurrected by the long-frame reset.

Current `replay/stage.gd` already calls `presentation.clear_round()` on clear/generation changes, freeing actor visuals and their accumulated state. A retained-visual replay adapter can use `seek_pose(actor, presentation_time)` or forward `replayEpoch`. `seek_pose` canonicalizes from the requested sample with a fixed 24-step warm start, neutral history, and a sample clock; it does not invent the missing historical root path. Its repeated-seek determinism is in the prepared native gate, not yet an observed engine result. No new signal subscription is installed.

## Verification actually completed

`python3 godot/tests/operator_motion/source_math.py` — **5 tests passed**:

1. Actual production scalar spring equations: partition/semigroup invariance at 30/60/144 Hz and a hitch partition, rates 9/12/22/24/28.
2. Actual production stride equations: stance world-velocity cancellation at 1/2/4/8/11 m/s, three crouch weights, forward/reverse/lateral/diagonal directions and 30/60/144 Hz intervals.
3. Bounded stance reach, swing clearance and phase wrapping.
4. Velocity continuity at lift-off/touchdown.
5. All nine actual GLB hierarchies, soles and SHA-256 identity against the existing catalog, including absence of baked animations.

This is a deliberately limited scalar GDScript-to-Python execution harness. It executes the production math bodies and independent invariants; it is **not** evidence that Godot parsed the types, solved the imported runtime hierarchy, maintained native foot locks or rendered correctly.

`/tmp/opencode/world-pass-two-parser/bin/gdparse` — **passed** for the five changed production scripts plus the two new native fixture scripts. Grammar parsing is not native type checking.

`git diff --check` — **passed**. Generated catalogs, finish resources, materials, GLBs, first-person/fighting/vehicle/input code and authoritative simulation are outside the diff.

## Native acceptance prepared, not yet run

Only run the following after the parent grants an engine/import/render slot:

```sh
godot --headless --path godot --script res://tests/operator_motion/contracts.gd
godot --path godot --resolution 960x640 --script res://tests/operator_motion/gallery.gd -- --motion-capture=/tmp/opencode/operator-motion-native
```

The native contract matrix covers all nine operators at 1/2/4/8/11 m/s, forward/reverse/lateral/diagonal movement, and 30/60/144 Hz. It measures planted ankle drift, IK residuals, actual hand-grip residuals after reach clamp, and source snapshot/root immutability. It also exercises turn, air/landing, crouch, teleport reset, mounted movement, missing ground and repeated seek.

Proposed native gates (acceptance targets, **not measured results**):

* Stable planted intervals: <= 1 cm adjacent-frame world ankle drift and <= 1.5 cm target residual after warm-up; report actual sample counts rather than pass vacuously with no contacts.
* Grip error beyond the reported source reach clamp: <= 3 mm.
* Airborne phase does not walk; no unsupported pin; landing settles below 1 mm.
* Crouch visibly lowers head > 0.2 m without losing planted contact.
* Teleport/mount resets do not advance stride; identical seek inputs recover identical imported joint transforms.
* Actual root transform and authoritative input dictionary remain unchanged.

The rendered gallery presents idle, walk, run, sprint, strafe, reverse, crouch, stop, turn, jump, land and reduced-motion movement for every operator, using real static floor collision and actual wrapper translation. Optional output is **216 native PNGs**, two per case, plus contact/grip JSON. Review full motion as well as stills: shoulder/hip opposition, knee direction, sprint cadence, recovery continuity, foot penetration, hand placement and identity finishes. Also manually review ADS/reload and real uneven-map terrain at native runtime; package performance is unmeasured.

Existing gates to revisit during native integration: `tests/animation_pass/actors.gd` and `tests/biomes/contracts.gd`. In particular, the old biome assertion that strafing requires > 0.4 radians of **hip yaw** encodes the discarded whole-leg-twist implementation. A valid new strafe uses anatomical abduction and should be judged by measured lateral ankle trajectory/ground contact. The legacy 3.8 m/s maximum adjacent-foot travel criterion may also be incompatible with the newly full-length swing; assess measured continuity and contact behavior before changing its expectation. These shared tests were not edited by this lane.

## Package and integration hooks

Five existing runtime files change: `character_rig.gd`, `locomotion.gd`, `motion_math.gd`, `ground_contact.gd`, `operator_visual.gd`. Existing preloads include the entire runtime change; no new gameplay asset registration or export/import recipe is needed. Tests/gallery are isolated under `godot/tests/operator_motion/`.

**Receipt impact:** `tools/godot-package/production_receipts/robots.json` records SHA-256 values for both shared `motion_math.gd` and `ground_contact.gd`. Their file digests change even though legacy robot helper behavior is preserved. Parent packaging must use its normal reviewed receipt reconciliation/verification flow for these source dependencies. This lane does not rewrite an existing receipt to claim new native evidence or touch the nine GLB hashes. Final build/restart/package validation remains pending.

**Third-person melee hook gap:** `world/melee_feedback.gd:consume` sees validated authoritative `type: melee` event IDs/times/actor IDs and deduplicates them. `world/presentation.gd` currently supplies operator visuals with snapshots and shot-count recoil only. There is no accepted-melee event dispatch into `operator_visual.gd`; `actor.melee` is a cooldown, not an acceptance event. A later parent-owned bridge must dispatch validated events by actor ID with its lifecycle/dedup epoch before adding a world-safe kick overlay after locomotion and before hand grips. The new first-person chain's camera-space offsets must not be copied to this world rig. No speculative extra attack is inferred here.
