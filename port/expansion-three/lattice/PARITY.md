# LATTICE strategic feedback expansion

Base: `27cfaa14`; branch `expansion-three/lattice`. Scope is native presentation
in `godot/lattice`, plus test fixtures and this handoff. Engine slot is **not
granted**. Frozen source `515daf07589150dd3241f4ae1425cc1b093912f5`, reviewed
derivative `0326b435a2fdd88e6e7a01b8a7325feccc4d15cb` and core SHA-256
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9` retained.

## Actual gaps selected and implemented

| Source behavior | Existing native gap | This batch |
| --- | --- | --- |
| `game/cocs-orders.mjs:272-405`, `cocsOrderNextAction`, `cocsSyncStrip`: queued, accepted, complete and refused are separate; refusal gives a next action. | `world_commands.gd` already records HOLD/BUY/recruitment; field HUD called only `Model.buy_receipt`, so an old BUY masked a later HOLD failure. | `world_feedback.gd` selects the latest exact local card in the current revision, including HOLD and recruitment. Field ribbon shows source refusal/reason in amber, with source HOLD recovery copy. Activity also includes recovery. Settled order cards do not imply capture. |
| `game/hud.mjs:1397-1425`, `cocsBoard`: clamp both published progress values, show `round(max(p0,p1)*100)` and contested status. `game/cocs.mjs` owns actual capture radius/presence rules. | Objective deck showed owner/live/legality/supply; tactical model showed planar distance, but neither exposed published capture percentage. | Current target HUD now shows capture percentage/contest; selected objective detail shows the same plus finite planar distance and radius **only if received**. Missing progress/range stays unknown. PvP snapshots omit radius: none is guessed from map assets. |
| `game/lattice-feedback.mjs:184-244`, `latticeCaption`; called by `game/hud.mjs:407` `audioCaption`. | Shared `caption_model.gd` falls through to the first-pass static catalog, omitting dynamic LATTICE branches/values. | Standalone `event_caption.gd` formats dynamic source labels/values: wave, phase, modifier, node/depot, route, stance, mutiny counts, order verb, role/prime/logistics, scan/repair/rally counts and rounded FLUX. Parent-only integration patch supplied below. |

`world_guidance`, `world_target`, `world_roles`, `world_outcomes`,
`world_session_panel`, `world_telemetry`, `world_tactical_model`, `world_commands`,
`world_transport`, and `multiplayer_worlds/lattice_{demo,flow,options}` were
inspected. Existing REQ catalogs, purchases, HOLD, recruitment, topology,
role teaching, outcome UI, recon count, wave force and command deck scrolling
are pre-existing work, not claimed as new.

## Authority and privacy

- Native command methods remain the ordinary `transport.activate` path. No new
  spends, local build/effect grants, capture credit, contact discovery or source
  authority changes. Receipts consume exact transport action state and round.
- Objective facts use current recipient nodes and current own actor only.
  Planar distance is not proof of physical capture presence, line of sight,
  reachability or legality. No private actor detail is derived from world poses.
- Existing world gates clear selection/consent on modal/focus/stale/death,
  results and identity changes; this batch adds no persistent selection state.
- New caption helper is **only a formatter**, with no queue, cache or policy.
  It must be called after the experience lane's shared event permission gate.
  That lane owns spectator/public event types and private clearing. Its source
  eligibility must also preserve `latticeSoundCue` (`lattice-feedback.mjs:111-182`):
  commands, team economy/roles/scan and order events are team scoped; device use
  is local-actor scoped. Role spot/repair captions expose only permitted event
  counts, never target IDs/coordinates. Dynamic text is not permission to show
  an event that source audio or the shared gate excludes.
- Real source mutiny success `seat` is an actor **string**, including `"0"`
  (`game/cocs.mjs:1509`); director tier is `D1`/`D2` etc. These are represented
  in oracle vectors, avoiding boolean-seat/numeric-tier assumptions.

## Parent integration

Apply `caption-integration.patch` **after** the experience lane's shared
recipient/team/spectator `event_allowed`/source-eligibility work. It adds one
preload and a dynamic formatter fallback in `text_for`; the shared consume path
must reject unauthorized events before calling it. Keep shared priority, TTL,
dedupe, settings and lifecycle clearing. Do not create a second caption queue.

The patch is not applied in this branch, so dynamic captions are **not yet
visible in production**. The other two feedback features are directly wired.
No edits to `godot/experience`, spectator helpers, game/server source, map
geometry, weather or challenge rewards are included. No session hook needed.

## Source oracle and fixtures

- `tools/port/lattice/source-oracle.mjs`: direct calls to frozen JS functions;
  47 dynamic caption cases, 4 progress cases, 13 refusal recovery cases, plus
  own/other source sound eligibility. Generates
  `godot/tests/lattice/fixtures/expansion_feedback.json`; default execution
  compares the fixture to source again and verifies the core hash.
- `wire-journey.mjs`: real normal-rate Tern derived authority, two WebSocket
  players and spectator, source-owned ordinary commands and recipient frames.
  Controlled REQ/phase setup is explicit in evidence. No fake snapshots.
- `native-clients.mjs` + `expansion_connected.gd`: executable engine-grant-only
  fixture, three isolated native processes, ordinary transports, actual HOLD /
  BUY / no-target / illegal HOLD results and spectator gating. Prepared, unrun.
  This is native transport evidence, separate from graphical input acceptance.
- `expansion_feedback_contract.gd`: differential comparison to the generated
  source vectors, malformed/unknown facts, latest-card and revision behavior.
- `world_tactical_contract.gd`: compact 150% test now includes contested 63%
  progress and a real-shaped rejected HOLD/recovery ribbon simultaneously.
