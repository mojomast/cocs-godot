# DESTINATIONS release matrix

This is an exercised port laboratory. Passing tools, headless gates or merged
branches does not establish a completed game port. Locked scope remains
`contracts/map-selection.json` at source `51289b79c627a26a381ba556b92bab71f93f3732`.

Owner direction: this need not be a 1:1 port. Godot-native improvements and
time-saving substitutions are welcome while preserving scope and gameplay
intent. Visual comparisons inform quality; exact original-art/effect parity is
not itself a release requirement. Historical parity reports retain their original
claims and limitations. Native presentation quality and usability still need review.

Campaign direction has changed: the owner wants an entirely new campaign and
has deferred implementation until substantial planning and research. The old
campaign is not the new design specification; the draft handoff is inactive.

## Evidence levels and current acceptance

### Graphics expansion — September 22, 2026

The owner requested parallel graphics development, new native showcase maps and
massive-particle experiments. The original nine-map gameplay catalog is retained.
Five additional routes are standalone native exploration/material laboratories.

| Addition | Implemented and exercised | Remaining acceptance |
|---|---|---|
| Moth resources/world | 101 exact pixel planes; triplanar albedo/normals; all-nine atmosphere/scenery; 36 integrated map captures; bounded scenery with popup-free F8 detail cycling | Final expanded package and broad hardware/human readability |
| First-person weapons | Ten source-derived weapon GLBs; hands, isolated viewport, source recoil/reload; 57 rig/15 binding fixtures; original switching live runs; shared three-map rounds/results/restarts | Broader weapons/modes, hardware/mouse/audio review; skeletal hand IK/ADS not implemented |
| Combined-arms graphics | 65 composition checks, 43 inherited control checks and 68 synthetic graphical checks; infantry/Puma transitions | Live combined-arms graphics and package review |
| Prism Foundry | Three-room reactor complex, mezzanine/ramp loop and deck; 49 native physics/lifecycle checks, eight real X11 input checks and 12 inspected captures | Final exported route, hardware and human exploration |
| Aurora Basin | Landing/lake/crown routes and aurora; 593 lane checks; shared production walker traversal rerun passes | Final exported route and independent desktop usability |
| Cinder Array | Six-area caldera/bridge/gantry/tunnel loop; production ramp-junction repair; 1246 assertions and both 16-waypoint circuits with zero off-floor frames/resets | Final exported route and hardware/human exploration |
| Particle Observatory | Stateful Compatibility GPUParticles3D and explicit analytic alternative; actual 8K–1M counts; 183 checks, 13 render sweeps, stable resize cycles | Hardware GPU performance; million-particle stress is ~462 ms median on software rendering |
| Moth Shader Gallery | Three reusable materials; 68 contracts and two-resolution visual tests; actual clock/LUT/normal contributions and pause stability | Packaged shader include/resources and hardware review |

Initial integrated graphics passed 96 aggregate gates. Expanded-map/scenery/lab
gates are being integrated; historical and new failures remain archived. The first
Windows export's exact PCK resolves all Moth/weapon resources under a Linux release
runtime. This is not a Windows graphical capture or final expanded-release claim.
See `graphics-batch/README.md` and the per-lane reports for scope and provenance.

| Area | Synthetic/offline | Saved genuine evidence | Independently rerun live | Graphical / playable acceptance |
|---|---|---|---|---|
| Asset provenance/parity | Asset audit9, cleanup4 and GLB-side6 geometry checks pass | Original blank GLB, experiments and repaired matched captures retained | At `0af3c51`, ten fresh exports/nine sky imports and historical/current before/after independently PASS; 1,057 source hashes unchanged | Production BackSide export loss fixed; hard sky/haze edges, original-art fidelity and rights remain OPEN |
| Gameplay catalog/analyzer/recorder | 29 catalog/recorder, 5 rocket recorder/navigation, 9 health/damage checks pass | Original and independent recordings retained, including failed rocket approach | Rocket/15s return PASS at `3991990`; nonlethal damage/+35 health/12s return PASS at `f7b586d` with 876 snapshots | Maximum-HP cap, modifier variants and broader playable scenarios OPEN |
| Guest workflow | 7 harness tests pass | Historical final and failed runs archived losslessly | All four cases PASS at `86ef719`: positive, invalid room, actual 120s host wait timeout and HTTP-rejected handshake | Guest UI/results/focus acceptance separate |
| Trace correlation | 13 tests pass; 11 synthetic, 2 real owned-process cleanup | Final historical run replayed: 333 snapshot / 647 input receipt matches | PASS at `86ef719`: 333 snapshot / 644 input receipt matches; disabled 0 trace records; deliberate timeout fails and cleans up | Neutral headless window only; native completion unproven |
| Death / respawn | Real defect regression failed 10 assertions before fix; now 2,497 control / 15 lifecycle checks pass | Original passing run and genuine premature-respawn failure retained | Two runs PASS at `7e505f2`; combined focus/lifecycle confirmation PASS at `bda5af2`: 352 snapshots, held Ctrl/fire, authoritative camera reseed and fresh-click gating | Programmatic input-path milestone established; OS focus/hardware acceptance separate |
| Focus / click / pointer | Attached-window regression fails before fix, passes 7/7 after | Original focus leak and passing corrected subagent run retained | Independent combined-runtime private X11 run PASS at `5e8136d`: 76/76, 424 queue/receipt matches | Click, confinement, Escape, transition/settled focus, held-control return and fresh-click recovery pass; hardware/Wayland/human review OPEN |
| Host setup / map selection | 95 selection checks, 25 scoreboard checks and 15 team-score checks pass | Original and new graphical menu logs retained | All three maps × DM/Instagib/TDM/Rockets session smoke PASS across retained runs; graphical Verdant/Rockets menu Start independently PASS | Four native modes enabled on three combat maps; authoritative Red/Blue team totals |
| Multiplayer lobby / spectator | Lobby33, context66, lead scene31/layout75×2 and popup-free selector63 PASS | Original release-popup failures preserved; inline selector avoids that engine path; final exported PNGs inspected | Lead rebuilt exported flow95.343s:82 checks,156 audit assertions,3855 source/native matches including1464 spectator applications; zero engine errors | Bounded exported Create/Join/move/fire/Leave/spectator/results/fresh guest/restart PASS; other menus' popup issues and human input OPEN |
| KOTH / Domination | 42 adapter/render checks and 3 route tests pass | Original failed Verdant route retained; independent two-size gameplay/results PNGs inspected | Independent Meridian Bravo capture/50.6 points and Verdant Alpha capture/17.25 points/rotation, natural60s results/restart PASS | Zero-bot native capture/scoring accepted for these pairs; live contest, rotated-hill capture and other pairs OPEN |
| Combined-arms Puma | 43 native checks; strengthened 9-case replay suite passes | Independent 960×640 mounted and1280×800 released PNGs inspected; original failures retained | Independent15.38s walk/mount/25.678m drive/brake/exit/3.118m infantry PASS;332/332 receipts,357 snapshots,3570 vehicle roots | Bounded Puma driving accepted; secondary chassis are visual/exit-only previews, broader vehicle combat and human camera review OPEN |
| Arms Race | 55 release-safe native checks, 38 source tests and inherited controls/HUD pass independently | Promotion1280×800 and timed-results960×640 PNGs opened by reviewer and lead | One independent Meridian attempt: local kill/source promotion8.217s/rung2 Rocket Launcher; all three arena startups; natural60s results/restart/fresh8.72m movement PASS | Bounded promotion/lifecycle accepted; full ten-rung victory and human play OPEN |
| Local Horde adapter | Lead50 adapter/validator,70 source/UI,15 model and31 input/3 look-vector checks PASS; public Room unchanged | Both historical HOLDs/event defects/visual failures retained; final results/restart and six exported startup PNGs inspected | Final repair:810 source-object/wire-event matches,378 native snapshots, genuine one-wave victory/restart; final package six default10 startups,881 public snapshots PASS | Bounded local adapter/common route/exported startup accepted; ten-wave/boss/defeat/upgrades/hardware/audio OPEN; small Tab board overlaps lower HUD |
| Native world / entities | All-nine-map smoke and 1,341 solids / 17,166 triangle compatibility independently pass; 52 entity checks pass | All nine overview renders independently captured and image-inspected at `e2fd1d3`; real native Meridian capture after integration | Integrated Meridian authority-backed capture at `edc222f` | Distinct palettes, landmark geometry and sports markings visible; broad route/hardware review OPEN |
| Combat overlay / audio / scoreboard | Overlay fixture inspected; 37 audio/integration checks and scoreboard fixtures pass | Synthetic render previews and audio notes retained | Authority event integration exercised by current session captures; no human listening acceptance | Human sound mix and broader HUD usability review OPEN |
| Puma driving / sports | Original119 plus guidance45 and coaching21 checks pass | Independent two-resolution target-victory and restart PNGs inspected | At `8a58c97`, Ion all17 gates / one-lap victory43.028s and43.129s PASS; F5 held-W block, Enter-only neutral, fresh displacement6.367m/6.175m PASS | Source guidance, target victory and round flow accepted; human camera usability/longer races OPEN |
| Soccer targeting / scoring | 45 guidance + 21 coaching checks pass; constructor/public roster prove forced bots | Original bot goals retained; independent Red1/Blue0 local-goal PNG directly inspected | At `8a58c97`, local Red actor0 scores at Blue goal at138.867s playing; score0→1/local credit0→1/centre reset and visible notification PASS | Genuine local-driver goal and passive coaching accepted; zero-bot practice unsupported by source; human play OPEN |
| Weapon selection / compact HUD | 64 graphical weapon checks; HUD scene gates; 29 current/legacy health evidence tests pass | Two-resolution HUD, live Tab team scores and actual hurt/heal images inspected | Five key/wheel switches PASS; visible HUD damage/+35 HP/12s return independently PASS at `9a8d59e`: 1,065 correlated snapshots, 316 rendered observations, 1,854 receipts | Current HUD and drawn hurt pulse accepted in bounded scenario; human sound/usability and heal-to-cap OPEN |
| Rocket combat | 27 projectile checks plus 12 navigation tests pass | Three Rocket Arena images, graphical menu and corrected DM pickup/fire image inspected | Three maps PASS Rocket Arena; DM pickup → switches `[0,1]` → 12 launches independently PASS at `cb908db`; original failed route retained | Source-aware acceptance navigation corrected; human audio/full-round rocket acceptance OPEN |
| LATTICE command board | 38 adapter and 10 UI checks independently pass | Original failures retained; two-resolution receipt and disconnect PNGs inspected | Handler cases all four map/modes PASS; native mouse/key cases both PvP maps + Asterion co-op independently PASS at `aca52f5`, 28/28/20 checks; 12 FLUX and one Fighter confirmed | Receipts fit 960×640; engine-input path accepted, OS-device automation/full world interaction OPEN |
| LATTICE co-op recruitment | 91 economy checks plus adapter38/UI10/map23 and selected source60 pass | Both independent 960×640 purchases, window wait and disconnect PNGs inspected | At `642c615`, both maps PASS natural window, one matching done REINFORCE, spent +50/spawned +1/REQ spent unchanged; all six original input regressions PASS | Co-op economy accepted in owned sessions; full campaign, concurrent per-unit attribution and human review OPEN |
| LATTICE map view | 23 map checks plus adapter38/UI10 pass | Independent two-resolution map receipts and disconnect images inspected | At `c982d25`, Map checks26 × both PvP maps/Asterion co-op PASS; all three original List cases PASS | Clickable public-coordinate diagram; explicit HOLD acceptance, no implied capture/topology/distance |
| LATTICE world traversal | 18 recipient/control contracts and all-four-route startup pass | Independent Asterion/Monsoon walk images inspected | At `6116f12`, Asterion56.075m/444 samples and Monsoon59.037m/469 samples PASS; 17 native + 8 external checks each | Source-world approach/release/resume accepted; Monsoon dies near node; no local capture in these runs, full strategy rounds OPEN |
| LATTICE world commands | 27 boundary/consent checks; each co-op archive passes22 audits and8 negative cases | Independent960×640/1280×800 receipts and expired-consent PNGs inspected | PvP12FLUX/+1Fighter; both co-op natural windows/lease expiry/new consent/+50FLUX spent/+1spawn/noREQ spend PASS;35 native checks per map | Same-socket world orders/recruitment and fresh movement accepted; full strategy rounds and human play OPEN |
| World usability / Payload guidance | LATTICE24, Payload geometry823/HUD99 and current-renderer historical replay3792 PASS | Final world released960/engaged1280 and cart off-range960/escort1280 PNGs inspected; initial failures retained | Agent bounded flows verify control-state labels, cart approach/range/escort/release; final bank/role/dead refinements fixture-only | Bearing/range/progress cues accepted in bounded views; obstacle-aware navigation, broad human readability and final960 world engagement OPEN |
| CTF / Payload initial slice | 19 renderer, 11 adapter-control and 8 evidence-validator checks pass | Original failures and initial two-resolution images retained | At `d498479`, Tidal pickup/carry/drop PASS with 609 correlated snapshots; Sunscar push/idle PASS with 118 | Historical baseline; later progression/HUD acceptance is recorded below |
| Objective progression / HUD | 33 HUD/lifecycle and 10 replay/corruption checks pass | Independent panel HUD, capture, contest, checkpoint, results and restart PNGs inspected | At `ffa6aac`, CTF return/capture/60s results/restart PASS, 1,871 correlations; Payload 80 contest snapshots/checkpoint1/90s results/restart PASS, 2,767 correlations | Compact HUD/progression accepted; later completion evidence below; combat/death interactions OPEN |
| Objective completion | 22 corruption/replay checks and queued-input timing fixture pass | Original failed CTF retained; new full acceptance images inspected | At `db0c3ee`, Payload148 rollback/79 bank samples/full delivery124.4s PASS, 3,801 correlations; CTF actor0→2 pass20.367s/capture37.9s/settled release/restart PASS, 1,870 correlations | Natural delivered win and teammate pass accepted; human play, broader combat/objective scenarios OPEN |
| Common launcher | Routing regressions cover ten routes/nine scenes; Horde uses separate reviewed local adapter; explicit lobby endpoint ownership tested | Original startups and expanded release-scene captures retained | Final16 launcher cases PASS; Horde readiness/failure/cleanup and external-server preservation verified | One command family; fixed10wave Horde local-only, external authority never owned by guest launcher; no interactive harness deadline |
| Native CI | Official pinned archive/hash, fresh npm install and GLB generation checked | Hosted successes and original audio failure retained | Ubuntu run `35700075573` passes all88 gates at `fc31852`; downloaded summary retained in `native-windows-package/evidence/hosted-native/` | Operator geometry and prior Horde/ownership gates confirmed hosted; Windows run35700483115 separately passes packaged headless combat |
| Linux prototype package | Official toolchain/ws integrity;84 locked source +2 separately hashed adapter modules; nine scenes/ten routes/nine maps, no tests/probes | Original X11/popup/Horde failures preserved; final114 runtime files/256 build inputs checked | Final16 launcher cases and six Horde map/size startups PASS; prior popup-free package clean full lobby flow separately retained | Editor-free startup and bounded prior lobby lifecycle accepted; full Horde/wider gameplay/human review OPEN |
| Windows operator demo | Official Windows export/Node hashes;119 packaged files verified; explicit staged candidate preload | Original draft-access/quoting failures preserved; exact-PCK Linux preview images reviewed | Native Windows run35700483115: Play.cmd from spaced path, three-map movement/fire/model markers, preview load and process/port cleanup PASS | Downloadable prerelease with bundled Node; Windows graphics/audio/human acceptance OPEN; nonfatal ObjectDB smoke-exit warning retained |
| Procedural operator candidate | Two deterministic rebuilds,112013 checks each; all nine IDs and three geometry variants | Recovered230 staged files; lead inspected40 matched PNGs; prior failures retained | Normal-rate1800 snapshots, movement/yaw and clean results/restart; editor-free preview PASS | Close-range shape improved; default replacement held for distant readability/render cost; enabled explicitly in user-requested Windows demo |
| Full verifier | All **88** implemented gates pass, including new operator geometry | Original failures and outer-deadline interruption retained | Complete local rerun and hosted run35700075573 PASS at Windows build revision fc31852 | See `reports/verification.json` and `native-windows-package/README.md`; graphical/playable gates separate |
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
| Ion Speedway | `puma-race` | Source checkpoint guidance, one-lap target victory, time-limit results/F5 restart independently pass; human play open |
| Aurora Stadium | `puma-soccer` | Native driving/coaching, local-driver goal with centre reset, source ball/score and results/F5 restart independently pass; zero-bot practice unsupported and human play open |

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
- The combined 88-gate verifier passes with operator geometry, rocket presentation, sports
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
