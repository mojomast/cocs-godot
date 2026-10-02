# Core source handoff — READY FOR ENGINE

Branch: `fighting/core-20261002`; worktree:
`/home/mojo/.tmp-on-disk/cocs-fighting-core-20261002`.

## Dependency mapping

| Original content commit | This branch | Parent supplied mapping |
|---|---|---|
| 827d24a8 | 342d8e84 | 0193f14a |
| 79d98652 | 72c409ae | b0669433 |
| bcb1effe | 480ef423 | 1c19f1ca |
| 242d5741 | b9640d4d | 70c1ce4b |

Early core contract: `ce3f603b` (superseded by the reconciled contract in the
implementation commit). Parent already has the content dependencies: cherry-pick
only the core-owned commits, rather than duplicating content history.
No core-authored change to production roster/rules was necessary. Current roster
SHA256: `a736dcfe91d44a08b165e1f7191420617984a561972505b0dd53df1b22cd4748`.

## Implementation

- Required configure/start_match/step/snapshot/save_state/load_state API; isolated
  RefCounted integer authority, no scene physics, class_name or callbacks.
- Input authority derives edges, handles chords/motions/charge/buffering/facing;
  absolute ticks and event IDs survive rounds and hitstop. One signed mul_div
  helper and a finite/integral typed JSON codec preserve replay arithmetic.
- Both actors move before collected contacts resolve. Guard levels, air
  unblockability, startup counter hits, armor, cancel conditions, resources,
  scaling/deterioration/juggle/bounce/OTG/max-combo limits and wakeup defenses.
- Finite projectiles, swept contacts, clash strengths, reflection ownership and
  ledgers; paired normal/command/counter throws with actual shared clocks.
- All nine mechanics: ChatGPT reel, Claude ward/counter-grab, Grok heat/charged
  jump, Meta brace/slam, Gemini timed band plus independent air-use counter,
  DeepSeek charge/fuel hover, Mistral air dash, Kimi blink, Qwen single-use anchor.
- Seeded delayed-observation AI emits the same commands and saves its own
  decisions/history/RNG. No player-input peek, health mutation or hidden stat write.
- Best-of-three-compatible round/match lifecycle, KO/double-KO/timeout, detached
  debug boxes/history, and explicitly training-only reset/placement helpers.

## Integration details to consume now

The authoritative expanded contract is `CORE_DATA_CONTRACT.md`.

1. **Animations:** both paired actors expose matching integer animation_frame and
   `pair_phase:{actor,target,move_id,caught_move_frame,elapsed,damage_frame,
   release_frame,end_frame,frame}`. The adapter must map those *actual* knots to
   .28/.68/.82/1.0, including late catches/counters. This optional mapping requires
   the animation lane's adapter integration; fixed earliest-contact knots alone
   are insufficient.
2. **FX:** persistent projectile current owner is `owner`, not actor. Snapshot
   operator_id/effect preserve original projectile identity on reflection. Contact
   events carry physical overlap/spawn/clash coordinates and projectile IDs.
   Reflection actor/owner = new owner, target = former owner. Canonical break
   spelling is `throw_tech`. Anchor/stance timers are top-level fighter fields.
3. **Input:** axis_y down=-1/up=+1; held is authoritative, pressed is advisory.
   Buffer T..T+5 ages through hitstop. Normal tech is catch elapsed0..9; elapsed10
   rejects. DeepSeek release charge survives six combat ticks, not indefinitely.
4. **Actual combos:** all 27 still have status proposed. Grounded fixtures use
   660 mm spacing. DeepSeek executes both explicit setup command streams; no
   repositioning or charge injection occurs during trace playback.

## Checks actually executed

- Node: **227/227 pass** = 222 content checks + 5 core source/trace checks.
- gdtoolkit 4.5 grammar parsing passes all six core and four fixture GDScripts.
- `git diff --check` passes.
- Evidence: `/home/mojo/.tmp-on-disk/cocs-fighting-core-evidence-20261002/`.
  `source-02.log` is the latest full Node run. `grammar-01.log` retains the initial
  indentation failure; corrected grammar runs are retained separately.

## Native gate queue and remaining acceptance

**No Godot, import, Blender or renderer was executed. Foundry still owns the
heavy slot.** Grammar parsing does not establish Godot type checking or functional
execution. The prepared native suites are:

- `godot/tests/fighting/core/run.gd`: synthetic functional cases, actual charge
  policy, edge authority, freeze behavior, tech boundaries, late pair clocks,
  nine mechanics, projectiles, JSON replay and input-only AI match lifecycle.
- `godot/tests/fighting/core/invariants.gd`: generated nine mirrors + 36 pairings,
  mirrored commands, numeric bounds, event monotonicity and JSON continuation.
- `godot/tests/fighting/core/actual_content.gd`: all 27 traces, both facings (54
  cases), actual contact sequence and uninterrupted combo count, plus JSON replay;
  retains detailed failing traces instead of relaxing requirements.

Exact grant-gated commands are in `tools/fighting/core/README.md`. Parent should
run these on the combined candidate in its one native sandbox before visual
Meta/Mistral acceptance. Native parser/runtime fixes and tuning of any failing
authored combo remain pending that run; no local deterministic, combo, balance,
visual, export or online acceptance is claimed by source-only checks.
