# Cinderwake Drydock — implementation and intake ledger

2026-09-25. **Implemented source/map/adapter/native code; source feature-branch
intake is complete in this isolated port branch, engine acceptance is pending.
Not a verified playable release.** The product factory refuses Cinderwake
under the old source pin rather than playing an unscripted static map.

## Provenance and ownership

- Port baseline: `ed2e27b2`, subsequently merged with the shared Horde fix
  `06f406bd`; worktree `/home/mojo/.tmp-on-disk/cocs-cinderwake-port`, branch
  `port/cinderwake-drydock`.
- Upstream baseline: `515daf07589150dd3241f4ae1425cc1b093912f5`;
  integrated port pin: `48264858af820c69a833ef8b15c09ebac69e8cc3`.
- Source implementation: `48264858af820c69a833ef8b15c09ebac69e8cc3`, pushed to
  [`mojomast/cocs:feature/cinderwake-horde-stages`](https://github.com/mojomast/cocs/tree/feature/cinderwake-horde-stages).
  Worktree `/home/mojo/.tmp-on-disk/cocs-cinderwake-source`.
- Source owns `game/horde-stages.mjs`, core constructor/topology transaction,
  single-player clear/arrival hold/snapshot hooks, tests and contract docs.
  This is an upstream addition, not an adapter Horde loop.
- Port owns `tools/godot-horde-maps/`, `godot/horde_maps/`, strict envelope
  validation, literal authority route, observation-only composition and package
  inventory additions. Shared Horde movement/rig files were not edited.
- Self-review performed; no additional agent or independent review is claimed.

Port commits (apply in order after resolving the source intake gate):

| Commit | Owned scope |
| --- | --- |
| `f7721c7a` | New map/compiler/strict schema and traversal/source fixtures |
| `1e478763` | Literal authority hook, transport hashes, launcher/package inventory |
| `f2eb1bd7` | Native composition, physical gates/signage/audio, gated native test |

Raw final Node logs are in `evidence/cinderwake/node.log` (36 tests),
`source.log` (53 tests), and `baseline.log` (baseline comparison). These are
focused Node verification artifacts, not engine or natural-play evidence.

The source branch was committed and pushed **before any port pin change**.
The isolated port branch now merges that upstream source commit as ancestry,
records its feature branch in `source-lock.json`, updates map selection to the
same commit and passes unchanged `verifySource`. No semantic export, Godot
invocation, full verifier or package build has occurred in this lane.

## Concrete implementation

The source constructor accepts a trusted `hordeArena` option for bounded Horde
only. It clones the base, validates a finite plan, installs closed gates and
initial pools before nav/spawns. Source clear events are the only scheduled
transition cause. Gate transactions replace arena identity, select
collision-keyed navigation and clear bot routes. Source movement, rays,
spawning and bots all read that topology. The adapter passes the reviewed
arena before construction and does not run a second rules loop.

Snapshots forward source `singleplayer.stage` unchanged. The transport also
publishes `hordeMapContract` (version, geometry hash, plan hash); native
composition rejects disagreement with its loaded recipe. Native gate bodies
and visible slabs follow the received mask, including revision/round resets.
Opening immediately clears the aperture. Signs, captioned warning horn and
arrival HUD read source state; they cannot advance a gate or wave.

The renderer shares geometry batching and the existing Horde session/HUD,
pickups, upgrades, operator rig and result/restart code. It creates a new
drydock footprint and high suspended ship/propeller decoration. One shared
environment/sun is installed. Nacre geometry is never loaded or transformed.

### Exact schedule and timing

| Waves | Committed enemy arena | Transition after clear |
| --- | --- | --- |
| 1–2 | B, Loading Cradle | 2 → C, open BC |
| 3–5 | C, Keel Trench | 5 → D, open CD; attempt BC closure after entry |
| 6–10 | D, Propeller Apron | 10 → B, open both |
| 11–13 | B | 13 → C, open BC |
| 14–15 | C | 15 → D, open CD; attempt BC closure |
| 16–20 | D | 20 → B, open both |
| 21–22 | B | 22 → C, open BC |
| 23–24 | C | 24 → D, open CD; attempt BC closure |
| 25–30 | D | Ordinary source target victory |

Any target 1–30 ends on that actual target; terminal victory suppresses the
scheduled transit. Source champions remain **9, 18, 27**, including summons.
Source lives remain **3**. Wave modifiers/composition, scoring, pickup cooldown,
resupply, upgrades, health regeneration and defeat are unchanged.

At source clear T: begin with causal clear serial. At T+180 ticks: open route.
Commit no earlier than T+240, with 30 continuous living/grounded/supported
arrival ticks, expired ordinary intermission and reachable destination pools.
The next wave starts on a subsequent source tick. Closure warns for 180 ticks,
defers for bodies/projectiles/deployables and cancels at 600 ticks after entry.
At T+1200 remind; at T+2400 open both gates, retaining the travel hold.

Normal simulation remains 1/60 second. Local authority retains its existing
`easy` preset (7-second ordinary intermission) and **900-second clock**. Normal
difficulty source fixtures use 5 seconds. Source normalization also caps the
maximum clock at **900 seconds**; 30-wave completion within that limit has not
been demonstrated. No clock extension or pacing acceleration was introduced.

### Geometry and measured traversal

88 × 128m envelope, Y=0 connected floor union; 25 non-overlapping floor
rectangles, 69 static solid blocks, 1,822 authored nav anchors and two 12 × 1 ×
5m gates. Four permanently open 6m E links. No hidden ground beneath hull
infill, moving floors, jump-dependent routes, teleports or pickup locks.

Final adjustments from the proposal: keel ribs centred X ±8; A shields at
Z=54 and human anchors at Z=58; C arrival Z=[10,14]; D rocket/flak at Z=-53;
B health at (-17,42). These resolve measured capsule/pickup interference.

| Authored route | Centreline length (m) |
| --- | ---: |
| A–B | 12.000 |
| B–C | 36.306 |
| C–D | 47.000 |
| D–B direct | 83.306 |
| D–B via E | 168.682 |
| E(46)–A | 49.000 |
| E(6)–C | 46.090 |

Each route is sampled every ≤0.2m for support and a conservative 1.2m-radius
obstruction probe, then walked in both directions by actual source
`moveActor` with ordinary input, no jump or sprint. Source movement uses
`RULES.radius=0.42`, `height=1.8` for NPCs as well as the human; NPC visual scale
is not a larger movement capsule. All four gate masks connect every human,
enemy and arrival anchor. Source A* is exercised from every stage enemy
anchor to every destination; cross-stage paths with both gates closed use E.

Geometry SHA-256:
`72bffc3ab368a5d0b8257edbd74aa0b291905f71154a04eb39e4ad6e39285eaa`

Plan SHA-256:
`d6494eda516476cce0a6f0f334b8ea2f950181fa1423c58294df3752189de037`

## Verification ledger

Run Node suites **serially**. `source-fixture.test.mjs` now imports the local
locked source ancestry. It is never a runtime source-loader override and never
a semantic-verifier bypass.

| Check | Result |
| --- | --- |
| Upstream `game/horde-stages.test.mjs` | 6 pass: causality/timing, live grounded arrival, fallback, occupied closure, terminal/restart, strict negatives |
| Upstream `game/singleplayer.test.mjs` | 47 pass |
| External vanilla baseline comparison | 600 ordinary ticks, seed 731: identical snapshot/events/RNG state and call count to source pin |
| `tools/godot-horde-maps/cinderwake.test.mjs` | 4 pass: strict recipe, all masks/A*, rays/capsules, input traversal |
| `tools/godot-horde-maps/source-fixture.test.mjs` | 4 pass: targets 1–30, all 12 NPC archetypes/support/pools, ordinary first-wave timing/death/restart, actual input travel after controlled clear |
| `port/native-horde/cinderwake.test.mjs` | 2 pass: literal launcher routing/negatives and explicit old-pin refusal |
| Dev/package option regression | 18 pass |
| Horde/native package closure checks | 19 pass after source intake; 85 locked source modules including `game/horde-stages.mjs` |
| Native gate ray/revision/restart test | Authored at `godot/tests/horde/cinderwake_test.gd`; **not run** |
| Godot parsing/import/render, two resolutions, natural 10/30-wave wins, live defeats/restarts, final aggregate/package | **Not run; engine gate closed** |

Controlled clear fixtures deliberately set wave/enemy state. They prove the
production controller, including actual input-driven arrival causality, but
are not natural combat wins. All-archetype tests prove spawn support and
graph access, not a completed boss fight. An exploratory constant-RNG husk
probe with a fixture-protected human reached E but had not reached the C
human after 90 simulated seconds; it wandered into D. That probe is not a
natural-play success or an orphan-free AI acceptance result. Live pursuit,
boss/summon behaviour and readable traversal remain part of the pending gate.

During authoring, the 1.2m probe rejected two original D weapon placements
and the first E–A bend. The revised placements/routes pass. Initial source
fixtures accidentally used the default easy difficulty while assuming normal
intermission; the fixture now explicitly requests normal. No rules timing was
changed to satisfy that test.

## Integration sequence for the lead

1. Source branch `feature/cinderwake-horde-stages` and shared port baseline are
   merged into the isolated Cinderwake port branch. The source pin and map
   selection both name upstream `48264858`; unchanged `verifySource` passes.
   Source map allowlist is unchanged: Cinderwake is a port-authored local map.
2. Reconcile the additive
   launcher/package hunks with LATTICE’s current files. Regenerate
   `godot/ui/routes.json` from the combined branch rather than overwriting
   unrelated route improvements. No Horde movement, rig or shared demo file
   from the main lead is part of these commits.
3. Focused source/map/authority checks pass from the integrated pin. The
   explicit source-module census in `horde_closure.test.mjs` is **85** with
   `game/horde-stages.mjs`.
4. Engine work requires both LATTICE release and the owner-created marker
   `/home/mojo/.tmp-on-disk/cocs-cinderwake-engine-slot-granted`. The earlier
   LATTICE marker alone grants nothing. Then run required semantic regeneration,
   serial import/native gate tests, two-resolution live sessions and aggregate
   verification using the repository’s current scripts. No engine process has
   been started by this lane.
5. Run the ordinary launch after engine preparation:
   `node tools/godot-dev/launch.mjs --experience=horde --map=cinderwake-drydock --waves=10`.
   Packaged equivalent: `node run.mjs --experience=horde --map=cinderwake-drydock --waves=10`.
   These are integration instructions, not a claim that an artifact exists.

The package builder records the new literal JSON, schema adapter, geometry/plan
hashes and upstream provenance separately from locked source modules. It
refuses to package Cinderwake without the upstream stage module. There is no
published Cinderwake artifact or test/download link at this checkpoint.
