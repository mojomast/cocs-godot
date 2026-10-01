# Windows Crown startup investigation (no local engine execution)

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
