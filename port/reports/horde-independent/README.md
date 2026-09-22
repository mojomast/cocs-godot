# Independent Horde acceptance — HOLD common/package integration

## Verdict

**The isolated local-authority architecture is appropriate, and the narrow gameplay claims are independently reproduced. This runtime is not yet accepted for common launcher/package integration.** Fix the transport/input/event boundary defects and product scoreboard overlap first. The public `server/room.mjs:988–989` local-only restriction is correct and must remain in place. Campaign stays deferred.

Reviewed delivery: `94690b6674e20f550990df68213376c554ec898c`.

New isolated worktree: `/tmp/opencode/horde-independent-5445295`, branch `review/horde-independent`. Integration baseline `54452957353bcaf72fe467739a1ce2dfcd6dc69a`; runtime-only cherry-pick `809ef2697463f1665f335f8602e71ecdc6d6b55a`. The independent review commit is its child, containing only this directory and the two new `godot/tests/horde-independent-product.*` helpers. The original missing Horde worktree was neither restored nor pruned. No agents, push, merge or deployment.

## Architecture and boundary review

Read delivery DISCOVERY/HANDOFF, every adapter/launcher/validator/test/smoke script and all three native scene/script sets. Cross-checked source construction, `game/input.mjs`, ordinary local `app/page.tsx:637,1066`, `game/core.mjs`, `game/singleplayer.mjs`, config, public Room rejection, inherited native input/network/lifecycle/HUD/scoreboard.

| Boundary | Finding |
|---|---|
| Authority | The adapter constructs unchanged `new Match('chatgpt','openclaw',Math.random,mapId,config)`, sends only actor 0 controls into `Match.step(1/60,{inputs:{0:…}})`, and never edits source actors, waves, health, damage or outcomes. It is a new transport, not Room. |
| Config | Three-map allowlist; fixed easy/solo ChatGPT/OpenClaw, zero rival bots. Other source profiles/loadouts/difficulty knobs are not exposed. `normalizeConfig` drops `humanCount`, but Match defaults it to one and source singleplayer enforces lone actor 0. Three lives, seven-second source intermission, default **10** waves, explicit legal **1**-wave harness preset. `timeLimit:1800` silently normalizes to **900 source seconds**, not 1800 and not guaranteed wall seconds. Source general default is 300; this is a legal longer preset. Endless/upgrades are not exposed. |
| Ordinary inputs | Source holds movement, jump/autohop, mobility and fire; ordinary local fire has a tap latch. Source resets reload/power/interact/melee/grenade presses after each simulation step. Native inherited polling sends held E/R and has no fire-tap latch. The adapter retains only the latest parsed frame, loses intermediate presses/releases, and reuses it until newer input or 250ms expiry. This is a source/input parity gap, not proved safe by held-fire combat. |
| Supported native controls | WASD, mouse look/fire, Space, Shift, Ctrl, E, R, F mobility and weapon selection are the delivered subset. Source bindings use X mobility/F melee, Q power, G grenade, Z/middle alt fire and right-mouse ADS; those additional source actions are not emitted by this native scene. Parser acceptance does not make them reachable native controls. No complete ordinary-input parity claim. |
| Seq / ACK | Only top-level safe integer `seq > received` replaces input; malformed/duplicate/lower/zero seq does not update controls/expiry. `ack=received` is assigned after a step, even if that step used expired `{}`. It is a high-water sample/receipt marker, not an independently applied count or proof a weapon/tap took effect. A received fire-on seq 1 followed by fire-off seq 2 before the next tick produced **ACK 2, shots 0**, while the latest yaw 0.2 applied. |
| Stale / capture | Adapter expires controls at 250 wall ms; black-box held-fire probe produced shots then stopped without further input. Native death, absent player, stalled snapshots, results, restart and focus-notification paths release capture and send neutral controls. E held before Verdant death remained blocked across respawn until release/fresh click. Escape pauses controls only: authority keeps running. Actual OS focus/hardware input was not exercised. |
| Scheduler | `setInterval(...,1000/60)` schedules one fixed step per callback, no elapsed accumulator. Node truncates the delay to 16ms; callbacks can run fast or slow. It is not equivalent to source local bounded wall-time accumulation or Room's elapsed accumulator. Unloaded diagnostic: 7 source seconds / 6.824627 wall seconds (**1.025697×**). Live ratios ranged 0.988816×–1.019123×. These are unchanged delivered-rate runs, not fast-forwarded tests; the launch metadata's `normalRate:true` must not be read as exact 60Hz/wall equivalence. |
| Events | `Match.emit` spreads payload over `id` and `type`. `horde-modifier` has string id `swarm`, so adapter numeric `e.id > eventId` drops it. Snapshot modifier is still correct. Repeated string traversal/upgrade IDs are incompatible with this cursor too. Deployment `husk`/`spitter` event types come from source payload overwrite, not fabricated adapter events. Source 300-event ring stays immutable. |
| Results / rounds | Numeric actor/winner 0 accepted; actual `over`, Horde `won`, winner 0 and source kill/death/life events separately checked. Results freeze stepping, in-flight results input is ignored, and start creates a new Match. Snapshot/input/ACK/event IDs reset; native clears actors/effects/Horde model and requires recapture. `ticks` and `lastInput` do not reset, so first snapshot cadence varies by old modulo; empty input prevents a held-control carry. Reconnect creates clean actor 0 state and ACK 0, with adapter round counter continuing. |
| Resource bounds | One accepted local no-Origin client, 16KiB inbound messages, source event ring 300, native snapshot history 32/event dedup 4096, recorded native rows 5500/trace 10000 and bounded harness time/logs. Tested snapshots had only 4 actors and small frames (see audits); this is not worst-wave sizing. No outgoing `bufferedAmount` cap or message-rate budget; rejected connections are upgraded then closed. Oversize input causes an **unhandled WebSocket error/process exit 1**. Process/listener cleanup passed for all live attempts, including the failed composition helper. |

## Material defects and exact proposals

1. **Input/ACK semantics:** received fire taps can disappear while ACK advances; native polling also misses taps between sends and differs from source press/hold contracts. Reproduced wire defect; native full parity remains OPEN.
2. **Event loss:** string payload IDs are filtered out. Reproduced `horde-modifier` omission on a genuine wave startup.
3. **Transport robustness:** oversize messages crash the Node process; outgoing buffering/inbound rate are not bounded at the adapter boundary. Crash reproduced in an isolated child; backlog/rate omissions are static findings, not stress-test claims.
4. **Source-clock fidelity:** one step per rounded interval is not elapsed-time scheduling. Measured and statically confirmed. No scheduler change was made for these runs.
5. **Product UI composition:** the delivery live scene omits Scoreboard. With the actual product composition, its layer-8 panel covers the layer-4 Horde lives/score and restart lines at 960×640. Direct pixel review and logged rectangles agree: Horde `[20,190,920,78]`; scoreboard `[100,224,760,301]`.
6. **Acceptance gate:** delivery CLI validator reports PASS despite a harness exit 1/resource errors, since it ignores summary exit/cleanup/stderr. The independent auditor correctly retains this run as FAIL.

[PROPOSED-FIXES.md](PROPOSED-FIXES.md) supplies exact localized unapplied replacements, including the small shared scoreboard reservation API requiring its owner's review. No hooks or fixes were applied. The fire-only minimum patch is explicitly not a full native-input solution; boundary cancellation and the remaining source actions still need a reviewed contract.

## Checks executed

All required focused gates were rerun at the integrated runtime:

| Check | Result | Evidence |
|---|---:|---|
| Semantic regeneration / source-lock verification | PASS; release gate still closed | `check-0.log` |
| Pinned Godot headless import | PASS | `check-1.log` |
| Adapter/validator Node tests | **14/14** | `check-2.log` |
| Source singleplayer + UI tests | **70/70** | `check-3.log` |
| Native Horde model/scene assertions | **15**, zero failures | `check-4.log` |
| Existing control-safety gate | **2,497**, synthetic, eight parts | `check-5.log` |
| Existing GameHUD session gate | PASS, actual scene with synthetic transitions | `check-6.log` |
| Independent black-box boundary diagnostics | Expected defects reproduced; stale release, defaults, second-client rejection, seq rejection, reconnect checked | `boundary.json`, `boundary.log`, `oversize-child.log` |
| Unmodified actual product scene, headless startup | PASS, **default 10-wave target**, real wave/enemies, child/listener cleanup | `product-smoke.json`, `product-smoke.log.gz` |

The 14 tests are largely config/validator fixtures plus Origin rejection; they do not cover the newly discovered semantics. The 70 inherited tests include source campaign cases, not a native campaign implementation. **Full aggregate/release verifier and Linux package build/acceptance were NOT run by this review or claimed by the delivery.** Baseline integration's earlier seven-scene package work is not Horde package evidence.

## Independent live attempts (all retained)

Unseeded source Match; one owned loopback PORT 0 listener per run; private Xvfb `-nolisten tcp -nolisten unix`; private XDG; pinned Godot; Dummy audio. Native scenario deadline 170 seconds, outer native-process deadline 180 seconds. No seed selection/retries, state writes, teleports, physics edits or timing changes. Second Meridian run was solely a purposeful product-composition check. No third attempt.

| Scenario / attempt | UUID | Gameplay and harness outcome | Correlated snapshots / receipts / ACK high-water |
|---|---|---|---|
| Meridian combat 1, 1280×800 | `72e82b9e-00f1-4132-b274-123f109115bb` | **PASS**: 3 kills; 1/1 wave victory; winner 0, score 94, lives 3; released restart with only actor 0, wave/score/kills reset. Harness exit 0. | 359 / 395 / 387 |
| Verdant death 1, 960×640 plus 1280×800 | `94e5f6e5-fff5-4262-be89-2c923416d2b8` | **PASS**: health 0/dead timer/lives 3→2 from real enemy damage, then health 100/living respawn. E held before death; W additionally held after death; blocked click until release, then fresh capture. Explicit Escape/resume probes. Harness exit 0. | 612 / 802 / 801 |
| Ember startup 1, 960×640 | `9a7bcaef-f882-48e3-80f0-75c25919b6b5` | **PASS startup only**: actual wave 1, 3 enemies, 0 kills, 3 lives, no results. Harness exit 0. | 147 / 349 / 346 |
| Meridian combat 2, product composition, 960×640 | `5f80cc71-f9f8-4315-a26c-223395de1d9c` | **FAIL acceptance, retained**: 3 real kills, victory and released restart did occur; `HORDE_DONE ok=true` and delivery validator PASS. Harness exit **1** due to Godot resource-leak errors. Screenshot independently exposes scoreboard overlap. | 487 / 1191 / 1179 |

Additional Verdant wire checks: first dead recipient seq **532**, living respawn **572**, recaptured living snapshot **598**; last pre-death input seq **630** held interact; **87** neutral received inputs in the post-death interval after a 150ms transition allowance. Source death event identified actor 0 with nonlocal killer, plus `singleplayer-life lives=2`. Delivery trace validator also checks more than ten neutral queued inputs until recapture. These establish engine-input behavior, not a physical user's mouse/key experience.

Meridian killed actual NPC IDs **1,2,3** with source death events `killer:0`, then source `horde-wave-cleared`, resupply, summary and mission-won. ACKs are separately correlated to recipient snapshots. A high-water ACK crossing an old input proves neither an individual application nor a kill/life/outcome.

All four attempts' wire JSONL, stdout/stderr, launch hashes/argv, summaries, validations and screenshots live in fresh `evidence/<UUID>/` directories here; original delivery evidence is byte-identical and untouched. `live-audits.json` and each `independent-audit.json` retain both PASS and FAIL. Running the independent auditor returns exit 1 deliberately because it includes the failed second attempt. No native trace has a recording-completion marker; harness completion and `HORDE_DONE` do not establish trace completion.

## Direct screenshot review

Opened fresh PNGs directly with the image reader (not merely dimension inspection):

- [Meridian results, 1280×800](evidence/72e82b9e-00f1-4132-b274-123f109115bb/gameplay-results.png): readable victory, enemy/lives/score and restart; no shared status overlap in the delivered **test composition**.
- [Meridian restart, 1280×800](evidence/72e82b9e-00f1-4132-b274-123f109115bb/gameplay-final.png): wave 0, three lives, score/frags zero, CLICK TO PLAY, clean player state.
- [Verdant respawn, 960×640](evidence/94e5f6e5-fff5-4262-be89-2c923416d2b8/gameplay-final.png) and [1280×800](evidence/94e5f6e5-fff5-4262-be89-2c923416d2b8/gameplay-alternate.png): clear wave/lives/health/ammo/controls; no HUD clipping at these sizes. Still-state image cannot independently prove held input.
- [Verdant death, 960×640](evidence/94e5f6e5-fff5-4262-be89-2c923416d2b8/gameplay-death.png): ELIMINATED, health 0/lives 2, visible close husk and distant spitter. Close-range world-sized `HUSK 30` badge is very large and intrudes behind the status panel; cosmetic sizing remains a presentation limitation. No enemy-art parity claim.
- [Ember startup, 960×640](evidence/9a7bcaef-f882-48e3-80f0-75c25919b6b5/gameplay-final.png): readable strip/status/vitals, dark world still discernible; startup only.
- [Actual composition results, 960×640](evidence/5f80cc71-f9f8-4315-a26c-223395de1d9c/gameplay-results.png): **FAIL**; scoreboard obscures Horde's second/third lines. The NPC-inclusive shared scoreboard also calls its roster “4 players”; it is not a solo Horde-specific results design.

Lead's separate review of the original final Verdant PNGs remains separate. The original delivery's image-reader limitation does not apply to these independently opened files. No human/OS focus transition, hardware aim, audible audio or motion smoothness acceptance.

## Helper limitations / provenance

- `horde-run.mjs` executes the committed launcher through a data URL, changing only its authority import resolution, fresh output directory, observed monotonic timestamps and hash inventory. The optional `--product-composition` selects the new helper scene with the same committed steering. It does not change Match, scheduler or driver behavior. Text replacements depend on the reviewed launcher bytes.
- First three runs used wrapper SHA256 `9b77682c9f7be0358c724f553e050d679c4d7ce4afa938462c9445b5ed6907e3`; those exact bytes are retained as `horde-run-initial.mjs` after the fourth-run option was added. It is an archived version, not a new successful attempt. Each launch records the hash actually used.
- `horde-independent-product.tscn` instances the actual product scene and overrides its root script with a subclass of the existing live driver; the GDScript helper only logs scoreboard geometry after screenshots. Its leak errors are **unresolved attribution**: overriding an instanced scene script may contribute detached field-created nodes. The separate actual product scene headless smoke has no errors. Do not assert those leaks are proven source/production defects or cleanly waive them. Both versions and the failed stderr are committed, with no third scenario retry.
- Delivery validator is scenario-scoped and trusts completion booleans more than a release gate should. Independent audit adds source killer/victim IDs, actual over/winner/target, recipient ACK equality, respawn wire state and received neutral controls, then checks harness exit/cleanup. Raw failed-run records remain available.
- Source lock `51289b79c627a26a381ba556b92bab71f93f3732`; source game tree `ae8015eeecec1d044cdcceaa1e5ea89d53251a90`; server tree `e54b6a715f46ff7e25db533ce9d1d5cc68942563`. `game/core.mjs` SHA256 `23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631`; adapter SHA256 `864b79258f1bce1b633283f8679584cb528a7f944dc3f4e7a581262e491588d1`.
- Godot `4.5.2.stable.official.6ce3de25a`, path `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64`, binary SHA256 `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`. Node `v22.23.1`, installed/locked `ws 8.21.3`. Primary `node_modules` was used read-only through an owned symlink; no install or dependency edit.
- `provenance.json` records full source/runtime/helper/generated-resource SHA256 inventories, PNG hashes/dimensions, runtime trees, and post-run closed endpoint/absent PID checks. Source and original delivery directory diffs are empty.

## Concrete common/package requirements (not applied)

1. `tools/godot-dev/launch_options.mjs` and `tools/godot-package/options.mjs`: add a strict Horde experience for Meridian/Verdant/Ember and `res://horde/demo.tscn`, with default ten waves and an explicit legal 1..30 wave option. Reject foreign maps/modes, joining/public-room routes, unsupported source knobs and campaign. Preserve existing experience options.
2. `tools/godot-dev/launch.mjs:14` and packaged `run.mjs:15,21` currently always construct `createGameServer`. Select a reviewed **local-only** Horde authority factory for this route. Package readiness currently requires the public server's JSON health response (`run.mjs:42–44`); delivery authority returns plain text, so explicit factory-specific readiness is necessary. Maintain loopback PORT 0, owned lifecycle, error/signal termination, private XDG and cleanup; do not weaken Room or reuse a public room.
3. `tools/godot-package/discover.mjs`/`build.py:96–109,183–184`: include both source-runtime import closure and the reviewed adapter. The current closure only roots the public game server, and the builder verifies every closure module against locked source; the **new adapter is not in that source commit**. Keep immutable source verification strict, and separately pin/hash port-owned adapter modules in the package manifest rather than relaxing source verification globally. Copy the adapter at its expected relative path so its `../../game` imports resolve. Include locked `ws`, license/integrity and supported Node prerequisite.
4. Native package staging already copies tracked non-test native files (`build.py:100`), so committed Horde scripts can stage, but scene routing/resource closure still needs explicit verification. Include shared session/UI/scoreboard/combat/audio and generated three-map resources; exclude all test steering, independent helpers and evidence from PCK/runtime. Reimport/export with pinned engine/template; verify resource and dynamic-import closure from an extracted artifact outside the checkout.
5. Fix product scoreboard composition/layout and validate actual product scene at both sizes, both held/released Tab and results/restart. Do not rely on the delivery live scene that omits Scoreboard. Resolve the independent composition-helper exit leak before treating that helper as a clean gate.
6. Make acceptance require harness exit/cleanup plus independent gameplay-state predicates and recipient correlation. Add adapter tests for taps/holds/cancel/expiry/seq, malformed/oversize frames, slow-reader bounds, repeat string-ID events, round reset and elapsed clock. Then rerun focused gates, aggregate, clean package build, and packaged startup/normal-input play/cleanup. None of these future common/package hooks was applied here.

**Still OPEN:** full ten-wave completion, later waves/boss combat, natural defeat, upgrade selection, endless, complete source input/loadout parity, worst-wave resource use, human input/OS focus/audio, packaged Linux gameplay and full aggregate acceptance. A one-wave victory proves none of those.

## Exact commands and cleanup

All commands ran from this new worktree unless explicitly prefixed with `git -C`. Initial isolation:

```sh
git worktree add -b review/horde-independent /tmp/opencode/horde-independent-5445295 5445295
git -C /tmp/opencode/horde-independent-5445295 cherry-pick 94690b6674e20f550990df68213376c554ec898c
ln -s /home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules node_modules
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
export TMPDIR=/tmp/opencode PORT=0
python3 -B port/reports/horde-independent/horde-checks.py
node port/reports/horde-independent/horde-run.mjs --map=meridian-exchange --scenario=combat --resolution=1280x800
node port/reports/horde-independent/horde-run.mjs --map=verdant-reliquary --scenario=death --resolution=960x640
node port/reports/horde-independent/horde-run.mjs --map=ember-crucible --scenario=startup --resolution=960x640
node port/reports/horde-independent/horde-boundary.mjs > port/reports/horde-independent/boundary.log 2>&1
node port/reports/horde-independent/horde-run.mjs --map=meridian-exchange --scenario=combat --resolution=960x640 --product-composition
node port/reports/horde-independent/horde-product-smoke.mjs
node port/reports/horde-independent/horde-audit-evidence.mjs > port/reports/horde-independent/live-audit.log 2>&1
python3 -B port/reports/horde-independent/horde-provenance.py
```

The checks helper executes the exact five delivery verification commands plus semantic export/import (listed with argv and exit in `checks.json`) into new report logs. It isolates all four XDG directories. Each new UUID was additionally passed individually to `node port/native-horde/validate.mjs port/reports/horde-independent/evidence/<UUID>`; only new independent evidence files were written. Pinned native argv/endpoint/scene/screenshot arguments are in every launch JSON. Xvfb command is the committed launcher's `Xvfb -displayfd 3 -screen 0 1280x800x24 -nolisten tcp -nolisten unix`. The product-smoke raw log was archived byte-for-byte with `gzip -n -k port/reports/horde-independent/product-smoke.log`, then its redundant plaintext copy removed to avoid a generated-log trailing-blank-line diff warning.

Every automated run reaped native/Xvfb, independently checked PID absence, closed listener/sockets and removed private XDG. `provenance.json` separately reconnect-tested all four former ports and rechecked all eight PIDs absent. Product-smoke child was reaped/absent, listener closed, XDG removed. Boundary diagnostics closed their owned listener/client; the oversize child exited 1 and its OS resources closed with the process. No shared services were touched. The dependency symlink and this worktree's generated import/cache output were removed after recording provenance; the committed source/content and all evidence remain. Final `git diff --check` and scope checks completed before the independent commit.
