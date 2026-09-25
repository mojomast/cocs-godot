# L1 projection/session handoff

Status: **follow-up source repairs applied; focused engine check pending**. Base: `d23d02a56ba622defffc94c249a08af9b32350c6`; source pin: `515daf07589150dd3241f4ae1425cc1b093912f5`.

## Owned diff

- `godot/lattice/transport.gd`: recipient-only bounded dominance/outcome projection, source sequence/time/context, validated start config echo, independent final result projection, and result notification ordering. Live authority/actions clear before `result_changed`; `changed` follows. Start revision/identity/error/disconnect clear the appropriate cache.
- `godot/lattice/world_transport.gd`: validates optional dominance and Operations outcome subtrees without requiring absent/null values or adding private state.
- `godot/lattice/session_options.gd`: LATTICE allow-listed maps/modes, time/bot/rung/endpoint validation, normalized Loadout pair and normal host frame builder.
- `godot/lattice/session_flow.gd`: host/guest state/API methods, source roster host authority, start/result/restart/disconnect; all return queue/reason state, not match success.
- `godot/lattice/world_demo.gd`: explicit endpoint/options; guests wait; competitive host config waits for explicit Enter; practice path may quick-start only when no rung requested.
- `godot/tests/lattice/flagship_l1_contract.gd`: synthetic contract checks.

Reviewed follow-up: fixed `world_demo.gd` argument-loop parse break and native trace handling; LATTICE guest wait bypasses only inherited phase-11 timeout. Restart queues from results, guest selection is validated against the request, and below-minimum errors remain waiting guidance. **Connected, non-spectating lobby peers count before actors are assigned** (the source roster's pre-start `actorId` is null); floor remains sourced from `lobby.cocs.minHumans`. Current bounded roster/config survive reset-before-start, while explicit disconnect clears revision, result, config and roster. Final reason reads source `state.overReason`, not a synthetic `reason`; world HUD refresh retains waiting/results messages rather than blanking them. Synthetic assertions cover these contracts. No engine parse/runtime check has been run.

## Projection schema / source evidence

Live `projection` preserves the existing `map`, `mode`, `team`, `health`, `req`, `flux`, `spent`, `income`, `upkeep`, `nodes`, `cuts`, `roles`, `command`, `commander`, `coop`, and `recruitment` values. Additive shape:

```json
{
  "dominance": {"team": 0, "progress": 12, "target": 90, "remaining": 78,
    "fast": false, "count": 3, "fastCount": 4,
    "counts": {"0": 3, "1": 2}, "breakCount": 1, "hold": 0, "fastHold": 0},
  "outcome": {"mode": "pvp", "waves": null, "hq": null},
  "source_sequence": 34, "source_time": 57.25,
  "context": {"revision": 2, "peer": 3, "actor": 8, "team": 0}
}
```

The example is schema-shaped, not observed live evidence. Actual source contract is `game/cocs.mjs:cocsSnapshot`, which publishes `dominance: cocsDominanceView(state)` and `outcome: cocsOutcomeSnapshot(state)`. Absent values remain absent; null is retained by bounded copy. Never read the other team's wallet/intel.

`session_config` is sourced only from authoritative start `config`/map and current assigned loadout, with map, mode, rung, bot_count, human_count, time_limit, operator, harness and bounded population metadata. The additive `roster` subobject records source roster host peer, connected peers, assigned actors, spectators and total roster. It is distinct from `SessionOptions.parse()` requested values. Server may omit fields; missing fields remain null/unknown.

`result_projection` contains map/mode/revision, frame sequence, source time if sent, numeric source scores if present, source winner/reason if present, bounded dominance and mode progress. It is separate from and has no action authority. Final winner/reason are read from final state, not inferred from ACK or progress. Consumers should treat dictionaries as immutable snapshots and deep-copy if retaining.

## Signal and composition contract

Transport is constructed before `world_demo` hooks. On incoming start: base decoder validates/resets round and emits `started`; transport handler records revision/config and clears prior result; world handler then validates config and resets UI. On snapshot: base emits `snapshot`; L1 `observe` updates projection/action receipts and emits `changed`; later UI snapshot callbacks consume it. On results: base decoder marks `round_finished` and emits `results`; L1 clears projection/actions, replaces final result, emits `result_changed(result)` and then `changed`; later UI result callbacks render final state. L3 can compose through `changed`, `result_changed`, `session_flow.state_changed`, `configuration_echoed`, and `round_result` (reserved signal; callers can add their handler without replacing L1). No consumer should retain prior-round dictionaries across revision/identity changes.

Session methods `request_configuration(options, client)`, `join(client, endpoint, room, player, character, harness)`, `start(client, roster)`, `restart(client, roster)`, `disconnect(client)` return `{queued,reason,queue_state}` (disconnect is a transition). The queue result is explicitly not evidence that a match started. Host authority comes from `hostId` in source roster. Existing one WebSocket client is used; L1 creates no second socket. Guests are not offered configure/start.

## Verification and evidence class

- Inspected both flagship contract documents fully and source `cocs.mjs` snapshot/outcome methods; read only base `godot/world/session.gd`, `godot/net/client.gd`, and lane-owned files otherwise.
- Planned focused command: `godot --headless --path godot --script res://tests/lattice/flagship_l1_contract.gd` — **not run**, no engine until marker. No import, server, multi-client, full-round or package operation was run.
- Ran Python source-contract sanity checks (projection/API fields, notification ordering, bounds/allow-lists, explicit host wait, guest no-start branch, roster authority gate, protected path untouched, pinned source snapshot symbols): **8 PASS**; `git diff --check`: **PASS**. These are static source checks only, not a GDScript parse/runtime check.
- Synthetic fixture assertions are `synthetic` evidence only and do not prove natural outcome, config echo, guest behavior or rendered UX. Expanded source assertions remain unrun pending the reserved engine slot.

Blockers: L1 focused GDScript contract still needs lead's scheduled engine slot; normal-source host configuration fields/roster metadata and minimum-floor echo require live source observation. Existing base client cannot be changed, so it remains responsible for recipient frame ordering, identity reset and one-socket transport. Do not claim MVP-A/B/C1/C2 acceptance from this lane.
