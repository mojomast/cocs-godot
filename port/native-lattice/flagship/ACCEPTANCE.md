# LATTICE Strike flagship integration and acceptance

Base: `d23d02a56ba622defffc94c249a08af9b32350c6`. Selected source:
`515daf07589150dd3241f4ae1425cc1b093912f5` (`port/contracts/source-lock.json`).
This report tracks the isolated flagship worktree; historical LATTICE evidence
from earlier pins is not substituted for this pin's acceptance.

## Lightweight baseline and pre-engine integration checks (2026-09-25)

| Check | Command | Result | Evidence class |
| --- | --- | --- | --- |
| Source semantics | `node tools/godot-export/semantic.mjs` | exit 0; nine semantic maps exported | provenance/build input, not native gameplay |
| Pinned source rules | `node --test game/cocs-wire.test.mjs game/cocs-spend-surface.test.mjs game/destination-lattice.test.mjs server/cocs-net.test.mjs` | exit 0; 56/56 | direct source contracts |
| Existing launcher/package/routes | `node --test tools/godot-dev/launch_options.test.mjs tools/godot-package/options.test.mjs tools/godot-package/route_parity.test.mjs` | exit 0; 25/25 | parser/metadata contracts |
| Shared endpoint seam | `node --test tools/godot-package/endpoint.test.mjs tools/godot-dev/launch_options.test.mjs tools/godot-package/options.test.mjs` | exit 0; 19/19 after allowing LATTICE routes | focused parser contract; not a live guest join |
| Existing lobby ownership | `node --test tools/godot-package/lobby_options.test.mjs tools/godot-package/lobby_ownership.test.mjs` | exit 0; 10/10 | focused launcher ownership fixture, not a shared LATTICE room |
| Existing economy/role rules | `node --test game/cocs-economy.test.mjs game/cocs-roles.test.mjs` | exit 0; 24/24 | direct source contracts |
| Existing PvP rung rules | `node --test game/cocs-pvp.test.mjs` | exit 0; 20/20 | direct source contracts, not ordinary server-seat tests |
| Existing Operations rules | `node --test game/cocs-coop.test.mjs` | exit 0; 14/14 | direct source contracts, not a natural five-wave clear |
| Disk-backed package state guard | Inline Python import of `tools/godot-package/build.py`, `COCS_PACKAGE_DISK_ROOT=/home/mojo/.tmp-on-disk`; four allowed/disallowed paths | exit 0; 4/4 | static path validation, no package build |
| Aggregate pre-engine runner (while L2–L5 pending) | `python3 port/tools/native_lattice_flagship/verify.py --node --semantic` | exit 0; 116/116 Node tests, nine semantic maps | contract/provenance only; `port/native-lattice/evidence/flagship/contracts-1790313322556940144/` |
| Expanded recipient/support contracts | `python3 port/tools/native_lattice_flagship/verify.py --node` | exit 0; 167/167 Node tests | direct/fixture contracts; `port/native-lattice/evidence/flagship/contracts-1790314190303355290/` |
| L1–L3 pre-engine integration | `python3 port/tools/native_lattice_flagship/verify.py --node --semantic` | exit 0; 168/168 Node tests and nine semantic maps | contract/provenance only; `port/native-lattice/evidence/flagship/contracts-1790315114234798383/` |
| L4 route parity | `node --test tools/godot-package/route_parity.test.mjs tools/godot-dev/launch_options.test.mjs tools/godot-package/options.test.mjs` after generating 22-route registry | exit 0; 27/27 | CLI/schema contracts only; no native launch |
| L1–L4 aggregate before L5 delivery | `python3 port/tools/native_lattice_flagship/verify.py --node --semantic` | exit 0; 170/170 Node tests, nine semantic maps | direct/fixture contracts and provenance; `port/native-lattice/evidence/flagship/contracts-1790315565130630928/` |
| L1–L5 pre-engine aggregate | `python3 port/tools/native_lattice_flagship/verify.py --node --semantic` | exit 0; 183/183 Node tests, nine semantic maps | contracts/synthetic audits only; `port/native-lattice/evidence/flagship/contracts-1790316187415181174/` |
| Two-client gate and direct Match matrix | `python3 port/tools/native_lattice_flagship/verify.py --node --semantic` | exit 0; 187/187 Node tests, nine semantic maps | synthetic two-client gate and privileged direct source experiment, **not** live multiplayer or natural rounds; `port/native-lattice/evidence/flagship/contracts-1790316494062383366/` |
| Engine slot guard | `python3 port/tools/native_lattice_flagship/verify.py --engine` without marker | refused before child creation, exit 2 | resource guard; `/home/mojo/.tmp-on-disk/lattice-engine-denial.log` |

Raw logs are retained outside the repository at
`/home/mojo/.tmp-on-disk/lattice-baseline-semantic.log`,
`/home/mojo/.tmp-on-disk/lattice-baseline-node.log`,
`/home/mojo/.tmp-on-disk/lattice-baseline-options.log`,
`/home/mojo/.tmp-on-disk/lattice-role-baseline.log`,
`/home/mojo/.tmp-on-disk/lattice-rung-baseline.log`,
`/home/mojo/.tmp-on-disk/lattice-endpoint-baseline.log`, and
`/home/mojo/.tmp-on-disk/lattice-coop-baseline.log`.
Some checks predate flagship integration and none establish MVP-A, MVP-B,
MVP-C1, or MVP-C2. Integrated gate results and attempt manifests belong below.

## Integrated gates

L1 projection/session, L2 legal-target/HUD, and L3 session/outcome/command
presentation are composed in this worktree. Pinned engine contracts now pass;
static review corrected source `overReason`,
pre-start null actor assignment, inactive-owned-node legality, and the distinction
between simulation actor and room peer IDs in observed order events. L4 launcher
and package options, menu metadata, and generated routes are integrated; Board
option consumption is now implemented in L5's Board, while the independent
two-client witness runner has engine-scripted short-run evidence but no human input, and the direct Match experiment
covers dominance, floor, roles and time tie-break with two explicit topology/order gaps. The
source host frame omits a bot-count override for rung requests.

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 provenance | Base and pin recorded; runtime package built from `fb7ac021`, later evidence-tool/report commit separately tracked; source lock unchanged | This document; source lock; `port/native-lattice/evidence/flagship/contracts-1790316494062383366/manifest.json` |
| G1 contracts | PASS: 189/189 Node and four GDScript fixtures; live behavior separately gated | `port/native-lattice/evidence/flagship/contracts-1790320775739691023/` |
| G2 import | PASS pinned Godot 4.5.2 import; failed repair attempts retained | `port/native-lattice/evidence/flagship/contracts-1790320775739691023/` |
| G3 rendered | Partial: synthetic layout pixels at 960×640 and 1280×720 plus real-source 60s scripted-input World setup/commands/results at 1280×800; inspected restart control and source result. Walk to legal frontier/OS-human input still open | `port/native-lattice/evidence/flagship/render-1790319250/`, `ordinary-1790320793556-ff89655f-98ec-4db8-8574-b447d1166ccd/` |
| G4 MVP-A natural rounds | BLOCKED: full-limit PvP on both maps ended by source dominance at ~77/82s, with source capture/owner change, exact local HOLD completion and restart. Input was engine-scripted and native UI was not reviewed in those attempts. Full-limit Monsoon Operations ended by source `operation-failed` with 4/5 waves cleared; Asterion driver observed the same, but its terminal wire records were lost. No five-wave win, REINFORCE effect, PvP loss or local physical capture participation was verified. Two Asterion and one Monsoon Operations recorder attempts lost terminal wire frames at their caps; every failure is retained | `port/native-lattice/evidence/flagship/ordinary-1790323022182-f550da57-82f2-4bb5-aa6b-ab431159b46d/`, `ordinary-1790323106742-0c1d38b3-ebee-4620-bd31-e95dbc37aa95/`, `ordinary-1790324104649-1b0808ca-2657-4850-b94b-2300aa26502a/`, `ordinary-1790321157954-cfe05035-1562-4aed-93b4-1ddb6599874c/`, `ordinary-1790322103724-6adbe1b3-3e28-4504-8cc4-4fecdc5c2546/`, `ordinary-1790323197626-1dc666c8-d9db-4675-8769-5d7893706a72/` |
| G5 MVP-B rung rules/server floor | Partial: 20/20 ordinary socket-seat floor cases pass after the source's 20s disconnect grace; direct Match matrix leaves adjacency/order cases unavailable | `port/native-lattice/evidence/flagship/ordinary-floor-1790319473466/`, `direct-match-1790316465667-1097543/` |
| G6 MVP-C1 independent native clients | Partial: two independent native clients on Asterion PvP and Monsoon Operations received source starts and moved with engine-scripted ordinary inputs; 45 input frames each, no full results/restart, OS/human input or negative guest-start authorization | `port/native-lattice/evidence/flagship/two-client-1790319858920-4cd6ea9c-583a-4619-bf1d-c780044f253e/`, `two-client-1790319926506-d68e94f0-fb46-4e43-98a8-f8b0abfff255/` |
| G7 packages | Partial: Linux and Windows archives built from committed `fb7ac021`; packaged Linux World startup/cleanup on Asterion PvP and Monsoon Operations plus packaged menu 22-route smoke passed. Windows 141-file manifest integrity checked on Linux. No packaged complete match, Board entry walkthrough or Windows native launch verified | `/home/mojo/.tmp-on-disk/lattice-flagship-linux-package-state/builds/1790320953885833610/`, `builds/1790325042880655616/`, `port/native-lattice/evidence/flagship/package-smoke-1790321115595890864/`, `package-smoke-1790321130145996343/`, `/home/mojo/.tmp-on-disk/lattice-package-menu-smoke.log` |
| G8 MVP-C2 eight human participants | Pending owner-organized play | — |

The resource marker `/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted`
was granted after the initial commit. Pinned import, synthetic native pixel review
and ordinary server-seat floor checks then ran serially. The first floor attempt
started during the server's reconnect grace and failed 4/20 cases; after waiting
for the source's own human-count echo to drop, the next attempt passed 20/20.
Failed attempts remain retained. Four short exploratory PvP rounds produced real
source time-limit results, ownership flips, matching local order completions and
restart, but no local physical capture participation. One earlier Asterion run
lingered for its harness deadline after a clean child exit; its cleanup file
records closure and the runner timeout was repaired. The first native pair ended
before simultaneous presence was checked; the second pair held both processes
through that check. Neither is a full C1 round. Direct Match mutation remains
privileged synthetic evidence, not natural gameplay. This report is **not** an
MVP-A/B/C1/C2 acceptance declaration.

### Full-limit and package notes

- Asterion PvP `ordinary-1790323022182-f550da57-82f2-4bb5-aa6b-ab431159b46d/`:
  source `timeLimit=900`, natural dominance win for team 0 at source time 77.3s,
  5 capture events, local order completion correlated by card/actor/node, restart
  revision 2; no local physical capture participant or human input.
- Monsoon PvP `ordinary-1790323106742-0c1d38b3-ebee-4620-bd31-e95dbc37aa95/`:
  same configuration, natural dominance win at source time 82.2s, restart.
- Monsoon Operations `ordinary-1790324104649-1b0808ca-2657-4850-b94b-2300aa26502a/`:
  source `timeLimit=900`, outcome `operation-failed`, winner team 1, wave clear
  4/5 at source time 900.0s, restart revision 2. Asterion's two corresponding
  native driver reports also show 4/5 losses, but its bounded wire recorder lost
  terminal frames; they cannot establish the full source-wire audit claim. The
  recorder was repaired for the later Monsoon attempt (0 capacity drops).
- Linux package archive SHA-256:
  `85963193ce22404ec549f21ba16f3dcdad6f8b43586e94db20284dea0e0dee9a`;
  package manifest SHA-256:
  `e42802f656cfd277e5a2047a5146db0ccd8cb3efeb11e3b16a27d3b9ea47c757`.
  Exact build command:
  `COCS_PACKAGE_DISK_ROOT=/home/mojo/.tmp-on-disk python3 tools/godot-package/build.py --target linux --state /home/mojo/.tmp-on-disk/lattice-flagship-linux-package-state --archive-directory /home/mojo/.tmp-on-disk/opencode/lead-native-linux-package/toolchain`.
  Built from HEAD `fb7ac021`; further changes are evidence tooling and this report,
  not packaged runtime bytes. Launch inside the extracted package with
  `node run.mjs --experience=lattice-world --map=asterion-relay --mode=cocs --bots=2 --time-limit=900`;
  for Operations use `--map=monsoon-foundry --mode=cocs-coop`. The smoke runner
  `python3 port/tools/native_lattice_flagship/package_smoke.py --package <package-path> --map=asterion-relay --mode=cocs`
  owns and closes its display/server/native launcher. A prior direct `timeout`
  attempt and a failed Xvfb displayfd attempt are retained in external logs and
  `package-smoke-1790321084451456360/`; neither is a passed package gate.
- Windows package archive at
  `/home/mojo/.tmp-on-disk/lattice-flagship-linux-package-state/builds/1790325042880655616/cocs-native-windows.zip`,
  SHA-256 `b06b1d66cd53bd53358495ed4cc87df9649b6ca7c67c2585ed52afb39f642a3b`,
  manifest SHA-256 `e884c0a6ebda23b8c8d8180cf5b1d22c2653cc23014d017d4f357e11d3b23c15`.
  Build used the same `build.py` command with `--target windows` and the same
  state/archive directory. A local 141-file manifest hash check passed; an actual
  Windows host is required for `tools/godot-package/verify_windows.mjs` and any
  Windows playability claim.

Engine-scripted ordinary inputs can lead to a real source outcome, but do not
prove human input or the entire MVP-A scenario matrix. A short smoke, fixture,
direct simulation, ACK, or generated image is not a full-round or human result.
Natural attempts retain failures, time-outs, cleanup and source outcomes separately.

## Post-preview development checks (not packaged or MVP acceptance)

The later integration branch adds a guidance-intent correction, an opt-in
two-native-client complete-round witness, and source-bound decorative LATTICE
instruments. These changes are newer than the packaged runtime `fb7ac021` and
the preview linked by that package; the previous gate counts remain historical.

| Check | Observed result | Boundary |
| --- | --- | --- |
| `node --test port/tools/native_lattice_flagship/two_client.test.mjs` | 10/10 focused tests pass after the pre-start null-actor identity fix | Synthetic evaluator contracts |
| Asterion PvP `--engine-driver --full-round --limit=120` | `ENGINE_FULL_ROUND_OBSERVED`: peer/actor 1/0 and 2/1 each observed source dominance win for team 0 at revision 1 and a new round at revision 2; independent terminal/restart probe reports correlate, no dropped wire records, evidence hashes and cleanup pass | `port/native-lattice/evidence/flagship/two-client-1790368769778-38f56c38-32b3-4fbf-9b70-2a85f7578e0b/`; engine-scripted inputs, **not** human C1 acceptance, not an Operations five-wave win |
| Pinned Godot 4.5.2 `--editor --import --quit` then `--script res://tests/lattice/flagship_asset_contract.gd` | Import exits 0; asset contract `PASS` | No on-screen readability or map walkthrough |
| Pinned Godot 4.5.2 `--script res://tests/lattice/flagship_l2_contract.gd` | 17 checks, 0 failures after explicit GDScript `bool` inference correction | Guidance fixture, not a natural opponent-contest session |
| Latest Mothbake recorded run/rebuild and four authenticated `blur-core-v1` live jobs/rebuild | Two local fixture jobs, four paid studies completed, normal hashes reproduced from archives | Material candidates and job IDs are recorded in `assets/README.md`; runtime instruments still use authored palette materials, no visual approval |

The complete-round runner is opt-in (`--engine-driver --full-round`). The
Asterion attempt used runtime commit `5b607541`; it predates the REQ/career
catalog additions. Its scripted input never establishes a human identity or
an Operations five-wave win. G6 remains partial pending human and second-map
observation, regardless of the new opt-in evaluator status.

### Follow-on catalog expansion (new source derivatives)

Two Flash lanes added real `spot-drone`/`repair-tool` REQ effects and expanded
career gear from 8 to 23 items and attachment mods from 14 to 22; the career
UI displays effect-derived stat lines and unlock levels. This edits `game/`
source files **after** the source commit named in the unchanged lock above.
Accordingly the additions are new source derivatives on this development
branch, not byte-identical evidence for the earlier locked/published runtime.
`catalog/REQ.md` records the field-equipment deviations; historical G0–G8
claims remain scoped to their original source/runtime commits.

Focused integrated checks: five REQ effect tests, 24 economy tests, 27 server
network tests, seven purchase UI tests, 101 career/gear/attachment/progression
tests and 82 additional COCS contracts passed. Web TypeScript typecheck and
the bounded production web build passed; 192 targeted UI/view contracts passed.
These are contracts/build checks, not natural match or live cross-client proof
for the new catalog items. Full-smoke neutral-policy stock and max-gear sweeps
each completed 144/144 with zero mode alarms, but the stock-vs-max tier
invariant **failed** (operator/spec/wing correlations 0.3833/0.5357/-0.5;
required ≥0.85). The reports live at
`/home/mojo/.tmp-on-disk/lattice-catalog-evidence-20260925/`. Balance acceptance,
owner visual review remain open.
An old-catalog max-gear comparison using the same stock report also failed this
invariant (`lattice-catalog-old-max-fullsmoke.json` in the same directory); the gate is
not established for either loadout set by these neutral-policy samples.

The native Godot LATTICE command panel now has a personal REQ picker. Its earlier
seven-row mirror was checked against `game/cocs-economy.mjs`; the recipient's
observed balance, buff slot, mode and owned depot gate the ordinary BUY request,
while server cards and snapshots alone settle/display outcomes. On the integrated
branch, Godot 4.5.2 import succeeds and focused headless checks report 84/84
catalog comparisons, 51/51 BUY lifecycle checks, 91/91 economy checks and
38/38 L1 checks. These are synthetic fixtures, not a live purchase on two native
clients. The older `world_commands_contract.gd` fixture was repaired by setting
its demo's selected mode to the echoed `cocs` start; its 27/27 behavioral checks
now pass. Godot still emits teardown resource-leak warnings for that synthetic
fixture, so it is not rendered acceptance evidence.

The newer post-preview derivative integrates Sentry and commander Recon Pulse
into the source-authoritative REQ catalogue, giving the generated native mirror
nine rows. `req_catalog_contract.gd` passes 197/197 and `req_purchase_contract.gd`
passes 60/60 on pinned Godot 4.5.2; economy remains 91/91 and the repaired
world command fixture 27/27 (with teardown warnings). Exact per-card source
receipts now settle non-buff PvP purchases and prevent same-item cross-settlement.
Focused REQ source tests, career unlock tests, web UI tests, TypeScript typecheck
and the production web build pass on this derivative. These fixtures do not
establish a live native purchase, rendered review, Operations five-wave win or
the stock-vs-max rank-invariance gate.
