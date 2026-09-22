# Independent native graphics review

Scope: integrated production scenes `showcase/demo.tscn`,
`aurora_basin/demo.tscn`, `cinder_array/demo.tscn`, `particle_lab/demo.tscn`,
and `shader_lab/demo.tscn`. Findings and directly inspected images are recorded
in `REPORT.md` after the run.

## Reproduce

From the repository root:

```sh
python3 port/native-graphics-independent/review.py
git diff --check -- port/native-graphics-independent
```

Requirements: the pinned sibling
`godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`, existing project resource
imports, Python 3, `Xvfb`, `libX11`, and `libXtst`. `xdotool` was not installed;
the runner uses the same XTest extension directly via Python's `ctypes`.

The runner starts one private Xvfb with `-nolisten tcp -nolisten unix`, private
HOME/XDG directories, and one Godot scene at a time. X11 connects through the
remaining local abstract socket. It uses Mesa software rendering with two
llvmpipe worker threads and a 30-fps cap to limit shared-machine load. No fixed
delta or accelerated simulation is used. This is a usability/graphics check,
not a hardware or throughput benchmark.

`observer.gd` is an external **independent evidence fixture**. It loads the
actual `.tscn` as `SceneTree.current_scene`; it neither substitutes a controller
nor changes actor/camera transforms or production control handlers. It reads
production properties and writes viewport PNG evidence only. It has no source
gameplay/file-access authority and makes no networking or session calls.
XTest sends synthetic **OS-level** keyboard/mouse events to the actual Godot
production X11 window. No `Input.parse_input_event`, controller method calls,
fake gameplay window, teleport, or photo camera is used. Real focus loss is
caused by focusing the X11 root while A remains physically down in XTest.
The runner waits for an actual moving physics sample before changing focus;
Escape is separately tested with D held. This avoids a vacuous pass from
sampling input before physics or from walking into a railing.

Harness-only F8 captures the rendered main viewport, F9 marks observed state,
F11 unloads/reloads the production scene, and F10 unloads and exits. PNGs are
native viewport captures (including the actual HUD), not desktop/window-border
screenshots. All map views retain their production eye-height cameras; the
first image is the spawn view, subsequent images follow a brief real walk.

## Evidence

- `evidence/summary.json`: machine-readable checks and qualifications.
- `evidence/<scene>/actions.json`: input stages, capture-state associations,
  measured pose differences, actual backend fields, and teardown checkpoints.
- `evidence/<scene>/native.log`: engine output plus periodic observational
  snapshots, including focus, mouse mode, production controller resource path,
  frame count, and engine memory/object counters.
- `evidence/<scene>/capture-*.png`: real production viewport pixels.
- `runtime/`: ignored private HOME/XDG/cache files.

Three unload checkpoints (with two reloads) check that the last two unloaded
node/orphan/object/resource populations plateau after warmup. This is a short
lifecycle check, not a long-duration leak proof. Engine buffer/video counters
and payload estimates are retained as their actual reported fields; zero or
unavailable values are not reinterpreted as measured GPU allocation.

Only this directory is owned by this review. No runtime, shared test, launcher,
package, or other review artifacts are edited. No package is built or published.
