# Port debug facility (`port/native-debug`, `godot/debug`)

Off by default. Enabled only by an explicit operator switch:

* `COCS_DEBUG=1` in the environment (the launcher path: `tools/godot-dev/launch.mjs`
  and the packaged `run.mjs` both pass the inherited environment to the Godot child), or
* `--debug-panel` on the Godot command line for hand-run scenes.

It is **never available in the multi-human lobby/room path**: `server/**` does not
import, mention or branch on the debug surface, `session.gd` refuses to create the
panel when `lobby_enabled` or a guest `join_room_id` is set, and the public room
answers a `debug` frame with its existing `unknown message type: debug` error.
`port/native-debug/room-boundary.test.mjs` proves that against a real two-human room.

## One additive frame, two local authorities

`{type:'debug', v:1, ...knobs}` is handled **only** by `port/native-arenas/authority.mjs`
and `port/native-horde/authority.mjs`, and only when the authority was constructed with
`debug:true` or `COCS_DEBUG=1` is set. With the channel disabled the frame falls through
to the pre-existing rejection path (`error` + terminate) — the old contract is intact.

Validation is strict (`port/native-debug/debug.mjs`):

* unknown keys refused (`mapId`, `path`, `url`, `actor`, … are not fields at all),
* every number must be finite and inside its documented bound, every flag a real boolean,
* no map id, path, URL or free-form field exists on the frame,
* a refused frame replies `{type:'debug-reject', reason}` and changes nothing; the socket
  stays usable. Malformed **envelopes** are still fatal, exactly as before.

Replies: `lobby.debug` (capability echo) and `{type:'debug-state', debug:{...}}` after each
accepted frame. Both are additive; clients that do not know them ignore them.

## What is live, what needs a restart, what is refused

| Knob | Class | How it reaches the locked source |
| --- | --- | --- |
| `damage` 0.5/1/1.5/2 | LIVE (source) | `match.mutators` recomputed from `normalizeConfig`; `damage()` reads `mutators.damageMultiplier` per hit. **Below 1× the locked source applies no reduction to actor damage** (Damage Boost only scales upward); `config.damage` still lowers vehicle/deployable damage. The panel says so. |
| `speed` .75/1/1.25/1.5, `gravity` .4/.7/1 | LIVE (source) | `moveActor` reads `match.config.speed/gravity` every tick |
| `respawn` 1..5 s | LIVE (source) | `respawnDelay()` reads `match.config.respawn` on each death |
| `difficulty` easy/normal/hard/nightmare | LIVE (source) | `match.difficulty` is re-assigned; bots read `think/reaction/error/fireDelay` every tick. Measured: same round, easy→nightmare took bot shots in a 6 s window from ~10 to 51 and landed hits from ≤3 to ~50. |
| 14 source mutators (`oneShot`, `instagib`, `noRecoil`, `bigHead`, `berserk`, `bounty`, `lifeSteal`, `suddenDeath`, `fastPowers`, `mirrorLoadout`, `randomLoadout`, `unlimitedAmmo`, + turbo/lowGravity via speed/gravity) | LIVE (source) | `match.mutators` recomputed; spawn-time ones (`mirrorLoadout`, `randomLoadout`) apply on respawn |
| `unlockAllWeapons` | LIVE (source flag + port grant) | sets the source `unlimitedAmmo` flag and grants `Infinity` ammo to the human seat's ten slots; switching it off restores the source spawn belt. The panel's weapon selector then offers all ten (`godot/tests/debug/panel.gd`). |
| `botCount` | RESTART (source) | queued and consumed by the next authoritative `start`; the echo reports `queued` vs `constructed`. Native DM accepts the route's reviewed 1..7; the solo Horde route refuses it (its config is fixed). |
| `startingWeapon` | RESTART (source) | same queue path; applied at construction |
| `godMode` | PORT RECONCILIATION | a per-hit guard on the authority's match instance caps a lethal hit one point short of the human's full pool, and a post-step reconcile refills health. **Human seat only** (single-human authorities); bots are never inspected. Cleared at every round boundary and on switch-off. Deaths/score already resolved by the source are never rewritten. |
| `playerIncomingScale` 0.25..4 | PORT RECONCILIATION, debug-only | same guard multiplies damage that targets the human seat. Clearly labelled debug-only in the panel; the global source multiplier stays honest. |
| `testDamage` 0..100000 | DEBUG ACTION | one self-hit through the source `damage()` path; used by the panel's "Test hit" button and by the harness to measure multipliers |
| pacify/aggressive bot toggle | REFUSED | the locked source has no reviewed live bot-policy swap: `botPolicy` is a harness-only *construction* seam (`actor.bot.policy`), and inventing a port-local policy object would fake a surface the source does not define. Live bot intelligence is `difficulty` only. |
| debug in a human room | REFUSED BY DESIGN | source-locked; see the boundary test. |

Round boundary: `godMode` always clears; every other live knob is re-applied to the newly
constructed match, so a debugger's damage/difficulty survive a restart on purpose.

## Adapter closure change (report to lead)

`tools/godot-package/discover.mjs` gained exactly one reviewed adapter module:
`port/native-debug/debug.mjs` (`debugAdapters`). It is imported by both local authorities
and by nothing on the ordinary/multi-human route; `modules` (locked source) stays at 84,
`external` stays `['ws']`, and the package builder picks the new file up through
`closure.adapterModules` as it already does for the other adapters.

## Verification

* `node --test port/native-debug/debug.test.mjs` — frame validation/partitioning, live
  override rebuild-from-base, guard semantics (human only), reconcile, echo.
* `node --test port/native-arenas/tests/debug.test.mjs` — real authority: off-by-default
  rejection, env switch, live damage amounts **and real health+armor deltas at 1.0 vs 2.0**
  (10 vs 20), debug-only incoming scale, god mode (survives 3× lethal 10000 hits, deaths
  unchanged, reversible, cleared at the round boundary with a real frag-limit restart),
  queued `botCount=4` applied on restart (5 actors), unlock-all (all ten `∞`, real weapon
  switch + fire, reversible), mutator echo in the public snapshot config, live respawn,
  malformed frames change nothing, no-live-round refusal.
* `node --test port/native-horde/debug.test.mjs` — same surface on the real solo Horde
  authority (restart knobs refused, NPC seats never granted).
* `node --test port/native-debug/room-boundary.test.mjs` — real two-human room rejects the
  frame; the shipped closure keeps the debug module out of the ordinary route; no
  `server/**` file mentions the surface.
* `godot --headless --script res://tests/debug/panel.gd -- --debug-panel` — 43 client
  checks: gating, echo, keyboard control, round boundary, room/guest refusal, all ten
  selector slots.
* `GODOT_BIN=<pinned> node port/native-debug/capture.mjs` — rendered evidence at 960x640
  and 1280x800 under a private Xvfb, showing the badge, the panel and a live
  god-mode + damage 2× example (`evidence/capture-*/`).
