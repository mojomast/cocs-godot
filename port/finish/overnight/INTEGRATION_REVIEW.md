# Overnight UI integration review — source-only

Base: `a78edd8d`. Dedicated branch `feature/overnight-ui-review`, worktree
`/home/mojo/.tmp-on-disk/cocs-overnight-ui-review-20261003`.
The completed Vesper branch/evidence was not reused or changed. No nested agents.
Stormglass owns local heavy grant J; this review has run **no engine, import,
Blender, server, render or benchmark**. Features remain source-ready, not native
accepted. Motion/rig and vehicle/movement owners retain their scope.

## Findings and fixes

### Home search and Campaign shortcut

- Guard initial restored-route focus through `Dictionary.get` and a Button type
  check, instead of indexing an assumed route button.
- Escape from a nonempty search clears it; Escape from an empty focused search
  returns to route focus. It no longer falls through to Quit while editing.
- Reviewed search against `route_registry.gd`: candidates come from catalog
  routes and the route's declared map values. Debug-category exclusion is retained;
  typing does not change route/options and Enter does not launch. The Campaign
  shortcut still selects its destination without an implicit launch.
- Added pending native regression cases for empty-field Escape and Unicode input.

### Controls search and modified summary

- Rebinding a row can make its current-binding search stop matching. Previously
  the deferred `grab_focus` targeted the now-hidden OptionButton. Filtering now
  repairs hidden-descendant focus; deferred selection rechecks visibility.
- One binding snapshot per filter pass replaces sixteen repeated reads.
- The 16-action UI remains separate from the complete binding profile. Hidden
  context swaps still report their action IDs, and reset still covers the whole
  profile. New pending regression rebinds a focused ArrowUp search result to I
  and checks focus after deferred callbacks.

### Relay Journal

- **Runtime API error:** `Node.get("phase", -1)` is invalid; Node.get accepts one
  argument. Replaced it and require an accepted playing campaign snapshot, not
  just transport phase 3. Pending action/application focus also gate opening.
- **Invented restart inference:** removed the union/max history and optional-data
  regression heuristic. Current chapter facts are replaced from public snapshots;
  retry continuity already belongs to authority. Other-chapter route marks record
  only observed clears in this session. A new playing snapshot clears that
  chapter's stale completion even when no optional objectives were completed.
- **Aliasing/timers:** snapshot data is deep-copied. Fractional authority elapsed
  times now display floored seconds instead of reverting to zero on almost every
  frame. Nonfinite hold values are rejected.
- **I conflict:** the physical-I convenience shortcut is unavailable whenever I
  is bound in the gameplay profile. Journal button access remains functional;
  hints reflect availability, text fields/modifier chords are guarded, and
  pointer capture is blocked while the journal is visible.
- Opening releases the pointer through the existing route lifecycle; closing
  restores visible prior focus after HUD layout, without stealing a later modal.
  A newly opened external modal closes the journal.
- Timer/hold changes no longer rebuild every workshop label. A separate content
  signature governs rows; removed children leave the tree before queue-free.
  Crew names/poses and workshop choices/hints/results participate in refresh.
- The route strip now lives inside the campaign card's scroll body, preventing
  four wrapped chapter titles from adding unbounded non-scrollable compact height.
- Added pending model/input cases for fractional time, input-copy isolation,
  completion with zero optional progress, rebound I and stable row identities.

### Fighting training feedback/goals

- Equal tick/round observations are idempotent. Previously `<=` reset the seen
  set before the equal-tick guard, so the same snapshot could award goals twice.
- Round changes and unpaired rewinds clear prior progress. Recording stores an
  exact observation prefix; replay restores pending attacks, history, goals and
  seen-event state alongside the saved core state. Future goal counts do not
  survive rewind or grow on repeated playback.
- A delayed projectile contact records the event's move separately without
  overwriting a different running move. `move_start` distinguishes repeated
  same-ID attacks. Empty-ID throw-tech events finalize rather than staying pending.
  Projectile-ID contacts stay separate even from a same-ID new attack. Reflected
  projectiles use factual IDs instead of the new owner's unrelated move name;
  signature goals require the event's authored effect identity to match that owner.
- Ending/replacing `move_id` alone cannot prove a whiff or cancel: interruption,
  mobility, projectile recovery and round transitions also do that. Feedback now
  says **no contact observed**, preserving authoritative hit/block/throw/counter
  results and explicit mobility-use feedback. No combo proof is invented.
- The incoming-throw-tech goal is awarded to the event target, not automatically
  to the attacker whose throw was teched. Targeted goals require the exact move ID.
- Fixed two pending tests that compared the goal's `id` against its `kind`.
- Recording storage is bounded to 18,000 commands (five minutes at 60 Hz).
- Training text uses a bounded scroll viewport below the actual top HUD. Full
  history/goals remain in Training controls. Round labels use the core's already
  one-based index instead of showing Round 2 at the start.
- Expanded pending native tests with duplicate snapshots, delayed contacts,
  round resets, exact saved-prefix restoration, and **480 ordinary-input steps
  through the real core followed by replay comparison**. Added a staged production
  HUD layout gate for 1280×800/UI100 and 760×520/UI150; it excludes rigs and is
  explicitly not rendered gameplay proof.

## Checks actually executed

| Check | Actual result |
|---|---|
| `node --test tools/godot-package/route_parity.test.mjs tools/godot-package/campaign_options.test.mjs` | 17 passed; real catalog generation/parser compatibility, no listener/server |
| `python3 tools/fighting/presentation/test_training_feedback.py` | 6 passed; authored-roster assumptions, grammar and source wiring only |
| gdtoolkit `gdparse` on all 14 changed/new GDScripts | Passed grammar parsing; **not Godot type/API/runtime checking** |
| `python3 tools/ui-review/native_queue.py` | Dry plan printed seven cases; `executed:false` |
| Python AST + `git diff --check` | Passed |

The existing fighting Python test uses source introspection. It is not evidence
that the new observer or engine UI works. The expanded `.gd` regressions have
**not run**. No new native tests were inserted into the parent's 142-case matrix.

## Runtime resource closure impact

New overnight runtime helper resources (already integrated at the review base):

| Root | New static dependency chain |
|---|---|
| `godot/ui/main_menu.gd` | `res://ui/route_search.gd` |
| `godot/campaign/demo.gd` → HUD | `res://campaign/journal.gd` → `res://campaign/journal_model.gd` → existing `catalog.gd` |
| `godot/fighting/main.gd` | `res://fighting/presentation/training_feedback.gd` |

Journal additionally preloads the **existing** `res://input_bindings/access.gd`.
There are no new dynamic FileAccess runtime resources or asset imports.

Actual builder inspection: `tools/godot-package/build.py:279–280` inventories
tracked `godot/` files excluding tests/content/cache; `:351` copies those native
files into the project, and export uses `all_resources`. Thus these committed
helpers are copied and hashed by the builder; this is not an assumed recursive
preload-discovery feature of `final_resources.mjs`. That helper inventories
data/assets/provenance, not the general script dependency graph. No package
change is needed for these scripts, and **no package files were edited**.

Parent closure owner must build/reconcile against the new reviewed commit:
modified `campaign/demo.gd`, `hud.gd`, journal/model, `ui/main_menu.gd`,
`input_bindings/settings_panel.gd`, and `fighting/main.gd`/feedback change runtime
input hashes. The fighting owner may need to reconcile concurrent `main.gd` edits;
core/rig/animation/assets and frozen source files were not changed here.

## Fix commits

- `bed562d4` — Home search intent and Controls hidden-row focus.
- `eddf8b16` — public-state Journal derivation, modal/input guards and stable rows.
- `4108c3f5` — fighting event provenance, exact replay observation prefixes,
  bounded recording/HUD and prepared behavioral regressions.

The final documentation/runner commit follows these. All work is confined to
the review branch; no merge/push, package promotion or native execution occurred.

## Focused native queue — only after a new explicit grant

Dry plan (safe now):

```sh
python3 tools/ui-review/native_queue.py
```

After J release **and a new grant**, on the parent's imported native test project:

```sh
python3 tools/ui-review/native_queue.py --grant NEW-EXPLICIT-GRANT-ID \
  --output /tmp/opencode/overnight-ui-native
```

The runner uses the pinned Godot 4.5.2, LP_NUM_THREADS=1, nonwaiting shared lock,
serial per-case 30–120-second deadlines, isolated settings/bindings and owned
process-group teardown. It does not import, render captures, or start servers.
Prepared cases: Home search/contracts; Controls contracts; Journal model/input;
fighting feedback/core replay; fighting staged compact layout. Proposed matrix
additions are `main_menu/search.gd`, `campaign/journal_model.gd`,
`campaign/journal_input.gd`, `fighting/presentation/training_feedback.gd`, and
`fighting/presentation/training_layout.gd`; the existing Home/Controls contract
entries can be reused. Parent owns registration and any resulting count change.

Follow those model/layout cases with bounded **rendered** inspection at both
sizes and actual routed input: Home Unicode/IME/Enter/Escape with settings/career
open; Controls popup rebind hiding its row; campaign live Journal open/close,
held-input release, rebound I, text-field focus, modal takeover, death/retry/
restart and long route cards; fighting recording-prefix replay, delayed
projectiles, same-move repeats, compact history scroll, focus loss and teardown.
Retain screenshots and actual clip bounds. These remain pending and require the
new owner-granted heavy slot; source checks do not substitute for them.
