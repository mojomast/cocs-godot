# COCS → Godot: DESTINATIONS groundwork

This is an exercised port laboratory, not a completed game port. It preserves the Node simulation and existing web game unchanged. Start here rather than treating a passing resource import as gameplay or visual-fidelity acceptance.

## Current integration and release status

**Porting direction:** prioritize a good native Godot game over a 1:1 recreation.
Use simpler or better Godot-native implementations when they improve quality or
save development time. Preserve the locked map/mode scope, recognizable map
identity, and gameplay intent; document meaningful behavior or presentation
changes. Source visuals are a reference, not a requirement to reproduce every
shader, effect, UI layout, or technical mechanism. Acceptance should establish
correct gameplay and a coherent, usable presentation. Focus verification on
real regressions and release risks rather than incidental implementation parity.

See [RELEASE_MATRIX.md](RELEASE_MATRIX.md) for current evidence levels, all nine
required map/mode identities, graphical acceptance and release blockers. The
asset/gameplay audits, bounded recorder, guest integration and native trace
correlation tools are now integrated in attributable commits. Historical guest
and trace evidence is losslessly archived with per-file provenance; failed runs
remain failures. The independent current-runtime trace run, commands and limits
are in [reports/native-trace-independent/README.md](reports/native-trace-independent/README.md).
The sections below retain the chronological implementation history.

### Current native feature batch

```sh
export GODOT_BIN="$PWD/../godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"
PORT=0 node tools/godot-dev/launch.mjs --play --setup
PORT=0 node tools/godot-dev/launch.mjs --play --map=verdant-reliquary --mode=instagib
# Add --mute to silence procedural cues.
```

- **Host setup:** Meridian, Verdant and Ember × Deathmatch/Team Deathmatch/Instagib/Rocket Arena are enabled.
  All nine locked maps remain visible; unsupported selections explain that they
  are pending. Setup does not connect before Start. Independent native runs of
  all six combinations and a private graphical Verdant/Instagib Start passed;
  see [selection evidence](reports/match-selection-independent/README.md).
  Team Deathmatch adds snapshot-derived Red/Blue scoreboard totals; see
  [mode expansion](native-mode-expansion/README.md).
- **Combat presentation:** armored operator silhouettes, distinct pickups,
  reticle, confirmed-hit marker, damage-edge pulse and procedural event-driven
  sound cues. A compact HUD shows health/armor bars, named weapon/ammo, scores
  and lifecycle prompts; `--debug-hud` restores the old diagnostic labels.
  Physical **1–9 / 0** and the **mouse wheel** select available weapons through
  authority. Independent rocket pickup/switch verification and two-resolution
  HUD renders pass; see [weapon evidence](reports/weapon-selection-independent/README.md)
  and [HUD evidence](reports/game-hud-independent/README.md).
  Rockets now follow authoritative flight snapshots, with source-event launch
  sounds and explosion flashes. All three Rocket Arena graphical runs and host
  smokes pass independently; see [projectile evidence](reports/projectile-independent/README.md).
  Human audio review remains pending. Hold Tab for scores; results
  display automatically. These UI layers do not capture the pointer.
- **World presentation:** all nine maps now have native skies, lighting,
  material palettes, architectural accents and landmark labels. Source geometry
  stays authoritative. The integrated Meridian client was independently captured
  on a private display. See [world notes](native-world-presentation/README.md)
  and [entity notes](native-entity-presentation/NOTES.md).
- **Puma driving demo:** standalone Ion Speedway and Aurora Stadium driving is
  integrated. Independent normal-rate runs verified movement, turning, reverse,
  release/resume, rendered/source correspondence and Ion reset. Soccer includes
  authoritative ball/score state. See [driving instructions](native-puma-driving/HANDOFF.md)
  and [independent evidence](reports/native-sports-independent/README.md).
  The compact sports HUD and authored-box camera clearance are integrated;
  independent driving and near-wall checks pass at both supported resolutions.
  See [polish evidence](reports/sports-polish-independent/README.md).

  ```sh
  python3 -B port/tools/native_vehicle_demo/play.py --map ion-speedway
  python3 -B port/tools/native_vehicle_demo/play.py --map aurora-stadium
  ```

  On your deliberately selected display: wait for countdown, Enter to engage,
  WASD to drive, Space brake, Shift boost, Escape release, R race reset.
  The standalone launcher is bounded to 80 seconds by default. These sports
  scenes remain separate from the infantry setup menu; complete laps, goals,
  results/restart and human camera usability are not yet accepted.

**Combined verification: all 44 implemented gates pass** after rocket and
sports-polish integration at `b55861f` plus the gate/capture changes
recorded with this batch. Independent driving passed on both sports maps;
the default compact HUD's nonlethal damage/+35 HP/12-second return was also
independently reproduced. See [visible health evidence](reports/native-health-hud-independent/README.md).
The earlier render-instance leaks came from fixtures skipping `_ready()` and
leaving the new environment/light nodes unparented. The fixtures now own those
nodes; production cleanup was not the cause. Setup's separate premature viewport
access is also fixed. Failed runs and the corrected report are retained in
[feature-batch evidence](reports/feature-batch-independent/README.md).
The extra Deathmatch rocket pickup/fire route timed out in independent testing;
its failed attempt is retained and a harness navigation correction is pending.
Full native recording completion and broader human gameplay acceptance remain open.

## Focus loss gates pointer capture and look

Application focus notifications now explicitly gate capture eligibility and mouse-look updates. Focus return restores eligibility, not pointer capture; a fresh click is still required. Previously release alone left capture eligibility true while unfocused.

Executed evidence: the new synthetic notification regression failed two assertions before the fix (exit 1). Afterward all 2,489 control-safety assertions and the complete `python3 tools/godot-dev/verify.py` passed, including live movement/fire, normal-rate results/restart and two native clients. These are injected focus notifications, not graphical operating-system focus acceptance. Both subagents' directories remain untouched.

## Authoritative round starts release pointer capture

Round-start handling now releases interactive pointer capture even when no local results screen preceded the start. The existing reset logic is a named signal handler so regressions exercise the actual callback. Fresh snapshots reseed camera orientation but do not recapture the pointer; neutral inputs continue while awaiting the pose and afterward until an explicit click.

Executed evidence: the added synthetic session regression failed three release assertions before the fix (exit 1). Afterward, all 2,486 control-safety assertions and the complete `python3 tools/godot-dev/verify.py` passed, including normal-rate results/restart, live movement/fire and two native clients. Tests cover starts from active, results and waiting phases, reset state, neutral output and fresh-pose recovery. Headless release-dispatch assertions are not graphical mouse-capture acceptance or live host-initiated restart acceptance. Both subagents' directories remain untouched.

## Input queue failures end the session

Gameplay input queue failures now enter the existing explicit error/disconnect path instead of leaving the session apparently active. This also covers neutral sends during snapshot stalls: pointer capture is released, the pose is invalidated, and later frames stop sending. This is fail-closed session handling, not automatic reconnect or proof that the server received a final neutral packet.

Executed evidence: the new actual-session regression failed four assertions before the fix (exit 1). Afterward, all 2,456 control-safety assertions and the complete `python3 tools/godot-dev/verify.py` passed. The failure is injected through a recording transport; live network failure and graphical acceptance remain unverified. Both subagents' directories remain untouched.

## Snapshot-stall recovery requires recapture

When the session detects a fresh-to-stale snapshot transition, it now releases pointer capture once. Neutral packets continue during the stall. Fresh snapshots restore capture eligibility, but do not recapture the pointer or silently reactivate held interactive controls. A subsequent stall releases again.

Executed evidence: the new actual-session regression failed with six release assertions before the fix (exit 1). Afterward, all 2,450 control-safety assertions and the complete `python3 tools/godot-dev/verify.py` passed, including live movement/fire, normal-rate results/restart and two native clients. The new cases use synthetic clock advancement and snapshot recovery with a recording transport; they are not live network-impairment or graphical pointer acceptance. Both subagents' directories remain untouched. Server rules, dependencies and map scope are unchanged.

## Death releases pointer capture

Authoritative non-controllable local snapshots now release pointer capture while retaining the camera pose. Respawn reseeds look from the server but does not recapture the pointer: a fresh click is required before normal interactive input resumes. This prevents held pre-death controls from silently reactivating after respawn.

Executed evidence: the actual-session regression failed before the fix with four release assertions (exit 1). After the fix, all 2,435 control-safety assertions and the complete verifier passed, including live movement/fire, normal-rate results/restart and two native clients. Synthetic snapshots cover repeated dead states, neutral movement and every action, uninterrupted packet cadence, and same-ID respawn look reseeding. Pointer release is instrumented through the real session method; this headless test is not graphical mouse-capture acceptance or live intentional death/respawn evidence. Both subagents' directories are untouched. Gameplay rules, dependencies and map selection are unchanged.

## Actor reassignment control-pose isolation

The session now associates each received local pose with its actor ID. A validated lobby that reassigns or revokes that identity immediately clears control eligibility and releases pointer capture, rather than permitting the old pose to drive the newly assigned actor until the next snapshot. Neutral packets continue; repeated rosters do not reset their cadence. A fresh local snapshot binds the new identity and reseeds look. Unchanged identities preserve the pose and accumulator.

Executed evidence: the new synthetic actual-session regression failed before the behavior fix (exit 1). Afterward, all 2,397 control-safety assertions and the complete `python3 tools/godot-dev/verify.py` passed, including live movement/fire, normal-rate results/restart and two native clients. Added cases cover positive IDs, actor zero, revocation, neutral output, repeated rosters and fresh-pose recovery. Reassignment itself was injected through session callbacks, not exercised on the live server. Visual/playable acceptance and original assets/audio remain open; server gameplay, dependencies and map scope are unchanged.

## Neutral cadence and durable verification batch

Repeated absent-actor snapshots previously reset the send accumulator on every arrival. The new actual-session regression reproduced starvation at 120 and 240 FPS (exit 1 before the fix). Reset now occurs only when a previously available pose is lost. Tests exercise 30/60/120/240 FPS, neutral packet contents, bounded send rate and a long frame without backlog replay. Control safety now passes 2,369 synthetic assertions; this is not live actor-removal acceptance.

The verification runner now writes atomic progress reports before executing gates, records individual durations and failure categories, preserves output on timeout, and terminates the timed-out command's process group so launcher children do not retain the output pipe. Launch failures and Godot error text with exit zero fail closed. The version probe and release-refusal check are bounded too. Preflight failures replace old success with explicit failure; interruption leaves a running/incomplete report rather than passed evidence.

Executed evidence: six permanent runner tests passed, including a real timed-out subprocess with a child inheriting stdout. Separate full-runner preflight probes verified missing GODOT_BIN and wrong-version failure reports. The complete verifier passed after the final changes: 27 gates including toolchain check, release refusal, normal-rate live results/restart, movement/fire, recorded replay and two native clients. Reports contain actual execution output, not sample data. Source gameplay, dependencies and map scope remain unchanged. Visual/playable acceptance, original assets/audio, live pickup/death/respawn and prediction remain open.

## Missing-pose neutral input continuity

Active rounds now keep sending neutral movement and action packets while the local pose is unavailable, rather than stopping input transmission. Pose availability remains required for active controls. This covers the initial snapshot wait and loss of the local actor; results still stop gameplay input. Restoring a pose restores normal eligibility without replaying prior inputs.

Executed evidence: the added actual-session process regression failed before the fix (assertions 2123–2125, exit 1). After the fix, `control-safety` passed 2,149 synthetic assertions, checking held fire followed by three neutral packets, all action flags, pose recovery, and results suppression. The complete `python3 tools/godot-dev/verify.py` passed all implemented gates, including normal-rate results/restart, live movement/fire and two native clients. The regression uses a recording transport double and is not live actor-removal acceptance. Visual fidelity and playable acceptance remain open.

## Eight-part native control safety batch

1. Native movement axes are normalized before rotation, so diagonal keyboard input has unit magnitude rather than exceeding cardinal input. Authority stays on Node.
2. A shared control-math helper rejects nonfinite movement and sanitizes nonfinite look seeds.
3. Look yaw wraps to a bounded revolution and pitch remains clamped, both on authoritative pose seeding and mouse motion.
4. Pointer capture now requires an active round, received local pose, fresh snapshot, and controllable lifecycle.
5. Mouse look ignores stale/dead/results/waiting states and nonfinite relative motion; fresh eligible input resumes without replaying discarded deltas.
6. Invalid or negative frame deltas are ignored before timers or session processing can be poisoned.
7. Missing local actors clear the pose latch and input-send accumulator and release the pointer; subsequent valid poses reseed look.
8. Added a permanent `control-safety` verifier gate covering these boundaries and 1,000 mixed fresh/stale look cycles. Its assertion harness accumulates failures and exits nonzero rather than allowing a later success exit to mask them.

Executed evidence: full `python3 tools/godot-dev/verify.py` passed, including live movement/fire, normal-rate results/restart, recorded replay and two native clients. The new suite passed 2,121 synthetic assertions. Its initial run exposed an overly strict test comparison at float32 +/-PI; a 1e-6 boundary tolerance resolved that test defect. These tests do not establish real graphical focus/mouse behavior, internet impairment, or playable acceptance. No source gameplay/server rules, dependency locks or map selection changed. Original assets/audio, live intentional pickup/death/respawn acceptance, graphical review and prediction remain open.

## Session recovery and focus batch

The actual native session now bounds each connection/create/configuration/start waiting phase to 15 seconds, clears presentation and disconnects on expiry, and reports a relaunch instruction. This is a provisional per-phase deadline, not automatic reconnect. Room creation, configuration and initial start queue failures now fail explicitly instead of advancing into a silent wait.

Restart requests remain in results when transport queueing fails, preserving Enter-to-retry. Successful queueing enters the authoritative-start wait; repeat Enter events and requests outside results do not enqueue duplicate starts. Application focus loss releases pointer capture; regaining focus does not automatically capture it again. Escape remains an explicit release.

Executed evidence: `session-recovery` passed 52 assertions against the actual session methods with explicitly synthetic queue outcomes, clocks and focus notifications. Tests cover failed/successful configuration and initial start, retry, duplicate suppression, all waiting-phase deadlines, phase timer reset and non-waiting phases. Focus tests verify release dispatch, not a real graphical desktop focus transition. The complete `python3 tools/godot-dev/verify.py` passed, including normal-rate live results/restart, movement/fire and two native clients. No source gameplay, lockfiles or map selection changed. Visual/playable acceptance, live pickup/death/respawn, original assets/audio and prediction remain open.

## Unassigned acknowledgement isolation

Snapshot ACK lookup now requires a nonnegative assigned actor ID. The internal `-1` sentinel can no longer acquire acknowledgement progress from a wire `"-1"` key after roster revocation or connection reset. Snapshot ordering and buffering continue normally for unassigned clients, and actor zero still accepts its own ACKs.

Executed regression evidence: the added synthetic cases failed before the fix (assertions 87 and 90), then `protocol-envelopes` passed all 95 assertions without engine errors. The complete `python3 tools/godot-dev/verify.py` suite passed, including recorded replay, normal-rate live session/results/restart and two native clients. This is defensive handling of synthetic ACK data, not an observed live-server defect. Visual/playable acceptance remains open.

## Unique roster actor ownership

The native client now rejects a full lobby roster assigning the same non-null actor ID to different peers, before emitting a lobby signal or changing actor identity, acknowledgement progress, input sequence, or snapshot ordering. Actor zero is valid and receives the same uniqueness check; multiple unassigned/null spectator entries remain valid. Reordering a valid roster remains supported.

Executed verification: `res://tests/protocol/envelopes.gd` passed 84 synthetic assertions, including collision ordering, integer/float ID equivalence, remote-only ownership collisions, atomic rejection, and valid unassigned spectators. `python3 tools/godot-dev/verify.py` passed every implemented gate, including recorded replay, native live/session smoke, normal-rate results/restart, and two native clients. Malformed ownership tests are synthetic, not an observed server defect or a live attack test. Graphical/playable acceptance remains open.

## Locked content

Source: `51289b79c627a26a381ba556b92bab71f93f3732`, the deployed v8.8 DESTINATIONS tree. Implementation branch: `port/godot-destinations`.

The owner clarified the target as v8.8, so an upcoming branch is no longer required. Registry execution at `6b6368b16d9c17ef57f2d26792703a70427c5a32` in an isolated comparison worktree and at the target identifies exactly these nine additions:

Meridian Exchange; Verdant Reliquary; Ember Crucible; Tidal Citadel; Sunscar Convoy; Asterion Relay; Monsoon Foundry; Ion Speedway; Aurora Stadium.

`contracts/map-selection.json` records IDs, source modules, authored commit, modes and distinctive features. LATTICE, race and soccer identities are preserved. Meridian is the first infantry spike, not a substitute for the rest. Older maps remain only in the source server's registry; none enter the generated manifest/menu/diagnostic package.

## Reproduce from the repository root

Requires Node >=22.13, npm, Python 3, desktop Linux x86_64. Xvfb is optional for graphical captures without a display. Downloads require network access. `npm ci --ignore-scripts` was sufficient for the isolated export harness; this does not claim the production web build has been tested.

```sh
npm ci --ignore-scripts
python3 tools/godot-dev/install-toolchain.py --directory ../godot-toolchain
export GODOT_BIN="$PWD/../godot-toolchain/Godot_v4.5.2-stable_linux.x86_64"
export XDG_DATA_HOME="$PWD/../godot-toolchain/data"
export XDG_CONFIG_HOME="$PWD/../godot-toolchain/config"
export XDG_CACHE_HOME="$PWD/../godot-toolchain/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
npx playwright install chromium
node tools/godot-export/semantic.mjs
node tools/godot-export/browser-export.mjs
node tools/godot-export/browser-export.mjs meridian-exchange
python3 tools/godot-dev/verify.py
```

Toolchain: exact Godot `4.5.2.stable.official.6ce3de25a`, Compatibility renderer. The installer verifies official SHA512 sums and installs matching Linux export templates. Editor/template archives stay outside the repository; no engine upgrade or dependency-lock update was made.

The source lock is not regenerated by builds. To reproduce intake itself:

```sh
git worktree add --detach ../cocs-godot-comparison 6b6368b16d9c17ef57f2d26792703a70427c5a32
node tools/godot-export/intake.mjs ../cocs-godot-comparison
```

Do not rerun this hard-pinned intake script to adopt a later release without reviewing and updating its source/comparison constants and the owner-approved selection.

## Use the viewer

```sh
"$GODOT_BIN" --path godot
"$GODOT_BIN" --path godot -- --visual-probe
```

Default viewer: nine-map selector, authored solid/terrain geometry and native
environment styling. Right mouse looks; WASD/QE flies; Shift accelerates.
`--diagnostic-markers` adds spawn beams and asymmetric coordinate axes. Static
pickup orbs are display aids; the native session replaces them with authoritative
pickup models. The viewer's free camera is not gameplay. Missing/corrupt maps fail
closed. Changing selection unloads the previous world.

`--visual-probe` loads the actual Meridian GLB through Godot's GLTFDocument. Selecting another map returns to semantic mode. Other maps do not yet have accepted visual exports. The probe imports the world hierarchy, not full dynamic/game presentation.

Capture the real renderer (software Mesa in this environment):

```sh
xvfb-run -a "$GODOT_BIN" --audio-driver Dummy --path godot -- --visual-probe --capture="$PWD/port/reports/meridian-glb.png"
```

A graphical capture is saved, but no cross-renderer visual acceptance is claimed. This environment emitted shader-cache write errors and a VSync warning during capture. Headless resource/runtime tests pass independently. The browser inspection tool failed with HTTP 400, so the saved screenshots still need human/vision review. No hardware frame-rate claims are made.

## What the exporter does

`semantic.mjs` strictly serializes all selected map root records, resolves callable terrain through the source triangulation helpers, preserves two-point wall segments, and emits provenance/counts/SHA256 hashes. Undefined structure colors are explicitly recorded omissions selecting source renderer defaults. Unexpected functions, cycles, typed arrays, nonfinite numbers and other unsupported objects fail rather than disappearing. Two clean exports are byte-identical in tests.

Output: `godot/content/generated/manifest.json` and `maps/<id>/map.json`. Manifest is intentionally `content_kind: semantic-diagnostic`, `release_ready: false`, with `world_glb: null`. `--release` deliberately fails until the remaining gates pass. The complete selected source tree is checked against the source lock before generation. Generated output is not hand-edited or committed.

`browser-export.mjs` uses the pinned Three.js dependency in a real browser context, initializes Moth assets, builds either the weapon/axis/instancing probe or a requested allowlisted map, converts supported RGBA DataTextures through canvas, expands instances with transforms/colors, and exports GLB. The isolated harness avoids constructing a legacy default arena and does not automate the production menu. No paid asset generation or API key is involved.

Visual spikes live under `godot/content/probes/`, intentionally outside accepted generated content. BatchedMesh and unsupported DataTexture formats are hard failures. userData is stripped temporarily and restored; a semantic dynamic-ID/anchor sidecar is still required before promotion. Shader hooks, sky/postprocessing, dynamic states and animation functions do not become native Godot effects automatically. Standard-material warnings are retained in reports.

Rendering RNG required an explicit seed (1337) in the isolated browser realm. Two separate seeded Meridian builds produced identical GLB bytes; report: `reports/glb-reproducibility.json`. This is a one-map/one-toolchain result, not universal cross-platform determinism.

## Protocol groundwork

Actual source protocol is v3, not the handoff's older v2; delta remains disabled. Typed `godot/net/client.gd` provides lobby/start/snapshot/events/results/error signals, source actor identity, string-key acknowledgements, bounded snapshot/event queues, event deduplication, map-substitution rejection, explicit reconnect reset and a 1MiB frame cap. That cap is provisional, not a measured all-map maximum. Automatic resume, input prediction and complete malformed-packet hardening remain work. Remote interpolation is implemented in the presentation layer (see below).

```sh
node tools/godot-fixtures/capture.mjs
node tools/godot-dev/launch.mjs --network-smoke
```

Capture runs the real pinned server, two WebSocket clients and two bots through configuration/start/input acknowledgement/results/restart. It accelerates wall time (`tickMs=1`, simulation dt unchanged); it is not internet-latency or performance evidence. Captured reconnect/progress credentials are explicitly redacted to null. The fixture is genuine server output, not authored packet examples.

The separate native live smoke uses Godot WebSocketPeer against the normal 60Hz server: one native client, two bots, actor identity and input ACK. It exits once verified. This is not a server-backed playable match.

The development launcher owns a loopback-only server, uses a free port by default, checks HTTP readiness, isolates Godot runtime files and cleans up the server when its child exits. Server history/progression are ephemeral. With no flags it launches the diagnostic viewer. `--play` now launches the native server-backed Meridian session described below. Node packaging is not supplied.

## Diagnostic executable

```sh
"$GODOT_BIN" --headless --path godot --export-debug 'Linux Diagnostic (not a game release)'
.port-runtime/destinations-diagnostic.x86_64 --headless -- --smoke
```

This produced and exercised an actual Linux diagnostic executable using matching templates. It includes only the nine selected semantic maps, excludes fixtures and GLB spikes, and is not a packaged standalone game. `.port-runtime/` and `.godot/` are ignored. Required script UID metadata is committed.

## Evidence and next integration gates

`reports/verification.json` and named logs record the implemented gates. Current results: five export tests, 88 applicable source tests, headless editor import, all-nine-map repeated viewer load/unload, native GLB/axis/instance checks, captured packet replay and native live transport smoke pass. Release refusal is tested. The full original web/server suite was not run.

The first real visual gate remains OPEN: inspect matching source/Godot views, material/normal/UV behavior, winding and routes; inventory dynamic nodes, anchors, texture provenance, environments and missing effects. Export the other eight visual maps only after that interface is accepted. Do not promote the probe just because its GLB imports.

## Native session increment

```sh
node tools/godot-dev/launch.mjs --play
node tools/godot-dev/launch.mjs --session-smoke
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/presentation.gd
```

`--play` hosts Meridian deathmatch with two existing server bots. Native snapshot presentation maintains stable actor nodes, hides the local/dead actors, follows the source eye position and displays health, armor, weapon/ammo, frags/deaths and results. Click captures the pointer; Esc releases it. WASD moves; Space jumps; Shift sprints; Ctrl crouches; R reloads; E interacts; F holds mobility. Mouse aims/fires. Enter after results sends the source protocol's `start` request for another match. Uncaptured/unfocused input sends neutral controls. No local Match or client authority is introduced.

This is an interactive diagnostic prototype, NOT the first-playable acceptance milestone. Actors are capsules and the level is semantic geometry. Pickup markers now follow authoritative snapshot positions and availability; they remain diagnostic cubes rather than original models. There is no original weapon model, dynamic obstacle presentation, audio or prediction. Server-driven diagnostic shot tracers and hit/damage messages are now implemented (see Combat feedback increment). Remote actors now use receive-clock interpolation with a provisional 100ms delay; the local camera still follows authoritative snapshot cadence and local look responds immediately. The renderer has not been visually accepted. Race/soccer/LATTICE sessions are not exposed by this prototype; all nine maps remain in the separate viewer.

Real `--session-smoke` execution verified three presented actors, source-authoritative camera updates, displacement greater than 0.5 metres, server-recorded shots, and more than ten acknowledged inputs. It runs the normal-rate server and actual session scene, not a separate mock implementation. Recorded-packet replay verified six states including a results state, coordinates, eye height, visibility and HUD. Additional explicitly synthetic lifecycle mutations test absent-actor and reset cleanup. These do not establish live pickup/death/respawn/restart completion, second-native-client behavior or keyboard/graphical usability. The existing transport-only smoke and captured recording used an ignored `forward` input; they remain transport evidence only. New movement input uses `x/z`, matching `game/input.mjs` and `game/protocol.mjs`.

The full verifier now includes presentation replay and the native-session smoke; all implemented gates pass. Next gates: original actor/weapon presentation and visual review, live pickup/death/respawn/results/restart acceptance, two native clients, then essential audio, prediction and selected-map-specific features.


## Remote motion increment

`world/remote_motion.gd` buffers up to 32 receive-timestamped poses per actor and interpolates remote position and shortest-path yaw. It holds the newest pose on packet starvation rather than extrapolating. Death/respawn transitions and displacements above 8 metres flush history; despawn and round reset remove it. The distance threshold is a provisional visual heuristic, not authoritative teleport detection. Local position, camera, HUD and visibility are never delayed. The 100ms receive-clock delay is not server-clock synchronization or prediction; clustered arrivals and high-speed traversal still need measured network testing.

`tests/protocol/remote_motion.gd` exercises 14 explicit synthetic checks: interpolation, yaw wrap, startup/starvation clamps, timestamp rejection, teleport/death/respawn history, bounded storage, local-camera invariance and cleanup. The normal-rate native session smoke additionally requires remote pose application through the actual scene process loop. These gates do not constitute visual smoothness acceptance or adverse-network benchmarking.

## Two-native-client increment

Run `node tools/godot-dev/two-clients.mjs` with the pinned `GODOT_BIN`. The runner owns a normal-rate, ephemeral loopback server and two separate headless Godot processes. One native client creates/configures Meridian deathmatch; the other joins through the new `PortNetwork.join_room()` API. No JavaScript client substitutes for either player. Room identity is retained from welcome and cleared on disconnect; reconnect still requires an explicit fresh join.

Both clients independently require four presented actors (two humans and two existing bots), distinct authoritative human identities, movement of both human actors by more than 0.5 metres, their own input acknowledgement above 15, and remote interpolation applications. The runner cross-checks both human identity lists, rejects errors/early exits/timeouts, then terminates its owned children and closes the server. Per-client XDG directories isolate runtime caches. `reports/two-native-clients.json` contains actual run evidence, without reconnect credentials. This gate is included in the full verifier.

This closes the narrow two-native-client transport/presentation smoke gate, not multiplayer playable acceptance: it is headless, loopback, a short movement run, and does not test adverse networks, full match lifecycle, graphical input, reconnect recovery or a join-menu UI. The interactive launcher is unchanged. Original models/audio, visual acceptance, pickup/death/respawn/results/restart and prediction remain open.

## Round boundaries and live restart increment

Results now latch at the protocol boundary: duplicate results, late snapshots and late combat events cannot overwrite the results presentation. An explicit server start resets the latch, acknowledgements, sequence tracking and effect identity history. Disconnect clears transport identity; session errors clear actors, pickup/effect nodes and control state while preserving the visible error message. No automatic reconnect/resume is implied.

`node tools/godot-dev/launch.mjs --lifecycle-smoke` exercises the actual session scene against a normal-rate Node server, with two bots and a 60-second match (the source configuration minimum). It verifies results disable controls, sends the normal restart request and verifies a new alive local actor, three presented actors and fresh acknowledged input. Real execution returned `starts=2 results=1 restarted_actors=3 restarted_ack=11 map=meridian-exchange normal_rate=true`. The initial attempt timed out because a requested 30-second limit was clamped to 60; the corrected gate uses a 90-second deadline without changing source rules or accelerating simulation.

Twelve explicitly synthetic boundary/cleanup assertions also passed. Full `python3 tools/godot-dev/verify.py` passed all implemented gates, including the new lifecycle/combat/boundary tests, normal-rate live results/restart, recorded replay, native imports, two-native-client movement, source/export tests and release refusal. Logs and verification JSON in `reports/` are regenerated from real execution.

This closes the narrow native results/restart gate, not full playable acceptance. Live intentional pickup collection and death/respawn, visual review, original models/audio, network impairment handling, local prediction and map-specific modes remain open. Node authority and the pinned nine-map scope are unchanged; no push or deployment occurred.

## Combat feedback increment

`world/combat_feedback.gd` consumes deduplicated server shot/damage events. It creates source-endpoint diagnostic line tracers (128 maximum, 120ms lifetime) and brief hit-confirmation/damage HUD messages. Environmental and self damage never confirm a hit on another actor. Results/new rounds clear effects. This is not original weapon presentation, projectile rendering or audio.

Native execution passed 13 explicitly synthetic checks including actual mesh endpoints, decoder deduplication, event identity reuse after reset, null-source attribution, bounds and expiry. Genuine recorded events exercised 610 shots and 32 local hit confirmations. The normal-rate live session now requires event-driven feedback and passed with one confirmed shot event, movement, ACK 14 and 76 remote poses. No graphical appearance acceptance is claimed.

## Local lifecycle increment

`world/local_lifecycle.gd` derives alive/dead/waiting/results strictly from authoritative snapshots. Dead players send neutral movement/action controls; the HUD shows the server-provided respawn timer without locally predicting its completion. First spawn and respawn reseed mouse look from the server pose; ordinary snapshots preserve immediate local mouse look. Missing local actors gate controls, and new rounds reset transition state.

The native targeted test passed 12 explicitly synthetic transition assertions. The real normal-rate session smoke also passed (three actors, movement, shots, ACK 12, 66 remote pose applications, 20 pickup markers). These are not live death/respawn acceptance or graphical evidence.

## Resilience batch

Five implementation/test increments were exercised with the pinned Godot binary:

- `860e5f2`: validate welcome/lobby/snapshot/event envelope shapes before typed iteration or integer conversion. Invalid event batches are rejected before deduplication state changes. 31 synthetic assertions passed; genuine 3,616-frame recording still replays. This is not complete nested gameplay-state schema validation.
- `a0b536a`: reject nonfinite remote positions, yaw and receive timestamps. 1,801 deterministic assertions cover synthetic dropped delivery, duplicate/stale timestamps, outage hold, memory bounds and invalid numbers. These are receive-schedule tests, not network latency benchmarks or graphical smoothness acceptance.
- `8a55c8c`: show receive-age warnings and send neutral controls after one second without a fresh snapshot. Normal input eligibility returns when authoritative updates resume. Eight clock checks and the real normal-rate session smoke passed. The threshold is provisional; this cannot guarantee delivery of neutral input across a broken connection and does not replace server timeout behavior.
- `d135783`: consume input sequence numbers only after successful transport queueing. 46 assertions cover the real disconnected peer and explicitly synthetic queue failures, retry and round reset.
- `91c24bc`: exercise the actual session process with synthetic clock/transport injection; 12 assertions verify movement/fire/all action buttons neutralize on stall, warning text appears, fresh updates recover controls, and disconnect resets the guard.

The full verifier passed after integration, including all new gates, existing source/export tests, native import, genuine packet replay, normal-rate results/restart and two-native-client tests. Generated test script UIDs are retained. No gameplay source, server rules, dependency locks, map selection, deployment or workspace layout changed.

Remaining gates are unchanged: live intentional pickup/death/respawn acceptance, original actor/weapon/audio presentation, graphical review, actual impaired-network testing, local prediction and map-specific modes. The helper CLIs attempted at the beginning of this pass failed authentication/model access before making changes; implementation and verification were completed directly.

## Lobby identity increment

The native decoder now treats each lobby as a complete roster, matching `server/room.mjs` `Room.lobby()`. A null assignment, absent local peer or empty roster clears the previous local actor identity instead of retaining it. Duplicate peer IDs are rejected before any identity mutation; map-substitution rejection remains atomic. This does not implement spectator UI or automatic reconnect.

The envelope suite passed 46 synthetic assertions, including 15 new assignment/revocation/reassignment and invalid-roster checks. The full verifier passed after integration, including genuine packet replay, normal-rate native results/restart, session movement/fire and two native clients. Live intentional assignment revocation and graphical acceptance remain untested. Source gameplay/server rules and nine-map scope are unchanged.

## Actor-scoped acknowledgement increment

Lobby reassignment or revocation now clears the previous actor's acknowledgement high-water mark. An unchanged assignment preserves it; malformed rosters leave it untouched. Connection input sequence numbers and snapshot ordering are preserved across assignment changes. This prevents an old actor's ACK from masking a new actor's lower acknowledgement value without introducing sequence reuse.

Real execution passed 63 envelope assertions, including 17 new synthetic checks for reassignment, revocation, unchanged identity, invalid-roster atomicity, old-actor ACK isolation and monotonicity within an assignment. The full verifier passed, including genuine packet replay, native session movement/fire, normal-rate results/restart and two native clients. Live intentional reassignment and graphical acceptance are not established by these tests. Gameplay source, server rules and map scope remain unchanged.

## Snapshot pickup increment

`world/pickups.gd` maintains diagnostic markers keyed by authoritative pickup ID, not array position. Snapshot `wait > 0` hides a collected pickup; a later authoritative `wait <= 0` reveals it. There is no local respawn countdown or client collection authority. Position uses snapshot x/y/z with an explicit one-metre diagnostic marker offset, rather than resampling terrain. Kind metadata is retained; original pickup meshes/effects are not yet implemented. Missing pickups are removed and round start clears nodes. The viewer keeps its static markers; the interactive session hides that group and consumes snapshots/results instead.

`tests/protocol/pickups.gd` passed 374 assertions across six genuine recorded states plus explicitly synthetic collection/respawn, reorder, removal and reset cases. Synthetic tests demonstrate presentation semantics, not a player collecting an item over the network. The actual normal-rate session smoke also requires nonempty dynamic markers and hidden static markers. The full verifier passed including the two-native-client gate. Live end-to-end collection/respawn, graphical acceptance and complete match lifecycle remain open.

Ownership and interfaces are in `contracts/CONTRACT.md`. No subagent tool was exposed in this session; lanes were executed serially by the lead. Existing `game/`, `server/`, package manifests/lock and production services were not changed. No branch was pushed and no deployment or Orbit workspace mutation was performed.
