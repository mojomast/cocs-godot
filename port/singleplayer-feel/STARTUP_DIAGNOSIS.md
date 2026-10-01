# Windows Crown startup investigation

## Original-launcher follow-up (supersedes external-entrypoint acceptance)

Windows diagnostic `36905902348` passed all three external SceneTree attempts,
but unchanged full verifier `36904489179` attempts 1 and 2 both failed at Crown
after 14 cases. External SceneTree startup ordering is different and those passes
do not resolve the production-entrypoint failure. Parent supplied the results;
no runtime fix is justified yet.

`startup_probe.mjs --run-launcher` now executes the original entrypoint:

* Windows: `cmd.exe /d /s /c ""PACKAGE\Campaign.cmd" --map=crown-array --smoke"`,
  verbatim Windows argument handling, unrelated fresh sandbox cwd and isolated
  TEMP/TMP/APPDATA/LOCALAPPDATA, matching `verify_windows.mjs`.
* Linux: `node PACKAGE/run.mjs --experience=campaign --map=crown-array --smoke`,
  same sandbox plus isolated XDG directories and `LP_NUM_THREADS=1`.
* The campaign deadline stays at the verifier's 120 seconds. On watchdog,
  Windows invokes `taskkill /PID <owned cmd pid> /T /F`; Linux terminates its owned
  process group, escalating after two seconds.

The runner injects `NODE_OPTIONS=--import=<external preload file URL>` only into
the child environment. `startup_preload.mjs` imports **exactly**
`COCS_STARTUP_PACKAGE/runtime/node_modules/ws/index.js`; no dependency fallback,
authority factory override, script entrypoint change, input injection or queue/
TTL adjustment. It observes original `send/close/terminate` methods and accepted
connections, preserving arguments, callbacks, return values and thrown errors.
It logs first command of each type (including start/input), map/route, counts,
bytes, 250-ms unsent-buffer samples, socket/TCP closure/errors, and terminate/close
call stacks. Stack line locations distinguish authority limits from launcher
cleanup. Timing uses both wall-clock milliseconds and monotonic nanoseconds.
Telemetry itself incurs modest overhead, so a diagnostic pass cannot clear the
unmodified failing full-suite gate.

Each Node process writes `startup-ws-PID.jsonl`, including argv/cwd and package
identity. Processes not using the packaged ws prototype emit only preload metadata.
Thus the same preload can instrument all 23+44 cases without file collisions.
The launcher runner additionally saves timestamped stdout/stderr chunks with its
child PID in `launcher-stream.jsonl`, raw `launcher.log`, invocation and result.
Package markers in those streams identify the authority and native child PIDs.
The result requires a real observed socket and no preload setup failure.

### Parent Windows commands (workflow remains parent-owned)

Single original Crown launch:

```powershell
node port/singleplayer-feel/startup_probe.mjs --run-launcher "--package=$package" "--output=$evidence\original-crown"
```

Full existing verifier, without editing it or the archive:

```powershell
$oldNodeOptions = $env:NODE_OPTIONS
$preload = ([System.Uri](Resolve-Path 'port/singleplayer-feel/startup_preload.mjs').Path).AbsoluteUri
$env:COCS_STARTUP_PACKAGE = $package
$env:COCS_STARTUP_OUTPUT = "$evidence\original-suite-ws"
$env:NODE_OPTIONS = "$oldNodeOptions --import=$preload".Trim()
try {
  node tools/godot-package/verify_windows.mjs $package "$evidence\original-suite"
} finally {
  $env:NODE_OPTIONS = $oldNodeOptions
  Remove-Item Env:COCS_STARTUP_PACKAGE, Env:COCS_STARTUP_OUTPUT
}
```

Keep the normal verifier assertions; upload the preload output even on failure.
The root verifier can also load the preload harmlessly; the prototype identity
only affects that exact packaged ws module, and every child PID has its own log.

### Bounded local verification

Granted local slot was used only for original-launcher Crown checks; released
afterward. Linux `091b1333` proof, **not Windows acceptance**:
`integrated-release/linux-original-launcher-probe-2/launcher-result.json` reports
`passed=true`, `instrumented=true`, exit 0. Its 96 telemetry rows include 2,349
outbound frames and 1,172 incoming frames, a peer close handshake code 1000 with
zero buffered bytes, then a teardown `write ECONNRESET`. No authority terminate
was observed. All **174 package-manifest hashes** were checked afterward and
remain unchanged, commit `091b13332fcb935af871d1affff1768a26f572e5`.

The first local probe caught packaged ws's CommonJS export shape: named ESM
`WebSocketServer` was undefined. Fixed to use the exact default export's
`WebSocketServer`/`Server` property; the runner now rejects missing instrumentation.
A Node-only real socket check verified callback-once, original send return value,
original thrown TypeError and logged terminate stacks. Its first test incorrectly
used invalid `close(999)`, which ws itself leaves CLOSING before throwing; that
test was bounded out and replaced by invalid send data without state mutation.
No production code changed and no root-cause conclusion is drawn from Linux.

## Findings and limits

The `091b1333` CI log `windows-36904489179-attempt1/campaign-crown-array.log`
only establishes that the client had previously opened a WebSocket, then observed
CLOSED. `godot/net/client.gd` emits the generic "Disconnected" in that branch;
it does not print close code/reason. This does **not** identify who closed it.
The same reported first-attempt symptom on `614e11ad` predates snapshot coalescing.

**128 packets ≠ automatic disconnect in 2.13 seconds.** Godot 4.5.2's
[`WSLPeer::_wsl_recv_callback`](https://github.com/godotengine/godot/blob/4.5.2-stable/modules/websocket/wsl_peer.cpp)
limits reads to `min(payload_space_left, packets_space_left * 2)` and returns
`WSLAY_ERR_WOULDBLOCK` when zero. Full inbound storage applies backpressure.
`poll()` closes on transport/protocol errors (and enabled heartbeat timeout),
not merely because the inbound queue reached 128. Increasing that queue blindly
would therefore address neither a proven root cause nor bounded startup flow.

There is a separate credible failure chain: long main-thread startup callback →
no network polling → TCP backpressure → Node `socket.bufferedAmount` grows →
authority's existing **2,097,152-byte outbound cap** terminates without a close
handshake. The observer already exposes `transport-error: Outbound limit`.
Ordinary socket error/close handlers currently detach without reporting details;
the external probe attaches additional listeners to distinguish them.

First-map terrain builds before connect in `campaign/demo.gd:_ready`. Initial
`on_started` still synchronously runs shared `av_start` / AV binding, then first
snapshot creates actor visuals, first-person binding, pickup/effect state and
story UI. Those are distinct post-connect stall candidates. Chapter transitions
can additionally rebuild terrain in `on_started`. The probe brackets start and
first snapshots instead of assuming robot creation is the first long operation.

## Node-only bounded evidence

`startup_probe.mjs --model-stall` imports the real authority and match, substitutes
only an EventEmitter transport whose `bufferedAmount` grows on every send, and
stops after termination or eight seconds. It does not run Godot or modify actors.

Local source observations (not the Windows archive):

| Map | Sent snapshots | Total frames | Sent JSON bytes | Max frame | Time after start | Closure |
|---|---:|---:|---:|---:|---:|---|
| Crown | 301 | 305 | 2,096,115 | 7,000 | 5.024 s | Outbound limit |
| Rootfall | 300 | 304 | 2,094,253 | 7,017 | 5.001 s | Outbound limit |

Evidence: `/tmp/opencode/crown-startup-stall-model/transport.json` and
`/tmp/opencode/rootfall-startup-stall-model/transport.json`.
This proves immediate unacknowledged publishing can hit the sender's cap even
without gameplay input, and that the observed initial bandwidth is not unique
to Crown. It **does not reproduce Windows or prove the actual close cause**:
real kernel buffering delays growth of Node's reported unsent bytes.

## Exact-package remote diagnostic proposal

Two standalone files; no package bytes, workflow, authority, client or demo edits:

* `startup_probe.mjs`: imports `PACKAGE/runtime/port/native-campaign/authority.mjs`,
  creates its ordinary Crown authority with `observe`, logs message counts/bytes,
  input arrival, resets, authority termination reason, WS close/error and TCP
  error/end. Bounded log, 120-second cleanup watchdog. The fake mode is separate.
* `startup_probe.gd`: external SceneTree script loads packaged `demo.tscn`, uses
  its real `--smoke` route unchanged, records wall-clock frame gaps and synchronous
  start/snapshot entry/exit, native queue count, close code/reason and last sequence.
  It does not replace callbacks, add polls or change limits. `--verbose` exposes
  Godot's native WebSocket failure messages.

Parent can run on Windows with the same extracted zip, before the unchanged full
verification rerun (workflow changes require parent coordination):

```powershell
node port/singleplayer-feel/startup_probe.mjs --run-native "--package=D:\path\cocs-native-windows" "--output=D:\evidence\crown-startup"
```

Collect `transport.json`, `native.log`, `invocation.json`. Keep the original archive
hash and verify extracted runtime/PCK/executable hashes unchanged. The external
script has **not** been parsed or executed by Godot locally: this lane has no
engine permission. Node fake-sender runs passed and the JS syntax was checked.

Decision rule: an observed authority `Outbound limit` with a long native callback
gap supports the backpressure hypothesis; native protocol/close errors without
authority termination require a different fix. A diagnostic success alone does
not clear the flaky packaged full-suite gate.

## Code proposal, pending coordination and remote evidence

If startup backpressure is confirmed, introduce a campaign-owned, epoch-bound
bootstrap readiness acknowledgment: send start + bounded bootstrap snapshot,
hold simulation/publication until the native client has applied that snapshot
and sends ready. Validate ready strictly, reject stale/duplicate epochs, reset
input state at release, retain the 250 ms input TTL after readiness. Cover first
launch, retry/restart and chapter transition. Keep bounded startup failure policy;
never silently grant readiness on elapsed time. This addresses the producer outrunning
an unready consumer rather than expanding queues. Any broader steady-state flow
control would need explicit snapshot delivery acknowledgment; input ACKs acknowledge
server-applied controls, not client-consumed snapshots. No production fix is made
until parent coordination and the actual Windows transport evidence.
