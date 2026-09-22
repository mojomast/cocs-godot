# Native Puma presentation — lead integration handoff

Base: 079c4b9043450cb67add939904b6c93e46621e1a.
Branch: subagent/native-puma-presentation.
Worktree: /home/mojo/.hermes-instances/fresh/workspace/cocs-native-puma-presentation.

Standalone component implemented; not connected to the shared session. No game/server/runtime integration files changed. The primary checkout's ongoing audio, launcher and handoff edits were left alone.

## Discovery and deliberate simplifications

Read port/README.md, contracts/CONTRACT.md, map-selection.json, vehicles.mjs, race.mjs, soccer.mjs, destination-sports.test.mjs, client.gd and relevant view.mjs code. Match.snapshot in game/core.mjs:1313 is the authoritative wire mapping.

Puma dimensions in vehicles.mjs are length 3.6, width 2.1, height 1.7 metres. The source vehicleModel in view.mjs:887 onward has an olive stepped hood, open rear bed, cage, four .42-radius wheels and a turret. This component uses inexpensive native boxes/cylinders with a simplified cage, paired barrels, headlights, red rear lights and team-colored bed panels. No imported texture, GLB, shader or generated asset dependencies.

Coordinates are unmirrored x/y/z, +Y up, 1 unit = 1 metre. IMPORTANT: vehicle heading zero faces +Z, unlike actor camera -Z; positive PI/2 faces +X. This follows stepRace/stepSoccer and source vehicleModel nose at positive Z. Snapshot y is ground/vehicle anchor, not body centre. Tires sit at y=.42 with radius .42. Godot Euler order explicitly XYZ matches the source Three.js rotation order; pitchBody/yaw/roll map to x/y/z. No PI offset is applied.

Snapshot fields consumed: vehicles[].id, kind, x/y/z, yaw, roll, pitchBody, turretYaw, health, respawnTimer, vx/vz, driver; actors[].id/team; state.time. Team comes from the driver actor, not an invented vehicle.team field. IDs including numeric zero remain valid. Snapshot driver null means unoccupied. Unsupported chassis are skipped, never portrayed as a Puma. No authoritative steer angle or wheel phase exists; wheels do not steer. Cosmetic roll integrates signed forward velocity only when snapshots arrive, with 100ms cap; no prediction, physics, autonomous process loop or smoothing. Position is applied immediately.

## Component API

Preload res://vehicles/renderer.gd, instantiate and add to an identity-transform world parent.

apply_state(state: Dictionary, local_actor_id: int = -1) -> bool
Consumes a COMPLETE decoded snapshot state (frame.state), not a protocol envelope or delta. Rejects malformed/duplicate Puma rosters atomically. Caller must supply ordered accepted snapshots and handle round/connection boundaries. Missing vehicles array rejects; an empty array removes the fleet. Models are stable keyed nodes until disappearance/reset. Invisible while health <= 0 or respawnTimer > 0. Actor/driver metadata is presentation only and does not decide control authority.

vehicle_node(id: Variant) -> Node3D
Returns existing node or null. Public node metadata: driver (absent when null), local_driver. Do not mutate it as game authority.

clear_round() -> void
Immediately detaches fleet, queues deletion and clears cosmetic clocks. Call on start/new round, disconnect/error, map replacement and teardown. Results may retain final frozen state until reset; that policy is lead-owned.

Lead integration: add one renderer to the world, call apply_state with each accepted full state, clear it on boundaries. Hide/adjust seated actor presentation and set an appropriate sports chase camera separately; this task does not change actors, first-person camera, controls, race HUD, ball, rules, world environment or session scripts. Puma is rendered even when locally driven. Authoritative vehicle authority stays with Node.

## Executed checks

python3 -B port/tools/native_vehicle_demo/run.py --capture port/native-vehicle-presentation/puma-synthetic.png

Pinned Godot 4.5.2.stable.official.6ce3de25a verified. Runner copied ONLY this component/demo/tests into a private disposable Godot project, imported it, executed tests and rendered under private xvfb-run -a. Result: 19 checks, 0 failures; PNG save OK; exit 0. Compatibility Mesa llvmpipe. VSync unsupported warning remains; no script or engine ERROR in final run. Private project removed and bounded owned commands returned.

Tests cover actual unmirrored position, +Z/+X orientation, unit scale, tire ground anchor, actor zero/team/turret state, node reuse, signed forward rolling, destroyed/respawn visibility, XYZ body tilt, malformed/duplicate rejection, disappearance, reset and unsupported chassis. All are explicitly synthetic. Initial test failed exact .42 float comparison; fixed test to use approximate float comparison. Initial direct rendering before isolated import produced shader-cache errors; final isolated import/render resolved those. These earlier attempts are not accepted evidence.

Screenshot: puma-synthetic.png. Synthetic two-vehicle scene, not live driving. Rendering succeeded, but browser visual inspection failed at browser service initialization (HTTP 400 /tabs). No direct pixel inspection or visual acceptance is claimed. Orchestrator/owner must inspect the PNG before visual sign-off.

No live server demo was executed. Normal-rate source snapshot integration and race/soccer driving acceptance remain pending. The full verifier was deliberately not run and no shared service was started/restarted. No packages installed, no push or primary merge.

## Review and manual test

Run the isolated command above. Inspect the image for olive buggy silhouette, tire contact, readable red/blue accents, headlights on front and red lamps on rear; front is +Z. For interactive inspection run the demo scene with pinned Godot on a private display, not the owner's desktop. To integrate, review/cherry-pick this branch and exercise actual Ion Speedway race and Aurora Stadium soccer snapshots, driver/team changes, vehicle disappearance and round reset. Check mounted camera/actor occlusion independently. Treat current image/tests as synthetic presentation evidence only.

Known limits: no interpolation, suspension simulation, authoritative steering animation, damage FX, mounted gun events, driver character, health bar, sports UI, live snapshot acceptance or graphical visual sign-off. No arbitrary non-Puma vehicle support. Malformed actor entries are ignored for coloring; full protocol validation remains the caller's responsibility. Numeric IDs are assumed protocol-safe. Snapshot ordering is caller-owned. Visual rolling is cosmetic and deliberately not a claim of physical wheel parity.
