# Native Moth shader studies

Three reusable **Godot 4.5.2 GL Compatibility** object materials and a standalone, keyboard-operated gallery at **`res://shader_lab/demo.tscn`**:

1. **Interference shell** — translucent cyan/violet rim, scan bands, grid and original Moth shield RGB motif.
2. **Flux reactor** — opaque machined surface with flowing amber channels and cool calibration bands.
3. **Phase prop** — static cargo module with a macro-field cutout and time-driven violet edge shimmer.

These are presentation fixtures, not source-confirmed shield, damage, invisibility or gameplay state. Materials use the inherited exact Moth images; the composition, geometry and animation are native presentation work. [API, integration and export hooks](HANDOFF.md).

## Run and controls

From the repository root, after Godot asset import:

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility --resolution 1280x800 \
  res://shader_lab/demo.tscn
```

| Control | Action |
| --- | --- |
| `1`, `2`, `3` | Select shell, reactor, phase prop |
| `Space` | Pause/resume the caller clock |
| `A` / `D`, left/right arrows | Orbit camera |
| Left-drag in the 3D view | Orbit and adjust elevation |
| `+` / `−` (also keypad) | Effect intensity, clamped to 0–2.5 |
| `[` / `]` | Step the static-prop transition by 5% |
| `R` | Reset time, intensity, transition and camera |

The HUD reports the actual backend, adapter, visible-pass draws/primitives, FPS and CPU process time. GPU timestamp timing is explicitly unavailable. Verification stills label their timing as suspended; their separate proxy measurements exclude image comparison work. There are no popup dialogs.

## Accepted verification

```sh
python3 port/native-shader-lab/verify.py
```

Final accepted run: **[run-r_ec81xc/summary.json](evidence/run-r_ec81xc/summary.json)**. Import, 68 contract checks, and both graphical resolutions passed with pinned engine `4.5.2.stable.official.6ce3de25a`, native OpenGL Compatibility, Mesa 25.2.8 / llvmpipe LLVM 20.1.8. Only the expected software-driver V-Sync warning remains. Each attempt has private HOME/XDG directories and `Xvfb -nolisten tcp -nolisten unix`; no shared display/server is used.

Final gallery images were opened and visually inspected at their actual, asserted dimensions:

| Material | 960×640 | 1280×800 |
| --- | --- | --- |
| Shell | [Image](evidence/run-r_ec81xc/960x640/shield-t1.png) | [Image](evidence/run-r_ec81xc/1280x800/shield-t1.png) |
| Reactor | [Image](evidence/run-r_ec81xc/960x640/conduit-t1.png) | [Image](evidence/run-r_ec81xc/1280x800/conduit-t1.png) |
| Phase prop | [Image](evidence/run-r_ec81xc/960x640/phase-t1.png) | [Image](evidence/run-r_ec81xc/1280x800/phase-t1.png) |

The core and rings remain visible through the shell; rim and scan coverage follow the curved silhouette. The reactor has legible amber packets over metal rather than a dark featureless prop. The phase module retains its riveted texture and silhouette while a jagged violet edge exposes the pedestal below. Both resolutions keep the notes and controls readable. The pedestal's lower edge intentionally sits behind the footer.

### Image A/B proof

Measurements use the same camera/geometry/light and exclude the HUD. A changed pixel has max RGB-channel difference **> 0.025**. `t1` = 1.25 seconds, `t2` = 3.75 seconds; phase threshold stays fixed for the time comparison.

| 1280×800 specimen | Effect off/on | Time change | Field strength 0/default | Normals off/on | LUT off/on |
| --- | ---: | ---: | ---: | ---: | ---: |
| Shell | 125,447 | 57,664 | 20,495 | 701 | 5,045 |
| Reactor | 24,447 | 22,338 | 23,155 | 201 | 147 |
| Phase prop | 80,184 | 17,216 | 28,537 | 202 | 17,926 |

The sparse original LUT gives the reactor a deliberately small rim contribution; the normal maps are also restrained. Their actual rendered contribution is measured, not inferred from uniforms. Every specimen has **exactly zero** rendered RGB difference across repeated paused frames at both sizes. At 960×640, time changes affect **37,324 / 14,345 / 11,036** pixels respectively.

- Shell: [t1](evidence/run-r_ec81xc/1280x800/shield-t1.png), [t2](evidence/run-r_ec81xc/1280x800/shield-t2.png), [disabled](evidence/run-r_ec81xc/1280x800/shield-disabled.png).
- Reactor: [t1](evidence/run-r_ec81xc/1280x800/conduit-t1.png), [t2](evidence/run-r_ec81xc/1280x800/conduit-t2.png), [disabled](evidence/run-r_ec81xc/1280x800/conduit-disabled.png).
- Phase: [t1](evidence/run-r_ec81xc/1280x800/phase-t1.png), [t2](evidence/run-r_ec81xc/1280x800/phase-t2.png), [intact 0%](evidence/run-r_ec81xc/1280x800/phase-full.png), [absent 100%](evidence/run-r_ec81xc/1280x800/phase-empty.png).
- Alpha/depth: [shell on](evidence/run-r_ec81xc/1280x800/alpha-depth-on.png), [shell off](evidence/run-r_ec81xc/1280x800/alpha-depth-off.png). The warm opaque rear plate is visible through the shell. The foreground bar is unchanged pixel-for-pixel; all four sampled bounding-square corners are unchanged. No solid source-alpha rectangle appears.
- Full measurements: [960×640](evidence/run-r_ec81xc/960x640/measurements.json), [1280×800](evidence/run-r_ec81xc/1280x800/measurements.json). The latter directory also contains every normal/field/LUT-disabled image.

The 0% phase image exactly matches the intact, disabled-effect specimen. At 100%, both prop surface and its shadow contribution disappear. This controls render coverage only; no collision, actors, gameplay state or visibility authority is involved.

### Contract and lifecycle coverage

`godot/tests/shader_lab/validate.gd` checks finite numeric handling, invalid-time preservation, clamped clock bounds, backwards replay seek, state-copy isolation, distinct material/shared shader/shared texture ownership, reset to creation settings, asset allowlists, opaque source alpha, 64-instance capacity, dead-material weak-reference pruning, 256 create/release cycles and the inherited Moth cache limit. Registry clearing leaves live caller textures valid.

`godot/tests/shader_lab/graphics.gd` also routes real Godot input events through selection, pause, intensity, reset, transition stepping and mouse orbit. Freeing the gallery releases its factory and all three material instances. The native renderer checks cover alpha, foreground occlusion, clean corners, endpoint transitions and pause/time A/Bs.

### Software performance proxy

60 frame samples after warmup per effect, with the gallery stage/HUD and one shadowed key light. These are wall-clock frame intervals on a shared **software llvmpipe** host, not hardware-GPU acceptance or GPU timestamps. Visible-pass counters include the gallery and UI, not shadow-pass totals.

| Effect | 960×640 median / p95 ms | 1280×800 median / p95 ms | Visible draws, 1280×800 | Visible primitives |
| --- | ---: | ---: | ---: | ---: |
| Shell | 15.21 / 18.64 | 20.64 / 23.59 | 50 | 10,036 |
| Reactor | 15.33 / 18.93 | 21.49 / 25.06 | 72 | 6,316 |
| Phase | 14.36 / 17.97 | 18.82 / 22.51 | 37 | 4,776 |

Earlier retained passing runs vary noticeably under concurrent host load. A/B capture and CPU image comparison are excluded from these timing loops. Each reusable material itself adds one surface pass; the gallery's rails, rings, stage, shadows and UI account for the larger counts. Geometry is built once and time only updates shader uniforms.

## Preserved discovery/failure evidence

- `run-4kw2jy9_`: shader compiler rejected a matrix built-in inside a helper. Normal transforms now originate in the vertex stage and pass through an explicit varying.
- `run-wpr2jrrm`: compiler rejected reusing one sampler-argument helper for different color-space/filter policies. Distinct sRGB-albedo and linear-data helpers preserve the correct policies.
- `run-b2_o3thb`: invalid environment enum caused the first graphical script to stall; its native app log was recovered and retained. The runner now preserves timeout stdout and requires completion markers; the graphical script has a watchdog.
- `run-zkm8r6_m`: first passing 960×640 draft; inspection found overly blue/bright studio lighting and imprecise delayed performance counters. Superseded.
- `run-cuudw71o`: wrong `Viewport.get_render_info` signature; corrected to visible-pass type plus counter.
- `run-15ia4uza`: the phase normal-map toggle changed only 20 pixels above threshold and failed the >20 check. Default phase normal strength was raised from 0.20 to 0.38; the final result changes 202 pixels.
- `run-sqa6nucs`: passed both resolutions; superseded only to correct the phase endpoint capture's HUD percentage and strengthen the standalone contract-test failure exit.

The accepted delivery is native Compatibility only. Hardware GPUs, Forward+, mobile/web, overlapping transparent shells and the lead's final exported package have not been accepted by this lane. Exact hook and resource requirements are in [HANDOFF.md](HANDOFF.md).
