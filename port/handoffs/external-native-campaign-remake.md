# DEFERRED — preliminary campaign-remake draft

**Do not execute this prompt or start campaign implementation.** The owner
subsequently deferred campaign work because it needs substantial planning and
research. No campaign agent was launched. The scope, mission count, architecture
and workflow below are unapproved draft suggestions, not committed requirements.
A future dedicated planning phase must establish the brief before implementation.

## User direction

The owner explicitly wants the campaign **entirely remade instead of ported**.
Create new missions, narrative, progression and encounter pacing. Existing
DESTINATIONS maps/operators may be reused as a setting and visual resources.
The existing campaign scripts are not the gameplay specification.

## Copy-ready task

You are implementing a NEW campaign for COCS: DESTINATIONS, not translating the
old campaign. Deliver a complete, deliberately compact three-mission campaign
with a beginning, escalation, finale and ending. Aim for replayable, enjoyable
native gameplay rather than maximum mission count. Also document an expansion
plan using the remaining DESTINATIONS locations.

### Context and isolation

- Repository: https://github.com/mojomast/cocs-godot
- Canonical checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
- Integration branch: `port/godot-destinations`; task baseline: `8ff2e7c`.
- Create your own branch/worktree under `/tmp/opencode/`; never work directly in
  the integration checkout. Fetch/read a newer baseline if necessary, recording
  its exact commit and rechecking `port/handoffs/ACTIVE_LANES.md`.
- Latest verified baseline: 63 local/hosted gates; an editor-free Linux prototype
  also passes independent exported-client startup and cleanup checks.
- Pinned editor:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
- Existing dependencies may be reused read-only from the canonical `node_modules`.
- Existing gallery: http://100.125.104.79:43595/ — screenshots only; leave it running.

Own NEW paths only:
- `godot/campaign_remake/` — standalone scene, gameplay, missions, UI and resources.
- `godot/tests/campaign_remake/` — focused tests and input-path observers.
- `port/native-campaign-remake/` — design, runner, verification, evidence and handoff.

Do not edit shared sessions/network/UI, existing sports/objectives/LATTICE/vehicle
modules, export/package tools, root documentation or the aggregate verifier.
Other agents own KOTH/Domination, sports victory/practice, combined arms and
LATTICE in-world commands. An external agent reserves multiplayer lobby/shared
session work; pulse-rifle asset paths are also reserved. Read these modules for
reuse, but propose any indispensable shared hook as an unapplied patch.

### Product and architecture

Implement a self-contained **Godot-native single-player campaign**, with its own
native gameplay authority and physics. It must launch directly without a Node
server, endpoint or multiplayer room. Existing Node-backed modes keep their
current authoritative simulation. Do not change their source or contracts.

Reuse the existing map catalog and presentation where practical. Prefer Meridian,
Verdant and Ember for the first three missions if their collision/navigation
supports good encounters. Select and document a coherent final set after research.
All nine maps remain part of the overall project; three campaign locations do
not replace or narrow that scope. Do not silently substitute legacy campaign maps.

Required player experience:
1. Campaign title/start/continue and clear controls/settings accessible before play.
2. A readable brief, authored encounter sequence and clear objective guidance per mission.
3. Three genuinely different mission flows, not three copies with different labels.
4. Native movement, aiming, weapons, enemies, pickups and damage feedback sufficient
   for this campaign. New mechanics should be small, coherent and complete.
5. Checkpoints, death/retry, mission completion, progression to the next mission,
   a final ending, replay and return to title.
6. Versioned campaign-local saves; loading/retry must not duplicate rewards or
   leave enemies, projectiles, timers, sounds or held input from the old state.
7. Readable HUD/pause/results at 960×640 and 1280×800, with deliberate fresh input
   after focus return, death, pause and scene transitions.

Reuse visual resources and proven UI components through composition. All new
campaign gameplay belongs inside your namespace. If existing actor presentation
assumes source snapshots, write a documented native adapter rather than mutating
shared code. Use existing/procedural resources; do not wait for new art or add
unapproved dependencies. No new voice-generation service is needed.

### Phase 1 — discovery before implementation

Use parallel read-only discovery subagents when available. Otherwise perform
the same audits sequentially. Do not implement until all discovery is complete.

A. Native foundations: inspect `godot/world/{viewer,catalog,presentation}.gd`,
   controls, collision generation, map bounds, verticality and navigation options.
   Identify what can be reused without depending on Node snapshots.
B. Campaign design: propose a compact three-mission arc, contrasting objectives,
   encounters, enemy roles, checkpoint placements and an achievable finale.
   Include an explicit effort budget and what constitutes a finished campaign.
C. Integration and verification: inspect `godot/project.godot`, current save/input
   patterns, exported-release restrictions, package inspection and owned-process
   helpers. Identify exact scene, persistence and regression boundaries.

Each returns file/line findings, risks and concrete recommendations, not code.
Read relevant implementations fully. Write `DISCOVERY.md` and `DESIGN.md` under
your owned documentation directory. Do not use the old campaign's mission graph,
progression rules or story as the new design merely because they already exist.

### Phase 2 — synthesis

Choose the architecture and mission arc. List expected files, collision and AI
strategy, save schema, finite entity budgets, acceptance scenarios and genuine
blockers. Proceed autonomously on reversible choices. If a source/map incompatibility
would require editing reserved paths, document it and use a scoped solution or
return the precise blocker rather than modifying another lane.

### Phase 3 — sequential implementation

Use implementation subagents one at a time for dependent work, if available:
1. Native player/combat/enemy foundation and one representative playable encounter.
2. Mission director, checkpoint/save/restore and all three complete mission flows.
3. Campaign UI, objective feedback, pause/death/results, ending and replay polish.
4. Independent review, meaningful regression checks, documentation and minimal fixes.

Keep each step attributable and runnable. A mission selector, design document or
single vertical slice alone is not completion of this task. Do not manufacture
length with repeated waves. Favor a short finished campaign over placeholders.

### Phase 4 — verification

Build a scoped `port/native-campaign-remake/verify.py` with bounded commands and
explicit failure reporting. Test real risks: collisions/grounding, enemy ownership,
objective ordering, duplicate completion, checkpoint restoration, invalid saves,
death/retry, focus/pause gating and cleanup across repeated scene transitions.

Use normal-rate native input events for live acceptance. The new campaign is
Godot-authoritative: never inject its health, positions, objective flags, enemy
deaths, completion or saves to claim genuine play. Synthetic save/error fixtures
are useful but must be labeled separately. Test-driver steering is not a product
autopilot. Demonstrate all three missions completing via ordinary controls and
interactions, plus an actual death/retry and a fresh-process Continue.

Commands, from your worktree:
```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
python3 -B port/native-campaign-remake/verify.py
git diff --check
git status --short
```

Run relevant inherited gates when reused behavior could regress; do not claim
the aggregate suite passed unless actually run. Tests must fail explicitly in
release builds, where GDScript assertions are disabled.

### Phase 5 — graphical and restart acceptance

Use owned private Xvfb displays with `-nolisten tcp -nolisten unix`, isolated XDG
directories and only your own bounded processes. Leave shared services intact.
Open actual PNGs with an image-capable tool; log output is not visual inspection.

Exercise: title → new game → first mission → checkpoint → real death/retry →
mission completion → next missions → ending → replay/title. Quit and relaunch
in a separate process with the same isolated save directory to verify Continue.
Check both target resolutions and focus/pause transitions with held controls.
Preserve original failures with exact scene/state/input context. Record build
hashes, engine version, frame/input outcomes and owned-process cleanup.

Rebuild semantic resources and reimport after final runtime changes. Relaunch
only your own campaign scene for final smoke checks:
```sh
"$GODOT_BIN" --path godot res://campaign_remake/main.tscn
```

If practical, verify the final scene in a privately staged release export using
the existing package pipeline read-only. Do not alter its committed five-scene
contract; provide an unapplied integration hook and exact resource requirements.
Do not upload binaries or restart/deploy the gallery.

### Phase 6 — delivery

Commit only your owned files; no force operations, primary merge, push or deploy.
Supply proposed common-launcher/package hooks separately for lead integration.
Document the campaign-authority boundary prominently: new native single-player
rules, unchanged Node-backed multiplayer rules.

Final handoff must include:
- Commit hashes, baseline, branch/worktree and changed paths.
- The new campaign design and what each mission actually does.
- Exact launch/build/verification commands and save-file behavior.
- Actual test results and per-mission live acceptance, with screenshot/evidence paths.
- Original failures, unresolved issues and remaining human/hardware checks.
- Whether final-release export was exercised, and exact integration hooks.
- Clear distinction between implemented gameplay, synthetic tests and demonstrated
  live completion. Never label a partial campaign finished.
