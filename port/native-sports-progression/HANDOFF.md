# Native sports progression

Isolated branch `sports-progression-agent`, worktree `/tmp/opencode/sports-progression-8094d41`, base `8094d410fd576911f39712f91c7dc2bfc2d5d80a`.

## Player-facing changes / API

- `godot/sports/guidance.gd`: a single reusable expected-checkpoint marker (seven unlit boxes and one label). Position, normal, half-width and expected index come from the accepted race snapshot. The arrow points through the plane along the source normal; posts span the source crossing interval −0.25 to 3 m. The visible ground stripe is raised 0.06 m to avoid z-fighting. Missing/invalid gates, missing/finished racer, stale state, results and restart hide and clear the marker. Gate selection never uses local proximity or locally scores progress.
- `godot/sports/hud.gd`: retains `describe()` compatibility and `demo.hud.text`; adds elapsed/configured-limit clock, source-gate bearing/distance, short authoritative notifications and a passive central results panel. Time-limit standings say how many laps were completed, rather than claiming a race finish. Soccer results show source scores/winner or draw. All controls remain mouse-ignoring and unfocusable.
- `godot/sports/progression.gd`: bounded transient message/lifetime. Only network-deduplicated `soccer-goal` and own `race-lap` events create notifications. Soccer's “Ball reset to centre” describes `scoreGoal()`'s immediate reset; ball motion alone creates no goal/reset claim.
- `godot/sports/demo.gd`: connects authoritative events/results; emits a final neutral packet at results, releases controls, and resets all accepted round references, fleet, ball transform/visibility, guidance, message, HUD, camera pose and input cadence on F5/start. The new helper is parent-owned even in existing out-of-tree test fixtures. Existing `state`, `vehicle`, `actor`, `hud.text`, eligibility and controls API remain available.
- `godot/sports/chase.gd`: reset also zeros stored eye/target/last pose and last query count, keeping the immutable map cache.
- Optional demo arguments `--time-limit=60..900` and `--round-target=N` send ordinary host configuration. Target clamps to source limits (race 1..10, soccer 1..15). Without these arguments, the original configuration path remains in use.

Source references: `game/race.mjs` (`raceSnapshot`, `crossRaceGates`, `raceStandings`), `game/soccer.mjs` (`soccerSnapshot`, `scoreGoal`), `game/destination-sports-maps.mjs` (Ion's 17-point centerline/gates and Aurora's pitch/goals), `game/config.mjs:289` (legal time limit minimum **60 seconds**), `game/core.mjs` (`overReason`, flattened event payload), `server/room.mjs` (start resets input state; round-over ignores further input).

## Reproduction

```sh
python3 -B port/native-sports-progression/run.py
# Optional focused runs:
python3 -B port/native-sports-progression/run.py --unit-only
python3 -B port/native-sports-progression/run.py --map ion-speedway --resolution 960x640
python3 -B port/native-sports-progression/run.py --goal-attempt
```

The new helper creates a private `/tmp/opencode` copy of Godot/game/server, reads primary `node_modules` through a symlink, exports locked semantic data, and imports using pinned Godot `4.5.2.stable.official.6ce3de25a`. It runs the original controls27/Puma19/polish41 checks and new synthetic progression checks. Graphical runs use private Xvfb `-nolisten tcp -nolisten unix`, Mesa llvmpipe, Dummy audio and owned `127.0.0.1:0` servers. The new server has a 240-second deadline; the original launcher/verifier are untouched.

Each graphical run hosts a legal 90-second Ion or 60-second Aurora round, with target 10 laps / 15 goals so that time-limit results can be observed. The observer injects native physical key events, including normal event-buffer flushing, through the actual demo. Its compact test-only driver reads accepted state and source gate geometry, follows a short lookahead on Ion, and approaches Aurora's ball toward the opponent goal. It never writes state, inputs, actor pose, snapshots, rules or clock. It releases after a completed lap or a bounded driving interval. Server physics/tick rates are unchanged.

After natural time-limit results, it releases movement, presses F5, checks immediate native cleanup, holds W through the new countdown, verifies no movement without Enter, then verifies Enter alone remains neutral and only a fresh W causes accepted displacement. Captures include countdown, driving, progression, results, restart countdown, held-key blocked, Enter-only neutral and fresh driving.

The separate `--goal-attempt` uses Aurora at 1280×800, ordinary 180-second configuration and a **135-second observer bound**. It adds only a short physical reverse maneuver when jammed and clamps the approach point inside the source pitch. It stops on a local-driver goal or the bound, preserving all source goal events and their actor/team attribution. It is explicitly not a substitute for the results/restart matrix.

Every run records commands, exact script/source/binary SHA-256 hashes, generated semantic hashes (newer runs), native/import/export/test logs, sanitized input-arrival receipts, snapshot ACK/state samples, source events/results and cleanup receipts. Input arrival is not proof of application. Snapshot ACKs track source `appliedSeq`; accepted position and source standings/events establish gameplay outcomes. The final neutral packet at results is a socket receipt only: `Room.input()` rejects round-over input. F5 resets the server's latest/received/applied input state; post-restart ACKs and unchanged/moved positions verify the fresh-input gate.

## Final accepted verification

Final unchanged-code matrix: [`evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/summary.json`](evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/summary.json). Manifest SHA-256: `843a5613b711892f80ffe859bc33a0f1b450057fafd326e97a20195b8735cf77`. An audit compared every recorded source/script hash with the current worktree: **zero differences**.

- Original controls **27**, Puma **19**, polish **41**, and new progression **32** checks passed: **119 assertions**, no script/engine errors. The new wire-JSON regression covers float team IDs in goal notifications.
- Four real graphical cases passed at normal source rate. All ended by ordinary `overReason: time`, restarted with F5 and proved held-W blocking, Enter-only neutrality, then fresh-W source displacement. Source elapsed advanced at 1.007–1.023 seconds per wall second under the unmodified default scheduler.

| Case | Time limit | First observed completed lap | Input receipts | Neutral packets before fresh restart movement | Fresh source displacement |
|---|---:|---:|---:|---:|---:|
| Ion 960×640 | 90 s | elapsed 42.933 s | 1,989 | 90 | 7.567 m |
| Ion 1280×800 | 90 s | elapsed 42.833 s | 2,209 | 111 | 7.567 m |
| Aurora 960×640 | 60 s | — | 1,651 | 110 | 7.654 m |
| Aurora 1280×800 | 60 s | — | 1,518 | 92 | 7.229 m |

Both Ion cases crossed all 17 gates and returned through the start plane, with source `completedLaps: 1`; the ten-lap target was not completed. After F5, all four cases reset source elapsed to zero, race gate/lap counters returned to initial values, and soccer scores returned to 0–0. One or two neutral socket receipts followed results in each case; they are not claimed as applied after round-over. Every owned server closed with zero sockets, every child was reaped, and private copied projects were removed.

**Soccer limit:** final two short Aurora matches had no goal events. Three real **bot-scored** goals and a Blue 2–1 result were observed in the retained earlier matrix below. No local-driver goal was achieved, including the separate 135-second attempt. The corrected goal/reset notification is validated by wire-JSON regression; a post-fix live goal-message screenshot is **not** claimed. No further route/goal repeats were pursued after lifecycle acceptance.

Directly inspected final PNGs (all fit; no label/panel overlap):

- [Ion 960 guidance/countdown](evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/ion-speedway-960x640/countdown.png): source-width mint frame, ground arrow and counter are visible.
- [Ion 1280 time-limit results](evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/ion-speedway-1280x800/results.png): accurately says one lap completed and time expired.
- [Aurora 960 results](evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/aurora-stadium-960x640/results.png): source 0–0 draw, restart instructions.
- [Aurora 1280 Enter-only neutral](evidence/4df4abb2-0b35-4df4-bd7a-7d82ae3273f8/aurora-stadium-1280x800/restart-enter-neutral.png): fresh round, engaged, stationary at 0 m/s until a fresh movement key.

Earlier direct image reviews also covered both Ion lap views, all four 4b815 results views, Aurora's actual goal/ball-reset scene, its Blue 2–1 result, and restart neutrality. That review caught the float-team notification bug rather than accepting the machine summary alone.

## Lead integration hook (unapplied)

Lead reports `tools/godot-dev/launch.mjs` sports support at `5d7a442`, with an owned endpoint and no interactive deadline:

```sh
node tools/godot-dev/launch.mjs --experience=sports --map=ion-speedway
node tools/godot-dev/launch.mjs --experience=sports --map=aurora-stadium
```

This branch stays based on `8094d41`; no lead/primary merge or launcher edit was made. Existing map/endpoint forwarding is sufficient for ordinary play. Optional **unapplied lead hook**: accept/forward `--time-limit=60..900` and `--round-target=N` as Godot user arguments after `--` when short legal configuration is desired. Scene target limits are race 1..10, soccer 1..15. The scoped helper already uses these arguments directly. The launcher commands above refer to the lead's integrated tree, not a claimed launcher acceptance run in this isolated base.

## Retained attempts

- `evidence/df52063e-30b1-4143-a8ab-35750b2d35de`: controls27 assertions passed, but shutdown leak checks failed because the new guidance helper was initially unparented in the original out-of-tree demo fixture. Fixed by parent-owning the helper/caption; existing controls test unchanged.
- `evidence/4554dc9e-01f2-4bfc-a253-d0627f60521e`: first real Ion run crossed all 17 gates and completed a lap at source elapsed 43.367 s, then natural 90-second results and a second round. An observer assertion checked F5 cleanup before buffered native events were delivered; retained as a **failed acceptance run**. Fixed the new observer to flush normal input events before its synchronous lifecycle assertion. Countdown/lap PNGs were directly inspected and fit at 960×640. This run predates the final immediate HUD-clear and integer-format polish.
- `evidence/71d9ae42-2a7a-4fa9-92ac-178a59516a47`: interim headless-only pass, including original suites and 31 progression assertions; no live claim.
- `evidence/6077ee31-3796-44ad-b7fc-b1011d9212a2`: four-case graphical matrix passed at both resolutions on both maps, including full Ion laps, natural time-limit results, F5 and fresh-input gating. Zero Aurora goal events in the two short matches. This precedes singular “1 lap” formatting and stronger capture-stage/neutral-receipt assertions; superseded by the final matrix. Ion 960 results PNG was directly inspected and fit without overlap.
- `evidence/4b815be2-ef83-49a1-a853-b5ad0718d9b2`: stronger four-case lifecycle/neutral-receipt matrix passed. Both Ion cases completed a lap. Aurora 960 produced **three actual bot-scored goals** (Blue actor 1 twice, Red actor 2 once), with final Red 1–Blue 2 source scores; no local-driver goal. Direct PNG review caught a **presentation failure missed by that helper revision**: score/reset were visible, but the transient goal message was absent. Godot's `in [0, 1]` membership did not match wire JSON float team IDs. Fixed to numeric equality and added a real JSON-decoding synthetic regression; newer captures wait for and assert the goal/reset notification. The run's machine `PASS` covers lifecycle/progression, not this subsequently discovered notification bug.
- `evidence/da6cd3bb-5c56-4f6c-aeee-62478f01778d`: separate bounded goal attempt completed cleanly, ending at source elapsed **131.267 s**, with **zero goal events**. No local-driver goal acceptance. Its initial observer considered actor attribution alone for early stopping; the retained tool now also requires the scored team to match the driver, excluding own goals. This distinction does not change this zero-event attempt's result. Its `PASS` means the bounded attempt ran/cleaned up, not that a goal succeeded.

## Runtime identity

- Godot `4.5.2.stable.official.6ce3de25a`, SHA-256 `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
- Node `/usr/bin/node`, `v22.23.1`, SHA-256 `93956de2e59480474a7b46571da1651180b1a050cdf32641ebec4ce6e478e068`.
- Read-only-used primary `ws` dependency version `8.21.3`; sorted relative-path/file-SHA-256 tree digest `c0dc2e2d4228652d0f4f653026eb2f85a0777177d34ec9a485260ebf82b9ef8d`.
- Every evidence directory's `hashes.json` pins the actual source/script revision used, rather than assuming the worktree stayed at its base while developing. `summary.json` pins that hash manifest and records exact commands. Older runs deliberately remain intact.
- Final sorted `relative-path SHA-256\n` manifest-prefix digests: `game/` = `5c1d5db429f209985d725b7084ac5fca80852c6bd2abe7cc705cfe06adaeabaa`; `server/` = `a6021151152fd656eab010a90da8621d0c7b39e5de6a63eac61f5e5c75b243b9`; native `godot/sports/` scripts = `abd17aa886f96ee5d01071080fe64e3393560fff925a3fe7e63577be6a5fe9bd`.

## Limits

- The physical-key driver is an acceptance helper, not a player autopilot. No solver or racing AI was added to gameplay.
- Source snapshots/events own all score/progress. No local gate or goal detector exists.
- Camera collision still uses the existing source-box cache; this work does not add terrain or full-frustum collision.
- These are native programmatic key-event runs, not human or OS focus acceptance. Soccer bot-attributed goals must be distinguished from local-driver goals in the receipts.
- Only scoped sports files, new `godot/tests/sports/progression*`, and this new tools/docs/evidence directory are changed. No primary merge/push is performed.
