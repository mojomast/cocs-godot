# Second pass: source challenge settlement and VIP diagnosis

Status: **READY FOR ENGINE — source/Node checks pass; no engine invocation made.**
Worktree: `cocs-pass-two-modes-20261002`, branch `improvement/pass-two-modes`,
base `51c29dc9`. This pass does not authorize a release.

## Source authority and actual missing feature

`app/page.tsx:641` advances `game/challenges.mjs::applyMatchAll`, then passes
`bonusXp` and `challengesCompleted` into `game/progression.mjs::awardMatch`.
`server/room.mjs:1367–1373` instead calls `awardOwned` with `{win, actor, mode}`.
The ordinary network source therefore previously awarded base/prestige/achievement
XP but **no daily or weekly challenge bonus**. The native reader could not honestly
present those rewards as earned merely by calculating them locally.

`challenge-authority.mjs` composes these existing source contracts in Node:

1. Construct the unchanged source `createGameServer`.
2. Admit settlement only for an owned non-spectator actor object from a finished
   Room's exact `lastResult` snapshot. No client challenge/result/bonus verb exists.
3. Normalize the UTC day/week through source helpers; run source `applyMatchAll`.
   Team eligibility uses source `teamMode`; streak events are scoped to the
   credited source actor (the browser's single-local-player path scans its events).
4. Invoke existing `ProgressionStore.awardOwned` exactly once with the source
   bonus/count. Its sanity check, `awardMatch`, unlock/achievement calculation,
   token ownership, gear, level and history contracts remain authoritative.
5. Store namespaced `portChallenges` on the same source profile **before** its
   synchronous flush trigger. The existing atomic version-2 progression write
   persists XP and challenge state together; existing retry/revision logic stays
   responsible for disk failures. There is no second XP store or second award.
6. A WeakMap keyed by the actual source Match guards recipient settlement for
   its entire lifetime. Reconnect retains that Match; round restart constructs a
   new Match. Process restart restores counters/earned flags and never restores
   a settleable old Room. No timed eviction can re-open an active receipt.

The adapter rehydrates only its namespaced state after the ordinary source loader.
Wire profiles expose bounded source status rows as
`challenges:{version:1,daySeed,weekSeed,daily,weekly}`. Award frames additionally
carry `challengeAward:{version:1,gained,completed:[{id,label,reward}]}`. The bonus
is already included in `gained`; consumers must never add it again.

## Native feature

- `godot/career/challenges_model.gd`: read-only, bounded projections. Malformed or
  absent status remains unavailable, never fabricated zero or earned status.
- `godot/career/service.gd`: CHALLENGES tab with daily/weekly source progress and
  earned status; RESULTS shows the included bonus and completed source labels.
- Profile updates are accepted through existing same-identity/connection checks.
  Reconnect restores status from welcome but does not attribute an old award to
  the replayed result. Existing results/history/equipment code paths remain in use.
- External servers without the extension display challenge status unavailable.
- No local challenge rotation, reward arithmetic, XP persistence or native award.

## Minimal parent integration hook

The separate production hook commit changes only `tools/godot-dev/launch.mjs`,
`tools/godot-package/run.mjs`, and the explicit runtime adapter closure in
`tools/godot-package/discover.mjs`.
The follow-up fixture commit adjusts only the synthetic menu/lobby authority
entry paths and records their process-boundary regression results.

The default **ordinary owned source authority** factory becomes
`port/pass-two/modes/challenge-authority.mjs::createGameServer`. This must cover
all ordinary routes sharing `owned:source-v3`, rather than only mode-expansion:
otherwise a subsequent ordinary source loader/award would discard the new
namespaced counters from the shared progression file. Existing specialized
authority factories and external endpoint ownership stay as currently routed.

Discovery adds exactly one adapter and its static source dependency closure,
with a `routes.challenges` inventory. No map catalog/registry rewrite is involved.
Parent owns combined provenance/gate registration and Linux/Windows packaging.
Package smoke/progression verification should use this new owned factory when
checking challenge behavior; a direct frozen server still has no challenge award.

## VIP: concrete source collision, not an accepted extraction

`vip-probe.mjs` reproduces the existing failure using ordinary input **only for
human actor 0**, at unmodified 1/60 source steps (accelerated wall time). It never
positions a runtime actor or changes the extraction target.

At source time 90 seconds, the diagnostic copy of the VIP shows:

| Stage | X | Z | Y / floor |
|---|---:|---:|---:|
| Snapshot after objective update | -32.35333499 | -18.49119141 | 0 |
| Ordinary `moveActor(copy,{})` | -32.420001 | -18.49119141 | 0 |
| Next direct extraction step | -32.35333499 | -18.49089486 | floor 0 |

The collision is the authored bulkhead `{x:-30,z:-22,w:4,d:56,h:7.4}`.
`game/core.mjs:220–227` ejects an embedded actor to the nearest clear side.
`game/objectives.mjs:50–59` then moves the VIP directly toward `(78,-18)`, only
checking floor support. Its seven-unit human proximity test is just a movement
enable; it does not steer the VIP along the human route or source navigation.
The VIP re-enters the bulkhead by 4/60 units on every enabled tick, then is
ejected again. The Z coordinate tends toward the beacon while X remains blocked.

Consequently, changing a follow-controller waypoint cannot by itself route this
VIP around the wall. A future ordinary-input success would need a separately
proved, legal source interaction that changes the VIP path. None is established
here, and no fixture supplies VIP controls, moves the beacon, changes geometry,
or patches the frozen movement/objective rule to manufacture completion.
The retained 180-second attempt ends in defender timeout with zero extraction.
This is a bounded diagnosis, not a proof that every possible combat/traversal
interaction is incapable of producing extraction.

Frozen `game/` and `server/` files and existing core/derivative approvals are
unchanged. Native VIP extraction remains **not accepted**.
