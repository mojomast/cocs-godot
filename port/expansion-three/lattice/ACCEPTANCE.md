# Acceptance — READY FOR ENGINE

No Godot, Blender, import, render or export has been run. Parallax owns the
heavy slot. This is source/code/Node completion, not native acceptance.

## Executed

1. `node --test game/lattice-feedback.test.mjs game/audio-captions.test.mjs game/lattice-ui.test.mjs server/cocs-req-receipts.test.mjs`
   — **46 passed, 0 failed**, log:
   `/home/mojo/.tmp-on-disk/cocs-expansion-three-lattice-evidence-20261002/source-tests-1.log`.
2. `node tools/port/lattice/source-oracle.mjs --write` — generated 47 captions,
   4 progress and 13 recovery vectors directly from source. Core hash verified.
   Default (without `--write`) rechecks exact fixture equality.
3. `node tools/port/lattice/wire-journey.mjs` — **22 checks passed** in
   `.../cocs-expansion-three-lattice-evidence-20261002/wire-DXt7SV/{result.json,wire.jsonl}`.
   Includes both player HOLD acceptance, invalid target, spectator refusal,
   no-target, commander-only, BUY settlement/debit, one-active-buff/no debit,
   own-team contacts, spectator private-card/contact absence, window-closed,
   and stale-round rejection. Authority used the existing Tern derivative.
4. `node --check tools/port/lattice/native-clients.mjs` — passed.
5. Default source-oracle comparison passed; all 10 reviewed derivative runtime
   hashes are checked alongside the source/core pins. Production whitespace and
   `git apply --check port/expansion-three/lattice/caption-integration.patch`
   passed; the hunk remains unapplied.
   The `.patch` artifact's unified-diff context prefixes necessarily put a
   space before GDScript tabs; exclude that data file from whitespace lint.
6. Protocol fixture rerun after bounded-log/socket-cleanup changes: **22 passed**
   in `.../cocs-expansion-three-lattice-evidence-20261002/wire-oEfx7k/`.

### Preserved failed attempt

`wire-y5luXi`: configuration deadline. Base server resolves unregistered Tern
to lattice-slice. Fixed fixture to use the existing
`port/multiplayer-worlds/derived/game-server.mjs`; no production source change.
Both the failed and successful JSONL traces remain outside the export tree.

## Commands after explicit engine grant

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/lattice/expansion_feedback_contract.gd
LATTICE_ENGINE_GRANTED=1 LP_NUM_THREADS=1 node tools/port/lattice/native-clients.mjs
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_tactical_contract.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_commands_contract.gd
```

Native runner is bounded to 45 seconds, uses unique evidence and private career /
XDG roots per process, awaits children/server/socket cleanup and preserves
failure logs. Protocol runner independently bounds waits and evidence bytes.
Run heavy jobs sequentially; native fixture intentionally has three clients as
one exclusive-slot test job. Its source wallet setup is a test condition, not
evidence of naturally earned REQ.

## Remaining native/graphical acceptance

- Parse/import and differential GDScript tests are unrun; do not claim compilation.
- Connected native fixture is prepared, unrun. Verify exact failure/settlement
  display through the ordinary adapter before any graphical acceptance claim.
- Graphical Tern two-player + spectator journey: open deck with movement/fire
  held; choose objective, issue HOLD, close and see its receipt; buy with fresh
  consent, then source-refused HOLD replaces BUY; field equipment no-target
  does not spend; inspect accepted vs settled. Source setup must be labelled.
- Inspect 1280×800 and 760×520 at 150% UI with progress, failure, REQ delta and
  combat ribbon simultaneously. Scroll the command-deck detail/activity tabs,
  keyboard focus and close controls; confirm no pointer/held-input leak.
- Verify selection/consent clears on focus/modal, stale state, reconnect,
  death/respawn, results and leave. Verify old receipts do not survive a new
  identity/revision. Existing gates are reused, not newly proven here.
- After the experience lane applies the caption hunk, run shared private-event
  tests with own/enemy/spectator contexts and lifecycle clearing. Verify dynamic
  formatted values and sound eligibility from the 47 source vectors; shared
  subtitle settings/TTL/priority remain authoritative.
- Parent owns canonical test registration, package checks and exports.
