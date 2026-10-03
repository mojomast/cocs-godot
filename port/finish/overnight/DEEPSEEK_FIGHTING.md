# DEEPSEEK FIGHTING — live training feedback and authored practice goals

Lane: `feature/overnight-deepseek-fighting` (DeepSeek Fighting feature lane)
Worktree: `/home/mojo/.tmp-on-disk/cocs-overnight-deepseek-fighting-20261003`
Base: `aa3b8f0f` (Publish four-chapter campaign scenery before-and-after gallery)
Status: **source complete, native tests authored and explicitly pending an
ordinary engine grant.** No Godot/editor/import/server/render/Blender/audio/
encoding/large-benchmark process ran. `gdparse`, small Python/Node source checks
and `/tmp/opencode/fighting-core-grammar` only. No nested agents.

## Selection (shortlist of 3, finished 2 + one folded-in)

| Candidate | Code evidence in `godot/fighting/main.gd` / core | Decision |
|---|---|---|
| 1. Live input history + actionable move/combo feedback | `history` is 12 raw command dicts shown only as `JSON.stringify` (line ~583); HUD `input_label` shows a single raw `_command_label`; nothing consumes the core's real `hit`/`block`/`throw_*`/`mobility`/`counter` events, `contact`, `combo_hits`/`combo_damage` | **Finished** |
| 2. Guided operator-specific practice goals from actual move data | `show_moves` lists authored moves but gives no practice guidance; all 27 authored routes are `status: proposed` and must not be asserted as verified | **Finished** |
| 3. Training reset/replay discoverability | Reset/record/replay already exist but are buried and show no recording/replay status | Folded in as a status line + navigation hint; no new reset semantics |

Rationale: (1) and (2) share one read-only tracker over authoritative
events/ticks, are high value for learning, and are low-risk because they never
touch authority. (3) was a presentation gap inside the same modal, so it is
addressed in passing rather than as a second feature. Everything is derived from
real core emissions and the authored roster; no large combat subsystem was added.

## Delivered

* New `godot/fighting/presentation/training_feedback.gd` (`extends RefCounted`,
  read-only, no engine/authority access). It tracks, per player:
  * a facing-relative input history (numpad `5/6/4/2/8` + held/pressed buttons +
    the recognised move id) on real ticks, bounded to 12 rows;
  * the outcome of each started attack — **HIT / BLOCKED / WHIFF / CANCELLED →
    next move / THROW / TEC / COUNTER** — finalised from snapshot move lifecycle
    and the core `hit`/`block`/`throw_hit`/`throw_tech`/`counter`/`mobility`
    events, with the live hit chain taken from the victim's real
    `combo_hits`/`combo_damage`;
  * seven practice goals generated from that operator's authored moves: low
    normal, signature 1 (kind-aware: land vs counter), signature 2 (mobility),
    forward throw, tech, super at 1000 meter, and blocking an incoming strike.
    Labels use the real authored move names and `input.simple`/`input.motion`.
* `godot/fighting/main.gd` wiring (owned file only):
  * `feedback.reset(operators,roster)` on every new match;
  * `feedback.observe(state,last_inputs)` after `simulation.step`, so tracking is
    strictly after authority and never feeds back;
  * `feedback.reset_transient()` on recording playback (re-reads replayed events
    from restored core state) and automatically on round-index changes;
  * training HUD line (3 lines, unchanged 64 px reservation) showing each
    operator, goal summary, latest actionable result and a short live input
    history; full 12-row history, last-attack detail, goals and a
    recording/replay status line in the scrollable Training controls modal;
  * the old `JSON.stringify(history)` dump and its display-only `history` use are
    gone from the modal;
  * each operator's goal block ends with a dynamic bind hint built from
    `router.label(p,…)` for L/M/H/Special/Mobility/Grab/Guard, so keyboard and
    controller layouts read correctly without a second binding table.
* Native tests (authored, **pending grant**): `godot/tests/fighting/presentation/training_feedback.gd`
  drives the helper with the real nine-operator roster, real `input_router`
  commands and synthetic snapshots mirroring core event shapes; it asserts
  hit/block/whiff/cancel/throw/tech/mobility tracking, goal derivation for all
  nine operators, bounded history, read-only non-mutation, and
  transient-vs-full reset/lifecycle behaviour.
* Source contract: `tools/fighting/presentation/test_training_feedback.py`.

## Guardrails honoured

* Combat authority, core determinism, roster/rules numbers, input router, camera
  and all other presentation files are untouched. `feedback` is a listener only.
* No fabricated move names, timings or combos. The helper never mentions a combo
  name; goals and labels come from `roster.json`. The 27 authored routes remain
  `proposed` and are not asserted by this work. The source contract refuses any
  authored combo name inside the helper.
* AI/local/training modes, recording/replay exactness, controller recovery,
  stage routes, throws/tech and Home teardown are preserved: no existing line of
  those paths was reordered except adding the post-step observer and UI text.
* No new bindings, text fields or modal input handling. Focus order is preserved
  (`Back` still grabs focus last); existing choice/button texts are unchanged so
  `ui_journey.gd` continues to find them.
* HUD fit: the training line stays within the existing fixed 64 px bottom label,
  so the compact 760×520 UI150 camera-safe reserve is unchanged (the camera's
  0.25 clamp is never exceeded). Full detail lives in the modal's ScrollContainer.
* No assets/GLB/.import, no package receipts, no `.github`, no locked game/server
  changes. Published `cb6` preview remains immutable.

## Source checks actually run (no engine)

* `gdparse` on `main.gd`, `training_feedback.gd`, native test: **passed**.
* `tools/fighting/presentation/verify.py` (gdtoolkit parse of 23 fighting `.gd`,
  918 camera cases, stage hashes, main.gd invariants): **passed**.
* Python unit suites: `test_camera`, `test_devices`, `test_training_feedback`
  = **18 passed**; `tools/fighting/acceptance` discovery = **26 passed**.
* Node: `tools/fighting/core/source.test.mjs`,
  `godot/tests/fighting/content/{content,schema}.test.mjs`,
  `tools/fighting/effects/verify.test.mjs` = **237 passed**.
* `git diff --check`: clean.

These are source/grammar checks only and do **not** waive the 142 final gates.

## Exact native follow-up (after an ordinary engine grant)

1. Read-only helper gate (headless SceneTree, no rendering/audio needed):
   ```sh
   <Godot_v4.5.2-stable_linux.x86_64> --headless --path <worktree>/godot \
     --script res://tests/fighting/presentation/training_feedback.gd
   # marker: FIGHTING_TRAINING_FEEDBACK_OK
   ```
2. Production UI journey with the new modal/HUD (X11 + virtual pads; existing
   acceptance owner): the unchanged `godot/tests/fighting/acceptance/ui_journey.gd`
   already exercises the training modal buttons; run it via
   `tools/fighting/acceptance/ui_driver.py native` as before. It now also renders
   the new read-only labels, which must not disturb button lookup or focus.
3. If the parent wants it registered, propose a `fighting-training-feedback`
   job in the acceptance matrix; this lane did **not** edit
   `port/fighting/acceptance/plan.json` or any matrix.

## Package closure impact

`godot/fighting/presentation/training_feedback.gd` is the only new runtime
resource. The existing proposal include filter `res://fighting/**` already covers
it; `res://tests/**` stays excluded. No new manifest, `.import`, effect audio,
GLB, roster or rules entry is required, so the canonical dependency filters and
the 142-job final matrix are unchanged.

## Files

* `godot/fighting/main.gd` (owned shell)
* `godot/fighting/presentation/training_feedback.gd` (new, isolated)
* `godot/tests/fighting/presentation/training_feedback.gd` (new native test)
* `tools/fighting/presentation/test_training_feedback.py` (new source contract)
