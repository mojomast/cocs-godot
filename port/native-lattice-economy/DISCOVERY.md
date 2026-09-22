# Source findings: recipient-authorized co-op recruitment

Base: `c982d25ca335da3983df48ea37f7602bf8ded1f2`. Locked source:
`51289b79c627a26a381ba556b92bab71f93f3732`. No source changes are needed for
this narrow purchase. The gameplay, server, contracts and dependency tree are
read-only in this lane.

## Legal request and actual price

`game/protocol.mjs:64–65,127–145` explicitly accepts both `spawn` and
`reinforce` as economy actions. `server/room.mjs:520–580` maps the co-op
action to the REINFORCE sink. The native co-op request is:

```json
{"type":"economy","action":"reinforce","role":"fighter","cardId":"native-r1-p1-s2","roundRev":1,"actionSeq":2}
```

The room resolves the ordinary peer's actor. The client supplies no privileged
actor identity, funds, units, execution tick, or command-seat override.

| Mode | Native action | Source price | Additional budgets/permissions |
|---|---|---|---|
| `cocs` | PvP Fighter / `spawn` | 12 team FLUX | Role allow-list, free team thread |
| `cocs-coop` | Co-op REINFORCE / `reinforce` | **50 team FLUX, no REQ charge** | Open intermission, own human membership, own rotating executor, slice **allowance** ≥50, free thread, available squad slot |

`game/cocs-difficulty.mjs:195–198` defines REINFORCE as `cost:50`,
`squad:1`, `threads:1`, `squadCap:2`. `game/cocs-coop.mjs:532–565`
calls `spawnCoopSquad(role)`, increments thread bonus, debits pooled FLUX,
increments cumulative FLUX spent and writes the correlated spend log.
`game/cocs-coop.mjs:675–713` creates/reuses one source bot and increments
`subagentStats.spawned`. The default role is Fighter; this lane explicitly
requests it. The PvP Fighter's `spawnCost:12` is **not** its co-op price.

There is no legitimate dual REQ+FLUX recruitment price in this path. REQ is
a separate personal `buy` economy (`game/cocs-economy.mjs:203–240`), and
RESUPPLY's `req:24` is a grant, not a recruitment debit. Native tests therefore
check FLUX, slice, thread and squad constraints independently, and prove that
zero/hidden REQ does not disable this FLUX-only action. They do not invent a
second currency cost to satisfy a hypothetical multi-currency model.

## Authority and readiness

- `game/cocs-coop.mjs:431–432`: `phase == intermission` **and**
  `intermissionOpen === true`. The initial pre-wave deploy phase is closed.
- `game/cocs-coop.mjs:303–346,391–403`: the live command snapshot carries
  numeric human actor IDs, executor, lease epoch, threads and slices. REINFORCE
  is a big sink. The server checks `allowance`, not the historical `remaining`
  display; a player with remaining zero can legally purchase if the current
  allowance covers the cost. Native follows that distinction.
- `server/room.mjs:564–579` rechecks window, pool, threads and spend gate at
  submission. `coopSpend` rechecks its own window, pool and slice/lease gates
  when applying the queued action. A snapshot is permission evidence, not a
  guarantee that later server validation will succeed.
- `game/cocs-coop.mjs:1994–2015`: `director.intermission.sinks` supplies the
  actual REINFORCE cost and availability/affordability/enabled booleans.
  The native client requires that source price to equal its pinned 50-FLUX
  label, and refuses an unknown or changed price.
- `game/cocs-coop.mjs:1097–1105`: source automatic spending is a no-human
  fallback. This lane uses an ordinary living human actor and never enables
  the validator-only force override. Other ordinary source spending (such as
  scout orders) can still contribute to the cumulative spend before purchase.

## What the recipient actually receives

- `game/cocs.mjs:1907–1910,1949–1955`: team-keyed `flux`, `fluxSpent`,
  `fluxIncome`, `fluxUpkeep`, and `req:[{id,req,earned,spent}]`.
  An actor's raw `req` may be absent before first earning/spending; the public
  recipient-filtered `cocs.req` entry is the source's normalized wallet. Native
  selects **only its exact actor ID**, falling back to that same actor's raw
  `req` only if the array lacks an entry. Neither source present means unknown.
- `game/cocs-coop.mjs:2050–2062,2180–2217`: intermission sink view,
  recipient command state and co-op `roles.spawned`. Co-op has no PvP
  `roleBoard`. Native copies only the needed sink booleans/cost, phase/wave,
  window flag and public spawn counter into its new recruitment projection;
  it does not reconstruct units or use actor positions.
- `game/cocs-intel.mjs:125–162`: enemy wallet keys are removed, REQ arrays
  and slices are team-filtered, command is team-0 scoped, and cards are
  team-filtered. Native additionally correlates receipts to its own peer/actor.
- JSON numeric values decode as floats in Godot. Actor/executor comparisons
  use validated numeric equality, not `str(0.0)` versus `str(0)`.

## Receipt semantics and source limits

`server/room.mjs:235–277` binds round/seat/sequence to a payload. Identical
retries are idempotent and reuse with another payload is rejected. Native
sends once per explicit authorization and blocks unresolved queued/accepted
purchases beyond the short click cooldown; it never retries automatically.

`server/room.mjs:298–317,358–374` settles economy cards against the source
spend log, matching card and actor. Native shows queued, pending (server
accepted), confirmed (`done/ok=true`), or rejected. Movement ACKs do not settle
purchases. Missing receipts remain unresolved. Rejections retain their raw
reason for evidence and use friendly UI explanations for window, executor,
slice, funds, threads, expiration and round changes.

**Confirmed means the source's successful spend receipt**, not a client-made
unit simulation. The source squad-cap helper can return no new squad when full;
the sink's `available` flag exposes that condition, so native disables the
purchase preemptively. Source completion is based on the spend log, not an
action-keyed spawned-actor record. These live single-recipient cases additionally
require source `fluxSpent +50` and `roles.spawned +1` at the matching done
receipt. They do not claim strict per-action unit attribution under concurrent
multi-client races. A stronger per-action effect receipt is a source follow-up,
outside this native lane.

## Natural live path

The ordinary board's configured solo room, its source bot fill, normal ticks,
normal initial budget (120 FLUX), and normal passive income are sufficient.
The first observed window opened after about 129 seconds. No funds, wave state,
health, units, clocks or navigation were injected. The source can withdraw a
stalled non-boss remnant after its normal overrun (`stepWave`, lines 1767–1787);
the harness simply waits for the recipient's real open-window flag.

HOLD is still initially accepted/running. Its normal TTL may expire while
waiting for recruitment; that is shown as rejected/expired, not falsely
reported as an objective capture or order completion.
