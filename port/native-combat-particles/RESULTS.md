# Measured in-world combat-particle result

## Delivered

`godot/combat_particles/manager.gd` is integration-ready with `configure(camera, map_id_or_bounds)`, `apply_state(public_state, local_id)`, `consume(events, local_id)`, `reset()`, `set_quality(level)`, and `snapshot()`. See [README.md](README.md) for exact session/native-root wiring, lifecycle calls, quality help, and ownership boundaries.

The bounded pool is **20 large explosion/debris/dust emitters + 8 persistent projectile trails + 4 world-fixed ambient fields**. Extreme has **1,000,000 shared allocated slots**, one shared draw mesh/material and collision atlas, 32 process materials sharing one particle shader, and zero CPU particle iteration. This is actual stateful `GPUParticles3D` transform feedback on Compatibility; there is no analytic or CPU-particle fallback masquerading as GPU simulation.

## Rendered normal-arena matrix

Godot **4.5.2-stable**, Compatibility, **Mesa llvmpipe (LLVM 20.1.8, 256 bits)**. These are **software-renderer measurements**. Hardware/user-GPU performance remains unknown.

Each row has 16 warm-up frames followed by **72 retained frame-time samples**. Median/p95/max are wall-frame milliseconds, including the screenshot readback/save hitch. Normal `world/viewer.gd` Meridian Exchange geometry is present: **89 semantic blocks and 813 support triangles**, regular arena materials, a first-person-height camera, crosshair, and explicitly labeled dummy health/armor/weapon HUD. No particle-lab scene is used.

| Actual viewport | Workload | Submitted particle slots | Median ms | p95 ms | Max ms | Scene primitives | Scene draws |
|---|---|---:|---:|---:|---:|---:|---:|
| 1280×800 | Arena baseline | 0 | 23.144 | 27.976 | 228.409 | 13,549 | 299 |
| 800×600 | Arena baseline | 0 | 19.951 | 23.543 | 122.071 | 13,365 | 291 |
| 1280×800 | High stress | 32,768 | 44.128 | 48.384 | 266.661 | 79,103 | 331 |
| 800×600 | High stress | 32,768 | 38.201 | 42.091 | 148.820 | 78,919 | 323 |
| 1280×800 | **Extreme combat stress** | **1,000,000** | **448.429** | **466.295** | **764.119** | **2,013,615** | **331** |
| 800×600 | **Extreme combat stress** | **1,000,000** | **434.377** | **460.590** | **600.933** | **2,013,431** | **323** |

Final Extreme snapshots report all **32 emitters active**, 20 bursts, 8 persistent trails, 1,000,000 allocated/submitted slots, and 320,000,000 estimated bytes of GLES3 particle-buffer payload plus a 442,368-byte shared occupancy texture. Both PNG header sizes and actual viewport dimensions were checked by the runner. The >2-million scene primitive counters corroborate submission of one million world-space quads alongside ordinary geometry.

The screenshot keeps architecture, cover edges, the crosshair and HUD readable; the effects are small alpha-blended particles with world depth testing and near-camera fade. It does not imply that every slot produces a visible pixel: solid/depth-occluded, expired and transparent particles remain distinguished from submitted capacity, and **no GPU live-count readback is claimed**.

- [1280×800 Extreme screenshot](evidence/extreme-1280.png) · [raw measurements](evidence/extreme-1280.json) · [renderer log](evidence/extreme-1280.log)
- [800×600 Extreme screenshot](evidence/extreme-800.png) · [raw measurements](evidence/extreme-800.json) · [renderer log](evidence/extreme-800.log)
- [All six summarized rows](evidence/measurement-summary.json) · [matrix run log](evidence/measurement-run.log)

Extreme remains explicit selection. Original combat defaults to **High 32,768**; native Prism/Aurora/Cinder High is **131,072**. Low is 8,192. The heavy software-renderer result does not justify increasing original-map defaults or claiming smooth one-million operation on hardware that was not measured.

## Verification beyond the showcase

- **Bounded/lifecycle contract passes:** malformed events, world-space behavior under a translated parent, event-ID dedup/out-of-order/floor rejection, bounded 512-item scans, emitter recycling, late local projectile priority, missing-projectile fade without an invented explosion, exact shared allocation across quality switches, stable pool identities, invalid quality rejection, pause, hidden ancestors, focus loss, SceneTree pause, invalid delta, staleness, results, round ID reuse. [contracts.log](evidence/contracts.log)
- **Rendered collision/depth control passes:** 210-frame directed exhaust test against a solid wall. Behind-wall region changed **0 pixels**; equivalent front-side positive control changed **4,678 pixels**. The source behind the wall is actively emitting toward the camera side, so this tests sustained confinement as well as normal depth occlusion. [occlusion.json](evidence/occlusion.json) · [behind](evidence/occlusion-behind.png) · [front](evidence/occlusion-front.png)
- **Native collision/default-quality contract passes:** actual Cinder and Aurora map geometry roots are extracted at authored coordinates, with **0 unsupported collision shapes**. Cinder voxelizes 99 box/triangle primitives; Aurora 20,543. Both allocate 131,072 High slots and activate only their four offline weather fields (16,384 submitted slots). Map subtree discovery is checked so dynamic session actors do not become frozen obstacles. [native-geometry.log](evidence/native-geometry.log)
- **Ordinary server public-event correlation passes:** independent observer, normal source server cadence/rules, 22 seconds of ordinary movement/fire inputs, **636 acknowledgements, 27 local launch events, 930 local trail samples, and 31 exact source-position explosion matches**. Three of 34 public explosions were outside the configured world bounds and were rejected. The log preserves 12 source event IDs, public positions, and converted Godot positions. This check is headless protocol/presentation correlation, not a rendered hardware performance claim. [live.log](evidence/live.log) · [server log](evidence/live-server.log)

## Retained limits and failures

The collision field is a bounded voxel presentation approximation: actual boxes/convex bounds and sampled triangle shells, not gameplay physics. Conservative solid-source suppression can hide an effect embedded in a coarse voxel; bounded GPU sweeps and ordinary depth testing prevent tested through-wall false cues. Rounded/rotated convex bounds can over-clip; triangle sampling is half-cell spacing. Native integrations should pass the authored `collision_root` explicitly.

[FAILURES.md](evidence/FAILURES.md) records compile fixes, the rejected initial 800×600 capture that was actually 1280×800, the shared-X11-directory failure, the first full-matrix saturation failure and fairness fix, and retained VSync warnings/stalls. Invalid measurements are clearly named and excluded from the table above.

Final session/F9 wiring, package generation, and cross-lane/global verification belong to the lead integration lane. This commit is confined to the three assigned new directories.
