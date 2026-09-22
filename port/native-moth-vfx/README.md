# Bounded native Moth world VFX

Delivery is restricted to `godot/graphics_fx/`, `godot/tests/graphics_fx/`, and
`port/native-moth-vfx/`. Production integration hooks below are **unapplied**.
Baseline: `b0ac0b54aa6d815e4d61f63e929612069e2c3d11`.

## API and integration hooks

`res://graphics_fx/moth_world.gd` extends `Node3D`:

- `configure(provider: Callable)`: provider receives an effect key and returns
  `{frames: Array[Texture2D], fps: number}`.
- `configure_resources(resources: Dictionary)`: same sheets keyed by name.
  Both configuration methods reset the round; configure once when assets are ready.
- `consume(events: Array, local_id: int = -1, actors: Array = [])`: consume fresh
  **public wire events** and latest public authoritative snapshot actors.
- `reset()`: immediate node/material release and event-ID/counter reset.
- `advance(delta)`: automatically called by `_process`; disable processing if
  driving it explicitly in a test. Invalid/negative delta is ignored; long valid
  delta expires effects immediately.
- `active_count()`, `spawned`, `overflow`, `duplicates`, `rejected`: diagnostics.

Example lead-owned composition hook (asset library location provided by the asset lane):

```gdscript
const WorldFX = preload("res://graphics_fx/moth_world.gd")
var world_fx := WorldFX.new()
var public_fx_actors: Array = []

# In composition setup, after the effect library is available:
add_child(world_fx)
world_fx.configure(Callable(moth_library, "effect"))

# In the existing authoritative snapshot callback:
public_fx_actors = frame.state.get("actors", [])

# In the existing public events callback, guarded by the live-round phase:
world_fx.consume(items, client.actor_id, public_fx_actors)

# At authoritative start / results / disconnect / teardown:
world_fx.reset()
public_fx_actors = [] # Release our reference without mutating the public snapshot.
```

For a library exposing static methods, pass its script resource as `moth_library`,
or explicitly build the four-name dictionary using `Library.effect(name)` and call
`configure_resources`. The core has **no preload** of the external asset library.
It consumes `spark-impact`, `effect-explosion`, `effect-teleport`, `effect-heal`.
The concurrent asset lane's `res://moth/generated/effects/<key>-<index>.png`
resources can be passed directly; no rebaking or image modification is required.

Keep the existing `combat.apply_state`, `combat.apply_events`, source projectiles,
tracers, diagnostic blast spheres, hit UI and audio calls in place. This node adds
only short world cues. `local_id` does not trigger a hit claim or a muzzle flash.
The ordinary session and specialized Horde composition each have their own
events connection; hook the composition actually used. Reset on each existing
authoritative round boundary, not on an inferred clock reversal.

## Accepted event fields

Every event requires `id`: a finite nonnegative integer in JavaScript's exact-safe
range `0..9007199254740991`, and a string `type`. Numeric JSON floats and integers
denote the same ID; null, bool, strings, fractions and unsafe numbers are rejected.
Every position component must be finite numeric with absolute value <=100,000.

| Public event | Additional fields read | Visual / authoritative position |
|---|---|---|
| `explosion` | `pos: {x,y,z}` | Explosion at exactly `pos`; `weapon` may be absent in source detonation events |
| `vehicle-destroyed` | `pos: {x,y,z}` | Larger explosion at exactly `pos` |
| `teleport`, `teleporter` | numeric `actor`; valid `from` and/or `to` | One portal for each valid endpoint, without moving the actor |
| `damage` | numeric `actor`, finite `amount > 0` | Small impact at latest public actor `{x,y,z}` plus 1m presentation height |
| `pickup` | numeric `actor`, `kind` equal to `health` or `megahealth` | Heal accent at public actor position plus 1m |
| `mender-heal` | numeric `actor`; finite `x,z`; finite positive `radius,healed` | Event x/z plus latest public actor y + 1m; source omits y |

`actors` entries use numeric `id` and finite **top-level `x,y,z`**. Actor-dependent
cues skip when the actor is unavailable. They remain at their sampled position;
they do not track/predict moving actors. Damage/pickup location is consequently
a latest-snapshot approximation, not an exact wound point. Mender's authored
radius changes only visual size within a 2–4m bound. Health amounts are never
inferred from pickup graphics.

`shot.hit` is deliberately unused: `game/core.mjs` retains a candidate target ID
even on some obstructed trajectories. Shot endpoints alone also do not establish
a collision. Only an actual positive public `damage` event gets an impact cue.
Launches, muzzle flashes, death inference and projectile-disappearance explosions
are outside this module.

## Exact identity and replay semantics

Read sources: `game/core.mjs` (`emit`, `damage`, `detonate`, `explode`, `collect`,
traversal forwarding); `game/singleplayer.mjs` (mender emission);
`game/view.mjs:3030–3145`; `game/moth-sprite.mjs`;
`godot/world/combat_feedback.gd`; `godot/net/client.gd`;
`port/native-horde/authority.mjs:17–28,121–144`.

The source retained event ring can contain **different event objects with exactly
equal payloads**. Source payload `id` can overwrite the source serial with a
device/modifier string. Never deduplicate raw source events by payload, timestamp,
`sourceId`, or a presumed serial high-water mark. Horde's production `EventCursor`
follows retained object identity and assigns a distinct per-round ordinal in wire
`id`, preserving the original value as `sourceId`. This module consumes that wire
ordinal, not `sourceId`. The fixtures execute the actual source `Match.emit` and
extract/import the actual self-contained `EventCursor` class to prove equal source
events still produce two separate visual emissions.

The API intentionally does not accept a raw Match ring or invent IDs. Standard
server wire events are consumed by their delivered numeric ID; events filtered
out by the upstream Room/client cannot be reconstructed here. Raw local-source
integration must retain the production source-object cursor upstream.

Within a round, the numeric ID window is 4096, with O(1) modulo eviction. Reordered
IDs within the window are accepted once. Older IDs are dropped even after cache
eviction, so retained history cannot restart expired effects. A reset permits IDs
to start again at zero. This is bounded replay protection, not arbitrary historical
replay support. Only the first 512 events and 512 actors per call are inspected.

## Rendering and budgets

- 32 pooled quads maximum, two triangles and one material/draw per visible slot.
  Slots allocate lazily, reuse after expiry, replace the oldest active slot on
  overflow, and never temporarily exceed the cap. No pending effect queue.
- Maximum lifetime 0.6s. Source FPS is retained: impact 14 (2 frames), explosion
  14 (3), teleport 12 (3), heal 10 (3). Last frame holds while fading over the final
  40% of the lifetime. Modest growth affects only the presentation mesh.
- World-coordinate top-level nodes; full camera-facing billboard; normal alpha
  blending, depth test on, depth writes off, shadow casting off, unshaded and fog
  independent. No glow, lighting pass or Compatibility-unsupported feature.
- Source RGBA is exact and remains shared. All 11 used source frames are fully
  opaque, with a dark background. The source browser used additive blending.
  The native shader derives coverage relative to the corner background, feathers
  the perimeter, and multiplies original alpha. A five-tap highlight dilation and
  source-signal exposure make the sparse impulses readable without an opaque
  card. This is an intentional presentation treatment, not byte-identical browser
  rendering. Six texture reads/fragment including the background sample.
- Used fixture images total 101,376 raw RGBA bytes (11 × 48 × 48 × 4), excluding
  Godot/GPU overhead. Injected resources are held until reconfiguration/destruction;
  expired slots clear their texture binding. Reset frees pooled nodes immediately.
- 4096 cached IDs plus a 4096-entry int64 modulo table. Per-event dedup is O(1),
  spawn selection and per-frame animation are bounded by 32 slots. Near-camera
  alpha overdraw can still be expensive; there is no hardware-independent GPU/FPS
  claim. The headless stress timing in `evidence/regression.log` is CPU-only.

## Reproduction and evidence

```sh
python3 port/native-moth-vfx/verify.py
python3 port/native-moth-vfx/verify-live.py
```

Both runners use pinned Godot
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`,
private temporary staging beneath `/tmp/opencode`, isolated HOME/XDG directories,
and owned `Xvfb -nolisten tcp -nolisten unix`. All owned processes and staging are
removed afterward. The live runner copies the existing installed `ws` dependency
from the primary workspace and exports semantic maps only into its private copy.

`verify.py` regenerates read-only source RGBA fixture data and validates malformed
payload handling, no snapshot mutation, source-FPS frame progression, exact-safe ID
semantics, equal retained source events, retained replay after expiry, old-history
rejection after eviction, 32-slot saturation/replacement/reuse, invalid delta,
reset freeing, parent freeing, and missing-library behavior. The 300-frame CPU
stress exercises 4,800 spawns under continuous overflow.

Renderer proofs use the actual source frames in Compatibility/llvmpipe:

- `fixture-1280x720.png`, `fixture-960x540.png`: explicit **source-informed fixture**
  montage, near/far rows. Both were opened and visually inspected.
- `alpha-near.png`, `alpha-far.png`, `alpha-angled.png`: effect at 6m, 12m, oblique
  camera. Near/angled each alter 2,581 pixels; far alters 667. Card corners remain
  background, the near image contains 545 color tones, animation changes real
  pixels, an opaque blocker fully occludes the effect, and fade/expiry remove it.
  These are thresholded pixel checks, not a GPU performance measurement.
- `source-*.png`: nearest-neighbor enlarged source-frame references, explicitly
  not rendered alpha output. `source-pixels.json` records raw frame SHA-256,
  dimensions, source FPS, color counts and source-alpha values.

`verify-live.py` runs the unchanged shipped Horde composition in a private copy,
attaching this node through the same signals recommended above. It drives ordinary
native fire/grenade inputs against an owned **normal-rate** local authority, with
no game-state, event, timing, health, position, or protocol injection. Effect
resources are source-extracted fixtures standing in for the concurrent library.
`live-client.json` maps every cue to its exact public event ID/payload and world
position; `live-authority.json` records the authority's public events and step
timing; `live-summary.json` contains the correlation/cleanup result. Godot's JSON
formatter rounds floating point text, so payload numeric comparison tolerates
1e-12; IDs are compared exactly and position conversion to Vector3 tolerates 1e-4.
`live-horde.png` was opened and reviewed: the small orange ground burst is visible
in the actual world, alongside the existing source tracer/diagnostic blast.

Live coverage proves the events encountered in that run (reported in the JSON);
teleport/mender and every renderer edge case are fixture coverage. This is not a
claim of all-map or all-mode acceptance. Final asset-library wiring, packaged
exports and composition-wide graphics acceptance remain lead integration work.
