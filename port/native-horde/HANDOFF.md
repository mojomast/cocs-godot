# Native Horde delivery

Branch: subagent/native-horde
Worktree: /tmp/opencode/cocs-native-horde
Exact baseline: 3645efdab87870d1dea1548729e2269fbc9ba8f1
Pinned engine: 4.5.2.stable.official.6ce3de25a
Source/engine/code hashes and exact native argv: each evidence/*/launch.json.

## Scope / important architectural discovery

Implemented an isolated native Horde scene for Meridian Exchange, Verdant Reliquary and Ember Crucible. Node's unmodified Match owns all waves, actors, damage, regeneration, lives, scoring and results. The native adapter owns only input, presentation and received-state HUD. Defaults: easy, ten waves; normalized source clock limit 900 seconds. --waves=1 is a legal, explicitly bounded test preset, NOT ten-wave acceptance.

CRITICAL: server/room.mjs:988–989 forbids network Horde as local-only. This delivery does NOT remove that restriction or claim public-room compatibility. port/native-horde/authority.mjs is an explicitly local-only, one-client transport around unchanged Match, using the existing input parser and fixed 1/60 steps at 1000/60 wall milliseconds. It binds loopback through the owned launcher, rejects browser Origin and additional clients, and never edits source actors/health/waves. It is new adapter code requiring integration review, not the existing production Room server. It uses the existing ws dependency.

No shared runtime, source, contracts, dependency lock, common launcher, package pipeline, campaign or other lane was edited. Generated semantic resources were rebuilt but not changed. Campaign tests happen to be in the inherited source suite; no campaign implementation was undertaken.

DISCOVERY.md contains the completed read-only audits and implementation plan. CLI delegation failed authentication/model checks; this work was implemented directly, not by a successful background subagent.

## Delivered files and APIs

- godot/horde/demo.tscn + demo.gd: subclass of existing world/session.gd, independent initialization, host configuration, inherited combat/audio, GameHUD/scoreboard composition, fresh-input capture gate and results/restart cleanup. Scene args: --endpoint=ws://127.0.0.1:PORT, --map=one-of-three, --waves=1..30; optional --horde-evidence / --native-trace.
- godot/horde/model.gd: received-state-only model, clear/apply(snapshot, stale); no client-side wave timers. Missing/stale state clears the Horde model. Numeric JSON floats/actor zero and winner zero handled. Boss details shown only when actually projected.
- Existing presentation retains exactly received actor IDs and removes absent actors. Each received NPC visual gets an npcType/health label. This is economical native presentation, not enemy art parity. Local interpolation disabled for direct snapshot-position evidence; no prediction.
- port/native-horde/authority.mjs: createAuthority({observe}), validateConfig; listener/close owned by launcher. In-flight inputs at results ignored without reopening simulation.
- port/native-horde/run.mjs: manual launcher and bounded evidence harness. Adapted cleanup/evidence patterns are attributed to native-objective-completion/run.mjs. Manual mode uses real audio and no evidence recording; automated mode uses Dummy audio/private Xvfb.
- validate.mjs: recipient sequence/state/visible HUD/actor position checks, genuine kill+victory+restart requirements, held-input death probe validation. Its PASS is scenario-scoped, not full release acceptance.
- test.mjs, verify.py, godot/tests/horde/test.gd, live.gd/.tscn: offline tests and test-only event steering. Steering never ships in the product scene, invokes only ordinary InputEventKey/MouseMotion/MouseButton through Input.parse_input_event, and does not mutate simulation state.
- scene-smoke.mjs: actual product scene headless startup, default ten-wave config; no combat claim.

Optional source upgrade offers are displayed as unavailable; selection is explicitly unsupported. Public protocol has no Horde upgrade command and source progression does not wait for a choice. Endless UI and advanced upgrades remain unsupported. No shared protocol extension was invented.

## Executed commands

From this worktree, with existing primary node_modules temporarily linked read-only:

    export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
    export TMPDIR=/tmp/opencode PORT=0
    node tools/godot-export/semantic.mjs
    "$GODOT_BIN" --headless --path godot --editor --import
    python3 -B port/native-horde/verify.py
    node port/native-horde/run.mjs --map=meridian-exchange --scenario=combat
    node port/native-horde/run.mjs --map=verdant-reliquary --scenario=death --resolution=960x640
    node port/native-horde/run.mjs --map=ember-crucible --scenario=startup --resolution=960x640
    node port/native-horde/validate.mjs port/native-horde/evidence/4d1edc81-ddb1-4e4d-9cfb-e3ebad8a99f0
    node port/native-horde/validate.mjs port/native-horde/evidence/5771ef43-a3d5-4bcb-b63b-7759fcb47824
    node port/native-horde/validate.mjs port/native-horde/evidence/0a9bf1c1-444b-42af-87c0-db9c7a25ce9b
    node port/native-horde/scene-smoke.mjs
    git diff --check

Final focused verifier: 14 Node adapter/validator tests, 70 inherited source/UI tests, 15 native Horde assertions, 2,497 inherited synthetic control-safety assertions, and inherited GameHUD session gate all pass. Logs: check-0.log through check-4.log and verify-final.log. Import: import-final.log. Full aggregate/release verifier was NOT run. Existing semantic exporter still reports release gate closed; no release bypass.

## Real normal-rate acceptance and exact attempt history

Two attempts per scenario; all six retained. No preferred-seed selection. Each was bounded to native 170s/outer 180s. Each uses owned loopback adapter and private Xvfb with -nolisten tcp/-nolisten unix.

1. Ember startup attempt 1, 65d0162d-3a4b-4f40-b3d2-174ef2a3d116: received real wave/enemies but rejected because hidden map selector had no items. Fixed native initialization; excluded from acceptance.
2. Ember startup attempt 2, 0a9bf1c1-444b-42af-87c0-db9c7a25ce9b: PASS, 149 recipient-correlated snapshots, real wave 1 with three enemies, zero claimed kills/victory.
3. Meridian combat attempt 1, 267efa5b-8bfe-4870-9c18-c559f3322787: actual three kills and source victory, then new transport rejected an input still in flight at results. Excluded from accepted lifecycle result. Final actor coordinates in retained source: x=-29.594169339562665, y=0.6854999999999997, z=-7.428015062173067. No source defect claimed; adapter handling fixed.
4. Meridian combat attempt 2, 4d1edc81-ddb1-4e4d-9cfb-e3ebad8a99f0: PASS, 399 correlated snapshots, three real kills, legal one-wave victory and source restart with capture released. 358 input receipts; ACK high-water 351 (across per-round reset observations, not a count of independently applied messages). Test steering aimed at received enemy positions, approached ranged targets via native W/jump, fired actual native mouse events. This is not human aim/camera acceptance.
5. Verdant death attempt 1, 88ba2aa4-7b04-495e-9bb7-f75d8f9db012: natural life loss, respawn and capture gate succeeded, but movement was only held after death. Its original narrower validation is retained; NOT accepted as pre-death-held-action proof. Superseded by the next attempt; final stricter validator intentionally rejects its missing pause/held-action evidence.
6. Verdant death attempt 2, 5771ef43-a3d5-4bcb-b63b-7759fcb47824: PASS, 553 correlated snapshots, genuine source death/life loss then living state, E held while alive through death/respawn, attempted click blocked until release, fresh capture after release. Explicit pause/resume probes and more than ten neutral queued-control observations during dead/respawn release window. 1,487 receipts, ACK high-water 1,486. Defeat was NOT reached.

The final HUD position was moved below the shared status panel after reviewing its layout code (y=190 instead of y=80). Final Verdant screenshots/test exercise this layout. Meridian/Ember earlier gameplay evidence has the prior strip position; gameplay/model logic is unchanged. Those older screenshots are not final layout acceptance.

Final product-scene smoke subsequently passed at default ten waves: real wave/enemy state, child reaped, source listener closed, no scripts errors. product-smoke.json/log. This is startup only; an actual human engage/fight/pause/death/restart playthrough is still pending.

Queue records show client queueing, wire observations show receipts, ACK records show last processed sequence. Gameplay effects are separately established by actual snapshot kills/lives/outcome and source events. Do not call every queued/ACKed input independently applied. Native trace lacks a recording-completion marker; bounded harness completion is not native trace completion.

## Screenshots / visual limitation

Final screenshot directory:
port/native-horde/evidence/5771ef43-a3d5-4bcb-b63b-7759fcb47824/
- gameplay-final.png: 960×640
- gameplay-alternate.png: 1280×800
- gameplay-wave.png and gameplay-death.png: 960×640

PNG dimensions independently read. HORDE_LAYOUT records show the 51px Horde strip at y=190 does not intersect the shared status panel y=78,height=70 at both resolutions; mouse filter is passive. These are geometry checks, not pixel review.

Image-capable browser navigation failed with HTTP 500 from the browser service (127.0.0.1:9377/tabs). A private screenshot HTTP endpoint returned 200, but no image was actually opened for visual inspection. That temporary server was stopped, PID absent and port closed. Visual review REQUIRED by the lead remains pending. Do not present screenshots/logs as already visually accepted.

No human hardware/mouse feel, actual OS focus transition, audible audio, ten-wave completion, endless, boss combat, upgrade selection, natural defeat or packaged Linux acceptance claimed. Audio is reused but automated runs used Dummy.

## Human launch and controls

After resource export/import and dependency availability, on an explicitly coordinated graphical display:

    node port/native-horde/run.mjs --manual --map=meridian-exchange
    node port/native-horde/run.mjs --manual --map=verdant-reliquary --resolution=960x640
    node port/native-horde/run.mjs --manual --map=ember-crucible --waves=1

Manual default is ten waves, not the harness's one-wave preset. Click to engage/fire, WASD move, mouse aim, Space jump, Shift sprint, Ctrl crouch, R reload, E interact, F mobility, 1–9/0/wheel weapons, Tab scoreboard, Esc release. Esc releases input; it does NOT pause authority. After death/respawn or results/restart, release action/movement keys and click afresh. Enter requests restart only at results. Close window/Ctrl-C to terminate owned session. No joining shared services.

Manual acceptance checklist: engage and fire; Esc releases controls while enemies continue; release held keys and click to resume; verify death/life loss or victory; Enter from results; verify old enemies/effects cleared and no automatic capture. Inspect both sizes and actual audio/focus. Not yet completed by a human.

## Identity-family hook (Nacre Engine) — added after this delivery

The authority now also owns one frozen identity entry so Horde can play Nacre
Engine through the same loopback transport:

- `IDENTITY_MAPS = Object.freeze(['nacre-engine'])`, `HORDE_MAPS` = the three
  source maps plus that entry. `validateConfig` accepts both families; the
  single-human, epoch, event-cursor, bounded-message and loopback-only contract
  is unchanged.
- `readIdentityMap`/`validateIdentityEnvelope` resolve one literal
  package-relative path (`godot/identity_maps/generated/nacre-engine.json`),
  re-validate the envelope (schema, id, `mode: 'horde'`, bounds, spawns, blocks,
  pickups, terrain meshes) and recompute the canonical `arena` SHA-256. No wire
  frame, CLI argument or environment variable can select a map, path or document.
- `createHordeMatch({mapId, config, random})` is the single map/factory hook.
  Source maps keep the historical constructor; the identity family installs its
  validated arena through a reviewed local constructor accessor and re-checks
  arena identity, horde mode, single human and a supported spawn.
- The hook is inline in `authority.mjs` on purpose: the package closure
  (`tools/godot-package/discover.mjs`) derives the shipped adapter inventory from
  the static import graph and rejects unreviewed runtime inputs, so a new
  imported helper would change the package inventory without a package-lane
  review. `game/core.mjs` was already in the closure.
- Acceptance for the identity route (runs, screenshots, corridor measurement,
  open items) lives in `port/native-identity-horde/HANDOFF.md`. Existing
  source-map Horde evidence above is unchanged and still valid.

## Integration proposal (NOT applied)

- Common launcher --experience=horde should route only the three validated maps to res://horde/demo.tscn and launch this local-only adapter, not createGameServer/Room. The identity route (`--map=nacre-engine`) uses the same authority and the identity composition `res://native_arenas/identity_horde_demo.tscn`; see `port/native-identity-horde/HANDOFF.md` for the map/hook and package notes.
- Prefer a reviewed local-authority abstraction for singleplayer rather than weakening public room security. If the lead wants shared-network Horde instead, that is a distinct server/protocol design change and is outside this delivery.
- Carry default ten-wave settings; explicitly forward optional legal wave target. No campaign route.
- Linux resource allowlist must include godot/horde scenes/scripts, their existing shared session/UI/combat/audio dependencies, generated three-map semantics and existing map visual resources. Runtime Node packaging must include authority.mjs, unchanged imported game modules and existing ws runtime dependency. Exclude godot/tests/horde live steering and port/native-horde/evidence from product resources.
- Rebuild/reimport, independently rerun focused/live claims and inspect screenshots before updating aggregate gates or releasing. No package/launcher patch applied; no indispensable shared code modification needed for this standalone path.

## Cleanup / delivery state

All six run summaries confirm native/Xvfb processes reaped and independently absent, listeners closed, sockets zero, private XDG trees removed. Product-scene smoke also confirms cleanup. No shared services restarted; failed delegate processes exited. The temporary dependency symlink is removed before commit/delivery. Source authority files unchanged. Scope only the three authorized directories; no merge/push/deployment.
