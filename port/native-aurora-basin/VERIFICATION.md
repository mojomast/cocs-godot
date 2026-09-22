# Aurora Basin verification

**Accepted run:** [`run-20260922T085726833130Z`](evidence/run-20260922T085726833130Z/summary.json).

All **14 steps passed**: import, compile preflight, collision validation, standalone smoke launch, and ten native captures. There are no script, shader, or resource errors in this run. The native GL logs retain the expected llvmpipe V-Sync warning.

Engine: `4.5.2.stable.official.6ce3de25a`. Renderer: `gl_compatibility`, OpenGL 4.5, Mesa 25.2.8, **llvmpipe (LLVM 20.1.8, 256 bits)**. Private Xvfb and isolated HOME/XDG; 2× MSAA; no hardware-GPU measurement.

## Actual collision and bounded-resource checks

[`collision.json`](evidence/run-20260922T085726833130Z/collision.json) records **593 passing checks**, 119,816 finite mesh vertices checked, 279 supported route rays, eight completed capsule traversals, and zero invalid transforms. All measured traversal frames stayed grounded. Maximum authored skywalk slope: **16.3617°**.

| Capsule traversal | Distance | Physics frames | Maximum waypoint-height error |
| --- | ---: | ---: | ---: |
| Landing to lake | 13.50 m | 90 | 0.025 m |
| Complete lake circuit | 169.50 m | 1,130 | 0.026 m |
| Sealed lake crossing | 55.19 m | 368 | 0.001 m |
| Crown, east → west | 128.17 m | 854 | 0.066 m |
| Crown, west → east | 128.13 m | 855 | 0.078 m |
| Walk into lookout | 4.80 m | 32 | 0.001 m |
| East lake/skywalk junction | 3.30 m | 22 | 0.001 m |
| West lake/skywalk junction | 3.30 m | 22 | 0.001 m |

The probe uses 120 physics ticks/s with time scale 3 to accelerate an actual gravity/collision simulation. It steers the compatible 1.8 m capsule toward successive route points, with no teleport between waypoints. The eye remains 1.6 m above the capsule's feet. Spawn grounding, build idempotence, continuous support heights, and resource ceilings also pass.

Map construction was **70.576 ms** in headless validation and **66.577–70.511 ms** across the ten native captures. Map nodes remain 525 after traversal. All ten captures retain **532 scene nodes and 23 engine-reported loaded resources** from the end of warmup through the end of measurement. These are native engine counters; the separate authored geometry counts are in the README and every capture JSON.

## Images actually opened and inspected

All ten final PNGs below were read as images after the final run. Dimensions were also asserted by the capture script.

| View | 960×640 | 1280×800 | Inspection |
| --- | --- | --- | --- |
| Landing, native 1.6 m eye | [PNG](evidence/run-20260922T085726833130Z/landing-960x640.png) | [PNG](evidence/run-20260922T085726833130Z/landing-1280x800.png) | Aurora, ice gates, landing perimeter, signed route, HUD fit; no earlier landing depth fighting. |
| Observatory, native 1.6 m eye | [PNG](evidence/run-20260922T085726833130Z/observatory-960x640.png) | [PNG](evidence/run-20260922T085726833130Z/observatory-1280x800.png) | Complete dome/telescope silhouette, warm orbital frame, landing access, and source-textured surfaces. |
| Fracture, native 1.6 m eye | [PNG](evidence/run-20260922T085726833130Z/fracture-960x640.png) | [PNG](evidence/run-20260922T085726833130Z/fracture-1280x800.png) | Continuous lake floor, legible turquoise plate seams, ice gate scale, pressure ridge, elevated ramp. |
| Vista, native 1.6 m eye on +9 m deck | [PNG](evidence/run-20260922T085726833130Z/vista-960x640.png) | [PNG](evidence/run-20260922T085726833130Z/vista-1280x800.png) | Lake overview from the reachable deck, arch shadows, floor/edge context, stable HUD. |
| Overview, explicitly non-player camera | [PNG](evidence/run-20260922T085726833130Z/overview-960x640.png) | [PNG](evidence/run-20260922T085726833130Z/overview-1280x800.png) | Whole basin, closed lake circuit, connected raised loop, station placement, curved mountain rim, two aurora layers. |

The snowy terrain is deliberately faceted, and thin distant cracks/stars can alias. The 1280×800 vista shows strong lake specular highlights from the inherited ice normal map; these are ordinary surface lighting, not a glow effect. The overview hides the HUD and is not used as first-person framing evidence.

## Native llvmpipe frame timings

Each capture discards 24 warmup frames, then measures 60 completed draws using a monotonic microsecond clock. These wall times include CPU/software rasterization and host scheduling. The final run was sequential. Earlier, simultaneously running validation/captures had slower timings and are retained as iteration evidence.

| View / resolution | Mean ms | Median ms | P95 ms | Draw calls, last frame |
| --- | ---: | ---: | ---: | ---: |
| Landing / 960×640 | 54.91 | 54.63 | 60.68 | 234 |
| Observatory / 960×640 | 45.49 | 45.45 | 49.18 | 166 |
| Fracture / 960×640 | 45.61 | 45.57 | 49.69 | 201 |
| Vista / 960×640 | 53.08 | 53.50 | 56.04 | 199 |
| Overview / 960×640 | 48.37 | 48.43 | 52.29 | 165 |
| Landing / 1280×800 | 63.24 | 63.35 | 67.50 | 241 |
| Observatory / 1280×800 | 53.63 | 53.60 | 57.55 | 170 |
| Fracture / 1280×800 | 51.98 | 51.82 | 56.28 | 201 |
| Vista / 1280×800 | 57.56 | 56.87 | 63.85 | 199 |
| Overview / 1280×800 | 51.34 | 51.49 | 54.54 | 167 |

Each PNG has an adjacent `.png.json` containing raw timings, exact camera coordinates, renderer identity, resource counts, draw/primitives counters, and reported video memory. The run summary includes every exact command and exit code. These figures make no promise of a particular frame rate on hardware or other software-renderer hosts.

## Remaining integration boundary

The final branch is verified with its dynamically selected private test controller. The lead should dispatch `--experience=aurora-basin` to the scene and check the lead-owned `res://exploration/walker.gd` there. Its required camera/spawn contract is documented in [README.md](README.md). No shared launcher or source combat map is changed by this delivery.
