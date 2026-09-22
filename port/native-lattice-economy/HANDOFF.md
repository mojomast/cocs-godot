# Independent verification handoff

## Integration

- Branch: `native-lattice-economy`.
- Worktree: `/tmp/opencode/native-lattice-economy`.
- Exact base: `c982d25ca335da3983df48ea37f7602bf8ded1f2`.
- Scoped deliverable: two native runtime files, two existing assertion-description
  changes, new `godot/tests/lattice/economy*` and this new evidence/tool/doc tree.
- Source/game/server/contracts/dependencies, all map renderer/observer files,
  root docs, root verifier and shared sessions were not changed. No merge/push.

Cherry-pick the scoped branch commit after independent review. Its manifests
have the pre-commit Git revision because tests ran before committing; exact
file SHA-256 values identify the tested contents. Both final live manifests
were compared with current files after testing: **zero hash mismatches**.

## Decision and implementation

The source supports ordinary-recipient recruitment. Co-op is the **50-FLUX
REINFORCE sink**, not the 12-FLUX PvP Fighter role price. No REQ is charged.
See [DISCOVERY.md](DISCOVERY.md) for legal frames, source citations, all gates,
public wallet schema and the source's per-action effect-attribution limitation.

Native co-op recruitment requires a fresh authorized view, between-wave window,
explicit matching source price/permission, squad slot, own executor lease and
slice allowance, and free thread. Each purchase consumes fresh consent;
unresolved actions remain deduplicated. Existing co-op HOLD and PvP purchase
behavior remain verified. Friendly expiration/rejection text preserves raw
wire reasons in evidence.

## Accepted evidence

### Final co-op acceptance on both authored maps

[Results and exact wrapper commands](evidence/1790042899109757665/results.json).
Both cases use the actual command-line board scene at **960×640** with engine
mouse/key events: Connect → Map → select frontier using mouse/keys → explicit
HOLD → wait for natural source window → explicit checkbox → Tab/Enter purchase
→ repeated click suppression → source receipt/counter checks → Disconnect.

| Case | Window wait | Native checks | Wire checks | Source spend / spawn |
|---|---:|---:|---:|---|
| Asterion Relay | 129.6 s | 26 / 0 failures | 9 / 0 failures | spent 28 → 78; spawned 0 → 1 |
| Monsoon Foundry | 132.5 s | 26 / 0 failures | 9 / 0 failures | spent 28 → 78; spawned 0 → 1 |

The witness sees exactly **one HOLD and one economy/reinforce**, own peer 1 /
actor 0 / round 1, unique native action sequences, the same source `done/ok`
card, and unchanged **REQ spent 0**. Personal REQ remained 50 around each final
purchase (naturally earned by source gameplay); it was not a purchase input.
Earlier unrelated source spending accounts for the initial 28. Income keeps
changing wallet balances; cost proof uses cumulative `fluxSpent`, not wallet
subtraction. Each final wire file has only **23 allow-listed records**.

HOLD was initially accepted/running and later expired by normal TTL during the
wait. The receipt explicitly says “Order expired; issue HOLD again.” No order
capture/completion is claimed.

Final case artifacts:

- [Asterion manifest](evidence/1790042899109757665/economy-asterion-relay-960x640/manifest.json),
  [wire witness](evidence/1790042899109757665/economy-asterion-relay-960x640/wire.jsonl),
  [result](evidence/1790042899109757665/economy-asterion-relay-960x640/result.json),
  [native log](evidence/1790042899109757665/economy-asterion-relay-960x640/native.log).
- [Monsoon manifest](evidence/1790042899109757665/economy-monsoon-foundry-960x640/manifest.json),
  [wire witness](evidence/1790042899109757665/economy-monsoon-foundry-960x640/wire.jsonl),
  [result](evidence/1790042899109757665/economy-monsoon-foundry-960x640/result.json),
  [native log](evidence/1790042899109757665/economy-monsoon-foundry-960x640/native.log).

Both record engine SHA-256:
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.

### Unit/source checks and original regressions

- [Checks](evidence/1790042899153737401/results.json): semantic source/export,
  pinned import, adapter 38, UI 10, map 23, new economy 91 — all pass.
  Selected source tests: 60 pass, zero failures, one existing skipped long
  sampled D1–D4 win-rate test.
- [Six original graphical cases](evidence/1790042899113625211/results.json):
  all pass, including both PvP maps in List (28 checks each) and Map (26 checks
  each), plus initial-deployment co-op List (20) and Map (26). The old map
  observer and helpers are unchanged. Only the old List observer's “economy
  disabled” assertion description now says “during initial deployment.”

### Direct screenshot inspection

The following actual PNGs were opened with the image-capable `read` tool:

- [Final Asterion receipts](evidence/1790042899109757665/economy-asterion-relay-960x640/economy-receipts.png).
- [Final Monsoon receipts](evidence/1790042899109757665/economy-monsoon-foundry-960x640/economy-receipts.png).
- [Monsoon waiting window](evidence/1790042899109757665/economy-monsoon-foundry-960x640/waiting-window.png).
- [Asterion disconnected](evidence/1790042899109757665/economy-asterion-relay-960x640/economy-disconnected.png).
- [Original PvP List receipts](evidence/1790042899113625211/native-lattice-physical-asterion-relay-cocs-960x640/receipts.png).
- [Original co-op Map HOLD](evidence/1790042899113625211/native-lattice-map-asterion-relay-cocs-coop-960x640/map-receipts.png).

The map layouts are distinct, labels and selection remain visible, prices and
action labels are correct, receipts fit at 960×640, and disconnect removes all
map targets. The existing outer scrollbar handles the footer/long history;
the two final receipt rows are visible without scrolling.

## Retained failure and cleanup

[Initial synthetic leak failure](evidence/initial-synthetic.txt) and the earlier
successful pre-hardening attempts remain preserved; see README for chronology.
Final cases have no script/resource errors. Xvfb's software renderer emits the
existing V-Sync capability warning.

[Final cleanup](evidence/cleanup.json): **all nine recorded ports closed**,
**no owned native/server/Xvfb runtime children**. Each case's `cleanup.json`
confirms exited native process, closed HTTP endpoint and removed temporary
runtime. The displays used both `-nolisten tcp` and `-nolisten unix`.

## Lead reproduction

With the pinned binary and read-only dependency symlink described in README:

```sh
python3 port/native-lattice-economy/verify.py checks
python3 port/native-lattice-economy/verify.py live
python3 port/native-lattice-economy/verify.py regression
python3 port/native-lattice-economy/cleanup_check.py
```

Allow about five minutes for the two natural co-op windows. No shared lobby,
privileged peer, source changes, injected authoritative state or accelerated
simulation are required. The lead remains responsible for independent
verification and integration into the primary branch.
