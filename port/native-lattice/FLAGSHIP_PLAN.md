# LATTICE Strike — sequential delegated build plan

Status: **not executed**. Companion contract:
[FLAGSHIP_SPEC.md](FLAGSHIP_SPEC.md). Source remains
`515daf07589150dd3241f4ae1425cc1b093912f5`; branch
`port/godot-destinations`. This plan is for a future lead assigning small agents
**one implementation lane at a time**. The docs-only synthesis ran no builds,
imports, suites or benchmarks and owns only this file and the specification.

## 1. Execution rules and priorities

Priority P0: truthful session identity, recipient projection, legality, outcomes,
natural full rounds. P1: host/guest and human-rung acceptance, role understanding
and measurable contributions. P2: additional source-supported commands, complete
vehicle polish, and evidence-led source proposals.

1. Lead first records current HEAD, selected pin and working-tree changes. The
   checkout has concurrent Horde/release work and modified launcher/package files.
   Do not restore, overwrite or rebase that work. Obtain an explicit file handoff
   before L4. Prefer isolated lane worktrees based on the latest accepted lane.
2. No lane edits `game/**`, server rules, the source lock, shared base session or
   base network client. Read them for contracts. A shared change request goes to
   the lead with exact location, reason and narrow proposed patch.
3. No edits to `FLAGSHIP_VISION.md` or historical evidence. New lane documentation
   and evidence have unique paths. Lead owns shared release docs, aggregate
   `verify.py`, route/menu integration outside L4, merges and eventual publication.
4. Give each agent the spec, its row below, dependency artifacts, current base,
   and exact allowed files. Require implementation, meaningful focused checks,
   an evidence manifest and a handoff. A plan/ACK response is not completion.
5. Implementation and resource-heavy work are serial. Lead explicitly grants the
   engine/server/display/build slot after ongoing Horde work finishes. Only one
   import, full-round scenario, multi-client scenario or package build at a time.
   A multi-client gate is one controlled scenario with its required two clients.

## 2. Ownership ledger

Paths below are future ownership grants, not edits performed by this synthesis.
All new helper/test names must be checked for collisions before use.

| Owner / sequence | Exclusive runtime/config files | Exclusive new checks/docs | Dependencies / deliverable |
| --- | --- | --- | --- |
| L1 projection/session | `godot/lattice/transport.gd`, `world_transport.gd`, `world_demo.gd`; new `session_options.gd`, `session_flow.gd` | `godot/tests/lattice/flagship_l1*`; `port/native-lattice/flagship/l1/` | Source echo, bounded outcome/result projection, config parser and host/guest state machine with stable composition hooks |
| L2 guidance | `godot/lattice/world_hud.gd`; new `world_target.gd`; narrow `topology.gd` fixes only if required | `godot/tests/lattice/flagship_l2*`; `port/native-lattice/flagship/l2/` | L1 projection/context; pure legal target selector and integrated HUD |
| L3 outcomes/roles/commands | `godot/lattice/world_commands.gd`; new `world_outcomes.gd`, `world_roles.gd`, `world_telemetry.gd`, `world_session_panel.gd` | `godot/tests/lattice/flagship_l3*`; `port/native-lattice/flagship/l3/` | L1 composition API + L2 target model; visible result/setup/role UI, effect evidence and bounded telemetry |
| L4 entry points | `tools/godot-dev/launch_options.mjs`, its test; `tools/godot-package/options.mjs`, its test; `tools/godot-package/routes_meta.mjs` | New LATTICE-specific option fixtures if needed; `port/native-lattice/flagship/l4/` | L1 flags + L3 setup surface; dev/package/menu metadata parity, after lead releases shared modified files |
| L5 lobby and witness | `godot/lattice/board.gd`; new `godot/tests/lattice/flagship_l5*`; new `port/tools/native_lattice_flagship/` harness except lead-owned aggregate verifier | `port/native-lattice/flagship/l5/`; unique `port/native-lattice/evidence/flagship/<attempt>/` | All prior lanes; explicit board host wait/start, independent clients, ordinary-wire witnesses, direct simulations and evidence audit |
| Lead integration | Composition patches to L1 files after L1 releases ownership; aggregate `verify.py`; shared menu/route code and release docs | Gate summaries, package manifests, reproduction/test links | Accept each lane, resolve seams, run serial acceptance/build, preserve failure history |

`world_guidance.gd` already serves control-state and bearing presentation. Reuse it;
lead arbitrates any needed change. New `world_target.gd` is strategic selection,
not a second copy of pointer/lifecycle rules. L5 must not edit L1 files to solve
lobby integration; submit a request for lead integration or reopen L1 ownership
explicitly after releasing L5. This avoids overlapping “small” fixes.

## 3. Freeze the cross-lane interfaces before L2

L1 publishes a checked example schema and lifecycle diagram in its handoff.
These are additive to existing fields and signals:

- Live projection preserves current resource/command/role/recruitment keys;
  adds bounded `dominance` and `outcome`, source scores/time when actually sent,
  and source sequence/context. Missing and explicit null are distinguishable.
- `session_config` retains validated lobby/start echoes: map, mode, rung or null,
  bot configuration, limit, own assigned loadout and roster/population metadata.
  Requested values are a separate structure, never presented as an echo.
- `result_projection` is immutable recipient-derived final state, separate from
  live `projection`. Results clear action authority and purchase consent while
  retaining final display. New revision, disconnect and identity changes clear
  the correct caches. Document signal order: base decoding → projection/result
  update → UI notification; no consumer races a prior-round dictionary.
- Session methods: validated configuration request, join, explicit host start,
  restart and disconnect. Return reason/queue state, not success of the match.
  Host/guest authority derives from source roster; preserve one socket per client.
- L1 provides composition slots/signals for L3 session/results/role modules.
  It may test with a dummy consumer; lead wires actual L3 modules after delivery.
- L2 `world_target` consumes projection + `topology.model(...)` + local pose;
  emits the advisory model specified in S2. It sends no network frames.
- L3 telemetry consumes decoded observations, source events, input boundaries and
  UI visit boundaries. It cannot mutate source state or query private room objects.
- L5 harness audits outgoing recipient frames separately from native presentation.
  Direct source simulations live in separate files/output with a `direct-sim`
  evidence class; their privileged state access cannot enter the live witness.

Open a seam issue when a needed field is not recipient-published. Either degrade
to unknown or mark the dependent feature blocked. Do not invent support credit,
timer progress, human identity or missing enemy information to close a gate.

## 4. Lane work packets and acceptance

### L1 — authority projection and session foundation (P0)

Read `transport.gd`, `world_transport.gd`, `world_demo.gd`, base session/client,
`cocsDominanceView`, `cocsOutcomeSnapshot`, source config and room start gates.

1. Add bounded shape validation/projection for public outcomes without broadening
   enemy wallet/intel access. Preserve numeric JSON identity handling and current
   malformed/stale/actor-reassignment behavior.
2. Add the shared LATTICE argument/config model from S1. Use existing normal host
   frames with source-supported fields, preserve map allow-lists and normalize
   loadouts through existing native/source-compatible validation.
3. Replace implicit-only world auto-start with explicit practice/host/join flow;
   permit intentional practice quick start. Do not execute the inherited 60s
   lobby branch accidentally. Validate actual start echoes before enabling play.
4. Persist only final display facts on results and support ordinary new rounds.
   Provide stable UI integration hooks; commands remain disabled until live.
5. Add meaningful contracts for malformed/absent public fields, result ordering,
   round reset, below-floor error display model, guest no-host/start behavior and
   configured-versus-echoed identity. Existing adapter checks remain applicable.

Done: checked contracts + documented API + a lead-scheduled ordinary live smoke
showing source config echo and outcome projection on each mode. Smoke is plumbing
evidence only. No claim of full-round or human-rung acceptance.

### L2 — legal and useful world guidance (P0)

1. Bind authored map topology when map identity changes; feed only received nodes
   and own-team cut evidence. Audit the existing topology missing-owner/cut-list
   behavior before certifying supply; if evidence is absent, preserve uncertainty.
2. Implement S2 ranking, stable target selection and fallback. Fixtures must
   include a closer illegal enemy node, a legal disconnected frontier, incomplete
   topology, an owned cut node, 3-node and 4-node opponent dominance, and no legal
   target. No assertion that one retake always resets a 4-node holder.
3. Render separate capture legality, supply, ownership and contest without
   changing `activate` authorization. The board and world must not disagree about
   the underlying topology model. Show a readable prerequisite if no direct break
   target is available; route hints must accommodate authored HQ doorways.
4. Retain released/dead/stale controls and compact HUD layout at 960×640 and
   1280×800; use text/symbols as well as colors.

Done: contracts plus a lead-scheduled native walk on both maps where recommended
legal frontier, source owner transition and subsequent guidance are correlated.
Local capture credit requires the actor in the source event. Review actual PNGs;
image generation alone is not visual acceptance.

### L3 — results, roles and command outcomes (P0/P1)

1. Build session/setup panel and results panel using L1 methods/models. Wire via
   agreed composition hooks; send lead the exact integration patch request.
2. Show mode-specific majority/breakCount or waves/HQ, winner/reason and restart
   state. Unknown final values remain unknown; stale live controls remain blocked.
3. Compact commands retain HOLD/Fighter/REINFORCE and existing spend gates. Label
   card settlement separately from effects, including `replaced`. Give selection
   legal/supply context using the shared helper rather than a duplicate rule.
4. Add all 57-pair-compatible role explanations, opportunity limitations and
   pickup-dependent ammo teaching. Use existing catalog/loadout data where possible;
   pin any port-owned explanatory data to the source symbols in its handoff.
5. Add bounded telemetry with evidence class and source IDs/times. Count panel
   visits and available authoritative effects; log attribution unavailable rather
   than claim every nearby capture or income tick for the local actor.
6. Check no duplicate spending, no stale consent on wave/lease/round changes,
   pointer release/reentry, results reset and false capture celebrations. Support
   transfer/cut fixtures prove presentation only, not natural role opportunity.

Done: actual rendered result/command/setup panels, audited trace schema and
focused checks. Lead integrates and schedules MVP-A before moving to broad polish.

### L4 — consistent launch/package/menu parameters (P0)

1. Re-read current files after Horde handoff; preserve unrelated changes. Extend
   only LATTICE branches to S1 flags, endpoint/join flow and diagnostic trace parity.
2. Keep both existing route identities: `lattice` board and `lattice-world` FPS.
   Metadata labels explain practice versus competitive lobby; menu choices expose
   only implemented paths. Lead patches generated routes/menu consumers as needed.
3. Validate both maps/modes, bounds 60–900 and 0–16, rung only in PvP, invalid
   Claude pair, unknown map, guest/config conflicts and bot-fill ownership. Ensure
   endpoint use reaches one existing server rather than launching a second room.
   If `lobbyEndpoint` or launcher process code blocks this, request a lead-owned
   narrow edit; do not expand ownership silently.
4. Run only focused option tests in the lane. Deliver exact dev/package equivalent
   argv fixtures and expected native flags. Heavy package generation is lead-only.

Done: dev/package parity tests and a lead-reviewed metadata diff. Newly documented
commands must be run during integrated acceptance, not assumed from parser tests.

### L5 — lobby parity and independent acceptance harness (P1)

1. Change board auto-start to share the L1 configuration/host-wait model; provide
   explicit Start and host/guest feedback. Remove the 15s limit on legitimate
   human roster waiting while retaining bounded connect failures. Preserve map
   selection, ordinary commands and recipient filtering.
2. Implement `port/tools/native_lattice_flagship/run.mjs` and `audit.mjs` for
   ordinary sessions with input-driven native clients, source recipients and
   bounded attempt directories. Add a separate `rung_sim.mjs` for direct source
   experiments and `rung_floor.mjs` for ordinary server-seat tests. Lead owns any
   aggregate `verify.py`. These are proposed new tools, not available commands yet.
3. Witness capture events/owner changes, population/config, natural outcomes,
   restart revisions, commands/counters and observed native UI/pose. No teleport,
   node/wallet/time/wave mutation, direct private-room inspection or accelerated
   ticks in a live-natural run. Engine input, OS input and human input are distinct.
4. Audit negative mutations: removing owner change, replacing actor/round/card,
   replacing natural result with ACK, dropping fifth-wave clear, inserting bot-only
   rung label or losing cleanup must fail the relevant claim.
5. Build two-client orchestration: same endpoint/room, different peers/actors,
   explicit host start after guest arrival, source-echoed identities, guest cannot
   reconfigure/start, disconnection and next-round behavior. Source automatic
   fallback or rejected start must be shown as returned, not silently “fixed.”

Done: harness documentation, focused audits, then lead-run MVP-B/C1. Human C2 is
a scheduled play session, not something socket automation can manufacture.

## 5. Serial verification gates

Lead acquires the resource slot once per stage; lane agents do not independently
launch full verifiers. After focused checks pass, repeat only for a changed scope,
a failure or an unresolved concern. Do not repeatedly rebuild unchanged assets.

| Gate | Required procedure | Pass condition |
| --- | --- | --- |
| G0 provenance | Record pin, HEAD, changed files and exact tested hashes; inspect source-diff status | Approved source identity and ownership; concurrent work preserved |
| G1 contracts | Focused projection/guidance/UI/options/lobby audits; existing affected LATTICE checks | No malformed, hidden, stale or wrong-round authority leaks; no ACK-only outcome |
| G2 import | Lead runs required semantic/source verification and pinned Godot import once after integration | Correct maps and source; no engine script errors; retain logs |
| G3 short rendered | Actual setup, legal front approach, commands, results layout on both resolutions/maps | Native pixels inspected, genuine input effect and source correlation; smoke-labelled |
| G4 MVP-A | See natural matrix below, each case serial at normal rate | Full practice/Operations outcomes and restart, not a short smoke substitute |
| G5 MVP-B | Both-map direct 4v4/8v8 simulations, then ordinary-server floor tests | Correct thresholds/roles/timers; below-floor rejected; valid-seat fill accepted, evidence class explicit |
| G6 MVP-C1 | Two native clients, one shared source room, both maps; practice and Operations join paths | Independent movement/actions observed, correct host/guest rights and same-round outcomes/reset |
| G7 package | Lead builds target packages serially from tested bytes, then launches LATTICE through packaged/menu routes | Options, identity, server ownership and gameplay path match dev; exact artifact hashes and paths |
| G8 MVP-C2 | Scheduled eight-human roster on both maps; test 4v4 and 8v8 rung, label any bot fill | Real human gameplay, source floor satisfied, complete results/restart, recipient evidence and feedback |

### Natural MVP-A matrix

- **Each map, Practice PvP:** ordinary pinned config with 900s limit, recorded bot
  count/difficulty and default gameplay rates. Reach real results by dominance or
  deadline; observe a genuine legal capture and a source-attributed local useful
  contribution. Show final reason, winner/draw and a second round's clean state.
- **Each map, Operations:** preserve the five-wave operation, 900s legal limit and
  ordinary Director. Require a real fifth-wave clear/HQ survival success, natural
  intermission, and existing REINFORCE effect evidence where affordable/authorized.
  A first-wave purchase alone is not completion.
- **Each map, defeat handling:** retain a natural PvP loss and Operations loss
  (HQ/Director/time as actually produced), correct result explanation and restart.
  A scripted ordinary-input defensive/idle strategy may seek a loss, but cannot
  mutate the outcome. If a requested branch does not occur, that branch is pending.
- Across PvP runs, record a real contest and ownership flip. Seek a majority break
  with ordinary play; if no natural break is observed, keep the break UX live gate
  pending even if the synthetic model passes. Do not force the baseline histogram.

Allow at most two predeclared attempts per scenario before reviewing a failure or
unobserved outcome with the lead. Retain every attempt. Bound each 900s round to
20 minutes wall time including setup/cleanup; restart can be checked through its
first active snapshot without requiring another complete round. A timeout is not
a natural time-limit result. If ordinary play cannot clear Operations, report the
gate blocked and investigate inputs/strategy/source behavior rather than weaken it.

### MVP-B specifics

Direct simulation checks: exact rung role allow-lists, five capturable nodes,
3/5 and 4/5 dominance targets, reset on loss below majority, contest-without-flip
does not reset, adjacency versus supply, remote-order capture and idle no-decay,
deadline clamp and winner tie-break. Injected starting scenarios are permissible
only here and in explicitly synthetic tests.

Server floor cases: request each rung with 1, 2 and 7 ordinary seats and expect
below-minimum; with 8 ordinary socket seats validate 4v4 and 8v8 start/config/bot
fill. Automated seats count for server API verification, not human acceptance.
Check disconnect-before-start updates the floor. Observe disconnect-after-start
behavior as implemented; do not invent an unsupported population migration rule.

### MVP-C2 and measured design quality

Recruit eight actual people, not eight headless agents. On 8v8, label eight human
plus eight bot fill accurately; a full 16-human match is a separate later gate.
Rotate sides, retain source roster/rung echo, collect round/contribution metrics
and the unaided comprehension questions from the spec. A small sample proves a
working session, not balance. Continue the separately budgeted baseline cohorts
before proposing economy/topology/pacing changes.

## 6. Evidence, documentation and completion checklist

Every lane handoff includes: owned diff, dependency versions, APIs, commands run
with exit status, exact failures, evidence class, unresolved blockers and files
requested from lead. Each live attempt contains `manifest.json`, bounded
`wire.jsonl`/native trace, `summary.json`, actually reviewed screenshots and
`cleanup.json`. Record own children/display/ports and close only those resources;
use private displays, isolated XDG and `/tmp/opencode` temporary paths.

Lead records integrated results in a new LATTICE flagship acceptance report and
updates shared release docs only after the corresponding gate passes. Historical
old-pin evidence stays intact. Publish exact tested dev and packaged commands,
map/mode selection, local artifact paths and any real available test links. A
native app need not have a browser URL; never invent a hosted link or imply an
expired ephemeral endpoint is still playable.

Proposed post-L4 example (must be verified before documenting as runnable):

```sh
PORT=0 node tools/godot-dev/launch.mjs --experience=lattice-world --map=asterion-relay --mode=cocs --bots=7 --time-limit=900
```

It is **Practice PvP**, with one human plus configured bots, not 4v4. A rung
host instead requests `--rung=4v4` or `--rung=8v8`, waits for the published floor,
and starts explicitly. Guest commands use the exact same printed endpoint and
room ID; L4/L5 must publish the tested invocation and source-echoed configuration.

Completion requires explicit status for MVP-A, B, C1 and C2, each independently
PASS/BLOCKED/PENDING with links. No aggregate “flagship complete” label while a
required natural match or human gate is pending. Source proposals remain a
separate backlog with measurements, upstream ownership and approval requirements.
