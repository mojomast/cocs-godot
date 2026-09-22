# Minimal unapplied fixes and integration requirements

## Blocking: event append identity is not `Match.serial - events.length`

`port/native-horde/authority.mjs:19–23,128` assumes every increment of
`Match.serial` appends one event. Source `game/core.mjs:1058,1097,1153,1167`
also increments that serial for rockets, grenades and sentries. `emit` itself
increments the same counter at line 741. Consequently old ring entries acquire
new inferred wire IDs and are emitted again.

Independent reproduction (normal-rate, ordinary input; expected exit 1):

```sh
node port/reports/horde-repair-independent/horde-event-gap.mjs
```

The recorded run sends grenade-on seq 1 and grenade-off seq 2. The real source
steps seq 1 at source time 0.4666666666666666. Source spawn
`{type:'spawn',sourceId:1,time:0}` first has wire ID 1, then is replayed as wire
ID 2 beside the new grenade event ID 3. This bypasses native deduplication.
`event-gap.json` and `event-gap-wire.jsonl.gz` preserve the raw proof. The fresh
Meridian product recording independently contains **eight identical source
event payload replays**, including a repeated explosion.

### Proposed adapter-only replacement (not applied or certified)

Keep a per-round last **event object** cursor and a separate monotonically
increasing **adapter event ordinal**. Source retains event object identities in
its append/shift ring. Preserve payload `id` as `sourceId`, and leave source
objects and payload `type` untouched. A minimal sketch:

```js
export function createEventCursor() {
  let previous = null, ordinal = 0;
  return {
    take(match) {
      const ring = match.events;
      const start = previous === null ? 0 : ring.indexOf(previous) + 1;
      if (previous !== null && start === 0)
        throw Error('Source event ring cursor lost');
      const fresh = ring.slice(start);
      const batch = fresh.map(event => ({
        ...event, sourceId: event.id, id: ++ordinal,
      }));
      if (ring.length) previous = ring.at(-1);
      return batch;
    },
  };
}
```

Create/reset this cursor for every new Match, consume the initial construction
ring before advancing it, then call it after every successful step. If the
previous object was evicted, fail closed; this conservatively rejects even an
exactly-full replacement batch. Initialization must explicitly account for the
source's bounded construction history (currently one spawn for this preset).
Do not infer an exact event count from the global serial.

**API wording must change:** wire `id` is a local transport event ordinal, not
the exact source global serial. `sourceId` is the unmodified original payload ID
(numeric or string). The true emit serial for a payload-overwritten ID cannot
in general be reconstructed from the global serial and ring length alone.

Required repair tests: mixed real projectile/grenade allocations plus events;
no re-emission on zero new events; repeated string source IDs; a shifted but
still-present previous object; missing cursor/overflow; per-round reset; and
native deduplication across repeated opaque source IDs. Preserve the failed
independent grenade and Meridian evidence. Re-run the failed probe against the
actual repaired adapter. The old 29 tests passing is insufficient for this fix.

## Acceptance correction: enemy kills and source net frags are distinct

`validate.mjs:114–115` assumes the legal one-wave case has exactly three net
frags and that all deaths with killer 0 are enemy deaths. Source
`singleplayer.mjs:272,993` exposes `kills:player.frags`; a self-kill reduces that
value. The fresh Meridian run has three NPC victims `[1,2,3]`, one actor-0
self-kill, net frags/kills 2, score 94, lives 2, genuine winner-0 victory and a
released restart. The repaired CLI rejects it with `2 !== 3` despite clean
observer/harness exits. That rejection remains preserved and is not relabeled.

For a predicate meaning **three actual enemy kills**, use the distinct source
death victims where `killer === 0`, `actor !== 0`, `self !== true`, and the
victim is a source NPC from the received state. Independently check the legal
wave target, over/winner, zero enemies, and restart. Report source net frags and
self-deaths separately; do not edit source scoring. If the intended acceptance
instead requires no life loss and three net frags, retain this run as failing
that narrower criterion rather than performing an RNG retry.

## Lead-owned local adapter/package contract after re-review

The supplied `port/reports/horde-repair/API.md` otherwise describes the reviewed
boundary accurately, subject to the event identity correction above:

1. Route only Horde to `createAuthority({observe}) -> {server,wss,close}` and
   `res://horde/demo.tscn`. Bind owned loopback PORT 0. Strict readiness checks
   must verify `service === 'cocs-local-horde'`, `transport === 1`,
   `localOnly === true`, and the actual allocated port. The standalone helper
   currently checks service/port; the integration owner should check all four.
2. Carry the local input epoch, cancellation and applied-ACK extensions. ACK
   means the named sample reached a successful `Match.step`; cancelled gaps
   exist, and it does not certify a gameplay effect. Preserve separate receipt,
   step and native-queue evidence.
3. Keep exactly the three supported maps, default ten waves, optional integer
   1..30 target, and the fixed easy solo preset. Keep public/default Room's
   Horde rejection and campaign deferral.
4. Own all child/listener/error/signal cleanup, private XDG, and dependency
   closure. Separately hash port-owned `authority.mjs` and `input-buffer.mjs`;
   preserve strict immutable-source verification for transitive `game/` files.
5. Package Horde native scripts/scenes and their shared/generated dependencies;
   exclude tests, steering and reports. Run lead-owned common/aggregate, rebuild,
   extracted-package and packaged-gameplay checks after repairing the blocker.

No runtime, common glue, launcher, aggregate gate or packaging change was applied
by this review. **Independent HOLD remains in force.**
