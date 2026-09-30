# Quiet Relay robot visuals

## Integration

Factory: `preload("res://campaign/robot_visual.gd").new()` for exactly
`scrapper`, `skirmisher`, `sentinel`, `mortar`, `bulwark`, `warden` in `npcModel`.
Keep the source-known `npcType` brain aliases; visual identity never changes AI.
The client-owned `world/presentation.gd` factory seam is not modified here.

Compatibility API:

```gdscript
configure(actor: Dictionary, local_actor_id: int = -1)
apply_actor(actor: Dictionary, local_actor_id: int = -1)
apply_identity(actor: Dictionary)
advance(dt: float)
select_distance(distance: float)
set_lod(level: int)
visible_cost() -> Dictionary
kick(amount: float = 1.0)
reset_pose()
```

`automatic_animation` defaults to true. Set it false when the host calls
`advance`. The host positions/orients the root; the model does not change world
position, root rotation, collision, or actor dictionaries. Host centre is source
feet y + 0.9, local forward is −Z. `FeetOrigin` is always at −0.9. The received
`npcProfile.scale` (default 1, bounded 0.25–3) scales the anatomy **around that
feet origin**, including bosses. Do not also scale the visual root. This avoids
the floating/sunken soles caused by scaling a centre-relative −0.9 offset.
Snapshot `actor.y` itself is **feet**, never centre.

### Authority dimensions and hit boxes

Measured unscaled resting near-LOD art envelopes below include thin
limbs, barrels and antennae (rounded to millimetres). Multiply
dimensions by `npcProfile.scale`. These are art envelopes, not movement blockers.

| ID | Width × height × depth (m, measured) | Initial recommended `hitScale` after spawn |
|---|---|---|
| scrapper | 1.680 × 0.875 × 1.440 | `1.0 * scale` |
| skirmisher | 0.808 × 2.029 × 1.325 | `1.2 * scale` |
| sentinel | 1.672 × 0.875 × 1.980 | `1.0 * scale` |
| mortar | 1.730 × 1.619 × 1.527 | `1.1 * scale` |
| bulwark | 1.232 × 1.640 × 1.325 | `1.6 * scale` |
| warden | 2.060 × 1.533 × 1.780 | `1.4 * scale` |

These recommendations cover central hull targets, not every outlying leg or
antenna. `game/core.mjs:330–331` uses a foot-relative box of
`0.85*hitScale × 1.8*hitScale × 0.85*hitScale`; a scalar cannot simultaneously
match a broad low crawler and avoid empty space above it. Review actual body hit
points in the authority's tests before finalizing these gameplay values.
`npcProfile.scale` does **not** set `hitScale`; `Match.spawn` resets the latter
(`core.mjs:848`). The authority must apply its chosen per-model value **after
every spawn/retry**. This visual module never mutates it. Source movement collider
remains fixed regardless: large art is not a huge physical obstruction. Route
and spawn clearance must accommodate art separately (a scale-1.6 Warden needs
roughly 3.5 m visual width clearance), especially beside walls and doorways.

## Six authored chassis

| ID | Silhouette and articulation |
|---|---|
| scrapper | Low rounded carapace, four splayed double-link legs, forward paired mechanical jaws |
| skirmisher | Narrow upright shell, two long legs, one shoulder pauldron and trailing arm, offset gun and tall antenna |
| sentinel | Three radial outriggers around a low gun pod; independent sensor/gun yaw and recoil |
| mortar | Wide four-foot siege carriage, steeply elevated large open-ended mortar tube and trunnion |
| bulwark | Broad armored biped, full-height left slab shield, separate right gun cradle |
| warden | Six radial links, broad rounded central carapace, raised twin crown pylons and lifting front legs |

Mechanical language is informed by `game/view.mjs:1009` `robotModel`: shaded
metal armor, dark chassis, contrasting link metal, rounded low-poly shells,
joint drums, inset optics, vents, antenna, and offset weapons. These are newly
authored campaign anatomies, not exported/recolored source operators. Armor is
lit PBR (metallic .6, roughness .46), not unlit white. Only the small optic batch
emits. Colored primitives are baked into a single surface per rigid assembly.

## Source-driven presentation

Read-only source audit: `game/core.mjs:1332` spreads actor fields into snapshots;
`game/enemy-types.mjs` defines role profiles; `game/singleplayer.mjs:659–863`
updates the countdown fields below. **No extra `campaignTell` fields are needed
when campaign snapshots preserve these existing fields.** If the authority
later filters snapshots it must retain these role fields and profiles.

| Field | Use |
|---|---|
| `npcModel` | Select chassis; unknown ID internally defaults to scrapper (factory should filter) |
| `id` | Hide local actor when matching explicitly supplied local ID |
| `npcProfile.scale` | Feet-pivot scale, independent of brain alias |
| `vx`, `vz` | Speed-driven alternating gait, including all elapsed dt |
| `yaw`, `bodyYaw`, `pitch` | Turret relative aim and pitch |
| `shots` increasing | Weapon kick then exponential mechanical recovery |
| `melee` increasing | Jaw/weapon kick; source attack timer is not an anticipation predictor |
| `health <= 0` | 0.65 s chassis slump, leg fold, weapon drop, extinguished optics |
| `health > 0` after death | Clear death pose for reset/retry |
| `artilleryWindup`, `npcArtillery.telegraph` | Tube elevation, chassis brace, intensified optic; source default 1.2 s, cooldown 5.5 s |
| `phalanxWindup`, `npcPhalanx.telegraph` | Shield/gun brace; default .55 s, interval 3.4 s |
| `flankWindup`, `npcFlank.telegraph` | Lean/brace before flank burst; default .5 s, cooldown 6 s |
| `bossStompWindup`, `bossPhase` | Front-leg lift, crouch and optic anticipation; Warden phases 1/2/3 use 1.1/.95/.8 s windups |

Windup progress is calculated from the received remaining time, not a local
attack scheduler. Ending/removing a windup makes the cradle settle; cancellation
also settles it. This is not proof a damaging ability executed. No damage,
projectile, impact, shield bubble, target ring, or invented attack timing is
generated. Source `enemy-telegraph` events/marks remain the host's responsibility
for ground targeting. Ordinary guns have no reliable pre-shot windup in these
fields, so they show confirmed shot recoil/recovery rather than fabricated
anticipation. `temporaryShield` does not claim the slab has become invulnerable.

## LOD and budgets

All three bands are explicitly authored because procedural meshes receive no
importer automatic LOD. Near <22 m: articulated hip/knee links, joint drums,
vents, inset trim. Mid 22–48 m: remove fine greebles and knee drums. Far ≥48 m:
six-sided core, simplified armor, merged upper/shin assemblies with hip gait.
Sensor, distinctive weapon, shield, and leg count remain at every distance.
Transitions preserve phase; only the visible rig poses each tick. `advance`
never clamps away elapsed time; recovery uses exponential dt and gait integrates
full dt. A host `set_lod` immediately reapplies current pose.

`visible_cost` returns `draws`, `surfaces`, `meshes`, `triangles`, `lod`; it walks
all registered batches and checks inherited visibility. Triangle counts come
from the actually baked primitive index arrays, including optics, feet, shield,
and guns. One surface per batch, no hidden detail omissions. Draws describe base
geometry submissions, **not** shadow/depth render passes. At most 16 visible
surfaces per near/mid Warden and 10 far, hence a 12-Warden worst-case ceiling of
192 near or 120 far base submissions. Ordinary two-legged units are cheaper.
Geometry is resident for all three bands; material resources are per-instance so
optic changes do not affect other enemies. CPU geometry is built once per ID
change, not on snapshots or LOD switches.

## Verification handoff

Verified in the parent's exclusive serialized engine slot using pinned Godot
4.5.2 and `LP_NUM_THREADS=1`. Focused headless: **264 checks passed**. No editor
import was necessary for these procedural resources. Xvfb OpenGL compatibility
captures exited 0 and were visually inspected (Mesa llvmpipe, not a hardware
performance measurement). Commands for reproduction:

```sh
LP_NUM_THREADS=1 godot --headless --path godot --script res://tests/campaign/robots.gd
LP_NUM_THREADS=1 xvfb-run -a godot --path godot --audio-driver Dummy --rendering-method gl_compatibility --script res://tests/campaign/robot_gallery.gd -- --capture=/tmp/opencode/campaign-robots.png
```

Headless tests reproduce the integrated `actor.y+0.9` host transform at terrain
y −4.25, 7.5, and 31 with scales 1, 1.6, and 2.2 across all six models and all LODs,
asserting actual rendered mesh sole bounds, not just a marker. They independently
recount rendered mesh arrays, check strict
triangle reduction at each band, anatomical leg counts, source-scale pivot,
dt partition invariance (the previous time-discarding gait regression), actual
joint motion, shot recovery, source windup, death/reset, and hidden zero cost.
The gallery is a lit 1600×1000 six-pedestal model inspection with labels and a
synthetic move / windup / recoil / death / reset sequence. Omit `--capture` for
continuous inspection. Its states are synthetic, not live campaign evidence.
`--pose=1` captures representative role windups, `--pose=3` captures death, and
`--lod=2` inspects authored far geometry. Captures step at deterministic 1/60 s.

Evidence directory:
`/home/mojo/.tmp-on-disk/cocs-campaign-evidence-20260930/robots/` contains
`headless.log`, `gallery.png`, `windup.png`, `death.png`, `far-lod.png`, rendering
logs, and `initial-test-failure.md`. Initial test-fixture mistakes (float equality,
testing rest bounds with moving gait, null index arrays) were corrected before
the passing suite. The first graphical attempt used fallback dummy audio;
subsequent commands selected Dummy explicitly. The display's unsupported VSync
warning is retained in logs. No engine crash occurred.

Measured near / mid / far base draws and triangles:

| ID | Near | Mid | Far |
|---|---|---|---|
| scrapper | 12 / 760 | 12 / 556 | 8 / 288 |
| skirmisher | 8 / 648 | 8 / 516 | 6 / 344 |
| sentinel | 10 / 576 | 10 / 408 | 7 / 228 |
| mortar | 12 / 744 | 12 / 540 | 8 / 312 |
| bulwark | 9 / 492 | 9 / 360 | 7 / 204 |
| warden | 16 / 1048 | 16 / 772 | 10 / 408 |

Research carried through: Valve silhouette/read hierarchy
<https://cdn.cloudflare.steamstatic.com/apps/valve/2008/GameFest08_ArtInSource.pdf>,
attack anticipation/action/recovery
<https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/>, and Godot
import-only automatic mesh LOD constraints. Render review and hardware frame
timing remain parent-owned evidence; budgets are structural bounds, not measured
GPU performance.

## Targeted ground telegraphs (follow-up)

`res://campaign/telegraphs.gd` is a standalone `Node3D` for source artillery and
boss-slam target warnings. Parent/client owns wiring; this follow-up does not
modify the demo, client, presentation, or robot visual scripts.

```gdscript
const Telegraphs = preload("res://campaign/telegraphs.gd")
var ground_tells = Telegraphs.new()
add_child(ground_tells) # world-space identity transform
ground_tells.bind_terrain(terrain) # height_at(world_x, world_z)
ground_tells.apply_state(snapshot_state) # {time, actors}; not the outer wire frame
ground_tells.apply_events(source_events)
ground_tells.clear_round() # every start/retry/map transition/leave
```

API: `bind_terrain(terrain: Node3D)`, `apply_events(items: Array)`,
`apply_state(state: Dictionary)`, `clear_round()`. Component and terrain must be
in the same world-coordinate convention. All warning vertices sample
`terrain.height_at` independently with a 0.055 m surface offset, including both
edges of the 72-segment circumference and the inward hazard pointers. Outer
radius and x/z come from source events; geometry never predicts target motion.

Recognized source events (`core.mjs:760` supplies numeric `id` and `time`):

- `enemy-telegraph` with `kind: "artillery" | "boss"`: consumes `actor`, `x`,
  `z`, `radius`, `duration`, `time`, `id`. Boss radius comes from the event rather
  than guessing a phase profile; `phase` need not be present in the snapshot.
- `enemy-artillery` / `boss-slam`: brief 0.22 **authority-second** pale boundary
  flash at the confirmed event location/radius. A flash reports execution, not
  player damage; `hit: false` can still be a real impact.

The component has no `_process`, wall-clock countdown, or attack/damage emitter.
Only `snapshot.time` advances progress, value pulses, expiry, and impact flashes.
Event-before-state and state-before-event are supported. Future events wait for
their corresponding snapshot; old snapshots do not rewind cues. Source actors
must be present/alive. Warning rings reconcile against `artilleryWindup` +
`artilleryMark`, or `bossStompWindup` + `bossStompMark`: missing/nonpositive
windup, missing actor, death, mismatched mark, or event deadline cancels the
warning. A changed mark waits for its new event rather than reusing an old
radius. Late/expired events cannot revive a warning. Clearing a round releases
meshes, actors, clock, and event-ID deduplication for fresh event serials.

Amber/orange cues also use alternating brightness dashes, a growing pale arc,
authority-time pulse, and **four artillery vs eight boss inward pointers**;
meaning is not conveyed by color alone. Bounded at 24 keyed actor/kind rings,
one mesh/surface each, and 256 remembered event IDs. Unsupported kinds, malformed
fields, unknown/dead sources, radius >64 m, or duration >30 s produce no cue.
An unknown future source can occupy pending bounded state but renders nothing
until an authoritative living actor arrives. Valid shipped timings/radii are
well inside these bounds. No sounds or fabricated explosions are added.

Follow-up tests are authored but **not engine-run yet**: worlds owns the heavy
slot. Parent should run serially once a slot is available:

```sh
LP_NUM_THREADS=1 godot --headless --path godot --script res://tests/campaign/telegraphs.gd
```

Tests cover sloped nonzero-height sampled mesh vertices, exact outer radius,
event/state ordering, duplicate IDs, wall-clock invariance, authority progress,
stale snapshots, cancelled/changed/dead/missing sources, source-only impact
flash/expiry, boss radius without profile guessing, bounded flood state, reset
and reused event IDs, and malformed/unknown events. Existing robot/gallery
verification above predates this separate follow-up and is not evidence for it.
