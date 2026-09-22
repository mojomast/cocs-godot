# Native particle lab — executed evidence

## Environment and acceptance scope

- Godot **4.5.2.stable.official.6ce3de25a**, pinned Linux x86-64 executable.
- Executable SHA-256:
  `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
- Actual renderer: **OpenGL 4.5 Compatibility**, Mesa
  **25.2.8-0ubuntu0.25.10.2**, **llvmpipe (LLVM 20.1.8, 256 bits)**.
- Native X11 windows on owned private Xvfb, isolated HOME/XDG, dummy audio.
  No browser rendering, remote services, driver installs or asset downloads.
- These are real native GPU-API paths executed by a **software renderer**.
  **Hardware GPU performance acceptance is not claimed.**
- The driver reports that V-Sync mode cannot be changed. That warning is
  retained in the native logs; final native runs have no shader/script errors.

## Full-count render sweep

Source: [`evidence/sweep-01/summary.json`](evidence/sweep-01/summary.json).
Every case has its original PNG, native log, settings, engine counters, raw
wall-clock intervals and median/p95 in the neighboring `metrics.json`.
`summarize.py` independently checks median values and actual count/primitive
consistency. All **13 cases passed**, with no timeout or count substitution.

Matched galaxy comparison: 1280×800 native window and 1280×800 render target,
0.34 m quads, additive energy 0.85, full explicit count. Eight warm-up native
render frames precede measurement. `n` is the number of genuine inter-frame
wall-clock intervals, not a requested/synthetic frame count.

| Backend | Actual amount / visible instances | n | Median ms | p95 ms | Engine buffer MiB |
| --- | ---: | ---: | ---: | ---: | ---: |
| GPUParticles / transform feedback | 8,192 | 119 | 6.86 | 9.12 | 8.85 |
| GPUParticles / transform feedback | 32,768 | 119 | 18.36 | 25.24 | 16.35 |
| GPUParticles / transform feedback | 131,072 | 119 | 57.28 | 62.13 | 46.35 |
| GPUParticles / transform feedback | 524,288 | 70 | 211.34 | 219.69 | 166.35 |
| GPUParticles / transform feedback | **1,048,576** | 32 | **462.04** | **476.69** | **326.35** |
| MultiMesh / GPU analytic vertex motion | 32,768 | 119 | 19.64 | 22.49 | 7.84 |
| MultiMesh / GPU analytic vertex motion | **1,048,576** | 24 | **603.75** | **620.57** | **54.34** |

The 1M GPU case reports `amount=1048576`, `amount_ratio=1`, and **2,104,278
actual total primitives**, including UI/stage. The particle draw alone is
**2,097,152 triangles**, at one quad per slot. MultiMesh's actual
`instance_count` and `visible_instance_count` are both 1,048,576. No individual
particle frustum/occlusion count or distinct visible-pixel count is invented.

**1M is usable as a deliberate stress/visual experiment, not a smooth
interactive workload on llvmpipe.** About 2.16 fps for the true GPU API path and
1.66 fps for analytic motion means input is limited to that slow render cadence.
The analytic path has much smaller buffers but recalculates trajectories per
quad vertex; it is **not faster** in this matched software test. The default
32K remains useful and allocates only its own capacity.

Additional runs at full render resolution:

| Window | Preset | Actual count | n | Median ms | p95 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 960×640 | Vortex | 32,768 | 119 | 20.93 | 32.72 |
| 1280×800 | Vortex | 32,768 | 119 | 19.53 | 33.35 |
| 1280×800 | Ion burst | 32,768 | 119 | 18.62 | 21.69 |
| 1280×800 | Plasma fountain | 32,768 | 119 | 20.04 | 22.73 |
| 960×640 | Vortex | 524,288 | 70 | 213.28 | 219.85 |

An explicitly **50%** render-scale case used a 960×640 window, **480×320 3D
target**, and 1,048,576 analytic instances: n=34, median **424.67 ms**, p95
**499.19 ms**, 54.34 MiB buffers. It visibly softens/aliases the particle field
while retaining a native-resolution readable HUD. Window size also differs
from the 1280×800 analytic test, so this is not a controlled isolated
render-scale speedup claim.

## Visual review and explicit energy control

Original, unretouched PNGs were directly opened and inspected:

- [960×640 / 32K vortex](evidence/sweep-01/960x640-vortex-gpu-32768-1x/capture.png)
- [1280×800 / 32K galaxy](evidence/sweep-01/1280x800-galaxy-gpu-32768-1x/capture.png)
- [1280×800 / 128K galaxy](evidence/sweep-01/1280x800-galaxy-gpu-131072-1x/capture.png)
- [1280×800 / 32K ion burst](evidence/sweep-01/1280x800-burst-gpu-32768-1x/capture.png)
- [1280×800 / 32K plasma fountain](evidence/sweep-01/1280x800-fountain-gpu-32768-1x/capture.png)
- [960×640 / 512K vortex](evidence/sweep-01/960x640-vortex-gpu-524288-1x/capture.png)
- [1280×800 / 1M true GPU galaxy](evidence/sweep-01/1280x800-galaxy-gpu-1048576-1x/capture.png)
- [960×640 / 1M analytic at explicit half resolution](evidence/sweep-01/960x640-galaxy-analytic-1048576-0.5x/capture.png)
- [1280×800 / 1M true GPU with explicit low energy](evidence/dense-view/1280x800-galaxy-gpu-1048576-1x/capture.png)
- [960×640 / final controls and default 32K](evidence/final-checks/960x640-vortex-gpu-32768-1x/capture.png)
- [1280×800 / 1M analytic, full resolution](evidence/sweep-01/1280x800-galaxy-analytic-1048576-1x/capture.png)

**Findings:** The 32K vortex has a readable blue-to-magenta funnel and bright
nozzle; the fountain has a green crown over a blue-violet plume; the ion burst
shows concentric warm shells. At 128K the galaxy's warm core, blue spiral arms
and scattered inclined halo are clearly resolved. Small circular coverage
avoids opaque source-alpha squares. Thin additive ground range rings fade into
the background without a finite opaque plane edge.

**Retained defect/limit:** Standard energy 0.85 strongly saturates the galaxy
core/arms at 1M and the vortex at 512K. It also obscures individual overlapping
particles. The implementation does not secretly normalize brightness by count.
Instead, the final UI adds the explicit **`L` / Low-energy view** toggle
(0.06 ↔ 0.85), plus fine comma/period adjustment. Current quad size and energy
are always displayed. Count, draw geometry, simulation and resolution stay
the same when energy changes.

The final low-energy 1M native capture resolves the cloud-like spiral and warm
core without broad white clipping. It measured **435.00 ms median / 518.79 ms
p95**, n=32, with the same **1,048,576 emitter amount**, **326.36 MiB** engine
buffers and full 1280×800 target. This is a presentation choice, not a count
reduction or promised performance optimization. Evidence:
[`dense-view/.../metrics.json`](evidence/dense-view/1280x800-galaxy-gpu-1048576-1x/metrics.json).

The final controls include the low-energy button; earlier sweep PNGs predate
that additional button and the clearer “Sim clock” wording. Shader/geometry
and default energy were unchanged by those final UI additions. At extremely
slow frame rates the normal Godot simulation delta can be clamped, so the
simulation clock lags wall time. All benchmark timing above uses independent
wall-clock render intervals, never the simulation clock.

## Verification / lifecycle

- **183 checks passed** in both headless and actual native Compatibility runs.
  See [`sweep-01/verify-native.log`](evidence/sweep-01/verify-native.log) and
  [`dense-view/verify-native.log`](evidence/dense-view/verify-native.log).
- All real count/preset/backend combinations in the bounded lifecycle suite
  preserve emitter, MultiMesh, quad mesh and material identities. Changes
  reset the clock, and invalid values do not mutate the field.
- Pause preserves the clock. **Every capture** also verifies byte-identical
  paused 3D render-target images and releases captured controls by dispatching
  an Escape input event, including the 1M cases.
- The three Moth `arc-burst` source frames were scanned over **6,912 pixels**:
  minimum and maximum alpha are both **1.0**. Coverage is intentionally derived
  in the shader. Actual flow-field and entanglement LUT resources are loaded.
- Eight warmed create/dispose cycles in the native verification retain exactly
  **1,411 objects, 12 resources, 32,361,649 static bytes, 6,405,544 render-buffer
  bytes** after every teardown in the full-sweep run. Owned mesh/material
  weakrefs clear. There is no monotonic retained growth in these measured cycles.
- Headless `--smoke` exits automatically and reports
  `gpu_performance_test:false`. The final version explicitly checks all Moth
  frame/field/LUT resources, not just scene loading.

The optional final massive-resize test and its results are recorded in
[`final-checks-02/stress-lifecycle.log`](evidence/final-checks-02/stress-lifecycle.log).
**Passed in 14.91 seconds:** three cycles of real 128K → 512K → 1M → 32K
rendering in one process, stable resource identities, buffer release on
reduction, and whole-scene teardown. Each return to 32K had exactly **1,586
objects, 16 resources and 17,154,016 render-buffer bytes**. Static memory went
from 34,980,145 bytes to 34,983,601 bytes (3,456 bytes of bounded variation,
not retained million-particle buffers). Whole-scene teardown returned the
render-buffer monitor to the same **6,405,544-byte** empty-scene baseline and
cleared material/mesh weakrefs. Reproduce with
`run.py --quick --stress-lifecycle`.

## Preserved development failures

The evidence is not a success-only selection:

- [`iteration-01/import.log`](evidence/iteration-01/import.log): GDScript could
  not infer a dynamically returned boolean. Fixed with an explicit type and
  a typed field reference.
- [`iteration-02/verify-headless.log`](evidence/iteration-02/verify-headless.log):
  caught `GPUParticles3D.restart()` turning the hidden GPU emitter back on in
  analytic mode. Reset now restarts only the active GPU backend.
- [`iteration-03/.../capture.log`](evidence/iteration-03/960x640-vortex-gpu-32768-1x/capture.log):
  capture helper needed explicit `PackedByteArray` types for image comparisons.
- [`iteration-04` original PNG](evidence/iteration-04/960x640-vortex-gpu-32768-1x/capture.png):
  direct review caught an offscreen right control panel, telemetry/footer
  overlap, an opaque finite ground-plane edge and overly subpixel default
  particles. Fixed anchoring/line spacing, made the range grid additive, and
  authored the final 0.34 m / 0.85 normal display settings before the count sweep.
- The full sweep's saturated massive-count images and slowdowns are retained.
  No timeout was hit, and a smaller count was never substituted.
- [`final-checks/stress-lifecycle.log`](evidence/final-checks/stress-lifecycle.log):
  the new large-resize helper initially inferred Variant weakrefs. Explicit
  `WeakRef` declarations resolve the parser's warning-as-error; the rerun is
  stored separately rather than overwriting that failure.
