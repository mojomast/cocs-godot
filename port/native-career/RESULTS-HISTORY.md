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

`career/results_model.gd:is_award` requires `gained` and rejects any equipment
shape, so a GEAR reply can never be mistaken for an accepted award.

## Wire admission and round pairing

The source sends the reward **before** the result
(`server/room.mjs`: `history.record` → per-peer `awardOwned` `progression` →
`sendResults`). `results` itself carries no `roundRevision`; `start` and `lobby`
do. The service therefore:

1. on `start`, records a round key `endpoint/room/revision`;
2. on an award `progression` from the **same** bound source identity, witnesses
   it as the active round's award;
3. on the matching `results`, exposes that award only when the round keys agree;
4. keeps an uncorrelated award as *Latest source award* — never attributed to a
   result.

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

The parent lane owns `godot/net/client.gd` and routes the admitted
`start` / `results` / `history` / non-fatal `history-error` frames to
`client.career_receive(frame)`; `welcome`/`progression` are already routed.

## History request

`service.request_history()` sends the existing `{'type':'history'}` verb through
`client.send_frame` (no network edits). It is allowed on any admitted seated
connection, including a spectator seat, because the reply is server-wide rather
than personal data. Status is one of:

| status | meaning |
|---|---|
| `offline` | Home / no seated source. No request is sent. |
| `loading` | request in flight |
| `ready` | bounded list projected (≤50 records) |
| `empty` | the source replied with zero records |
| `error` | malformed reply or non-fatal `history-error`; last known list kept |
| `timeout` | no reply within 8 s; last known list kept |

A malformed entry is counted and skipped while every valid record keeps its
known facts. A malformed top-level reply is an error, never a fabricated empty
list. Disconnect clears the list and returns to `offline`.

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
  not compute a win/loss. A missing own actor (spectator) is shown as unknown.

No token, profile id, full snapshot or RECONNECT private state is serialized
into the result/history projections.

## Verification

Static check now (this lane holds no engine slot):

```sh
node --check port/native-career/results-history.test.mjs
```

Run in the parent serial slot:

```sh
node --test port/native-career/results-history.test.mjs
godot --headless --path godot --script res://tests/career/results.gd
godot --headless --path godot --script res://tests/career/history.gd
godot --headless --path godot --script res://tests/career/results_history_ui.gd
```

Native UI journey (owned authority + real session, run from an integrated
checkout with a pinned `GODOT_BIN`):

```sh
node port/native-career/results-history-journey.mjs
```

## Limitations

* The native reader does not compute win/loss or role/team outcome; it shows
  *Round complete* and the source's own ending reason.
* The journey harness is prepared but unrun in this lane (no engine slot). It
  uses a legal short config (`timeLimit: 60`); the controlled fixture label and
  the match-resolution step are explicit there.
* `history` replies from an external server are read only; this lane owns no
  store and the parent owns the owned-server `historyPath`.
