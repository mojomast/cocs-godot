# Native player-facing usability audit

**Decision:** fix the mirrored sports directions and misleading setup availability first. Then give players a visible way to leave/switch experiences, and make LATTICE state and objective approach guidance more explicit.

This is an **agent heuristic audit with observed UI evidence, not human playtesting**. Six short, fresh graphical package flows took **372.85 seconds total**. All 46 raw fresh PNGs and five archived PNGs listed below were opened with an image-capable tool. No runtime changes were applied.

## Executive top five

| Priority | Finding / classification | Impact and smallest useful fix | Assignment |
|---|---|---|---|
| **1 · High** | **Sports Left/Right cues are mirrored — confirmed defect.** | Advice steers newcomers away from the visible gate/ball. Correct the presentation bearing sign using the camera/vehicle right vector; verify visible left/right targets in both sports. | Lead → sports presentation owner; no simulation change needed. |
| **2 · High** | **Setup calls supported experiences “pending” — confirmed copy/discovery defect.** | A player can conclude six maps are unavailable and stop searching. Distinguish “separate launcher” from genuinely pending modes; display the exact supported route. | Lead owns setup/common launcher/package integration. |
| **3 · Medium** | **Escape releases input but provides no leave/switch menu — design recommendation.** | Combat, sports, objectives and world require closing the client and relaunching a CLI route to switch experiences. Add a small session menu and an experience entry screen; expose existing restart eligibility. | **Collision: external multiplayer lobby / leave / retry + shared session/network.** Assign through that owner. |
| **4 · Medium** | **LATTICE tells experts about receipts more clearly than it tells newcomers what state they are in — observed omissions + design recommendation.** | World shows the same “LIVE” and generic resume instructions engaged/released/unfocused; board uses `cocs`, raw team IDs and order jargon without a first objective. Add explicit control-state feedback, readable HUD backing, and a one-sentence mode/first-action explanation. | Lead coordinate with **active world co-op acceptance**; delivered command-panel owner for presentation. |
| **5 · Medium** | **Payload explains escort rules but not where to go — design recommendation.** | On the sampled spawn, the cart is not identifiable from the forward view; the HUD's metres are route progress, not distance to cart. Add a labelled cart bearing/distance and approach marker using public authority coordinates. | Lead → objective presentation; **coordinate Sunscar combined-arms owner**. |

“High” means wrong or blocking guidance on a supported flow; “Medium” means recoverable friction that requires outside knowledge. The navigation and onboarding proposals are not claims that already accepted gameplay is broken.

## Findings with reproduction and source anchors

The `node run.mjs` commands below assume the package directory as the working directory. Desktop resolution is the stated native client area; automated reproduction uses the runner near the end of this report.

### 1. Sports direction text contradicts the chase view

**Fresh evidence:** [Ion after restart, 1280×800](race/07-restart.png): the gate centre/ground arrow is to the **right** of the Puma, while the HUD says `Next gate 1 · Left · 9 m`. [Aurora driving, 960×640](soccer/02-driving.png): the yellow ball is well to the **right**, while the HUD says `Ball Left · 34 m`. [Stationary Aurora](soccer/04-stationary-bearing.png) also places the ATTACK goal right of the car but says `Opponent goal Left`.

**Reproduce:**
1. Run `node run.mjs --experience=sports --map=ion-speedway`; wait for Racing without driving. Inspect gate 1 and the direction line. The retained fresh run used the supported extra option `--time-limit=60`; [restart image](race/07-restart.png) reproduces the original pose without the early capture artifact.
2. Run `node run.mjs --experience=sports --map=aurora-stadium`; after kickoff press Enter, hold W about two seconds, release, then Escape. Compare ball or ATTACK-goal lateral position with the HUD (bot ball motion varies).

**Implementation:** [guidance.gd:80–88](../../godot/sports/guidance.gd#L80), [soccer_guidance.gd:78–87](../../godot/sports/soccer_guidance.gd#L78), [chase.gd:87–100](../../godot/sports/chase.gd#L87), [demo.gd:218–220](../../godot/sports/demo.gd#L218). Both bearing functions label positive `atan2(dx,dz)-yaw` as Right. The camera looks along `(sin(yaw),0,cos(yaw))`; its screen-right vector is `(-cos(yaw),0,sin(yaw))`. Positive bearing therefore points camera-left. This source explanation corroborates the actual PNGs; it is not a log-only visual judgement.

**Small fix:** derive side from that right-vector dot product (or reverse the label sign after checking conventions). Keep Ahead/Behind thresholds. Add a visual two-sided regression when implementing; current completion acceptance can pass despite reversed coaching.

### 2. Default setup hides real availability behind “pending”

**Fresh evidence:** [map options](combat/02-map-options.png), [Ion selected](combat/03-ion-pending.png), contrasted with [working race](race/08-resumed.png). The setup explicitly says `Native gameplay pending for ion-speedway`, disables Start, and gives no sports-launch route. The same menu marks objective and LATTICE maps pending.

**Reproduce:** run `node run.mjs`; open the map selector and choose Ion Speedway. Then close the client and run `node run.mjs --experience=sports --map=ion-speedway`. The latter launches supported play. The menu's combat-only capability restriction is legitimate; the unqualified player-facing availability message is misleading.

**Implementation:** [match_setup.gd:23–28](../../godot/ui/match_setup.gd#L23), [85–96](../../godot/ui/match_setup.gd#L85), [118–130](../../godot/ui/match_setup.gd#L118), versus [package route table:2–7](../../tools/godot-package/options.mjs#L2) and [help:49–64](../../tools/godot-package/options.mjs#L49).

**Small fix:** name this screen “Combat setup”; mark supported external routes “Separate demo” and show the exact command/experience name. A later unified picker can invoke the same supported route table. Preserve genuinely pending statuses, including modes outside the baseline capability subset. **Deferred campaign is not a requirement for this audit.**

### 3. Release is discoverable; leave/switch is not

**Fresh evidence:** [combat Escape](combat/13-escape.png), [Payload Escape](payload/03-release.png), [sports results](race/06-time-results.png), [LATTICE closed panel](world/05-panel-closed.png). None offers a leave/experience-switch control. Board is a useful exception: [Disconnect](board/07-disconnected.png) exposes setup again and [Connect/start](board/08-coop-switched.png) creates a fresh PvP session.

**Reproduce:** launch default combat, click Start, click the world, then Escape. Try to find a route to sports or return to setup. Repeat from sports results: F5 offers a new round in the same experience. At this baseline, switching those routes means closing the window (or launcher Ctrl+C), then issuing another `node run.mjs --experience=…` command. **There is no observed in-app cross-experience navigation.**

**Implementation:** [session.gd:106–125](../../godot/world/session.gd#L106), [346–355](../../godot/world/session.gd#L346), [game_hud.gd:172–197](../../godot/ui/game_hud.gd#L172), [sports/hud.gd:131–167](../../godot/sports/hud.gd#L131), [board.gd:147–181](../../godot/lattice/board.gd#L147), [package help:64](../../tools/godot-package/options.mjs#L64).

**Small fix:** an Escape session panel with Resume, eligible Restart, Leave and experience selection. Retain the accurate `match continues` explanation; do not imply the authority pauses. While launcher switching remains CLI-only, show that honest exit/relaunch guidance in-app. Sports F5 versus infantry Enter is adequately labelled at results, so harmonizing keys is lower priority than discoverable navigation. Existing results-only restart is a limitation, not a failed fresh restart test.

### 4. LATTICE needs a player-oriented state/goal layer

**Fresh evidence:** [board idle](board/01-idle.png), [board connected](board/02-connected.png), [board Map + receipts](board/06-purchase.png); world [released](world/05-panel-closed.png), [engaged](world/06-resumed.png), [unfocused](world/07-unfocused.png), [returned](world/08-returned.png). World keeps `LIVE · HP … · ACK …` and `Release movement/action keys before clicking to resume` in every state. A small crosshair changes, but there is no explicit RELEASED / UNFOCUSED status like the sports HUD. On the bright building, white text depends on a heavy shadow and the entire top-left block competes with world labels. This is observed presentation, not a claim of failed movement neutralization.

The board's Connect/start, resources, distinct action receipts and price checkbox are usable. But `cocs`, `cocs-coop`, `Team 0`, `Issue HOLD / GO`, and `confirmed — replaced` explain protocol more readily than purpose. The Map legend uses **0 blue / 1 coral** ([map_view.gd:98–103](../../godot/lattice/map_view.gd#L98)); world markers use **0 red / 1 blue** ([world_hud.gd:33–34](../../godot/lattice/world_hud.gd#L33)). Consider aligning these within LATTICE.

**Reproduce:** run `node run.mjs --experience=lattice --map=asterion-relay --mode=cocs`; click Connect/start, select WEST / ARCHIVE GATE, Issue HOLD / GO, then List → Map. Separately run `node run.mjs --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop`; click/W, Escape, C, select WEST / FILTER COURT and Issue HOLD, C to close. Compare the HUD after click-to-resume and an OS focus-away/return. The fresh command capture shows **pending (server accepted)**; this audit does not claim co-op HOLD completion or recruitment.

**Implementation:** [board.gd:64–71](../../godot/lattice/board.gd#L64), [95–125](../../godot/lattice/board.gd#L95), [212–251](../../godot/lattice/board.gd#L212); [world_demo.gd:24–36](../../godot/lattice/world_demo.gd#L24), [190–193](../../godot/lattice/world_demo.gd#L190); [world_commands.gd:58–77](../../godot/lattice/world_commands.gd#L58), [148–167](../../godot/lattice/world_commands.gd#L148).

**Small fix:** backed, compact world status with explicit engagement/focus state; move ACK to diagnostics. Use readable PvP/co-op names and a short source-accurate “what HOLD controls / what to do first” hint. In co-op, show wave/window context where recipient state permits it. Preserve honest unavailable-window and receipt distinctions; **coordinate with the active world-co-op acceptance lane before touching its surface**.

### 5. Objective rules need an approach cue

**Fresh evidence:** [Payload spawn](payload/01-ready.png) and [one-second approach](payload/02-engaged.png). The panel clearly states ESCORT, IDLE, checkpoints and the rule, but no visible cue identifies how to reach the cart. Distant world text is tiny against the geometry. The displayed `0.0 / 165.6 m` is payload route progression, not a player-to-cart range.

**Reproduce:** `node run.mjs --experience=objectives --map=sunscar-convoy`; inspect the initial forward view, click and walk forward for one second. Decide where to go using only the UI. This is a bounded first-impression sample, not proof that the cart cannot be found by exploration.

**Implementation:** [renderer.gd:62–71](../../godot/objectives/renderer.gd#L62), [145–168](../../godot/objectives/renderer.gd#L145), [hud.gd:38–45](../../godot/objectives/hud.gd#L38). The world marker has a small world-space font and range bound; the HUD exposes route progress without approach bearing/range.

**Small fix:** a public-position cart waypoint with direction/range and a clearer escort-radius cue on approach. For CTF, consider equivalent home/enemy-flag guidance, but **CTF start navigation was only source/archived reviewed here**. Its archived HUD already explains pickup, E pass/drop and capture well. Avoid claiming terrain-aware routing from a simple bearing.

## Positive findings and coverage

- **960×640 combat/Payload:** health/armor, named weapon and ammo panels are readable, separated and fit. Payload rules/status compose cleanly with them. Escape explicitly says the match continues. Fresh combat shows a tracer, health dropping 100→52 and armor 5→0; attribution and audio were not assessed.
- **Sports:** clear ENTER → fresh movement and ESC release guidance, useful lap/checkpoint/score separation, OWN/ATTACK labels and shot coaching. Fresh Ion crossed checkpoint 1, reached natural **time-limit** results, restarted with F5, then moved after Enter + fresh W. This was not a lap victory. Soccer coaching fits 960×640, though its large upper panel uses about a third of the height.
- **Recovery:** fresh Payload and race focus-away/return show explicit paused/released feedback and a deliberate re-engage prompt. World tactical Close/C and click-to-resume visibly returned to traversal. No held-input or network acceptance claim is made.
- **LATTICE:** board List/Map, HOLD receipt, one Fighter receipt, Disconnect/reconnect and the co-op world panel were observed. The world panel clearly explains unavailable between-wave recruitment and distinguishes accepted from completed. A temporary “Repeated activation suppressed” status appears even with successful receipts; calmer cooldown wording would help but is secondary to the top five.

| Sample | Fresh resolution / duration | Fresh actions and image review | Limits / archived supplement |
|---|---|---|---|
| Combat setup → Meridian DM | 960×640 / 89.71 s | All [13 PNGs](combat/); pending-map selection, Start, capture, W/fire, Escape, focus cycle | Early automation selected Aurora accidentally; corrected before Start. Focus-return anomaly noted below; no full match. |
| Ion race | 1280×800 / 88.48 s | All [8 PNGs](race/); Enter/W, checkpoint, release/focus, 60 s time results, F5/Enter/W | No lap completion. [Archived 960×640 victory](../native-sports-victory/evidence/dea1d370-7fba-4280-8e4c-8e06850b9159/960x640/results.png) opened: target reached, #1 You, readable F5 instruction. |
| Aurora soccer | 960×640 / 39.54 s | All [4 PNGs](soccer/); engage, two-second drive, release, ball/goal bearing | No goal attempted. [Archived 1280×800 goal feedback](../native-sports-victory/evidence/9c72f6c8-6b15-4a90-a7b3-11c64c68c7f8/1280x800/end.png) opened: Red 1:0, goal/reset notification. |
| Sunscar Payload | 960×640 / 32.47 s | All [5 PNGs](payload/); start, approach, release/focus-return | No escort/completion attempted. [Archived delivered result](../native-objective-completion/evidence/58399317-d086-4f6d-814d-d09b03af2afb/gameplay-results.png) opened: 100%, 3/3, winner, Enter restart. |
| Asterion LATTICE board PvP | 960×640 / 85.27 s | All [8 PNGs](board/); connect, List/Map, HOLD/Fighter receipts, disconnect/reconnect | Reconnect was still PvP; attempted keyboard co-op selection did not take. No full strategy round or economic attribution. |
| Monsoon LATTICE world co-op | 1280×800 / 37.38 s | All [8 PNGs](world/); traverse/release, C, HOLD accepted, close/resume, focus | No natural recruitment window wait/purchase; owned by another lane. |
| Tidal CTF | **Archived only**, 1280×800 | Opened [teammate carry](../native-objective-completion/evidence/1c249468-b8f4-42e7-ae30-97430fdbb2a9/gameplay-pass.png) and [results](../native-objective-completion/evidence/1c249468-b8f4-42e7-ae30-97430fdbb2a9/gameplay-results.png): objective instructions, carrier, team score, Enter restart readable | Existing [completion acceptance](../reports/objective-completion-independent/README.md) supplies long pass/capture/restart evidence; this lane did not replay it. |

Archived sports outcomes use [sports-victory-independent](../reports/sports-victory-independent/README.md), runtime `8a58c97`; objective outcomes use runtime `db0c3ee`. Archived review is not a fresh exported-package acceptance claim. Existing [world-command acceptance](../reports/lattice-world-commands-independent/README.md) was read for command semantics and limits, not rerun.

## Baseline, environment and cleanup

- Worktree `/tmp/opencode/native-usability-audit`, branch `audit/native-usability`; baseline **`83e4aff175eeef47c9ceab5714bad162ce9b32a6`**. Read README, release matrix and active-lane reservations before sampling. Campaign deferred; Arms Race, zone, Horde, pulse assets and lobby implementations are outside this baseline audit.
- Private copy `/tmp/opencode/usability-package-83e4aff` of the approved `.../builds/1790049033430669279/cocs-native-linux`; launched its unmodified official `run.mjs`. Package port revision **`8a58c97e48493e41903c2c9a729e753cb3579500`**, locked simulation **`51289b79c627a26a381ba556b92bab71f93f3732`**. **All 189 manifest build-input files match this baseline checkout; all 111 packaged file hashes still match after play.** Changes since packaged revision in inspected runtime/tool paths are UID sidecars and verification tooling. See [provenance.json](provenance.json).
- PCK SHA256 `4d7b8eb47afc7bce5f63d349dec817d348b0b0eac809c8f2e0f3fc568a6b51f4`; executable `3c0994716982c2f557f7738a789269074520ac0c0a3f11bb7a84a34ee96c683d`; manifest `babb513fe1ad519aa929dadd1a3a0d8347d747934358b1dc94ce9b21192d0814`. Per-script, runtime tree and PNG hashes are in provenance.
- Linux x86_64, Node **22.23.1**, Python **3.13.7**, Godot **4.5.2.stable.official.6ce3de25a** release executable. Private Xvfb screen 1600×1000×24, native windows resized to the specified viewports; `-nolisten tcp -nolisten unix`, isolated XDG directories. `PORT=0`; package authority itself binds a fresh loopback port. Normal-rate source, ordinary XTest input, no state/time/physics edits. No editor used. ALSA was unavailable and Godot fell back to dummy audio; VSync warning retained. Audio/hardware/Wayland/human usability not assessed.
- Cleanup receipts: [combat](combat/cleanup.json), [race](race/cleanup.json), [soccer](soccer/cleanup.json), [payload](payload/cleanup.json), [board](board/cleanup.json), [world](world/cleanup.json). All six show `PACKAGE_STOPPED`, launcher/client/Xvfb PIDs absent and owned ports closed (**34077, 46299, 34585, 45307, 40665, 36665**). Launcher exit 130 is deliberate owned Ctrl+C cleanup. Shared 4332, gallery and other worktrees/services were not used.

### Reproduce the bounded sample

[runner.py](runner.py) uses the existing read-only private-X11 helper and standard-library PNG capture; each supervisor has a 240-second ceiling. Run one flow at a time from this worktree. Its `ROUTES` table records all exact CLI routes; each flow also has `session.json`, `actions.jsonl`, `runtime.log` and `cleanup.json`.

```sh
# Terminal 1 (or harness background):
python3 -B port/native-usability-audit/runner.py start race \
  --package /tmp/opencode/usability-package-83e4aff --width 1280 --height 800
# Terminal 2, after active.json exists:
python3 -B port/native-usability-audit/runner.py action shot ready
python3 -B port/native-usability-audit/runner.py action key Return
python3 -B port/native-usability-audit/runner.py action key w 2
python3 -B port/native-usability-audit/runner.py action key Escape
python3 -B port/native-usability-audit/runner.py action stop
```

Use a fresh copy of this evidence directory/worktree for reruns to preserve these raw files. `provenance.py` rechecks package integrity and baseline input equivalence without launching gameplay.

### Honest failures and evidence limits

- `combat/runtime.log` and `board/runtime.log` also retain Godot `focus_entered` / `tree_exited` duplicate or nonexistent signal-connection errors from these popup/focus sessions. Their cause was not isolated within the sampling budget; do not treat these runs as clean engine-regression passes. Visual interaction continued and cleanup succeeded. All routes retain the separate expected ALSA/dummy-audio fallback.
- `combat/04-start.png` through `06-release.png` are **still setup**, despite planned filenames. Home/Return did not select the intended map; `07-reopen.png` documents recovery. `08-started.png` onward is actual combat. A focus-away image shows the paused prompt, but this initial helper's return capture retained a crosshair; no fresh combat focus-reset PASS is asserted. Later Payload/race focus cycles used a settled one-second transfer and showed the expected re-engagement prompt.
- `race/01-start.png` and `02-driving.png` contain a right-edge **capture-helper sink occlusion**, not a game defect. The sink was moved outside both sample viewports; `03-results.png` is actually released play at 0:35, not results. `06-time-results.png` is the genuine terminal state. No screenshot was retouched or replaced.
- `board/08-coop-switched.png` is **PvP reconnect**, not co-op: the attempted dropdown keyboard change did not take. The screenshot and source expose mode selection, but fresh successful cross-mode switching is unproven. The world sample separately starts co-op through its official CLI route.
- These screenshots establish observed presentation. There are no new authority-correlated completion/held-key/network claims. Full rounds, additional combat maps, CTF first-spawn navigation, co-op recruitment, audio and hardware remain outside the finite sample. Ownership collisions above are assignment guidance, not permission for this review lane to implement them.
