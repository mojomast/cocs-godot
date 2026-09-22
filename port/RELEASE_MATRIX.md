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
| Host setup / map selection | 94 selection checks, 25 scoreboard checks and 15 team-score checks pass | Six original automatic combinations and graphical menu logs retained | All three maps × DM/Instagib PASS; TDM native session smoke independently PASS on all three, plus three normal TDM rounds/scoreboard checks at `5ce0ae0` | TDM enabled with authoritative Red/Blue totals; Rocket authority also checked but its native projectile presentation remains pending |
| Native world / entities | All-nine-map smoke and 1,341 solids / 17,166 triangle compatibility independently pass; 52 entity checks pass | All nine overview renders independently captured and image-inspected at `e2fd1d3`; real native Meridian capture after integration | Integrated Meridian authority-backed capture at `edc222f` | Distinct palettes, landmark geometry and sports markings visible; broad route/hardware review OPEN |
| Combat overlay / audio / scoreboard | Overlay fixture inspected; 37 audio/integration checks and scoreboard fixtures pass | Synthetic render previews and audio notes retained | Authority event integration exercised by current session captures; no human listening acceptance | Human sound mix and broader HUD usability review OPEN |
| Puma presentation | 19 synthetic checks independently PASS at `e2fd1d3` | Independent private-Xvfb render inspected | No live driving acceptance | Standalone renderer integrated; sports session/chase-camera follow-up assigned externally |
| Weapon selection / compact HUD | 64 graphical actual-session weapon checks; HUD ordinary/setup/debug scene gates pass | Two-resolution native HUD renders and synthetic lifecycle previews independently image-inspected | At `3a049d5`: real rocket pickup and five key/wheel switches, 470 input receipts / 14 weapon commands; held-key recapture suppression passes | Current visible HUD health/damage acceptance update in progress; old hidden labels no longer prove visibility |
| Full verifier | All **40** implemented gates pass after setup/fixture corrections | Original `edc222f` failure and subsequent 7-failure continuation retained; unparented fixture environment/light diagnosed | Complete rerun at `5ce0ae0` plus this integration batch passes, including HUD/setup/debug, team scores, Puma, live lifecycle/restart and two clients | See `reports/feature-batch-independent/`; graphical/playable gates separate |
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
| Tidal Citadel | CTF, teamdeathmatch, domination, assault, team-elimination | Vehicles/objectives/native session and visual acceptance open |
| Sunscar Convoy | Payload, assault, combined-arms, teamdeathmatch, domination, VIP escort | Convoy/vehicles/objectives/native session and visual acceptance open |
| Asterion Relay | LATTICE (`cocs`, `cocs-coop`) | Native LATTICE orders/economy/traversal/objectives and art open |
| Monsoon Foundry | LATTICE (`cocs`, `cocs-coop`) | Native LATTICE orders/economy/traversal/objectives and art open |
| Ion Speedway | `puma-race` | Native driving, checkpoints/laps, race HUD and presentation open |
| Aurora Stadium | `puma-soccer` | Native driving, ball/goals/scoring and presentation open |

## Release blockers carried forward

- Native operators, pickups, environment, combat overlay, procedural audio and
  scoreboard are implemented; animation, broader visual/audio quality and human
  usability need completion/review. Exact source reproduction is not required. The pulse-rifle
  preview has no accepted completion report.
  Meridian's blank GLB preview is now traced to exported sky `BackSide` semantic
  loss; a private culling-only experiment reveals the map, not full art parity.
  A production GLB exporter correction remains open; the default native
  environment now uses its own procedural sky and does not depend on that GLB.
- The combined 40-gate verifier passes after fixture ownership and setup fixes.
  Rocket Arena remains pending real projectile and launch/explosion feedback;
  stronger default-HUD health/damage acceptance is being integrated separately.
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
