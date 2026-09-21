Native trace correlation handoff

Scope and provenance

Repository origin inspected locally: https://github.com/mojomast/cocs.git. Development branch port/godot-destinations resolved to 6071da714cf8123da14d1947bd3e099e2c040503 when work began. The trace implementation abbreviation 6071da7 resolves to that full commit, “Trace native round and error boundaries without sensitive messages”. This is local Git verification, not a claim of remote fetch verification.

Base: 6071da714cf8123da14d1947bd3e099e2c040503.
Branch: subagent/native-trace-correlation.
Worktree: /home/mojo/.hermes-instances/fresh/workspace/cocs-native-trace-correlation.
Guest harness inspected read-only: /home/mojo/.hermes-instances/fresh/workspace/cocs-guest-session-integration, commit 389561510ac7c2223a22897c963f3440304ec928. Its HANDOFF.md, run.mjs, lib.mjs and observe.gd supplied proven setup and cleanup patterns. guest_helpers.mjs is vendored from that commit's lib.mjs with attribution; observe.gd adapts its passive SceneTree sampler; run.mjs adapts its startup/server observation/cleanup design. Files were obtained from Git, not referenced from the mutable guest worktree at execution time.

All changes are under port/native-trace-correlation/ and port/tools/native_trace_correlation/. Runtime files, existing tests, other worktrees, shared reports, port/README.md and the full verifier are untouched. No package installs, source switching, stash/reset/clean, merge, push, deployment, desktop/browser attachment, death/respawn orchestration or results/restart tests.

Exact commands (from the owned worktree)

node --test port/tools/native_trace_correlation/test.mjs > port/native-trace-correlation/offline-tests.tap

GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node port/tools/native_trace_correlation/run.mjs

GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node port/tools/native_trace_correlation/run.mjs --fault-timeout

node port/tools/native_trace_correlation/replay.mjs port/native-trace-correlation/evidence/6e7af608-fa87-4e1e-b7b2-a749ae342808/enabled.stdout.log port/native-trace-correlation/evidence/6e7af608-fa87-4e1e-b7b2-a749ae342808/enabled.json

The fault-timeout command intentionally exits 1 after a 100ms impossible predicate following a real native join. It is cleanup/failure-path evidence, NOT a failed runtime acceptance scenario. The other commands exited 0. See result.json for compact results. The evidence summaries record the actual per-run native command including allocated port and unique room; private temporary paths in those commands have already been removed.

Prerequisites and isolation

Existing Godot 4.5.2.stable.official.6ce3de25a, matching source-lock.json, plus Node and the pre-existing ws dependency are used without installation. The existing node_modules directory is used for read-only module resolution, not guest-harness source. The runner copies this isolated base's godot/, game/ and server/ into a mode-0700 mkdtemp directory, runs the semantic exporter into that private copy, imports that private Godot project and uses private HOME/XDG paths. It never writes generated assets or Godot caches into any checkout. Evidence directories are private; saved native/evidence files use mode 0600 and are sanitized to omit welcome tokens and host packet bodies.

Each case owns createGameServer({historyPath:null,progressionPath:null}) in the runner process, without tickDt, tickMs, snapshotHz or other timing overrides. Server defaults are normal-rate. Listen uses 127.0.0.1 port 0, reserving the OS-selected port without a free-port race. A separate UUID-named room is created for each case. Only the owned host sends CREATE/HOST/START, with v=3 and delta=0. The real headless native sends JOIN before START. Two passive phase-11 observations prove waiting, no pose, no snapshots and no starts before host action. Zero bots; no injected control state.

The observer instantiates the unmodified res://world/session.tscn. It does not subclass/override session methods, alter input, replace transport, change simulation or trigger gameplay. Its signal connections are registered after the shipped handlers. This is a real headless Godot client with a harness-owned passive driver, not an exported standalone binary.

Schema and semantics verified in source

Sources: godot/world/session.gd, godot/net/client.gd, godot/world/local_lifecycle.gd, godot/world/presentation.gd, server/game-server.mjs and server/room.mjs.

Opt in with --native-trace in user arguments after --. Endpoint and guest room are --endpoint=ws://127.0.0.1:PORT and --join-room=ROOM. No trace filename, completion option or configurable trace limit exists. Output is stdout, one line per JSON record prefixed PORT_NATIVE_TRACE followed by a space. Tracing is disabled by default. General records have schema=1, sequence starting at zero, monotonic_usec from Godot ticks, event, local round count, actor_id and phase. Trace sequence is NOT a protocol sequence. Timestamps are only checked for monotonicity, never used to join streams.

snapshot: emitted synchronously after on_snapshot applies authoritative presentation, including the absent-actor branch. Fields include ack, pose_present, health, dead, lifecycle, camera_reseeded, yaw/pitch, camera_position, pointer_captured, control_eligible and focused. health is numeric or null. Crucially, dead is a numeric remaining-respawn timer (0 when alive), NOT a boolean; null is possible for absent actors. The lifecycle helper uses dead > 0 to classify death. These fields prove program state at that handler, not rendered pixels, physical pointer behavior, prediction correctness or death/respawn acceptance. The record lacks server snapshot seq and room/peer identity.

input_queue: emitted immediately after client.send_input. Contains selected x/z/yaw/pitch and fire/jump/reload/sprint/crouch/interact/mobility controls, queue_result and queued=(queue_result==OK). ack is the previously observed snapshot ACK, not an ACK for this input. Successful WebSocket queueing proves neither server receipt nor server application. The trace does not expose protocol input seq. Client send_input increments input_seq only on success, and reset_round resets it to zero; this permits ordinal inference only for a complete fresh-round observation of all attempts with no alternate senders/reconnects. Do not use arbitrary trace excerpts for this inference.

round_start: emitted after server START invokes on_started, resets presentation/pose and enters phase 3; local round count increments. complete=false. It is a boundary record, not recording completion. It lacks mapId and server roundRevision, supplied only by the separate passive observer in this harness.

session_error: emitted after phase=-1, presentation reset, disconnect and pointer release. It deliberately omits sensitive error messages; actor_id is normally reset to -1. It establishes a native error boundary, not the cause. Parsed/tested synthetically here; no intentional native error orchestration in the positive run.

limit: after 10000 ordinary records, a separate {schema:1,event:"limit",complete:false} is printed without sequence or timestamp; no later records are emitted. This explicitly indicates truncation, not success or completion. The offline fixture exercises this exact shape/count; the live run does not reach it.

There is NO recording-completion marker. Normal child exit and bounded harness observation are NOT proof of native trace completion. completionProven remains false in all results.

Parser and correlation

validate.mjs parses only native-prefixed records, preserves source file, line, column and original order, and rejects malformed JSON, unknown schema/event, missing/wrong scalar/container fields, inconsistent queue result, sequence gaps/reordering, decreasing/negative monotonic time, malformed limit and post-limit records. Nontrace engine output is ignored. EvidenceError.kind distinguishes invalid from missing evidence; queue success lacking receipt returns MISSING_RECEIPT with explicit unmatched records, not PASS. replay.mjs exits 2 for missing evidence, 1 for invalid evidence and 0 for a correlated PASS. It expects this harness's observation JSON plus genuine native stdout, not an arbitrary log excerpt. This is a schema-1 validator, not a general log-recovery utility.

Server observation attaches before any clients, with owned host first and owned native second. WELCOME peerId and LOBBY ownership select the native actor; this prevents mixing host or unrelated actor evidence. Outbound send wrappers forward bytes unchanged and retain only start metadata, snapshot seq, actor, ack, health and dead. Native inputs are observed in the server socket's message listener, before cleanup. This listener establishes receipt, not permission checks, simulation execution or command acceptance.

START matching uses the same dedicated guest connection, exactly one server START, observer mapId/roundRevision, the native local round=1 and actor identity. Snapshot matching uses the passive client's accepted frame.seq to find the owned server's corresponding outbound snapshot. The observer executes synchronously immediately after the runtime's snapshot trace. The parser requires stdout adjacency to that event and binds native sequence to the observer record. It then compares actor, health, numeric dead and per-actor ACK high-water. No timestamp-proximity matching occurs. Native trace alone cannot identify an arbitrary server snapshot; the external passive observer supplies that missing key without changing runtime. Reconnect, duplicate/reordered input, multiple rounds or truncated captures are not silently accepted.

Input matching counts successful queue records from the fully observed fresh START to infer protocol seq 1..N, checks the server's actual contiguous seq ordering and compares every selected control field exactly. It does NOT equate trace sequence to input seq. Fresh round/connection and complete prefix are mandatory. Snapshot ACKs are independently checked against server per-actor high-water. The server uses latest-input state and appliedSeq high-water, so an ACK high-water is not evidence that every intermediate command was independently applied. Receipt and ACK/application claims remain separate.

Boundaries: capture begins at client launch; server listeners precede the connection. The passive driver quits after 12 seconds, without a native completion claim. After child stdout closes, the harness allows 200ms for server receipt, then matches all successful queues. Any unmatched tail is reported as unobserved/in-flight, not silently discarded; positive acceptance requires none. Server snapshots beyond the observed native prefix are not assumed delivered. Output is capped at 4MB per stream with a failure rather than silent truncation.

Executed results

Final authoritative run: evidence/6e7af608-fa87-4e1e-b7b2-a749ae342808/.
Enabled PASS: 981 native records, one round start, actor 1, 333 native/observer/server snapshots correlated, 647 successful input queues matched to 647 server-received messages in sequence, no unmatched queue records. Observed snapshots consistently had health=100 and dead=0. ACK high-water was 646; receipt of input 647 is NOT claimed as acknowledgement or application. The lack of death-state transitions is expected and outside this task.
Disabled PASS: guest joined before host start, received and applied snapshots; 335 server snapshot emissions and corresponding observer samples, 651 server-received inputs, zero native trace records in both stdout and stderr over the bounded window. This is not a performance benchmark and differences in counts are not interpreted as overhead.
Offline: 13 passing focused tests in offline-tests.tap. Eleven tests use explicitly synthetic fixtures (including record/actor/health/input mismatch, missing data, successful queue without receipt, malformed fields, sequence order, error/limit and signal association); two exercise real owned-process cleanup, including SIGTERM resistance and SIGKILL escalation.
Replay of final genuine output returned PASS, actor 1, 333 snapshots, 647 received inputs, no unmatched queue, completionProven=false.

Failure history is retained transparently. Initial run 7d1a088a-1107-4b43-9e88-c620846dff9a rejected genuine numeric dead because the first harness draft wrongly expected a boolean. That was a harness schema defect, not a runtime defect; the source-confirmed numeric representation and regression fixture corrected it. Its disabled case and cleanup succeeded. Intermediate run 2e41a441-c6aa-49b2-86ac-a593192dde33 passed before the additional synchronous-signal association hardening. Final run above is authoritative. a2b37402-8dab-4b13-9447-785192f4dd8a is the deliberately injected timeout after a real join; it verifies cleanup while native remains alive. No runtime defect was reproduced in this task.

Cleanup and limitations

Version has 10s deadline; semantic export and import 60s; loopback/host/configuration waits 5s; native waiting 10s; normal observation wait 16s and child watchdog 25s. Driver quits at 12s. Cleanup targets only owned child handles: SIGTERM, 2s wait, SIGKILL if necessary, then reap and ESRCH check. It terminates only owned sockets, closes only the owned game server, verifies no listening server/clients, and removes private temporary storage. Importers and every native PID were reaped. Final success and injected-timeout runs have source SHA256 matching the delivered harness sources. Recorded native PIDs were independently checked absent after execution. Evidence for success, parser failure and intentional timeout all records closed servers, zero remaining clients and removed temporary trees. External SIGKILL of the supervisor itself cannot execute finally cleanup and is not covered.

Remaining gaps: native records lack direct snapshot/input identifiers and native completion; external association is required as documented. Only neutral headless input and stable alive snapshots were exercised. Error/limit records were parser-tested synthetically, not forced live. No intentional death/respawn, results/restart, graphical focus or pointer acceptance, long-session trace-limit run, arbitrary packet loss/reconnect, or performance claim. Pointer/focus/control fields establish engine state only. The minimal reproduction for the instrumentation gap is the final live command and inspection of its genuine stdout: records contain neither input seq nor snapshot seq nor a completion record. No runtime changes were made to fill that gap.
