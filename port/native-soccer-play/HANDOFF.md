# Native local soccer guidance and bounded play acceptance

Isolated worktree `/tmp/opencode/native-soccer-play`, branch `subagent/native-soccer-play`, base `e76acdbb48385c638b01a24e3c5997d6e1ce8353`. Only the new soccer helper, narrow sports demo/HUD integration, new `godot/tests/sports/soccer*`, and this directory are owned by this change.

## Player-facing behavior

- `godot/sports/soccer_guidance.gd` consumes public `race.ball`, `race.goals`, `race.pitch`, the accepted local actor's team, and their driver vehicle. It shows source-relative ball direction/distance, identifies OWN and ATTACK goals, and displays restrained source-width colored goal stripes/captions plus a small gold ball marker. Red and Blue identify the actual defending team; OWN/ATTACK text distinguishes friendly/opponent without relying on color.
- `Goal.team` is the **defending** team. The opponent goal is therefore the one whose `team` differs from the authoritative local actor. No Red-local assumption and no hidden-actor targeting.
- Missing local actor/driver, invalid team/geometry, stale authority, results, restart and connection error clear the helper. Selection never changes actor/ball, scores, controls or simulation. Public positions/normals/widths are used directly; no map-coordinate fallback.
- HUD remains mouse-ignoring and unfocusable. `demo.hud.text`, prior observer APIs, race guidance, controls, fleet, chase and progression/results behavior are retained. A wrapping soccer-only row extends the existing top panel naturally at 960×640 and 1280×800.

## Source inspection and changed acceptance approach

Inspected `game/soccer.mjs` and `game/vehicles.mjs`, plus Aurora's geometry in `game/destination-sports-maps.mjs`, before attempting scoring.

- `soccerSnapshot()` publicly exposes ball, goal normals/widths/heights/depths and pitch bounds. Goals are at Aurora's source x=±44, with outward normals and half-width 7; these numbers are documentation only, not gameplay fallbacks.
- `resolveBallCars()` clears overlapping chassis, inherits contact-normal vehicle velocity, adds sideways velocity, and stores the last touching actor. Simply pointing at the ball is insufficient: glancing hits and car collisions can send it sideways.
- `crossSoccerGoals()` requires a swept outward crossing from the inner side of the goal plane, within its finite width and ball-height interval. `scoreGoal()` increments the **opposite** team, emits `soccer-goal` with `actorId` equal to last touch, and immediately resets the ball to centre. An own-goal last touch is not local scoring acceptance.
- Puma has low-speed steering assistance below 3 m/s, source brake deceleration 22 m/s², reverse limited to 6 m/s, normal top speed 20 and boost 26. Native W/S/A/D/Space/Shift exercise these unmodified rules.
- The original retained attempt is `port/native-sports-progression/evidence/da6cd3bb-5c56-4f6c-aeee-62478f01778d/aurora-stadium-1280x800`. Inspection of its wire samples found the local position pinned near **(-38.747, 18.884)** from about 16–131 source seconds while reported velocity remained around (-0.61, 0.70). Its speed-based stuck threshold missed that lack of displacement; no goal occurred.
- The new **test-only** native-key driver approaches 8 m behind the public ball, goes around if ahead of it, commits to an aligned strike, brakes/turns for sharp headings, uses boost only on aligned nearby strikes, and detects jams from accepted position displacement over two samples. Recovery is a bounded ordinary reverse maneuver. It does not write source state, tune bots, change seeds/spawns, inject input packets, or add gameplay autopilot.
- Scoring attempts are explicitly invoked, maximum **two**, each with a 175-second observer wall bound and a fresh owned server. Stationary 7-second visual checks send no driving keys and are not scoring attempts.

## Reproduction

```sh
python3 -B port/native-soccer-play/run.py             # synthetic suites only
python3 -B port/native-soccer-play/run.py --visual    # stationary native views, both sizes
python3 -B port/native-soccer-play/run.py --attempt 1 # one bounded scoring attempt, 1280×800
python3 -B port/native-soccer-play/run.py --attempt 2 # optional second/final attempt, 960×640
```

The helper copies the project/source into a private `/tmp/opencode` directory, uses primary dependencies read-only through a symlink, exports locked semantic geometry, imports pinned Godot, and runs original controls/Puma/polish/progression suites plus new soccer checks. Graphical runs use private Xvfb `-nolisten tcp -nolisten unix`, Mesa llvmpipe, Dummy audio and a fresh owned server bound to `127.0.0.1:0`. No source clock overrides. Test-only observer injects `InputEventKey` through Godot's normal event path, rather than OS keyboard automation.

Each evidence folder records exact commands and SHA-256 hashes of source/scripts/binary and generated content, native/import/test logs, all goal events (including bot/own-goal attribution), public role samples, input-arrival receipts and ACK/state snapshots. A successful local goal requires **event.actorId == local actor**, **event.team == local team**, **local bot == false**, and a matching source score increment. Socket input arrival alone is not proof of application. Cleanup receipts verify zero sockets, owned child reaping, and removal of the temporary project.

## Runtime identity

- Godot `4.5.2.stable.official.6ce3de25a`, SHA-256 `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`.
- Node `/usr/bin/node`, `v22.23.1`, SHA-256 `93956de2e59480474a7b46571da1651180b1a050cdf32641ebec4ce6e478e068`.
- Primary read-only-used `ws` `8.21.3`; sorted `relative-path SHA-256\n` file-tree digest `c0dc2e2d4228652d0f4f653026eb2f85a0777177d34ec9a485260ebf82b9ef8d`.

## Verification evidence

Initial visual and synthetic pass: [`evidence/1f0df218-abe4-49ff-b51b-4bff058cfdcc/summary.json`](evidence/1f0df218-abe4-49ff-b51b-4bff058cfdcc/summary.json), hash-manifest SHA-256 `a191c9a48c9bee850fb52b5e95aa2ffaf78f3d098c4f01b72759eaf55dc50060`.

- Existing controls 27 + Puma 19 + polish 41 + progression 32 = **119 checks passed**. New soccer **45 checks passed**, including both JSON-float teams, own/opponent orientation and colors, nonmutation/reuse, bearing/distance, missing local actor, bad/missing geometry, stale clearing and observer summary compatibility.
- Direct image-tool review of [`960×640/guidance.png`](evidence/1f0df218-abe4-49ff-b51b-4bff058cfdcc/960x640/guidance.png) and [`1280×800/guidance.png`](evidence/1f0df218-abe4-49ff-b51b-4bff058cfdcc/1280x800/guidance.png): all labels/panels fit without overlap; explicit OWN Red / ATTACK Blue, ball direction/distance, opponent bearing/distance, source ball marker and ordinary controls remain visible. Distant world goal captions are small by design; the HUD provides the readable role/direction information.
- Both stationary visual runs cleaned up all owned processes/sockets and temporary files. No goal claim from these checks.

### Attempt 1: local scoring not achieved; real bot goal/reset observed

[`evidence/8c7774f4-316d-4f3d-9c7c-c9653e9f30c7/summary.json`](evidence/8c7774f4-316d-4f3d-9c7c-c9653e9f30c7/summary.json) retained the full 175-second bound, ending at source elapsed **172.900 s**, with **18** displacement-based recoveries. Five real goal events occurred: Blue actor 1 twice, Red actor 2 twice, and Blue actor 3 last-touch on a Red own goal. None was local actor 0. All attribution and source samples are retained. The wrapper's PASS means the bounded attempt and checks completed/cleaned up, **not** local scoring acceptance.

This run used the same source/tool hash manifest as the initial visual checks (`a191c9a48c9bee850fb52b5e95aa2ffaf78f3d098c4f01b72759eaf55dc50060`). It recorded **3,594** input arrivals, final sampled ACK **3,593**, and final server wall sample **177,639 ms** (includes native startup). Every goal's adjacent source-time samples show exactly one team score increment and ball reset to `(0, 0)`. Public roles identify actor 0 as the Red human and actors 1/2/3 as bots.

Directly read [`1280×800/goal.png`](evidence/8c7774f4-316d-4f3d-9c7c-c9653e9f30c7/1280x800/goal.png): actual Blue bot goal, **Red 0 / Blue 1**, corrected **Blue GOAL · Ball reset to centre** notification, centre ball, and OWN Red world caption. This is live post-fix notification evidence, explicitly not a local goal.

Attempt 2 planning: the first run escaped jams but spent time circling source-clamped behind-ball points beside the boards. The second/final driver variant reflects the public opponent goal across the side board for a reachable bank-shot approach and uses ordinary boost on long aligned runs. It also permits a 26 m/s cap while boosting, instead of simultaneously braking at 17 m/s. No gameplay or source changes. The receipt verifier now compares source time around goals, because `Room.tick()` can send the scoring snapshot before its event within the same tick.

### Attempt 2: final bounded attempt; local scoring not achieved

[`evidence/1249d656-97f3-4ca2-92f0-5bb0a5aadfd1/summary.json`](evidence/1249d656-97f3-4ca2-92f0-5bb0a5aadfd1/summary.json), hash-manifest SHA-256 `f71efd183482cfe24d093b27883309fb6ad7468285ae4ef463f63493e5a7f5bc`.

- 960×640; last observer source elapsed **175.533 s**, final server wall sample **177,066 ms**, **12** reverse recoveries, **4,474** input arrivals. Source simulation remained at its normal scheduler rate (1.0208 source seconds per wall second).
- Two real goals, both **Red bot actor 2 own goals for Blue**. Local actor 0 had no goal, and `provenLocalGoals` is empty. Stopped at the bounded attempt deadline; the final Red 0 / Blue 2 screen is an active-round end capture, not time-limit results.
- Directly read [`goal.png`](evidence/1249d656-97f3-4ca2-92f0-5bb0a5aadfd1/960x640/goal.png), [`driving.png`](evidence/1249d656-97f3-4ca2-92f0-5bb0a5aadfd1/960x640/driving.png) and [`end.png`](evidence/1249d656-97f3-4ca2-92f0-5bb0a5aadfd1/960x640/end.png). They show the actual corrected Blue GOAL/reset notification, readable Blue ATTACK and Red OWN world markers, source ball marker/bearing/distance, and passive HUD fit at the smaller size. The final frame shows controls released.
- Final original **119** checks (including progression **32**) and new soccer **45** checks passed: **164 total**. No script/engine errors. Controls/lifecycle code was not changed, so no extra full-round lifecycle replay was necessary.

### Offline receipt audit and limits

```sh
python3 -B port/native-soccer-play/audit.py
```

[`evidence/audit.json`](evidence/audit.json), SHA-256 **`a8e08463c89d38984becab242a7040a5450829db0528a442daab2a8709871b76`**, records:

- Exactly **two** scoring attempts, each below three minutes of owned-server wall time; no retries beyond them.
- Seven real source goals: **four normal bot goals, three bot own goals, zero local-driver goals**. Every event has the source actor/team role, adjacent score increment, ACK/sequence/time and reset ball sample. Nothing is credited to the local player without matching `actorId`, team and score increment.
- Zero current production/source hash differences across all three runs. The first visual/attempt used the earlier test-only driver/verifier; those two tool differences are explicitly listed. The final attempt matches the current recorded scripts. The auditor includes its own hash and runtime identities.
- SHA-256 and byte length for every retained PNG, wire receipt, log, summary and hash manifest. Every run verified closed server/zero sockets, owned-process reaping and removed private project.

**Accepted:** practical passive soccer guidance, both team orientations under synthetic JSON-float tests, both native HUD sizes, real post-fix GOAL/reset notification, and unchanged existing checks. **Not achieved:** a legitimate local-driver goal. The changed driver recovered from the old permanent jam and tried reachable bank approaches, but normal bot contacts and vehicle driving still prevented local scoring within the two bounded attempts. This limit is retained rather than substituting a bot goal or synthetic score. No additional scoring runs were attempted.

Production commit: `fe71fef` (`Add passive source-authoritative soccer guidance`). Tools/evidence are committed separately. No primary edits, push or merge.
