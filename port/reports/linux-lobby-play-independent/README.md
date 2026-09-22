# First exported lobby lifecycle run — FAILED clean-log gate

Actual release executable/PCK from build1790054125934591826 and unchanged
packaged Node authority. `tools/godot-package/verify_lobby.py` adapts the reviewed
follow-up input observer to external script and artifact paths without adding
tests to the production PCK or modifying runtime bytes.

The full functional flow reached all milestone assertions, including natural
results and spectator join. Overall summary remains **PARTIAL/FAIL** because
guest stderr contains two Godot errors disconnecting nonexistent `focus_entered`
and `tree_exited` signal connections. It is not accepted as a clean exported
multiplayer run. The host has only the software-driver warning.

Exact adapted flow, observer, provenance, compressed native/wire/actions,
screenshots, summary and cleanup are retained here. Engine events/Window focus
APIs are test automation, not physical-input/human acceptance. An independent
focus triage owns new evidence in `port/reports/lobby-export-focus/`; do not
overwrite or recategorize this failure.
