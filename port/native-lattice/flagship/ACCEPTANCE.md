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
presentation are composed in this worktree. Their GDScript fixtures have **not**
been run before the engine slot; static review corrected source `overReason`,
pre-start null actor assignment, inactive-owned-node legality, and the distinction
between simulation actor and room peer IDs in observed order events. L4 launcher
and package options, menu metadata, and generated routes are integrated; Board
option consumption is now implemented in L5's Board, while the independent
two-client witness runner is implemented but unrun, and the direct Match experiment
covers dominance, floor, roles and time tie-break with two explicit topology/order gaps. The
source host frame omits a bot-count override for rung requests. Engine review
remains open.

| Gate | Status | Evidence |
| --- | --- | --- |
| G0 provenance | Base and pin recorded; input hashes retained in contract manifests; integrated commit hash is the isolated worktree HEAD | This document; source lock; `port/native-lattice/evidence/flagship/contracts-1790316494062383366/manifest.json` |
| G1 contracts | Partial: pre-engine Node/semantic checks passed; Godot contracts pending | `port/native-lattice/evidence/flagship/contracts-1790316494062383366/` |
| G2 import | Pending engine slot | — |
| G3 rendered | Pending engine slot and pixel review | — |
| G4 MVP-A natural rounds | Pending | — |
| G5 MVP-B rung rules/server floor | Pending | — |
| G6 MVP-C1 independent native clients | Pending | — |
| G7 packages | Pending integrated verification | — |
| G8 MVP-C2 eight human participants | Pending owner-organized play | — |

The resource marker `/home/mojo/.tmp-on-disk/cocs-lattice-engine-slot-granted`
was absent during this integration. No Godot import, rendered inspection, ordinary
round, server-seat test, two-native-client run or package build was performed.
The direct Match experiment is privileged synthetic evidence, and its retained
failed attempts are not erased or counted as natural failures. This is an
implementation checkpoint, **not** an MVP-A/B/C1/C2 acceptance declaration.

No smoke, scripted fixture, direct simulation, ACK, or generated image is a
natural full-round or human acceptance result. Natural attempts retain failures,
time-outs, cleanup, and source outcomes separately.
