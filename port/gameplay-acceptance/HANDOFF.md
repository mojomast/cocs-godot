Handoff: gameplay acceptance audit

Bounded recorder follow-up
Started clean on subagent/death-respawn-evidence at 2bf3df876311e4ed85730512b712db67249c3633; verified branch, HEAD and status before edits. Added record.mjs, test_record.py and RECORDING_RUNBOOK.md; extended analyzer for cocs-recording-v1 lifecycle/completion. Primary checkout untouched. No live game session, server, GUI, packages or persistent services started. An initial require.resolve('ws') check failed because the isolated worktree has no ws package; used Node 22 built-in WebSocket instead, without installation. Canonical protocol constants imported read-only.

Executed: python3 -B -m unittest discover -s port/tools/gameplay_acceptance -p 'test_*.py' -v
Final result: 29 tests passed in 3.203s. Eight ephemeral loopback mock cases run the real recorder CLI and analyzer CLI, verify exit codes, exclusive output handling and cleanup. Additional envelope tests reject invalid opening and decreasing timestamps. Synthetic artifacts live only in temporary directories. Incomplete/interrupted recordings with apparent triples remain incomplete.
Executed: python3 -B port/tools/gameplay_acceptance/death_respawn.py godot/tests/protocol/captured.json
Result: INCOMPLETE, zero transitions, exit 1, genuine input unchanged.
Executed git diff --check: passed. Scoped path checks before commit and clean-status verification afterward are reported with commit in final response.

RECORDING_RUNBOOK.md gives exact future commands and coordination: approved existing normal-rate server/room, permission for an idle participant, human attacker, join-before-start, 120-second bound, 10-second connection and 30-second welcome deadlines, 10000 received frames/8 MB raw payload bound, owner-only new output, SIGINT cleanup. Recorder never sends gameplay input or creates/starts a game. Native victim instrumentation remains primary-owned and is necessary for native acceptance. Camera reseeding, pointer capture and input gating remain unobserved. Native WebSocket allocates a whole message before byte-limit checks; use a trusted endpoint only. Close marker means observation ended/release requested, not close-handshake confirmation; no reconnect. Final complete window is not itself a gameplay pass. No live recording has occurred.


Follow-up: offline death/respawn evidence (supersedes no earlier live claims)
Base: 1206e41cce014c2413ef1670325d20f56c9324be.
Branch: subagent/death-respawn-evidence.
Worktree: /home/mojo/.hermes-instances/fresh/workspace/cocs-gameplay-acceptance-audit.
Verified git status --short empty and HEAD at audit commit before git switch -c subagent/death-respawn-evidence 1206e41cce014c2413ef1670325d20f56c9324be in this isolated worktree. No primary checkout changes.

Deliverables: DEATH_RESPAWN_EVIDENCE.md defines source/schema, strict evidence levels and limitations. ../tools/gameplay_acceptance/death_respawn.py is read-only standard-library CLI; test_death_respawn.py contains explicitly synthetic projected fixtures and regressions. No runtime fixes, packages, servers, GUI, shared browser, live verifier, deployment or external services used.

Executed commands from this worktree:
python3 -B -m unittest discover -s port/tools/gameplay_acceptance -p 'test_*.py' -v
Result: 27 tests passed (13 analyzer tests plus 14 existing specification tests). Real subprocess CLI tests exercised established exit 0, sparse incomplete exit 1 and malformed/truncated/duplicate-key invalid exit 2, deterministic JSON and input byte preservation.
python3 -B port/tools/gameplay_acceptance/death_respawn.py godot/tests/protocol/captured.json --json
Result: incomplete, exit 1. Seven nonduplicate full snapshots across the two receiving clients, one duplicate, zero mapped dead snapshots, four death-event receipts and sixteen spawn-event receipts. Broadcast receipts must not be mistaken for distinct world events. No same-actor same-round triple; camera reseeding and dead-input gating unobserved. The generator is sparse and accelerated; see detailed source/provenance in DEATH_RESPAWN_EVIDENCE.md.
python3 -B port/tools/gameplay_acceptance/death_respawn.py port/reports/protocol-capture.json --json
Result: invalid, exit 2: expected object with frames array. This file is a summary report, not another capture. Repository JSON content discovery found only the captured.json frame recording. Genuine recordings were read only.

A first exploratory terminal command was blocked by the gateway command guard; a narrower read-only Python command successfully inspected the schema. No service operation was attempted. Initial implementation incorrectly discarded a lobby mapping that precedes start; source/capture inspection exposed this, corrected before commit and protected by test_lobby_before_start. Actual snapshot-delta spelling is explicitly rejected; no delta reconstruction is claimed.

Limitations and unresolved issues: sparse recordings cannot prove dead-state transitions from events alone. Structurally complete truncated prefixes cannot be identified without a recorder completion marker. Existing capture lacks transport close timestamps; trust socket indices and complete boundary recording, never silently combine separate files. Analyzer is a relevant-schema evidence checker, not the primary agent's full protocol validator. Observed snapshots and event-corroborated snapshots are separate result levels. No gameplay defect was reproduced. Earlier zero-health/zero-dead classification concern remains a hypothesis; ambiguous samples fail continuity here. Quantization near interval endpoints can conservatively prevent event corroboration.

Smallest next primary-owned task: add bounded full-snapshot retention to a sibling of tools/godot-fixtures/capture.mjs (not replace existing captures), and native observability alongside godot/tests/protocol/local_lifecycle.gd or a focused new harness. Record stable per-socket indices; welcome, complete lobby, start roundRevision, all full snapshots and events in receive order; explicit recorder transport-open/close/completion metadata in a documented adapter; actual clock/config/source revision. Normal simulation rate only. Do not change game rules or author debug HP/position edits. Confirm supported controlled attacker/victim session setup before running.

Later live recording plan (NOT started): 30-second setup timeout, 120-second total wall-clock deadline, stop after the first same-round alive/dead/alive witness plus two seconds of post-respawn samples, or stop inconclusive on results, disconnect or missed dead interval. Preserve existing Meridian selection and normal supported inputs. Capture local assignment and actor health/dead/time/seq before lethal damage, during positive dead timer and after authority spawn, plus death/spawn event IDs/times. Record native lifecycle status, attempted input and emitted input during death, applied camera pose/look seed before/after respawn, correlated with the snapshot; packet actor yaw alone cannot prove camera reseeding or input gating. Timeout/boundary without triple is incomplete, never a pass. Redact reconnect/progress credentials; write a new bounded file, do not overwrite shared evidence. On success/error/timeout release input, close only harness-created clients and stop only its own server if authorized/created; preserve user sessions and existing services. Flush the capture and explicit completion reason before analyzer invocation. No such session or instrumentation was executed on this branch.

Scope verification and commit review: git diff --check, git status --short, and staged/committed path checks must contain only port/gameplay-acceptance/ and port/tools/gameplay_acceptance/. Final response provides resulting commit ID; no merge, push or deployment.


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
