# Acceptance and retained limitations

Base `642c615`, source lock `51289b79c627a26a381ba556b92bab71f93f3732`, Godot `4.5.2.stable.official.6ce3de25a`. No source/rule/transport/shared-session edits. Native implementation is a standalone optional scene with new world-prefixed helpers.

## Accepted checks

**Final full verification:** [`1790044868397163098/results.json`](evidence/1790044868397163098/results.json) passes semantic export, import, all 18 contracts and both final doorway-route cases. This run uses the final implementation, runner and observer versions. Both final walk screenshots were read directly: [Asterion](evidence/1790044868397163098/asterion-relay-cocs/walk.png) clearly shows Archive Gate and Oculus architecture; [Monsoon](evidence/1790044868397163098/monsoon-foundry-cocs-coop/walk.png) shows Filter Court, close authorized enemies and real DEAD/respawn status following arrival.

| Final case | Native duration | Maximum displacement | Target distance at stop | Exact render/wire samples |
|---|---:|---:|---:|---:|
| Asterion / cocs | 18.235 s | 55.829 m | 0.252 m | 444 |
| Monsoon / cocs-coop | 18.668 s | 61.370 m | 0.186 m | 454 |

Each final case passes 17 native checks and all eight external socket/render checks. Both stop at the public front node using real key input, with ordinary source collision and no action commands. The local capture participation and detailed death/respawn trace discussed below refer to the explicitly linked earlier runs, not a claim that every repeated walk personally captures the node.

[Full verification run](evidence/1790044426485331514/results.json): semantic export/source verification (nine locked maps), Godot import, **18 detached contract checks**, Asterion PvP walk and Monsoon co-op movement/release checks all pass. Tests exercise actual JSON float wire decoding, camera source position, missing wallets, received-actor-only presentation/removal, focus/look gating, stale gating, missing projection, roster revocation/reassignment, malformed/duplicate actors and malformed public objectives, results, restart and connection-error reset.

The initial Monsoon direct-bearing walk encountered a real HQ wall. A targeted observer-route improvement uses three static authored doorway waypoints, exclusively through native key/mouse input. The playable scene has no autopilot. [Targeted Monsoon rerun](evidence/monsoon-portals-1790044670/monsoon-foundry-cocs-coop/result.json) passed and reached Filter Court. A later Asterion run with a different ordinary spawn also encountered a wall on a direct bearing, so the final observer uses the shared central HQ doorway on both maps.

| Case | Wall-clock native run | Own displacement from start | Closest target distance at stop | Render/wire matched samples |
|---|---:|---:|---:|---:|
| [Asterion / cocs](evidence/1790044426485331514/asterion-relay-cocs/result.json) | 16.60 s | 55.939 m | 1.550 m | 401 |
| [Monsoon / cocs-coop, doorway route](evidence/monsoon-portals-1790044670/monsoon-foundry-cocs-coop/result.json) | 18.68 s | 58.625 m | 0.105 m | 445 |

Each has **17 native checks, zero failures**, plus eight external socket/render checks. Both use ordinary peer 1 / actor 0 / round 1, host-configured botCount=2, default source tick/snapshot cadence, default speed/gravity/damage, private Xvfb and loopback PORT=0. No order/economy frame was sent. The source default config, exact native command, hashes, endpoint and display are retained in each manifest. The runner's audit cap was added after the full run; the final targeted Monsoon run includes that version.

### Input receipt versus observed application

`wire.jsonl` contains only allowlisted recipient/socket fields: input changes and periodic sequences, actor ACK, own x/y/z/yaw/pitch/health/team/REQ, recipient actor poses, own-budget keys and public nodes/capture events. It never accesses `game.rooms` or omniscient `Match.snapshot()`. `native.log` separately records real camera and visual actor anchors with the exact applied snapshot sequence.

All accepted sampled camera coordinates equal the matching recipient's `(x, y + eyeHeight, z)` within 0.0001 float32 tolerance. All rendered actor IDs and anchors equal that same recipient snapshot's actors at `(x, y + 0.9, z)`. No interpolation/extrapolation or missing-actor construction is used. For example, Asterion's final source feet `(-53.512, 0, -7.658)` correspond to native camera `(-53.512001, 1.450000, -7.658000)`.

W drives measured displacement. Escape releases, subsequent held W cannot recapture and produces a stationary source pose after settling; release W plus a fresh click resumes movement. A/S/D also pass through physical-keycode events. The 60 Hz shared input sender and current server routing are unchanged. These are **engine input-path tests**, not an OS keyboard/mouse or human playtest.

### Public objective outcome, precisely scoped

- **Asterion:** own actor stopped at `(-53.512,0,-7.658)`, 1.550 m from `front-0` at `(-52,-8)`. Source emitted `cocs-capture`, team 0, participants `[0,2]`; owner changed to 0. This proves local participation alongside a bot. `orderCompleted=true` came from source automatic duty-order behavior; the native client issued no HOLD. Do not attribute the capture solely to the local walk.
- **Monsoon:** own actor reached `(-51.895,0,12.002)`, 0.105 m from `front-0` at `(-52,0,12)`, whose recipient radius is 14. The capture event named participant `[1]`, **not actor 0**, before arrival. This proves local approach to already captured public ground, not a local capture.
- Monsoon then delivered real close-range enemy damage, death and respawn. Correlating `native.log` with recipient health gives **57 dead-state samples, zero with captured pointer**. The final healthy respawn at `(-108,0,5)` still had captured=false. No native reactivation or teleport was injected.

### World identity and screenshots read directly

The normal existing viewer's full geometry is retained: Asterion **164 blocks / 4,992 support triangles / seven landmarks**; Monsoon **186 blocks / 5,072 support triangles / seven landmarks**. Tests locate every authored landmark label at source `(x,y+0.5,z)` and verify total geometry counts. Public node-marker anchors are separately recorded; PvP's omitted y/r do not become invented gameplay values.

The following actual viewport PNGs were opened directly with the image-capable read tool:

- [Asterion startup](evidence/1790044426485331514/asterion-relay-cocs/startup.png): source-height view from Flight Control, blue/purple architectural palette, visible authorized teammate and clear compact HUD.
- [Asterion Archive Gate walk](evidence/1790044426485331514/asterion-relay-cocs/walk.png): courtyard/oculus buildings, authorized actor visible, owner Team 0 at 1.6 m, no oversized nearby label.
- [Monsoon startup](evidence/1790044426485331514/monsoon-foundry-cocs-coop/startup.png): green Watershed architecture, teammates, source supply presentation and courtyard doorway.
- [Monsoon doorway-route arrival](evidence/monsoon-portals-1790044670/monsoon-foundry-cocs-coop/walk.png): Filter Court at 0.1 m, HP 59 and inherited damage feedback; source-authorized blue enemies occupy the close foreground. Their size is real source proximity, not a marker overlay.
- [Monsoon released/respawned](evidence/monsoon-portals-1790044670/monsoon-foundry-cocs-coop/released.png): source returned actor to HQ, HP 100, pointer released, visible native architecture and source SMG supply.

This is the current native semantic presentation and generic native character geometry, not a new art-parity claim. Distant landmark/objective text can overlap; nearby objective information remains readable in the compact HUD.

## Retained failures and bounded attempts

1. [Early detached failure](evidence/early-contract-failure.md): team/owner validation used type-sensitive Array membership, rejecting JSON float identities. Diagnostic showed `0.0 in [0,1]` false. Corrected to the existing transport's wire-integer/numeric comparison pattern; 18 contract checks pass.
2. [First graphical Asterion attempt](evidence/1790044271783212385/asterion-relay-cocs/result.json): native walk/release/capture worked, but the external exact-coordinate checks failed on one teardown sample after the client identity became -1 while the detached observer still saw the last pose. Projection-clear now releases and clears pose immediately. The actual gameplay samples matched; the failed overall result remains retained. Its [walk screenshot](evidence/1790044271783212385/asterion-relay-cocs/walk.png), read directly, exposed a giant near-node label, corrected by yielding to the HUD within 10 m.
3. [Initial accepted Monsoon movement](evidence/1790044426485331514/monsoon-foundry-cocs-coop/result.json): 21.373 m displacement, stopped at the actual HQ wall, still 40.912 m from Filter Court. Its wall-facing screenshot was read directly. This was valid movement/release evidence but not successful approach. The targeted doorway rerun above resolves that route limitation without changing collision or movement rules.
4. [Additional bounded Asterion movement](evidence/final-asterion-1790044800/asterion-relay-cocs/result.json): with a different normal spawn, the direct-bearing route stopped at a wall after 22.846 m, 37.984 m from Archive Gate. All 17 input and eight wire checks passed; capture events named bots only. Its wall-facing screenshot was read directly. This motivated applying the same authored doorway waypoints to both maps in the observer; no gameplay changes were needed.

## Cleanup and scope

Every case has `cleanup.json`: HTTP port closed, native child exited, temporary XDG directories removed. `xvfb-run` owns and shuts down the private display. [Final cleanup audit](evidence/cleanup.json) checks all recorded ports and runtime processes in this isolated worktree. The inherited input/session error and results handling remain reused; detached tests establish unavailable-state gates, while the live co-op run additionally witnessed a real death/respawn.

No accelerated ticks, time-limit overrides, wallet overrides, authoritative injection, game-mode/menu additions, full strategy victory or co-op campaign completion are claimed. Focus/stale/owner-loss assertions are detached contract tests; no live network stall or OS focus-loss scenario was induced. The current source visibility filter still exposes enemy positions; rendering is strictly recipient-bounded, and the HUD never displays enemy wallets.

Exact standalone play commands and the **unapplied** `--experience=lattice-world` common-launcher suggestion are in [README](README.md). Existing `--experience=lattice` continues to mean command board.
