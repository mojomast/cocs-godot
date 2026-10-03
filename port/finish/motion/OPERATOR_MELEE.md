# Accepted third-person kick chains

2026-10-03 follow-up to `2258c048` / canonical `a5c26f25`. The canonical parent was merged into the operator worktree before this follow-up. The original locomotion commit is not amended.

**Status: source implementation complete; four scalar source tests and eight GDScript grammar checks passed. Native event routing, transforms, foot contact, audio counts and rendered appearance are pending the assigned engine slot.** No engine/import/Blender/render/server/benchmark command was executed.

## Event ownership and routing

`source_operators/melee_events.gd` is a pose-only recipient. `world/presentation.gd` binds one named handler to its host's existing `client.events` signal. This common `_ready` binding also covers standalone ordinary-world scenes which override `world/session.gd::_ready`; the source session explicitly calls the same idempotent binding. Rebinding disconnects the old recipient, round clears do not add subscriptions, and `_exit_tree` disconnects it. The activity predicate is read from the existing combat feedback component without flushing or playing effects.

The live callback still calls `combat.apply_events` and `av_events` exactly as before. The pose recipient does **not** call `combat.apply_events`, `melee_feedback.consume`, any sound player, damage function, input sender or hit generator. Combat feedback's existing central `_fresh_events` filtering and its melee/audio handlers are unchanged. This new recipient has independent defensive deduplication because replay and direct presentation fixtures also call its API.

Only public `type: melee` events with valid integral nonnegative source ID/actor ID, finite nonnegative time and a valid source `pos` are eligible. Validation reuses `world/projectiles.gd`'s existing identity/point guards. The event actor must resolve to a currently living, visible, unmounted remote operator; the locally-owned hidden body is excluded. Spectators (`local_id == -1`) can animate all visible operators.

The recipient:

* Holds a bounded 4096-entry seen-ID queue/window and consumes duplicate, malformed-ID-bearing, absent, hidden, locally-owned and suspended events without queuing an animation.
* Accepts events no more than 0.40 source seconds old or 0.25 source seconds ahead of the latest snapshot; after 0.5 s without a new snapshot it suppresses new kicks.
* Tracks incarnation/eligibility floors across character, deaths/spawn IDs, vehicle, visibility and actor removal/reappearance changes. An event predating a new incarnation is suppressed even if it falls inside the ordinary freshness window. Short-lived tombstones protect reused actor IDs, then expire after the stale-event horizon.
* Resets ID acceptance only at the existing round/replay boundary or a genuine source-clock rewind. Ordinary interruptions preserve consumed IDs. The ordered source transport/round-start barrier remains the owner of round identity; no synthetic round ID is added to the wire.

There is no cooldown-derived attack and no input queue. A malformed optional `hit` is treated as unconfirmed by the unchanged shared chain helper, consistent with the FPS path; it cannot establish a combo continuation.

## Shared accepted-chain rules, world-safe pose

`source_operators/melee_pose.gd` reuses `first_person/kick_motion.gd` for acceptance, deduplication within the actor, source-time chain gaps and the 0.29 s authored load/chamber/snap/contact/recovery phases. It does not copy the FPS camera-space root or weapon offsets.

The same sequence is used: **lead push (left), cross snap (right), heel drive (left)**. A previous confirmed hit permits continuation only across the shared 0.299–0.85 s accepted-event gap. A miss, blocked strike or protected hit breaks subsequent continuation. These decisions affect presentation only; damage and accepted-action timing remain source-owned.

`operator_visual.advance` now orders presentation as:

1. Advance channels and locomotion, with `kickingSide` marking the active leg.
2. Apply the world-safe kick body/leg overlay.
3. Apply the existing weapon handling/aim/recoil mount.
4. Run the existing final hand-grip constraints.

The active leg releases its gait pin and recovery-step ownership for the kick. Imported thigh/shin vectors point DOWN: positive Godot hip-X raises the thigh toward -Z, and negative knee-X folds the shin. The authored rotations are used directly rather than passing through the source rig's pitch-negating convenience method. A smooth entry/recovery envelope blends back to the current gait, so moving and airborne baselines remain available.

A small model-root lateral weight shift (2.5 cm, reduced while airborne), 1.8 cm compression and opposing torso/hip yaw brace the strike. These are **cosmetic imported model joints**, not the authoritative visual wrapper/root-world, collision body or camera. The already-confirmed planted support leg is re-solved after that body shift to the same real world target and sole orientation. Running flight/air does not acquire invented support. The rig's rigid foot anatomy and all grip/contact keys are retained.

Death, mounting, hidden presentation, long-frame reset, identity/respawn reset and seek interrupt the overlay. Discarded source IDs cannot animate again on reveal. No generated geometry, material, identity color, armor/finish resource or body statistic is edited.

## Replay

`replay/stage.gd` routes its already-admitted `eventsBetween` selection to `presentation.apply_events`. Clear/paused samples consume without animating. Existing `clear_cues()` now interrupts the world pose recipient too; generation/seek clears already destroy/recreate actor visuals.

Replay explicitly supplies the interpolated **source state time** via `set_melee_clock`. Kick age is then `sample_clock - accepted_event.time`, not elapsed render time. Holding a sample or changing rendering framerate cannot continue a replay kick. An interrupted clocked sequence has a separate inactive flag, so reevaluating that same clock cannot revive it. No replay file, source simulation, transport schema or playback controller is rewritten.

The bridge is attached to ordinary `PortPresentation` hosts with `client.events` and to the explicit read-only replay stage. Separate renderer/network owners that do not use this presentation host (for example a composition built around `net` rather than `client`) must explicitly call the recipient API if they want this overlay; no vehicle/combined-arms branch was modified in this scoped follow-up.

## Verification actually passed

```sh
python3 godot/tests/operator_motion/melee_source.py
```

**Four tests pass**, executing the actual shared `kick_motion.gd` scalar source through a limited syntax adapter:

* Accepted 1/2/3/1 sequence and repeated-ID rejection.
* Miss/block/protection continuation rules and interruption retaining consumed IDs.
* Invalid IDs/times and exact completion under 30/60/144 Hz advancement.
* Independent world-axis forward kinematics of the authored contact poses using measured 0.34/0.35 m links, without FPS root translation: forward reach, bounded lateral reach, lifted ankle and invariant link lengths.

This validates shared scalar acceptance/pose math, **not** the Godot dispatcher, imported transforms or native audio playback.

Grammar parsing passed for `melee_events.gd`, `melee_pose.gd`, `operator_visual.gd`, `locomotion.gd`, `world/presentation.gd`, `world/session.gd`, `replay/stage.gd`, and `tests/operator_motion/melee_contracts.gd`. Native type checking is still pending.

The existing five `source_math.py` tests were rerun and passed, including all nine catalog GLB hashes/anatomy checks. `git diff --check` also passed.

## Authored native regression, pending execution

After an engine/import slot is granted:

```sh
godot --headless --path godot --script res://tests/operator_motion/melee_contracts.gd
```

The fixture uses a real static floor and all nine actual operators. It dispatches through a real signal into the presentation recipient, records actual ankle extension/support error for each of three accepted strikes, and checks:

* One subscription after repeated binding and round reset; zero retained subscriptions after freeing the recipient.
* One pose acceptance per event despite repeated transport delivery; foreign/local/invalid/stale/hidden/suspended events cannot animate later.
* Actual kicking ankle extension > 0.25 m and released kicking-foot pin.
* Planted support residual < 1.5 cm after the body overlay; existing grip residual beyond measured source reach clamp < 3 mm.
* Actor-world transform, authoritative actor dictionary and event dictionary remain unchanged.
* Confirmed chain order, miss/block/protection behavior, death/mount interruption, respawn/actor-reuse floors and repeated seek-ID suppression.
* Sprint and airborne kick coexistence without root changes or fabricated air support.
* Fixed replay sample age across render steps and no revival after replay interruption.
* Round reset admits fresh reused event IDs; the existing real melee feedback component still reports exactly three whooshes and three impacts for three confirmed strikes with duplicate deliveries.

All thresholds and audio/event counts above are **acceptance criteria, not observed native results**. Render all three strikes from side/front/three-quarter views, then inspect sprint, air, crouch, ADS and reload overlap before claiming visual acceptance. No new capture or packaged evidence exists for this follow-up yet.

## Package implications

Two new runtime scripts are reachable by existing operator/presentation preloads. The shared FPS `kick_motion.gd` already exists in canonical `a5c26f25`; it is referenced without edits. No asset bake/import recipe or authoritative protocol hook is added. Packaging should include the source dependency closure and perform native script/type checks during its granted rebuild. This follow-up does not change the shared `motion_math.gd` / `ground_contact.gd` hashes again, so it does not add to the earlier robot-helper receipt reconciliation.
