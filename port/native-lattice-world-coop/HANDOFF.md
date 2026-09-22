# World-panel co-op independent acceptance

**PASS on both maps.** One Asterion attempt and two Monsoon attempts; the failed
Monsoon setup attempt remains preserved. No runtime defect or patch is needed.

Worktree: `/tmp/opencode/lattice-world-coop-8a58c97`.
Branch: `native-lattice-world-coop-acceptance`.
Base: `8a58c97e48493e41903c2c9a729e753cb3579500`.
Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`.
Scope: new `port/native-lattice-world-coop/` and
`godot/tests/lattice/world_coop_live.gd` (+ UID).

## Evidence chronology

1. [Initial checks](evidence/1790049738437010168/results.json): semantic export,
   pinned import, observer parse and **separate synthetic lease fixture** pass.
2. [First live batch](evidence/1790049748030221118/results.json): Asterion PASS;
   first Monsoon attempt FAIL after 13.3 s, preserved unchanged.
3. [Corrected observer checks](evidence/1790049892885164891/results.json): all
   four pass; existing fixture has 27 checks and zero failures. This fixture
   does not count as natural lease acceptance.
4. [Second Monsoon attempt](evidence/1790049900845755296/results.json): PASS.
   This exhausts its two-attempt allowance; no further live attempts were run.

## Accepted natural-window results

| Case | Window opened¹ | Whole attempt | Lease epoch | FLUX spent | Spawned | REQ spent |
|---|---:|---:|---|---|---|---|
| Asterion, 960×640 | 54.029 s | 68.187 s | 3600→4200 | 14→64 | 0→1 | 0→0 |
| Monsoon, 1280×800 | 135.173 s | 146.723 s | 8400→9000 | 35→85 | 0→1 | 0→0 |

¹ Native observer elapsed time, including startup; source timing/config is
unmodified. Actual live windows vary with ordinary source bot outcomes.

Both cases passed **35 native checks / 0 failures** and **22 wire checks**.
Each first authorized the old lease, waited naturally (8.799 s / 6.733 s) for
its epoch to expire, clicked the now-disabled purchase, and sent no economy
frame. A new 50-FLUX checkbox click followed by Tab/Enter sent exactly one
REINFORCE. Same actor/socket, neutral inputs throughout the visible overlay,
and stable source own x/z/shots after initial snapshot settling all passed.
Close → release → fresh click moved
the same source actor about 3.835 units, and reopening sent no stale duplicate.

- [Asterion result](evidence/1790049748030221118/asterion-relay/result.json),
  [manifest](evidence/1790049748030221118/asterion-relay/manifest.json),
  [wire](evidence/1790049748030221118/asterion-relay/wire.jsonl).
- [Monsoon result](evidence/1790049900845755296/monsoon-foundry/result.json),
  [manifest](evidence/1790049900845755296/monsoon-foundry/manifest.json),
  [wire](evidence/1790049900845755296/monsoon-foundry/wire.jsonl).

Receipt snapshot sequences are **1825** and **4220**, respectively.

### Retained Monsoon failure and purposeful retry rationale

The observer required seeing HOLD in `running/accepted`. In the failed Monsoon
attempt the source already emitted `done/ok`, `reason:replaced`, for the one HOLD
before any recipient `running` card was observed. See
[native log](evidence/1790049748030221118/monsoon-foundry/native.log) and
[actual failure screenshot](evidence/1790049748030221118/monsoon-foundry/hold-failed.png).
`server/room.mjs:349–356` explicitly settles a replaced task this way. The new
observer accepts running or already-settled HOLD, and the audit requires its
same peer/actor/card with `accepted:true, ok:true`. This is a harness correction;
it does not assert objective capture or successful HOLD task completion.

The only post-Asterion code changes are this setup predicate and its audit.
Exact original bytes are retained as
[observer-v1.gd.txt](evidence/1790049748030221118/observer-v1.gd.txt) and
[audit-v1.mjs.txt](evidence/1790049748030221118/audit-v1.mjs.txt), matching that
run's manifest hashes. Current offline audit also passes Asterion.
The preserved failed Monsoon case still fails current offline re-audit; no
earlier failure is relabeled as live acceptance.

## Receipt interpretation

All purchases require source card `native-r1-p1-s2`, peer **1**, actor **0**,
round **1**, `state:done`, `accepted:true`, `ok:true`, REINFORCE/fighter, plus
cumulative FLUX spent **+50**, source spawned **+1** and unchanged REQ spent.
The preceding HOLD is `native-r1-p1-s1` and can be replaced by ordinary bots.
Earlier source spend is unrelated to recruitment. Wallet subtraction is not the
cost proof because passive income continues.

ACK only establishes input high-water receipt. The audit separately requires
matching done cards and counters; eight negative evidence-mutation cases reject
missing/wrong receipts, duplicate purchase, REQ debit, missing spawn, missing
lease rotation, overlay fire and a second socket. No capture, full-round,
human/OS-input, or strict per-action spawned-actor attribution claim is made.

## Reproduce

From the worktree with this lane applied and primary node_modules linked
read-only (see [README](README.md)):

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
python3 port/native-lattice-world-coop/verify.py checks
python3 port/native-lattice-world-coop/verify.py live
```

Actual second-attempt command:

```sh
python3 port/native-lattice-world-coop/verify.py live --map=monsoon-foundry
```

Each case includes the exact dynamic endpoint/Godot/Xvfb commands and file hashes
in `manifest.json`; the wrapper records exact runner commands in `results.json`.
All source/server/native runtime files remain baseline bytes. Engine SHA-256:
`5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.

The manifests record the base revision because all live work preceded the
delivery commit. Their content hashes identify the executed uncommitted helper
versions. Original Asterion observer SHA-256 is
`781a08de8eb865712af5be5dd6cce99343cd99f5151985903da4ebcde6b64184`;
original audit SHA-256 is
`4b6d75625b381411f785ddb02aefd37322766d1ac02ebc21d7f6ecd69f766462`.

Final observer SHA-256:
`9f2eb317e3f48f44a250f8db73d17c93e29d9628d1e18acf16cd93e9b928d3b8`.
Final audit SHA-256:
`823eba3d7bc73c43b714e85319d456dbea6f4743328d14fabaa3b2b6be35c3d7`.

## Direct screenshot review and cleanup

Opened with the image-capable read tool, at actual viewport dimensions:

- Asterion 960×640: [purchase receipt](evidence/1790049748030221118/asterion-relay/purchase-receipt.png),
  [expired consent](evidence/1790049748030221118/asterion-relay/expired-consent.png),
  [reopened](evidence/1790049748030221118/asterion-relay/reopened.png).
- Monsoon 1280×800: [purchase receipt](evidence/1790049900845755296/monsoon-foundry/purchase-receipt.png),
  [expired consent](evidence/1790049900845755296/monsoon-foundry/expired-consent.png).
- The first Monsoon failure screenshot linked above was also opened directly.

Both panels fit their native viewports; price, disabled old consent, both receipt
rows, ACK distinction and release/fresh-click instructions are readable. The
world geometry visible behind the overlay is distinct on each map.

[Final artifact review](evidence/review.json) confirms every manifest hash against
current or exact archived helper bytes, **zero source/server/native runtime
deltas from base**, correct PNG dimensions, and peer 1 / actor 0 in **all**
recipient/input/command records. All three ports (**44985, 42955, 35681**) are
closed, all nine recorded native/server/Xvfb PIDs are gone, and each case reports
its isolated XDG runtime removed. Xvfb used both `-nolisten tcp` and
`-nolisten unix`. The V-Sync capability warning is retained; passing cases have
no script/resource errors. No merge, push or deployment. Lead owns integration.
