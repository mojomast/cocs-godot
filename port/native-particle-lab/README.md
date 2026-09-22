# Native Particle Observatory

Standalone native Godot 4.5.2 particle experiment, based on `7bfb473`.
Owned code lives in `godot/particle_lab/`, tests in
`godot/tests/particle_lab/`, and reproduction/evidence here.

## Launch / lead integration contract

The scene is **`res://particle_lab/demo.tscn`**. The lead's native experience
selector should resolve `--experience=particle-lab` to this scene. It needs
neither a game session nor the semantic map catalog. The scene ignores that
experience-selector argument, so the lead may leave it in the user arguments.

Direct launch after the project's normal Godot resource import:

```sh
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility \
  res://particle_lab/demo.tscn

# Massive allocation is explicit. Defaults are 32,768 and GPU simulation.
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility \
  res://particle_lab/demo.tscn -- --particles=1048576 --preset=galaxy

# Headless resource/control smoke: auto-exit, NOT GPU/performance acceptance.
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --headless --path godot res://particle_lab/demo.tscn -- --smoke
```

Optional user arguments: `--particles=<integer>`,
`--preset=vortex|galaxy|burst|fountain`, `--particle-backend=gpu|analytic`,
`--render-scale=0.75|0.5`. Invalid counts/presets/backends report an error and
use the safe 32K scene; smoke returns a failing exit code for malformed input.

### Reusable field API

```gdscript
const ParticleField = preload("res://particle_lab/field.gd")
var effect := ParticleField.new()
effect.budget = 8192  # choose a smaller per-map budget BEFORE configure
world.add_child(effect)
var result: Dictionary = effect.configure(2048, "fountain", "gpu")
assert(result.ok)
effect.set_appearance(0.16, 0.65)  # world-space quad size, additive energy
effect.set_paused(true)
effect.reset()  # deterministic initial field; preserves pause
var live: Dictionary = effect.snapshot()
effect.dispose()  # idempotent; releases buffers/nodes/materials immediately
effect.queue_free()
```

- `configure(count: Variant, preset: Variant = "vortex", backend: Variant =
  "gpu") -> Dictionary`: positive integer count up to the smaller of `budget`
  and 1,048,576. Returns `{ok, count, preset, backend}` or `{ok:false,error}`.
  Invalid values leave an existing field unchanged. A valid reconfiguration
  resets the clock, preserving pause and node/material/mesh identities.
- `reset()`, `set_paused(bool)`, `set_appearance(float,float)`, `dispose()`.
- `snapshot()` reports actual `GPUParticles3D.amount` / `amount_ratio`, or
  `MultiMesh.instance_count` / `visible_instance_count`, exact draw-slot budget,
  clock, bounds-related capacity, estimated buffer payload and Moth resources.
- `resource_ids()` supports lifecycle/identity verification. These are resource
  IDs, not GPU buffer handles. A count change legitimately resizes GPU buffers.
- Local fields can be moved/rotated as a node. Analytic mode receives the
  field's global transform as one uniform; particle size is world-space.

## What actually runs on the GPU

### Default: true GPUParticles3D simulation on Compatibility

Godot **4.5.2's OpenGL Compatibility renderer supports particle shaders via
transform feedback**. Compute-shader availability is not the deciding factor.
The pinned engine's [`drivers/gles3/storage/particles_storage.cpp`](https://github.com/godotengine/godot/blob/4.5.2-stable/drivers/gles3/storage/particles_storage.cpp)
uses `glBeginTransformFeedback` / `glDrawArrays(GL_POINTS, ..., amount)` for
particle simulation and for packing the instanced draw buffers.

`simulation.gdshader` persists each particle's position and velocity and takes
an exact critically damped spring step toward an evolving flow target. This is
stateful GPU simulation. All slots initialize together (`explosiveness=1`,
`amount_ratio=1`), remain active, and use one quad draw pass. Reset uses a fixed
seed. There is no CPU particle animation, depth sorting, collision readback,
preprocessing warm-up loop, trail pass or fixed-FPS catch-up loop. The shader's
spring update stays finite during very slow native render frames.

The shader does not depend on unsupported Compatibility trails, subemitters,
SDF collisions, vector-field attractor nodes, glow or compute shaders. Our
Moth flow field is sampled in the particle shader directly. Index-order
additive rendering avoids the engine's CPU depth-sort path.

### Selectable comparison: one-MultiMesh GPU analytic motion

`B` switches to the explicitly labeled **GPU analytic vertex motion** backend.
One bounded MultiMesh uses `INSTANCE_ID` to compute deterministic trajectories
in its vertex shader. It has no stateful particle simulation. The shader
intentionally ignores zero-initialized instance transforms and supplies clip
positions itself. The explicit custom AABB is required for correct culling.
No CPU per-instance buffer fill or per-frame array upload is necessary.

Both backends share field targets, Moth resources and small soft billboards.
The simulation's spring lag produces different motion from the analytic mode;
these are meaningful alternatives, not two names for the same backend.

## Effects and material behavior

- **Storm vortex:** rising funnel, nested rotating filaments, cyan/magenta.
- **Spiral galaxy:** five differentially rotating arms, gold core, blue halo.
- **Ion burst:** four independently phased expanding orange/gold shells.
- **Plasma fountain:** green/violet ballistic crown and twisted nozzle.

All load authentic resources through `res://moth/library.gd`: animated
`arc-burst` frames, `flow-field`, and the `entanglement` material LUT. The source
effect alpha is explicitly scanned by tests: the baked frames are opaque.
`particles.gdshader` subtracts their dark background and derives circular soft
coverage. A narrow core plus local halo and additive emission give a luminous
appearance without fullscreen glow. Quad corners are discarded, rather than
displaying full opaque squares. No assets are fetched/generated externally.

## Controls and budgets

| Control | Action |
| --- | --- |
| `1`–`4` / four preset buttons | Switch effect; reset clock |
| `−` / `+` / budget buttons | 8,192 / 32,768 / 131,072 / 524,288 / 1,048,576 |
| `B` | True GPUParticles simulation ↔ GPU analytic MultiMesh |
| Space / `R` | Pause/resume / reset (preserves paused state) |
| `V` | Explicit 100% / 75% / 50% 3D render target; HUD stays native resolution |
| Drag / wheel / `O` | Orbit / zoom / automatic orbit |
| `F`, hold RMB | Freeflight, capture mouse while looking/moving |
| WASD / Q/E / Shift | Freeflight planar / vertical / fast movement |
| Escape / release RMB | Release mouse and movement immediately on next engine frame |
| `[` / `]`, `,` / `.` | Quad size / additive energy |
| `L` / Low-energy view | Explicit 0.06 / 0.85 additive energy toggle, useful at massive density |
| `H` | Show/hide HUD |

Default allocation is **32,768**, not a hidden million-particle pool. The inactive
backend releases its large allocation. Count and quality never change
automatically; even the half-resolution target is an explicit user choice and
is displayed. One million slots is a manual stress test. Input is handled
without modal dialogs or a synchronous benchmark loop; on a slow renderer the
next native frame still bounds input latency.

The count is **draw slots**, not a claim that every particle covers a distinct
visible pixel. GPUParticles exposes amount and ratio, not a cheap live visible
pixel query. Analytic mode reports both real instance-count properties. Native
tests additionally require the actual primitive counter to include at least
two triangles per requested slot. Transparent overlap, subpixel sizes and
camera clipping can reduce distinct visible pixels without changing allocation.

### Memory and timing labels

The 4.5.2 GLES3 GPU simulation payload estimate is **320 bytes/slot**: two
96-byte process buffers plus two 64-byte instance buffers, without userdata or
sort-history buffers. At 1,048,576, that is 320 MiB, plus engine/driver resources
and transient allocation copies. Analytic transform payload is 48 bytes/slot
(48 MiB at 1M), plus engine/driver copies. These are explicitly estimates;
captures separately report engine buffer/video/static-memory monitors. Some
OpenGL memory counters are unavailable and may report zero.

The bounded 240-sample live median/p95 uses **wall-clock intervals between real
`RenderingServer.frame_post_draw` signals**. This is end-to-end render cadence,
not GPU timestamp timing. It includes engine/driver/software-renderer stalls.
No time-scale change, forced draw, artificial FPS or frame multiplication is
used. Changing settings resets the measurement window. Test warm-up frames
and measurement intervals are recorded separately, including raw intervals.
The separately labeled **simulation clock** uses normal engine delta; Godot
can clamp that delta at very slow frame rates, so it is not a wall stopwatch.
This does not affect the measured wall-clock render intervals.

## Reproduce

```sh
python3 port/native-particle-lab/run.py --checks-only
python3 port/native-particle-lab/run.py --quick
python3 port/native-particle-lab/run.py --quick --stress-lifecycle
python3 port/native-particle-lab/run.py
# One bounded case, independent of the full sweep:
python3 port/native-particle-lab/run.py \
  --case 1280x800:1048576:galaxy:gpu:1 \
  --output /tmp/opencode/particle-million
# Same real million-particle draw, explicitly less saturated presentation:
python3 port/native-particle-lab/run.py \
  --case 1280x800:1048576:galaxy:gpu:1 --energy 0.06 \
  --output /tmp/opencode/particle-million-low-energy
```

The runner stages only this lab, its tests and the existing Moth library. It
uses the pinned binary, isolated HOME/XDG directories, private Xvfb with
`-nolisten tcp -nolisten unix`, dummy audio, and software Mesa. Every subprocess
has a timeout, and owned processes are reaped. No services or shared project
files are changed. Evidence preserves errors/timeouts instead of silently
substituting a smaller count. Each native capture takes eight warm-up render
frames then up to 120 real intervals, allowing a 15-second measured window
with a minimum of 24 render frames; the outer 90-second process limit bounds
even extremely slow cases.

Verification covers transactional malformed-input rejection, actual count
changes, stable node/material/mesh identities, configurable caps, paused clock,
reset, authentic resource alpha, release of inactive backend capacity,
idempotent disposal, resource weakrefs and eight warmed create/dispose cycles.
Native capture tests pause for byte-identical render-target images, exercise
Escape through input dispatch, and verify full-count primitive submission.

Executed metrics, direct visual review and any limitations are recorded in
[`RESULTS.md`](RESULTS.md). Software llvmpipe evidence does not establish
hardware GPU performance acceptance.
