# Content/core contract proposal v1

Status: concrete authored proposal; parent/core must reconcile optional mechanics
before native acceptance. Required fields and API are exactly DESIGN.md.

Frames are zero-based: startup S occupies 0..S-1; active occupies S..S+A-1;
recovery ends at S+A+R-1. Hitboxes are facing-local lower-left rectangles in mm.
Standing reference height is 1800 mm. Animation equals the common move key inside
each operator's unique GLB; effect is `operator:move`. No qualified animation names.

## Strict machine shape (audit C2/C3/F9 correction)

`godot/fighting/data/schema.json` exports the complete accepted authored shape as
JSON Schema (draft 2020-12), generated from `tools/fighting/content/schema.mjs`.
Every actual optional dictionary field is typed/bounded; unknown keys and unknown
mechanic enums are errors. Missing required dictionary members are errors. All
numeric authoring values must be finite safe integers, with no bool/string coercion.
The existing literal mechanics below are retained; Astra owns their runtime handlers.
Cross-field frame chronology, resource references/clamps, paired placement and
motion-specific members are additionally checked by `validate.mjs`.

Initial HP/walk/weight intent lives in `tools/fighting/content/balance_targets.json`;
`roster.json` is authoritative runtime data. The validator never parses DESIGN prose.
`tools/fighting/content/state_keys.json` pins the actual **22** universal clip keys
listed in DESIGN, independently of the prose's approximate clip-count target.
Neither state nor combat coverage permits shared/recolored operator libraries.

Optional typed dictionaries (all integer values unless stated):

- `projectile`: `spawn_frame`, `x`, `y`, `vx`, `vy`, `gravity`, `w`, `h`,
  `life`, `range`, `max_count`, `clash_strength`, `pierce` (bool). Spawn exactly
  once; moving contacts use swept AABBs; hit ledger disallows repeated contact.
  Range is accumulated absolute travel, not distance from a moving owner.
- `movement`: `type` enum reel/rush/glide/super_jump/slam/double_jump/hover/air_dash/
  blink/anchor; `from`, `to`, `vx`, `vy`, `distance`, `duration`, `air_only`,
  `ground_only` (bool), `cooldown`, `invulnerable_from`, `invulnerable_to`.
  Distance caps total displacement. Blink teleports once on `from`, respects stage
  and pushboxes, and has no strike invulnerability. Rush applies velocity to the
  attacker; reel's `on:hit` applies `pull_speed` to the target, not the attacker.
  Air dash/double jump specify `air_uses:1,reset_on_land:true`; this separate
  serialized counter prevents Gemini's band resource granting endless jumps.
  Anchor additionally has
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
DeepSeek S1 requires 36 back-held ticks even on simple controls; completed charge
is retained for six ticks after release (the ordinary input buffer). Grok S2 requires
18 down-held ticks. Chords must be resolved before individual buttons.

Combo inputs are sparse `{tick,axis_x,axis_y,held,pressed}` changes with absolute
ticks; omitted ticks release all buttons/axes unless an explicit `duration` holds
the sample. `setup_inputs` prepends real charge input samples; training fixtures
place both actors at specified height/separation before playback. For charged
traces, initial distance refers to the first attack tick, after setup walking.
Facing-relative axis_x is converted using initial facing by harness.
Canonical `axis_y` is down=-1, up=+1; canonical `axis_x` is world left=-1,
right=+1. Core derives button press edges from each actor's saved held history.
Caller `pressed` is a nonauthoritative hint and cannot initiate an attack without
a held rising edge. `trace.mjs` expands sparse samples into canonical inputs and
checks that author hints match the expected held edges. A duration holds buttons
through its window; it emits one rising-edge hint on the first tick, then zero.
Without duration, a sample occupies one tick and the next unspecified tick releases
it naturally. The helper is input expansion only, not recognition/combat authority.
Trace tick scheduling uses startup/active plus authored hitstop estimates, not a
second simulation. Preconditions specify positions/airborne/charge/resource.
Only the native core can certify contacts, hitstop, stun continuity and scaling.

Operator `resource` additionally declares `regen_ground_per_tick` (DeepSeek fuel
one per grounded tick), `regen_interval` (Qwen gains one tool each 120 grounded
ticks; zero disables), `reset_on_round`. Landing refills resources only where a
move explicitly declares `reset_on_land`; all additions/spending clamp min/max.
Rules include literal combo limits, scaling curve, fixed hurt/push rectangles,
gravity, terminal speed, startup/landing/round timers and independent guard policy.
The source validator establishes numeric bounds, not runtime clamp behavior.

FREEZE enforces runtime JSON, machine schemas/oracles, generator and validation
inputs. DESIGN, this document and generated move-list prose are excluded. Historical
DESIGN hashes are informational provenance only and never gate working prose edits.
