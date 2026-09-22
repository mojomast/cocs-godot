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
| Asset provenance/parity | Asset audit 9 tests pass; frozen inventory/rights review; owned-render cleanup 4 tests pass | Original blank GLB and causal culling experiments retained | Meridian blank-sky cause independently reproduced at `70e9075`; four private graphical cases and numerical audit pass | Production export correction and original-art parity OPEN |
| Gameplay catalog/analyzer/recorder | 29 catalog/recorder, 5 rocket recorder/navigation, 9 health/damage checks pass | Original and independent recordings retained, including failed rocket approach | Rocket/15s return PASS at `3991990`; nonlethal damage/+35 health/12s return PASS at `f7b586d` with 876 snapshots | Maximum-HP cap, modifier variants and broader playable scenarios OPEN |
| Guest workflow | 7 harness tests pass | Historical final and failed runs archived losslessly | All four cases PASS at `86ef719`: positive, invalid room, actual 120s host wait timeout and HTTP-rejected handshake | Guest UI/results/focus acceptance separate |
| Trace correlation | 13 tests pass; 11 synthetic, 2 real owned-process cleanup | Final historical run replayed: 333 snapshot / 647 input receipt matches | PASS at `86ef719`: 333 snapshot / 644 input receipt matches; disabled 0 trace records; deliberate timeout fails and cleans up | Neutral headless window only; native completion unproven |
| Death / respawn | Real defect regression failed 10 assertions before fix; now 2,497 control / 15 lifecycle checks pass | Original passing run and genuine premature-respawn failure retained | Two runs PASS at `7e505f2`; combined focus/lifecycle confirmation PASS at `bda5af2`: 352 snapshots, held Ctrl/fire, authoritative camera reseed and fresh-click gating | Programmatic input-path milestone established; OS focus/hardware acceptance separate |
| Focus / click / pointer | Attached-window regression fails before fix, passes 7/7 after | Original focus leak and passing corrected subagent run retained | Independent combined-runtime private X11 run PASS at `5e8136d`: 76/76, 424 queue/receipt matches | Click, confinement, Escape, transition/settled focus, held-control return and fresh-click recovery pass; hardware/Wayland/human review OPEN |
| Host setup / map selection | 95 selection checks, 25 scoreboard checks and 15 team-score checks pass | Original and new graphical menu logs retained | All three maps × DM/Instagib/TDM/Rockets session smoke PASS across retained runs; graphical Verdant/Rockets menu Start independently PASS | Four native modes enabled on three combat maps; authoritative Red/Blue team totals |
| Native world / entities | All-nine-map smoke and 1,341 solids / 17,166 triangle compatibility independently pass; 52 entity checks pass | All nine overview renders independently captured and image-inspected at `e2fd1d3`; real native Meridian capture after integration | Integrated Meridian authority-backed capture at `edc222f` | Distinct palettes, landmark geometry and sports markings visible; broad route/hardware review OPEN |
| Combat overlay / audio / scoreboard | Overlay fixture inspected; 37 audio/integration checks and scoreboard fixtures pass | Synthetic render previews and audio notes retained | Authority event integration exercised by current session captures; no human listening acceptance | Human sound mix and broader HUD usability review OPEN |
| Puma driving / sports | 19 Puma, 27 controls, 41 polish checks and 7 evidence-validator tests independently pass | Both resolutions × both maps near-wall PNGs inspected after polish | Independent driving rerun PASS at `b55861f`; reverse, turn, brake/boost receipts, release/resume and Ion reset | Compact HUD and box-aware camera; completed laps, goals, human camera usability and sports results/restart OPEN |
| Weapon selection / compact HUD | 64 graphical weapon checks; HUD scene gates; 29 current/legacy health evidence tests pass | Two-resolution HUD, live Tab team scores and actual hurt/heal images inspected | Five key/wheel switches PASS; visible HUD damage/+35 HP/12s return independently PASS at `9a8d59e`: 1,065 correlated snapshots, 316 rendered observations, 1,854 receipts | Current HUD and drawn hurt pulse accepted in bounded scenario; human sound/usability and heal-to-cap OPEN |
| Rocket combat | 27 projectile checks plus 12 navigation tests pass | Three Rocket Arena images, graphical menu and corrected DM pickup/fire image inspected | Three maps PASS Rocket Arena; DM pickup → switches `[0,1]` → 12 launches independently PASS at `cb908db`; original failed route retained | Source-aware acceptance navigation corrected; human audio/full-round rocket acceptance OPEN |
| LATTICE command board | 38 adapter and 10 UI checks independently pass | Original failures retained; two-resolution receipt and disconnect PNGs inspected | Handler cases all four map/modes PASS; native mouse/key cases both PvP maps + Asterion co-op independently PASS at `aca52f5`, 28/28/20 checks; 12 FLUX and one Fighter confirmed | Receipts fit 960×640; engine-input path accepted, OS-device automation/co-op economy/full world interaction OPEN |
| LATTICE map view | 23 map checks plus adapter38/UI10 pass | Independent two-resolution map receipts and disconnect images inspected | At `c982d25`, Map checks26 × both PvP maps/Asterion co-op PASS; all three original List cases PASS | Clickable public-coordinate diagram; explicit HOLD acceptance, no implied capture/topology/distance |
| CTF / Payload demo | 19 renderer, 11 adapter-control and 8 evidence-validator checks pass | Original failures retained; original and independent 1280×800/960×640 images inspected | At `d498479`, Tidal pickup/carry/drop PASS with 609 correlated snapshots; Sunscar push/idle PASS with 118 | Standalone slice; close-up labels/HUD polish, return/capture, contest/delivery and results/restart OPEN |
| Common launcher | Three routing regressions pass; all standalone pairs checked against locked catalog | Six native startup/cleanup logs retained | Real pinned headless scenes for all six standalone maps exit cleanly with owned processes absent and server ports closed | One command family for combat/sports/objectives/LATTICE; interactive mode has no harness deadline |
| Native CI | Official pinned archive/hash, fresh npm install and GLB generation checked | Hosted run/report retained | Ubuntu GitHub Actions run `35677168297` passes all 50 gates at `a12d89f` | Fresh-checkout automation accepted; graphical/hardware gameplay separate |
| Full verifier | All **52** implemented gates pass after tactical-map integration | Original failures and earlier pass reports retained | Complete rerun at `c982d25` plus map gate passes, including objective, launcher and LATTICE map gates | See `reports/verification.json`; graphical/playable gates separate |
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
| Tidal Citadel | CTF, teamdeathmatch, domination, assault, team-elimination | Standalone CTF pickup/carry/drop independently pass; return/capture, vehicles and other modes open |
| Sunscar Convoy | Payload, assault, combined-arms, teamdeathmatch, domination, VIP escort | Standalone Payload push/idle independently pass; contest/delivery, vehicles and other modes open |
| Asterion Relay | LATTICE (`cocs`, `cocs-coop`) | Native mouse/key command-board/HOLD/PvP Fighter acceptance; co-op economy, traversal and full objective gameplay open |
| Monsoon Foundry | LATTICE (`cocs`, `cocs-coop`) | Native mouse/key PvP command acceptance; co-op physical input/economy, traversal and full objective gameplay open |
| Ion Speedway | `puma-race` | Standalone native driving, compact HUD, box-aware chase and source reset independently pass; lap completion and results/restart open |
| Aurora Stadium | `puma-soccer` | Standalone native driving, compact HUD, box-aware chase and ball/score state independently pass; goal scoring and results/restart open |

## Release blockers carried forward

- Native operators, pickups, environment, combat overlay, procedural audio and
  scoreboard are implemented; animation, broader visual/audio quality and human
  usability need completion/review. Exact source reproduction is not required. The pulse-rifle
  preview has no accepted completion report.
  Meridian's blank GLB preview is now traced to exported sky `BackSide` semantic
  loss; a private culling-only experiment reveals the map, not full art parity.
  A production GLB exporter correction remains open; the default native
  environment now uses its own procedural sky and does not depend on that GLB.
- The combined 52-gate verifier passes with rocket presentation, sports
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
