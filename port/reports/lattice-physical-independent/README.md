# Independent LATTICE native-input verification

Runtime: `aca52f5`. The lead additionally records actual executed revision and
board/scene/observer/helper hashes in new manifests, preserving the original
agent's manifests and failed attempt unchanged.

```sh
PORT=0 TMPDIR=/tmp/opencode \
GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64 \
python3 -B port/native-lattice-physical/verify.py
```

**PASS**. Independent evidence:
[`1790040743513634792`](../../native-lattice-physical/evidence/1790040743513634792/results.json).
Semantic source export, import, **38 adapter / 10 UI** checks pass. Actual
`board.tscn` sessions use native mouse/key events through GUI dispatch:

| Case | Native checks | Wire actions | Observed outcome |
|---|---|---|---|
| Asterion PvP, 960×640 | 28 | 2 | HOLD accepted/running; Fighter confirmed |
| Monsoon PvP, 1280×800 | 28 | 2 | HOLD accepted/running; Fighter confirmed |
| Asterion co-op, 960×640 | 20 | 1 | HOLD accepted/running; economy disabled |

In both PvP cases the recipient done card matches peer/actor/round/card identity,
FLUX spent rises exactly **0 → 12**, and spawned count rises **0 → 1**. Rapid
duplicate clicks submit no extra commands. Native mouse Connect, ItemList
selection, Up/Down keys, checkbox, Tab/Enter purchase and Disconnect all pass.
After disconnect, real disabled controls submit nothing. Every cleanup report
confirms HTTP closed, native exited and temporary runtime removed.

The lead directly opened all three receipt PNGs and Asterion's disconnected
PNG. Resources, actions and both PvP receipts now fit the initial 960×640
viewport. Unknown/disconnected values wrap; co-op economy stays visibly disabled.

This is native **engine-input-path** acceptance, not OS device automation or a
human playtest. HOLD running is not completed capture. Monsoon co-op physical
input, induced live network staleness, multi-client command play, full keyboard
navigation and long history/error scrolling remain unaccepted. Native recording
completion remains unproven. Shared gameplay/network code was not changed.

The subsequent combined verifier at this runtime plus the manifest/route-gate
changes passes **47 gates**; `../verification.json` contains the exact commands
and results. This includes the original 38 adapter / 10 UI checks and the new
12-test source-aware projectile navigation gate.
