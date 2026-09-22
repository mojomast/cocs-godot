# Independent Arms Race delivery review

**PASS for the standalone bounded slice:** genuine Meridian native-input kill →
source promotion → displayed rung/weapon, natural timed results, fresh-input
restart, and all three arena startups. **Full ten-rung live victory remains open.**
One independently executed combat attempt; no second attempt needed.

## Scope and provenance

- Integrated baseline: `54452957353bcaf72fe467739a1ce2dfcd6dc69a`.
- Delivery: `52de3b9216ac2837344015cd55e5527cf7b260d7` and
  `21fbd93ded3e92228f882b1d582a3c1623943393`.
- Isolated cherry-picks: `5d03467` and tested HEAD
  `e7602fb2bd96f9e73f6c05b1bbb170be35df4dd9` in
  `/tmp/opencode/arms-race-independent`.
- Locked source: `51289b79c627a26a381ba556b92bab71f93f3732`.
- Godot `4.5.2.stable.official.6ce3de25a`, Node `v22.23.1`, primary read-only
  dependency tree as specified by delivery HANDOFF. Full paths, commands,
  ephemeral ports, PIDs, source configs and hashes are in each UUID's summary.
- Read primary ACTIVE_LANES and delivery HANDOFF/DISCOVERY/runtime/helpers.
  [PLAN.md](PLAN.md) records source-derived plan and run decisions.
- Only new independent report/evidence and the distinct
  `godot/tests/arms_race/independent_fixtures.gd` helper are authored here.
  Existing runtime, source, observer, server helper and shared launch/package
  files are byte-identical to the tested delivery/integrated baseline.

The new runner executes the reviewed delivery harness with explicit in-memory
changes for output location, extra fixtures, and cleanup checks. It does not
alter the native observer/server/runtime. `initial-wrapper.patch` reconstructs
the initial wrapper (SHA-256 `a9dea1613b6d7abb8ddf4460cff781b605940f9f05e70cf53814cd8fb764e007`)
for the first two UUIDs. The correction runs graphical weapon-selection fixtures
on Xvfb instead of headless. Every run records its wrapper hash.

## Independent live evidence

| UUID | Operation | Outcome |
|---|---|---|
| `2a8ac5ea-4118-489c-a9ac-c58388f7cc15` | Combat attempt 1, Meridian 1280×800 | PASS; promotion at source 8.217s, observer stopped at 8.596368s |
| `46927e91-1736-4e5d-ad29-48eba05c850f` | Startup preflight | Retained FAIL: graphical selection fixture mistakenly invoked headless; no authority/client gameplay starts |
| `5170738c-bc25-49c4-b839-17035898df9e` | Corrected fixtures + all three startups + Meridian timer/restart | PASS |

These are this reviewer's fresh executions, not the delivery author's two
combat attempts. Combat used **two Normal bots**, default **180-second round**,
all ten weapons, default loadout, empty mutators, speed/gravity/damage = 1,
normal source scheduler/RNG. No state/time/physics injection, direct gameplay
handlers, seed retries, altered bots or shortened ladder. The unchanged
snapshot-guided observer emits ordinary Godot keyboard/mouse events and reads
public geometry/state. Bound: 174s soft / 177s observer / 180s process deadline.

### Source effect and display attribution

At **8.217s**, source `shot` **425** used weapon **0 (Pulse Rifle)** and hit
actor **1**. Source death **424** names local actor **0** as killer, `self=false`.
Promotion **423** gives actor 0 weapon **1**, `bonus=false`.

| Layer | Independent observation |
|---|---|
| Native successful input queues | 380 |
| Passive server input receipts | 380 |
| Applied ACK highwater | 380; promotion snapshot ACK 376 |
| Source snapshots | Seq 246 → 247: frags 0 → 1, ladder 0 → 1, weapon 0 → 1, shots 30 → 31 |
| Post-draw capture, seq 247 / ACK 376 | `RUNG 2 / 10 · Rocket Launcher`; `Next: Rail Lance`; `PROMOTED +1` |

Queue success, server receipt, and ACK highwater are separate facts. A highwater
does not prove that every intermediate/coalesced input was applied. Source
events and actor changes prove this kill/promotion. Source death.weapon is **1**
because promotion occurs before the death event is built; the source shot event
and preceding snapshot establish the firing weapon as **0**.

The observer's `ARMS_SNAPSHOT` callback runs before the deferred HUD callback:
its native actor can be current while its HUD text is one callback old. Display
claims therefore use `ARMS_CAPTURE` after `frame_post_draw`, checked against
the same authoritative snapshot and directly opened PNG. The initial offline
audit incorrectly equated these callback times; [audit-initial-failure.log](audit-initial-failure.log)
retains that verifier failure and correction. Gameplay was not rerun.

### Natural timer and restart

Meridian 960×640 used the legal **60-second** source timer with the same two
Normal bots and ten-rung rules. Result time **60.01666666666454**, `over=true`,
`overReason=time`, `winner=null`. Grok won timed ranking with ladder **4**
(display **5/10**), 4 frags, 0 deaths; Claude had ladder 0 / 1 frag / 1 death;
local Godot had ladder 0 / 0 frags / 4 deaths. This was a timed bot win,
**not a ladder finish or local victory**.

Ordinary Enter requested restart: two source starts, one result. New round
resets all actors' ladder/weapon/frags/deaths to zero. Held W across restart
blocked capture and movement; source position was unchanged throughout the
first second. After release/fresh click/W, final source displacement was
**8.721939m**, with first moving receipt seq 60. Results released control;
post-restart screenshot shows cleared result UI and starting loadout.

| Arena / round | Size | Queued / received | ACK highwater |
|---|---|---|---|
| Meridian timed round | 960×640 | 3462 / 3462 | 3460 |
| Meridian restarted round | 960×640 | 117 / 117 | 116 |
| Verdant startup | 1280×800 | 221 / 221 | 221 |
| Ember startup | 960×640 | 269 / 269 | 268 |

ACKs reset per round; trailing receipts above highwater are not counted as
applied. All three startup configs were source-confirmed. Export/import and
native catalog retained all nine maps.

## Focused tests and code review

- **55 release-safe Arms Race fixture checks, 0 failures**: 32 delivery checks
  plus 23 independent checks (all ten held-action bindings, frag/rung independence,
  explicit completed ladder/current weapon and reset). Uses `push_error` and
  nonzero exit, not release-disabled assertions as the failure gate.
- **38/38 source tests**: Arms Race 7, outcome 13, input 15, movement-input 3.
- **Eight inherited native suites pass**: control safety **2497**, lifecycle
  **15**, round boundaries **34**, session recovery **52**, stalled controls
  **12**, graphical weapon selection **64**, plus HUD-session and
  scoreboard-session suites (these last two report pass markers, not counts).
  These are synthetic regression fixtures, not live gameplay proof.
- `core.mjs:1148–1149` owns catch-up, normal promotion, final kill, and demotion.
  `outcome.mjs:74–81` owns explicit winner priority, ladder/frags timed ties and
  scoreless draws. Native progress reads ladder/weapon rather than inferring
  progress from frags. Rung 9 alone says one more kill; explicit completion
  produces ladder-finish text. Scoreboard uses ladder then frags.
- Native digit/wheel events are consumed; `weapon_controls_active()` is false
  and inherited queueing cannot include weapon selection. No weapon field
  appeared in any live receipt. Source also pins the ladder weapon. The actual
  live combat route did not deliberately press every digit/wheel combination.
- Inherited session/client/HUD/scoreboard files are identical between delivery
  base `8a58c97` and integration base `5445295`. Subclass boundary dispatch retains
  focus, missing/stale actor, death/respawn and round neutralization. Fresh latch
  adds release-before-recapture; live timer/restart confirms the integrated path.

## Screenshots directly opened in this review

- [Meridian promotion, 1280×800](evidence/2a8ac5ea-4118-489c-a9ac-c58388f7cc15/meridian-exchange/promotion.png): rung/current/next agree with the bottom-right Rocket Launcher panel; promotion, health 5 and ammo 6 are legible.
- [Meridian timed results, 960×640](evidence/5170738c-bc25-49c4-b839-17035898df9e/meridian-exchange/results.png): Grok ranking, all three rows and Enter restart fit without HUD overlap.
- [Meridian restart, 960×640](evidence/5170738c-bc25-49c4-b839-17035898df9e/meridian-exchange/restart.png): initial rung/current/next and fresh control prompt restored.
- [Verdant startup, 1280×800](evidence/5170738c-bc25-49c4-b839-17035898df9e/verdant-reliquary/startup.png) and [Ember startup, 960×640](evidence/5170738c-bc25-49c4-b839-17035898df9e/ember-crucible/startup.png): distinct green/orange arena palettes and readable locked-loadout HUD. Existing world-space labels can extend offscreen.

## Cleanup, hashes and integration finding

Private copied projects, isolated HOME/XDG, owned `PORT=0` loopback authorities,
Xvfb `-nolisten tcp -nolisten unix`. Every child is reaped; every owned authority
listener is checked closed; all three temporary trees are removed. Final checks
recheck PIDs/listeners and runtime hashes. Mesa's V-Sync warning is retained;
successful runs contain no script errors. Audio used Dummy.

| File/tool | SHA-256 |
|---|---|
| Godot binary | `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae` |
| Node binary | `93956de2e59480474a7b46571da1651180b1a050cdf32641ebec4ce6e478e068` |
| ws dependency tree | `c0dc2e2d4228652d0f4f653026eb2f85a0777177d34ec9a485260ebf82b9ef8d` |
| game/core.mjs | `23d0a86acf720136c62a42547207b1c43f2146002fd26d8ac7d325b2d6312631` |
| godot/arms_race/demo.gd | `0cb94b4c21200af5eaeaee0fe4cf56c656582ade1205e3a52009eddb8b335969` |
| godot/world/session.gd | `a501f3814e08c6ba17ac4f9bf2b2d2942241a8a48613d902387b8774a3b31554` |

Complete per-run runtime/generated hashes accompany the logs.
[AUDIT.json](AUDIT.json) preserves source effects and per-round transport counts;
[FINAL-CHECKS.json](FINAL-CHECKS.json) and [EVIDENCE-SHA256.json](EVIDENCE-SHA256.json)
cover final verification and artifact integrity.

**Integration finding:** the delivery's `shared-hooks.patch` does not apply on
`5445295` because zone/combined-arms entries now separate combat and sports.
[shared-hooks-rebased.patch](shared-hooks-rebased.patch) contains the same two
route additions with updated context; `git apply --check` passes. It is
**unapplied**, for the lead's separate shared-hook integration. No standalone
runtime defect requiring an implementation patch was found in this bounded review.

## Limits and reproduction

Full ten-rung victory, live bonus/demotion/final-kill permutations, and all live
focus/death/respawn combinations remain beyond this bounded acceptance; those
rules have fixture/source coverage only. Automated snapshot-guided input is not
human usability approval. Audible quality and rebuilt package routes were not
tested. Existing player-usability reservations and external lobby/Horde reviews
remain separate. Campaign remains deferred.

Commands used: `python3 port/reports/arms-race-independent/run.py --attempt=1`,
then `--startup` (retained failed preflight and corrected execution).
Offline reproduction: `python3 port/reports/arms-race-independent/audit.py` and
`python3 port/reports/arms-race-independent/finalize.py`. Fresh live reruns allocate
new UUIDs; the independent combat budget is already satisfied with one run.
