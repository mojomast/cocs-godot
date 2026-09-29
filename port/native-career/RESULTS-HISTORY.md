# Native Career RESULTS / HISTORY

Adds two read-only tabs to the existing **CAREER / ARSENAL** modal:

* **RESULTS** — the latest *accepted* source `results` state plus the source
  award that belongs to that same round.
* **HISTORY** — the server's recent-match list (`{type:'history'}`), requested
  on demand from the seated connection.

Neither tab is an authority. No outcome is computed, no stat is invented, no
history row is associated with the local profile and nothing is persisted by
Godot.

## Source contract (unchanged, authority `61fca35`)

`server/history.mjs` `MatchHistory.all()` returns the most recent **server**
matches (cap 50). A recorded player row carries only
`name / character / harness / frags / deaths` (plus soccer `goals` and bounded
`scoreStats`); there is **no stable career id**, so a history row can never be
attributed to the local career from a name. The reader therefore labels the
list *Recent server matches* and never claims a personal timeline.

The exact top-level `progression` shapes are disjoint:

| reply | top-level fields |
|---|---|
| GEAR write | `type, profile, gear, attachments` |
| match award | `type, profile, gained, baseGained, prestigeBonus, achievementXp, levelUp, prestigeUp, unlocked, achievements, progress, toNext, result, actor, mode, flagged` |

`career/results_model.gd:is_award` requires `gained` **and rejects any
top-level `gear`/`attachments` key at all** — even a partial or malformed one.
A mixed frame is equipment, never an accepted award.

## Numeric policy (no fabricated values)

* Identities, counts and XP use `safe_int`/`count`: an exact, non-negative
  integer within the JS safe range. A fractional value (`1.5`), a negative
  value, or an overflow is **unknown** — never floored, zeroed or wrapped. A
  negative penalty count (e.g. source `frags`) stays unknown rather than `0`.
* Elapsed time, history `duration` and `objectiveTime`/`damage` use `decimal`:
  a finite non-negative number that keeps the source precision. The UI formats
  it deliberately (`format_seconds`), storage never floors it.
* A 0..1 ratio (`progress`) outside 0..1 is unknown; it is never clamped into a
  made-up `0`/`1`.

## Wire admission and round pairing

The source sends the reward **before** the result
(`server/room.mjs`: `history.record` → per-peer `awardOwned` `progression` →
`sendResults`). `results` carries no `roundRevision`; `start` and `lobby` do.
The service therefore:

1. on `start`, records a round key only when the source supplied a valid
   `roundRevision`. The internal key is `SHA-256(endpoint\nroom):revision`, so a
   long endpoint can never be clipped into a correlation mismatch and the raw
   endpoint never enters the public projection;
2. on an award `progression`, witnesses it only when the frame's profile id is
   the bound source identity **and** its `actor.id` equals the current known
   actor id;
3. on the matching `results`, exposes that award only when the round keys agree;
4. otherwise keeps the reward as *Latest source award* — never attributed to a
   result. A missing revision or actor context stays generic, and a result with
   no known started revision is rendered read-only (`reconnect`).

A `welcome` opens a new connection epoch and clears every per-round witness, so
a `results` **replayed on reconnect** renders read-only with an **unknown**
award instead of reusing the previous round's reward. A `results` seen twice in
one epoch is flagged `replayed` and keeps the single witnessed award. The reader
never counts matches, so a duplicate cannot double-count.

`service.receive(client, frame)` handles `welcome`, `start`, `results`,
`history`, `history-error` and `progression` and only admits frames from the
connection that `welcome` bound (`owned(client)`), so another client's history
or result is ignored. It requires the seated career connection
(`room_id` non-empty, `career_seated`, `career_wire_open()`).

## History request

`service.request_history()` sends the existing `{'type':'history'}` verb through
`client.send_frame` (no network edits). It is allowed on any admitted seated
connection, including a spectator seat, because the reply is server-wide rather
than personal data. The wire has **no request id**, so exactly one request may
be outstanding; `force` cannot stack a second one.

Status is one of:

| status | meaning |
|---|---|
| `offline` | Home / no seated source. No request is sent. |
| `loading` | one request in flight |
| `ready` | bounded list projected (≤50 records) |
| `empty` | the source replied with zero valid records and no malformed ones |
| `error` | malformed envelope, all-invalid reply, or non-fatal `history-error`; last known list kept |
| `timeout` | no reply within 8 s; the slot is released so an explicit refresh can retry |

A malformed entry is counted and skipped while every valid record keeps its
known facts. An **all-invalid** reply is reported as an error and keeps the last
known list (`error`, never a fabricated `empty`). A reply that arrives with no
outstanding request (e.g. after a timeout) still updates the snapshot but is
labelled a delayed observation, never a fresh readiness. Disconnect clears the
list and returns to `offline`.

The parent owns the source persistence: an owned local server is started with
`historyPath=<careerroot>/history.json` under the same exclusive owner lease as
progression, and the existing store is validated before the factory creates a
persistent `MatchHistory`. Godot never reads that file and never copies history
into preferences; the next connection simply re-queries the source.

## UI

* Tabs `Tab_results` and `Tab_history` join the existing HFlow tab row; the
  existing `Equip_<unlockId>` catalog actions and GEAR/MODS/FINISHES/RETICLES
  selectors are unchanged.
* `CareerBack` (44 px, `BACK (Esc)`) stays above the reader so it is reachable
  without scrolling at 760×520 @ 150 %.
* `HistoryRefresh` re-requests the source list.
* The reader shows *Round complete* with source mode/map/ending/elapsed and own
  frags/deaths when the seated actor is present in the accepted state. It does
  not compute a win/loss. A missing own actor (spectator) is shown as unknown,
  and a missing award is shown as unknown — never as `+0 XP`.

No token, profile id, full snapshot or RECONNECT private state is serialized
into the result/history projections.

## Verification (engine/server slot)

```sh
node --test port/native-career/results-history.test.mjs
node --test port/native-career/catalog.test.mjs
node --test port/native-career/wire.test.mjs
node --test port/native-career/equip-lifecycle.test.mjs
godot --headless --path godot --script res://tests/career/projection.gd
godot --headless --path godot --script res://tests/career/actions.gd
godot --headless --path godot --script res://tests/career/modal.gd
godot --headless --path godot --script res://tests/career/results.gd
godot --headless --path godot --script res://tests/career/history.gd
godot --headless --path godot --script res://tests/career/results_history_ui.gd
node port/native-career/results-history-journey.mjs   # pinned GODOT_BIN; owns its Xvfb
```

The real journey hosts one native session on an owned authority, plays a legal
short match (`timeLimit: 60`), captures RESULTS then HISTORY, and asserts the
authority's real award-before-results wire order, the attributed same-round
award, the ready `Recent server matches` list, the exact compact 760×520 @150 %
layout and the absence of any ownership token. Evidence (including the first
failing attempt, kept as-is) is under `port/native-career/evidence/`.

`res://tests/career/results_history_observer.gd` sets `current_scene` to the
instantiated session so `LocalSettings` reads the correct scene context.

## Limitations

* The native reader does not compute win/loss or role/team outcome; it shows
  *Round complete* and the source's own ending reason.
* The journey harness pins `GODOT_BIN` and requires the parent's
  `client.career_receive` routing of `start`/`results`/`history`/`history-error`
  (Sol's reconnect lane) at runtime; this lane's branch does not carry those
  net/session edits.
* `history` replies from an external server are read only; this lane owns no
  store and the parent owns the owned-server `historyPath`.
