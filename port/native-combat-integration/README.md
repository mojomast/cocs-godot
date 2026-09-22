# Shared native combat integration

`godot/world/combat_feedback.gd` composes the delivered weapon, world-particle,
and shield controllers in the ordinary shared session and Combined Arms graphics
adapter. It inherits the lead's shield attachment, F9/F10 canvas, and ADS reticle
fade. Horde, zones, Arms Race, and LATTICE modes use that shared session path;
the three native Deathmatch maps also inherit it. No additional host hook is
required.

## Ownership and ordering

- The real first-person rig is discovered from `session.first_person.rig` or
  `graphics.rig`. `external_muzzle_fx` suppresses the old rig flash.
- Public events are deduplicated at the composition boundary and queued until
  process priority 40. Network and rig listeners/animation run at priority 0;
  weapon effects run at 50. Before consumption, `rig.advance(0)` refreshes the
  current recoil/camera transforms without another time step or recoil event.
  This also handles Combined Arms, whose rig precedes its network node.
- Production sessions use the new controllers instead of the legacy yellow
  lines, orange spheres, and overlapping Moth world cues. Detached diagnostic
  consumers retain the small original fallback used by existing protocol tests.
  Shot/launch/explosion counters, authoritative positive-damage hit/hurt feedback,
  and existing procedural audio remain available.
- Focus loss, stale snapshots, SceneTree pause, inactive phases, results,
  identity changes, map replacement, and round cleanup drain transient FX.
  Resumption requires a fresh public frame. The boundary remembers hidden event
  IDs across temporary suspension and identity changes; an actual round reset
  permits IDs to restart. Existing source transport deduplication remains active.

## Geometry and projectile origin contract

`godot/world/combat_occlusion.gd` supplies the fail-closed visibility callback.
Original arenas use their checksum-validated semantic ground-to-height blocks
and a Godot `TriangleMesh` BVH made from locked support triangles. The sports
arenas use the source's unbounded zero-height floor. Their movement bounds are
not raycast bounds. No decorative rendered meshes are treated as authority.

Native map discovery selects the exact authored map script subtree. Particle
occupancy receives that explicit **built collision root**. Visibility queries
use native physics and accept only `StaticBody3D` RIDs from that subtree, excluding
unrelated actors/decoration. Camera-to-animated-muzzle and muzzle convergence
queries fail closed. The composition also checks the entire authoritative shot
segment, including remote shots. A 4 mm open-end tolerance accepts a source
endpoint exactly on a wall; the endpoint itself is never changed.

`godot/world/projectiles.gd` caches visual launch origins for at most 120 ms and
128 launches. It associates IDs using the actual `game/core.mjs` contract:

1. Alt fire explicitly publishes `event.projectile`.
2. Primary rocket/plasma/grenade creation increments `serial` immediately before
   emitting `launch`; its projectile ID is `sourceId - 1`, or `id - 1` on the
   unchanged source transport. Horde/native cursors preserve `sourceId` while
   assigning independent public event ordinals.
3. A matched snapshot must also have the same owner and weapon. Missing alt IDs,
   stale launches, unsafe segments, large discontinuities, and mismatches cannot
   produce a muzzle offset. No proximity/volley/pellet matching is used.

Only mesh position converges to the exact current authoritative projectile
sample. Source snapshots, launch positions, endpoints, collision, and damage are
never modified. Missing IDs, expiry, suspension, and resets clear associations.

## Quality and real metrics

F9 cycles **Low → High → Extreme** (default High); F10 toggles telemetry.

| Level | Original maps | Native maps |
|---|---:|---:|
| Low | 8,192 | 8,192 |
| High | 32,768 | 131,072 |
| Extreme | 1,000,000 total | 1,000,000 total |

The 32 particle emitter nodes and materials retain identity while their buffers
resize. Low retains primary weapon cues and reduces secondary effects and shield
quality. Metrics report actual allocated particle amounts, submitted capacity,
emitter/pool node counts, actual extant weapon nodes, shield **materials**, and
collision shape counts. Submitted capacity is explicitly not live GPU readback;
buffer bytes are the particle manager's labeled estimate. Shield `actors` counts
observations, not allocated shells (including the `d27f594` capacity fix).

## Verification

Pinned executable:

```sh
GODOT=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
node port/native-combat-integration/export-fixtures.mjs
"$GODOT" --headless --path godot --script res://tests/combat_integration/contracts.gd
"$GODOT" --headless --path godot --script res://tests/combat_integration/combined_adapter.gd
python3 port/native-combat-integration/review.py --output /tmp/opencode/combat-integration-review
```

The deterministic source fixture executes real `Match.fire`, `Match.snapshot`,
`rayWorld`, and the native public event cursor with explicitly arranged test
actors. It is labeled separately from live gameplay. Contracts cover all ten
real imported weapons, recoil/ADS animated origin alignment, exact endpoints,
720 source ray comparisons over all nine original maps, source near-wall damage
rejection, native physics and all three actual authored native roots, all three
controllers, ID association, quality/resource identity, deduplication, lifecycle,
and immutable public frames. The separate test uses the actual Combined Arms
graphics adapter and its late-network-listener order, including mounted fire.

### Actual rendered production evidence

[`evidence/live-first/summary.json`](evidence/live-first/summary.json) passed every
check. It uses the shipped `world/session.tscn`, an unmodified source authority,
a private Xvfb, normal-rate execution, and actual XTest mouse/keyboard inputs.
The observer only records state. Screenshots were reviewed at both sizes:

- [800×600 ADS/source fire](evidence/live-first/ads-fire-800x600.png)
- [1280×800 ADS/source fire](evidence/live-first/ads-fire-1280x800.png)
- [High F10 metrics](evidence/live-first/high-metrics.png)
- [Low F10 metrics](evidence/live-first/low-metrics.png)
- [Brief shared-session Extreme allocation](evidence/live-first/extreme-confirmed.json)

The ~15.8-second recording contains 393 snapshots, 65 source shot events,
3 explosions, and 5 damage events. It observed up to 3 simultaneous particle
burst emitters and 2 visible shield shells. Both sizes produced real weapon
flashes/tracers with zero legacy FX. OS F9 switched High/Extreme/Low/High while
the pool stayed at 32 nodes. Extreme was confirmed briefly once; this is not a
hardware performance claim. Focus loss drained emitters and required fresh ADS
input. Client, authority, and private display exited cleanly.

`evidence/contracts-final.log` (**1,013 checks**) and
`evidence/combined-final.log` (**12 checks**) contain the headless results; the
maximum animated-muzzle projection error was **0.0000267 pixels**. The original
combat-feedback, projectile, and audio protocol
tests pass, and `evidence/editor-import.log` records a clean pinned editor import.
Earlier failure logs are retained: an initial incorrect Godot TriangleMesh
method name, the sports-floor boundary mismatch, a test type annotation, and a
test timer using simulated rather than monotonic elapsed time were corrected.

## Lead handoff

No blocking session/graphics hook remains. Commit/package inclusion must include
the new occlusion/quality scripts and their UIDs alongside the already delivered
FX controllers. Native arena launcher/package/three-map gameplay acceptance is
owned by the lead's parallel lanes. This lane's actual-native-root checks read
those delivered builders without editing them.
