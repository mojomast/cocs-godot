Guest-session integration handoff

Scope and revision

Verified implementation: 3bb4268295dfc313daf9a7c2e0afc64c7fb1cb23, subject “Add opt-in bounded native guest session workflow”. Local origin is https://github.com/mojomast/cocs.git. The abbreviation was resolved with git show and branch containment checked; this is local Git verification, not a claim of remote fetch verification.

Read-only primary checkout: /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port. It was on port/godot-destinations at the implementation commit when inspected. During this work it advanced to 090178ad74f5cd2a3bbee30f5901a489141ca19d (native snapshot tracing). I inspected that diff read-only; this harness remains based on 3bb4268 and does not depend on the later tracing.

Owned branch: subagent/guest-session-integration
Owned worktree: /home/mojo/.hermes-instances/fresh/workspace/cocs-guest-session-integration
All added files are under port/guest-session-integration/ and port/tools/guest_session_integration/. No runtime, shared tests/reports, verifier, locks, README, or other agent files were changed. No system packages installed, full verifier run, merge, deployment, or push.

Exact commands and prerequisites

cd /home/mojo/.hermes-instances/fresh/workspace/cocs-guest-session-integration
node --test port/tools/guest_session_integration/test.mjs
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node port/tools/guest_session_integration/run.mjs

Prerequisites: Linux, Git with the locked source history, Node (executed with v22.23.1), existing ws dependency, and executable Godot 4.5.2.stable.official.6ce3de25a matching port/contracts/source-lock.json. GUEST_NODE_MODULES must be an absolute existing node_modules directory. It is symlinked read-only for resolution in a private temporary directory; there is no package installation. Export templates are not required. The harness invokes the existing semantic exporter with an explicit private output directory; no pre-existing generated content or primary .godot cache is needed. Exporter source-lock validation remains in force.

The standalone runner copies godot/, game/, and server/ into a private mkdtemp directory, exports semantic content there, and imports the private Godot project. HOME and XDG directories for native subprocesses are private. Source directories outside the two allowed paths are read-only. Only a small environment allowlist is passed to Godot/exporter. Outputs use a UUID directory. The private tree is deleted at completion.

Implementation findings

Production native invocation is Godot --headless --path GODOT_PROJECT res://world/session.tscn -- --endpoint=ws://127.0.0.1:PORT --join-room=ROOM_ID. Arguments after -- are user arguments. Endpoint is overridable, not hard-coded. Empty join IDs are rejected. Guest mode rejects --session-smoke and --lifecycle-smoke; those are not timeout overrides.

The harness invocation substitutes --script ABSOLUTE/observe.gd for the initial scene. This harness-owned SceneTree instantiates the exact shipped session.tscn and passively samples its fields. It does not subclass/override session methods, mutate native state, simulate inputs, change delta, or inject wire frames. This is a real headless Godot session with a test driver, not an exported standalone game binary.

Source: godot/world/session.gd, godot/net/client.gd, tools/godot-dev/launch.mjs, tools/godot-dev/two-clients.mjs, server/game-server.mjs, game/protocol.mjs, tools/godot-export/semantic.mjs.

Protocol: host sends canonical CREATE (v=3, delta=0), receives WELCOME/LOBBY, sends HOST for meridian-exchange/deathmatch with zero bots, then waits. Native sends JOIN with roomId, v=3, delta=0. WELCOME establishes peer identity; LOBBY moves native phase 10 to phase 11. Only the harness host sends START. Server START moves native to phase 3; full authoritative SNAPSHOT frames update presentation, local pose and acknowledged input. The runner imports MESSAGE and PROTOCOL_VERSION from the canonical game module.

Server construction uses createGameServer({historyPath:null, progressionPath:null}); tickDt, tickMs, snapshotHz and all simulation timing retain their normal defaults (1/60 tickDt and 1000/60 tickMs). Each case creates its own server and host-controlled random-ID room, with a UUID-qualified room name. Every listener binds 127.0.0.1 with port 0; the OS selects and holds ports. No existing endpoint is probed for reuse, attached to, or stopped.

Native handshake phases 0,1,2,10,20 have a 15-second deadline; phase 11 has 120 seconds. No documented/native timeout override exists in this implementation. Normal guest on_error sets phase -1, disconnects, and displays an error; it deliberately does not exit. Thus process exit is not a success/error oracle. The sampler observes phase and error text before the harness terminates its owned child.

Evidence and executed tests

Offline: seven passing tests in offline-tests.tap. Four are explicitly synthetic parsing/assertion/deadline tests; three exercise real owned-process cleanup without a game server, including failure, missing executable, and SIGTERM resistance requiring SIGKILL. Synthetic fixtures are not live gameplay evidence.

Authoritative final live run: evidence/5c110282-c8b3-4372-8038-fdb753b1d588/ (summary.json, per-case JSON and bounded native logs, import.log, semantic-export.log). The summary records source HEAD and SHA256 of all four harness source files, allowing exact source/evidence matching.

Positive: five observed phase-11 waiting samples with no pose, snapshots, or round starts. After host start, native phase 3, actor 1, pose present, six applied snapshots and ACK 10. The passive wire observer counted one guest JOIN, thirteen INPUT messages, seven authoritative snapshots, one server START, and six snapshots containing positive ACKs. Both native-state and wire assertions must pass; delivery on the wire alone is insufficient.

Invalid room: nonexistent UUID-based ID; native phase -1 with matching “room not found” error at about 0.50 seconds. One JOIN, no snapshots or start.

Final live runner exited 0 with all four cases PASS. Host-not-starting entered native error at 120.375617 seconds after remaining in phase 11 through the real 120-second limit. Connection-failure entered native timeout error at 15.106359 seconds. The final summary's four harness SHA256 hashes were recomputed and matched the delivered sources. All four recorded native PIDs were independently confirmed absent after completion; importer was also reaped, owned servers/rejector closed, and private temporary storage removed.

The no-host assertion requires phase 11 through at least phase_seconds 119 and native error only after 120 seconds. The connection-failure case uses an owned ephemeral loopback HTTP 503 rejector (failed WebSocket handshake), not a racy closed-port guess; no guest JOIN reaches the game server. Both require zero server starts/snapshots. This is a handshake-failure test, not a TCP ECONNREFUSED or blackhole-network test.

Earlier live run evidence/852d614f-cb54-4cc3-a90d-3403db99ee0b/ passed all four cases before final cleanup/listen hardening and source-hash recording.

Initial harness-development run evidence/987b0dbf-41d5-48aa-8b2c-6285fdbe44e8/ is retained transparently but INVALID as workflow acceptance: it omitted generated semantic assets. Its three failures were harness setup errors, not runtime defects. Its apparent connection-failure PASS is also invalid because a missing catalog produced the timeout. The final runner exports assets and the sampler rejects missing semantic-map prerequisites. Initial failed-run cleanup records remain useful cleanup evidence.

Guest role observation

A harness-owned passive observer wraps send and subscribes to message on this owned server's native socket, forwarding bytes unchanged. Host is the first WebSocket and native the second; all native application message types are counted from connection establishment, not only after a recognized JOIN. It records bounded counters and server error text, not packet bodies, tokens, credentials or environment dumps.

Within the observed waiting/initial active/error windows the guest sent no HOST/configuration, START, CREATE, REMATCH, or other restart command: only JOIN and, once active, INPUT. Assertions reject any other message type. This does not prove absence for the entire lifetime, after a completed round/results screen, or in response to interactive Enter. request_restart's guest guard was inspected in source, but an interactive/post-results restart attempt is not live-verified here.

Cleanup and bounds

Version subprocess: 10 seconds; source HEAD Git read: 5 seconds; semantic exporter and Godot import: 60 seconds each; each native case: 145-second OS watchdog plus sampler exit at 140 seconds. Protocol/readiness/error waits have explicit deadlines (5, 20, 25 or 130 seconds as appropriate). Loopback bind/rejector close have 5-second bounds. Output is capped at 400 lines of 2000 characters per native subprocess; sample cadence is half a second.

Cleanup sends SIGTERM only to the owned child handle, waits 2 seconds, escalates SIGKILL only to that same child if needed, waits 2 seconds, then checks ESRCH. Owned WebSockets are terminated and the owned game server is closed; the harness verifies server.listening=false and zero server WebSocket clients. The rejector is closed and private temp tree removed. No executable-name kills, port-based kills, or shared process groups are used. Initial failed cases and successful cases both have native reaped/serverClosed records. Offline failure and escalation tests also pass. As with any process, an external SIGKILL of the entire harness cannot run finally cleanup; do not forcibly kill its supervisor.

Limitations and defects

No runtime guest-workflow defect was reproduced with prerequisites satisfied. The missing-content false positive was a harness defect, corrected here; it is not being assigned to the primary agent. Native error screens remaining alive are existing intentional behavior and handled explicitly.

Headless state evidence does not establish graphical pointer capture, camera acceptance, focus behavior, rendered assets, or gameplay quality. No gameplay recording/analyzer, runtime tracing changes, production flags, simulation shortcuts, or full verifier integration were added. Long-round/results restart behavior and TCP-refusal/blackhole variants remain unverified, not silently passed. No prerequisite blocker remains on this host. Later primary commits were not incorporated or claimed tested.
