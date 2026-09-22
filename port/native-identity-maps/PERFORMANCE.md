# Prototype performance — not hardware acceptance

Pinned Godot 4.5.2.stable.official.6ce3de25a; Compatibility/OpenGL 4.5, Mesa 25.2.8, llvmpipe LLVM 20.1.8 (256 bits). No /dev/dri device exposed to this execution environment. These are software-renderer frame cadence observations, not GPU timings or 60 FPS hardware promises. No standalone CPU/GPU profiler timings were collected.

Latest artifact capture: evidence/render-1790081900090569141/1920x1080/report.json. Each of five fixed cameras receives 12 warm-up frames and 40 cadence samples. Median is sample index20 and the reported p95 is index37 (nearest-rank p95 for 40 samples). Short samples, warm-up and shared-host scheduling limit inference. Cold shader stutter is not isolated and the reports do not claim otherwise.

| Map | Authored mesh triangles | Material cells | Godot map build ms | Camera median range ms | Camera p95 range ms | Max measured draw calls |
|---|---:|---:|---:|---:|---:|---:|
| Lacuna Court | 7,226 | 67 | 21.732 | 12.505–17.905 | 15.703–22.503 | 249 |
| Vermilion Fold | 3,290 | 48 | 11.759 | 11.385–19.926 | 14.649–24.672 | 156 |
| Nacre Engine | 17,438 | 88 | 53.713 | 23.972–32.206 | 26.322–52.567 | 341 |

One shadowed directional light, no local lights, glow off, no decorative/combat particles, no actors/HUD. Batches currently bucket triangle centroids into 12 m cells; wide floor/boundary triangles are not clipped at cell edges, so some mesh bounds still span multiple cells. This is a prototype partition, not completed fine-grained culling. Five shared materials, zero imported textures and zero lightmaps. Maximum engine-reported total video-memory counters were respectively 23,455,859 / 23,219,699 / 24,068,579 bytes; these are NOT per-map texture allocations or discrete-GPU resident-memory measurements. Draw counts include shadow/depth passes and exceed material-cell counts.

Major performance finding: exact high-detail architectural triangles passed through the source wall-segment mover are expensive. Final cold in-process construction measured 6,059.348 ms / 2,950.349 ms / 14,827.741 ms respectively in evidence/graybox-final-fixed.log, versus tens of milliseconds for the earlier graybox. This is an explicit integration/performance hold, not an acceptable final load-time budget. Nav remains connected, but wall-segment scans and nav construction need a source-compatible simplified collision representation with independently verified ray/visible-cover parity. Do not modify locked source simulation to conceal this cost. Exact baked visual meshes and simplified collision provenance should be separated in the next iteration.

1280×800 graybox comparison is retained in evidence/render-1790081061279699658/1280x800. It predates the final ramp infill seam correction and is historical baseline evidence, not an exact final-geometry benchmark. Earlier final-art captures are also retained. A current existing-playable-map baseline under the same harness remains OPEN.

Lifecycle-final.json: three map build/free cycles, 251,652 assertions (mostly finite-vertex checks), zero failures. After each cycle: one root node, two resources, zero orphan nodes. This is resource cleanup, not load/play/results/defeat/restart/input/audio acceptance.

Still OPEN: identified representative desktop GPU, actor/FX headroom, CPU vs GPU timings, long path/cold-load/shader measurements, lightmap bake probe or genuine offline AO alternative, textures/trim detail, Low/High quality integration, occlusion and LOD comparisons, peak Horde load, packaged resource/load tests and visual review. No FPS claims from headless tests.
