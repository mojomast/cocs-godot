# Native first-person weapons

Integration-ready lane on `graphics/viewmodels`, authored against baseline
`b0ac0b54aa6d815e4d61f63e929612069e2c3d11`. The shared session, mode scenes,
HUD, gameplay source and external preview assets are lead-owned.

## Delivered

- Ten source-derived native GLBs in `godot/first_person/generated/`: Pulse Rifle,
  Rocket Launcher, Rail Lance, Scattergun, Plasma Driver, Grenade Launcher,
  Shock Beam, Flak Cannon, Marksman Rifle and Submachine Gun (IDs **0–9**).
- `rig.gd`: camera-relative hip rig, gloved hands/armored forearms, subtle idle,
  grounded locomotion and passed-look sway, source-event recoil and dual/single
  muzzle flashes, switch raise, source-flag reload feed/bolt/barrel movement.
- Independent transparent `SubViewport`/`World3D`. Its perspective camera copies
  the caller camera's FOV/aspect policy; it never writes the aim camera. World
  walls cannot occlude the viewmodel. Canvas layer **0**, HUD above it at **1+**;
  the compositing control ignores mouse input.
- `session_binding.gd`: passive integration adapter for the existing native
  session roots, including roots which override `_ready()`.
- Source hash manifest, byte-identical exporter check, lifecycle/policy tests,
  matched graphical fixtures, and a private normal-rate live input run.

### Source provenance / pulse reservation

`tools/godot-weapons/export.mjs` calls **the existing**
`game/weapon-models/index.mjs` builders using the same material colors and
geometry-helper contract as `game/view.mjs:342`. It reads `CHASSIS`, all ten
per-weapon modules, `game/model-geometry.mjs`, sights and authoritative
`game/data.mjs`. It bakes world transforms into static material batches while
preserving the authored `feed`, `bolt` and barrel assembly pivots. Godot imports
those GLBs as native `PackedScene`/`ArrayMesh` resources.

**`game/weapon-models/pulse-rifle.mjs` remains read-only.** The default Pulse
uses that locked builder through the generic exporter. No external Pulse Rifle
PREVIEW/ASSET reservation, browser preview route, source model, `player_models`,
`game/` or `server/` file is edited. This is the baseline source chassis, not a
replacement design for the separately reserved pulse asset.

The exporter also emits `catalog.gd`, a native metadata resource. Runtime does
not depend on reading JSON or on modifying export include filters. Audit JSON
includes source SHA-256s, GLB hashes, bounds, triangles and mesh counts.

## Lead integration

The included **unapplied** [integration.patch](integration.patch) adds only a
passive scene child to `godot/world/session.tscn`. Check/apply it from repo root:

```sh
git apply --check port/native-first-person/integration.patch
git apply port/native-first-person/integration.patch
```

For other mode roots, add the same child/script to each actual session scene
(`arms_race/demo.tscn`, `horde/demo.tscn`, `objectives/demo.tscn`, sports,
zone modes, combined arms, lattice and any lead-created composition).
Increment that scene's `load_steps` and use a free resource ID. Do not add both
a scene child and an imperative child. The standalone map viewer has no actor
and should not mount the session binding.

Equivalent code, after the root initializes its camera/client/presentation:

```gdscript
var first_person = preload("res://first_person/session_binding.gd").new()
first_person.name = "FirstPerson"
add_child(first_person)
```

The adapter binds deferred, after the root's `_ready`. Each rendered frame it
reads `presentation.local_actor` **after session processing**, and the source
policy fields `phase`, `received_pose`, `application_focused`,
`snapshot_watch.stale()`, `presentation.lifecycle.can_control()`,
`client.actor_id`, `client.spectating`, and transport ready state. It calls the
existing `weapon_controls_active()` (or `can_capture_pointer()` fallback) for
capture/focus eligibility. It never captures the pointer or changes controls.
Disconnected, foreign/unassigned identity, stale, unfocused, dead, spectator,
vehicle and results states hide the rig. A phase/identity boundary resets
transients. `started`, `results`, `connection_error` and `clear_round()` reset
immediately. Existing generic `clear_round` child sweeps can call it safely.

`client.events` is consumed **even while hidden**, after refreshing actor/gates.
This is important: do not put this adapter's event callback inside an alive-only
branch. Its own bounded dedup also handles events repeated in snapshots. It
does not depend on the network client's existing dedup.

### Direct rig API

```gdscript
const FirstPerson = preload("res://first_person/rig.gd")
var fp = FirstPerson.new()
add_child(fp)
fp.attach_to(camera) # In tree; idempotently updates source-camera reference.
fp.apply_actor(actor, can_show)
fp.apply_events(source_events, local_actor_id)
fp.apply_look_delta(Vector2(yaw_delta_radians, pitch_delta_radians)) # optional
fp.reset() # Round start/end, disconnect, actor/room handoff.
```

| Input | Contract |
|---|---|
| `actor.id` | Finite integral nonnegative source identity. |
| `actor.weapon` | Finite integer 0–9. Unknown/missing IDs hide. |
| `actor.health`, `dead`, `spectating`, `vehicleId` | Health must be positive; dead/spectating false; vehicleId null or absent. Source `dead=0` is accepted. |
| `vx`, `vz`, `grounded` | Optional source velocity for bounded cosmetic bob. No position prediction. |
| `reloading` | Only source `true` enables reload choreography. |
| `reloadTimer`, `reloadDuration` | Finite seconds; progress clamps to `[0,1]`. No local reload timer or inferred ammo state. |
| `can_show` | Caller owns phase, transport, focus/capture, stale and spectator policy. Call every render frame or gate transition, not just new snapshots. |
| `events` | Source dictionaries with `type: shot/launch`, integral `id`, finite nonnegative `time`, integral `actor`, integer `weapon:0..9`. Other events are ignored. |

Event identity is `(type,id,time,actor,weapon)`. Trigger grouping is
`(actor,weapon,time)`, so interleaved pellet events produce one kick. Source
`shrapnel` events are excluded. Source launch events whose ID is a projectile
ID remain distinguishable by type/time. No `damage`, `hit` or input-fire flag
can trigger recoil. Hidden events are remembered without playing effects;
late events for a previous selected weapon are consumed without playing.

The combined event/volley memory has **4096 entries** and an expired-time
watermark: very old replays cannot become new kicks after eviction. Call
`reset()` at each round boundary because source serials/time can restart.
Within a round, extremely late events older than the watermark are deliberately
dropped. Do not `reset()` for each snapshot or for a temporary focus/stale gate.

The rig owns cosmetic `_process`; `advance(dt)` is exposed for deterministic
fixtures (disable `_process` when using it manually). `reduced_motion` removes
idle/locomotion/sway and reduces recoil. No input actions, physics bodies,
damage logic, hit confirmation, camera rotation or FOV changes are created.

### Resource and material ownership

There is one live weapon scene, two combined hand/forearm meshes, and at most
two pooled flash meshes. A selected weapon's scene stays cached; repeated
snapshots do not rebuild it. Switching creates one new instance from the
cached scene and frees the previous instance, with explicit render-surface
detachment to avoid Godot 4.5 material-RID teardown errors. Private surface
overrides isolate mutable materials across rigs; immutable imported meshes
are shared. `reset` keeps caches warm; free the rig with the owning session.
Reparent/removal-and-reuse is not supported after teardown; create a new rig.

No Moth dependency is loaded. Current materials use source dark/light/emissive
colors. A later lead integration can augment the **private surface overrides
in `_select_weapon`**, or hand materials in `_build_hands`, using the concurrent
`res://moth/library.gd` texture/normal/material-LUT API. Do not mutate imported
mesh materials. The viewport's `own_world_3d` also prevents weapon lighting or
materials from leaking into the arena.

## Verification / evidence

Pinned engine: **Godot 4.5.2 stable, `6ce3de25a`**, GL Compatibility on private
Xvfb `:187`, Mesa llvmpipe. Xvfb used `-nolisten tcp -nolisten unix`; XDG data,
config and cache were isolated under `/tmp/opencode/viewmodels-runtime`.
The live server was a new `createGameServer({port:0})` on loopback, with default
production tick rate, in-memory persistence and no shared service changes.

- [lifecycle.log](evidence/lifecycle.log): **57 checks**, zero failures. Snapshot
  geometry stability, 10 distinct bounds, instance/cache limits, repeat and
  interleaved event grouping, hidden consumption, shrapnel rejection, source
  reload hinge/reset, material isolation, aim invariance, eviction and round reuse.
- [binding.log](evidence/binding.log): **15 policy checks**: focus/capture/stale,
  lifecycle, results, disconnected transport and identity changes.
- [determinism.json](evidence/determinism.json): source hashes match; all ten
  GLBs and native catalog reproduce byte-for-byte.
- [export-pack.log](evidence/export-pack.log) and
  [pack-check.log](evidence/pack-check.log): native PCK export succeeded and the
  lifecycle suite loaded all ten resources from the exported pack. This verifies
  packaging/resource availability, not a final lead-integrated game executable.
- [framing.log](evidence/framing.log), [framing-metrics.json](evidence/framing-metrics.json):
  24 actual rendered fixtures; all ten weapons at 960×640 and 1280×800,
  **zero occupied pixels in the central 48×48 region** at FOV 75, two wall-depth
  isolation shots, plus event-driven fire and reload fixtures. The real baseline
  HUD is used, above the rig.
- [Live result](evidence/live-result.json): a private session mounted the adapter
  at runtime without editing shared files. Only normal engine keyboard/mouse
  input was injected; snapshots and events came from the unmodified server.
  **318 snapshots, 9.39 m movement, Pulse → picked-up Marksman → Pulse,
  45 recoil events, source reload observed**. The trace and four screenshots are
  live, while `fixture-*` images are explicitly synthetic state/event fixtures.
- [Final-code live rerun](evidence/live-final/live-result.json), after tightening
  transport/identity gates and render-resource teardown: **304 snapshots,
  8.39 m movement, Pulse → picked-up Grenade Launcher → Pulse, 36 recoil
  events, source reload observed**. This also exercises authoritative projectile
  `launch` feedback in addition to the first run's hitscan `shot` feedback.

Inspected with the image read tool: Pulse at 960×640; Rocket and Scatter at
1280×800; Rail at 960×640; the all-ten contact sheet; wall-isolation image;
Scatter fire/reload fixtures; all eight live images below. Center aiming and HUD
remain legible. Source family resemblance remains visible; differences come
from receiver proportions, tubes/rails, scopes, feeds and stocks, not just color.

### Images

[All ten matched fixtures](evidence/fixture-all-ten-contact-sheet.png) ·
[Pulse 960×640](evidence/fixture-960x640-weapon-0.png) ·
[Rocket 1280×800](evidence/fixture-1280x800-weapon-1.png) ·
[Rail 960×640](evidence/fixture-960x640-weapon-2.png) ·
[Scatter 1280×800](evidence/fixture-1280x800-weapon-3.png) ·
[Wall isolation](evidence/wall-1280x800.png) ·
[Shot fixture](evidence/fixture-fire-scattergun.png) ·
[Reload fixture](evidence/fixture-reload-scattergun.png)

[Live Pulse](evidence/live-pulse.png) ·
[Live Marksman](evidence/live-weapon-8.png) ·
[Live reload](evidence/live-reload.png) ·
[Live switched back](evidence/live-switched-back.png)

Final-code rerun: [Pulse](evidence/live-final/live-pulse.png) ·
[Grenade Launcher](evidence/live-final/live-weapon-5.png) ·
[Reload](evidence/live-final/live-reload.png) ·
[Switched back](evidence/live-final/live-switched-back.png)

## Reproduce

From repo root with existing dependencies installed (the implementation run
temporarily linked the primary `node_modules` read-only):

```sh
node tools/godot-weapons/export.mjs
node tools/godot-weapons/verify.mjs
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
"$GODOT" --headless --path godot --editor --import
"$GODOT" --headless --path godot --script res://tests/first_person/lifecycle.gd
"$GODOT" --headless --path godot --script res://tests/first_person/binding.gd
"$GODOT" --audio-driver Dummy --path godot --script res://tests/first_person/framing.gd -- --evidence-out=/absolute/private/evidence
```

For live verification, generate the normal semantic map content first, launch
`PORT=0 node tools/godot-weapons/private-server.mjs`, read its allocated endpoint,
and run the same pinned engine on an owned display:

```sh
"$GODOT" --audio-driver Dummy --path godot --script res://tests/first_person/live.gd -- --endpoint=ws://127.0.0.1:ALLOCATED_PORT --evidence-out=/absolute/private/evidence --mute
```

The observer navigates to a reachable source weapon pickup and sends normal
engine input to fire, select, reload and return to Pulse. Spawn/bot randomness
can change the acquired weapon or prevent a successful route; it does not
rewrite source state to force success. This is engine input, not OS-level input.

## Costs and remaining limits

- Ten GLBs total **4,531,268 bytes** (4.32 MiB), 3,704–6,284 authored weapon
  triangles, 8–11 weapon mesh instances each. Full rig with hands and allocated
  flash meshes is **11–14 instances, 6,376–8,956 triangles**; hidden flashes do
  not draw. See per-ID metrics for exact values.
- One full-resolution transparent 2×MSAA viewport and two unshadowed directional
  lights per local rig. At 1280×800, a single RGBA8 attachment is ~3.91 MiB;
  depth/MSAA/backend intermediates add to that. No extra world pass is created.
- Recorded live full-session frame-time medians were **24.24 ms and 25.76 ms on
  software llvmpipe**. This includes the entire baseline arena and is not a hardware GPU
  budget or isolated incremental viewmodel benchmark. Shader/scene first-use
  costs remain; caches are lazy and at most ten scenes.
- Hands are compact procedural glove/forearm forms, not skinned IK. Reload
  choreography uses the exported feed and source Scatter hinge, with generic
  hand pose. No ADS sight alignment, attachment variants, alt-fire morphs,
  finish unlocks or Moth texture treatment is implemented in this lane.
- Weapon materials use stable presentation lighting, not sampled arena lighting.
  The lockstep hip pose keeps the reticle clear; extreme custom FOVs outside the
  tested baseline may need lead-side framing tuning.
- Shared session/mode integration is intentionally delivered as an unapplied
  patch/instructions. The private live run verifies that proposed adapter path.
