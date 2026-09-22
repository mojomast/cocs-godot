# Local Horde adapter API for the lead (no hooks applied)

Public Room still rejects Horde. This adapter is a separate, one-client local
transport around the unchanged source Match; it has no multiplayer/campaign route.

## Construction / ownership

```js
import {createAuthority, validateConfig, MAPS} from './port/native-horde/authority.mjs';
const authority = createAuthority({observe(record) { /* optional diagnostics */ }});
authority.server.on('error', stopOwnedSession);
await new Promise((resolve, reject) => {
 authority.server.once('error', reject);
 authority.server.listen(0, '127.0.0.1', resolve);
});
// Launch pinned Godot res://horde/demo.tscn with the actual allocated endpoint.
// Await/reap the owned native child, then:
await authority.close(); // idempotent; timer, sockets and HTTP connections closed
```

Return value remains `{server,wss,close}`. `server` is a Node HTTP server; `wss`
uses `noServer` with pre-upgrade loopback/Origin/one-client checks. The owner must
handle listener errors, launch cancellation, child errors/signals, TERM/KILL/reap,
and private XDG. No other process/service may supply the endpoint.

`GET /` returns JSON:

```json
{"service":"cocs-local-horde","transport":1,"localOnly":true,"port":12345}
```

Verify service, transport, localOnly and actual allocated port. Existing package
health checks expecting `token-arena-game-server` are incompatible and require
explicit experience-specific readiness, not a weaker generic success check.

## Config and scene

- `MAPS`: Meridian Exchange, Verdant Reliquary, Ember Crucible IDs only.
- `validateConfig({mapId, config:{mode:'horde',fragLimit:10}})` normalizes the fixed
  easy/solo/default ChatGPT+OpenClaw preset. Target is strict integer 1..30;
  omitted target is **10**. Source time limit is explicitly 900, respawn 2,
  unmodified damage/gravity/speed and ordinary source ammo rules.
- Other source profile/loadout/difficulty/endless choices are not exposed;
  optional upgrade selection remains unsupported. Do not advertise these knobs.
- Product scene: `res://horde/demo.tscn`, args `--endpoint=ws://127.0.0.1:PORT`,
  `--map=ID`, optional `--waves=1..30` (default ten). `--horde-evidence` and
  `--native-trace` are opt-in diagnostics, not steering.
- Observer is `res://tests/horde/live.tscn`, which **instances the product as a
  child** and sends engine input events from its separate controller. Never
  replace an instantiated product node's script. Exclude all tests from package.

## Local wire extension, transport 1

Existing protocol-3 create/host/start/lobby/snapshot/events/results shapes remain,
with the following explicit local-only additions. No source protocol file changed.

1. Welcome advertises `hordeTransport:1`. Start carries positive `inputEpoch`.
2. Input is `{type:'input',seq,inputEpoch,cancel:false,input:{...sourceFields}}`.
   `seq` must be a strictly increasing safe positive integer in that round;
   duplicate/lower/invalid sequences are ignored without renewing input expiry.
   An input from any other epoch is ignored before sequence acceptance.
3. **Ordinary source samples:** each accepted sample is kept in a FIFO and passed
   to one actual `Match.step(1/60,{inputs:{0:sample}})`, in sequence order. No
   replacement of intermediate fire taps by later held/released samples. Between
   new samples, held fields persist; source press fields `reload`, `interact`,
   `power`, `melee`, `grenade`, `weapon` do not repeat. Native fire/jump tap latches
   are consumed only after successful wire queueing. Source movement/mobility,
   fire, ADS/alt-fire/posture holds retain their source semantics.
4. `cancel:true` is a transport safety boundary: ignore that frame's input body,
   discard pending samples and held controls, then queue a **neutral** sample at
   its seq. This is distinct from an ordinary released-fire sample (which must
   follow, not erase, a prior fire tap). Native release/focus/death/stall/error
   paths clear physical-state models and pulse/weapon latches. Fresh capture
   requires movement/action keys and right/middle mouse to be released.
5. Source death or input expiry clears the queue/holds and advances the epoch,
   emitting `{type:'horde-input-reset',inputEpoch,reason}`. Old in-flight controls
   cannot resurrect after a death, stall or restart. Source life/health/respawn
   behavior is untouched. Inputs arriving while dead are discarded, not ACKed as
   stepped controls. New Match resets input/snapshot/cursor counters and source
   clock accumulation; input epochs continue increasing on that connection.
6. Snapshots carry `acks:{0:appliedSeq}`, `inputEpoch`, and
   `hordeInput:{receivedSeq,appliedSeq,cancelledThrough,queueDepth}`. `appliedSeq`
   means **that sample was actually supplied to a successful source step**.
   It is not proof that the actor could act, a weapon switch succeeded, a shot
   hit, or a kill/life/result occurred. It is not a contiguous-prefix claim:
   cancellation may discard earlier queued samples. `cancelledThrough` is a
   pending-input invalidation watermark, not a count or undo of prior effects.
   Received high-water is separate. The observer's `direction:'step'` records
   enumerate consumed seqs/controls/source time for stronger evidence.
7. Results ignore in-flight input and never reopen stepping. An explicit start
   creates a new Match and releases native capture. Escape releases controls;
   the match continues, like source's first pointer-release operation. No native
   pause menu/second-Escape simulation-pause UI is exposed.

Native default bindings now follow source: WASD, Space jump, Shift sprint,
Ctrl/C crouch, X mobility, Q power, E interact, R reload, F melee, G grenade,
left fire, right ADS, Z/middle alt-fire, digits 1–9/0 or wheel weapons. Default
mouse gain is source 0.002, scaled by source default 0.85 while ADS is held;
diagonal movement is normalized before the parser's
axis bounds (same direction as source Match's movement normalization). Touch,
remapping and display preference toggles are not exposed.

## Source events / clock / bounds

- `Match.emit` may overwrite payload `id` or `type`. Event cursor derives from
  source `match.serial` and the append positions in its bounded event ring.
  Wire `id` is that serial; original `id` is retained as `sourceId`. Source event
  objects and payload type are never mutated. Lost ring history fails closed.
- Scheduler uses actual `performance.now()` elapsed time, source fixed 1/60
  steps, and source local application's maximum five-step backlog. Excess stall
  backlog is discarded as in source. Construction time is excluded; clock state
  resets per round. There is no injectable production clock or synthetic dt.
- Inbound payload 16KiB; 120 messages/s with 128-token burst; FIFO 16 samples;
  oldest-input/held-input expiry 250ms. Queue overflow terminates rather than
  silently dropping commands or claiming them applied. Binary/malformed input
  fails closed. Socket protocol/oversize errors terminate the peer gracefully.
- Outbound frame <=1MiB and frame+queued bytes <=2MiB. Backpressure closes the
  peer rather than growing a queue. HTTP max connections 8, header cap 8KiB,
  request/header timeout settings 5s, keepalive 1s. A flood/load or worst-wave
  throughput qualification is not implied by bounded unit/fault probes.
- Optional `observe` sees `in`, `out`, `step`, `control-reset`, `transport-error`
  records with `round` and `observedMs`. Only `in/out` have `frame`. `out` means
  send attempt to that recipient, not guaranteed native receipt. Correlate native
  rows against snapshots and source outcomes separately. Keep observers cheap,
  bounded, and read-only.

## Packaging implications

Carry `port/native-horde/{authority,input-buffer}.mjs` at their expected relative
paths plus unchanged transitive `game/` imports and locked `ws`. Port-owned
modules require their own manifest hashes; they are not files in the locked
source commit. Keep source verification strict. Include Horde's native
`demo/model/client/controls/scoreboard` scripts, scene, shared runtime/UI/audio
dependencies and generated map content. Exclude tests, acceptance observers and
all evidence. Route only this local factory for Horde, without changing public
Room. Common options/readiness/closure/package gates remain unmodified here.

Acceptance CLI `node port/native-horde/validate.mjs NEW_RUN_DIR` requires clean
native exit/resources, owned cleanup, real product composition, both viewport
bounds, source/recipient/stepped-input correlation, scenario effects and an
explicit native `recording_end` marker. That marker closes a recording; it does
not replace harness-exit/resource checks or prove a full ten-wave run.
