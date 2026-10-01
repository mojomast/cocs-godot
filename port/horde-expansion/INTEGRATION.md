# Horde expansion intake contract (branch `expansion/horde-robots`)

**Live acceptance status (2026-10-01):** the integrated normal-clock native-input
chain run restored both feeders and the switch pump and source-entered stage B,
then lost in wave six before the relief valve, stage C, or Warden. Full chain
and live boss are still unverified. See `ENGINE_CHECKPOINT.md` and the retained
`headless-chain.{log,json}` evidence for exact commands, receipts and the
test-only native upgrade-hotkey fix made after that failed run.

## Route registration for integrator

- New map ID: `blackwater-reclamation`, mode `horde`, display name **Blackwater Reclamation**.
- Global launcher/menu/package registration was integrated at `ad511d9c` on
  `expansion/mp-urban` and merged into this branch. Do not cherry-pick the
  equivalent Horde implementation commits again.
- Client scene: `res://horde_maps/blackwater_demo.tscn` with mandatory
  `--map=blackwater-reclamation --endpoint=ws://127.0.0.1:PORT --waves=1..30`.
- Native local authority: `port/native-horde/authority.mjs`, `HORDE_MAPS` now
  allowlists the ID. It loads only `godot/horde_maps/generated/blackwater-reclamation.json`
  and returns `hordeMapContract:{version:1,geometryHash,planHash}`. Client refuses
  mismatched geometry/plan hashes on each snapshot.
- Package closure additions: `port/native-horde/robot-roles.mjs`,
  `port/native-horde/blackwater-schema.mjs`, `port/native-horde/blackwater-director.mjs`,
  `godot/horde/ground_tells.gd`,
  `godot/horde_maps/blackwater_catalog.gd`, `blackwater.gd`,
  `blackwater_demo.gd`, `blackwater_demo.tscn`, generated JSON and
  `godot/horde_maps/art/blackwater-reclamation.glb`.
  Include editable Blender master `tools/godot-horde/masters/blackwater-reclamation.blend`
  and `blackwater_blender.py`, `blackwater.py`, `check_assets.py` under `tools/godot-horde/` in source
  distribution. Integrator owns shared launchers, package manifests, map menus
  and route discovery; no shared files are modified in this branch.

## Gameplay and provenance

The existing three source Horde maps, Nacre Engine and Cinderwake share the
same Horde demo factory: only snapshot NPCs with `isNpc===true` and a mapped
`npcType` receive one of the six campaign Blender robots. `npcType`, roles,
attacks, telegraphs, source hit geometry, upgrades, score, death events and
input protocol remain source-owned. Operators remain source operator visuals.
The Horde-only adapter adds `npcModel` on **outgoing snapshots and results**;
it does not mutate source modules. Its source `Match` subclass uses the existing
`hitScale` field for NPC chassis-sized hits (players remain at source hitScale
1), and on bounded wave ten uses source `spawnGroup` to field exactly one Warden
with genuine AI, attack phases, health, damage and death IDs. Existing
Harbinger champion timing is unchanged. The final easy live count is 13: the
source cap of 12 plus the one authored boss.
The Horde-only health-beat adapter now raises the source Warden `bossPhase`
counter at 60% and 25% health and emits `boss-phase`; the frozen source applies
its speed/damage/stomp profile on the next normal step. A controlled source-
damage test exercises all three profiles. Live wave-ten phase, telegraph and
voice receipt still require the reserved engine fixture below.

Blackwater uses the existing frozen-source `hordeArena` constructor intake and
Horde stage gates. Authored bounds are 440 × 380 source units. The server-side
director adds north/south feeder arming, a repair hold, and a relief valve;
progress, objective dependency, cache opening and notices are included in each
snapshot. Pump and valve completion call the source's real `resupplyHorde` for
health/armor/ammo and run-upgrade reapplication. Horde wave 3 and 6 transit
gates are still wholly source-driven.
This local Horde transport supports one human seat; no coop claim or simulated
team contribution is made. Standard maps remain wave-survival without story
objectives.

## Exclusive-slot engine acceptance (2026-10-01)

The generator and JS-only contracts can run without Blender/Godot:
`python3 tools/godot-horde/blackwater.py` then
`python3 tools/godot-horde/check_assets.py` and
`node --test port/native-horde/blackwater.test.mjs port/native-horde/robot-roles.test.mjs port/native-horde/robot-authority.test.mjs`.
Socket acceptance: `node --test port/native-horde/robot-network-census.test.mjs`
(~60 seconds; one real wave on every local Horde map, then a real movement/E
repair on Blackwater). Disconnect terminates the solo match; reconnect creates
a fresh round and input epoch. This route does not support late joining or
multiplayer teammates, and does not claim either.
Asset counts after the district/tunnel/spillway fidelity pass: five batched
Blender materials/meshes, 48,284 triangles, 2,133,344-byte GLB,
2,216,755-byte editable master; source recipe owns 220
collision blocks, 30 walkable surfaces, and 184 focused navigation hints. All
three stage anchor pools and four interaction stations are source-graph reachable
under closed, first-open and both-open floodgate masks. Real Match authority
steps cover the objective chain under a **controlled intermission fixture**;
this is not proof of natural combat completion.

The Godot 4.5.2 import succeeds. A shipping Blackwater renderer instantiation
finds the exact 252 source-aligned static bodies, all five Blender batches, a
five-metre physical gantry, and four visible authority-controlled station signs.
Native ray probes from **both sides** of both gates under masks 0/1/3 verify
real closed/open collision changes (`godot/tests/horde/blackwater_map.gd`,
24/24). This is a physics fixture, **not** proof of a successful natural wave
transit or softlock-free seven-wave playthrough. The source graph walk tests
also pass under all three masks.

Native loopback startup census uses the product scenes on all six Horde maps:
3/3 first-wave NPCs per route use the expected campaign robot meshes while
the human still uses `operator_visual.gd`. Source role/hit-scale tests cover
all six identities and the bounded wave-ten Warden; campaign native robot,
telegraph, and voice checks pass (447/447, 21/21, 238/238). A native full
wave-ten fight, Warden phase/voice event, and hit confirmation **have not**
been observed. The Blackwater combat-effects renderer was bound to the actual
Blackwater scene collision to avoid the unrelated semantic-map catalog error.

Evidence is outside the worktree at
`/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/horde/`:
eight real Godot rendered district/ground/gantry/tunnel screenshots
`blackwater-*.png`, first-wave native HUD image `blackwater-live-wave1.png`,
and `blackwater-live-gameplay.mp4` (17 seconds of real engine video; early
wave-one traversal with the actual HUD, **not** an objective completion clip).
`native-census.json`, `native-census-summary.log`, `inspection-refined.log`,
`import-refined.log`, `network-retest.log`, `node-scoped-suite.log` and
`live-attempt.log` preserve successes and failures. The scoped native-Horde
Node suite passes 64/64, including real loopback movement/E arming and
restoration of the north feeder and fresh-session reset/input epoch.

**Unmet acceptance:** Natural native-controlled full feeder → pump → valve
chain, stage B/C source wave transit, Warden live phases, and natural survival
balance remain unproved. The bounded Godot native runner
(`port/native-horde/blackwater-native-live.mjs`) produced a genuine first-wave
loss (`live-attempt.log`); under software X11 the live scene measured roughly
4 FPS at 1280×800 and control samples were repeatedly cancelled, so no
later-stage screenshot or chain success is claimed. The route's source-valid
fixture tests do not write outcome state; neither they nor standalone physics
probes should be represented as natural-play completion.

## Prepared native-input acceptance — **NOT YET RUN**

`node port/native-horde/blackwater-headless-live.mjs chain` and the equivalent
`boss` invocation are reserved for a future **explicit exclusive Godot slot**.
They instantiate the shipping Blackwater scene with a test-only headless focus
seam, then send ordinary InputEventKey/MouseButton/Motion through
HordeControls.sample, HordeClient.send_controls and the normal-clock local
authority. The seam only replaces OS window focus/mouse capture unavailable in
headless; it does not replace client sampling, source input epochs, FIFO TTL,
combat, scoring, actor positions, inventory, health, stage or director state.
The fixture uses the real easy/10-wave product config and `debug:false`.
`chain` requires four restored source events, native progress HUD/sign receipts,
two actual stage-entered events, gate body revisions and source resupply.
`boss` continues the same normal waves until the wave-ten Warden shows source
phases 1–3, a boss ground telegraph and a native voice asset scheduled for the
Warden actor. Both are bounded failures if these conditions do not occur; neither
is human playtime evidence. Native event/input observations are written to
`headless-chain.{log,json}` or `headless-boss.{log,json}` in the evidence directory.

The rendering bottleneck and source expiry are distinct: InputBuffer keeps its
250 ms TTL. Software X11 sampled roughly every 250 ms at 4 FPS, crossing that
threshold on slow frames. The headless fixture records real `stale-input`
resets, cancelled frames and largest input gap instead of relaxing the product
contract. The scoped JS-only pregrant suite passes 65/65 (log:
`node-static-pregrant.log`). The new GDScript fixture has **not** been imported
or parsed by Godot yet; resolve any engine parse/runtime errors under the next
explicit grant. No headless success is claimed until that engine grant and run.
