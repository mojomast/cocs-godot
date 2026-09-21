Handoff: gameplay acceptance audit

Base commit: 9e46ad9d0b11dc21538b8c21087c4d2205798fd8
Verified development checkout: /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port
Initial branch/status: port/godot-destinations, clean (git status --short --branch).
Isolated branch: subagent/gameplay-acceptance-audit
Worktree: /home/mojo/.hermes-instances/fresh/workspace/cocs-gameplay-acceptance-audit

Repository discovery first found workspace/cocs on improvement/phase1-spatial; that checkout was NOT used as development base. git worktree list in cocs-godot-port confirmed the expected branch and existing asset subagent worktree. Created this worktree with:
git worktree add -b subagent/gameplay-acceptance-audit /home/mojo/.hermes-instances/fresh/workspace/cocs-gameplay-acceptance-audit 9e46ad9d0b11dc21538b8c21087c4d2205798fd8
No primary checkout switch/reset/stash/clean/commit occurred.

Deliverables
SPEC.md: source trace, authority/native mapping, coverage matrix, evidence limitations and suspected defects.
catalog.json: five pending scenarios (health pickup, weapon pickup, damage, death/respawn, round-ending kill/restart), six explicitly classified evidence records; all steps distinguish authority from diagnostic native presentation.
../tools/gameplay_acceptance/validate.py: standard-library-only structural/reference/evidence validator, not gameplay proof.
../tools/gameplay_acceptance/test_validate.py: in-memory invalid catalogs and CLI tests.
../tools/gameplay_acceptance/inspect_capture.py: read-only existing capture inventory; no network access or regeneration.

Exact executed commands (from isolated worktree)
python3 -B port/tools/gameplay_acceptance/validate.py port/gameplay-acceptance/catalog.json
Result: SPEC_VALID scenarios=5 evidence=6; gameplay acceptance NOT evaluated
python3 -B -m unittest discover -s port/tools/gameplay_acceptance -p 'test_*.py' -v
Result: Ran 14 tests in 0.051s; OK. Required fields, duplicate scenario/evidence IDs, missing/invalid classification, bad references, self dependency, blank fields, wrong root/row types, prohibited unearned pass status, valid CLI and missing-file CLI were exercised. Test duration is observed, not a performance benchmark.
python3 -B port/tools/gameplay_acceptance/inspect_capture.py
Result: client-1 retained states contain no dead>0 actor; 5 snapshots, 1 results; 11 pickup, 48 damage, 2 death and 10 spawn events. The capture identifies accelerated clock and older source commit. This is an offline inventory, not execution of Godot replay tests.

Key verified-by-inspection findings
Pickups are automatic useful proximity contacts (<1.05 in 3D); collection sets 12-second health/armor or 15-second other waits. There is no pickup button, and return is authority wait=0, not client timer. Megahealth does not simply exceed maxHealth. Damage event amount includes absorption, so it cannot be compared directly with HP loss. Death/respawn uses the same actor ID in ordinary Match.spawn; peer IDs, reassignment and round restart must not be confused with respawn. Results stop simulation timers. Native implementation is diagnostic markers/HUD/tracers with dead-timer control gating, not full audiovisual parity.

Existing reports are only attributed evidence. Two-client success asserts movement/ACK/interpolation, not intentional combat. Existing capture contains events but does not retain a complete alive/dead/alive snapshot sequence. Synthetic tests demonstrate branches but cannot fill that gap. No runtime defects were reproduced in this audit.

Suspected defects / questions
Investigate native dead<=0/health=0 classification before mode-wide acceptance (godot/world/local_lifecycle.gd and presentation.gd). Investigate economy collect consuming despite helper failure before labeling it a bug (game/core.mjs). Confirm normal session human join setup: session currently creates rooms; existing two-client harness is not an interactive paired session. Confirm walkable approaches to authored Meridian supplies and actual loadout/modifier values. Other modes, falls, shield-only damage, economy/power supply variants, full inventory rejection and contested collection deserve later targeted expansion; baseline does not claim all-mode acceptance.

Prioritized later live acceptance plan (not executed)
First, the primary agent should add the smallest useful evidence task: a bounded, normal-rate capture/assertion of one same-round local alive->dead->alive transition with actor identity, health/dead, camera pose and dead input gating. Likely files: godot/tests/protocol/local_lifecycle.gd for assertion factoring, a new narrowly scoped native gameplay harness beside godot/tests/protocol/live.gd, and tools/godot-fixtures/capture.mjs or a sibling bounded capture tool. Existing capture should not be overwritten merely to claim success. Implementation belongs to primary agent, not this branch.
Second, resolve controlled human join/aim setup via primary-owned godot/world/session.gd tooling, then execute DAMAGE and DEATH-RESPAWN on Meridian with actual existing config; no debug health/position edits.
Third, execute health and rocket pickup scenarios and wait for server-timed return while outside radius. Correlate event actor/kind with pickup ID snapshot; collect bounded screenshots.
Fourth, execute round-ending lethal kill/results/restart and negative full-health pickup; expand armor/shield/power/economy and mode-specific branches after baseline evidence exists.

Integration / boundaries
Only the two allowed new directories are changed. No runtime code, existing tests, settings, assets, existing reports, map selection, asset-audit directories or dependencies changed. No server, full verifier, shared browser, graphical app, account, service, deployment or restart used. No merge/cherry-pick/push performed. Review commit using git log -1 and git show --stat on this isolated branch; commit identifier is supplied in final handoff response (not embedded self-referentially here). Scope is checked before staging/commit and committed file paths checked afterwards. Validator success certifies specification structure only; all gameplay acceptance remains pending.
