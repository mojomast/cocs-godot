# REQ catalogue — field equipment slice

Base `a8727e13`. Branch `port/lattice-catalog-req-flash`. Scope: hydrate the
personal REQUISITION (`REQ`) catalogue with rows that already have a real,
deterministic simulation seam in this worktree. No new currency, no FLUX/RESERVE
crossing, no launch flag without a shipped effect.

## What changed

`game/cocs-economy.mjs` (`REQ_ITEMS`, `reqPurchaseOptions`) now launches two
existing catalogue rows in both wire modes (`cocs` PvPvE and `cocs-coop`
OPERATIONS):

| id | name | cost | effect descriptor | shipped sim effect |
| --- | --- | --- | --- | --- |
| `spot-drone` | Spot Drone | 45 | `{kind:'spot', radius:20, seconds:8}` | Marks every living enemy within 20 m for 8 s in the shared `state.spots` shape, so `cocsSpotDamageScale` pays the §8.1 `+15%` team damage and `cocsTeamVisibility` lists the contact. |
| `repair-tool` | Repair Tool | 30 | `{kind:'repair-link', reach:6}` | Clears the nearest own-team cut link within `node.r + 6` m via `repairLink`, and drops any SABOTEUR window on that node. |

Both rows are `launch:true`, `personalBuff:false`, and never occupy the
one-active-buff slot. `Smoke Marker` remains `launch:false`, `modes:[]` (see
deviations below).

## Truth rule (preserved)

§6A.5/WP1.3: only rows with a concrete, shipped effect are launchable. Each new
row was given one; nothing effectful was flipped on. A row with no legal target
is refused `no-target` **before** `reqPurchase` can debit REQ:

- `server/room.mjs` `Room.buy` rejects it before queueing, so the presentation
  card cannot hang waiting for a sim refusal.
- `game/cocs.mjs` `cocsBuyAction` and `game/cocs-coop.mjs` `coopBuyAction`
  re-check at apply time and refuse with no mutation, so a wire frame can never
  charge for an empty effect.
- The pure selectors `spotDroneTargets` / `repairToolTarget` live in
  `cocs-economy.mjs` and are shared by the menu, the server gate and the sim
  appliers, so offered / accepted / world state cannot disagree.

The `REQ` firewall is unchanged: a purchase moves only the buyer's `actor.req` /
`actor.reqSpent` / `actor.reqBuff` and the world slice named above. It never
touches team `FLUX`, `RESERVE`, respawns, or the other team's intel.

## Pinned-source deviations (provenance)

The pinned spec (`COCS-MODE-SPEC.md` §6A.5) is referenced by the shipped code but
is not vendored in this worktree, so the effects below were chosen from seams
that already exist and are already tested. These are deliberate deviations, kept
on the catalogue rows for a later wave to revisit:

1. **Spot Drone has no persistent drone entity.** It is an instant team pulse
   that reuses the §8.1 SPOT mark; there is no new actor, no pathing and no RNG.
   Radius `20 m` / window `8 s` are authored in the row.
2. **Repair Tool repairs cut lattice links, not vehicles.** This slice has no
   REQ-reachable vehicle-repair seam (the Puma is a depot spawn, not a repair
   target). Restoring a cut link is the shipped `repairLink` contract.
3. **Smoke Marker stays deferred.** V1 has no fog/line-of-sight model, so a smoke
   effect would be a visual-only claim. It is left unlaunched rather than sold as
   an empty effect.

## Tests

Focused, deterministic, no RNG/clock:

```bash
node --test --test-timeout=120000 game/cocs-economy.test.mjs
node --test --test-timeout=180000 game/cocs-req-effects.test.mjs
node --test --test-timeout=120000 server/cocs-net.test.mjs
node --test --test-timeout=120000 game/cocs-pvp.test.mjs game/cocs-wire.test.mjs game/cocs-identity.test.mjs
node --test --test-timeout=180000 game/cocs-ops-depth.test.mjs game/cocs-economy-wiring.test.mjs
node --test --test-timeout=120000 tests/req-purchase-ui.test.mjs   # React SSR (parent: render lane)
```

`cocs-req-effects.test.mjs` drives the real `Match.step` buy path in both modes
and asserts the world delta, the exact debit, the §8.1 damage scale, plus the
negative cases: no-target spot, no-target repair, enemy-owned link untouched,
ally never marked. `server/cocs-net.test.mjs` covers the room gate and the
settled card.
