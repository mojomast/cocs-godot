# Native LATTICE co-op recruitment

Isolated branch `native-lattice-economy`, based on `c982d25`, worktree
`/tmp/opencode/native-lattice-economy`. Source remains pinned to
`51289b79c627a26a381ba556b92bab71f93f3732`; engine is Godot
`4.5.2.stable.official.6ce3de25a`.

## Native behavior

The existing command board now distinguishes **PvP Fighter (12 team FLUX)**
from **Co-op REINFORCE (50 team FLUX, no REQ)**. Co-op requests one Fighter
and the source's extra thread through its legal `economy/reinforce` action.
The [source findings](DISCOVERY.md) trace the protocol, costs, permissions,
public wallet schema and receipt semantics to the actual implementation.

The co-op control waits for the source's between-wave window, available squad
slot, current recipient executor lease, slice allowance and thread budget. It
requires the public source price and permission flags. Unknown fields, stale
state, missing/wrong identity, wrong mode, death or disconnection disable it.
The footer explains why it is unavailable. The initial deployment is not a
spend window; waiting about two minutes in a normal solo source room is expected.

A fresh checkbox authorization is consumed on each purchase attempt. A change
of round, peer/actor, mode, team, wave or lease, or any blocked gate, revokes
authorization. Recovery never restores consent automatically. Queued and
server-accepted spends remain deduplicated beyond the short click cooldown;
there are no automatic retries. The existing bounded action history preserves
queued / pending (server accepted) / confirmed / rejected distinctions.

Public personal REQ now comes from the exact recipient actor's `cocs.req`
entry, with the same actor's raw `req` as a fallback. An absent wallet stays
unknown. REQ is displayed but is not charged or required for REINFORCE.

Both List and Map retain their existing selection/input behavior. The two
mode-specific labels, costs, selected target and first two receipts fit the
960×640 map viewport; the existing outer scroll remains available for the
footer and longer histories. Friendly rejection text does not replace the raw
reason retained by the transport/evidence.

## Files and checks

- Runtime: `godot/lattice/transport.gd`, `godot/lattice/board.gd`.
- New synthetic suite: `godot/tests/lattice/economy.gd` — **91 checks**,
  including real JSON float decoding, individual budget/permission omissions,
  50-FLUX versus zero/hidden REQ, historical slice remaining versus allowance,
  wrong mode/actor/peer/round, stale state, receipt correlation, exact frames,
  unresolved-spend deduplication and GUI authorization invalidation.
- New graphical observer: `godot/tests/lattice/economy_physical.gd` loads the
  actual board scene and drives `Input.parse_input_event` mouse and physical-key
  press/release events. It uses no handler calls, signals, focus assignment,
  source mutations or built-in smoke activation.
- `run.mjs` owns a normal-rate ephemeral source server and native process. A
  passive allow-listed socket witness checks exact incoming counts, recipient
  identity, permission, successful source receipt, cumulative spent +50,
  spawned +1, and unchanged personal REQ spent. It retains at most 300 wire
  records and 256 KB of native output; its deadline is 290 seconds.
- `verify.py` runs scoped checks, both real co-op maps, and the original List
  and Map observers. `checks`, `live`, and `regression` select those groups.
- Existing `adapter.gd` and `physical.gd` have only assertion descriptions
  updated for the new intended co-op UI. Existing UI test, map renderer,
  deterministic map test, original map observer and old harnesses are untouched.

These are engine-input-path checks, not OS-device injection or a human playtest.
Synthetic fixtures are not claimed as live source evidence.

## Reproduce

Use the primary dependency directory read-only through the ignored symlink:

```sh
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode
python3 port/native-lattice-economy/verify.py
python3 port/native-lattice-economy/cleanup_check.py
```

Every graphical case uses private `xvfb-run -a -s '-screen 0 1400x1000x24
-nolisten tcp -nolisten unix'`, fresh XDG directories, ordinary board connection
and an ephemeral loopback server. Manifest files record exact native commands,
source and runtime file hashes, source pin, display/port and engine version;
the new helper also hashes the engine binary. Cleanup closes the native process
and server and removes the temporary runtime; the wrapper owns its Xvfb lifetime.

## Retained development evidence

- [Initial synthetic attempt](evidence/initial-synthetic.txt): 86 functional
  checks passed, but a provisional unattached footer Label leaked. The unused
  allocation was removed; this attempt is retained as a failure.
- [First Asterion real run](evidence/first-asterion/result.json): 26 native
  checks and all nine wire checks passed. Natural window at ~129 seconds;
  spent 42 → 92, spawned 0 → 1, REQ spent unchanged. This predates final peer/
  lease readiness hardening and friendly TTL text, and is not the final binary
  evidence. Its manifest preserves the exact earlier runtime hashes.
- [Initial check group](evidence/1790042808497006649/results.json): all checks
  passed before the final additional identity/lease/round assertions.

## Final regression evidence

[Final scoped checks](evidence/1790042899153737401/results.json): semantic/source
verification and pinned import pass; adapter **38/38**, existing UI **10/10**,
existing map **23/23**, new economy **91/91**. Selected source suites report
**60 passed, 0 failed, 1 pre-existing skipped** sampled D1–D4 win-rate test.

[Original graphical regressions](evidence/1790042899113625211/results.json):
all six pass. The original map observer still verifies Asterion/PvP 960×640,
Monsoon/PvP 1280×800, and Asterion/co-op 960×640 HOLD/selection. The original
list observer verifies both PvP maps with one 12-FLUX Fighter and one spawn,
and initial-deployment co-op HOLD with recruitment correctly disabled.

Final long-run co-op results and independent-review entry points are recorded
in [HANDOFF.md](HANDOFF.md).

## Limits

This is one supported co-op recruitment purchase, not the entire REQ shop or
all intermission sinks. Confirmation is a source spend receipt; the two live
single-human cases additionally reconcile the public source counters. Concurrent
multi-client effect attribution would need a stronger per-action source receipt
(see the specific source caveat in [DISCOVERY.md](DISCOVERY.md)). HOLD acceptance
does not establish capture: while waiting for recruitment, its normal TTL can
expire, and the native board says so. No shared lobby or session is used.
