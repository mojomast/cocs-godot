# Core data contract v1

DESIGN.md required fields and APIs apply. Frame 1 is the first startup frame;
first active frame is `startup + 1`. All distances/velocities are integer mm/tick.
Optional dictionaries accept only the following keys (unknown mechanics reject):

- `projectile`: `speed` (180), `vy` (0), `gravity` (0), `life` (90),
  `range` (10000), `width` (400), `height` (400), `spawn_x` (600),
  `spawn_y` (900), `max_count` (2), `clash` (1), `reflectable` (true),
  `max_reflections` (2).
- `movement`: `type` = `dash|grapple|glide|super_jump|brace_slam|double_jump|hover|air_dash|blink|tether`,
  `speed` (140), `distance` (2200), `duration` (18), `range` (3600),
  `jump_velocity` (260), `cooldown` (60), `fuel_cost` (1).
  Applied at first active frame. Grapple pulls only on unblocked hit, bounded by
  distance; tether places a finite anchor and slows/pulls only a grounded nearby enemy.
  Blink is committed startup then bounded relocation, with no startup invulnerability.
- `throw`: `range` (900), `techable` (true for throw_f/b, false otherwise),
  `damage_frame` (14), `duration` (30), `victim_x` (600), `victim_y` (0),
  `side_swap` (true for throw_b), `knockdown` (35). These frames are pair-local,
  with pair frame 0 the catch. Normal throw damage cannot precede tech frame 11.
- `resource_effect`: `resource` (heat|ward|brace|charge|fuel|stance|anchor|blink|adaptive|tempo|context|tool),
  `cost` (0), `gain` (0), `on_hit` (0), `on_block` (0).
- `armor`: `from`, `until`, `hits` (1), `damage_percent` (50), `reflect` (false).
  Counter-kind moves counter strikes in their active interval; reflect also operates
  in the declared armor interval. Throws bypass armor/counter.
- `stance`: `set` (0 or 1), `duration` (180), `requires` (0 or 1),
  `variants` (dictionary mapping base move IDs to explicitly authored move IDs).

Optional move scalar fields: `chip`, `pushback`, `launch`, `knockdown`,
`juggle_cost`, `wall_bounce`, `ground_bounce`, `otg`, `cooldown`, `charge_frames`.
`launch` is integer upward velocity; bounce/otg are booleans, limited per combo.
Operator `resource` may contain `name`, `id`, `max`, `initial`, `regen`,
`decay`, `decay_delay`, `charge_frames`, `stance_duration`, `hover_fuel`,
`anchor_duration`, `anchor_range`, `anchor_pull`, `heat_damage_percent`,
`brace_push_percent`, `ward_max`, `description`. Defaults are bounded in core.
Resource name is display-only; `id` selects the numeric custom gauge.

Rules required: version=1, tick_rate=60, units_per_meter=1000, round_seconds,
rounds_to_win, stage_half_width. Optional: seed, buffer_frames (6),
throw_tech_frames (10), intro_frames (60), round_over_frames (120), gravity (12),
spawn_distance (2400), wakeup_invuln (12), throw_invuln (20),
combo_limits:{max_hits:12,juggle:8,scaling_floor:20,scaling_step:10,
stun_decay:2,wall_bounces:1,ground_bounces:1,otg:1}.

Input simple controls default on; optional match `simple_specials:false` requires
motions: quarter-circle forward+attack → special1, back+down+forward+attack →
special3, down+down+attack → special2. MOBILITY remains special2. SPECIAL+GRAB
selects special3 atomically. Neutral SOCD is enforced by the input adapter; core
accepts only axes -1/0/1. Pressed must be a subset of held; repeated claimed edges
while held are suppressed. Invalid API calls set `last_error` and preserve state.
`snapshot()` before a match returns `{}`. `save_state()` includes catalog and rules
identity; load requires the same configuration. AI also exposes save_state/load_state.
