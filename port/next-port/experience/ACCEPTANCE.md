# Experience native acceptance — 2026-10-02

Explicit serial engine grant received. Tested with World `656f0830` + `e99ab7ca`
and Modes `86c182f9` + `eb3f2d10` cherry-picked into this lane. These baseline
commits must **not** be cherry-picked back into the parent as new work.

Evidence root: `/home/mojo/.tmp-on-disk/cocs-port-experience-evidence-20261001`.
Rendering: Xvfb / Mesa llvmpipe, Godot 4.5.2, `LP_NUM_THREADS=1`.
No FPS, human-playtest, audio PCM or human-listening claim. Captions are text only.

## Native gates

| Script | Result | Evidence |
|---|---|---|
| `tests/experience/contracts.gd` | 488 checks, zero failures | `gate-tests-experience-contracts.gd.log` |
| `tests/experience/combined.gd` | 127 checks, zero failures; nine source operator models | `gate-tests-experience-combined.gd.log` |
| `tests/product_shell/settings_contract.gd` | 50 checks, zero failures | `gate-tests-product_shell-settings_contract.gd.log` |
| `tests/campaign/input_flow.gd` | 614 checks, zero failures | `gate-tests-campaign-input_flow.gd.log` |
| `tests/campaign/story_presentation.gd` | pass | `gate-tests-campaign-story_presentation.gd.log` |
| `mode_expansion/contracts.gd` | pass | `gate-mode_expansion-contracts.gd.log` |
| `tests/main_menu/lifetime.gd` | pass | `gate-tests-main_menu-lifetime.gd.log` |

Editor import attempt 2 exited zero with no errors. Attempt 1 aborted during
editor shutdown after importing assets; its original log remains. Initial native
checks found campaign type inference and an empty typed-array assignment error.
The caption oracle also exposed type-strict Dictionary comparison of JSON float
priorities versus native integers. The test now normalizes only that numeric
representation and accumulates failures so its final quit cannot mask them.
The frozen 432-case source oracle was not changed.

## Connected rendered journeys

`tools/experience/native-journey.mjs` starts a real source authority, drives Home,
F12 and gameplay with `Input.parse_input_event`, records input wire frames and
screenshots, and rejects runtime errors as well as failed assertions. Each run
uses isolated persisted settings. Controlled damage, pickup, respawn and local
kill setup uses the genuine Match methods, explicitly recorded in
`source-actions.json`; it is not a claim of unaided combat completion.

- Four new modes: wide **1280×800** and compact **760×520/UI150** passed.
  Evidence: `arsenal-wide-final`, `arsenal-compact-attempt4`,
  `{juggernaut,team-elimination,vip-escort}-{wide,compact}-accepted`.
  Includes real local fire, muted captions, Q/X status, source pickup, incoming
  damage, elimination, respawn, scoreboard and Home teardown.
- Newest compact boundary runs: `{campaign,sports,combined_arms,mode}-compact-boundaries2`.
  F12 and campaign F3 received W/Q/X input while open; source wire checks found
  no gameplay actions. Snapshot/event starvation clears status/captions; fresh
  transport resumes without replay. Campaign keyboard End reaches the kit in
  the focused objective scroll. F12 enable/disable and mute preferences survive
  save/reload; Esc closes without recapturing the pointer.
- Campaign wide: `campaign-wide-final`; compact: `campaign-compact-boundaries2`.
  Existing source story proximity was staged at a real story entity. Inspect
  `story-comms.png`, `kit-scrolled.png`, `cheats-overlay.png`, `match-settings.png`.
  Normal scene transitions return persistent labels safely to their owner.
- Local attributed elimination and OVERKILL: `local-kill-attempt1` (wide),
  `stale-kill-compact-attempt1` (compact). Three received incoming hits and
  unknown-source fallback are exercised; respawn clears the ledger.
- Career: `career-compact-attempt1` opens Career/Arsenal through the focused
  Settings button, checks neutral W/Q/X wire input while open, captures the
  panel and returns with Escape.
- Independent sports and combined-arms routes use real `net` / `"active"`
  lifecycles. Captions from controlled source respawn are visible; no infantry
  ability model is invented. Both test native Enter/W, stale/resume, modal
  neutral input and Home teardown.
- Gameplay's three original real mobility journeys passed on this combined tree:
  `mobility-live/` — Kimi blink, Qwen rope/ride, ChatGPT grapple. Nine operators
  remain model-contract coverage, not nine live ability journeys.
- `connected-round/juggernaut/acceptance.json`: two native players plus native
  spectator, normal 40.0167-source-second round, native guest reconnect, host
  restart, results and Home transitions. 340/318 player shots; controls released
  at result/leave boundaries. This inherited journey does not independently
  assert every PlayerInformation field for each peer.

All failed attempts remain alongside passing attempts. Notably: missing semantic
manifest, compact overlap, source crown shield preventing a health pickup,
incorrect campaign endpoint, pre-ready pointer clicks, keyboard focus timing,
and test-only manual scene teardown leaks. The harness now uses normal
`change_scene_to_file` handoffs. A genuinely unparented inherited mode selector
is also now tree-owned to release its popup resources.

## Render review and bounded gaps

Inspected actual wide/compact mode ability, pickup, death recap and local kill
frames, campaign story/kit frames, and independent compact caption frames.
The mode objective uses the existing responsive objective HUD. Captions fit
short side slots when the central aiming area is reserved; kit and hit history
use scroll viewports. Keyboard Home/End/Page/arrow navigation consumes its event
before gameplay. Continuous interleaved shot/blocked-movement spam is suppressed
until a quiet interval, without extending the displayed caption's TTL.

**Remaining acceptance gaps:** comprehensive native spectator privacy/seat
handoff assertions across independent route families; full mouse-wheel
transcript reachability and measured text-bound
assertions for every screenshot; protected mission-priority events connected
live (priority behavior is native oracle-tested). Combined-arms' existing HUD
still has overlapping/long control text at UI150 in the inspected screenshot,
although the added Respawn caption itself is readable and unobstructed. These
are not a complete product/release acceptance claim.

## Reproduction and parent gates

```sh
export GODOT_BIN=/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/experience/contracts.gd
LP_NUM_THREADS=1 "$GODOT_BIN" --headless --path godot --script res://tests/experience/combined.gd
SCENARIO=campaign COMPACT=1 EVIDENCE_DIR=/path/to/new-evidence node tools/experience/native-journey.mjs
MODE=vip-escort COMPACT=1 EVIDENCE_DIR=/path/to/new-evidence node tools/experience/native-journey.mjs
SCENARIO=sports COMPACT=1 EVIDENCE_DIR=/path/to/new-evidence node tools/experience/native-journey.mjs
SCENARIO=combined_arms COMPACT=1 EVIDENCE_DIR=/path/to/new-evidence node tools/experience/native-journey.mjs
```

Parent canonical additions: the two `tests/experience` contracts; connected
runner as a serial graphical gate. Parent's moved gameplay fixture path must be
used in `combined.gd` when integrated (this lane retains its original path).
Parent owns package filters/catalog shipping (115 captions + nine operators),
full canonical suite, exports and publication. No package contract was weakened.

No engine work is authorized by these reproduction commands without a slot.
Final slot release is reported after owned process verification.
