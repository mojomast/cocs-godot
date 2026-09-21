# Independent current-checkout guest integration

Actually executed in `/tmp/opencode/cocs-native-integration` at
`86ef71965e1a1e5c649bec660ab7c6660db09b89`, using that checkout's runtime:

```sh
TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules \
node port/tools/guest_session_integration/run.mjs
```

Exit 0. Run `b624e1aa-3c9d-4043-842d-5b50c04fd29a`:

- Positive: native waited before host start, then actor 1 applied six snapshots
  with ACK 10; server observed one join, one start and twelve received inputs.
- Invalid room: real error at 0.506 seconds, one join, no starts/snapshots.
- Host not starting: real native timeout at 120.372 seconds, no starts/snapshots.
- Connection failure: owned HTTP 503 WebSocket rejector; real timeout at
  15.107 seconds, no join/start/snapshots. This is not a blackhole/TCP-refusal test.

All importer/native children reaped, loopback servers/rejector closed, private
temporary storage removed. The lead independently checked all five recorded
PIDs absent after execution. Native test windows end via owned SIGTERM after
observed predicates; that is explicit harness termination, not native trace
completion. This test does not exercise death, pickup or graphical interaction.

`index.json` is a compact projection with source commit and harness hashes;
`evidence.tar.gz` losslessly retains all eleven original run files (18,047 bytes
compressed). The original historical subagent runs remain separately archived
under `port/guest-session-integration/`.
