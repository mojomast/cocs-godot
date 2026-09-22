# Native sports usability polish

Branch: `subagent/native-sports-polish`, isolated worktree `/tmp/opencode/cocs-native-sports-polish`, base `a34054e6b24ff63189e8e464f78d6dd809f7c334`.

## Changes and integration

- `godot/sports/hud.gd`: passive native top summary and bottom input/status panels, readable map/mode, rounded countdown, integer lap and **one-based** next checkpoint, labeled Red/Blue integer scores, speed magnitude in m/s. Missing fields display an em dash. Engaged, released, unfocused, unavailable vehicle, delayed snapshots, setup, error, and results instructions reflect demo eligibility. Race alone advertises R; F5 appears only after the actual results event. Error directs relaunch because this demo disconnects on failure.
- `godot/sports/demo.gd`: supplies accepted presentation state to HUD and configures camera geometry after map load. `demo.hud.text` remains a string summary updated each frame. `observe.gd` inspects accepted vehicle, render position, camera and input gate, and never reads HUD text; it is untouched. `controls.gd` is untouched.
- `godot/sports/chase.gd`: read-only source-box clearance with an 8 m XZ spatial grid, 0.35 m conservative padding and a small face epsilon. All exported boxes are included, including boards, rail runs, buildings, stands, mast and column boxes. The camera is clipped from a vehicle-relative 1.2 m-high anchor **after** eye interpolation. This prevents smoothing through solids; safety shortening is immediate, recovery uses the existing exponential damping. The query segment is bounded to a 10.3 m boom. Heading remains +Z, independent of velocity; yaw wrap uses Cartesian direction, reset/teleport reseeds the rig.

Cache: one selected map, built once and retained over round resets; replaced on map change. Hard bounds: 4,096 boxes and 32,768 grid memberships. Oversize geometry is explicitly rejected by demo startup rather than silently truncated. A normal follow query visits at most nine grid cells and deduplicates their box indices; candidate count is available for tests. No physics bodies or authoritative changes.

Source references: `game/destination-sports-maps.mjs` (actual Ion/Aurora geometry), `game/race.mjs`, `game/soccer.mjs`, `game/race-ui.mjs`, and `game/team-presentation.mjs`. Destination stadium board inner faces are at z ±24, not the legacy Puma Pitch's ±18.5. Source team 0 is Red, 1 is Blue. Lap starts at 1; nextGate starts at 0 and display adds 1.

## Focused verification

Run from the isolated worktree:

```sh
python3 -B godot/tests/sports/run_polish.py
```

The helper copies Godot/game/server into its own `/tmp/opencode` temporary directory, reads the primary dependencies through a symlink, exports locked semantic data into the copy, and uses pinned Godot 4.5.2. It runs the existing 27 controls assertions, existing 19 Puma assertions, and new focused synthetic presentation regressions. Then four short real standalone demo sessions cover both maps at 960×640 and 1280×800, on an owned private Xvfb (`-nolisten tcp -nolisten unix`; Linux abstract socket transport) and OS-assigned loopback servers. Only physical key events are injected into Godot. No state, clock, server or rules injection. Screenshots log the accepted sequence, ACK, vehicle, camera, input status and HUD summary. Sanitized existing server observer output records receipt/state/cleanup. This is focused visual/usability evidence, not a replacement for the previous driving acceptance matrix or a new live race/goal/restart acceptance.

Synthetic tests exercise actual exported Aurora board and Ion rail obstruction, unoccluded target/eye, steady-wall stability, gradual recovery, reverse, yaw wrap, reset, immutable map/cache budgets, segment edge cases and HUD partial/transition states. Live screenshot capture checks render position against accepted state and checks that HUD controls are passive and labels remain within the viewport.

### Final executed checks and inspected images

Final accepted run: `evidence/80fca080-7d19-408e-88c4-80cdf9f4763a/`.

- Pinned `4.5.2.stable.official.6ce3de25a`, Compatibility Mesa llvmpipe, Dummy audio.
- Existing sports controls **27 passed**; existing Puma **19 passed**; new polish **41 passed**, zero failures. Editor/import and all native logs passed the helper's script/engine-error scan.
- Four actual normal-rate private graphical sessions passed, each capturing countdown, driving, **obstructed near-wall**, and released views. Recursive passive-control and label-within-viewport assertions ran on every capture. No synthetic state or timing injection in these sessions.

| Map | Window | Received input packets | Most box candidates in captured frames |
|---|---|---:|---:|
| Ion Speedway | 960×640 | 234 | 2 |
| Ion Speedway | 1280×800 | 227 | 4 |
| Aurora Stadium | 960×640 | 287 | 4 |
| Aurora Stadium | 1280×800 | 237 | 4 |

All four servers report closed with zero sockets. All owned processes were reaped and the private copied project was removed. The candidate figures are observations at capture times, not a performance benchmark or an all-frame maximum.

Direct PNG inspection succeeded using the file/image reader. Inspected **all four** final `near-wall.png` files, plus final Aurora 960 countdown and Ion 1280 released. Titles, counters, speed, status and instructions fit. Soccer's ball remains visible; near-wall camera pull-in makes the vehicle larger and its lower rear can sit beneath the bottom HUD panel. No wall interior is visible at the eye. A separate read-only Node audit of all 16 capture coordinates against current authored boxes with the same 0.35 m padding found zero eye-inside-box hits (388 Ion boxes, 52 Aurora boxes). This is point clearance, not full-frustum verification.

Screenshot paths relative to this directory:

- `evidence/80fca080-7d19-408e-88c4-80cdf9f4763a/ion-speedway-960x640/near-wall.png`
- `evidence/80fca080-7d19-408e-88c4-80cdf9f4763a/ion-speedway-1280x800/near-wall.png`
- `evidence/80fca080-7d19-408e-88c4-80cdf9f4763a/aurora-stadium-960x640/near-wall.png`
- `evidence/80fca080-7d19-408e-88c4-80cdf9f4763a/aurora-stadium-1280x800/near-wall.png`

Each case folder also contains `countdown.png`, `driving.png`, `released.png`, `native.log`, `server.log`, and sanitized `wire.json`; root contains test/import/export logs and `summary.json`. Existing original live driving acceptance remains the earlier Puma revision/evidence. No new completed lap, goal, source reset, results/restart, OS focus or human driving acceptance is claimed by this polish run.

### Retained earlier attempts

- `evidence/f95c5683-c451-4989-acc8-ffe4d1b827a7/`: existing controls/Puma tests passed; the new synthetic wall fixture initially used legacy Puma Pitch coordinates instead of destination Aurora coordinates and correctly failed three assertions before gameplay. Corrected the fixture against `destination-sports-maps.mjs`; this is not accepted evidence.
- `evidence/968d1011-9250-4a67-9f38-a5fc9fa6acae/`: all 40 then-current polish assertions and four real graphical sessions passed. Directly inspected Ion 960 countdown, Ion 1280 driving, Aurora 960 obstructed and Aurora 1280 released PNGs. Friendly text fits, the ball and vehicle remain visible, and Aurora's obstruction brings the eye close to the car without entering the board. This preceded the added Ion-wall assertion and recursive passive/layout checks. Its Ion path did not obstruct the boom; the final observer turns the reverse approach toward Ion's outer rail to exercise that too.

## Limits

- Boxes only: terrain support triangles, decorative roof/arch spans, prop meshes, vehicles and the ball are not occluders. Both selected sports arenas have flat implicit support; no terrain triangle solver was added. This is not a general replacement for shared-world collision.
- Padding protects the eye/near-plane approximately, not a swept camera frustum. It does not guarantee every screen corner or the entire look-ahead target is unobstructed. At extremely tight clearances the camera may approach the vehicle; no alternate orbit or full depenetration solver is attempted.
- Assumes the authoritative vehicle anchor is outside static solids. An invalid/embedded anchor cannot yield a guaranteed external eye along the same segment. Safety shortening on a newly encountered wall is immediate; it cannot always be visually smooth without clipping. Ordinary recovery and unobstructed movement remain damped.
- Map cache keys assume the locked geometry for a map ID remains immutable during a demo session.

No renderer/shared world/UI/network/session/launcher/verifier/source/dependency changes, no external source-instance writes, no merge/push.
