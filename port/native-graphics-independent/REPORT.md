# Independent production-scene usability and graphics review

## Result and severity assessment

The five integrated production scenes launch and render through native Linux
X11. The three maps retain their production eye-level cameras and controllers.
Particle and shader controls respond through the actual native window without
opening a popup. **No confirmed blocking, high-, or medium-severity defect was
found in the exercised controls or inspected views.**

Final evidence contains **58/58 passing checks**, five clean process exits,
and **18 directly inspected PNGs** across 960×640 and 1280×800.

### Withdrawn visual concern — shader sidebar at 960×640

A preliminary visual reading suggested the Reactor Flow notes were clipped.
That concern was **withdrawn after measurement and direct reinspection**:
the production sidebar rectangle is `[676, 118, 269, 382]`, ending at **x=945**
inside the 960-pixel viewport. The sentence and border fit. The actual right
margin is 15 pixels, smaller than the layout's nominal 28 pixels, but no content
is lost. [960×640 Reactor Flow](evidence/shader_lab/capture-01.png) and
[1280×800 Reactor Flow](evidence/shader_lab/capture-05.png) provide the evidence.
No runtime fix is requested for this withdrawn concern.

No runtime changes were applied by this reviewer.

## Native input and camera review

Inputs are XTest-generated OS keyboard/mouse events delivered to the real
Godot X11 window. `xdotool` is absent. This is **actual native X11 interaction
with synthetic OS input**, not headless testing or engine-injected input.

- **Prism Foundry:** actual `res://showcase/player.gd` attached.
- **Aurora Basin / Cinder Array:** actual `res://exploration/walker.gd` attached.
- All map images use the current production player camera, original eye height,
  and original spawn followed by short, normal-rate W/A/D movement and a small
  relative mouse look. No teleports, photo views, alternate controllers, or
  camera-transform mutation were used by the fixture.
- Escape is tested while **D remains held**. Click recaptures the pointer.
- Focus is moved to the X11 root while **A remains held**, after a periodic
  observer sample confirms real lateral velocity. The subsequent unfocused
  interval checks horizontal position stability; focus regain plus click
  recaptures the same production window.

`evidence/<scene>/actions.json` contains the input stages and pose measurements.
The external observer reads production state; harness keys only mark/capture
evidence and exercise scene unload/reload.

| Map | Escape-held lateral drift | Focus-held lateral drift | Confirmed unfocused observation interval |
| --- | --- | --- | --- |
| Prism Foundry | 0.000 m | 0.000 m | 931 ms, 2 rendered-frame advances |
| Aurora Basin | 0.000 m | 0.000 m | 452 ms, 2 rendered-frame advances |
| Cinder Array | 0.000 m | 0.000 m | 617 ms, 8 rendered-frame advances |

Both focus samples are actually unfocused, with a released pointer; the earlier
sample confirms active lateral movement before focus is transferred.

## Labs: functional and backend evidence

### Particle Observatory

Verified the native **128K** button, keyboard count decrease/increase
(32,768 ↔ 131,072), Pause button, reset while paused, Space resume, backend
toggle, freeflight RMB capture, Escape release while RMB is held, and continued
rendering in the same popup-free main window. The clock is stationary while
paused and is reset to zero. The blank field in
[paused reset capture](evidence/particle_lab/capture-01.png) is specifically the
paused zero-time reset state; the running field is visible in the other images.

Observed production fields, rather than estimated API names:

| State | Actual fields |
| --- | --- |
| Initial stateful backend | `backend=gpu`, `emitter_amount=32768`, `amount_ratio=1`, `draw_slots=32768` |
| 128K stateful backend | `emitter_amount=131072`, `draw_slots=131072`, `particle_draw_passes=1` |
| 128K analytic backend | `backend=analytic`, `instance_count=131072`, `visible_instance_count=131072`, `emitter_amount=0` |
| Renderer | `gl_compatibility`; `llvmpipe (LLVM 20.1.8, 256 bits)` |

`field.gd:snapshot()` reads the actual GPUParticles3D amount and MultiMesh
instance fields. Its backend label identifies **OpenGL transform-feedback
simulation** versus **analytic vertex motion**. Both execute on the software
Mesa implementation here. The displayed particle count is a configured slot
count, not an on-screen pixel count. `buffer_payload_estimate_bytes` is explicitly
an estimate; `render_buffer_bytes` and `render_video_bytes` are engine-reported
counters. The raw draw calls, primitives, and render-target dimensions are
retained in `actions.json`; no hardware timing or throughput inference is made.

### Shader material studies

Verified 1–3 selection, +/− intensity, Space pause with frozen shader time,
phase adjustment, R reset, and native mouse-drag orbit. Escape leaves the
visible pointer and same main window responsive; this gallery has no
pointer-capture/Escape command of its own. Shader time and rendered frames
continue after normal reset/resume.

The production `factory.state()` reports three shared shaders and three material
instances. HUD statistics use viewport visible draw/primitives counters and
explicitly state **GPU timing: unavailable**. These are material presentation
fixtures, not gameplay evidence. The existing “PRESENTATION FIXTURE / NO
GAMEPLAY CLAIM” label remains visible in all inspected shader screenshots.

## Direct image inspection

Native main-viewport PNGs include the actual HUD; they are not desktop-border
screenshots. The following were opened and visually inspected by the reviewer:

| Scene | 960×640 | 1280×800 | Visual assessment |
| --- | --- | --- | --- |
| Prism Foundry | [Spawn](evidence/showcase/capture-00.png), [walk](evidence/showcase/capture-01.png) | [Walk](evidence/showcase/capture-02.png) | Central prism/rings, ramps, railings, floor lettering and two HUD panels are legible. |
| Aurora Basin | [Spawn](evidence/aurora_basin/capture-00.png), [walk](evidence/aurora_basin/capture-01.png) | [Walk](evidence/aurora_basin/capture-02.png) | Ice arches, aurora, route markers, instructions and minimap are visible without HUD clipping. |
| Cinder Array | [Spawn](evidence/cinder_array/capture-00.png), [walk](evidence/cinder_array/capture-01.png) | [Walk](evidence/cinder_array/capture-02.png) | Bridge route, crane, lava, location panel and controls remain legible. |
| Particle lab | [Running](evidence/particle_lab/capture-00.png), [paused reset](evidence/particle_lab/capture-01.png) | [Running](evidence/particle_lab/capture-02.png) | Budget buttons, statistics, field controls and footer fit at both sizes. |
| Shader lab | [Shield](evidence/shader_lab/capture-00.png), [reactor](evidence/shader_lab/capture-01.png), [phase](evidence/shader_lab/capture-02.png) | [Phase](evidence/shader_lab/capture-03.png), [shield](evidence/shader_lab/capture-04.png), [reactor](evidence/shader_lab/capture-05.png) | All three effects and their notes are visible. The 960-pixel phase notes extend slightly over the footer background, but end above the selection row without hiding content. |

This is a short spawn-area usability/graphics review, not complete route traversal
or a claim that every map location was inspected.

## Lifecycle and qualifications

Every scene undergoes three actual unload checkpoints and two production
reloads. The runner asserts a bounded final pair of node/orphan/object/resource
counts and checks clean process exit. Remaining renderer/library caches are
reported, not treated as scene-owned leaks. This is a bounded short-cycle
check, not an overnight or long-duration leak proof.

The final two unloaded checkpoints are identical for each scene:

| Scene | Nodes / orphans | Objects / resources | Static bytes | Engine video bytes |
| --- | --- | --- | --- | --- |
| Prism | 1 / 0 | 1455 / 25 | 45,961,505 | 27,306,685 |
| Aurora | 1 / 0 | 1440 / 23 | 38,120,257 | 32,612,387 |
| Cinder | 1 / 0 | 1443 / 24 | 37,734,069 | 16,760,867 |
| Particle | 1 / 0 | 1419 / 15 | 34,310,657 | 15,387,829 |
| Shader | 1 / 0 | 1434 / 26 | 35,334,801 | 15,576,715 |

The one remaining node is the main Window. No orphan accumulation or increasing
final-pair memory count was observed. Native logs contain the expected Xvfb
VSync-support warning; final scene runs report no script/resource errors.

The environment is pinned Godot **4.5.2**, private Xvfb with both TCP and
filesystem Unix listeners disabled, private HOME/XDG paths, and Mesa software
llvmpipe. A 30-fps cap and two software-render worker threads limit review load;
heavy maps can render much more slowly. Input is paced in wall-clock time with
unmodified engine timing. Frame-limited software response must not be presented
as Windows/native-hardware performance. No Windows package was built or tested,
and no server/authoritative gameplay or package validation was performed here.

## Commands and reproducibility

```sh
python3 port/native-graphics-independent/review.py
# Targeted validation of strengthened held-motion preconditions and sidebar:
python3 port/native-graphics-independent/review.py showcase aurora_basin cinder_array shader_lab
# Targeted focus-observer synchronization check on slowest scene:
python3 port/native-graphics-independent/review.py showcase
git diff --check -- port/native-graphics-independent
```

The pinned executable, exact Godot/Xvfb arguments, observed state, and automated
checks are recorded in `evidence/summary.json` and each scene's `actions.json`.
Read-only source hashes are in `evidence/source-sha256.json`.

An earlier strengthened-input attempt sampled F9 during input dispatch, before
the next physics step on the slow software renderer; Cinder also reached a
railing while holding the same lateral direction. Those precondition failures
are retained under `evidence/superseded-input-timing/`. The final fixture waits
for a real moving periodic sample and reverses along the already-traversed
path for focus loss, avoiding a stationary/collision-based false pass.
The retained `showcase-stale-focus-sample.json` also shows an attempted focus
assertion using a still-focused old sample; position had already stopped, but
the sample precondition failed. The final runner explicitly waits for observed
focus-out and a later rendered sample at least 750 ms apart; the targeted Prism
rerun verifies this change. Aurora and Cinder's earlier passing evidence already
contains two confirmed unfocused samples, with the exact measured intervals
listed above. These are fixture synchronization corrections, not production
control fixes.
