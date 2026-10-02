# Content/core contract proposal v1

Status: concrete authored proposal; parent/core must reconcile optional mechanics
before native acceptance. Required fields and API are exactly DESIGN.md.

Frames are zero-based: startup S occupies 0..S-1; active occupies S..S+A-1;
recovery ends at S+A+R-1. Hitboxes are facing-local lower-left rectangles in mm.
Standing reference height is 1800 mm. Animation equals the common move key inside
each operator's unique GLB; effect is `operator:move`. No qualified animation names.

Optional typed dictionaries (all integer values unless stated):

- `projectile`: `spawn_frame`, `x`, `y`, `vx`, `vy`, `gravity`, `w`, `h`,
  `life`, `range`, `max_count`, `clash_strength`, `pierce` (bool). Spawn exactly
  once; moving contacts use swept AABBs; hit ledger disallows repeated contact.
  Range is accumulated absolute travel, not distance from a moving owner.
- `movement`: `type` enum reel/glide/super_jump/slam/double_jump/hover/air_dash/
  blink/anchor; `from`, `to`, `vx`, `vy`, `distance`, `duration`, `air_only`,
  `ground_only` (bool), `cooldown`, `invulnerable_from`, `invulnerable_to`.
  Distance caps total displacement. Blink teleports once on `from`, respects stage
  and pushboxes, and has no strike invulnerability. Anchor additionally has
  `anchor_life`, `trigger_range`, `pull_speed`, `max_count`; one trap, one trigger,
  lifetime expires even if never touched. Reel is a strike pull only on contact.
- `throw`: `range`, `tech_frames`, `damage_frame`, `release_frame`, `victim_x`,
  `victim_y`, `side_swap` (bool), `command` (bool), `ground_only` (bool),
  `knockdown_frames`. Timeline frames are move-local; normal throws give ten tech
  frames before damage; command throws cannot catch hitstun/wakeup-invulnerable
  targets. Victim clip is `victim_<operator>_<move>` in every victim GLB.
- `resource_effect`: `resource` (String), `cost`, `gain`, `on` enum start/hit,
  `reset_on_land` (bool). Clamp every change to operator resource min/max; reject
  insufficient cost, consume once, gains never recursively trigger another move.
- `armor`: `from`, `to`, `hits`, `damage_percent`; never protects from throws.
- `stance`: `resource`, `set`, `duration`, `variants` (base move → listed move key).
  Gemini starts claw(0); special2 sets palm(1) for 180 ticks; timeout resets claw.
- `counter`: `from`, `to`, `reflect` (bool), `strike` (bool), `range`,
  `damage_frame`, `release_frame`. Claude special3 reflects projectiles during
  its window; a close grounded strike triggers its authored counter-grab timeline.
- Optional scalar `pushback`, `launch_velocity`, `juggle_cost`, `knockdown_frames`,
  `chip`, `meter_gain`, `air_ok` and `ground_ok` have literal meanings; meter gain
  occurs once on hit only. `input` is descriptive recognizer metadata:
  `simple` enum L/M/H/GRAB/BACK_GRAB/SPECIAL/MOBILITY/SPECIAL_GRAB/SUPER,
  `motion` String and optional `charge_frames`, `charge_axis` back/down.

Simple S1=Special, S2=Mobility, S3=Special+Grab simultaneous chord (one edge),
super=Super. Down chooses crouch normals, airborne chooses air normals. Back+Grab
selects throw_b; otherwise throw_f. Independent Guard holds high, Down+Guard low;
back alone walks backward. SOCD both axes neutral; negative edge disabled.
DeepSeek S1 requires 36 back-held ticks even on simple controls; Grok S2 requires
18 down-held ticks. Chords must be resolved before individual buttons.

Combo inputs are sparse `{tick,axis_x,axis_y,held,pressed}` changes with absolute
ticks; omitted ticks release all buttons/axes unless an explicit `duration` holds
the sample. Facing-relative axis_x is converted using initial facing by harness.
Trace tick scheduling uses startup/active plus authored hitstop estimates, not a
second simulation. Preconditions specify positions/airborne/charge/resource.
Only the native core can certify contacts, hitstop, stun continuity and scaling.
