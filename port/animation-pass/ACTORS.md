# Actor animation pass — 2026-10-01

Presentation physics is implemented on the existing rigid mesh pivots. Roots,
source movement, AI, weapon cadence, health and authoritative hit regions stay
source-owned. Production `apply_actor` / `advance` paths serve both play and menu.

## Primary references actually read

* [Godot 4.5 SkeletonModifier3D](https://docs.godotengine.org/en/4.5/classes/class_skeletonmodifier3d.html): modifiers run after AnimationMixer; a modifier requires a Skeleton3D parent, and the skeleton applies influence itself. These imported actors have **Node3D rigid pivots**, not Skeleton3D bones. A small post-pose solver fits their actual hierarchy.
* [Godot 4.5 SkeletonIK3D](https://docs.godotengine.org/en/4.5/classes/class_skeletonik3d.html): deprecated; FABRIK overrides chain transforms, with influence and pole controls. Two fixed-length links here have an analytic solution; adopting this deprecated bone-only node would require re-authoring assets.
* [Godot 4.5 PhysicalBoneSimulator3D](https://docs.godotengine.org/en/4.5/classes/class_physicalbonesimulator3d.html): applies PhysicalBone3D simulation to Skeleton3D, supports selected bones and collision exceptions. That is a different rig/physics contract. Current finite cosmetic death transitions remain appropriate; there are no new gameplay-obstructing rigid bodies.
* [Daniel Holden, Spring-It-On: The Game Developer's Spring-Roll-Call](https://theorangeduck.com/page/spring-roll-call), exact damper, critical spring and inertialization sections: frame-scaled linear interpolation and Euler springs can vary/explode with large dt. `motion_math.gd` uses the exact critically damped closed form, preserving spring velocity across goal changes. It is bounded secondary presentation, not an authority movement controller.

## Coverage inventory

|Owned state/path|Implementation / disposition|
|---|---|
|Operator idle/breathe|Existing small chest/head breath retained; support feet remain still. Source pose solver and provenance fixtures retained.|
|Walk/run/strafe/backpedal|Travel-distance clock, 62% flat stance / eased lifted swing, smoothed travel-plane rotation, start/stop amplitude follows damped speed. Existing two-link hip/knee/ankle solver retains level foot orientation.|
|Start/stop/turn|Velocity-change impulse into analytic bounded lean; direction easing avoids abrupt leg-plane flips. Authority body turn and aim focus retained. No invented root turn delay.|
|Airborne/land/crouch/slide|Spring-blended grounded chains and travel-plane rotation, exact landing spring with impact-speed impulse, spring root-height transitions, existing source crouch/slide poses; no discarded 50ms locomotion timestep.|
|Aim/fire/reload/switch/melee|Source aim retained; exponential shot recoil; exact spring on source reloading/weaponSwitch/melee signals. Reload lowers/rolls held weapon and services left grip with timer-normalized bounded offset; right grip stays aligned. No speculative shot/damage events.|
|Operator damage/death/respawn|Source hit channels and existing captured-pose finite cosmetic fall retained; respawn clears locomotion/handling inertia.|
|Six robot gaits|Two-link rigid leg solve at near/middle LOD; distinct biped, sentinel ripple-tripod, diagonal quadruped and alternating Warden hexapod patterns. Cycle lengths differ by role. Far LOD retains directional rigid motion because its shin is fused into the hip mesh.|
|Robot direction/plant/tell|Body-yaw local velocity directs steps; exact spring start/stop and tell blending. Windup/stagger/exposed states plant even if a stale velocity sample remains. Mortar cradle raises, Warden front legs prepare stomp, Bulwark guard drops; optics preserve authority punish-window colors.|
|Robot damage/guard break/death|Confirmed hit flare/recoil and shield amber flash retained. Living chassis displacement is only 8mm gait / 12mm hit (before scale), without living chassis pitch/roll. Death uses quintic settling into the existing 0.8s lifetime. Respawn resets spring state.|
|Robot sensor containment|Sensor pitch bounded to reviewed ±0.4 radians, sensor relative yaw ±0.025; excluded gun cradle carries remaining relative aim yaw. No expanded monster hit regions. Expanded real-fire fixture catches the old Warden ±0.5 pitch escape.|
|Terrain support|Read-only layer-1 StaticBody ray queries under feet, ±12cm maximum correction with exponential easing; missing terrain preserves source support plane. Robot correction is local-scale normalized. Root never moves.|
|Mara/Ivo gestures / menu|Shared finite wave/point/work gestures use quintic key easing and preserve exact current pose on interruption. Story staging moves/turns with dt-based easing. Story walk clock follows actual displayed displacement; stationary story actors stop marching. Standalone gesture showcase retains its explicit walk pose.|
|Patch idle/walk/sit/pet/work|Support paws no longer inherit endless idle root bob. Distance/speed-aware contact gait, spring-blended walk/sit/happiness, diagonal steps, restrained delayed ears, finite pet lean, pose/LOD/serial contracts retained. Production director supplies measured displayed speed.|
|`world/actor_visual.gd`|Audited: referenced only by historical `player_models/preview.gd` static before/candidate comparison and its baseline test. Production presentation preloads source operator. Kept static so its historical measurement remains meaningful.|

## Constraints and limitations

* Procedural contact is **not world-space locked motion matching**. Robot stance
  travel matches the distance clock at steady full gait; start/stop blends and
  reach clamps can still slide slightly. Operator step amplitude is bounded by
  its short source legs, so high-speed run cannot perfectly lock world contact.
* Robot imported shin meshes include feet; ankle sole leveling cannot be independent
  without splitting/re-authoring those meshes. Target endpoints are grounded,
  while an angled foot box can intersect the ground slightly. Far LOD is fused.
* Ground sampling is shallow/bounded static-surface fitting, not navigation or
  predictive stepping over large ledges; no support platform physics is invented.
* Story support is collision-free staging; menu camera replay remains the same
  production controller. Captures are deterministic staged state sequences and
  real menu replay, not a human combat playthrough or release package benchmark.

## Reproduction

Use a single serialized Godot process with `LP_NUM_THREADS=1` and a worktree-local
import cache. Replace `$GODOT` and `$EVIDENCE` with absolute paths.

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --editor --import
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/animation_pass/actors.gd
ACTOR_ANIMATION_POINTS="$EVIDENCE/animated-points.json" LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/animation_pass/geometry.gd
ACTOR_ANIMATION_POINTS="$EVIDENCE/animated-points.json" node --test port/animation-pass/actors-fire.test.mjs
ACTOR_ANIMATION_CAPTURE="$EVIDENCE/after" LP_NUM_THREADS=1 python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility --script res://tests/animation_pass/capture.gd
COCS_ATTRACT_EVIDENCE="$EVIDENCE/menu-sequence" LP_NUM_THREADS=1 python3 tools/godot-dev/xvfb_run.py "$GODOT" --path godot --rendering-method gl_compatibility --fixed-fps 30 --script res://tests/animation_pass/menu_sequence.gd
```

`geometry.gd` writes only when `ACTOR_ANIMATION_POINTS` is set. The separate old
`campaign/targeting_geometry.gd` in this base writes its fixture unconditionally;
acceptance preserves original bytes, tests the newly extracted points, then
restores them. No generated source/game-core edit is involved.

For before capture, temporarily extract robot/puppy/operator/locomotion/gesture
scripts from `4d41cdef` to `godot/tests/animation_pass/reference_<name>.gd`; change
only the reference operator's locomotion preload to the reference copy. Set
`ACTOR_ANIMATION_BEFORE=1`. Exact extracted scripts are retained with evidence;
these temporary fixture scripts are not part of the implementation commit.

## Parent integration

Include new runtime dependencies `source_operators/motion_math.gd` and
`source_operators/ground_contact.gd` in explicit resource closure lists. No shared
presentation/session hooks are needed. Gate the native actor test and explicit
geometry→source-fire chain above. Parent owns packaging, combined build and release.

## Acceptance evidence

Directory: `/home/mojo/.tmp-on-disk/cocs-animation-actors-evidence-20261001/`.
All native runs used Godot **4.5.2**, serialized, `LP_NUM_THREADS=1`; graphical
runs used privately owned Xvfb and GL compatibility/llvmpipe. No Blender or
additional agent was needed. Engine slot explicitly released after final runs.

* `actors-terrain-closure.log`: **3,258,456 assertions, zero failures**. Most are
  per-vertex live chassis/sensor containment checks, not millions of independent
  gameplay cases. Behavioral checks cover exact spring 30/60/144 Hz, contact
  stance/swing continuity, all-six-role pose consistency, windup planting,
  pause/invalid dt, finite death/respawn, idle paws/ankles, reload right grip,
  interrupted gesture pose continuity, bounded hitch landing, native terrain
  queries and actual six-role leg endpoints/operator ankle fitting to a raised
  static surface with unchanged roots.
* Constant robot pose differences at 60/144 versus 30 Hz: **0–0.000691 rad**,
  within 0.002 rad float tolerance. Operator transition peak adjacent foot
  travel: **0.10996 / 0.05520 / 0.02384 m**, respectively. The test requires
  travel less than `3.8 / fps` metres, detecting a discontinuity that survives
  increased frame rate. Final operator feet agree within 5mm.
* `animation_pass-geometry-verified.log`, `source-fire-aim-final.log`: **18,468
  native imported solid triangle-centre samples → 73,872 real source fire/damage
  checks**, all pass. Includes six roles, three body yaws, requested pitch −0.5 /
  0 / +0.5 (bounded on the visual), relative aim ±0.6, moving/tell/damage/exposed
  states, multiple animation frames and feet at terrain y=7.5. No hit volumes
  were changed.
* Existing source-operator acceptance: **6,138 joint-world matrices**, **450
  grip cases / ten weapons**, all-ten-weapon art/anchor checks and presentation
  lifecycle pass. Existing story presentation, **7,615 story gesture checks**,
  **459 robot checks**, native campaign/Horde current-authority-pose targeting
  test (**2,988 points**), and **8/8 Node targeting tests** pass. Existing targeting
  test includes 11,952 actual fire checks plus Horde, shield and projectile paths.
  `generate-core.mjs --check` passes. Generated targeting fixture bytes restored.
* Final rendered evidence: **180 before + 180 after frames** per six-second
  overview and close cast view. `actors-before-after-final.mp4` and
  `cast-before-after-final.mp4` are 30fps split-screen comparisons. Frames and
  final contact sheets were inspected: clearer alternating/ripple supports,
  planted combat silhouettes, restrained tell movement, operator directional
  chains and left-hand reload service, quiet Patch idle and eased sit/pet.
  `gait-frame-sequence.png` provides 12 consecutive earlier reviewed gait frames.
* Real production menu: existing graphical spot check **12/12**, and new
  `menu-sequence-verified.log` **93/93** with **90 sequential frames** (three
  seconds, fixed 30Hz). `production-menu-mara.mp4` shows the unchanged functional
  menu over the actual shared story performance; foreground panels obscure part
  of the cast by design. This complements the clear staged cast close-up.

### Failed attempts retained

`actors-first.log` preserves a too-tight rotation comparison (single-precision
quaternion angle noise of 0.000691 rad); tolerance is now 0.002. Expanded native
geometry first exposed the old Warden −0.5 pitch escape (`source-fire-first.log`);
bounding solid sensor pitch fixed real-source registration without enlarging
targets. `actors-root-continuity.log` and `actors-plane-continuity.log` preserve
transition measurements during refinement: root height smoothing alone left a
5.6cm airborne plane snap; grounded rotation blending removed that fixed jump.

The initial menu spot run lacked its required evidence environment; the first
graphical real-time run then outlasted the finite clip on software rendering.
Fixed-delta spot check passes. The first new sequence waited on both process and
draw signals, consuming two simulation frames per saved frame and reaching the
next clip before its final assertion. It now waits on exactly one draw per frame,
guards the lifecycle assertion and completes at the intended 90-frame bound.
Those logs and captured frames remain alongside the passing sequence. Early
captures with the rear-facing/wide camera are retained; final cast views face
the actual silhouettes. These are verification-harness failures, not omitted
release gates or a claim of human-paced combat acceptance.
