# Identity Horde (Nacre Engine) — delivery

Branch: `port/godot-destinations` (worktree `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`).
Pinned engine: `4.5.2.stable.official.6ce3de25a`
(`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`).
Per-run source/engine hashes and exact argv: `evidence/<run>/launch.json`.

## What was delivered

1. **Reviewed static identity hook** in `port/native-horde/authority.mjs`
   (`IDENTITY_MAPS`, `HORDE_MAPS`, `readIdentityMap`,
   `validateIdentityEnvelope`, `createHordeMatch`, `identityArenaHash`). One
   frozen allowlist entry (`nacre-engine`), one literal package-relative path,
   strict envelope + canonical-arena-hash validation, reviewed constructor
   accessor, post-construction invariants. Loopback-only transport, single
   client, input epochs, retained-object event cursor, bounded messages and the
   single-human contract are unchanged. See `README.md` for the review list.
2. **Identity Horde composition**
   `res://native_arenas/identity_horde_demo.tscn` / `.gd`, loading Nacre Engine
   through `res://identity_maps/map.gd` and installing exactly one sun and one
   `WorldEnvironment` through `identity_environment.gd`, while inheriting the
   shared session presentation, first-person/ADS, pickups, combat feedback,
   effect stack, Horde strip, GameHUD and scoreboard.
3. **Acceptance lane** `port/native-identity-horde/` — runner, validator,
   corridor measurement, tests, evidence. Four accepted runs on the final code,
   plus a retained bounded-window failure and the full attempt history.
4. **Test surfaces** `godot/tests/horde/identity_live.gd|.tscn` (real-input
   observer/steering), `godot/tests/horde/identity_composition_test.gd` (offline
   composition gate), `port/native-identity-horde/identity-horde.test.mjs`
   (11 adapter/hook/measurement tests).

## Acceptance results (accepted runs, final code)

| Scenario | Run | Resolution | Result |
| --- | --- | --- | --- |
| startup | `evidence/2026-09-22T18-29-01-418Z-startup` | 960×640 | PASS — real wave 1 (SWARM, 3 enemies), default ten-wave target, 209 correlated snapshots, clock 10.50 s source / 10.51 s wall |
| waves | `evidence/2026-09-22T18-43-27-864Z-waves` | 960×640 | PASS — 4 waves (3/4/5/7 enemies: SWARM, MIXED, ARTILLERY, SHIELDED), 3 wave clears, 2 upgrade offers, **victory**, clean restart |
| defeat | `evidence/2026-09-22T18-32-32-209Z-defeat` | 960×640 | PASS — 3 natural deaths, lives 3→2→1→0, **defeat**, clean restart with 3 lives and no auto-capture |
| peak | `evidence/2026-09-22T18-33-51-321Z-peak` | 960×640 | PASS — waves 1–5 (up to 10 simultaneous NPCs), 4 clears, cadence measured |

Retained failures in the same lane (logs kept, PNGs pruned):
`evidence/2026-09-22T18-29-27-477Z-waves` (a second identical 1280×800-primary
attempt hit its bounded window with zero clears — the automated aimbot at ~9 fps
did not finish wave 1) and `evidence/2026-09-22T18-39-22-522Z-waves` (the
integrating tree had a third-party parse error in an uncommitted
`godot/moth_scenery/scenery.gd` while another lane edited it; the identical
command passed at 18:43 once that file parsed). The accepted waves run therefore
uses 960×640 as its primary capture size with 1280×800 alternates; both product
sizes are present for every captured tag, which the validator enforces.

Per-run validator output is `evidence/<run>/validation.json`; the raw wire,
stdout/stderr and both-resolution PNGs are in the same directory.

Provenance note: every accepted run records its own base revision and the
SHA-256 of every lane-owned file plus the arena recipe in `launch.json`. All
four accepted runs share identical bytes for the adapter, the composition, the
observer, the runner/validator/measurement and
`godot/identity_maps/generated/nacre-engine.json`. The art lane's
`godot/identity_maps/map.gd` changed between the first and the last accepted
run (hash recorded per run); it is the Godot renderer/collider builder, not the
arena recipe the corridor numbers come from, so the measured geometry is
identical across the set.

**Waves detail** (`2026-09-22T18-43-27-864Z-waves`): wave clears paid score
94 → 207 → 338, with source `horde-wave-cleared` and `horde-resupply` events
(each clear resupplied the player); the source published pending upgrade choices
after the wave-3 clear and the wave-4 start, and the composition projected them
as `UPGRADES AVAILABLE · selection unsupported`. Victory at wave 4 / 4 with 19
kills, `winner 0`, then Enter produced a fresh round (rounds 2, lives 3, no
automatic capture). 2353 recipient-correlated snapshots, 1660 input receipts,
1500 samples stepped, ACK high-water 1651, source clock 116.75 s vs wall
116.76 s.

**Defeat detail** (`2026-09-22T18-32-32-209Z-defeat`): three genuine source
death events for actor 0 (distinct enemy killers), the source life sequence
2 → 1 → 0, results `phase: 'lost'`, `winner: 1`, then a clean restart. The
observer fired no shots at all in this scenario: the defeat is the enemies'
doing.

**Peak-load detail** (`2026-09-22T18-33-51-321Z-peak`): waves 1–5 with
3/4/5/7/10 simultaneous NPCs, 4 wave clears (score 94 → 488), 3 upgrade offers
and 27 kills; 2670 recipient-correlated snapshots, 2693 input receipts, 2515
stepped samples, 2651 applied snapshots (high-water), source clock 132.78 s vs
wall 132.77 s. Frame cadence, measured with `Engine.get_frames_per_second()`
sampled twice a second: median **18 fps**, average **19.8 fps**, minimum 3 fps
(session start), and **16.4 fps while 10 NPCs were alive** (5 samples at peak).
This is software rendering (`llvmpipe` through OpenGL compatibility under a
private Xvfb at 960×640, no GPU, no vsync): the numbers are honest for this
environment and are not a hardware claim. The run ended in a genuine defeat on
wave 5 (3 deaths, 0 lives) rather than the ten-wave target; the champion wave
and endless were not reached.

## Enemy clearance and approach widths (deliverable 3)

Measured with the capsule the source actually moves —
`game/data.mjs RULES = {radius 0.42, height 1.8}`, applied through
`game/core.mjs obstructed()`, which is a real capsule test (blocks expand by the
radius; terrain walls require the actor's full height to overlap). Enemy
`npcProfile.scale` (0.72 husk … 1.32 brute) is written by `enemy-types.mjs` and
read only by the presentation layer — no movement, spawn, nav, ray or damage
path consumes it, so clearance must not be sized from display scale.

Static analysis of the shipped recipe (`evidence/nacre-corridors.json`,
SHA-256 `b3636e…9feb4`):

- nav graph the source bakes: 78 nodes, 136 accepted edges; **0 edges below the
  capsule**; narrowest accepted edge channel **4.07 m** at (−24, −23.25);
- all six authored spawns sit in **6.0 m** of free space and are reachable; the
  narrowest spawn→centre approach channel is **5.48 m** at (−12, −11.5);
- the nav bake itself is stricter than the capsule (nodes reject below 0.65 m
  probe, edges below 0.52 m), i.e. the graph admits nothing narrower than 1.04 m;
- a 1 m footprint scan finds 94 grid points below capsule clearance — decorative
  pockets between separate vault feet (narrowest 0.36 m), none of them on a graph
  route.

**The corridor the NPCs actually traversed**: sampling every accepted NPC
position in the runs (snapshot rate, so this is an upper bound on the tightest
passage):

| Run | Narrowest channel traversed | Closest capsule clearance | Contact instants | NPC samples |
| --- | --- | --- | --- | --- |
| waves | 2.07 m (husk, wave 4) | 0.420 m | 21 | 5177 |
| defeat | **1.31 m** (husk, wave 1, south-east corner) | 0.420 m | 682 | 3063 |
| peak | 2.02 m (husk, wave 1) | 0.420 m | 9 | 5512 |
| startup | 4.00 m (husk, wave 1) | 1.018 m | 0 | 213 |

So the measured minimum corridor the NPCs actually traversed is **1.31 m**
(defeat run, the corner between the boundary and a vault foot, where the player
walked into the enemies), against a **0.84 m** capsule requirement — 0.45 m of
margin — while the tightest corridor the nav graph itself uses is 4.07 m.
Closest-approach samples of 0.420 m are the capsule touching geometry, not a
corridor: at those same points the opposite side measured 2.8–3.6 m. Sampling is
at the snapshot rate, so the true tightest passage could be narrower than
reported; the static graph bound (every accepted edge ≥ 1.04 m, measured
narrowest edge 4.07 m) is what the routing itself guarantees.

## Rendered evidence (inspected, not just captured)

Both product sizes are in every run (validator enforces that each tag's primary
is captured at the launch resolution and its `-alternate` sibling at the other
size):

- mid-wave with HUD: `.../18-43-27-864Z-waves/gameplay-wave3.png` (960×640) and
  `gameplay-wave3-alternate.png` (1280×800) — Nacre Engine arches, first-person
  Pulse Rifle, two `HUSK 30` labelled enemies, strip `HORDE · WAVE 3 / 4 · WAVE ·
  ENEMIES 5 / 5 · LIVES 2 · SCORE 207 · ARTILLERY`, health/armor 100/100;
- peak load: `.../18-33-51-321Z-peak/gameplay-wave5.png` and
  `gameplay-wave5-alternate.png` — `ENEMIES 10 / 10`, `UPGRADES AVAILABLE ·
  selection unsupported`, first-person weapon;
- victory/results: `.../18-43-27-864Z-waves/gameplay-results.png` and
  `-alternate` — `ROUND COMPLETE`, shared scoreboard `Nacre Engine · Horde`,
  18 frags, strip `WAVE 4 / 4 · VICTORY`;
- defeat: `.../18-32-32-209Z-defeat/gameplay-defeat.png` and `-alternate` —
  `WAVE 1 / 1 · DEFEAT`, `LIVES 0`, `ROUND COMPLETE` scoreboard with the local
  actor on 3 deaths in red.

This lane inspected the images itself. They were not accepted by a human; note
also that the Horde scoreboard layout belongs to the UI lane and may change
under this evidence. Shared presentation bytes outside this lane's ownership
(for example `godot/moth_scenery/**`, `godot/world/environment_style.gd`) are not
hashed in `launch.json`: they were whatever the integrating tree carried at run
time, and another lane briefly broke that closure with an uncommitted parse
error after the first accepted set (retained as the 18:39 attempt above).

## Executed commands (final code)

```sh
node --test port/native-horde/test.mjs port/native-horde/input-buffer.test.mjs \
  port/native-horde/repair-regression.test.mjs port/native-horde/event-cursor.test.mjs \
  port/native-horde/npc-kills.test.mjs port/native-identity-horde/identity-horde.test.mjs   # 61 pass
godot --headless --path godot --script res://tests/horde/test.gd                            # 15 checks
godot --headless --path godot --script res://tests/horde/identity_composition_test.gd       # 22 checks
godot --headless --path godot --script res://tests/horde/controls_test.gd -- --vectors=…    # passes
godot --headless --path godot --script res://tests/horde/layout_test.gd                      # 2 checks
godot --headless --path godot --script res://tests/protocol/control_safety.gd                # passes
godot --headless --path godot --script res://tests/protocol/game_hud_session.gd               # passes
godot --headless --path godot --script res://tests/protocol/scoreboard.gd                    # passes
godot --headless --path godot --script res://tests/protocol/scoreboard_session.gd             # passes
GODOT_BIN=… node port/native-identity-horde/run.mjs --scenario=startup
GODOT_BIN=… node port/native-identity-horde/run.mjs --scenario=waves --waves=4 --resolution=1280x800
GODOT_BIN=… node port/native-identity-horde/run.mjs --scenario=defeat --waves=1
GODOT_BIN=… node port/native-identity-horde/run.mjs --scenario=peak --waves=10
node port/native-identity-horde/validate.mjs port/native-identity-horde/evidence/<run>   # PASS
node port/native-identity-horde/measure.mjs port/native-identity-horde/evidence/nacre-corridors.json
```

Every run's `summary.json` records reaped/absent native and Xvfb children, a
closed listener, zero sockets and a removed private XDG tree; `validate.mjs`
re-checks the same hygiene, so a leaking run cannot pass.

## Integration the lead must wire (not applied here)

1. **Launcher routing**: `--experience=horde --map=nacre-engine` should start
   the same loopback Horde authority and launch
   `res://native_arenas/identity_horde_demo.tscn` instead of
   `res://horde/demo.tscn`. `IDENTITY_MAPS`/`HORDE_MAPS` are exported so the
   options module can allow the map without a second allowlist.
2. **Package closure**: the identity route needs
   `port/native-horde/authority.mjs` (hook included), `port/native-horde/input-buffer.mjs`,
   `godot/native_arenas/identity_horde_demo.{gd,tscn}`,
   `godot/identity_maps/map.gd`, `godot/native_arenas/identity_environment.gd`,
   `godot/native_arenas/catalog.gd`, `godot/horde/*`, the shared session/HUD/
   combat dependencies, and `godot/identity_maps/generated/nacre-engine.json`.
   `tools/godot-package/discover.mjs` classifies the adapter inventory from the
   static import graph — the hook adds no new runtime module by design, but the
   identity JSON is a runtime data read the package lane must ship.
3. **Release allowlists**: `godot/identity_maps/generated/*.json` already needs
   to be in the PCK for the identity Deathmatch route; the Horde route reuses it.

## Remains open (stated plainly)

- **Boss**: wave 9 (champion modifier in a bounded run) was not reached; the
  champion modifier, Warden/Harbinger phases and stomp/summon behaviour are
  therefore not accepted on Nacre.
- **Endless**: not exposed by the adapter contract (`validateConfig` accepts a
  bounded 1–30 wave target only). `HORDE_MAPS` has no endless entry.
- **Full ten-wave completion**: not reached. The ten-wave default is exercised at
  startup only; the longest accepted run reached wave 6 with 5 clears.
- **Upgrade selection** remains unsupported (protocol v3 has no command); only
  the projection of the source's pending choice is verified.
- **Frame cadence**: measured on software rendering only.
- **Human feel/audio/focus/hardware**: not accepted; all runs are automated with
  Dummy audio on a private Xvfb display.
- **Scoreboard layout**: owned by the UI lane; this lane does not claim its
  pixels beyond the offline layout gate and its own screenshots.
