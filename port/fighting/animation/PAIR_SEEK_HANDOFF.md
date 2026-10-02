# Bounded dynamic paired seek follow-up

Status: source implementation and numeric checks complete; native execution
belongs to integration worker `ses_f0294303bffed6Fb8UJLKe4ZDz` under
`FINISH-COMBINED-NATIVE-20261002-A`. No heavy tools were used here.

Read authority: core `6be3b1ce`, especially `snapshot`, `_begin_pair`, `_pair_place`,
`_pair_step`, `_tech` and `_round_result`. No core files or content data changed.

## Adapter behavior

`fighter_visual.gd::_presentation_seconds` uses the matching snapshot pair's
`caught_move_frame,damage_frame,release_frame,end_frame` as independent knots
for `.28,.68,.82,1.0` authored seconds. An optional initial `(0,0)` supports
pre-catch sampling when catch > 0; catch = 0 has no duplicate zero knot.
The current `animation_frame` must equal `pair_phase.frame`. Invalid, nonfinite,
fractional, negative or non-increasing phase clocks are rejected rather than
silently dividing by zero or guessing timing. This affects presentation only.

Pair mapping only applies to the matching attacker move or victim clip and actor
identity. Tech/KO/knockdown/wakeup states, new moves and reaction clips select
their own manifest mapping. `present()` still copies snapshot x/y/facing exactly;
the phase helper never mutates the snapshot, moves roots, swaps actors, emits
events or advances elapsed time. Side swap at core damage therefore remains
canonical without an adapter-side positional adjustment.

## Required parent/core follow-up: persistent attacker recovery projection

Core currently clears `_state.pair` on the release tick, and `snapshot()` emits
`pair_phase:{}` immediately. That loses the dynamic release/end map even on the
release snapshot. A cached presentation fix would fail fresh snapshot playback,
load/rewind and adapter reconstruction. No such cache was introduced.

Add **optional fighter `animation_pair_phase: Dictionary`**, consumed by the
adapter when `pair_phase` is empty, with the same shape:

```
{actor,target,move_id,caught_move_frame,elapsed,
 damage_frame,release_frame,end_frame,frame}
```

Required lifecycle:

1. On successful catch, preserve the exact actual knots on the attacker. While
   held, existing identical `pair_phase` on both participants remains preferred.
2. On release, keep this attacker projection without keeping gameplay `_state.pair`
   alive. Update `frame` from the authoritative attacker `animation_frame` and
   `elapsed = frame - caught_move_frame`; keep all four knots immutable.
3. Retain it through that attacker's recovery animation, including the release
   snapshot and terminal animation sample. Clear on animation transition/new
   move, tech, interrupted recovery, KO/round reset or training reset. Clearing
   solely because `move_id` becomes empty can be premature: current `_advance`
   leaves the old animation selected on its terminal move-frame snapshot.
4. Include the retained projection in saved-state validation/serialization, so a
   restore directly into recovery has exactly the same pose as uninterrupted play.
5. Victim exits to knockdown on release and does not require a retained victim
   clock. Never extend paired gameplay/resource pauses just to retain visual data.

The current roster's earliest/latest catches usually retain the same damage and
release frames, so the existing fixed recovery segment often happens to agree.
That is not a general invariant: core explicitly extends damage/release/end when
needed. A synthetic extended-active catch proves loss of projection can jump from
authored `.82` directly to `1.0`. The adapter supports the field now, but **this
gap is not claimed closed until core supplies it**.

## Checks and integration command

Executed source checks against the parent's current content, SHA256
`a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748`:

- 60 catch scenarios: every active catch frame for all 25 throw/counter timelines,
  including Claude's full delayed-counter window.
- 2,072 shared frame samples: monotone maps and equal attacker/victim phases;
  exact catch/damage/release/end anchors and recovery projection equivalence.
- 360 interruption checks; 420 invalid-clock rejection checks.
- Existing full source motion/rig oracle rerun with current parent content:
  unchanged coverage, zero IK clamping, all 225 body usages checked.
- Python compilation and gdtoolkit grammar parsing of the adapter/new native
  fixture pass. These are source tests, not execution of GDScript, Godot type
  checking, native pair playback or art acceptance. The standalone `gdparse`
  launcher lacked its module path; parsing succeeded with its package directory
  explicitly supplied through `PYTHONPATH`.

Evidence:
`/home/mojo/.tmp-on-disk/cocs-fighting-animation-evidence-20261002/pair-seek-source.json`
and `source-audit-current-content.json` in the same directory.

The integration worker may run the prepared asset-free native assertions:

```sh
LP_NUM_THREADS=1 "$GODOT" --headless --path godot --script res://tests/fighting/animation/pair_seek.gd
```

This exercises the **actual adapter method** for shared phases, release recovery,
rewind, malformed knots and tech. After core persistence is added, its native
save/load/replay suite should include a load directly on release and mid-recovery.
The animation lane has not executed that command or taken the integration grant.
