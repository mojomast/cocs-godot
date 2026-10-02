# Responsive combat framing — source candidate

Parent `bb02e34b` merged cleanly into the existing presentation checkout. Nine
production GLBs, masters, lossless import settings, animation adapter, core, data,
stage geometry and FX are unchanged by this follow-up. No nested agents or heavy
processes ran. Exclusive grant `PARALLAX-INTERIORS-PRODUCTION-20261002-C` remains
with the Parallax owner.

## Evidence actually inspected

Read `port/fighting/animation/PRODUCTION_B.md` and these full-resolution existing
PNG frames under `/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/production-b/`:

- `gameplay-refined-meta-mistral/throw-010.png`
- `gameplay-refined-qwen-meta/walk-040.png`

The images show articulated fighters occupying only a small band near the floor,
with the majority of the frame occupied by scenery. Read the Meta/Mistral,
Qwen/Meta and ChatGPT/Claude `trace.json` files: actual Basalt shell/core, 270 PNGs
per sequence, throw/tech/contact events and Qwen/ChatGPT projectile spawns. The
old camera always reserved `(8+2.4)/.58 = 17.93m` of vertical extent. Its roughly
80-pixel grounded bodies are a demonstrated blocker. No new native image or
video was generated or claimed inspected.

## New camera contract

### Real geometry envelope

`presentation/pose_bounds.gd` reads the production MeshInstance3D skin arrays once
after both visuals configure. For every positive bone influence, transform each
mesh vertex with its actual Skin bind pose, accumulate a bone-local AABB and
resolve the real Skeleton3D bone name/index. After `visual.present()` seeks the
actual animation frame, transform each box's eight corners through the presented
bone pose and skeleton world transform. This bounds the deformed mesh rather than
using its stale undeformed mesh AABB, or assuming the two operators have identical
height. Positive normalized blend weights stay inside the union's convex AABB;
the committed operators are rigid-skinned. Invisible LOD mesh nodes are omitted
from frame sampling. No skeleton, animation, import or combat state is written.

Current body bounds are the union of the actual skin envelope and each fighter's
authored standing-height envelope. The latter prevents crouch/knockdown animation
from repeatedly causing an aggressive zoom-in. Current safety adds .18m for edges.
The predictive target adds .45m of motion/FX breathing room and neutral lateral
room proportional to the taller actual body (1.25× height each side), rather than
an always-on jump-height constant. Meta/Qwen throws and rotated victim limbs are
included by their actual presented bone envelopes.

### Jump and projectile safety

Current y/vy comes directly from the snapshot. Positive vy predicts remaining
apex using the rule gravity and a discrete upper bound:

`n = ceil(max(vy,0)/max(gravity,1))`

`rise_m = max(0, n*vy − gravity*n*(n−1)/2) / 1000`

The jump edge at ground uses that fighter's authored jump velocity; committed
`super_jump`/`double_jump` startup reads the move's actual vy and launch frame.
No jump is assumed when both actors are grounded and have no committed launch.
Horizontal lookahead is eight ticks of current vx. No prediction moves fighters
or projectiles or drives hit detection. Every current projectile width/height/XY
is included, regardless of reflected ownership; despawn removes it from the next
target. Current geometry is never capped at a presumed maximum jump.

The ground line remains in view even if both fighters jump. A .30m under-floor
target band preserves platform contact. Camera y is derived from the lower
envelope and bottom HUD region, not an orbit or aim-at target.

### Framing, temporal behavior and reset

- Orthographic KEEP_HEIGHT, unchanged +Z=24, −Z view, near .1 / far 140.
- Target center x is clamped ±4m; required horizontal extent measures distance
  **from that clamped center to both edges**, so corner throws cannot be clipped
  by a midpoint clamp. All four authored crops retain x ±45m behind x ±8m actors;
  their source transforms/geometry are unchanged.
- Top/bottom exclusion comes from actual HUD/input Control heights plus padding,
  not a fixed percentage. Baseline fallback is 155/78 pixels; existing HUD values
  are retained while a modal replaces its Controls. Resize/UI-scale changes fit
  immediately. Fractions are bounded .12–.48 top and .08–.25 bottom, leaving at
  least 27% of the viewport for combat at the most restrictive tested compact UI.
- One presentation update per snapshot tick. Repeated renders of one snapshot do
  not advance the filter; no wall-clock delta enters smoothing.
- Growth lerp .18/tick, shrink .035/tick, center pan .12/tick. .08m size deadband,
  .15m center deadband and 24-tick hold after growth reduce pose/jump pumping.
- Both fighters in hitstop freeze the camera filter. Current geometry containment
  can still override it if a legitimate snapshot/viewport discontinuity requires.
- Hard current-envelope fit runs after easing: it may enlarge the frame for an
  unexpected teleport/contact/projectile rather than clip a fighter. This safety
  exception is intentional; normal jumps have predictive lead-in.
- `configure(roster,rules,visuals)` builds the bind caches once. `reset()` clears
  temporal history at enter/new match, new round and training replay seek. Tick
  regression, large snapshot jumps, viewport/safe-area/reduced-mode changes also
  reset the fit. Old zoom is not carried into rematch.
- Reduced-motion lock reserves the full arena ±9.6m and a fixed 12m vertical
  envelope (8m jump review limit plus 4m pose/safety room). Normal attack-pose
  height changes do not change that lock. A genuine out-of-envelope fighter or
  projectile can still force containment; safety is never traded for a zoom cap.

## Checks run / limitations

`python3 -m unittest discover -s tools/fighting/presentation -p test_camera.py -v`
passes six independent source-only checks: wide/compact UI100/UI150 projection,
grounded-size budget, clamped corner pairs, actual nine-operator jump/mobility
velocities, ascent/hitstop/landing/projectile safety, real nine-GLB bind-space
vertex envelopes/rest reconstruction, and authority-isolation wiring.

The independent oracle predicts >250px body height for the defined close-grounded
1.8/2.1/2.5m envelope cases at 1280×800. **That is a mathematical regression target,
not a measurement of new rendered fighters.** Real skin import/bind mapping,
pose cache CPU cost and actual final pixel readability require native execution.

Existing 918 legacy framing/extrema assertions remain, adapted to reserve the 8m
jump only for locked framing. Source grammar and original resource/hash/isolation
checks remain in `verify.py`. The new owned camera scripts and focused fixtures
pass source grammar parsing. Full Godot static-type/runtime execution is pending.

## Prepared native comparison (UNRUN)

`godot/tests/fighting/presentation/camera_gate.gd` exercises actual GDScript camera
startup/airborne/extreme spacing, repeated snapshot freeze, hitstop, projectile
envelopes, HUD150 and rematch reset after the next grant.

`camera_compare.gd` is a **separate focused fixture**, not a change to animation's
global capture harness. It uses the real shell/visual/core/FX, silent audio, labelled
training positions followed by real command steps. Cases: neutral, jump, throw,
projectile, full separation and corner pair. `--baseline` substitutes the exact
old camera projection after presentation for matched before/after comparisons.
It records images and per-frame camera/pose/snapshot data in `camera-trace.json`.

After explicit serial grant, replace `$GODOT` with the approved 4.5.2 binary:

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/presentation/camera_gate.gd
LP_NUM_THREADS=1 "$GODOT" --path godot --resolution 1280x800 --script res://tests/fighting/presentation/camera_compare.gd -- --stage basalt-reach --operators meta,qwen --output /path/to/camera-basalt-responsive
LP_NUM_THREADS=1 "$GODOT" --path godot --resolution 1280x800 --script res://tests/fighting/presentation/camera_compare.gd -- --stage basalt-reach --operators meta,qwen --baseline --output /path/to/camera-basalt-baseline
```

Repeat serially for `canopy-divide`, `crown-array`, `helix-conservatory`; 760×520,
1280×800 and 1920×1080; UI100/UI150; reduced motion; Meta/Qwen and Grok/Gemini.
Additionally drive Grok charged launch/Gemini double jump through real controls.
Inspect the actual floor line, head/hand/foot and paired-throw silhouettes, camera
breathing, readable near exchanges and projectile tracking. Closer views may
expose stage crop seams/foreground issues; refer those to the stage owner rather
than hiding them by restoring an unreadably distant camera. No native readability,
four-stage composition or GPU/CPU performance acceptance is claimed here.
