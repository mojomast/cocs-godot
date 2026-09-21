# Gameplay evidence handoff review

Reviewed primary base: 7e974f3. Subagent tip: b5d88e9f0ee99dc2515c2e3ea6f9232c2b064a34, including 1206e41 and 2bf3df8. Review only: no integration or live session performed.

## Independently executed

In the isolated gameplay-acceptance worktree:

- `python3 -B -m unittest discover -s port/tools/gameplay_acceptance -p 'test_*.py' -v`: 29 tests passed, including the recorder mock CLI matrix.
- `python3 -B port/tools/gameplay_acceptance/validate.py port/gameplay-acceptance/catalog.json`: SPEC_VALID, five scenarios, six evidence records; not gameplay acceptance.
- `python3 -B port/tools/gameplay_acceptance/death_respawn.py godot/tests/protocol/captured.json`: INCOMPLETE, zero transitions. Camera/input behavior remains unobserved.
- `git diff --check 9e46ad9..b5d88e9`: no whitespace findings.
- `git diff --name-only 9e46ad9..b5d88e9`: all changed paths confined to the two allocated subagent directories.

Both worktrees were clean at review start. Source reviewed directly: recorder, analyzer, runbook, primary session and network client. This is not a complete security audit or independent validation of every gameplay rule in the catalog.

## Findings and limitations

The recorder has explicit deadlines, exclusive output creation, welcome credential redaction and unsuccessful completion on interruption/error. Analyzer completion checks prevent unsuccessful versioned recordings from claiming acceptance. Legacy captures lack that protection and require independent provenance review. Synthetic classification is retained as an input label, not a prohibition on analyzer status `established`; automation must check provenance as well as status.

The recorder is a separate idle actor. Its transition cannot establish native-victim behavior. Recorded `close` means release requested, not completed handshake. Byte limits apply after native WebSocket message assembly. Use only a trusted approved endpoint. Setup completion means welcome, not authoritative actor assignment or round readiness.

No merge is required to run the isolated tools. Retain their branch for review rather than treating committed work as already integrated.

## Native evidence collection points

`godot/world/session.gd:on_snapshot` is the authoritative application point: record source snapshot sequence/time, local actor identity and health/dead, lifecycle status, reseed flag, source yaw/pitch, resulting session yaw/pitch and camera position. Capture both before and after application to avoid mistaking previous state for the current result. Camera rotation is assigned later in `_process`; a snapshot callback alone must not claim rendered orientation.

`session.gd:_process` computes active gating and controls immediately before `client.send_input`. Record computed controls, active predicate, capture mode, focus state, staleness, identity, input sequence and queue result. A successful queue is not server delivery; correlate later ACK independently. Neutral inputs alone do not prove held-input gating without an actual attempted action.

`session.gd:release_pointer` and `_unhandled_input` provide pointer transition sites. Godot-reported mouse mode is program-state evidence, not graphical OS acceptance.

`godot/net/client.gd:decode_text` and its lobby/start/snapshot/events signals provide protocol correlation. `send_input` advances sequence only on successful queue. Do not log welcome credentials or endpoint secrets.

## Prerequisite discovered

The current interactive session unconditionally creates a room once connected, then configures and starts it through its lobby phase machine. Although `client.join_room` exists, there is no session-level join-existing-room path. The default auto-start also leaves no explicit wait-for-participant stage for a recorder that must join before start. A controlled native victim/attacker session therefore needs primary-owned join/wait orchestration or a dedicated acceptance scene before the runbook is executable as native acceptance. Do not silently change default startup behavior just to accommodate the recorder.

## Next implementation scope

Implement an opt-in, bounded native acceptance trace plus explicit controlled-session orchestration, preserving ordinary launch behavior. Test failures and trace limits offline before live use. Require approved endpoint/room and coordinated attacker, normal server timing, unchanged gameplay rules, same-round same-actor snapshots, and clean completion. Correlate native telemetry and protocol observations by identity, round and snapshot sequence; never correlate by nearby wall-clock timestamps alone.

No live server was started, no shared desktop/browser was used, and no runtime code or subagent directory was changed during this review. Live death/respawn, camera reseeding under live respawn, held-input gating and graphical pointer acceptance remain pending.
