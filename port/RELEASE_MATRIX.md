# DESTINATIONS release matrix

This is an exercised port laboratory. Passing tools, headless gates or merged
branches does not establish a completed game port. Locked scope remains
`contracts/map-selection.json` at source `51289b79c627a26a381ba556b92bab71f93f3732`.

Owner direction: this need not be a 1:1 port. Godot-native improvements and
time-saving substitutions are welcome while preserving scope and gameplay
intent. Visual comparisons inform quality; exact original-art/effect parity is
not itself a release requirement. Historical parity reports retain their original
claims and limitations. Native presentation quality and usability still need review.

## Evidence levels and current acceptance

| Area | Synthetic/offline | Saved genuine evidence | Independently rerun live | Graphical / playable acceptance |
|---|---|---|---|---|
| Asset provenance/parity | Asset audit9, cleanup4 and GLB-side6 geometry checks pass | Original blank GLB, experiments and repaired matched captures retained | At `0af3c51`, ten fresh exports/nine sky imports and historical/current before/after independently PASS; 1,057 source hashes unchanged | Production BackSide export loss fixed; hard sky/haze edges, original-art fidelity and rights remain OPEN |
| Gameplay catalog/analyzer/recorder | 29 catalog/recorder, 5 rocket recorder/navigation, 9 health/damage checks pass | Original and independent recordings retained, including failed rocket approach | Rocket/15s return PASS at `3991990`; nonlethal damage/+35 health/12s return PASS at `f7b586d` with 876 snapshots | Maximum-HP cap, modifier variants and broader playable scenarios OPEN |
| Guest workflow | 7 harness tests pass | Historical final and failed runs archived losslessly | All four cases PASS at `86ef719`: positive, invalid room, actual 120s host wait timeout and HTTP-rejected handshake | Guest UI/results/focus acceptance separate |
| Trace correlation | 13 tests pass; 11 synthetic, 2 real owned-process cleanup | Final historical run replayed: 333 snapshot / 647 input receipt matches | PASS at `86ef719`: 333 snapshot / 644 input receipt matches; disabled 0 trace records; deliberate timeout fails and cleans up | Neutral headless window only; native completion unproven |
| Death / respawn | Real defect regression failed 10 assertions before fix; now 2,497 control / 15 lifecycle checks pass | Original passing run and genuine premature-respawn failure retained | Two runs PASS at `7e505f2`; combined focus/lifecycle confirmation PASS at `bda5af2`: 352 snapshots, held Ctrl/fire, authoritative camera reseed and fresh-click gating | Programmatic input-path milestone established; OS focus/hardware acceptance separate |
| Focus / click / pointer | Attached-window regression fails before fix, passes 7/7 after | Original focus leak and passing corrected subagent run retained | Independent combined-runtime private X11 run PASS at `5e8136d`: 76/76, 424 queue/receipt matches | Click, confinement, Escape, transition/settled focus, held-control return and fresh-click recovery pass; hardware/Wayland/human review OPEN |
| Host setup / map selection | 95 selection checks, 25 scoreboard checks and 15 team-score checks pass | Original and new graphical menu logs retained | All three maps × DM/Instagib/TDM/Rockets session smoke PASS across retained runs; graphical Verdant/Rockets menu Start independently PASS | Four native modes enabled on three combat maps; authoritative Red/Blue team totals |
| Native world / entities | All-nine-map smoke and 1,341 solids / 17,166 triangle compatibility independently pass; 52 entity checks pass | All nine overview renders independently captured and image-inspected at `e2fd1d3`; real native Meridian capture after integration | Integrated Meridian authority-backed capture at `edc222f` | Distinct palettes, landmark geometry and sports markings visible; broad route/hardware review OPEN |
| Combat overlay / audio / scoreboard | Overlay fixture inspected; 37 audio/integration checks and scoreboard fixtures pass | Synthetic render previews and audio notes retained | Authority event integration exercised by current session captures; no human listening acceptance | Human sound mix and broader HUD usability review OPEN |
| Puma driving / sports | 19 Puma, 27 controls, 41 polish, 32 progression checks and 7 original evidence-validator tests pass | Near-wall, lap/guidance, results and restart PNGs inspected | At `e76acdb`, Ion one full lap/90s results PASS; Aurora 60s results PASS; both F5 cleanup, neutral/held-key gate and fresh movement PASS | Source guidance and round flow accepted; local-driver goals, target-lap victory and human camera usability OPEN |
| Soccer targeting | 45 guidance checks plus original119 pass | Agent bot-goal PNGs directly inspected and source receipts independently audited | At `4eb0e36`, both real-source stationary resolutions PASS; seven archived bot/own goals verified, zero local goals | Ball/goal guidance and post-fix goal/reset notification accepted; local-driver scoring OPEN |
| Weapon selection / compact HUD | 64 graphical weapon checks; HUD scene gates; 29 current/legacy health evidence tests pass | Two-resolution HUD, live Tab team scores and actual hurt/heal images inspected | Five key/wheel switches PASS; visible HUD damage/+35 HP/12s return independently PASS at `9a8d59e`: 1,065 correlated snapshots, 316 rendered observations, 1,854 receipts | Current HUD and drawn hurt pulse accepted in bounded scenario; human sound/usability and heal-to-cap OPEN |
| Rocket combat | 27 projectile checks plus 12 navigation tests pass | Three Rocket Arena images, graphical menu and corrected DM pickup/fire image inspected | Three maps PASS Rocket Arena; DM pickup → switches `[0,1]` → 12 launches independently PASS at `cb908db`; original failed route retained | Source-aware acceptance navigation corrected; human audio/full-round rocket acceptance OPEN |
| LATTICE command board | 38 adapter and 10 UI checks independently pass | Original failures retained; two-resolution receipt and disconnect PNGs inspected | Handler cases all four map/modes PASS; native mouse/key cases both PvP maps + Asterion co-op independently PASS at `aca52f5`, 28/28/20 checks; 12 FLUX and one Fighter confirmed | Receipts fit 960×640; engine-input path accepted, OS-device automation/full world interaction OPEN |
| LATTICE co-op recruitment | 91 economy checks plus adapter38/UI10/map23 and selected source60 pass | Both independent 960×640 purchases, window wait and disconnect PNGs inspected | At `642c615`, both maps PASS natural window, one matching done REINFORCE, spent +50/spawned +1/REQ spent unchanged; all six original input regressions PASS | Co-op economy accepted in owned sessions; full campaign, concurrent per-unit attribution and human review OPEN |
| LATTICE map view | 23 map checks plus adapter38/UI10 pass | Independent two-resolution map receipts and disconnect images inspected | At `c982d25`, Map checks26 × both PvP maps/Asterion co-op PASS; all three original List cases PASS | Clickable public-coordinate diagram; explicit HOLD acceptance, no implied capture/topology/distance |
| LATTICE world traversal | 18 recipient/control contracts and all-four-route startup pass | Independent Asterion/Monsoon walk images inspected | At `6116f12`, Asterion56.075m/444 samples and Monsoon59.037m/469 samples PASS; 17 native + 8 external checks each | Source-world approach/release/resume accepted; Monsoon dies near node; no local capture in these runs, full strategy rounds OPEN |
| CTF / Payload initial slice | 19 renderer, 11 adapter-control and 8 evidence-validator checks pass | Original failures and initial two-resolution images retained | At `d498479`, Tidal pickup/carry/drop PASS with 609 correlated snapshots; Sunscar push/idle PASS with 118 | Historical baseline; later progression/HUD acceptance is recorded below |
| Objective progression / HUD | 33 HUD/lifecycle and 10 replay/corruption checks pass | Independent panel HUD, capture, contest, checkpoint, results and restart PNGs inspected | At `ffa6aac`, CTF return/capture/60s results/restart PASS, 1,871 correlations; Payload 80 contest snapshots/checkpoint1/90s results/restart PASS, 2,767 correlations | Compact HUD/progression accepted; later completion evidence below; combat/death interactions OPEN |
| Objective completion | 22 corruption/replay checks and queued-input timing fixture pass | Original failed CTF retained; new full acceptance images inspected | At `db0c3ee`, Payload148 rollback/79 bank samples/full delivery124.4s PASS, 3,801 correlations; CTF actor0→2 pass20.367s/capture37.9s/settled release/restart PASS, 1,870 correlations | Natural delivered win and teammate pass accepted; human play, broader combat/objective scenarios OPEN |
| Common launcher | Five routing regressions pass; all standalone pairs checked against locked catalog | Six original scene startups plus four LATTICE world combinations retained | Real pinned headless scenes exit cleanly with owned processes absent and server ports closed | One command family includes separate LATTICE world/board; interactive mode has no harness deadline |
| Native CI | Official pinned archive/hash, fresh npm install and GLB generation checked | Hosted successes and original audio failure retained | Ubuntu GitHub Actions run `35680987135` passes all 62 gates at `3600791`, including objective completion and LATTICE world contracts | Fresh-checkout automation accepted; graphical/hardware gameplay separate |
| Full verifier | All **62** implemented gates pass after objective completion and LATTICE world integration | Original failures and earlier pass reports retained | Complete rerun at `6116f12` plus launcher/completion/world gates passes | See `reports/verification.json`; graphical/playable gates separate |
| Pulse rifle preview | No completion commit available | None reviewed | Owner believes work is not finished | Pending; reserved directories untouched |

The actual commands, clean execution tree hashes, source provenance, receipt vs
ACK distinction and timeout failure are in
`reports/native-trace-independent/README.md` and its indexed archive.
This table is updated as new runs are actually reviewed, not from anticipated
subagent results.

## Nine-map scope (no replacements)

All nine have semantic manifest/viewer coverage. That is not original-art,
mode-specific interaction or playable acceptance. Exact supported modes remain
the locked JSON contract; the family summary below does not narrow them.

| Map | Identity retained | Current native acceptance gap |
|---|---|---|
| Meridian Exchange | Infantry combat/objective modes | Native rocket/health pickups, nonlethal damage and death/respawn accepted; presentation quality and broader playable review open |
| Verdant Reliquary | Infantry modes plus campaign | Deathmatch/Instagib native movement/fire/ACK and graphical menu Start pass; broader modes/campaign and routes open |
| Ember Crucible | Infantry combat/objective modes | Deathmatch/Instagib native movement/fire/ACK pass; broader modes and routes open |
| Tidal Citadel | CTF, teamdeathmatch, domination, assault, team-elimination | Standalone CTF pickup/drop/return/pass/capture and results/restart independently pass; vehicles and other modes open |
| Sunscar Convoy | Payload, assault, combined-arms, teamdeathmatch, domination, VIP escort | Standalone Payload push/contest/banked rollback/full delivery and results/restart independently pass; vehicles and other modes open |
| Asterion Relay | LATTICE (`cocs`, `cocs-coop`) | Map/List/HOLD/PvP Fighter/co-op REINFORCE and native world traversal independently pass; full objective rounds open |
| Monsoon Foundry | LATTICE (`cocs`, `cocs-coop`) | Map/List/HOLD/PvP Fighter/co-op REINFORCE and native world traversal independently pass; full objective rounds open |
| Ion Speedway | `puma-race` | Source checkpoint guidance, full lap and natural time-limit results/F5 restart independently pass; target-lap victory and human play open |
| Aurora Stadium | `puma-soccer` | Native driving, compact HUD, source ball/score and natural results/F5 restart independently pass; local-driver goal scoring open |

## Release blockers carried forward

- Native operators, pickups, environment, combat overlay, procedural audio and
  scoreboard are implemented; animation, broader visual/audio quality and human
  usability need completion/review. Exact source reproduction is not required. The pulse-rifle
  preview has no accepted completion report.
  Meridian's blank GLB preview is now traced to exported sky `BackSide` semantic
  loss; a private culling-only experiment reveals the map, not full art parity.
  The production GLB exporter correction now passes independent matched-camera
  review and all-nine-map imports; hard sky/haze boundaries remain. The default
  native environment uses its own procedural sky and does not depend on that GLB.
- The combined 62-gate verifier passes with rocket presentation, sports
  camera/HUD polish, source-aware projectile navigation and compact LATTICE
  command modules and standalone objectives. Focused native LATTICE mouse/key
  and objective interaction follow-ups also pass.
- Bounded native death/respawn and private-X11 focus milestones now have
  independent acceptance. Default weapon pickup/15s return also independently
  passes, as do nonlethal damage and health pickup/12s return.
  Lethal round-ending results/restart and mode-specific gameplay remain open.
- Native recording lacks a terminal completion marker and direct protocol IDs.
  Current harnesses may supply explicit boundaries and limited association;
  they cannot turn error/limit/forced exit into successful native completion.
- Asset rights remain unresolved: missing repository redistribution grant,
  Moth input/output rights, and OmniVoice/model/output lineage. Music has
  documented CC0 declarations/notices that must be preserved. See
  `asset-audit/HANDOFF.md`; inspection is not legal clearance.
- Prediction, adverse-network behavior and cross-renderer/hardware acceptance
  remain open. Race, soccer and LATTICE are required scope, not optional cuts.
