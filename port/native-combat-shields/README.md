# Native combat shields — integration handoff

**Implementation:** `res://combat_shields/controller.gd`, passive `Node3D`.
Owned changes are confined to `godot/combat_shields/`,
`godot/tests/combat_shields/`, and `port/native-combat-shields/`.
The source simulation, network adapters, maps, and existing presentations are
read-only in this contribution. Lead session owns attaching the controller.

**SHIELD-CAP-ORDER P2 fixed:** actor observation is now independent of render-slot
ownership. The sole protected actor renders after either a 16-actor Low or
32-actor High unprotected prefix, in either array order, with just one material.
See [capacity fix, independent re-checks and new evidence](CAPACITY-FIX.md).

## Exact hooks

```gdscript
const CombatShields = preload("res://combat_shields/controller.gd")
var combat_shields = CombatShields.new()

# Once the world and first-person camera exist:
world.add_child(combat_shields) # identity-transform world-space parent
combat_shields.configure(camera)
combat_shields.set_quality("high") # default; also accepts "low", 1, 0
combat_shields.bind_actor_visuals(presentation.actors) # optional, recommended

# Immediately after presentation.apply_state(frame.state, local_actor_id):
combat_shields.apply_state(frame.state, local_actor_id)

# On the client's actual `events(items)` signal:
combat_shields.apply_events(items, local_actor_id)

# Start/new round, disconnect, connection_error, explicit session reset:
combat_shields.reset()

# Results: accept the final state, which clears and latches results:
combat_shields.apply_state(frame.state, local_actor_id)
# If a results signal does not carry `state.over`, call reset() instead.

# Optional explicit pause/control-reset integration:
combat_shields.set_suspended(true)
combat_shields.set_suspended(false) # fresh state is required before showing FX
```

`_process` advances the visual clock. Automatic application focus-out clears
visuals and pauses the clock; focus-in waits for fresh state. Snapshot staleness
over one second hides all tracks and transients. `reset()` immediately frees
meshes/material instances, releases factory registrations, clears event IDs, and
permits a new round. It preserves quality, camera and optional anchor binding.
`set_suspended(false)` is available if the lead explicitly suspends on a control
boundary that is independent of OS focus. `reset()` does not override suspension.

`apply_state` takes **the state dictionary**, not the snapshot envelope. It uses
the source's numeric actor IDs, including actor zero; spectators may pass `-1`.
Events may arrive before the first snapshot: 64 pending events can wait up to
0.75 seconds for their actual actor. Hook both signals; do not synthesize events
from HUD damage or clicks. `bind_actor_visuals()` keeps a read-only reference to
the presentation's numeric-ID dictionary so interpolated remote bodies and
shells share their rendered center. Unbound controllers use source positions.
Presentation anchor convention is actor feet plus 0.9m, as in the existing
presentations. Replace the binding if the lead replaces the entire dictionary.

A caller can inject a dedicated `shader_lab/factory.gd`-compatible instance into
`combat_shields.factory` **before configuration or any state/events**. The
controller clocks/releases only its own registrations, even in a shared factory;
the existing factory has a global 64-material cap. The default factory is private.

## Authoritative meanings

The same actor schema comes from `Match.snapshot()` (`game/core.mjs:1313`). The
ordinary Room quantizes these fields; Horde sends the source snapshot directly.
No effect modifies them.

| Public fields / events | Visual meaning and guard |
|---|---|
| `id`, `x/y/z`, `baseHeight`, `yaw`, `health`, `dead` | Finite source-space actor envelope; health > 0 and dead <= 0 required. Numeric safe integer IDs, not truthiness. Missing/invalid coordinates are rejected. Source yaw governs the directional shield. |
| `protection > 0` | Cyan interference shell: actual spawn immunity. `Match.damage` early-returns while this timer is positive; firing/powers can clear it. |
| `temporaryShield > 0` | Cyan shell: real absorb pool, including overshield and COCS/Horde support grants. Pool, not the pickup timer, controls visibility. |
| `juggernautShield > 0` | Amber shell: real separate absorb pool. `juggernaut` boolean alone does not enable it. |
| `verbState.verb == "alignment-review"`, `active == true`, `pool > 0`, `poolIn > 0` | Cyan shell: actual class absorb pool after temporary/Juggernaut pools and before armor. |
| `npcShield.reduction`, `.arc`, actor `yaw` | Frontal cone only: Horde bulwark damage reduction, **not immunity or a breakable full bubble**. Source defaults reduction 0.7, arc 0.6 radians, front -Z. Temporary shield pools take precedence if also present. |
| `armor > 0` | Much subtler amber **armor-energy** visual. Armor is not immunity: source armor absorbs up to 60% of remaining incoming damage. `debug_state().kinds` names it accurately. |
| `damage`: `actor`, numeric `source`, `amount > 0`, `shield`, `shieldBreak` | Directional angular ripple from the last observed attacker position, rotated into actor space. This is an attacker-direction approximation, not a source impact point. Missing/self/coincident attacker uses a neutral pulse. `shield` reports **temporary** absorption only; it excludes armor/Juggernaut/review. |
| `damage.shieldBreak == true` | One brief expanding fragmented shell. Source defines this as temporary + Juggernaut + armor going from positive to zero while the actor survives. It does not identify which component broke. |
| Positive-to-zero `armor` with a recent genuine damage event | Armor-only break cue even if another source pool remains; event/snapshot ordering coalesces the same break for 0.35 seconds. A state change with no observed damage does not invent a shatter. |
| Health increase between alive snapshots; `pickup.kind` health/megahealth | Bounded green rising recovery halo. Pickup and corresponding health delta coalesce; this is recovery/overhealth presentation, never a new shield. Unknown cause of a health delta is not labeled as a specific healer. |
| `mender-heal` with `healed > 0` | Halo on the **mender actor**. `healed` is a count, not target IDs; the controller does not fabricate recipient identities or buff neighbors. |
| `spawn` event; observed dead-to-alive | Height/noise phase cut across a transparent visual envelope. Source actor geometry stays intact. Event plus observed respawn coalesces. Initial roster appearance alone is not treated as a spawn event. |
| `grounded: true -> false`, `vy > 1` | One brief low jump-phase echo, from an observed rising transition. Repeated airborne snapshots do not retrigger. |
| `teleport`, `dash` with finite `from` and `to`, actual nonzero displacement | Source endpoint phase echoes; dash has 4 high / 2 low trailing echoes. Large position deltas alone never imply a teleport/dash. |
| `vehicleId != null` | Actor shell/transients hidden while seated; vehicle hull FX belong to vehicle presentation. |

Important source distinctions (`game/core.mjs:836–866`, `979–989`, `1157–1188`):
`active` means harness-active, not generic invulnerability. `powerups.overshield`
may remain positive after the pool is exhausted. `cocsArrival` is partial damage
reduction, and depot immunity is evaluated contextually by source; this actor
controller does not invent a boolean immunity flag for either. There is no generic
public `invulnerable` actor flag used by this implementation.

Horde's `phalanx-shield` affects actual allied `temporaryShield`; snapshots show
those shells. The event's `shielded` count is not a list of actor IDs. Mender and
phalanx semantics were checked in `game/singleplayer.mjs:675–689,734–748` and
the NPC shield schema in `game/enemy-types.mjs:80,171–181`.

### Event identity

Only safe numeric wire `event.id` deduplicates. Ordinary events use the Room's
delivered serials; the Horde adapter uses a per-round ordinal and preserves the
source payload's overwritten ID in `sourceId`
(`port/native-horde/authority.mjs:20–29`). Repeated `sourceId: "same-pad"` events
with distinct numeric wire IDs remain distinct. The 2,048-ID sliding window
permits out-of-order arrivals inside the window; older replays cannot re-enter.
The controller consumes only events actually delivered by the adapter. It does
not repair source/Room event loss or reinterpret string IDs as numeric serials.

## Maps/modes

Mode-independent public fields above apply across all nine shipped maps. The
source fixture constructs these real combinations and checks their actor shape:

| Map | Exercised source constructor mode |
|---|---|
| meridian-exchange | deathmatch; also actual Horde bulwark fixture |
| verdant-reliquary | deathmatch |
| ember-crucible | deathmatch |
| tidal-citadel | ctf |
| sunscar-convoy | payload |
| asterion-relay | cocs |
| monsoon-foundry | cocs |
| ion-speedway | puma-race |
| aurora-stadium | puma-soccer |

These are schema/source-construction checks, not nine-map rendered acceptance.
Sports vehicle occupants are intentionally gated by actual `vehicleId`.
The additional meridian Horde fixture uses source `applyEnemyFields("bulwark")`,
`spawn`, `snapshot`, and the production EventCursor. Mode permissions and the
supported-map list remain the existing lead-owned transport responsibility.

## Rendering / bounded lifetime

The shader reuses the showcase's actual `moth_common.gdshaderinc`, factory-loaded
Moth normal/flow/motif/LUT resources, interference pattern, and height/noise phase
front. The controller uses transparent **outer visual geometry**, not the
showcase static prop's opaque dissolve material on gameplay bodies.

- Compatibility renderer; opaque depth tested, transparent depth never written,
  outward back-face culling, no shadow casting, no screen/depth texture reads.
- Original Moth alpha is opaque. Coverage is generated analytically and clamped
  to 0.62; body-center coverage is small, strongest details are at shell edges.
- Local actor produces no shell or transient, so there is no opaque first-person
  overlay. Any remote shell within sqrt(5)m of the camera is also hidden.
- High: 32 actor slots + 16 pooled transient slots, max 48 independent materials.
  Low: 16 + 8, max 24; fewer sphere triangles, fewer dash echoes, skips expensive
  triplanar Moth field/normal/LUT/motif work in the fragment shader.
- Up to 256 CPU-only actor observations are retained independently of both
  quality budgets. `tracks[id].slot` can be empty; `debug_state().actors` counts
  observations, while `slots` counts allocated shell nodes. Only eligible
  remote actors claim shell slots. Allocation ranks real protection ahead of
  ordinary armor, then in-frustum centers, camera distance, and numeric ID.
  Local, dead, seated, hidden-bound-visual, camera-adjacent and behind-camera
  actors reserve no shell slots. Source arrays are never sorted in place.
- Slots can be recycled without resetting history. Quality downsizing only
  evicts render ownership; armor breaks, health recovery and dead-to-alive
  transitions remain observed for actors outside the material budget.
- Geometry is shared. Independent materials avoid one actor's hit affecting all
  actors. Pool exhaustion drops visual bursts; it never allocates above budget.
- Death, despawn, stale state, focus, results and reset remove/hide effects.
  Shrinking quality immediately frees excess slots and factory registrations.

## Verification and evidence

Pinned binary:
`/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`

```sh
node port/native-combat-shields/run-checks.mjs
```

The runner executes source fixture generation, headless native assertions, a
fresh loopback source/native oracle, and both Compatibility render sizes. It
retains timestamped logs, including failed attempts, and rejects script errors,
resource leaks and nonzero exits.

**Latest native checks: 83 assertions passed.** Includes ordinary pool semantics,
source Horde front cone, actual source Cline dash, 16 actor pressure, per-actor
materials, reset release, quality downsizing, malformed finite/ID guards,
duplicate/reset/Horde equal-source-ID handling, 2,048-ID and 64-pending bounds,
pending expiry, event-before-state spawn, grounded transition, death/respawn,
results/focus/stale lifecycle, local camera exclusion, and read-only interpolated
anchor binding/fallback.

**Fresh source/native oracle:** six SHA-256-correlated snapshots. The source
actually consumes 35 temporary shield, later depletes 24 armor, emits the real
damage/shieldBreak events, heals, and respawns. Duplicate damage delivery produces
one ripple per actual event and one shatter across event/snapshot delivery. Final
factory registration count is zero. This is a private explicitly configured
Match with scripted source damage calls, **not natural input-only multiplayer
play**. The evidence JSON preserves setup provenance and the full outgoing wire.

### Render results

| Size | Occluder changed pixels | Local center changed pixels | Actor center mean RGB delta | 16-shell high median / p95 | Low median / p95 |
|---|---:|---:|---:|---:|---:|
| 960×640 | 0 | 0 | 0.0205 | 12.85 / 15.13 ms | 9.32 / 11.52 ms |
| 1280×720 | 0 | 0 | 0.0213 | 14.51 / 18.73 ms | 10.13 / 12.58 ms |

Adapter was **Mesa llvmpipe LLVM 20.1.8**, Compatibility OpenGL 4.5. These are
45-frame software wall-clock proxies with 16 candidate actor models plus scene,
not hardware GPU timings or acceptance for the user's fast GPU. Pressure rigs
are explicitly replicated visual fixtures. A V-Sync unsupported-driver warning
is retained in logs; no shader/script/resource failures occurred.

- [960 before](evidence/960x640/before.png) / [after](evidence/960x640/after.png)
- [1280 before](evidence/1280x720/before.png) / [after](evidence/1280x720/after.png)
- [Directional hit](evidence/1280x720/directional-hit.png)
- [Armor break](evidence/1280x720/armor-break.png) / [depleted](evidence/1280x720/depleted.png)
- [Recovery](evidence/1280x720/recovery.png)
- [Actual source spawn phase](evidence/1280x720/source-spawn-phase.png)
- [Local camera clear](evidence/1280x720/local-camera-clear.png)
- [16-shell high](evidence/1280x720/pressure-high.png) / [low](evidence/1280x720/pressure-low.png)
- [960 measurements](evidence/960x640/measurements.json) / [1280 measurements](evidence/1280x720/measurements.json)

The final anchor-binding addition was checked with the 83-assertion headless run;
the preceding full runner logs contain 80 assertions and the rendered evidence.
It adds optional read-only pose alignment; the unbound render path is unchanged.
