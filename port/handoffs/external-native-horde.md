# External task: native Horde survival

Build a playable native Godot Horde survival mode on Meridian Exchange, Verdant
Reliquary and Ember Crucible. Preserve the existing Node-authoritative Horde
rules and deliver readable wave progression, real enemy combat, lives,
results and restart. Campaign work is deferred and is outside this task.

## Context and ownership

- Repo: https://github.com/mojomast/cocs-godot
- Primary checkout: `/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port`
- Integration branch: `port/godot-destinations`; known baseline: `8ff2e7c`.
- Create an isolated worktree/branch under `/tmp/opencode/`. Record your exact
  baseline; read `port/handoffs/ACTIVE_LANES.md` before starting.
- Current accepted baseline: 63 local/hosted gates and a verified local Linux
  release package. Node remains authoritative for existing modes.
- Pinned Godot:
  `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`
- Reuse primary `node_modules` read-only if needed.

Own new files only in:
- `godot/horde/`
- `godot/tests/horde/`
- `port/native-horde/`

Active agents own zone-control modes, sports, combined arms and LATTICE commands.
External reservations cover multiplayer lobby/shared session integration and
pulse-rifle assets. Do not edit their files, shared sessions/network/UI, locked
source/contracts/dependencies, common launchers, package scripts, root docs or
the aggregate verifier. Compose/subclass existing systems; return indispensable
shared changes as unapplied patches. Do not touch campaign implementation.

## Phase 1 — parallel discovery, no edits

Use parallel read-only discovery subagents if supported; otherwise perform these
audits sequentially. Do not implement until every discovery report is complete.

1. Authority/protocol: inspect `game/singleplayer.mjs`, `singleplayer-ui.mjs`,
   `enemy-types.mjs`, `config.mjs`, `core.mjs`, protocol encoding and server room
   configuration. Document exact `state.singleplayer`, enemy/actor, wave, lives,
   score, upgrade and win/loss schemas, including JSON-number behavior.
2. Native integration: inspect `godot/world/session.gd`, controls/presentation,
   `godot/objectives/demo.gd`, GameHUD and scoreboard. Identify a standalone
   subclass/composition path preserving focus, death/respawn and round boundaries.
3. Acceptance: inspect existing normal-rate input observers, source-aware route
   helpers, owned-process cleanup and release-export restrictions. Design real
   combat/wave-clear and death/retry scenarios with bounded runtimes.

Return file/line findings and concrete recommendations. Write `DISCOVERY.md`.
Known starting points: Horde is a source-supported mode on all three maps;
`initializeSinglePlayer()` makes it a lone-human session, and the public snapshot
contains `singleplayer`. Verify details instead of guessing from these hints.

## Phase 2 — synthesis

Write a concise implementation plan, file list, protocol/renderer boundaries and
acceptance matrix. Choose a practical native presentation, not exact original
art parity. Resolve uncertainties before coding; do not silently substitute
mock state or change source rules to make a test succeed.

## Phase 3 — sequential implementation

Use dependent implementation subagents one at a time, if available:

A. Standalone `godot/horde/demo.tscn` and adapter. Host an ordinary source match
   with a validated map and mode=horde. Reuse existing player controls, combat
   presentation and audio. Render only received actors, with bounded cleanup.
   Distinguish relevant enemy roles using economical native presentation.
B. Compact HUD: wave/target, intermission countdown, enemies alive, remaining
   lives, authoritative score and outcome. Include boss/upgrade information only
   where supported by actual source projection. Never advance waves locally.
   Surface required upgrade choices if source progression requires user action;
   optional advanced/endless features may stay explicitly unsupported.
C. Complete lifecycle: real death/life loss, fresh-input respawn, victory/defeat,
   results and restart. Clear old enemies, effects, messages and input state.
   Support 960×640 and 1280×800 without intercepting gameplay unintentionally.
D. Focused tests, acceptance harness, documentation and final integration review.

Expose clear scene arguments and manual controls. Defaults should provide a
normal playable Horde session. A one-wave host preset is valid only if allowed
by source configuration; label it explicitly in acceptance evidence. Do not
pretend a one-wave victory demonstrates a full ten-wave or endless run.

## Phase 4 — meaningful verification

Add tests for missing/stale singleplayer state, JSON floats/actor zero, enemy
removal, wave changes, lives and outcome interpretation, duplicate events,
results/restart cleanup and fresh-input gates. Avoid tests that merely repeat
the implementation. Use explicit test failures where release assertions are off.

Create `port/native-horde/verify.py`, then run:
```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
node tools/godot-export/semantic.mjs
"$GODOT_BIN" --headless --path godot --editor --import
python3 -B port/native-horde/verify.py
git diff --check
git status --short
```

Run relevant inherited safety/HUD gates when reused behavior could regress.
Do not claim the full aggregate suite passed unless you actually ran it.

## Phase 5 — real gameplay and visual acceptance

Use ordinary native key/mouse events against an unchanged normal-rate source
server. No actor/enemy teleports, health edits, direct handler calls, artificial
kills, injected wave/results state, tick acceleration or preferred-seed retries.
Separate test-only steering from human gameplay; it must not become product aim assist.

Required acceptance:
- All three maps genuinely start the native Horde scene and receive wave/enemy state.
- At least one map: ordinary firing damages/kills a real enemy, clears a legal
  bounded wave target and reaches genuine victory; restart requires fresh input.
- Another map: actual source death decreases lives and restores a fresh playable
  state, with held controls blocked across respawn. Report defeat separately if reached.
- Correlate visible wave/enemy/lives/outcome and rendered positions with actual
  recipient snapshots. Distinguish queued input, receipts, ACK high-water and
  gameplay effects; ACK alone is not a kill or wave-clear proof.

Plan routes before running. Bound acceptance to two purposeful attempts per
scenario, each at most 180 seconds. Retain failed runs, exact blockers and
coordinates; deliver honest partial acceptance if a live goal remains unproven.
Do not weaken validators to declare success.

Use only owned loopback servers and private Xvfb with `-nolisten tcp -nolisten unix`.
Isolate XDG/runtime files, terminate/reap all owned children and verify listeners
close. Preserve shared services and unrelated worktrees. Open actual screenshots
with an image-capable tool at both resolutions; logs are not graphical review.
Record exact code/source/engine hashes and reproducible commands.

After final edits, rebuild resources, reimport and repeat affected checks. Start
a fresh owned server/client for final manual smoke: engage → fight → pause/release
→ resume → death or victory → restart. Provide precise human-play steps and any
untested hardware/audio limitations.

## Phase 6 — delivery

Write `port/native-horde/HANDOFF.md` and retain evidence/attempt history in that
namespace. Propose, but do not apply, common-launcher and package support for
`--experience=horde`. Identify release-export resource requirements. Preserve
all nine map identities and current mode support.

Commit only owned files. No primary merge, push, public binary upload or shared
service restart. The lead will integrate, rerun important claims, rebuild the
Linux artifact and publish verified history.

Final response: commit(s), branch/worktree/baseline, changed files, exact launch
and test commands, actual pass/failure counts, evidence/screenshot paths, source
gameplay outcomes, cleanup, unapplied integration hooks and remaining limitations.
Do not equate a working HUD or successful import with playable Horde acceptance.
