# Core data contract — reconciled v1

This supersedes the provisional contract in ce3f603b. The authored field names in
`port/fighting/content/CONTRACT_DETAILS.md` and `roster.json` at 242d5741 are
accepted. Core normalizes aliases internally, without changing those data files.
`schema.gd` rejects unknown mechanics. All 138 authored moves and all nine
operator mechanics have backend paths; native execution remains a separate gate.

## Time, input and arithmetic

- Zero-based move frames: startup `0..S-1`, active `S..S+A-1`; the input-start tick
  presents frame 0. All authored boxes are facing-local lower-left rectangles.
- `axis_y=-1` down, `+1` up; `axis_x` is world left/right. Neutral SOCD is the
  adapter's policy; only -1/0/+1 enters authority. Independent GUARD only: back
  walks, it does not automatically guard. Air guard is disabled.
- **Authority derives `pressed = held & ~previous_held`.** Caller `pressed` is a
  known-mask advisory field; stale/forged hints neither activate moves nor reject
  an otherwise valid held stream. Both masks must be 0..511. Negative edge is off.
- SPECIAL+GRAB chord resolves before either single button. Simple controls default
  on; `config.simple_specials=false` requires motion+L/M/H for S1/S3. MOBILITY
  selects S2. Motions: 236, 63214, 22, 236236, [4]6 and [2]8. Motion history is
  40 samples, recognition window 18 absolute ticks. Directions are recorded using
  facing at sampling time. Facing locks throughout a committed move.
- Back/down charges use that same locked facing during commitment. Charge counts
  combat ticks, survives **six release ticks**, and is consumed on move start.
  DeepSeek S1 requires 36 back ticks even in simple mode; Grok S2 requires 18 down.
- Button buffer age is **absolute tick age**, including hitstop: a button sampled
  at T is eligible at T..T+5, expires at T+6. It is not extended by a freeze.
- Every valid step advances absolute tick. Inputs/history/buffer are sampled first.
  Global hitstop then freezes move frames, stun, resources, positions, projectiles
  and fight timer together. Only the freeze counter advances. Event serials and
  absolute ticks never restart at round boundaries.
- `integer_math.gd::mul_div` performs signed int64 multiplication/division with
  truncation toward zero. Validated operands <=1e9, product <=1e18. No float
  arithmetic participates in gameplay. JSON floats must be finite integral exact
  values before `state_codec.gd` converts them; fractions/NaN/objects reject.

## Authored mechanic fields consumed

- **projectile:** spawn_frame/x/y/vx/vy/gravity/w/h/life/range/max_count/
  clash_strength/pierce. Finite swept contacts, per-projectile hit ledger,
  ownership changes on reflect; optional reflectable/max_reflections default
  true/2 (bounded to 3). Travel accumulates horizontal absolute displacement.
- **movement:** reel/rush/glide/super_jump/slam/double_jump/hover/air_dash/blink/
  anchor. `from/to` own activation/window; `vx/vy`, `distance`, `duration` bound
  displacement. air_only/ground_only/cooldown/invulnerable_from/to are honored.
  Blink has no invulnerability. Reel `on:hit` starts target pull_speed over its
  duration/distance; guard prevents it. Air uses are separately serialized,
  air_uses=1/reset_on_land=true. Anchor uses anchor_life/trigger_range/pull_speed,
  max_count=1; one trigger consumes the anchor, jump avoids it. Trigger starts a
  12-tick pull capped by trigger range (maximum 1000 mm), no hitstun/guaranteed grab.
- **throw:** range/tech_frames/damage_frame/release_frame/victim_x/victim_y/
  side_swap/command/ground_only/knockdown_frames. Ground-only throws cannot catch
  stun, knockdown, wakeup immunity or an airborne target; they bypass armor.
- **counter:** from/to/reflect/strike/range/damage_frame/release_frame. Claude's
  projectile ward reflects inside its window; only a grounded strike from a
  grounded opponent inside range triggers the paired counter-grab.
- **resource_effect:** resource/cost/gain/on/reset_on_land. Cost once at start,
  gain once on start or unblocked contact. Reflect/counter payoff uses on-hit gain.
  All changes clamp to operator min/max. DeepSeek hover pays 30 fuel once, rather
  than paying again each hovering tick. Its explicit reset_on_land refills fuel;
  grounded regen is one per tick. Qwen gets one tool each 120 grounded combat ticks.
- **armor:** from/to/hits/damage_percent. **stance:** resource/set/duration/variants.
  Gemini sets band=1 for 180 combat ticks, then resets band/stance to 0. Its extra
  jump counter is independent of band. Authored palm move IDs execute directly.
- Scalars meter_gain/chip/pushback/launch_velocity/juggle_cost/knockdown_frames/
  air_ok/ground_ok and input charge_axis/charge_frames are consumed. Optional
  wall_bounce/ground_bounce/otg are bounded by rules. Rules' scaling curve,
  deterioration/minimum stun, max hits, juggle/bounce/OTG limits are applied.
- Grok heat additionally builds one on unblocked strikes (authored hit gain can
  add more), increases damage up to 12%, and decays after 90 idle combat ticks.
  Meta crouch brace halves pushback while its bounded brace gauge is nonzero.
  These default policies can use resource heat_damage_percent/decay/decay_delay/
  brace_push_percent; no FPS cooldowns or distances are inherited.

## Pair clocks: animation and tech

Catch is **elapsed 0**. Normal throw tech is accepted on catch and elapsed 1..9:
exactly ten opportunities. Elapsed 10 is too late. Damage cannot precede elapsed
10, and otherwise retains the authored move-local damage_frame. Command throws
have no input-tech window. Simultaneous catches resolve symmetrically as a break.

Both actors have the SAME integer `animation_frame`, the actual attacker move
frame, starting at the actual catch frame (including late active/counter catches).
Victim animation is `victim_<attacker_operator>_<move>`. Snapshot fighters expose:

```
pair_phase: {actor,target,move_id,caught_move_frame,elapsed,
             damage_frame,release_frame,end_frame,frame}
```

Both actors receive identical pair_phase while held; otherwise it is `{}`. The
animation adapter maps actual **caught_move_frame/damage_frame/release_frame/
end_frame** to authored **.28/.68/.82/1.0 seconds**, preserving authored knot
fractions. `frame` equals both animation_frame values. This optional mapping
handles late catches without inventing clocks or advancing combat from animation.
Attacker recovery continues after release. Victim faces opposite attacker; side
swap occurs at the damage frame. Tech/KO clears the pair. Projectiles/resources
are paused during the paired cinematic while its timeline and fight timer advance.

## Snapshot, events and persistence

Persistent projectiles expose `id,owner,operator_id,move_id,effect,x,y,vx,vy,
life,range,travel,width,height,reflections`. **owner** is current actor 0/1;
operator_id/effect retain projectile provenance after reflection. There is no
projectile `actor` field. Snapshots are detached. Fighter anchor_x/anchor_left/
stance_left are top-level integer fields; gauges are in resources. Do not infer a
timer from a gauge or run a second expiration clock in effects/UI.

Canonical events: move_start, jump, land, mobility, hit, block, counter, reflect,
projectile_spawn, projectile_clash, throw_start, throw_hit, throw_end, throw_tech,
anchor_trigger, anchor_end, round_start, fight, round_over, match_over. Every event
has the DESIGN fields. Contact events carry physical fixed-point contact x/y:
box-overlap centre for hits/clashes, projectile centre at spawn, contact point at
reflection, paired victim impact at throw damage. Reflection actor/owner is the
new owner, target is previous owner. projectile_id and other_projectile_id are
optional. Events are once-per-contact; effects have no authority callbacks.

Public required API unchanged. `last_error` explains atomic rejection. Invalid
configure/start/step/load preserves previous authority; snapshot before start is
`{}`. Save includes catalog/rules identity, checksum, all histories/gauges/RNG/
cooldowns/ledgers/pairs. Load requires matching configuration and validates every
nested numeric value and typed state fields before assignment. AI has separate
save_state/load_state, delayed public observations and seeded decisions; callers
record its state alongside the match for continuation.

Training-only extras: `training_reset({fighters:[{x,y,meter},{x,y,meter}]})` resets
the round and places actors; `training_place` repositions without rewriting charge
history. Both reject versus use. Actual charged combo fixtures place actors once,
then execute both authored setup streams (`defender_setup_inputs` follows the
charging attacker). No repositioning occurs during actual trace playback.
