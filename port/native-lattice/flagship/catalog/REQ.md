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

## Addendum — native client REQ picker (lane `port/lattice-native-req-catalog-flash`)

Base `0dfe7c22`. Scope is the Godot client only: `godot/lattice/*.gd` plus new
native contracts in `godot/tests/lattice/`. No `game/`, `server/`, source lock,
app or Moth asset changes. This lane hydrates the *native* personal REQ surface
that previously only displayed `own REQ` in `world_commands.gd` and could not
send a BUY.

### What was added

| file | role |
| --- | --- |
| `godot/lattice/req_catalog.gd` (new) | Immutable, hardcoded mirror of the launched `REQ_ITEMS` rows (7): `field-repair`, `ammo-crate`, `haste`, `overshield`, `spot-drone`, `repair-tool`, `puma`. Pure option/gate helpers; no I/O, clock or RNG. |
| `godot/lattice/transport.gd` | Projects recipient-observed `reqBuff` and traversal `depots` (id/owner only); adds `req_options()`, `req_context()`, `req_gate(item, depot)` and an ordinary `activate("buy", item, depot)` that emits `{type:"buy", itemId, depotId?, cardId, roundRev, actionSeq}`. REQ rejection copy added. |
| `godot/lattice/world_commands.gd` | Personal REQ picker (list, cost, `effectCopy`, per-row disabled reason), separate explicit consent, queued/accepted/settled/refused notice, and `RECEIPTS` settlement for `buy` cards. |
| `godot/lattice/world_transport.gd` | Bounded shape validation for the new optional `traversal.depots` list and `actor.reqBuff`; absence stays allowed/unknown. |
| `godot/tests/lattice/req_catalog_contract.gd` (new) | Reads the tracked `game/cocs-economy.mjs` `REQ_ITEMS` block and fails on `id`/`name`/`cost`/`effectCopy`/`modes`/`personalBuff`/launch drift; asserts unlaunched and reserved ids are absent. Also pure gate checks. |
| `godot/tests/lattice/req_purchase_contract.gd` (new) | Synthetic recipient wire + GUI lifecycle: exact BUY frame, pending vs confirmed vs rejected, unknown/insufficient REQ, buff slot, depot gate, and reserved-action refusal. |

### Contracts preserved

* **Mirror, not authority.** The native side never decides a purchase; it only
  decides what it may *ask*. Mode, depot ownership, REQ balance, buff slot and
  life are read from the recipient-observed projection, and every row is gated
  again by `Room.buy` / `reqPurchase` on the server.
* **Finite and launched only.** The table is exactly the 7 source rows with a
  shipped effect. `at-mine`, `smoke`, `barrier`, `sentry`, `forward-depot`,
  `supply-drop`, `recon-pulse`, `fortify-doctrine`, `tier-upgrade`,
  `oracle-unlock` and reserved `FLUX` ids (`respawn`, `reserve`, `flux`) cannot
  be selected and are refused before any frame is sent.
* **No fabricated acceptance.** A queued BUY is `queued`; only the authoritative
  `cards` row turns it `pending (server accepted)`, `confirmed` (server settle
  evidence: co-op `buyLog` or the PvP `reqBuff`+`reqSpent` debit) or `rejected`.
  The UI shows the server-owned result and the live `own REQ`, never a click
  success or a local debit.
* **Unknown stays unknown.** A missing `req` renders `req-unknown`/disabled
  instead of an inferred zero; a missing depot list renders `depot-unknown`
  instead of "no depot"; a malformed row is dropped rather than coerced.
* **One request per intent.** `req_gate` refuses a second frame while an
  unresolved BUY for the same item is queued/pending (`roundRev`/`actionSeq`/
  `cardId` are bounded and idempotent server-side).

### Native tests (parent runs serial; not run in this lane)

```bash
"$GODOT" --headless --path godot --script res://tests/lattice/req_catalog_contract.gd
"$GODOT" --headless --path godot --script res://tests/lattice/req_purchase_contract.gd
# regression: the touched transport/commands paths
"$GODOT" --headless --path godot --script res://tests/lattice/economy.gd
"$GODOT" --headless --path godot --script res://tests/lattice/world_commands_contract.gd
```

`req_catalog_contract.gd` reads the source table by absolute path derived from
`res://`, so it must run from this repo checkout (the parent's normal lane
context); it fails loudly if the file is missing or drifted.

### Known deviations / remaining work

* **Depot choice is implicit.** The OPERATIONS Puma uses the first
  recipient-observed owned depot (deterministic wire order) rather than a
  per-depot picker; the frame carries that observed `depotId`.
* **Target validation is server-side.** `spot-drone`/`repair-tool` can still be
  refused `no-target` by the authority; the client does not model cut/enemy
  geometry and shows the refusal rather than pre-claiming a hit.
* **Not run here.** No Godot import/render/build or live two-client run was
  executed in this lane; the parent runs the serial suite and any live probe.
