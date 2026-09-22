# Cinder Array: production-controller crest repair

## Result

Godot **4.5.2-stable**, production `res://exploration/walker.gd::step()`:

| Traversal | Reached | Physics frames | Off-floor frames | Controller resets | Worst waypoint height error |
| --- | ---: | ---: | ---: | ---: | ---: |
| Forward, walk (6 m/s command) | 16/16 | 2022 | 0 | 0 | 0.01895 m |
| Reverse, sprint (10 m/s command) | 16/16 | 1216 | 0 | 0 | 0.01878 m |

Both the fixed-frame run (`verified.json`) and ordinary headless run
(`verified-realtime.json`) passed **1246 assertions**, with identical traversal
results and no engine/script errors in their logs.

## Finding and repair

The original map reproduced the reported forward stall exactly:
`(-20.12536, 15.89261, -28.52951)`, aiming for `(-23, 16, -28)`, after
9/16 waypoints. `before.json` records the real slide contact: floor shape 65,
normal `(0.455411, 0.886171, -0.085449)`, depth `0.02032484`, zero resulting
velocity, and the convex shape's vertices. No controller reset occurred.

Rim Ascent's incline ends at `(-20.44, 16, -28.48)`. Originally its collider
continued 15 mm beyond this crest, to a top elevation of **16.00695 m**, while
the separate upper-landing collider extended backward at **16.0 m**. The
production capsule stalled at this overlapping convex-solid junction even
though it still reported a walkable floor. Floor rays alone did not expose
the problem. The baseline reverse attempt then started from the failed
forward position, so its failure was not an independent reverse-loop result.

`map.gd::_connection_collision()` now makes each incline and its upper landing
one convex floor solid, ending the incline exactly at its visible crest. It
retains the lower level section and its small collision overlap. This removes
the internal crest end faces and the tiny overshoot above the upper landing.
The same construction applies to the map's four ramps in either slope
direction: SuspendedSpan, RimAscent, WestDescent, and ReturnRamp.

This is a collider-topology repair. The authored route, visible polygons,
slopes, rails, tunnel lining, and waypoint thresholds are the same. The map
has 99 collision shapes instead of 103, and 212 nodes instead of 216; its
23,474 authored triangles, 91 mesh nodes, and 1,180 instanced solids match the
baseline. The production walker file was not edited.

## Verification details

The verifier's subclass only adapts the desired world-space direction to the
local input axes passed to production `step()`. It inherits the real capsule,
gravity, floor handling, speeds, and `move_and_slide()` implementation:

- Capsule radius **0.35 m**, height **1.8 m**.
- `safe_margin = 0.02`, `floor_snap_length = 0.3`,
  `floor_constant_speed = false`.
- No jumping, waypoint teleporting, or resets during either traversal.
  Reverse starts at the forward loop's endpoint.
- Floor support now requires **exactly zero** off-floor frames, rather than
  tolerating up to 11. Each traversal also asserts zero controller resets.
- All **342** centre/edge-strip floor ray probes passed, including the
  visual-height and walkable-normal checks. Maximum ramp slope: **27.60077°**.
- Both bridge rails arrested **70 frames of outward sprint** at approximately
  **2.1553 m / 2.1533 m** across the span, within the **2.4 m** limit. The
  capsule remained on the floor at both endpoints.
- Five bore head-clearance rays remained clear; all five ceiling rays hit
  the native ceiling at **y = 17.2 m**. Both full loops also passed through
  the bore's actual entrances.
- Four out-of-bounds cases restored the authored spawn and cleared velocity;
  nonfinite-position rejection and safe-spawn reset suppression passed.
- Node and collider counts remained stable after traversal and resets.

The existing isolated rail and boundary fixtures reposition the capsule only
**after** both loops, to test those separate conditions. The loop itself
advances exclusively through production movement. The JSON reports include
every waypoint's actual position, rail/tunnel/boundary measurements, controller
configuration, and contact diagnostics on failure.

## Junction captures

`before-capture/` and `after-capture/` contain matching approach and side
views, with both ordinary rendering and `-colliders.png` overlays. Magenta
wireframes are generated from the **actual convex shape debug meshes**, not
an illustrative approximation. The manifests export the actual floor-shape
vertices: three Rim Ascent solids before, two after.

- [Before: side with collision wireframes](before-capture/rim-junction-side-colliders.png)
- [After: side with collision wireframes](after-capture/rim-junction-side-colliders.png)
- [After: ordinary approach view](after-capture/rim-junction-approach.png)

Captures use Xvfb, GL Compatibility, and llvmpipe. These are static junction
inspection images, not an interactive/full-loop video or GPU performance
measurement. Loop evidence is the headless production-controller test; input
is supplied programmatically rather than by desktop key events. Capture logs
include the environment's unsupported V-Sync warning and audio-driver fallback.

## Reproduce

Run from the repository root; all report destinations below are absolute.

```bash
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
OUT="$PWD/port/native-cinder-integration"

"$GODOT" --headless --path godot \
  --script res://tests/cinder_array/verify.gd -- "$OUT/verified-realtime.json"

"$GODOT" --headless --path godot --fixed-fps 60 \
  --script res://tests/cinder_array/verify.gd -- "$OUT/verified.json"

xvfb-run -a "$GODOT" --path godot --rendering-method gl_compatibility \
  --audio-driver Dummy --script "$OUT/capture_junction.gd" -- "$OUT/after-capture"
```

`capture_junction.gd` accepts an optional second argument for a baseline map
script. The recorded baseline was obtained from Git blob
`f76a745ea29a312111bbe993b6b6845346ff9475` (also present at
`f9c45dd3d49a58836303fd8457536cce8b418be4:godot/cinder_array/map.gd`).
The temporary baseline copy was removed after capturing.

`before.*` preserves the instrumented reproduction; `crest-merged.*` records
the first successful topology repair; `verified*` contains the final richer
reports. The pre-existing `port/graphics-batch/evidence/expanded-preflight/`
`cinder-production-physics*` evidence was read only and remains in place.
`provenance.json` records source and protected-evidence hashes.
