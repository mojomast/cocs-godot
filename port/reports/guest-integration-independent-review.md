# Independent guest integration review

Tested runtime commit: 6071da714cf8123da14d1947bd3e099e2c040503.
Harness adapted without edits from subagent/guest-session-integration, reported commit 389561510ac7c2223a22897c963f3440304ec928. Actual harness hashes are retained in summary.json.

Seven offline tests passed via `node --test port/tools/guest_session_integration/test.mjs` in the subagent checkout. No subagent files were edited.

A detached temporary worktree of the primary HEAD received only a copy of the four standalone harness files. Executed:

`GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node /tmp/cocs-primary-guest-review/port/tools/guest_session_integration/run.mjs`

Exit 0. All four real loopback cases passed at normal server timing: positive guest waiting/start, invalid room, host-not-starting timeout, and connection-failure timeout. Positive wire observations: one JOIN, thirteen INPUT messages, seven snapshots, one START and six snapshots with positive ACKs. No guest host/configuration/restart messages were observed in the bounded test window.

Full evidence is in guest-review-d91a6504/. The summary identifies the tested primary commit and harness hashes. It records importer/native child reaping, server closure and private temporary directory removal.

This independently exercises the latest primary runtime, rather than merely repeating the subagent's results at its older base. Native tracing was not enabled. No intentional death/respawn, graphical acceptance, or post-results restart was tested. No runtime code changed; no subagent commits were integrated. The full project verifier was not rerun because this change contains only review evidence.

Next prerequisite remains enabled native trace correlation, followed by controlled native death/respawn evidence. The existing guest workflow is now independently verified as a coordination building block.
