# Moth scenery: existing nine-map accent layer

Branch `graphics/moth-scenery`, baseline `7bfb473`. Runtime ownership is
`godot/moth_scenery/`; tests and retained evidence are in the corresponding
`godot/tests/moth_scenery/` and `port/native-moth-scenery/` directories.

## Lead integration

```gdscript
const Scenery = preload("res://moth_scenery/scenery.gd")
const SceneryDetail = preload("res://moth_scenery/detail_control.gd")
var scenery_detail := SceneryDetail.new()

# Once, in the existing viewer UI container:
panel.add_child(scenery_detail)

# In load_map, after ordinary style.decorate(map, world):
var scenery := Scenery.create(map, world, scenery_detail.selected)
scenery_detail.bind_scenery(scenery)
```

`decorate(map, world, detail)` is an alias for `create`. The ordinary style,
terrain materials, sunlight and atmosphere remain supplied by the viewer.
Call `create` after any style/atmosphere decoration; order between the latter
and this layer is immaterial. It reads the resolved source dictionary and
attaches one `MothScenery` root to the same source-coordinate world.

### Public API

| API | Contract |
| --- | --- |
| `Scenery.create(map: Dictionary, parent: Node3D, detail: int = Detail.FULL) -> Node3D` | Immediately frees any prior owned root on that parent, plans deterministic mounted accents, and attaches the replacement. Unknown map IDs produce an empty root. |
| `Scenery.decorate(...) -> Node3D` | Same arguments and behavior. |
| `Scenery.clear(parent: Node3D) -> void` | Immediate, idempotent removal of this lane's marked direct child. Ordinary world destruction also frees everything. |
| `root.set_detail(level: int)` | `Detail.OFF = 0`, `LOW = 1`, `FULL = 2`. Rebuilds only when changed. Off frees every draw resource; Low frees all ambient batches and optional vents/secondary trims. The bounded placement plan is retained for restoration. |
| `root.stats() -> Dictionary` | Caller-owned counts: surfaces, motes, pockets, batches, triangles, explicit per-map ceilings and current detail. |
| `root.geometry_hash() -> String` | SHA-256 of deterministic plate transforms, dimensions, kinds, essential flags, pocket bounds, mote positions and instance data. Independent of detail selection and shader time. |
| `root.placement_snapshot() -> Dictionary` | Deep diagnostic copy of plate/pocket descriptors. No source map reference is retained. |
| `root.set_clock_for_capture(seconds = -1.0)` | Optional deterministic visual probe; negative restores live shader `TIME`. No script ticking is needed. |
| `SceneryDetail.new()` / `control.bind_scenery(root)` | Visible, keyboard-accessible **Scenery detail: Off / Low / Full** `OptionButton`. Keeps the user's choice across maps and only weakly references the active root. |

The settings control has no processing callback. It is optional if the lead
already has a graphics-settings UI; that UI can call `set_detail` directly.
Selecting Low/Off reclaims meshes and materials immediately, rather than only
setting a visibility flag. Create the next map at the selected level to avoid
allocating a Full scene before applying the user's preference.

## Art and geometry

- **Meridian:** slate service displays, narrow warm transit-style wall strips,
  restrained civic-column insets, localized dust.
- **Verdant:** sparse muted chitin/ceramic inlays on existing ruin masonry,
  subdued structural strips, pale pollen pockets. No screens on trees/caves.
- **Ember:** warm etched circuit readouts and corrugated ventilation on the
  existing furnace columns, amber maintenance strips, four local gray ash pockets.
- **Tidal:** cold neutral service plates, icy-white strips and four bounded
  snow pockets; the snow texture contributes RGB detail rather than a dark square.
- **Sunscar:** weathered service circuitry, sand-warm structural trims and dust.
- **Asterion:** cool slate diagnostics, multi-panel relay-feed banks, reactor
  plates, small ventilation-drift pockets. No outdoor snow blanket.
- **Monsoon:** damp-neutral pump/reactor/sluice panels, service-light trims and
  sparse pale moisture motes around machinery.
- **Ion/Aurora:** only existing buildings, substantial columns and light-mast
  surfaces. No track/goal/gate accents or ambient motes. Ion's maintenance plates
  sit above its authored three-metre apron.

All plates are **opaque, depth-tested QuadMesh instances**, mounted **0.032 m**
from a vertical source block face, with a **0.16 m minimum silhouette inset**.
Their four corners remain within one source segment. The planner rejects
faces intersecting nearby solids; strips cannot bridge separate segments or
door openings. Equipment takes priority, followed by substantial columns and
walls, with stable spatial/index ordering. There is no load-time RNG.

The layer adds no colliders, support geometry, horizontal ground, lights,
labels, objective markers, status symbols or free-floating holograms. Existing
labels retain their regular depth/visibility behavior; plates stay against
surfaces that already occlude the same scene. Source cover/crate/pickup shapes,
race rails and soccer goals are not decorated. No source coordinates, modes,
collision or dictionary entries are changed.

Ambient pockets are only 3.6 × 2.6 × 3.6 m, separated by at least 12 m. Solid
blocks and elevated support triangles exclude a pocket. Initial points use a
fixed low-discrepancy sequence, with bounded shader-only drift/fall and edge
fading. They are tiny neutral translucent motes, not fog volumes. Dust/ash/snow
do not emit pickup-like colored flashes. Native GL depth testing is retained.

## Original baked resources

All textures come through the inherited **`res://moth/library.gd`**. No source
files, manifests or baked pixel data are modified or duplicated.

| Role | Original library resources |
| --- | --- |
| Mounted display/inlay | `holographic_grid`, `alien_chitin` |
| Etched equipment/feed paths | `circuit_board-etch`, `circuit_board` |
| Housing/ventilation | `brushed_metal`, `carbon_fiber`, `corrugated_metal` |
| Low-strength original normals | `holographic_grid`, `metal`, `corrugated_metal`, `rough_stucco` |
| Linear anodized-edge LUT | `entanglement`, `entanglement-arcane`, `entanglement-ceramic`, `entanglement-ember`, both R/T planes |
| Ambient density/variation | linear `dust-field`, linear `flow-field` |
| Snow detail | original `effect-weather-snow` frame 0, supplied by `Library.effect` |

The inherited raw-texture and FX/LUT contact sheets were opened before design.
Green circuit pixels are deliberately muted into a map-neutral maintenance
finish. Their blue-channel contrast retains etched paths more clearly than
their nearly constant luminance. Sparse RGB LUTs are sampled **without
`source_color`**, only on a narrow foil edge. LUT rows can be black; the chosen
R phase 0.8 has original nonzero data. Normal samplers and the two field maps
are also linear. Base color maps are sRGB.

Original FX alpha is opaque. The snow shader uses original RGB as a small
radial-mote modulation, with explicit analytic alpha; it never renders the
opaque dark FX background. No heal/shield/capture/teleport glyph assets are used.

Display animation is a gentle ≤9% moving readout modulation. Motes and panels
self-clock in shaders. Runtime scripts have no `_process`, `_physics_process`,
timers, animation players or per-frame node allocation. Compatibility features
only: no glow, volumetrics, screen textures, scene depth reads or extra lights.

## Cost and ownership

The hard global ceiling is **216 mounted quads + 192 motes**; each is two
triangles. Per-map caps in `profiles.gd` are lower where appropriate. At most
**10 MultiMesh batches** are permitted; actual source-map results are recorded
in `geometry.json`. A map uses one shared QuadMesh, one material per mounted
kind, and one material shared across all its ambient pockets. Textures and the
two shaders are shared. Library caching is inherited and bounded at 128 textures.
There is no scenery material/scene cache that keeps former maps alive.

Mounted vents cull after 125 m, other plates after 180 m, ambient pockets after
55 m. These are cheap whole-batch ranges, not per-instance LOD. Ambient motion
has explicit conservative custom AABBs, including drift and billboard extent.
Full→Low→Off→Full rebuilding and same-frame replacement are verified with weak
resource references. Freeing the parent releases the complete per-map layer.

## Reproduction and evidence

```sh
python3 port/native-moth-scenery/run.py
python3 port/native-moth-scenery/run.py --checks-only

# Use the existing environment with Pillow to validate/render contact sheets:
/home/mojo/.hermes/releases/hermes-agent-f11558a08f/venv/bin/python \
  port/native-moth-scenery/review.py port/native-moth-scenery/evidence/<run>
```

The runner copies this baseline project and the read-only generated nine-map
catalog to an isolated `/tmp/opencode` directory. It uses pinned Godot 4.5.2,
private HOME/XDG directories, Dummy audio, software GL, and its own
`Xvfb -nolisten tcp -nolisten unix`. It starts no HTTP server, shared display or
service. Runs have unique directories; all failures are retained. Script/shader
errors, missing completion markers, leaks and nonzero exits fail verification.

Headless verification first uses the **unmodified baseline viewer/style**.
For captures only, `private-staging.patch` records the exact private adaptations:

1. A minimal test-only triplanar mapping uses inherited `MothSurfaces` for
   concrete, equipment/structure, rock/bark and terrain.
2. The inherited Compatibility terrain vertex-color correction removes the
   baseline CPU `.srgb_to_linear()` conversion.
3. `capture.gd` applies inherited Atmosphere and the original Library sky to
   both phases, then calls the scenery API after ordinary decoration.

These adaptations are **not changes to shared files in this branch** and are
not the lead's final semantic texture mapping. They supply a repeatable textured
world beneath this layer. The matched pair changes only scenery visibility;
cameras, lighting, world materials, labels, overlay and source map stay fixed.
First-person eye height is source support +1.8 m, FOV 72, and the harness rejects
cameras inside source solids. Meridian, Ember and Asterion get paired street
and service views at **960×640 and 1280×800**; the other six maps get full-size
overview smoke captures. All image dimensions and camera pairs are asserted.

The accepted-run report and direct image findings are in [RESULTS.md](RESULTS.md).
Geometry JSON records full/low counts, independent deterministic hashes and
every mounted/ambient initial position. The graphical run repeats source
immutability, face-corner constraints, particle bounds and immediate teardown
checks in the real Compatibility renderer. Same-view no-LUT and alternate-clock
captures measure actual LUT/motion contribution on the existing world.

The captures are offline source-map art review, not final lead integration,
packaged-app, live objective HUD or hardware-GPU performance acceptance. The
baseline static yellow pickup spheres and bright window/cover trims visible in
the captures belong to the inherited viewer, not this scenery layer.
