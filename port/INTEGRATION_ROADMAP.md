# Native product consolidation and continued source migration

Research baseline: **2026-09-28, `794e5b99`**, branch
`port/lattice-flagship-next`, repository `mojomast/cocs-godot` (remote `godot`).
Upstream source repository is `mojomast/cocs` (remote `origin`).

## Decision in brief

**2026-10-01 broad migration checkpoint:** runtime `1c1f6e34` is published with
targeting, campaign-variety, animation and edge/effects improvements; both
platforms passed 67 package cases. The owner now requests four parallel Astra
lanes to improve the broader game and resume Three.js feature migration. See
[the active workstream](next-port/WORKSTREAM.md) for current ownership, parity
audits, selected feature implementations and engine grants. The older capability
inventory below is historical and must not be used to label current features missing.

**2026-09-30 campaign checkpoint:** the owner authorized four substantially larger
connected biome levels, a varied robot roster, and campaign story/pacing design.
Flash research preceded the Astra implementation lanes. **The Quiet Relay** is
now integrated on `feature/relay-campaign`; its active verification/export work
is recorded in [the campaign workstream](campaign/WORKSTREAM.md). The older
campaign-deferral statements below describe the September 28 baseline.

**2026-09-29 checkpoint:** all three authorized follow-up streams are integrated
at `156cd370`: Uplink/Holdout/Assault, five-kind vehicles/crew, and audiovisual
presentation. The full **273-gate** native suite and **228 server tests** pass;
lint has zero errors. Consolidated Windows/Linux exports use that same revision;
Linux extracted acceptance and actual Windows headless smoke checks passed.
The consolidated prerelease is published with two remaining hosted rendered
fixture failures documented (271/273 hosted gates); general CI passed.
See [the expansion record](THREE_STREAM_EXPANSION_2026-09-29.md) for exact evidence
and final artifact acceptance. The historical sequencing below is retained.

Make the next milestone **one coherent native build**, then resume source-feature
migration through complete player journeys. Most earlier native feature lanes are
already integrated. The immediate work is to consolidate their entry points,
lifecycle, verification and release identity, and deliberately integrate the
outstanding Cinderwake/Nacre branch.

Use the current branch as the consolidation baseline. Promote the verified result
through the Godot repository's mainline and ship one Windows/Linux release with a
clear feature matrix. Keep the source Node simulation authoritative. Improve the
native presentation and interaction design without duplicating simulation rules.

This document is a **proposed implementation backlog**, not evidence that the
milestones below are complete. It supersedes scattered handoffs for *sequencing*;
the individual evidence records retain their original scope and results.

### Implementation progress — 2026-09-28

- **NATIVE-01 implemented:** integration-branch CI trigger and explicit frozen
  derivative propagation through exports, active development launchers and
  evidence runners. Original-source defaults remain strict. The inherited
  gallery lint error is fixed.
- **NATIVE-02 implemented and locally verified:** the canonical
  runner now inventories 199 gates including REQ, tactical and flagship coverage.
  Reports identify the tested port/source/derivative and distinguish executed
  from unrun checks. Gate registration, preflight-report and source-selection
  contracts cover the new plumbing.
  The final Linux aggregate passed **199/199** at `6b782f2b`, with zero unrun
  gates; full repository lint also passed. Hosted native CI reproduced all
  **199/199** at `508f2e03`, and general CI also passed there. Owner-run acceptance
  remains separate from these automated results.
- **NATIVE-03-A implemented:** the existing process-based menu remembers the
  selected activity and validated per-activity options using a versioned local
  preference file. Headless menu contracts pass 776 checks, including repeated
  menu lifetimes and corrupt preference recovery.
- **NATIVE-03-B implemented:** shared persistent audio/display/mouse/interface
  settings, Home Settings and F12/Back/Leave navigation, stable preference paths
  across disposable route processes, and generated player-facing route
  capabilities. Home now reflows for compact windows and large interface scales.
  Source-driven scripted evidence covers three Home/combat/LATTICE/sports cycles
  and external-guest leave while the host continues running. See the
  [shared shell guide](native-shell/README.md) for exact controls and scope.
- **NATIVE-04 compact layout increment implemented:** modal command deck above
  combat diagnostics, wrapped selected-objective facts, scrollable and responsive
  objective/REQ pages, and first-open live-layout recovery. Broader cross-mode
  theme unification and human readability/feel acceptance remain open.
- **NATIVE-05 authority integration is implemented:** the combined LATTICE/Horde
  derivative supplies Cinderwake stages while preserving ordinary Horde and
  Nacre. Source-correlated motion checks and the six-route journey passed.
- **Pre-release expansion implemented and locally verified:** persistent Career,
  source-confirmed Arsenal actions and room discovery/chat. The final aggregate
  passed **218/218**, server tests **228/228**, and lint with zero errors at
  `0d8bd78c`. See [the expansion record](NATIVE_EXPANSION_2026-09-28.md) for exact
  revisions, failed attempts, native journeys and retained evidence.
- **Reconnect / Career follow-up implemented:** explicit source-compatible Retry
  and Leave, round-result/XP summaries and recent server history with owned-server
  persistence. Integrated source/native journeys passed, followed by **226/226
  aggregate gates**, **228/228 server tests** and lint with zero errors at
   `5c519b5d`. See [the follow-up record](RECONNECT_CAREER_BATCH_2026-09-28.md).
- **Arsenal presentation integrated:** source-derived first-person finishes and
  source-confirmed saved-loadout summaries in Career and connected match setup.
  Integrated **237/237 native gates, zero unrun**, passed at `22892e79`, including
  source/native journeys and compact-layout checks. Server tests passed
  **228/228**, and lint passed with **zero errors**. See
  [the presentation record](ARSENAL_PRESENTATION_BATCH_2026-09-28.md).
- **Hosted confirmation complete:** general CI and native **237/237 gates, zero
  unrun**, passed at `b6eec0cf`. This includes the Horde capture/input-order repair;
  the prior failed run at `683ead49` remains preserved. Exact run URLs, artifact
  and report hashes are recorded in the presentation record.
- **NATIVE-05–06 acceptance remains open:** natural staged-campaign completion,
  extracted-package consolidation acceptance and the
  unified release. The 2026-09-29 request authorizes consolidated builds after the
  three additional feature streams and current player-flow polish are complete.

The shell increment passed **203/203 local aggregate gates, zero unrun**, at
`a9dbeaab`. The subsequent ESM-only journey-wrapper change was checked by
rerunning both affected source-backed journeys and full lint. See the
[shell verification record](native-shell/EVIDENCE_2026-09-28.md) for commit
identity, evidence, repaired failures and public screenshots.

The research findings below describe the original baseline. Implementation
results and remaining acceptance gaps are recorded in
[consolidation evidence](native-ci/evidence/CONSOLIDATION_2026-09-28.md).

## 1. What is already together, and what is genuinely separate

Four parallel DeepSeek V4.1 Flash research agents examined runtime/product
architecture, git/release lineage, source/native parity, and external practices.
The lead checked critical findings against code, git, hosted CI logs and a
read-only source-verification probe. No engine/build/full acceptance run was
performed for this research.

### Integration facts

| Area | Finding at the research baseline | Implication |
| --- | --- | --- |
| Existing native work | `godot/main` (`77081412`) and `release/playable-2026-09-23` are ancestors of this branch. Many mode, graphics, weapon, CI and usability lanes are patch-equivalent to changes already present. | Do not merge every old worktree again. Review genuinely unmatched changes with ancestry **and** patch equivalence. |
| Cinderwake/Nacre | `port/cinderwake-drydock` (`91fa1a39`) has 17 unmatched patches against this branch. `port/godot-destinations` is its ancestor. | This is the substantial outstanding native integration stream. |
| Cinderwake authority | Its source lock selects `48264858` on `feature/cinderwake-horde-stages`; current LATTICE selects `515daf07` plus derivative `fa6dda2d`. | Integrating just scenes cannot supply the required source stage controller. Resolve a combined authority baseline first. |
| Current product entry | The packaged launcher already returns to the menu after a route exits, but spawns a new Godot process per menu/route. Editor boot still opens the viewer. | There is an existing product shell to evolve; this is not a greenfield application. |
| Release identity | The LATTICE playable package, Cinderwake preview, general mode-parity release and gallery describe different snapshots. | Publish a consolidated build with explicit contents instead of asking players to choose a development lane. |

Code anchors: `tools/godot-package/run.mjs:120-203`,
`godot/project.godot:3-10`, `godot/ui/main_menu.gd:1-10`,
`godot/ui/match_setup.gd:16-56`.

Important correction: the LATTICE derivative manifest is **absent** from the
Cinderwake branch; a tip-to-tip diff shows it as deleted. That does not establish
that Cinderwake intentionally deleted it, or that a normal three-way merge would
delete it. The substantive incompatibility is the selected source baseline.

### Capability inventory

"Integrated" means code is present, not that every human acceptance gate passed.

| Family | Native state | Next consolidation or migration work |
| --- | --- | --- |
| Infantry combat | DM/TDM/Instagib/Rockets, weapon selection, health/ammo HUD, scoreboard, movement smoothing, feedback and loadout selection exist. | Common launch/setup/return journey; persistent preferences; hardware feel review. |
| Zones and objectives | KOTH/Domination, CTF and Payload have dedicated native routes. | Shared lifecycle/navigation, then broader contested/multiplayer acceptance. |
| Arms Race | Source-controlled progression and native route integrated. | Include in the common product flow and current release verification. |
| Horde | Source-backed Horde and in-run upgrade selection exist. Cinderwake/Nacre additions are on the separate branch. | Reconcile authority and routes; preserve ordinary Horde while integrating staged content. Natural ten-wave/champion acceptance stays open. |
| LATTICE | World and command-board routes, tactical HUD/markers, nine-choice personal REQ, team economy and receipt lifecycle exist. | Register newer contracts centrally; native purchase witness; shared UI and navigation. |
| Vehicles/sports | Puma driving, race/soccer and bounded combined-arms support exist. Other chassis have partial presentation/exit support. | Retain their distinct cameras and controls; extend source-authoritative chassis support later. |
| Multiplayer | Host/join, lobby, spectator and fresh-join recovery behavior exist. | Shared session flow; later chat, room discovery and source-compatible reconnect. Voice/ranked are separate features. |
| Career/Arsenal | Source/web progression and expanded catalog exist. Native operator/harness selection and REQ are not a full persistent career UI. | Add source-backed career projection and equip requests after the shell is ready. |
| Settings | No general native persistent settings surface was identified. | Shared audio/display/input/UI-scale preferences, carried across routes and launches. |
| Graphics/audio | Nine destination environments, source-derived weapons/operators, Moth materials, FX and procedural audio are integrated; several previews remain opt-in. | Consistent player-facing style, diagnostics placement, readability and audio controls. Dynamic weather/music/announcer depth remain migration candidates. |
| Source-only modes | Assault, Arsenal, Juggernaut, Team Elimination, VIP Escort, Holdout and Uplink lack equivalent native mode routes. | Port one complete mode journey at a time. Campaign remains owner-deferred. |

Source/native anchors: `game/config.mjs`, `godot/ui/routes.json`,
`godot/ui/match_setup.gd`, `godot/net/client.gd:180-271`,
`godot/horde/`, `godot/combined_arms/fleet.gd`,
`godot/lattice/req_catalog.gd`, and `port/native-lattice/flagship/catalog/CAREER.md`.

## 2. The first engineering pass: make the baseline trustworthy

Do this before promoting the branch or issuing another consolidated package.

### NATIVE-01 — Current branch CI and source identity

- Native CI triggers on pushes to `main`, PRs and manual dispatch, not pushes to
  `port/lattice-flagship-next` (`.github/workflows/godot-native.yml:3-7`). Add the
  integration branch or use its PR as the required native CI path.
- Configure the **explicit frozen derivative** for semantic export and dependent
  gates. The workflow currently runs export without `COCS_SOURCE_DERIVATIVE`.
  A read-only `verifySource` probe rejected the default with
  `Locked source differs from working tree`, and accepted the checked-in
  derivative. Merely changing the trigger will not make this branch green.
- Preserve exact inventory/byte/ancestry validation. Never weaken the source
  verifier to make an integration build pass.
- Fix the specific inherited lint error at
  `port/mode-parity-gallery/capture.mjs:52` (`no-this-alias`), preserving the
  instrumentation's behavior. Avoid a broad lint exclusion.

Evidence: [failed CI run 36466983794](https://github.com/mojomast/cocs-godot/actions/runs/36466983794),
`tools/godot-export/semantic.mjs:46-73`,
`port/contracts/lattice-catalog-derivative.json`,
`tools/godot-package/build.py`.

**Done:** a fresh checkout of the actual integration commit passes the corrected
source checks and applicable CI jobs; failures and unexecuted acceptance remain
visible in its report.

### NATIVE-02 — One current verification index

- Register the newer REQ catalog/purchase and tactical HUD contracts, plus
  appropriate flagship contracts, in the product verification entry point.
- **Preserve existing coverage:** `world_commands_contract.gd` is already
  registered at `tools/godot-dev/verify.py:218`. It is not a missing gate.
- The separate flagship runner's engine discovery only selects
  `flagship_l*.gd` (`port/tools/native_lattice_flagship/verify.py:113`), so it does
  not automatically cover new tactical/REQ contracts either.
- Distinguish fast contracts, rendered/input checks, live-source scenarios and
  owner-run checks. A top-level manifest may dispatch these tiers; it must not
  count a skipped tier as passed.
- Generate current summaries from the actual run. The script currently lists
  183 commands; the committed report has 167 gate records at the older
  `51289b79` source pin. Different historical counts describe different runs,
  not necessarily regressions. Do not edit the old report into a new pass.

**Done:** one discoverable command/report lists the current source pin, derivative,
port commit, registered gates, actual executions and remaining manual work.

## 3. A coherent player experience

### NATIVE-03 — Shared product shell, introduced incrementally

Proposed player navigation:

```text
Home
  Play -> activity/mode -> map + loadout -> host/join -> match
       -> results -> rematch / return Home
  Arsenal / Career (when source-backed)
  Settings
  Extras (labs, visual previews, diagnostics)
```

Keep labs accessible, but group player choices by activity rather than technical
implementation ("Play", "Native", and "Modes" currently expose that distinction).
Use a shared theme and predictable Back/Leave behavior. Preserve direct CLI
routes for tests and development.

Consolidate route/map/mode/authority capability metadata behind the existing
route generator (`tools/godot-package/gen_routes.mjs`). Keep `routes.json`
generated and make dev launch, packaged launch and setup consume the same
capabilities instead of extending separate hardcoded lists for every new mode.

Recommended ownership, with names illustrative rather than an imposed rewrite:

```text
Node supervisor: owns local authority process/server lifecycle
Godot AppRoot: owns navigation, common UI and local preferences
  SessionCoordinator: explicit setup/connect/live/results/leave/error states
  ActiveExperience: existing infantry/LATTICE/Horde/sports adapter + scene
  SharedUI: navigation, settings, error treatment, common HUD styling
Source JS runtime: owns simulation, match outcomes, wallets and progression
```

Start by making the existing supervisor/menu journey consistent and preserving
preferences across its current process boundaries. Then migrate one route at a
time into an in-process shell if that measurably improves transitions. An
in-process shell needs an explicit supervisor start/stop/endpoint handoff; merely
changing `run/main_scene` will not start the correct authority.

Use small lifecycle interfaces around existing scenes. Do not force sports,
the tactical board and infantry into one giant inheritance hierarchy or one
universal wire decoder. Their capability/privacy boundaries are useful. Extract
shared cleanup and input ownership only where actual duplication warrants it.

Local settings may use a versioned `user://` store. Remembered loadout choices
are **requests**, revalidated by the source. Career balances, ownership and
unlocks must come from the source's identity/progression flow; a local config
file is not an authority for them.

**Done:** the same installed build supports
`Home -> combat -> results/leave -> Home -> LATTICE -> leave -> Home`, repeated
three times, with retained preferences, correct pointer/focus recovery, no stale
HUD or input, and no abandoned owned server/socket. After Horde integration,
repeat with Horde in the same journey. Test both host ownership and guest leave.

### NATIVE-04 — Consistent play-facing UI

- Apply a shared layout/theme vocabulary across menu, setup, HUD, deck and results.
- Move diagnostic controls out of the ordinary play layer. In the published
  command-deck capture, the combat-effects diagnostic label overlaps the header.
- Make objective rows readable without losing legality/supply meaning; the
  current 1280x800 capture truncates the rows.
- Translate source identifiers into useful player copy (for example, a friendly
  wave-phase label), while preserving unknown/missing-state behavior.
- Keep the source-authentic distinctions between request queued, accepted,
  settled and refused. Explain actions in player language; reserve detailed
  receipt diagnostics for the appropriate view.
- Check keyboard navigation, focus return, small-window reflow and UI scaling.

These are screenshot observations and design targets, not a fresh live usability
test. Source privacy, objective legality and purchase outcomes remain unchanged.

**Done:** reviewed captures and normal input-driven journeys at compact and
standard resolutions; no overlapping play/debug layers or inaccessible essential
text. Owner review covers readability, audio and input feel on actual hardware.

## 4. Bring the outstanding Horde work into this product

### NATIVE-05 — Cinderwake/Nacre source and native integration

**Implementation update, 2026-09-28:** combined source
`61fca35c65488502b794900cde0a5247bfb123bf` preserves the LATTICE derivative and
adds the reviewed Horde stage controller. The explicit derivative inventories
all ten changed runtime files while retaining the original source lock. Native
Cinderwake (Preview) is integrated alongside ordinary Horde and Nacre. An
18-session source-backed Home journey passed across six route/map choices;
package acceptance and natural campaign completion remain separate gates.

1. Inventory the unmatched patches against the current integration tip. Treat
   Nacre and movement/kick work in `port/godot-destinations` as dependencies of
   the Cinderwake branch, not a second blind merge.
2. Reconcile the Cinderwake source stage-controller changes with the LATTICE
   runtime/catalog changes on a reviewed source line. Preferred steady state:
   an upstream source commit containing both. If using a reviewed derivative
   temporarily, explicitly record the combined delta and its exact ancestry and
   hashes; check whether the current inventory format can represent it.
3. Update the source pin/selection/derivative deliberately and regenerate
   affected mirrors and semantic data. Preserve REQ, receipts, recon privacy,
   source movement and ordinary Horde semantics.
4. Bring native maps, stage presentation, controls, routes and tests onto that
   resolved baseline in reviewable changes. Keep new content preview-labelled
   until its own acceptance passes.
5. Verify ordinary Horde **and** Cinderwake **and** LATTICE using the same package
   source, including cleanup/restart and the existing purchase contracts.

**Done:** one package contains both the LATTICE catalog/HUD and the intended Horde
additions; source identity is unambiguous. Natural ten-wave/champion completion
remains separately tracked until observed. No rule change is inferred from a
visual port or a forced fixture result.

## 5. Ship a consolidation checkpoint

### NATIVE-06 — One release of record

**Build authorized, 2026-09-29:** Career continuity, source-confirmed Arsenal
equipment, room discovery/chat, reconnect and native finishes/loadout presentation
are integrated and verified. The user now requests all three additional streams
(Uplink/Assault/Holdout, remaining source vehicle coverage, and audiovisual
presentation), followed by consolidated Windows/Linux builds. Player-flow polish
is being integrated first. See the
[three-stream plan](THREE_STREAM_EXPANSION_2026-09-29.md),
[player-flow record](PLAYER_FLOW_POLISH_2026-09-29.md) and
[presentation record](ARSENAL_PRESENTATION_BATCH_2026-09-28.md). Resource-heavy
verification and packaging remain serial.

**Implementation update, 2026-09-28:** extracted-artifact validation now binds
source identity, launcher bytes and the re-derived runtime closure to the
manifest's recorded commits. Its 35 fixture checks pass, including advanced/dirty
ambient checkouts and artifact tampering. Building, exercising and publishing
the consolidated artifacts remain release gates.

- Run resource-heavy imports, rendering, builds and suites **serially**.
- Build Linux and Windows from one reviewed port commit and resolved authority
  identity using the pinned Godot 4.5.2 toolchain. Preserve package file hashes,
  provenance and source-derivative metadata.
- Exercise extracted-package startup and the multi-mode player journey, not
  only editor scenes. Include a two-native-client source-authority round for
  the multiplayer slice. Verify the local-server vs external-host cleanup rules.
- Modernize the older `tools/godot-package/verify.py` inventory assumptions for
  the consolidated package. Bind any derivative verification to the package
  manifest's recorded commit/hash, not an ambient development environment
  selection. Its original strict source check remains in place until that work.
- Attach one concise feature/evidence matrix and stable screenshots to the
  playable release. Keep a direct README download link to that release.
- After the corrected native CI and release checks pass, promote through a PR
  to `godot/main` (ancestry permits a fast-forward at the research baseline).
  Recheck remote state first. Do not rewrite existing release tags.

The old gallery is a valid screenshot receipt; its tag need not move to follow a
documentation commit. A gallery release must not become the only prominent link
for users looking for a playable download.

**Done:** a new tester can identify one download, launch it, select the supported
activities, return safely and understand which content is preview. Linux checks,
Windows execution, scripted evidence and human acceptance have distinct statuses.
Eight-human acceptance and full natural campaign-length runs do not block every
small integration change; they do gate the claims that depend on them.

## 6. Resume Three.js feature migration through this foundation

Recommended order after the consolidation checkpoint:

The user requested concurrent slices. Home catalog browsing and **F12 Settings →
Career / Arsenal**, persistent identity, source-validated equipment, results and
recent server history are integrated. Profiles remain unknown when disconnected;
per-mode totals do not invent a personal match-history API. Room discovery, chat
and explicit source-compatible reconnect are also integrated. The current
presentation batch adds visible first-person finishes and saved-loadout summaries.

1. **Native Career/Arsenal:** read-only source profile/history first, then
   source-validated equip/unlock interactions and results-to-career continuity.
   Resolve the existing stock/max rank-invariance failure before claiming gear
   balance acceptance; a faithful read-only UI need not wait for a balance claim.
2. **Multiplayer quality of life:** room discovery and text chat, followed by
   source-compatible reconnect. Review identity/session-token handling before
   persisting a connection. Voice/ranked remain separately scoped.
3. **Additional source modes or vehicles:** select one complete loop, including
   setup, mode-specific HUD, authority events, results and replay/restart checks.
4. **Presentation depth:** music/announcer/weather and reviewed model candidates,
   with settings and performance budgets already available from the shell.

For every feature record:

```text
Feature and player journey
Source commit + exact authoritative modules/messages
Native capability and supported map/mode combinations
Integration status | source parity | packaged evidence | human review
Generator/exporter or protocol adapter; explicit unknown/error behavior
Tests registered in the product runner, including negative/privacy cases
Source/port/artifact hashes and evidence links
Remaining differences, owner acceptance and next migration step
```

Reuse the three working seams already in this repository: generated fail-closed
catalog mirrors (`port/tools/native_lattice_req_catalog/`), source-construction
asset exports (`port/native-source-operators/`), and read-only recipient/mode
projection adapters (`godot/zone_modes/adapter.gd`, `godot/lattice/`).

Develop with short-lived branches from the current integrated baseline. Parallel
agents can discover independent concerns; land dependent implementation changes
sequentially. Every new feature should extend the common product flow, rather
than establishing another permanent alternate application.

Upstream `origin/main` has also advanced beyond the current source pin. Keep an
explicit source-intake queue for those changes (including projectile tuning and
material updates), assess their native impact, and advance the pin with matching
contracts/exports. An upstream frontend change is not automatically a missing
native feature, and an upstream simulation change needs parity review.

## 7. Verification starting points for implementation

These commands are entry points for the next engineering pass, **not checks run
by this research**. Inspect relevant runners before execution; preserve their
resource/engine-slot ownership requirements.

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export COCS_SOURCE_DERIVATIVE="$PWD/port/contracts/lattice-catalog-derivative.json"

# Focused current contracts, run serially as applicable:
node --test tools/godot-package/route_parity.test.mjs tools/godot-dev/launch_options.test.mjs tools/godot-package/options.test.mjs
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/req_catalog_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/req_purchase_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_commands_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lattice/world_tactical_contract.gd

# Aggregate after fixing gate registration and derivative propagation:
python3 tools/godot-dev/verify.py
git diff --check
git status --short
```

Packaging authority: `tools/godot-package/build.py` (current derivative builds
require its explicit `--source-derivative` option). Follow its documented
platform/toolchain options and the actual current source identity; do not reuse
the old derivative path after changing the authoritative baseline without review.

Preserve unrelated untracked evidence and UID files. Keep the external Mothbake
credential out of logs, documentation and commits.

## 8. Research basis and deliberate limits

These recommendations apply established practices to this repository; the
references do not prescribe this project's exact architecture.

- [Godot 4.5 scene organization](https://docs.godotengine.org/en/4.5/tutorials/best_practices/scene_organization.html):
  explicit entry point, focused scenes, injected dependencies and lifecycle-based
  ownership. Supports a small app shell and mode adapters, not mandatory global
  singletons or one inheritance tree for all modes.
- [Godot 4.5 autoload guidance](https://docs.godotengine.org/en/4.5/tutorials/best_practices/autoloads_versus_internal_nodes.html):
  use globally persistent services deliberately. Keep direct route tests viable.
- [Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)
  and [Parallel Change](https://martinfowler.com/bliki/ParallelChange.html):
  introduce an interface, migrate consumers incrementally, then retire temporary
  paths. Supports wrapping the current supervisor/session behavior first.
- [Godot 4.5 WebSockets](https://docs.godotengine.org/en/4.5/tutorials/networking/websocket.html):
  use the existing custom-server boundary. Transport replacement, engine upgrades
  and a simulation rewrite are separate measured decisions, not consolidation
  prerequisites.
- [Godot 4.5 command-line tools](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html):
  keep the existing headless-script/export approach and pinned toolchain. No new
  test framework is required to register missing contracts.
- [Xbox Accessibility Guideline 112](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112)
  and [101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101):
  consistent navigation/focus/back actions, readable text and reflow when scaled.
  Supports shared settings/theme and measurable layout review.

Existing manual boundaries remain: native Windows execution, hardware feel,
live native REQ settlement, natural Operations five-wave victory, Cinderwake
ten-wave/champion completion and the owner-scheduled eight-human session.
The failed stock/max gear correlations remain **0.3833 / 0.5357 / -0.5** versus
the **>=0.85** target. Historical asset provenance questions remain in their
existing audit; consolidation does not resolve them by implication.

## Current review links

- [Playable tactical HUD build](https://github.com/mojomast/cocs-godot/releases/tag/lattice-tactical-hud-v2-2026-09-26)
  — packaged from `1736d0f2`, not a consolidated Cinderwake build.
- [Public native-world gallery](https://github.com/mojomast/cocs-godot/releases/tag/lattice-live-gallery-2026-09-28)
  — source-driven matches with scripted controls. All five published PNG hashes
  were rechecked against its public manifest during this research.
- [Cinderwake preview](https://github.com/mojomast/cocs-godot/releases/tag/cinderwake-drydock-preview-2026-09-25)
  — separate branch snapshot, not yet part of the current LATTICE line.
