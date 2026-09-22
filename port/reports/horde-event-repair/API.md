# Horde event/NPC repair API — lead integration still HOLD

Runtime/test commit: `c64762ad8104c1976ba7d08051a305009eb95782`.
This supersedes the **source-global-serial claim** in the retained older repair
API. The older reports and failed validations remain unchanged.

## Local authority and event identity

The launcher-facing factory remains:

```js
const {server, wss, close} = createAuthority({observe});
// Owned server.listen(0, '127.0.0.1'); await close() on owned shutdown.
```

Readiness remains JSON
`{service:'cocs-local-horde',transport:1,localOnly:true,port:ALLOCATED_PORT}`.
The owner must check all four fields, own listener/native/error/signal cleanup,
and select `res://horde/demo.tscn` with that endpoint. Public/default Room still
rejects Horde; it is not an alternative authority for this experience.

Events retain the existing local transport shape:

```js
{type:'events', items:[{
  ...originalSourceEvent,
  sourceId: originalSourceEvent.id,
  id: perRoundAdapterOrdinal
}]}
```

- **`id` is an adapter event ordinal**, starting at 1 and increasing once for
  each newly appended source event object delivered in that round. It is not
  the source global serial, an entity ID, or a gameplay count.
- **`sourceId` is the original payload ID**, with its original string/numeric
  value. It is not required to be unique. Two distinct source event objects may
  have identical `sourceId`, type, time and complete payload: both are delivered.
- Source payload `type` is preserved, including a payload overwrite of the
  nominal `emit` type. Source objects are not mutated.
- Each Match gets a new cursor. Construction events are consumed before the
  first source step, then sent after `start`; the supported constructor's one
  initial spawn is tested on all three maps.
- Native clients already clear event deduplication on `start`. Restart and a
  new connection each begin at ordinal 1 without old-round/client replay.
- The cursor follows the last retained **object identity** in the bounded ring.
  Earlier shifts are harmless while that object remains. If it is absent, the
  authority fails closed and terminates that peer before sending a partial
  event batch or a subsequent snapshot. The listener remains reusable.
- Losing the marker is rejected even when exactly 300 new events would all fit
  in the replacement ring; that is a conservative fail-closed boundary. No
  missing history is inferred from global serial arithmetic.

The old internal/test export `eventBatch(match, numericCursor)` is replaced by
`new EventCursor().take(match)`. Production owns cursor creation and reset; the
lead launcher does not call it. Each cursor retains one source event reference
and an ordinal. Existing payload/rate/FIFO/outgoing limits, input epochs,
cancel/expiry policy, successful-step ACK semantics and elapsed scheduler are
unchanged. Observers remain read-only diagnostics; no new gameplay control API
or source-state access is added to the factory return value.

## Bounded acceptance helper

`validateRun` still requires clean harness exit/resources/cleanup, actual
product composition, source/native/step correlation, recording completion,
legal one-wave result and released restart. Its combat check now calls:

```js
validateNpcKills(roundSnapshotStates, roundEvents, resultState, localActor = 0)
// -> {npcKills, npcVictims, netFrags, lives, selfDeaths}
```

For this fixed first-wave case, three NPC identities must be established by
`isNpc === true` in that round's snapshots. Exactly three distinct qualifying
death events must identify those victims and local killer 0, excluding actor 0
and `self:true`. Unknown, missing, duplicate, nonlocal or self victims cannot
stand in for a target. IDs are derived from the roster, not hard-coded to 1–3.
There is no payload/source-ID deduplication that could erase a legitimate event.

Source `singleplayer.kills` is **net frags**, checked against the local result
actor's `frags`. Lives and self-deaths are reported separately. A legitimate
self-kill does not invalidate three genuine NPC kills. This is an acceptance
helper for the bounded case, not a change to source scoring or a generic
ten-wave/boss/defeat validator.

## Packaging implications remain lead-owned

Keep port-owned authority/input-buffer modules separately hashed from immutable
source imports, preserve the three-map/default-ten-wave local route and input
extensions, and exclude test/observer/report code from shipped resources.
The object oracle used for this report is test-only instrumentation of the
adapter cursor method; it never belongs in a production package. Common routing,
aggregate, extracted-package and packaged-gameplay gates remain for the lead.
