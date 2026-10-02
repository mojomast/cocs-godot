# Source-only baseline follow-up during animation grant B

Base: `5eb72bc2`. Existing integration worktree/cache retained; no parent merge.
No Godot, Blender, import, rendering, audio, encoding, new authority journey or
nested agent was run. Grant A remains released. Grant B belongs to animation.
These changes are **source-ready, not newly native-accepted**.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-finish-integration-evidence-20261002`.
Read-only analyses and Node TAP: `source-only-baseline-16/`.

## Demonstrated fixture repairs

### Exact public snapshot history

`run-99yb89rp/spectator-world-wide` reported spectator peer 3 at time **12.467**.
The exact transmitted state is row 69 of 285 spectator snapshots in retained
`wire.ndjson`; **215 newer snapshots** follow it. The fixture retained only 160.
Running the existing `assertPublicObservation` against that actual wire row
passes, including exact positions, private-context emptiness and public allowlist.
SHA-pinned analysis: `source-only-baseline-16/snapshot-analysis.json`.

The fixture now retains detached public-only scalar snapshots for its entire
bounded journey, with a hard 16,384-frame limit that **fails rather than evicts**.
Exact time lookup and exact public comparisons remain. No nearest-time fallback,
tolerance, resampling, fabricated state, or production mutability change.
The source-to-native filter and native-to-source zero-actor-input assertions remain.
Node regression covers delayed lookup, caller mutation, malicious changed scalar,
private-field exclusion and hard-cap failure.

### Rope reconnect never connected

Retained `run-1tdw_lph/gameplay-rope-reconnect` has an **empty trace.json** and
`shared native journey deadline stage=0`. The launcher adds `--lobby-menu` only
for reconnect. `world/session.gd` intentionally enters phase -3 and creates the
form in that mode; it does not auto-connect from `--join-room`. The fixture never
activated Connect and its stage loop waited for phase 3 forever.

The fixture now uses ordinary input to select Guest, type the supplied room code,
and press/release the focused Connect button. Reconnect similarly uses the visible
Retry button instead of directly invoking its handler. No actor/transport writes,
route teleport, authority change or assertion removal. GDScript remains awaiting
native compilation and the actual rope/reconnect journey under a future grant.

## Horde source/native controller alignment

The successful 803.45s source journey is **not** a native result. Retained native
wave timestamps show wave 4 at 174.15, wave 5 at 333.85, wave 6 at 468.10,
wave 7 at 655.55, wave 8 at 733.80, wave 9 at 825.72, then loss at 900s.
This was already behind before wave 9, not solely a Warden finishing problem.

Two concrete controller discrepancies are repaired in the expansion fixture:

- Its visibility ray targets actor y+1.2, but inherited aim targeted y+0.9. Aim now
  matches the source controller's y+1.2 target and player y+1.45 eye; normal mouse
  events carry relative and screen-relative deltas and honor configured sensitivity.
- Inherited navigation always held Shift while moving. The successful source
  controller releases sprint within 30m of an enemy. The native fixture now does
  likewise through key release, preserving ordinary WASD and all source rules.

The Node guard checks the source close-combat aim/sprint contract without running
a journey or changing authority state. Other differences remain (route scheduling,
station ordering, source-clock sampling and close-range backoff). Neither repaired
discrepancy is claimed to explain all lost time or guarantee a 900s native win.
Rendered llvmpipe cadence failures remain; thresholds and clocks are unchanged.

## Still-owned investigations, not waived

- **Campaign movement:** pointer-admission check passes and ACK rises 7→24, but
  actor remains `(-152,18,-104)`. Authored critical path points 0–8 run along the
  same initial direction; retained data does not establish an obstacle or an
  authority movement defect. The fixture now enables existing bounded native
  input tracing only around its normal W-key interval, restoring the previous
  trace setting afterward. This is diagnostic instrumentation, not a claimed fix.
- **Controls textures:** 90 checks pass; two 87,380-byte GL texture leaks remain.
  The fixture already frees both unparented session instances and waits for draw.
  Logs do not identify texture owners. No speculative sleep, scan weakening,
  autoload teardown or runtime resource change was made. Requires native lifetime
  attribution when regranted.
- **Spectator input/retry variants:** exact snapshot-history failure is addressed;
  mode keyboard-cycle and prior reconnect/focus/button failures still need focused
  native reruns. This batch does not declare all variants fixed.

The integration owner retains all these jobs through the next native pass.
Fighting/material/texture source files and frozen `game/`/`server/` are unchanged.

## Verification and future native retry queue

Source check: `node --test tools/experience/connected-native.test.mjs
port/expansion-three/horde/targeting.test.mjs` — **7 passed**.
Initial new test incorrectly expected an explicit false sprint field; source omits
inactive sprint. Initial TAP retained; corrected test checks field absence plus
absence of Shift and exact aim angle. No native checks run during grant B.

**Do not execute below until a new native grant is issued.** Each invocation uses
the stock 4.5.2 binary, `AUDIO_DRIVER=Dummy LP_NUM_THREADS=1`, a fresh evidence path,
and `python3 tools/godot-dev/finish_runner.py --run --grant engine`.
Every selection includes `--select native-version --select native-import`.
Select each listed ID with its own `--select`; budgets are overall wall bounds.

| Order | Additional selection IDs (including dependencies) | Budget seconds |
|---|---|---:|
| 1 | `spectator-native-contract`, `spectator-camera-contract`, `spectator-world-wide`, `spectator-mode-wide` | 900 |
| 2 | `gameplay-contract`, `gameplay-rope-reconnect`, `world-connected-campaign`, `controls-combat` | 600 |
| 3 | `horde-guidance`, `horde-upgrade`, `horde-chain`, `horde-boss` (also `--grant horde-boss`) | 1900 |
| 4 | `horde-guidance`, `horde-upgrade`, `horde-chain`, `horde-rendered-wide`, `horde-rendered-compact` | 2300 |

Then remaining spectator compact/sports/combined variants, with both spectator
contract prerequisites, in separately bounded selections. No full matrix launch
is proposed during this source-only phase. All original failed receipts remain.
