# LATTICE Strike — flagship implementation specification

Status: **design contract; L1–L5 implementation integrated, acceptance incomplete**. Prepared
2026-09-25 on `port/godot-destinations`, against selected source
`515daf07589150dd3241f4ae1425cc1b093912f5` in
`port/contracts/source-lock.json`. Execute with [FLAGSHIP_PLAN.md](FLAGSHIP_PLAN.md).
The six completed research lanes supplied to this synthesis cover rules, maps,
roles, native/session gaps, external precedents, and implementation seams.
This document grounds their findings in the current checkout; it is not new
playtest evidence. Existing acceptance reports often refer to an older pin.

## 1. Product promise and scope

**Take legal ground, keep income connected, and make the next team push possible.**
The first-person world should explain which action matters now, let the player
perform it through ordinary source inputs, and show its actual strategic result.
The command board explains where and why; combat, routes, pickups and teammates
supply the means. Commands remain optional aids to field play.

Phase 1 is a native presentation/session completion at the pinned rules:

- Both authored maps: `asterion-relay` and `monsoon-foundry`.
- `cocs` practice, explicit competitive rung configuration where the server
  permits it, and distinct five-wave `cocs-coop` Operations.
- Legal-frontier world guidance, source outcome display, role/loadout teaching,
  existing command outcomes, useful session setup, host/guest flow, results/restart.
- Recipient-only data, existing combat/input authority, and recorded natural rounds.

Eight-versus-eight is the long-term competitive showcase; practice is the first
honest playable milestone. No source topology, economy, timing, kit, pickup,
capture or bot-rule change is authorized by this specification. Later proposals
require an upstream revision and a separately approved source-pin advancement.

## 2. Fact ledger and corrections to the vision

These are code observations, not measured match-quality claims.

| Topic | Pinned-source fact and implementation consequence | Grounding |
| --- | --- | --- |
| Capture | A live non-HQ target needs an owned adjacent node. A connected path to HQ is **not** required for capture. Ownership, adjacency, live status and supply are separate facts. | `game/cocs.mjs`, `capturableBy`, `connectedToHq` |
| Orders | HOLD/ATTACK tasks last 2s. A valid active order can advance an empty point without friendly actors when no enemy actor is present. Base capture is 5s; progress does not decay merely because engagement stops. Reissuing before expiry can complete a remote capture; gaps can also preserve partial progress. Only actual actors supply physical participation and kit bonuses. | `ORDER_TTL_SECONDS`, `processCocsOrder`, `captureNodeStep` |
| Dominance | Five capturable nodes; 3 owned gives majority, 4 gives the fast target. 4v4 uses 90/45s, 8v8 120/60s. Ownership loss below majority resets; contest alone does not. A holder of 4 nodes needs two losses to fall below 3. Read source `breakCount`, never promise one retake always resets the clock. | `game/config.mjs:16–30`; `cocsDominanceView` |
| End conditions | These maps have no ARRAY node. PvP resolves sustained dominance or the deadline, then score, then owned-node count, with a possible draw. Operations has its own five-wave/HQ outcome. | `game/destination-lattice-maps.mjs`; `cocsOutcome`, `cocsOutcomeSnapshot` |
| Duration | Normalization clamps `timeLimit` to 60–900 seconds. The vision's 15–25-minute **active-round** median cannot be achieved at this pin. Lobby, restart and loading time must not be counted as round time to satisfy it. | `game/config.mjs`, `normalizeConfig`; `cocsOutcome` |
| Maps | Both graphs have 7 nodes and 10 edges. Each HQ is a leaf behind its own front articulation. Each economy node touches both fronts and the relay. Owning the connected home front plus both siphons supplies 7/s node income and majority; relay pays 0/s. This is gross node income, not net FLUX after upkeep or a guaranteed wallet delta. | `game/destination-lattice-maps.mjs:14–17,67–117`; `connectivityIncome`; `game/cocs-economy.mjs` |
| Map identity | Asterion's archive/galleries and Monsoon's dam/filter-house/roads differ in geometry, elevation and approaches, despite shared topology. Planar bearing is not a traversable path. | `makeTheatre`; `port/native-lattice-world/ACCEPTANCE.md` doorway failures |
| Kits | 9 operators × 7 harnesses, except Claude is locked to Claude Code: **57 legal pairs**. Capture field bonuses take the strongest contributor, capped at 1.35; they do not stack. Qwen already reaches that cap. | `game/data.mjs`, `validLoadout`; `game/lattice-roles.mjs`; `latticeCaptureRate` |
| Unit roles | 4v4 permits Fighter/Harvester/Builder; 8v8 also Scout/Saboteur. Rung-free practice allows all roles. Unit role names do not prove their co-op named abilities execute in PvP. PvP sabotage has dedicated execution; do not advertise co-op PRIME/REPAIR/RALLY as general PvP unit actions. | `game/config.mjs`; `game/cocs-roles.mjs`; `game/cocs.mjs`; `game/cocs-coop.mjs` |
| Repair | At this pin 4v4 excludes the Saboteur cut source, so cut-repair hooks have no natural 4v4 opportunity. Losing an owned connection is not itself a repairable sabotage cut. Practice/8v8 opportunities still need observation. | role allow-list; `game/lattice-support.mjs`, `repair`; PvP sabotage path |
| Ammo | Default Pulse has infinite ammo; useful sharing needs pickup-acquired finite ammo. Donor must carry the recipient's equipped weapon ammo, retain at least one round, and recipient must have capacity. | `game/data.mjs`; `game/lattice-support.mjs:138–159` |
| Vehicles | `vehicles:false` does not remove depot Puma loaners. Owned depots automatically maintain a free armed Puma; this is not a paid spawn button. The map comment saying “purchase” is not the runtime behavior. | `game/cocs-traversal.mjs:486–551`; `game/vehicles.mjs`, `PUMA` |
| Population | Both rungs require **8 human seats**. 4v4 total is 8; 8v8 total is 16 and may fill the rest with bots after meeting the floor. One human plus bots is practice, never a started competitive rung. Automated ordinary socket seats can test the floor but are not eight human playtesters. | `cocsRungPlan`, `cocsRungMeetsMinimum`; `server/room.mjs:723–755,1005–1019` |

Native implementation observations:

1. `world_hud.gd.approach_node` prefers the nearest live non-owned node, without
   capture adjacency. `topology.gd` already computes advisory legality and
   three-valued supply for the board; reuse it in the world.
2. `transport.gd.observe` projects nodes/resources/roles/recruitment, but omits
   the source's public `dominance` and `outcome`. Its results callback clears the
   live projection before world results display. A separate bounded result model
   is needed; retaining stale interactive state is not the solution.
3. `world_commands.gd` offers HOLD and Fighter (12 team FLUX) or Operations
   REINFORCE (50 team FLUX). Co-op recruitment already checks intermission,
   executor lease, slice allowance, threads and budget. Historical README text
   saying all co-op economy is disabled is superseded by that implementation.
4. `world_demo.gd` auto-connects/starts an ordinary two-bot host and rejects join
   arguments. It bypasses the shared session's setup parser. Its default branch
   calls `configure_match(mode, bots)`, which sends **no timeLimit**. The shared
   session's separate 60s lobby/smoke branches must not be mistaken for this route.
   Record normalized server configuration rather than assuming duration.
5. `board.gd` has an optional room field but auto-starts a newly configured host;
   its waiting timeout is 15s. That is insufficient for organizing human rungs.
6. Developer/package option surfaces reject several useful LATTICE settings;
   developer `--native-trace` and package support also differ. These are integration
   gaps, not reasons to change the shared base network client.

## 3. Phase 1 player experience requirements

### S1 — Session identity before action

Offer Practice PvP, competitive 4v4/8v8 lobby, and Operations explicitly. Display
map, mode, actual human/bot counts, requested rung, source floor, echoed loadout,
and echoed round limit. Never infer rung identity from actor count alone.

Proposed native configuration contract: `--time-limit=60..900` (default 900 for
the flagship route), `--bots=0..16` for practice/Operations, `--rung=4v4|8v8`
only for PvP, operator/harness, endpoint and optional room ID. Omitting rung means
practice. Rung bot fill comes from the server, not a native population override.
Explicitly distinguish a requested value from a validated server echo. Native
flagship default 900 is an ordinary permitted configuration, not a rule revision.

Practice may offer quick start; competitive hosting must wait for an explicit
host Start and source eligibility. Guests join the same endpoint/room, never
create a second authority, reconfigure the host or start a round. Below-floor
errors explain Practice/Operations choices without silently changing the mode.
Human waiting has no short smoke timeout; transport connection attempts remain
bounded. Results offer ordinary host restart and guest waiting, with clear round
revision, actor and receipt reset.

### S2 — One actionable world sentence

Render an urgency-ranked recommendation from **received facts plus authored
topology**, with target name, reason, planar bearing and distance:

1. Opponent dominance: choose a legal enemy-held target, state how many flips
   are still needed; if none is directly legal, explain the legal prerequisite.
2. Own dominance: defend a threatened owned node when contest is published;
   otherwise offer a legal extra-node push or maintaining the held line.
3. Known cut/disconnection: explain repair only for a published repairable cut
   and eligible loadout; recapturing a lost connecting node is a different job.
4. Otherwise rank legal frontier targets by strategic use, then planar distance
   and stable node ID. Avoid reproducing the board's fixed front/relay/economy
   preference as an untested universal strategy.

The new target helper returns a pure advisory model: `target_id`, `intent`,
`reason_code`, display text, `capture_legal`, `supply`, and source sequence/context.
Keep a stable target until eligibility, urgency or explicit player selection
changes; do not flicker on equal-distance samples. An explicit valid selection
may override the recommendation, but cannot fabricate legality.

Show ownership, live/contest, own progress, adjacency and supply separately.
Unknown or incomplete evidence says unknown. Supply can be linked, cut off or
unknown; advisory “staging connected” on a neutral node is not income ownership.
Map links and straight bearings do not promise an obstacle-free path. Use known
doorways/landmarks as authored route hints only. No hidden actors, timers, wallet
values, guessed capture radius or simulated local capture.

### S3 — Mode-specific outcome and results

PvP HUD displays authoritative majority counts, dominance holder, remaining,
target/fast state and breakCount. Freeze or hide stale timing; never tick a
locally reconstructed victory clock. Wording must distinguish “contested” from
“dominance broken.” Operations shows waves cleared/total, HQ health/integrity,
Director phase and genuine intermission recruitment eligibility.

On results, display source winner/draw, reason, received final scores and final
mode progress, plus source-timed duration when available. Missing reason/duration
stays unknown. Final summary is immutable and noninteractive until a new round;
old purchase consent and tasks cannot survive it. Explain personal contributions
only when source events/counters attribute them.

### S4 — Compact commands and honest feedback

MVP actions remain HOLD, Fighter and Operations REINFORCE. List useful labels,
legality/supply context, exact cost and rejection reason. Preserve fresh per-spend
authorization, source identity correlation and no automatic spending retries.
Opening commands neutralizes world input; match simulation continues. Closing,
focus regain, respawn and reconnect require the existing release/fresh-click gate.

Separate four layers: locally queued → server accepted → card settled → observed
game effect. `done/ok/replaced` is settlement, not capture. A capture needs an
owner transition/event; personal participation needs a matching actor ID. A
purchase needs its settled card plus authoritative spend/spawn evidence. Additional
ATTACK/SCAN/route or economy buttons are deferred, separately scoped port work
after MVP-A; they may expose existing source actions but cannot invent permissions.
Do not auto-renew HOLD to manufacture the promised field-play loop.

### S5 — Roles with observable teammate value

All nine operator and seven harness descriptions must reflect shipped hooks and
valid pairing. Jobs are situational, not exclusive classes or required composition.
Selecting a job does not issue a gameplay action or grant equipment.

| Job | Pinned examples | Useful evidence and limitation |
| --- | --- | --- |
| Breach/disrupt | Gemini swap, Grok Heat, OpenClaw disruption, Cline dash window | Enemy progress reduction or combat opening followed by a capture event; disruption alone never transfers ownership. Strongest capture bonus wins. |
| Anchor/ward | Claude/Claude Code, Roo; DeepSeek overwatch | Real slow cleanse, ward opportunity and held/retaken ground; damage or kills alone do not prove a saved dominance window. |
| Link/repair | Meta braced channel or Codex | Published cut removed, connection restored, then income opportunity. Mark “no cut opportunity” in 4v4; never repair ordinary enemy ownership. |
| Recon/rotation | Kimi moving reveal, DeepSeek still reveal, Mistral running point | Recipient-visible intel event/mark, approach or participation; intel-only marks confer no SCAN damage bonus. Mistral bonus requires moving on point. |
| Quartermaster | ChatGPT post-swap, OpenCode transfer; Hermes REQ delivery | Real finite donor debit/recipient gain, or REQ debit and FLUX gain at connected economy. Pulse-only loadouts yield no ammo opportunity. |
| Puma delivery | Qwen interaction identity, Hermes mobility, any eligible crew | Depot spawn, actual board/travel/dismount and subsequent useful contribution. Vehicle availability is source-owned; native end-to-end controls still need acceptance. |

Teach move/fire → legal front → ownership versus connected income → one command
and its receipt → one useful route/pickup. Operations terminals/PRIME belong to a
separate chapter. Full native vehicle handling is a conditional stretch gate:
document unsupported paths rather than promise that inherited infantry controls
prove Puma usability. The same applies to role telemetry absent from recipient wire.

## 4. Acceptance levels and telemetry

All levels preserve the selected source, ordinary tick rate, actual collisions,
normal damage/economy, source outcomes and recipient visibility. Fixtures and
direct simulations are explicitly labelled. An ACK-only or button-click-only
result never satisfies a gameplay gate.

| Level | Required evidence | Claim allowed |
| --- | --- | --- |
| MVP-A | Full natural practice PvP rounds and five-wave Operations completion on **both maps**, results/restart, observed capture/contribution and losses as specified in the plan | Native full-round practice/Operations; no competitive-rung claim |
| MVP-B | Direct source 4v4/8v8 rule simulations on both maps, plus ordinary-server below-floor/refill/start tests | Rung rules/configuration verified; not human match acceptance |
| MVP-C1 | Two independent real clients in one room, host waiting/join/start, independent recipient effects, results/restart on both maps | Two-client practice/Operations multiplayer; not a started two-human rung |
| MVP-C2 | Eight real human participants; actual floor-qualified rung sessions, roster and configuration retained | Human 4v4 or 8v8-rung acceptance; 8 humans + 8 bots is labelled as such, not 16-human play |

Instrumentation is port-owned, observational and versioned. Each attempt records
pin/implementation hashes, seed if exposed, normalized config, map/mode/rung,
human-versus-automated-seat-versus-bot counts, round/peer/actor, source tick/time,
snapshot/event sequence and input method. Maintain a bounded JSONL event stream
and a per-round summary; do not write every rendered frame indefinitely. Keep
source observations, derived correlations and human answers distinct.

Minimum metrics:

- Active round length, winner/reason, deadline hits, first capture/majority,
  first-majority-to-win conversion, successful breaks, recoveries from 1 to 4
  owned capturable nodes, node ownership/income over time. Report p10/median/p90
  separately by map, mode, population and config; no invented pacing target.
- Spawn/respawn to first useful combat or objective contribution; first useful
  contribution within 120s (kill/assist, attributed capture, actual support).
  Record remote/order-only captures separately from participant captures.
- Role **opportunities**, attempts, successful effects and teammate follow-through.
  Report no-opportunity and unavailable-wire separately from zero successes;
  denominator definitions include range, cooldown, stock/capacity or cut existence.
- Pickup acquisition, finite-ammo availability, route/road use, Puma delivery,
  command panel visit durations, world-active ratio excluding lobby/loading/results.
- After a round, unaided answers: next legal target, why adjacency differs from
  supply, how to stop opponent dominance, and the current mode's win condition.

Proposed usability targets, not achieved results: ≥80% of novices identify a legal
next target and correct win condition; ≥80% make a useful contribution within
120s; median spawn-to-useful-action ≤30s; median routine command visit <5s;
≥85% active-round time in the world. Pilot with at least 10 novices across both
maps; publish raw counts and uncertainty, not a population-wide claim. Initial
balance baseline: at least 10 complete rounds per map/population/config cohort,
with side rotation; practice and human cohorts remain separate. >75% first-majority
conversion is an investigation trigger, not an automatic balance patch.

## 5. Later source proposals, ordered by evidence

1. **Field capture plus persistent intent as one revision.** Replace order-only
   capture with physical presence while making squad orders persistent; review bot
   duties and contributor rewards together. Merely extending TTL strengthens
   remote capture. Compare capture attribution, command burden and round outcomes.
2. **Pacing.** If measured rounds justify 15–25 minutes, change upstream limit
   normalization and outcome assumptions, then dominance timing. The current
   900s ceiling cannot be solved by native UI. Test deadline and comeback effects.
3. **Economy/topology/pickups.** Measure front-plus-siphons openings, HQ-front
   lockout, double score/FLUX snowball, route emptiness and finite-ammo scarcity
   before changing either authored graph or rewards. Change one variable per trial.
4. **Role opportunity gaps.** Investigate repair in 4v4, PvP unit named verbs,
   quartermaster pickup access and Qwen dominance. Do not create new multipliers
   simply to make every pair appear equally specialized.

Each proposal needs a source-owner decision, upstream tests and commit, approved
new pin, refreshed semantic assets, and repeated affected native acceptance.

## 6. External precedents and remaining unknowns

Research-lane precedent summaries are **design context**, not evidence that a
CoCS change works. Existing primary links in [FLAGSHIP_VISION.md](FLAGSHIP_VISION.md)
cover EA Operations, Unknown Worlds commander design, PlayStation's Helldivers
hands-on and a PlanetSide update. The latter is not proof of a universal graph
degree rule. Exact primary citations for the additional lane summaries must be
retained with any future source-change proposal; they were not independently
web-revalidated during this docs-only synthesis.

| Reported primary principle | CoCS hypothesis to test, not a copied mechanic |
| --- | --- |
| EA Battlefield Operations: captured sectors and defender fallback | Make existing node flips feel like readable chapters; no new sector-lock rule in Phase 1. |
| Unknown Worlds NS2: commander as gardener, not field-play bottleneck | Brief optional command visits should increase useful field activity. |
| Splash Damage Enemy Territory: coordinated spawn waves/class reward | Measure reinforcement timing and support credit first; synchronized spawns would be a later source change. |
| PlanetSide 2 lattice: limited branching/avoid empty routes | Audit route population. The research's “<4 links” guidance is not binding; current front degree is 4 and relay degree is 4. |
| Helldivers 2 team weapon handoffs | Teach finite-ammo cooperation with existing transfers; do not imply CoCS has a new weapon-drop action. |
| Valve Left 4 Dead: PvE intensity pacing | Observe Operations' existing Director peaks/rest; do not apply a PvE director to competitive PvP. |
| Riot Split: purposeful vertical towers | Measure Asterion sightline and flank use before adding elevation or topology. |

Unresolved until implementation/play: recipient coverage of support attribution,
reliable full Operations clear/defeat distributions, native Puma control/render
completeness, real human lobby timing/disconnect behavior, practical role variety,
map-specific navigation comprehension and balanced-match duration. These are
tracked blockers or experiments, never assumed passes.
