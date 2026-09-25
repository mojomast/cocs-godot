# Commander / team REQ slice — Recon Pulse

Base `ff72b43e`, branch `port/lattice-hydrate-commander-flash`. Scope: hydrate
the commander/team REQUISITION rows that already have a real, deterministic
simulation seam. This is a **new derivative** of the source catalogue, not a
byte-for-byte reproduction of the pinned preview: the `recon-pulse` row moves
from `launch:false`/`modes:[]` to a shipped effect. No currency was added and no
`FLUX`/`RESERVE` crossing was introduced.

## What changed

`game/cocs-economy.mjs` now launches one existing commander/team row in both
wire modes (`cocs` PvPvE and `cocs-coop` OPERATIONS):

| id | name | cost | effect descriptor | shipped sim effect |
| --- | --- | --- | --- | --- |
| `recon-pulse` | Recon Pulse | 60 | `{kind:'recon-pulse', seconds:5, target:'enemies'}` | Reveals every living, uncloaked enemy to the buyer's team for 5 s as team-private information: a `fieldSupport.intel[team]` entry plus an `intelOnly` SPOT mark, the exact shape the shipped §8.1 `recon` field hook writes and `cocsTeamVisibility` reads. No damage bonus. |

`supply-drop`, `fortify-doctrine` and every other effectless row stay
`launch:false`, `modes:[]` and are refused `not-launched` before any `REQ`
moves. `recon-pulse` is `teamWide:true`, `commanderOnly:true`,
`personalBuff:false` and never occupies the one-active-buff slot.

## Truth rule (preserved)

§6A.5/WP1.3: only rows with a concrete, shipped effect are launchable. A row
with no legal target is refused `no-target` **before** `reqPurchase` can debit
`REQ`:

- `server/room.mjs` `Room.buy` rejects it before queueing, so the presentation
  card cannot hang waiting for a sim refusal.
- `game/cocs.mjs` `cocsBuyAction` and `game/cocs-coop.mjs` `coopBuyAction`
  re-check at apply time and refuse with no mutation, so a wire frame can never
  charge for an empty effect. The applier refunds in full and restores the buff
  slot if the world changes between the precheck and the debit.
- The pure selector `reconPulseTargets` lives in `cocs-economy.mjs` and is
  shared by the menu, the server gate and both sim appliers, so offered /
  accepted / world state cannot disagree.

The commander seat is the real `peerId` mapping (`String(actor.id)`) in both
modes: PvP reads `state.command.seat[team]`, OPERATIONS reads
`state.coop.commandSeat[team]`, and `Room.buy` gates on the same in-sim id. A
non-seated or seat-stolen buy is refused `commander-only`.

The `REQ` firewall is unchanged: a purchase moves only the buyer's `actor.req` /
`actor.reqSpent` / `actor.reqBuff` and the world slice named above. It never
touches team `FLUX`, `RESERVE`, respawns, or the other team's intel.

## Private team information

The pulse is information only and team-private:

- `fieldSupport.intel` is a `team-map` and `spots` is a `team-array` in
  `game/cocs-intel.mjs`, so `filterCocsSnapshot` removes the buyer's mark from
  every other recipient's wire snapshot.
- `cocsSpotDamageScale` returns `1` for an `intelOnly` mark, so recon pays no
  §8.1 `+15%` bonus (a real SCAN/SPOT is never downgraded and a longer live
  window is never shortened).
- The `cocs-recon-pulse` sim event is team-tagged and not on the public
  `COCS_PUBLIC_EVENTS` allow-list, so it is private to the buyer's team.
- Cloak is counterplay: a cloaked enemy is never revealed, matching the shipped
  `recon` hook.

## Tests

Focused, deterministic, no RNG/clock:

```bash
node --test --test-timeout=120000 game/cocs-req-commander-hydration.test.mjs
node --test --test-timeout=180000 game/cocs-economy.test.mjs game/cocs-req-effects.test.mjs
node --test --test-timeout=180000 server/cocs-net.test.mjs
node --test --test-timeout=120000 game/cocs-pvp.test.mjs game/cocs-wire.test.mjs game/cocs-identity.test.mjs
node --test --test-timeout=180000 game/cocs-coop.test.mjs game/cocs-coop-waves.test.mjs game/cocs-coop-o1b.test.mjs game/cocs-coop-o1c.test.mjs
```

`game/cocs-req-commander-hydration.test.mjs` (new) drives the real
`Match.step` buy path and the real `Room.buy` gate in both modes and asserts:
the exact `60 REQ` debit, the team-private `fieldSupport.intel` + `intelOnly`
mark, the absence of a damage bonus, buyer-team-only visibility through
`cocsTeamVisibility` and `filterCocsSnapshot`, and the negative cases —
unauthorized seat, seat stolen by a same-team actor, all-enemies-cloaked and
all-enemies-dead (each `no-target`), all with no debit and no pulse state. A
deterministic twin match without the buy proves the purchase moves no `FLUX` /
`RESERVE` and no other actor's wallet.

`game/cocs-economy.test.mjs` and `game/cocs-req-effects.test.mjs` were updated
to their new exact launch/offer sets; `tests/req-purchase-ui.test.mjs` had its
two exact offer arrays updated. That React SSR test is owned by the parent
render lane and could not be run in this worktree (no `node_modules`).

## Pinned-source deviations (provenance)

The pinned spec (`COCS-MODE-SPEC.md` §6A.5) is referenced by the shipped code
but is not vendored in this worktree, so the 5 s window and the map-wide (no
radius) sweep are authored here from the seam that already exists. This is a
deliberate derivative, kept on the catalogue row for a later wave to revisit:

1. **Recon Pulse is an instant map-wide team pulse**, not a projectile or a
   persistent drone. It reuses the §8.1 recon contact model and adds no actor,
   pathing or RNG.
2. **Recon is information only.** It deliberately does not pay the §8.1 `+15%`
   SPOT damage bonus, so it is not a cheaper Spot Drone for the whole team.
3. **The native mirror lags.** `godot/lattice/req_catalog.gd` and
   `godot/tests/lattice/req_catalog_contract.gd` still treat `recon-pulse` as
   unlaunched; the native catalog contract will report drift until a native REQ
   wave adds the row. No native/Godot file was touched by this lane, so no
   native BUY witness is claimed.

## Known limitations

- Only `recon-pulse` shipped. `supply-drop` (an actual ammo transfer) and
  `fortify-doctrine` remain deferred and unlaunched.
- No live native or rendered purchase was observed here; the effect is proven
  through the real Node sim/room paths only.
