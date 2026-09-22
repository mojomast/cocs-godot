# External task: improve native player/operator models

Prepared at integration HEAD `2af744f`. This task is reserved for an external
agent; the lead has not launched it. Recheck the current ownership ledger before
starting. The owner's request is to begin improving player models using the
procedural-generation research, not to implement the report's crate pilot.

## Primary goal

Deliver a visibly better, reusable **stylized modular operator model** suitable
for the current Godot game. Improve silhouette, human proportions, helmet/visor,
torso/armor, joints, hands and boots. Establish three recognizably different
operator variants through geometry as well as identity accents. Preserve all
nine existing character IDs and team identification.

The current model is a static assembly of boxes, with operator identity largely
encoded by color. This first milestone should yield a convincing in-engine
replacement candidate, a reproducible recipe/generator and reviewed gameplay-
distance evidence. A modeling framework or an attractive close-up alone is not
completion. Full skeletal animation, facial animation and a complete bespoke
nine-character roster are later milestones unless discovery establishes a small,
well-tested improvement within this task's budget.

## Project context

- Repo: https://github.com/mojomast/cocs-godot
- Primary checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
- Integration branch: `port/godot-destinations`; last observed HEAD `2af744f`.
- Create a new branch/worktree under `/tmp/opencode/` from the latest committed
  integration HEAD. Record the exact baseline. Do not use or copy the primary
  checkout's uncommitted changes as your implementation base.
- Pinned engine:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
  (`4.5.2.stable.official.6ce3de25a`).
- Read-only shared dependencies: primary `node_modules`.
- Existing screenshot gallery: http://100.125.104.79:43595/ — preserve its service;
  it is not a browser-playable build.
- Existing Node simulation remains authoritative. Campaign work is deferred.

Read these before planning:
1. `port/handoffs/procedural-model-generation-llm-research.md` — the owner's research.
   It may be untracked in the primary checkout; read that exact file without
   moving, deleting or staging it. Record its hash with your research notes.
2. `port/handoffs/ACTIVE_LANES.md`, root README and `port/RELEASE_MATRIX.md`.
3. `godot/world/actor_visual.gd`, `presentation.gd`, `remote_motion.gd` and
   `local_lifecycle.gd`, plus `godot/tests/protocol/entity_visuals.gd`.
4. `game/{models,model-geometry,operator-profiles,operator-anatomy,character-anim}.mjs`
   and relevant operator data. Use these as identity/context references, not as
   a requirement for exact original-art reproduction or permission to edit rules.
5. `godot/tests/glb_side_import.gd`, `godot/project.godot`, package builder and
   current model/provenance documentation as relevant to your selected backend.

## Ownership and compatibility

Own NEW paths only:
- `godot/player_models/` — candidate visuals, recipes, generators and preview scene.
- `godot/tests/player_models/` — focused geometry/identity/lifecycle checks.
- `port/native-player-models/` — brief, tools, evidence, metrics and handoff.

Do not edit shared `actor_visual.gd`, presentation/session/network, existing tests,
source rules, maps, sports, vehicles, pickups, audio, shared launch/package tools,
aggregate verifier, root docs or another lane's assets. Supply the smallest
indispensable integration changes as an **unapplied patch** in your directory.
You may apply it in a separately staged temporary project to prove integration;
record the patch hash and keep that runtime distinct from the primary checkout.

The pulse-rifle preview/assets remain reserved. Keep the existing generic weapon
as a compatibility reference or use a clearly labelled placeholder for grip/
muzzle alignment. Do not redesign the reserved weapon, first-person arms, vehicle
drivers or Horde enemy classes as an incidental expansion of this task.

Preserve the current actor contract unless separately approved:
- Visual-only Node3D; no colliders, hitboxes, navigation or local gameplay authority.
- Current presentation origin is source position plus **0.9 m in Y**; feet local
  **−0.9**, top **+0.9**, standing height **1.8 m**, width no greater than **0.7 m**.
  Recheck actual source/tests before modeling. Do not change the origin to feet
  and silently double the existing offset.
- Current actor local forward is **−Z**; authority body yaw is applied by
  presentation. Do not borrow the sports car's opposite convention.
- `apply_identity(actor)` handles all nine IDs and numeric JSON teams, including
  floats. Red/blue readability must coexist with operator identity and a
  non-color-only team cue. One actor's recoloring must not recolor another.
- Hidden local player, authoritative dead/absent actor hiding/removal, stable
  instances across snapshots and round cleanup remain intact.
- Identify existing `armor`, `identity`, `team_marks`, `Helmet` and `Muzzle`
  consumers. Preserve their meaningful contracts, or explicitly propose minimal
  fixture/API adaptation. Do not weaken geometry/identity checks to hide a mismatch.

## Phase 1 — parallel discovery before implementation

Launch three bounded read-only discovery agents. Do not implement until **all
three return**. If delegation is unavailable, record that and perform the same
audits sequentially; do not claim nonexistent subagent work.

A. **Runtime/attachment contract:** audit coordinates, current bounds, identity
   fields, material ownership, callers, lifecycle and package/export constraints.
   Return exact file/line findings and a minimal integration proposal.
B. **Visual direction:** study current operators, source profiles and actual
   gameplay screenshots. Propose a coherent armored-operator design and three
   character-specific silhouettes. Choose three IDs after research, preserving
   existing identity intent. Specify front/side/back proportions, semantic parts,
   palette, team marks, gameplay viewing distances and explicit non-goals.
C. **Geometry/backend/performance:** measure the current model's actual meshes,
   vertices/triangles, surfaces/materials, construction time and population cost.
   Evaluate native primitives/SurfaceTool/ArrayMesh versus Blender→GLB for this
   asset. Check exact Godot 4.5 APIs and installed tooling. Return measured
   baseline, practical budgets, reproducibility strategy and likely failure modes.

Do not implement both backends merely to satisfy a comparison. Prefer the least
complex backend that achieves a clear visual improvement. Blender, if selected,
is an offline authoring tool only, with pinned version/export settings and GLB
as the game boundary. Do not add a new dependency or paid asset/service without
justification and owner approval.

## Phase 2 — synthesize the brief

Write `DISCOVERY.md` and `DESIGN.md` in your owned directory. Settle:
- One coherent base model and three distinct variant briefs; palette/fallback
  support for all nine IDs must remain explicit.
- Backend, semantic parts, stable attachment sockets, material strategy and
  source-compatible bounding dimensions.
- Numerical budgets for triangles, surfaces, materials, nodes, textures and
  generation cost, based on the measured baseline. Explain tradeoffs; do not
  invent a universal performance threshold or pretend software rendering is GPU
  hardware acceptance.
- Bounded data-only recipe schema, generator/version/seed and finite part counts.
- Exact output files and acceptance scenarios. Proceed autonomously on reversible
  design choices; ask only about genuine blocking style/dependency decisions.

## Phase 3 — sequential implementation

Use implementation agents **one at a time** for dependent work:

1. Implement a small recipe contract, only the shape operations actually needed,
   and deterministic builder/cache. Reject unknown operations/fields, non-finite
   dimensions, unbounded counts and executable recipe expressions. Generate
   stable geometry once, never rebuild it every frame/snapshot.
2. Build the operator candidate and three geometry-distinct variants. Prioritize
   silhouette and proportion before small panels. Use purposeful joints and hand
   placement; avoid floating arms, fused legs, unreadable dark masses, excess
   emissive trim and decorations extending beyond the established body envelope.
3. Build a reusable neutral inspection scene, matched baseline/candidate captures,
   representative map-lit preview and compatibility adapter. Provide standing,
   aiming/grip and simple articulated-pose inspection where useful. Label manual
   pose fixtures honestly; no rigging/walk-cycle acceptance from a static pose.
4. Perform independent numeric/visual review, localized repairs and documentation.
   Permit at most **three repair iterations per candidate**. Retain the baseline,
   candidates and failed renders; record why each localized change was made.

New generators must be inspectable code. Run them in owned isolated projects
without credentials or network access unless genuinely needed and approved.
Do not load unreviewed generated `@tool` code into the owner's active project.
Record provenance/licenses for any external inputs; original procedural geometry
does not automatically clear unrelated assets' rights.

## Phase 4 — meaningful verification

Provide `port/native-player-models/verify.py` with explicit nonzero failure
reporting, including release-safe checks where GDScript assertions are disabled.
Verify finite geometry/index ranges, nondegenerate required surfaces, winding,
bounds, transforms/pivots, socket orientation, material isolation, all-nine-ID
fallbacks, numeric team forms, non-color team markers and stable repeated updates.
If using nested articulated geometry, compute recursive transformed bounds.
Test absent/dead/self visibility and scene cleanup via the staged integration.

Rebuild twice from clean outputs. Compare recipe/generator/tool/input hashes and
canonical geometry/metadata; use byte equality where deterministic. Explain any
export metadata differences rather than claiming the seed alone is sufficient.

Commands, from your own worktree/staged project as appropriate:
```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
python3 -B port/native-player-models/verify.py
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/entity_visuals.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/presentation.gd
"$GODOT_BIN" --headless --path godot --script res://tests/protocol/local_lifecycle.gd
git diff --check
git status --short
```
The inherited gates must exercise the candidate in the privately patched project;
unchanged-baseline passes alone are not candidate compatibility proof. Do not
claim the aggregate suite passed unless you ran it.

## Phase 5 — actual rendering, live use and export

- Fixed cameras/lighting/exposure: front, side, back, top, perspective, silhouette,
  underside and attachment views. Include a scale reference and matched old/new
  shots at approximately 3, 10 and 25 m, documenting exact camera conventions.
- Render at **960×640 and 1280×800** and directly open the resulting PNGs.
  Check team distinction and variant recognition at gameplay distance, not only
  attractive close-ups. A screenshot file's existence is not visual review.
- Measure representative populations (for example 1/16/32 visible actors,
  labelled as synthetic loads). Record actual draw calls, resource counts and
  frame-time distributions relative to baseline under identical settings.
- In the staged integration, run an owned normal-rate server with unchanged source
  and observe real remote actors moving/turning with the candidate. Correlate root
  position/body yaw and identity with received snapshots. Exercise removal/round
  cleanup. Synthetic death/pose fixtures remain separate from live outcomes.
- Use private Xvfb with `-nolisten tcp -nolisten unix`, isolated XDG directories,
  dynamic loopback ports and only owned processes. Preserve shared port4332,
  screenshot gallery and other worktrees. No state injection to claim gameplay.
- Rebuild/reimport after final model changes and relaunch only your preview:
  `"$GODOT_BIN" --path godot res://player_models/preview.tscn`.
- Privately stage a Linux release export using existing tooling read-only. Confirm
  the candidate loads from a fresh extraction without Blender/editor/source-cache
  dependencies and inspect an actual release render. If not achievable, report
  the precise blocker; do not equate editor import with packaged acceptance.
- Provide exact human smoke steps: inspect variants/teams, view remote actors in
  motion, approach/turn around them, check weapon grip, then restart/leave.

## Delivery

Commit **only owned paths**, with source recipe/generator, candidate resources,
tests, preview, metrics, reviewed before/after images, provenance and HANDOFF.md.
No primary merge, push, public binary upload or shared-service restart. Preserve
all unrelated work and the owner's untracked research file. The lead owns shared
integration, final release rebuild and publication.

Final response: exact baseline/commits/branch/worktree; selected design/backend;
three variants and remaining nine-ID treatment; changed paths; measured budgets
and baseline deltas; actual test/import/visual/live/export results; failure history;
copy-ready preview/build commands; screenshot paths or a permitted private test
link; unapplied integration patch; cleanup and remaining human/animation/hardware
checks. State clearly whether the result is a replacement candidate or already
integrated gameplay. Never call a turntable a completed animated character system.
