# Exact unapplied fixes

These are review proposals against runtime cherry-pick `809ef2697463f1665f335f8602e71ecdc6d6b55a`. **None was applied or exercised by the acceptance runs.** Source `Match`, source physics, public Room restrictions and common/package hooks must stay untouched in this review. The following small replacements are independently scoped; a runtime owner must combine and verify them before integration.

## F1: preserve a received fire tap rather than ACKing an overwritten tap

In `port/native-horde/authority.mjs`, introduce `let pendingFire = false;` with adapter state. Replace line 38 with:

```js
if (Number.isSafeInteger(f.seq) && f.seq > received) {
 if (parsed.fire && !input.fire) pendingFire = true;
 received = f.seq;
 input = parsed;
 lastInput = performance.now();
}
```

Replace line 47 with:

```js
const fresh = performance.now() - lastInput < 250;
const controls = fresh ? {...input, fire: input.fire || pendingFire} : {};
pendingFire = false;
if (!fresh) input = {};
```

Set `pendingFire=false` at start and close alongside `input={}`. This is the minimum correction for the demonstrated **received** press/release pair. It is not a claim of complete input parity. Native `world/session.gd` polls physical buttons at its send cadence, so it also needs a native fire-tap latch to capture a press/release between sends. Source `game/input.mjs:46` plus `app/page.tsx:637` implements precisely such a one-step `fireTap`.

Before common integration, the native owner must define a boundary-cancel signal/latch reset for Escape, focus loss, death, results, restart, stale snapshots and errors; a physical release and a safety cancellation are currently indistinguishable neutral wire frames. Do not simply OR all controls forever. Source jump and mobility are held inputs; `reload`, `power`, `interact`, `melee`, and `grenade` come from per-step press latches in ordinary singleplayer, unlike the native held E/R path. The adapter must consume edge latches once and retain held controls until release/250ms expiry. Add meaningful tap, hold, cancellation, burst-receipt and ACK tests for that completed contract. This broader native input correction is OPEN, not solved by the fire-only replacement.

## F2: transport event identity must not assume source payload `id` is serial

Keep `eventId` as a transport counter. Add `let seenEvents = new WeakSet();` with adapter state and reset it on every new Match and close. Replace lines 50–51 with:

```js
const events = [];
for (const event of match.events) {
 if (seenEvents.has(event)) continue;
 seenEvents.add(event);
 events.push({...event, sourceId: event.id, id: ++eventId});
}
if (events.length) send({type:'events', items:events});
```

A WeakSet tracks source object identity without retaining objects dropped from the source's 300-event ring. The copies preserve original `sourceId`, payload `type` and all gameplay fields; numeric wire IDs support the existing native deduplicator. This also handles repeated string modifier/traversal IDs across waves. Do not change `Match.emit` or pretend source `type:'husk'`/`'spitter'` deployment payloads were `npc-deploy`: source spreads payload over envelope `type` too.

## F3: oversized/protocol errors must terminate the peer, not the Node process

Immediately after `wss.on('connection',(ws,req)=>{`, before rejection or message handling, add:

```js
ws.on('error', () => ws.terminate());
```

This is the minimum correction for the reproduced unhandled `WS_ERR_UNSUPPORTED_MESSAGE_LENGTH`. `maxPayload:16384` remains. Add a test expecting graceful closure and listener survival rather than the existing crash. Attach an owned server/WSS error path at launcher level too; do not absorb an authority failure as success.

## F4: cap outgoing queued bytes

Replace the one-line `send` with:

```js
const send = frame => {
 if (socket?.readyState !== WebSocket.OPEN) return;
 const text = JSON.stringify(frame);
 if (Buffer.byteLength(text) > 1048576 ||
     socket.bufferedAmount + Buffer.byteLength(text) > 2 * 1048576) {
  socket.terminate();
  return;
 }
 observe({direction:'out', round, frame});
 socket.send(text);
};
```

These caps align with the current native 1MiB frame/2MiB inbound buffer; worst-wave closure must still be measured. This bounds queued payload memory for a slow reader. Pre-upgrade local/Origin/one-client rejection and a bounded message-rate budget are additionally needed to cap rejected sockets and inbound CPU; no flood/load acceptance was run here. Never log an attempted send as guaranteed client receipt.

## F5: clock accounting

The literal `1000/60` Node interval is truncated to 16ms, and one tick per callback is not source wall-clock accounting. Keep `Match.step(1/60, …)` immutable. The minimum structural correction is a monotonic elapsed accumulator around that same tick body:

```js
let ticks = 0, wall = performance.now(), accumulator = 0;
const timer = setInterval(() => {
 const now = performance.now();
 const elapsed = Math.max(0, (now - wall) / 1000);
 wall = now;
 if (!match || finished) { accumulator = 0; return; }
 accumulator = Math.min(accumulator + elapsed, 5 / 60);
 for (let steps = 0; accumulator >= 1 / 60 && steps < 5 && !finished; steps++) {
  accumulator -= 1 / 60;
  // Existing lines 47–53: resolve input, step once, events/snapshot/results.
 }
}, 1000 / 60);
```

At round start reset `ticks=0; wall=performance.now(); accumulator=0; lastInput=0;` **after** constructing the new Match, so construction cost does not advance its clock. This is the source local application's bounded five-step policy (`app/page.tsx:637`), not a claim that the adapter is Room. The comment in the snippet denotes the exact existing tick body (with the independent fixes above if adopted), not additional simulation code. Catch-up backlog beyond five steps is intentionally discarded, as in source; document that overload behavior. Verify wall/source ratios, event ordering, input expiry and results-once at idle and bounded load. All evidence in this review used the delivered scheduler, never this proposal.

## F6: reserve scoreboard space for the Horde strip

In shared `godot/ui/scoreboard.gd`, add `var reserved_top: float = 224.0` next to other layout state, then replace:

```gdscript
page_size = clampi(int((viewport.y - 224 - 24 - 190 - team_height) / ROW_HEIGHT), 3, MAX_VISIBLE)
```

with:

```gdscript
page_size = clampi(int((viewport.y - reserved_top - 24 - 190 - team_height) / ROW_HEIGHT), 3, MAX_VISIBLE)
```

and replace the `224` in `position_panel()`'s `maxf(224, ...)` with `reserved_top`.

In `godot/horde/demo.gd` at the end of `_process`, after assigning any stale label text, add:

```gdscript
var scoreboard: Node = get_node_or_null("Scoreboard")
if scoreboard != null:
	var top := maxf(224.0, horde_label.position.y + horde_label.size.y + 12.0)
	if not is_equal_approx(scoreboard.reserved_top, top):
		scoreboard.reserved_top = top
		scoreboard.resize()
```

This is a minimal shared layout API, **unapplied and requiring the shared HUD owner's review**. It recalculates paging as well as position, instead of moving a large panel offscreen. Recheck both sizes, results, Tab, long optional-upgrade/boss text, minimum page size and other experiences before accepting it. The delivered test scene must gain the same Scoreboard child as `godot/horde/demo.tscn` (one ext_resource plus one child; increment load_steps), rather than validating an incomplete UI composition. The independent second-attempt helper exposed the overlap but reported exit resource leaks; do not reuse that failed run as clean lifecycle acceptance.

## F7: evidence gate must fail on harness/cleanup errors

In `port/native-horde/validate.mjs` CLI, immediately after reading `summary`, before calling `validate`, require:

```js
assert.equal(summary.exit, 0, 'native harness failed');
assert.equal(summary.serverClosed, true, 'listener leaked');
assert.equal(summary.sockets, 0, 'sockets leaked');
assert.equal(summary.temporaryTreeRemoved, true, 'private XDG leaked');
assert(summary.cleanup.length >= 2 && summary.cleanup.every(p => p.reaped && p.absent),
       'owned process cleanup missing');
```

This specific two-child expectation is for automated `run.mjs` evidence (native plus Xvfb), not manual or product-headless smoke. Also parse stderr/stdout for runtime errors and correlate ACKs to recipient frames. The independent auditor does the latter and rejects the retained second Meridian harness exit. Scenario-level `HORDE_DONE ok=true` remains separate from a completed native recording: there is still no native trace completion marker.
