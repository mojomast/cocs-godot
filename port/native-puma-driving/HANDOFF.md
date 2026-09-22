# Standalone authoritative native Puma driving — orchestrator handoff

## Branch and integration

Worktree: `/home/mojo/.hermes-instances/fresh/workspace/cocs-native-puma-presentation`.
New branch: `subagent/native-puma-driving`.
Base: `edc222f` (current primary at discovery).
The original `subagent/native-puma-presentation` branch remains at `3159acb124458d5564ac6317e9f722026a68ade4` unchanged.
`2f2cc14` is the clean cherry-pick of that original Puma delivery onto the primary base. The next commit on this branch contains only the sports demo/tools/tests/evidence. If the lead already integrated 3159acb, skip the equivalent 2f2cc14 and cherry-pick only the follow-up. Inspect ancestry before doing either. No primary checkout files, shared runtime, source simulation, dependencies or other agents' files were edited. No merge, push or deployment.

## Discovery

Read original vehicle handoff; current PortNetwork, viewer/catalog/environment; source vehicles.mjs, core.mjs snapshot mapping, race.mjs, soccer.mjs, race-camera.mjs; protocol definitions and destination-sports tests; locked map entries. No subagent tool is available in this session, so both investigations were performed directly before implementation.

Ion Speedway exclusively supports puma-race; Aurora Stadium exclusively puma-soccer. Both start with an authoritative three-second countdown/kickoff. Human sports controls are ordinary protocol x/z/yaw, not invented throttle/steer wire fields. Source inverse projections are throttle=-x*sin(yaw)-z*cos(yaw), steer=-x*cos(yaw)+z*sin(yaw). Demo uses vehicle heading-PI as actor input yaw and exactly inverts these projections. Space sends jump (brake), Shift sends sprint (boost), R sends interact (race reset; soccer ignores it). Race item power is deliberately omitted. Vehicle heading zero is +Z, source ground anchor y is preserved. No position, clock, health or rules writes.

Race snapshots expose phase/countdown/laps/standings[].lap/nextGate. Soccer uses state.race with scores and ball{x,y,z,r,vx,vz}. Race reset is an interact rising edge and source two-second reset wait; no resetWait wire field is invented. Source chase convention is 9 behind, 5 above, aim 6 ahead/1 above. This rig follows heading, not velocity, so reversing cannot flip it. Camera smoothing is presentation-only; >8 m jumps snap. No local vehicle physics.

## Delivered API

`godot/sports/demo.tscn`: standalone scene.
`demo.gd`: small host client using the existing PortNetwork; explicit --endpoint and --map; create/configure/start, bounded setup and snapshot timeout, results/restart, native world reuse, fleet and ball.
`controls.gd`: physical key event gate. Enter engages only when focused, fresh, owned, alive and authoritative phase is racing/playing. Escape, focus changes, ownership/health loss and stale snapshots clear held keys and latch release. Returning eligibility never auto-engages. All movement keys must be pressed anew after engagement. Neutral packets continue while active but released. Queue failure disconnects explicitly.
`chase.gd`: follow(vehicle,delta) -> {eye,target}; reset() drops smoothing seed.

Snapshot integration point: `on_snapshot(frame)` receives accepted full network frames, calls `fleet.apply_state(frame.state, net.actor_id)`, identifies actor/vehicle ownership, applies ball snapshot and stores HUD state. No standing actor renderer is instantiated. Network sequencing/deduplication remains in PortNetwork.
Round cleanup point: `on_started(frame)` releases input, calls fleet.clear_round(), chase.reset(), clears authority and hides ball. Error cleanup does the same and disconnects. Results retain final presentation but neutralize controls. F5 sends a new start only after results; not live-accepted here.

No shared change is required. Lead owns main-menu/session integration. Existing viewer is reused read-only, with its fly controls and map selector disabled. All file changes stay under authorized sports/tests/tools/evidence paths.

## Clear launch commands

From this worktree, on a display the operator deliberately selects:

`python3 -B port/tools/native_vehicle_demo/play.py --map ion-speedway`

`python3 -B port/tools/native_vehicle_demo/play.py --map aurora-stadium`

These copy the project into a temporary directory, generate locked semantic content, import with pinned Godot and create their own normal-rate OS-assigned loopback server. The native client creates/starts its own room. Default session bound is 80 seconds; --seconds 10..80 changes it. Optional --endpoint=ws://HOST:PORT uses an explicitly approved existing server instead. No guest mode. Exit the window to stop early. Owned resources are cleaned on exit. GODOT_BIN and GUEST_NODE_MODULES can point to the existing pinned engine/dependencies. No installs. Audio is intentionally Dummy; this task adds no vehicle sounds.

Controls: wait through countdown, fresh Enter to engage, W forward/S reverse, A/D steer, Space handbrake, Shift boost. Escape releases. Refocus requires fresh Enter and fresh movement keys. R requests source race reset (not a soccer reset). F5 restart only after results.

## Actual execution

Pinned Godot 4.5.2.stable.official.6ce3de25a; Node v22.23.1; Compatibility Mesa llvmpipe.

`python3 -B port/tools/native_vehicle_demo/driving.py`

Final accepted live run: `evidence/edbe276a-8da2-4050-86f0-dda4905a0747/`.
27 synthetic sports assertions and original 19 synthetic Puma assertions passed. Both real normal-rate sessions passed. They ran on newly owned private Xvfb displays, never the owner's desktop. Native physical InputEventKey events were dispatched through Input.parse_input_event; focus loss/return was explicitly injected via engine notifications, not OS window-focus acceptance.

`python3 -B port/tools/native_vehicle_demo/validate_driving.py port/native-puma-driving/evidence/edbe276a-8da2-4050-86f0-dda4905a0747`

Strengthened offline replay passed: Ion had 93 native samples, 20 exact server/native snapshot-sequence correlations, 435 received inputs, ACK high-water 431, max displacement 30.972748 m, max heading change 2.442 radians, reverse speed reaching -6.000004 m/s and observed source race reset. Aurora had 92 native samples, 17 exact sequence correlations, 446 received inputs, ACK high-water 442, max displacement 33.653436 m, heading change 2.756 radians and reverse speed reaching -5.919861 m/s. Its ball was present throughout. Every sampled rendered position matched its accepted vehicle snapshot. Each map has 26 ACK-correlated neutral samples after release/focus gating, excluding first-stage boundary samples for in-flight packets. Fresh engagement stages are asserted. No claim that every received input was acknowledged or individually applied.

`python3 -B -m unittest discover -s port/tools/native_vehicle_demo -p 'test_validate.py' -v`

Seven replay/negative-validation tests passed. Negative tests mutate in-memory copies only and are not live evidence: missing receipts, changed server positions/actor IDs, duplicate input sequences, non-neutral release and cleanup failure are rejected. The stronger validator was added after the live recording; its replay is separate from the older summary.json fields. The harness now imports this stronger validator for future runs.

Both actual standalone launcher commands were also executed with `xvfb-run -a ... --seconds 10`; both passed, no script/engine errors in final launcher logs. Those are idle launch/cleanup checks, not driving evidence. An earlier launcher run hit unavailable ALSA and fell back to Dummy; explicit Dummy fixed that. VSync unsupported warning remains under private Xvfb.

`git diff --check` passed before delivery. Full verifier deliberately not run per ownership scope.

## Retained unsuccessful attempts

`5cc063e1-bcd1-4115-883d-24c2c2795cc5`: first Ion run failed the observer assertion because it sampled immediately after queuing an Escape event but before Godot dispatched it. Stage timestamps now allow 150 ms after native-event dispatch before sampling. This is recorded observation latency, not a game-timing change. Other neutral assertions still check real server receipt/ACK after in-flight boundaries.

`bc239695-1a7b-4c7e-967e-999e75f081a5`: Ion passed; Aurora exposed a demo startup bug: snapshot age initialized to 999 on start, permitting timeout before the first frame. Fixed by beginning the first-snapshot deadline at round start, while authority remains unavailable until a valid snapshot. Regression added. Neither failed run is final acceptance. All their owned child processes were reaped; private temporary directories are managed by TemporaryDirectory.

## Screenshots and visual status

Final live images (not synthetic fixtures):
`port/native-puma-driving/evidence/edbe276a-8da2-4050-86f0-dda4905a0747/ion-speedway.png`
`port/native-puma-driving/evidence/edbe276a-8da2-4050-86f0-dda4905a0747/aurora-stadium.png`

Both screenshots were saved from actual rendered live sessions. Browser inspection failed initializing the browser service: HTTP 400 /tabs. No pixel inspection, aesthetic sign-off or human camera-usability acceptance is claimed. Lead/owner must inspect these PNGs. Original Puma synthetic screenshot remains intact on its original branch and in the cherry-picked component.

## Cleanup, boundaries and remaining gaps

Final live run verifies owned native/importer/server/Xvfb process reaping (PID absent), server closed, sockets zero, private project removed. A normal native exit and the harness observation-ended message are NOT a native trace terminal marker or proof of complete recording. Welcome frames/credentials are never retained; server evidence stores only input and selected snapshot fields. No welcome authentication tokens in screenshots/logs.

No completed lap, goal, race item use, full sports gameplay, remote multiplayer, results/restart, human camera usability, OS focus behavior, visual parity, camera-wall collision avoidance, native sounds or live stale-transport impairment acceptance. Stale/ownership gating and round reset are synthetic regressions; release/resume and injected focus gating also run against real server input receipt. Brake/boost command receipt and reverse state are exercised, not isolated physical performance benchmarks. Soccer R has no effect and no soccer reset is claimed.

Manual lead test still required: start each map, wait countdown, Enter, accelerate/steer, brake and reverse, boost, Escape, refocus/Enter/fresh keys, inspect chase visibility (including nearby structures) and soccer ball/HUD. Test race R reset; inspect countdown/phase and lap/checkpoint/score. Exercise F5 only after real results before accepting restart. Keep broader sports acceptance gates open.
