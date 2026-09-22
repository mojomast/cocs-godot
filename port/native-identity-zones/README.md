# Identity Zone Modes — Vermilion Fold Domination

Scope: make **Vermilion Fold** playable as source-authoritative **Domination**
through the delivered identity-map envelope. This lane owns:

- `port/native-identity-zones/**` — static allowlist, source-backed match
  factory, owned loopback authority, travel measurement and graphical
  acceptance.
- `godot/native_arenas/identity_zone_demo.gd|.tscn` — the separate identity
  zone composition (never the Deathmatch `demo.tscn`).
- `godot/tests/zone_modes/identity_live.gd` — the graphical driver.
- `godot/zone_modes/**`, `godot/tests/zone_modes/**` — the delivered zone
  adapter/renderer/HUD this route reuses. The only change to the delivered
  files is the compact zone panel moving to y=104 in `zone_modes/hud.gd`, clear
  of the shared effect-quality line at y=70 that otherwise overlapped it.

Launcher routing and package closure are **not** this lane: the lead wires the
release path. This README documents the authority/self-contained acceptance the
launcher will call.

## Authority

`port/native-identity-zones/authority.mjs` mirrors the delivered native-arena
authority contract exactly, for one reviewed pair:

- `mapId = vermilion-fold`, `mode = domination` only (static allowlist;
  `host` frames naming another map or mode close the socket).
- The reviewed identity envelope is read from the static catalog entry, never a
  client path; `arena.objectiveZones` (exactly three) and `arena.teamSpawns`
  are strict-parsed before a Match exists.
- `createIdentityZoneMatch` reuses the scoped constructor-accessor pattern:
  the source `Match` constructor's first `this.arena = getMap(mapId)` assignment
  is intercepted **before** the floor query, nav graph, spawn pools, objective
  template and actor seats initialize, and returns the validated identity arena.
  No source registry is written and no completed Match is transplanted.
- Protocol v3 with `nativeArenaInput:1` epochs, FIFO bounded inputs (16 deep,
  250 ms TTL) and explicit cancellation, wire-ordinal events, snapshots every
  third tick, source results and a clean restart. Loopback-only WebSocket
  (`/` or `/native-zones`), no binary frames, no origin header, bounded
  outbound/frame/rate limits reused from `port/native-arenas`.
- HTTP is the documented readiness probe on `GET /` only.

Factory acceptance pins the identity contract the route consumes:

- the three zones are the authored fold points **in authored order**
  (`alpha/bravo/charlie`, exactly the source's mode ids) or a documented source
  navigation-node snap, at the authored radius, on walkable support above void;
- both `arena.teamSpawns` pools survive source normalization exactly, every
  published point is supported and unobstructed, and every seat spawns inside
  its authored team pool.

## Composition

`res://native_arenas/identity_zone_demo.tscn` composes the shared authoritative
session (presentation, first-person/ADS, pickups, combat/effects, GameHUD,
scoreboard, results/restart) with:

- `identity_maps/map.gd` for the identity recipe geometry/collision, loaded
  through the reviewed catalog renderer entry;
- exactly one shared identity environment (`native_arenas/identity_environment.gd`:
  one `DirectionalLight3D`, one `WorldEnvironment`, colors from the validated
  palette). The viewer's default sun/environment are freed in `_init`;
- `zone_modes/adapter.gd|renderer.gd|hud.gd` for the three zones. Rings,
  captions and HUD lines are read-only projections of the source snapshot.

There is no exploration camera and no map preview pose: the camera is only ever
`presentation.eye_position()` from the authority's local actor, matching the
delivered native/identity routes. `--mode=` accepts `domination` only,
`--map=` accepts `vermilion-fold` only, and the scene refuses the
smoke/lifecycle/setup/join flags that assume another composition.

## Run

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64

# full gate (node tests, arena suites, zone/HUD protocol gates, travel, capture)
node port/native-identity-zones/verify.mjs

# graphical acceptance alone, both evidence sizes
node port/native-identity-zones/capture.mjs --bots=2 --round-seconds=180 --score-limit=900

# grounded spawn-to-zone travel table
node port/native-identity-zones/travel.mjs

# owner playtest against the owned authority on the caller's display
node port/native-identity-zones/play.mjs --bots=2 --round-seconds=180
```

Launcher wiring (lead): `port/native-identity-zones/route.mjs` exports
`IDENTITY_ZONE_ROUTE` — experience id `identity-zones`, map `vermilion-fold`,
mode `domination`, scene `res://native_arenas/identity_zone_demo.tscn`,
endpoint path `/native-zones`, the authority factory and the bot/seconds/score
limits. `tests/route.test.mjs` pins that contract against the scene constants,
so a launcher/package copy cannot drift silently.

## Source discovery

- `game/mode-data.mjs`: `authoredPoints` maps `arena.objectiveZones` to the
  source mode ids in array order; `clearZone` then moves an obstructed centre to
  clear ground, and the `Match` constructor can snap a zone onto the nearest
  navigation node. This route therefore accepts exactly those two documented
  positions, never a guessed coordinate.
- `game/objectives.mjs`: actors participate within `<= radius` and
  `abs(actor.y - zone.y) <= 5`; multiple teams contest; an enemy occupant
  neutralizes the old owner before capturing; contested owned progress drains at
  0.75 rate; an **uncontested friendly occupant** of an owned zone earns `dt`
  team score (empty owned zones do not score). 5-second base capture.
- `game/core.mjs` snapshot: `objectives.zones` carry
  `id,x,y,z,radius,owner,captureTeam,progress,captureSeconds,contested`; the
  first constructor template may omit `contested`, so the adapter waits for the
  first ticked snapshot. `teamScores`, `time`, `config.timeLimit`, `over` and
  `winner` come from the same snapshot.
- Vermilion Fold's authored fold points are `(0,-17)`, `(0,0)`, `(0,17)` at
  radius 3.5 (y from terrain support); team pools are `(-27,-21/-27,21/-27,0)`
  west and `(27,-21/27,21/27,0)` east.

## Verification

`port/native-identity-zones/evidence/verify-report.json` records every step;
per-step logs sit beside it.

- `identity-zone-node-tests` — factory contract and a deterministic two-seat
  rules acceptance (capture, contest, neutralize, lose, recover, hold scoring
  from **both** teams, score-limit results, fresh restart) plus the live
  loopback authority (readiness, allowlist rejection, real capture/held score
  over the wire, source results, restart).
- The delivered arena suites (`port/native-arenas/tests/*`) stay green.
- Existing zone/HUD protocol gates stay green: `tests/zone_modes/unit.gd`,
  `tests/protocol/{input_queue,round_boundaries,local_lifecycle,game_hud_session,scoreboard_session,team_scores}.gd`.
- `travel-times` — 36 measured runs (3 authored spawns × 3 zones × 2 gaits ×
  both teams) from a real source Match, standstill start, timed until the actor
  enters the source radius. Evidence: `evidence/travel-vermilion-fold.json`.
- `graphical-capture` — private Xvfb, live authority, ordinary input events,
  framebuffer PNGs at 960x640 and 1280x800. The validator correlates every
  rendered marker and HUD line with the **same** authority snapshot, and the
  driver asserts the composition contract at runtime: exactly one world sun,
  one world environment and one current authoritative camera (viewmodel-rig
  nodes live inside an isolated `own_world_3d` SubViewport and are not counted
  as world lights). If the host kills the Godot process with a signal, that one
  size is retried once and the summary records `attempt`/`signal`; a real gate
  failure is never retried.

## Which receipt proves what

| property | proof |
| --- | --- |
| capture, contest, neutralize, lose, recover, both teams score, results, restart | `tests/match.test.mjs` — deterministic two-seat source acceptance with the exact per-zone ownership sequence |
| live wire: readiness, allowlist refusal, input epochs, capture + held score, source results, restart | `tests/authority.test.mjs` |
| rendered marker/HUD projection equals the source, evidence frames, one sun/environment/camera | `graphical-capture` + `validate.mjs` |
| spawn-to-zone travel and west/east symmetry | `travel.mjs` |

The live graphical run also reports whether the source bots took the ring the
driver deliberately left open (`lost`) and whether the driver retook it
(`recovered`). Those two flags are **observations, not gates**: a bot's decision
is not deterministic and a 180-second round may end before the churn completes.
The exact `0 -> 1 -> 0` ownership sequence is gated by the deterministic
two-seat acceptance instead, where both teams are controlled seats.

## Travel table (source seconds, standstill at the authored spawn)

| zone | gait | west spawns (min) | east spawns (min) | delta |
| --- | --- | --- | --- | --- |
| alpha (0,-17) | walk | 3.37 | 3.37 | 0.00 |
| alpha | sprint | 2.50 | 2.50 | 0.00 |
| bravo (0,0) | walk | 3.77 | 3.77 | 0.00 |
| bravo | sprint | 2.75 | 2.75 | 0.00 |
| charlie (0,17) | walk | 3.37 | 3.37 | 0.00 |
| charlie | sprint | 2.50 | 2.50 | 0.00 |

Full per-spawn rows (including the long rotations) are in the JSON evidence.
Both seats are pinned to one identical loadout so a character-speed difference
can never masquerade as map asymmetry; before that pin the measurement showed a
~9 % "asymmetry" that was entirely seat speed. With identical seats the west and
east rotations are byte-identical in time, which is the grounded balance claim
for this map.

## What is proven and what is not

Proven: source-backed construction and rules, live authority protocol, real
rendered projections correlated to source snapshots at both evidence sizes,
one world sun / one world environment / one authoritative camera, the
deterministic two-seat capture/contest/loss/recovery/results/restart sequence,
and the travel table above.

Not proven (stated rather than implied):

- No hardware GPU: all rendering evidence is software/`gl_compatibility` under
  Xvfb. Frame time, fill rate and real-window behaviour on the owner's machine
  are not measured here.
- No human play: the driver injects ordinary native input events, but a human
  has not played this route.
- Boss/endless equivalents do not apply: Horde owns those modes; this route is
  Domination only.
- The live graphical run's win/loss outcome depends on the source bot AI; only
  the presence of the events (capture, contest, loss, recovery, both teams
  scoring, results, restart) is gated.
