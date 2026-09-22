# Aurora Basin — native exploration

An additive, offline Godot-native polar-night environment, based on `7bfb473289df582e62be5fe21d83e840e5aa7439`. This is a standalone exploratory showcase; the existing nine combat maps remain source authority.

## The place

1. **Halcyon Landing:** a circular landing apron, slotted observatory dome, polar telescope, orbital instrument frame, and amber wayfinding.
2. **The Fracture:** a 49-plate frozen lake, recessed turquoise fracture inlays, a pressure ridge, two curved ice arches, and a continuous 169.5 m lakeside circuit. The fractures are sealed, walkable ice.
3. **The Crown:** a 4.6 m-wide, curved, approximately 128 m skywalk rising to a 9 m lookout. Both approaches descend to the lake circuit. Guard rails open at the lookout entrance and the ground-level junctions. Maximum authored ramp grade is **16.36°**.

The basin includes a sculpted snowy mountain rim, irregular glacial cliffs, two gently animated high-altitude aurora curtains, a star-and-moon sky, and three small local snow fields. The map diagram and unobtrusive HUD show location and controls.

## Launch and integration

Scene: **`res://aurora_basin/demo.tscn`**

```bash
/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
  --path godot --rendering-method gl_compatibility \
  res://aurora_basin/demo.tscn
```

Add `-- --smoke` to build, render, log resource counts, and exit after three scene seconds. Import the project first on a clean checkout, or use the isolated verification runner below.

**Lead-owned launcher hook:** dispatch `--experience=aurora-basin` to `res://aurora_basin/demo.tscn`. This branch supplies the scene, not the shared launcher switch.

`demo.gd` resolves `res://exploration/walker.gd` with `load()` in `_ready()`. The required shared-controller contract is:

```gdscript
extends CharacterBody3D
var camera: Camera3D
func set_spawn(position: Vector3, yaw := 0.0, pitch := 0.0) -> void
func reset_to_spawn() -> void
```

On this baseline, the shared controller does not exist, so the scene dynamically uses `res://tests/aurora_basin/test_walker.gd` and prints that fact. This is a private compatibility probe with WASD/mouse, Shift, Space, Esc, and R; it changes no shared InputMap. Once the lead's script is present it is selected automatically. No setup dialog appears.

### Map API

`res://aurora_basin/map.gd` extends `Node3D`:

| API | Meaning |
| --- | --- |
| `build()` | Build once after adding the node to the scene tree; subsequent calls are no-ops. |
| `get_spawn()` / `spawn` | Feet position `Vector3(-23, 0.12, 34)`, just above the landing. |
| `SPAWN_YAW`, `SPAWN_PITCH` | Radians `-0.455`, `0.106`; forward view toward the arches and aurora. |
| `route_points` | 145 points closing the 27 m-radius lake circuit. |
| `landing_points` | 25 points connecting the landing and lake route. |
| `skywalk_points` | 109 points, east entrance → lookout → west entrance. |
| `camera_views()` | Authored `landing`, `observatory`, `fracture`, `vista`, `overview` poses and eye-level flags. |
| `area_at(position)` | Display label for the local landmark. |
| `resource_report()` | Geometry, collision, instancing, light, particle, finite-transform, cache, and construction counters. |

Demo camera: 74° vertical FOV, 0.12 m near clip, 450 m far clip, 2× MSAA. The probe capsule is 1.8 m high, radius 0.35 m, eyes 1.6 m above its feet, speed 6 m/s, sprint 10 m/s, and 45° maximum floor angle.

## Rendering and resource budgets

Godot **4.5.2 / GL Compatibility**. Terrain, plate clipping, tubes, arches, dome, ribbons, and routes are generated once at construction. Repeated ice fragments, rail posts, piers, and beacon components use MultiMesh. All animation uses shaders or fixed-capacity particles; no nodes or materials are spawned per frame.

Final authored map counters:

| Resource | Count |
| --- | ---: |
| Map nodes | 525 |
| Mesh instances | 87 |
| Non-instanced mesh triangles | 45,976 |
| MultiMesh batches / instances | 9 / 223 |
| Expanded MultiMesh triangles | 10,302 |
| Total expanded static triangles | **56,278** |
| Collision shapes | 206 |
| Lights / shadow lights | **3 / 1** |
| Snow emitters / total live capacity | **3 / 384** |
| Aurora transparent ribbon layers | 2 |
| Inherited Moth texture-cache entries | 11 |

The inherited `moth/surfaces.gd` and `moth/library.gd` supply unchanged baked `ice-cracked`, `hex_paneling-mottle`, `brushed_metal`, `weathered_concrete-worn`, their normals, the `frost` sky plane, and the `entanglement-ceramic` LUT pair. Triplanar procedural surfaces leave UV.x at zero because the inherited vertex-tint shader reserves that channel for semantic depth priority.

Atmosphere uses ordinary depth fog, an authored sky shader, two additive aurora meshes, and soft local CPU snow. Emissive-looking route markings and cracks work without a post-processing glow pass. There are no volumetric-fog, SSAO, or hardware-performance claims.

## Verification and captures

```bash
python3 port/native-aurora-basin/verify.py --stage all
```

This runs native import, compile preflight, collision traversal, smoke launch, and five views at **960×640 and 1280×800**. Each invocation creates a new evidence directory and private HOME/XDG directories under `/tmp/opencode`. Screenshots use a private Xvfb with `-nolisten tcp -nolisten unix`, the pinned engine above, and `LIBGL_ALWAYS_SOFTWARE=1`. The runner shuts down its display. No shared display, server, or network service is used.

The physics harness uses real `CharacterBody3D.move_and_slide()` with the capsule dimensions above. It probes the lake circuit, continuous sealed lake floor, both skywalk directions, lookout access, both lake/skywalk junctions, and landing spawn. Ray checks verify support heights and floor normals. It checks idempotent construction, finite geometry and transforms, resource ceilings, and stable map node counts. Captures assert exact image size and stable node/resource counters after warmup.

**Final evidence and measured software-renderer timings are recorded in [VERIFICATION.md](VERIFICATION.md).** Frame timings are wall time between completed native draws, after 24 warmup frames, over 60 measured frames. They are llvmpipe observations, not a hardware-GPU benchmark.

## Preserved failures and visual iterations

Every attempt is retained under `evidence/`, including:

* `run-20260922T083633829693Z`, `run-20260922T083633829704Z`: first script parse failures (enum spelling and inferred Variant types). The second run was interrupted by the outer tool timeout and contains raw logs without a completed summary. No accepted images were produced.
* `run-20260922T084050952549Z`: actual capsule traversal exposed a raised landing overlapping the lake circuit and a lookout cylinder/rail blocking both skywalk approaches. Its companion `run-20260922T084050995467Z` images also revealed coplanar landing surfaces and Moth semantic UV depth bias incorrectly applied to ordinary mesh UVs.
* `run-20260922T084459336473Z`, `run-20260922T084459361133Z`: an explicit Vector3 annotation was needed in the rail-gap builder. Compile preflight was added to the runner afterward.
* `run-20260922T084826148643Z`: lake circuit was still obstructed by the low skywalk approach. The approaches were moved outside the circuit before gaining elevation and ground-level rails opened. Companion visual captures exposed distant lake depth fighting; the luminous inlay was physically recessed below a separate continuous collision floor.
* `run-20260922T085138470553Z`, `run-20260922T085328308754Z`: reverse skywalk traversal found a leaning cliff reaching the capsule at head height. The latter retains actual blocking contact normals/positions. Glacial cliffs were moved farther onto the mountain rim; both directions then passed in `run-20260922T085508710357Z`.

Earlier images are iteration evidence, not the final accepted appearance. Native images were opened and inspected during each visual revision. The final inspected set is listed in `VERIFICATION.md`.

## Scope and limitations

This branch owns only `godot/aurora_basin/`, `godot/tests/aurora_basin/`, and `port/native-aurora-basin/`. It adds no campaign/combat, multiplayer, server, schema, source-game, or catalog integration. The observatory is an exterior landmark. Cliff and pressure-ridge collision uses coarse convex hulls; authored route collision is separate and verified. Small distant cracks and stars may still alias. Software-renderer rates are resolution-dependent. The final shared walker and launcher selection are lead-owned integration checks; baseline verification uses the private compatible controller.
