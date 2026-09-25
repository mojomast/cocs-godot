# REQ catalogue — field-equipment hydration (Sentry)

Base `ff72b43e`. Branch `port/lattice-hydrate-field-flash`. Scope: launch the one
*field equipment / fortification* row from the native `REQ` catalogue that has a
real, deterministic simulation seam already shipped in this worktree. Companion
to `REQ.md` (Spot Drone / Repair Tool) and `CAREER.md`; no commander row, no
`FLUX`/`RESERVE` crossing, no new currency.

## Decision: which field row is supportable

| id | category | seam in this worktree | verdict |
| --- | --- | --- | --- |
| `sentry` | fortification | Core deployable turret: `Match.deploySentry`, `stepDeployables`, `damageDeployable`, `repairDeployables`, the `SENTRY` stat table in `game/core.mjs`, and the rendered/serialized `deployables` list. Real health, targeting, damage, expiry and enemy counterplay. | **launched** |
| `at-mine` | equipment | None. There is no mine entity, no proximity trigger and no mine damage model. Shipping one would require new collision/proximity mechanics. | left unlaunched |
| `barrier` | fortification | None. There is no placement geometry, collision volume or nav/deployable barrier. Shipping one would require new collision/nav behaviour. | left unlaunched |

`at-mine`/`barrier` are explicitly out of scope per the lane constraint "no
collision/nav/ray changes without authoritative source mechanics". A visual-only
mine or barrier would violate the §6A.5 truth rule, so both stay `launch:false`,
`modes:[]` and are refused `not-launched` before any debit.

## What changed

`game/cocs-economy.mjs` (`REQ_ITEMS`, `reqPurchaseOptions`) now launches the
existing `sentry` row in both wire modes (`cocs` PvPvE and `cocs-coop`
OPERATIONS):

| id | name | cost | effect descriptor | shipped sim effect |
| --- | --- | --- | --- | --- |
| `sentry` | Sentry | 60 | `{kind:'sentry', duration:30, target:'ground', limit:1}` | Deploys the **shipped core deployable turret** at the buyer's feet for a bounded window, reusing `Match.deploySentry`/`stepDeployables`. The turret has the shipped `SENTRY` stats (80 health, 22 m range, 9 damage, 0.5 s cadence), fires on the nearest visible enemy, can be destroyed by enemy fire and repaired by the owner/allies. |

The row is `launch:true`, `personalBuff:false`, and never occupies the
one-active-buff slot. The turret's health/range/damage/cadence are **not**
re-authored: `game/cocs-economy.mjs` only authors the bounded rent window and the
one-live-per-operator bound, so the REQ turret is stat-identical to the economy
pickup turret (`game/cocs-req-field-hydration.test.mjs` proves this by comparing
against a pickup-deployed reference).

The `REQ` firewall is unchanged: a purchase moves only the buyer's `actor.req` /
`actor.reqSpent` / `actor.reqBuff`, the `match.deployables` slice, and the
shared `cocs-buy`/`deployable` event feed. It never touches team `FLUX`,
`RESERVE`, respawns, or the other team's intel.

## Bounded deployment, idempotency and no paid no-op

* **Legal target.** The sentry is placed at the buyer's feet, so the "target" is
  the buyer's own position. The one illegal point is a downed or *mounted*
  operator (a turret dropped from inside a hull would ride the vehicle), which
  is refused `no-target`.
* **One live turret per operator (`limit:1`).** A re-buy does **not** refuse and
  does **not** stack: it refreshes the live turret's life to the authored window
  (`Math.max(live.life, duration)`), mirroring the shipped HORDE `sentry`
  upgrade. This keeps the buy useful and idempotent.
* **Why refresh, not refuse.** The pure picker (`reqPurchaseOptions`) cannot see
  `match.deployables`, so refusing on a live turret would make the offered row
  disagree with the accepted one. Refresh keeps offered/accepted honest while
  still bounding the world to one turret.
* **Bounded effect.** The turret expires at the end of the authored 30 s window
  (or earlier under enemy fire/repaired damage), so a purchase cannot leave an
  unbounded entity behind.
* **Refund on a lost apply.** Every buy path validates before the debit and the
  applier re-checks; if the world changes between precheck and apply the full
  cost is refunded and `reqBuff` restored, so a wire frame can never charge for
  an empty effect.

## The shared gate (offered == accepted == world)

`sentryDeployment(actor, deployables, effect)` in `cocs-economy.mjs` is the one
pure selector, shared by:

* the picker `reqPurchaseOptions` (mounted/downed → `disabledReason:'no-target'`);
* `server/room.mjs` `Room.buy` (refuses before queueing, so a card cannot hang);
* `game/cocs.mjs` `cocsBuyAction` and `game/cocs-coop.mjs` `coopBuyAction`
  (re-check at apply time and refund without mutation if the deploy seam fails).

`applySentry(match, state, actor, effect)` in `game/cocs.mjs` is the one mutating
seam; `cocs-coop.mjs` imports it so PvP and OPERATIONS run byte-identical logic.

## Mode correctness and private intel

* Sentry works in `cocs` (PvPvE) and `cocs-coop` (OPERATIONS): `Match.step`
  runs `stepDeployables` unconditionally, and the turret's team comes from the
  finite `actor.team` both modes assign.
* The turret is a **physical world object**, so it rides the existing top-level
  `deployables` snapshot list (unfiltered, like vehicles) and is equally visible
  to both teams — world truth, not private intel. The per-team `cocs-sentry`
  event is buyer-team-scoped like the other `cocs-*` purchase events; the
  authoritative debit/confirmation still rides `cocs-buy`, the PvP `reqSpent`
  delta or the OPERATIONS `buyLog`.

## Pinned-source deviations (provenance)

The pinned spec (`COCS-MODE-SPEC.md` §6A.5) is referenced by the shipped code but
is **not vendored in this worktree**, so it could not be read as unchanged
authority. This lane therefore records a **new derivative**, chosen from a seam
that already exists and is already tested:

1. **The 30 s window and the one-live-per-operator bound are authored here.**
   The pinned spec's Sentry numbers are unknown in this checkout; 30 s is a
   deliberate deviation sitting on the catalogue row for a later wave to
   reconcile against the spec.
2. **No new turret entity or AI.** The REQ Sentry is the shipped core deployable
   reused verbatim; the effect adds no actor, no pathing, no RNG and no
   collision/nav/ray change.
3. **`at-mine` and `barrier` remain deferred.** Their mechanics are not authored
   in this slice; buying them would be a visual-only or no-op claim.
4. **The initial field lane did not update the native mirror.** The subsequent
   integration generated its nine-row mirror from the launched source catalogue;
   `sentry` now appears in the native request picker.

## Tests

Focused, deterministic, no RNG/clock (run from this worktree):

```bash
node --test --test-timeout=180000 game/cocs-req-field-hydration.test.mjs
node --test --test-timeout=180000 game/cocs-economy.test.mjs game/cocs-req-effects.test.mjs
node --test --test-timeout=180000 game/cocs-economy-wiring.test.mjs game/cocs-spend-surface.test.mjs game/cocs-pvp.test.mjs game/cocs-ops-depth.test.mjs game/cocs-coop-o1b.test.mjs
node --test --test-timeout=180000 game/cocs-intel.test.mjs
node --test --test-timeout=180000 --test-name-pattern="the room gates coopLaunch|the room target-gates field equipment" server/cocs-net.test.mjs
# tests/req-purchase-ui.test.mjs is updated for the new offer list but NOT run
# here (React SSR; parent render lane owns it).
```

`game/cocs-req-field-hydration.test.mjs` drives the real `Match.step` buy path in
both modes and asserts the exact debit, the deployed turret's provenance against
a pickup-deployed reference, refresh-not-stack idempotency, a real fire/expiry/
destroy cycle, the mounted `no-target` refusal, the refund-on-lost-apply path,
and that `at-mine`/`barrier` stay unlaunched. `server/cocs-net.test.mjs` covers
the room gate (accepted sentry queued once and settled; mounted operator refused
before any queue or debit). `game/cocs-req-effects.test.mjs` and
`game/cocs-economy.test.mjs` had their exact-offer / launch-set / unsupported-row
expectations updated to match the newly launched row.

## Integration resolution

The native exporter now mirrors `sentry` and `recon-pulse` from the source
catalogue; the Godot parity contract passes 197 checks. The commander lane's
adjacent purchase changes were reconciled. A full-window Sentry re-buy now
refuses `no-target` without charging rather than selling a no-op refresh.
