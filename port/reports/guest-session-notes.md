# Opt-in native guest session

The interactive session now accepts `--join-room=ROOM_ID` alongside its existing `--endpoint=URL` user argument. Without it, create/configure/start behavior is unchanged. Use only a coordinated trusted endpoint and an existing compatible Meridian room. This does not provide a room browser or arbitrary-map support.

A guest queues join rather than create, waits for lobby acknowledgement (15-second handshake bound), then waits up to 120 seconds for authoritative start. Repeated lobby messages do not reset that wait. Guests do not configure or start the room; Enter at results does not send a host restart. Empty IDs and automatic smoke-mode combinations are rejected. Joining already-running games is not acceptance-tested.

Executed: pinned Godot 4.5.2 headless guest_session.gd: 10 assertions, zero failures. Synthetic transport checks cover default creation, explicit join, no host commands from lobby/restart, bounded acknowledgement/start waiting, authoritative start and queue failure. The complete tools/godot-dev/verify.py passed after registering guest-session as a permanent gate, including 2,489 control-safety assertions and existing live native gates.

The new interactive guest route itself has not been exercised against a live room or graphically inspected. Existing two-native-client verification uses its own network-level harness. No death/respawn acceptance, native tracing, camera/held-input live evidence or controlled attacker session is claimed. Subagent directories remain untouched. This is the join prerequisite, not the full tracing/orchestration milestone.
