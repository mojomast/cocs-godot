# Opt-in native snapshot tracing

Pass `--native-trace` among Godot user arguments alongside the existing session endpoint/join arguments. Disabled by default. The session emits `PORT_NATIVE_TRACE ` followed by schema-1 JSON to stdout after active-round snapshot application (including missing local actors). No endpoints, room tokens, player names or full packet bodies are serialized.

Fields identify the session-local round counter, local actor, latest ACK, lifecycle, health/dead state, pose availability, camera position/angles, whether this snapshot reseeded look, focus, engine pointer mode and capture eligibility. Sequence numbers start at zero; monotonic_usec is process-local, not a server timestamp. Eligibility is not equivalent to held controls or successfully queued input. An ACK is not a snapshot identity or proof that a specific input was applied.

Emission stops after 10,000 snapshot records with an explicit limit record carrying complete=false. This is bounded diagnostic stdout, not a complete recording format: there is no connection-close/completion marker, full authoritative state, input queue trace or graphical observation. Never treat absence of further lines as successful completion or stitch separate process traces together. Retain raw server evidence separately.

Executed `python3 tools/godot-dev/verify.py` after final code/test edits: every implemented gate passed, including the new native-trace gate, existing control-safety gate, live movement/fire, normal-rate results/restart and two native clients. The trace gate exercises 12 synthetic assertions: disabled emission, selected-field serialization, JSON roundtrip, focus/death eligibility, absent pose, actual missing-actor callback emission, inactive-phase suppression and cap behavior. Its JSON output is synthetic, not live death/respawn evidence. Existing live gates ran with tracing disabled; live enabled-trace correlation remains pending.

Next: add input queue/neutral-control evidence and explicit lifecycle markers, then coordinate normal-rate native victim acceptance. No subagent directories changed. No gameplay rules or default launch behavior changed.
