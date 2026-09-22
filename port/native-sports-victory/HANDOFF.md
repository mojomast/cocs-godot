# Native target victory and soccer shot coaching

Isolated worktree `/tmp/opencode/native-sports-victory`, branch `subagent/native-sports-victory`, base `013ad65`. Scope: narrow sports presentation, new `godot/tests/sports/practice*`, and this directory. No shared source, networking, world, launcher, package or root-document changes.

## Important source finding: solo practice is unsupported

The requested premise that `botCount:0` permits a solo soccer host is false at this base:

- `game/config.mjs:289` **normalizes** zero, but this is not the final match setup.
- `game/core.mjs:452` then sets soccer bot count to `max(0,min(3,4-humanCount))`, independent of the requested bot count. With one real human this is **three bots**.
- `game/config.mjs:349` explicitly documents that empty soccer seats are always filled and zero requested bots still produces 2v2.
- `server/room.mjs` uses the normal Match constructor. Existing sports hosting already requests zero bots. This explains why earlier attempts still faced three bots.

`source-config.mjs` reproducibly proves the distinction without stepping a match: caller configuration stays unchanged, normalized count is zero, effective count is three, and public roles contain one human plus three bots. There are no fake human seats, idle peer substitutes, bot-policy changes or source mutations. Native wire receipts independently record host requests and actual roster.

Accordingly, **zero-bot practice remains blocked**. `--practice` and `--practice=...` now fail explicitly before connection instead of being silently ignored and misleadingly launching a bot match. The error explains the source limitation. No “solo practice” label or accepted solo goal is claimed.

## Human usability shipped

The passive `godot/sports/practice.gd` shot coach uses the validated existing soccer target selection and public ball/car/opponent geometry. Its wrapping HUD row gives actionable advice: get behind on the OWN-goal side, line up car → ball → ATTACK goal, brake and turn, push/boost when aligned, and approach side-board balls from the open pitch. Both team orientations work. It is labeled **Shot practice**, an instruction rather than a different game mode. It never presses keys or changes simulation/configuration. Normal bots and rules remain the source defaults.

All existing `demo.hud.text`, marker selection, input eligibility, progression/results and F5 semantics remain available. Coaching clears with the existing missing/stale/results gates.

## Native evidence approach

```sh
python3 -B port/native-sports-victory/run.py           # original 164 + new coaching checks
python3 -B port/native-sports-victory/run.py --race    # target=1, both native sizes, F5 checks
python3 -B port/native-sports-victory/run.py --visual  # stationary normal soccer, both sizes
python3 -B port/native-sports-victory/run.py --attempt 1 # explicit ordinary-bot attempt, max 175 s
python3 -B port/native-sports-victory/run.py --attempt 2 # optional second/final attempt only
node port/native-sports-victory/source-config.mjs
```

The new race observer inherits the accepted source-gate lookahead route. It changes only acceptance expectations: ordinary `--round-target=1`, full 17-gate progression, source `race-finish` event, winner ID, completed lap and non-null finish time. It waits for actual winning results rather than the clock. F5 checks immediate cleared references/markers/camera, held-W blocking, Enter-only neutrality and fresh-W accepted displacement. Wire auditing distinguishes arrival from ACK/application.

All driving uses native `InputEventKey` plus Godot's normal buffered event dispatch. Test drivers only read recipient snapshots; no direct handlers, input packets, state writes, source clocks, teleports or seed selection. Fresh owned normal-rate servers bind `127.0.0.1:0`. A private Xvfb disables TCP/Unix listeners. Mesa software rendering and Dummy audio use pinned Godot `4.5.2.stable.official.6ce3de25a`. Private projects symlink the primary dependencies read-only. Commands, full source/script/Godot/Node/ws hashes, generated hashes, inputs, ACK/state samples, events, results and cleanup are retained per run.

### Soccer plan and bounds

Source inspection preceded the new driver: contact radius is `CAR_RADIUS 1.7 + ball.r 1.1`, contact inherits the normal chassis velocity with a lateral slice, and goals require an outward swept plane crossing inside half-width and height. Goal team denotes defender. The event last-touch actor must equal the human and the scored team must equal their own team, with an adjacent source score increment and visible GOAL/reset notification. Bot goals and local own goals do not qualify.

The new test-only driver approaches a point 5.5 m behind the public predicted ball, uses a short velocity horizon, commits with alignment hysteresis, and follows through towards the opponent. It clamps chassis waypoints inside source board faces. Near a side board, the reflected goal permits a reachable inward approach and ordinary bank bounce. Sharp headings brake using the ordinary low-speed steering assist; jams get bounded reverse maneuvers. No actor/ball writes or source modifications. Unlike the originally requested zero-bot plan, any attempts here are explicitly **ordinary bot-filled 2v2**.

Maximum two attempts, each bounded to 175 observer seconds (below 180), no rerolls/restarts/retries to search for a favorable scoring match. Prior archives remain unchanged and prior bot goals stay bot goals.

## Unapplied lead integration proposal

Do **not** forward `--practice` as though zero bots works at this base. A true solo preset needs an explicit source-supported configuration contract and a narrowly reviewed exception to forced soccer filling; those changes are outside this agent's ownership and were not applied. Only after that upstream capability exists should the launcher forward `--practice`, the native host request it, and the accepted roster validate zero bots. Forwarding alone cannot implement it.

The existing ordinary launcher can consume the shot-coaching HUD without new arguments. Race target verification uses the already supported direct native `--round-target=1` argument. No launcher edit is included.

## Results and retained attempts

A helper `PASS` for a bounded soccer attempt only means evidence and cleanup passed; local scoring requires `provenLocalGoals` to be nonempty.

### Race target victory accepted, both sizes

[`evidence/3bd1c1f4-80c7-49c8-9091-aa188d7ce703/summary.json`](evidence/3bd1c1f4-80c7-49c8-9091-aa188d7ce703/summary.json), hash-manifest SHA-256 `dc36cc5278bf312928403af128e50f11a39acb0e316268a6e92088d4c2748779`.

- **960×640:** source `race-finish` actor 0, lap 1, finish time **42.689 s**; **1,068** input arrivals across victory and restart.
- **1280×800:** source `race-finish` actor 0, lap 1, finish time **42.825 s**; **1,214** input arrivals across victory and restart.
- Both observations follow expected gate indices **0,1,…,16,0** before the winning crossing. Source results say `overReason:race-finish`, `winnerId:0`, `laps:1`, `completedLaps:1`, with a non-null finish time. The configured clock was 180 seconds, not the finish cause.
- Both execute F5 once, clear all inherited state, keep held W blocked, stay still after Enter alone, and then demonstrate ACK-backed displacement after release/repress W. The audit records displacement at the fresh-input capture; the observer's later end displacement includes natural coasting after release.
- All original **119 + 45** checks and new **21** coaching/option checks passed (**185 total**), no script/engine errors. Every owned process reaped, zero server sockets, private project removed.
- Direct image-tool review: both `results.png` show **Lap target reached · 0:42 / #1 You · Finished 0:42**, with unobscured released controls and F5 instructions. `960x640/restart-enter-neutral.png` shows engaged **0.0 m/s**, initial gate and fresh round. `1280x800/restart-fresh-driving.png` shows **11.7 m/s** and the original source gate marker. HUD panels/labels fit with no overlap.

The race run predates addition of the soccer observer, constructor receipt and offline auditor. Its production source hashes match the final sports code; the historical runner difference is retained rather than rewriting that manifest.

### Local soccer goal accepted on first bounded attempt

[`evidence/ce29cbd1-2f72-42b6-b03d-a7c82c4509ff/summary.json`](evidence/ce29cbd1-2f72-42b6-b03d-a7c82c4509ff/summary.json), hash-manifest SHA-256 `3385812166aebdef2bccb8ffbf145ff1e6383a9e2d06a4ebf15af43c7d36684d`.

**This is an ordinary three-bot match and a genuine local goal. It is not zero-bot practice.** No second scoring attempt was made.

- 1280×800; ordinary host requested `mode:puma-soccer, botCount:0, timeLimit:180, fragLimit:15`. Effective public source configuration is `botCount:3`, with actor 0 the Red human, actors 1/3 Blue bots and actor 2 a Red bot.
- Local goal **event 12**, source match time **151.300 s** (playing elapsed **148.300 s**, after the normal 3-second kickoff), owned-server wall **151,425 ms**. `actorId:0`, `scorerId:0`, `team:0`, at the **opponent Blue goal (44,0)**.
- Before: snapshot **4538**, ACK **2883**, ball **(43.611,1.1,-1.343)** moving **(14.360,1.546)** in x/z; local chassis **(40.523,0,-1.454)**, velocity **(14.483,2.284)**; Red **4**, Blue **3**, local credited goals **0**.
- After: snapshot **4541**, ACK **2885**, ball reset exactly to **(0,1.1,0)** at zero velocity; Red **5**, Blue **3**, local credited goals **1**. Same source role and unmodified physics/configuration.
- The observer stops after the goal notification: final playing elapsed **149.333 s**, final ACK **2904**, **2,905** input arrivals, **10** ordinary reverse recoveries. The 175-second bound was not exhausted.
- Seven preceding goals belong to bots: two ordinary bot goals and five bot own goals. They are retained separately and do not count as local acceptance.
- Direct image review of **`1280x800/end.png`** confirms **Red 5 / Blue 3**, **Red GOAL · Ball reset to centre**, the local Puma beside the Blue ATTACK goal and released controls. The ball itself is behind the camera at centre; its exact reset is established by the public snapshot. `goal.png` is the **first Blue bot goal**, explicitly not the local-goal proof. `driving.png` shows readable live shot coaching and all four ordinary cars.
- Original **164** plus new **21** checks pass, all source/sports hashes match. Cleanup verifies zero sockets, reaped children and removed private project.

The offline auditor additionally requires opponent-goal event geometry, local actor/team/bot status, score and local credited-goal increments, centre reset and a **post-local-event** native capture containing that team's GOAL/reset notification. This closes the distinction between an earlier bot-goal screenshot and actual local-goal visibility. The runner was strengthened to require the same visibility condition after this run; existing receipts pass the stronger offline audit without replaying or altering the attempt.

### Coaching visuals and source configuration receipts

[`evidence/6a3e6772-7066-456a-b370-745e085e736f/summary.json`](evidence/6a3e6772-7066-456a-b370-745e085e736f/summary.json), manifest SHA-256 `1e782724d4eccab3b27a6573a6f01404f7fb1db773c6811eddba9264e8f54314`.

Both stationary `guidance.png` files were directly inspected at **960×640** and **1280×800**. The extra coaching row is fully readable, including its arrows and Space-brake instruction; the existing roles, ball bearing, source markers, scoreboard and bottom controls remain visible. No overlapping panels or clipped labels. These seven-second stationary observers send neutral controls and are not extra scoring attempts. Both have zero goal events. All **185** checks pass again with the complete new observer set imported.

Both visual and scoring directories retain `source-config.json`, proving normalized zero becomes three soccer bots without mutation of caller options. Actual public snapshots confirm the same effective configuration.

### Final offline audit

```sh
python3 -B port/native-sports-victory/audit.py
```

[`evidence/audit.json`](evidence/audit.json), SHA-256 **`2ad44cdf21e0317427058eeb9b8b6da74cb7d9e11b055a6f8dcb89b319b4fc9e`**:

- **Three runs, five native cases, exactly one scoring attempt. One local non-own goal, seven bot goals, zero local own goals.** No new failed scoring run or second attempt.
- **Zero production/source hash differences** across all runs. Historical helper changes are explicitly named (`run.py`, plus the later auditor revision where present). No old manifests/logs/images were rewritten.
- Source/owned-wall ratios: race **1.02278 / 1.00604**; soccer scoring **1.01368**; stationary visuals **0.99808 / 0.99168**. Default source scheduler throughout. Scoring ended at owned wall **152,576 ms**, within the bound.
- Race restart neutral arrivals **87 / 120**, fresh capture ACKs **113 / 140** versus Enter-only ACKs **86 / 119**, and accepted fresh displacement **7.775 / 6.957 m**.
- Every retained artifact has byte length and SHA-256; the auditor records its own digest. Every summary confirms reaped processes and removed private projects; every server confirms closed with zero sockets.
- Godot binary SHA-256 `5803746bbe055bee0f07a3c5b0dd347719bd45599f3d34519a8a0beaf83014ae`; Node `93956de2e59480474a7b46571da1651180b1a050cdf32641ebec4ce6e478e068`; read-only ws tree `c0dc2e2d4228652d0f4f653026eb2f85a0777177d34ec9a485260ebf82b9ef8d`. Per-run manifests pin all script/source/export hashes.

## Failed-attempt knowledge retained for the lead

Read first: `port/native-soccer-play/HANDOFF.md`, its `run.py`/`server.mjs`, and `port/native-sports-progression/HANDOFF.md`. Those archives are untouched.

- The older progression attempt stayed around **(-38.747,18.884)** despite reporting nonzero velocity; velocity-only stuck detection was misleading. Position displacement remains the recovery signal.
- The two prior soccer-play attempts failed to produce a local goal, while bots produced seven goals. Their behind-ball targets could become unreachable beside source boards, and goal attribution needed both actor and team checks. They remain failed local-goal attempts, not upgraded by this new success.
- This new successful attempt still needed **10 recoveries**; the steering helper is not a guaranteed goal solver. The last ten exact public car/ball coordinates, waypoints, strategies, held keys and ACKs are preserved in the audit. Source collision edges and changing bot contacts remain relevant, even though the final aligned approach succeeded.
- The false zero-bot assumption was caught before any practice preset was advertised. `botCount` normalization alone is insufficient evidence; inspect the actual Match constructor and public roster. A future true practice mode requires source ownership and explicit supported configuration.

**Accepted:** target-winning race and F5 fresh-input behavior at both sizes; actionable passive soccer shot coaching; a legitimate human-driver, non-own soccer goal with source increment, centre reset and visible native notification in an ordinary bot match. **Blocked:** the requested zero-bot host preset, because this source unconditionally fills soccer seats. No merge or push performed.
