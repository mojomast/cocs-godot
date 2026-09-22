# Verification evidence

All evidence here is authority-owned. No test changes source Match state to
manufacture live damage, kills, score, death, respawn, time or results.

## Passed

- `tests-final.log`: **17/17 Node tests passed** (also passed in
  `tests-transport-second.log`). Source construction,
  strict schema/canonical geometry hash, three-ID filesystem allowlist, bounded
  DM config and launcher aliases, FIFO/ACK semantics, ADS true/false, stale/death
  cancellation, finite event ordinals/source ID retention, bot nav/shooting,
  player weapon damage/frags, death/respawn, real-time loopback results/restart,
  transport rejection/cleanup, and HTTP readiness.
- `godot-protocol-first.log`: pinned Godot **4.5.2** decoder fixture passed with
  **zero failures** for ordinary and epoch-aware clients.
- `godot-live-synthetic-first.log`: pinned Godot **4.5.2** connected through real
  WebSockets using **both** the native epoch client and ordinary `net/client.gd`.
  Both observed source ADS press, release, stale reset; ACK 3; finite/deduplicated
  construction and gameplay events. The source arena in this test is explicitly
  a synthetic platform, not a claim about generated-map playability.

## Retained first-attempt failures and corrected test assumptions

- `tests-initial.log`: the test expected `kill`; source emits `death` with
  `killer`. Corrected the assertion; source gameplay was already scoring frags.
- `tests-transport-first.log`: authority sockets/listener closed correctly, but
  the test asserted remote-client close propagation synchronously. It now waits
  for the peer close event before asserting remote state. Other live lifecycle,
  combat/results/restart and death/respawn tests passed on this attempt.

## Generated assets: separate delivery gate

- `actual-schema-first.log`: the first delivered geometry shapes validated after
  aligning explicit metadata fields and source wall-segment schema. This run
  preceded the canonical-arena hash contract and is **not final acceptance**.
- `actual-maps-first.log`: all three assets rejected because their then-current
  hash was from the previous geometry hash algorithm. The strict new requirement
  is SHA-256 of recursively key-sorted `arena` JSON only. The authority does not
  rewrite/re-hash generated files or fall back to synthetic maps.

Run `node --test port/native-arenas/tests/actual-maps.mjs` after the geometry agent
regenerates the canonical hash envelope. Run the documented Godot protocol
command with `--actual --map=<id>` for each map. These gates deliberately fail
missing or invalid delivery. The integrating lead owns the final geometry,
native visual scene, packaged-closure, source-fire/movement and product smoke
acceptance after both agents' deliveries.
