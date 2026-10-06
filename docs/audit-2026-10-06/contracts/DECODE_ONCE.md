# Contract: decode-once protocol path (W1, F03)

**Owner of the base hook:** orchestrator (`godot/net/client.gd`). **Worker scope:**
`godot/campaign/client.gd`, `godot/native_arenas/client.gd`, and their focused
tests. The base hook is already committed; do not reshape it without an
orchestrator-approved contract change.

## Interface (frozen 2026-10-06)

- `net/client.gd decode_text(text: String) -> bool` owns: bounded size check,
  **one** `JSON.parse_string`, then `deliver_frame(frame)`.
- `net/client.gd deliver_frame(frame: Dictionary) -> bool` owns the JSON envelope
  checks and the base dispatch/state machine (welcome, lobby, start,
  snapshot/results, events, history, rooms, chat, error).
- A subclass keeps `decode_text` **only** for a pre-parse size check whose
  rejection message must stay identical (campaign: `"Oversized campaign frame"`),
  then calls `super.decode_text(text)`.
- A subclass overrides `deliver_frame(frame)` for its protocol checks and ends
  with `return super.deliver_frame(frame)`. Subclasses must not parse text.

## Ordering that must not change

`campaign size → native size → base size → one parse → campaign frame checks →
native frame checks → base envelope checks → base dispatch`.

Every rejection uses the same `fail(message)` string as before. Every state
mutation (input epoch, `input_status`, `campaign_phase`, `expected_next`,
`action_pending`, `last_start_epoch`, `pending_snapshot` clearing) happens exactly
once per accepted frame, in the same order relative to base dispatch.

## Explicitly preserved

- Epoch monotonicity and reset semantics; input acknowledgement retirement
  (`appliedSeq` / `cancelledThrough`), outstanding-input bounds.
- Event deduplication/order (`seen_events`, `event_order`) and the 4096 cursor.
- Campaign snapshot coalescing (`deliver_snapshot` + `pending_snapshot`) and
  `draining_snapshots` — unchanged.
- `round_finished` latches, results emission counts, reconnect/identity paths.
- `fail()` semantics (error surface + connection teardown).
- Out of scope: `godot/horde/client.gd`, `godot/lattice/transport.gd` (they may
  keep their text path; must not regress), `valid_envelope` contents.

## Required evidence

- `res://tests/campaign/client.gd` and every existing test that preloads
  `native_arenas/client.gd` or exercises protocol frames pass unchanged.
- A deterministic guard proving one parse: e.g. a GDScript test reading the three
  files and asserting `JSON.parse_string` appears exactly once across the chain,
  in `net/client.gd`. (Orchestrator registers a new gate name for it on merge.)
- Negative cases: oversized campaign frame message, malformed JSON envelope,
  unknown message type, regressed epoch, duplicate/reordered snapshot, duplicate
  event, same-batch lifecycle + events, reconnect.
- No behavior claim beyond structural evidence without a measurement. Do not
  claim frame-rate benefit; a parse-count/CPU note is acceptable.
