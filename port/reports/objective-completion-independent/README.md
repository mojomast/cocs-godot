# Independent Payload delivery and CTF pass acceptance

Agent commits `460674e`, `12e0707`, `0981a0d` integrated with attribution as
`1228369`, `2077911`, `db0c3ee`. No production objective/source changes were
needed. The lead reviewed the route, ordinary protocol peers and strict replay,
added actual executed revision to new manifests, then ran both cases once:

```sh
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
node port/native-objective-completion/run.mjs --small
PORT=0 TMPDIR=/tmp/opencode GODOT_BIN="$PINNED_GODOT" \
node port/native-objective-completion/run.mjs --pass
```

## Payload: full delivery after banked rollback — PASS

Evidence: `port/native-objective-completion/evidence/58399317-d086-4f6d-814d-d09b03af2afb/`.
**3,801 exact source/native correlations**, 960×640, normal-rate authority:

| Milestone | Source observation |
|---|---|
| Checkpoint 1 | 39.183 s |
| Defender rollback | 148 decreasing snapshots |
| Bank floor held | 79 snapshots, 46.733–49.333 s, never below checkpoint 1 |
| Primary resumes escort | Source occupancy and positive progression verified |
| Checkpoint 2 | 87.600 s |
| Checkpoint 3 / delivered | **124.400 s**, before the legal 180 s limit |
| Natural result and restart | Red winner, delivered, 100%, 3/3; cleared new round and deliberate fresh capture |

Primary: 5,923 received inputs, 3,725 applied-ACK samples, high-water 5,922.
Defender: 3,732 receipts, 3,731 samples/high-water. ACKs and gameplay source
events are checked separately; high-water does not prove every superseded input
was applied. The lead directly opened banked rollback and delivered-results PNGs.
The HUD shows the checkpoint floor and genuine delivery-ended winner clearly.

## CTF: pass to teammate, capture, settled release and restart — PASS

Evidence: `port/native-objective-completion/evidence/1c249468-b8f4-42e7-ae30-97430fdbb2a9/`.
**1,870 exact correlations**, 1280×800. Native actor **0 passed to actor 2 at
20.367 s**, and actor 2 captured at **37.900 s**, without a drop or second pickup.
Natural 60 s results show Red 1:0; restart resets flags/score and sends neutral
input until deliberate recapture. The lead opened teammate-carry and results PNGs.

Primary receipts/high-water: **2,462 / 2,461**. Each ordinary secondary peer has
1,800 receipts and 1,799 applied-ACK samples/high-water. The corrected observer
actually witnesses physical key release after queued events settle:
`fullLiveAcceptance:true`, `settledResultPhysicalReleaseObserved:true`.
Immediate same-callback physical release is false; input eligibility/capture
are already disabled and source input suppression is independently checked.

The original agent CTF run remains **FAILED**. Its narrower replay demonstrates
pass/capture but lacks the settled-release witness. The corruption suite still
requires its full acceptance to reject; the new independent run resolves the
missing witness with fresh live evidence rather than relabeling history.

## Provenance, cleanup and gates

Both summaries record runtime `db0c3ee` plus launcher provenance additions,
exact runtime/helper hashes, unchanged locked source, pinned binary and launch
arguments. Compressed logs have byte-count and SHA256 integrity checks. Both
native/display children reaped and absent, server closed, sockets zero and
temporary trees removed. These are engine mouse/key events, not human/OS-device
playtests; secondary players are ordinary protocol peers, not native clients.

`original-provenance.json` independently verifies original Payload/CTF hashes
against publicly reachable, content-identical cherry-picks and preserves their
original success/failure status. The provenance tool now uses these reachable
revisions and accepts `GODOT_BIN`, avoiding reliance on unpublished agent refs.
Its PID-absence check is an additional same-host observation, not a portable
claim about an old PID on another machine.

Completion replay/corruption **22 tests** and the pinned queued-key timing
fixture participate in the **62-gate combined PASS** with LATTICE world routing.
Full combat/death objective interactions, adversarial networking, human
usability and native recording finalization remain open.
