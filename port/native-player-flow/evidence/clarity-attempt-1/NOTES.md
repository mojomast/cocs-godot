# First clarity journey attempt (retained)

`summary.json` and `observer-last-sample.json` are the first run of
`port/native-player-flow/clarity-journey.mjs`. It failed **before any Career
code**: the native session never completed its WebSocket handshake
(`observer-last-sample.json`: `phase: -1`, `error: "Connection/round-start timed
out. Relaunch to reconnect."`, `opened: false`). The Career panel therefore never
opened and no state was rendered or captured.

The owned authority itself is fine: the two `node --test
port/native-career/results-history.test.mjs` checks (real `Room`/`MatchHistory`
and a live `createGameServer` + `ws` client history round-trip) passed in the same
session. The failure is a Godot-client handshake timeout under the current
runtime, not a reader regression.

The same handshake failure reproduced on the existing
`port/native-career/equipped-journey.mjs` (its own retained attempt lives outside
this lane), so this is not specific to the clarity lane.

The default evidence directory (`port/native-player-flow/evidence/clarity/`) is
left free for a later passing run in an integrated environment. Per the lane
convention, this failing attempt is retained rather than rewritten.
