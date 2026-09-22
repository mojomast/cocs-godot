# DESTINATIONS release matrix

This is an exercised port laboratory. Passing tools, headless gates or merged
branches does not establish a completed game port. Locked scope remains
`contracts/map-selection.json` at source `51289b79c627a26a381ba556b92bab71f93f3732`.

## Evidence levels and current acceptance

| Area | Synthetic/offline | Saved genuine evidence | Independently rerun live | Graphical / playable acceptance |
|---|---|---|---|---|
| Asset provenance/parity | Asset audit 9 tests pass; frozen inventory/rights review; owned-render cleanup 4 tests pass | Original blank GLB and causal culling experiments retained | Meridian blank-sky cause independently reproduced at `70e9075`; four private graphical cases and numerical audit pass | Production export correction and original-art parity OPEN |
| Gameplay catalog/analyzer/recorder | 29 tests pass, including loopback mock recorder | Sparse accelerated capture insufficient; new native death evidence below | Death milestone independently rerun; native rocket pickup reported PASS, sanitization review pending | Health pickup, nonlethal damage and broader playable scenarios OPEN |
| Guest workflow | 7 harness tests pass | Historical final and failed runs archived losslessly | All four cases PASS at `86ef719`: positive, invalid room, actual 120s host wait timeout and HTTP-rejected handshake | Guest UI/results/focus acceptance separate |
| Trace correlation | 13 tests pass; 11 synthetic, 2 real owned-process cleanup | Final historical run replayed: 333 snapshot / 647 input receipt matches | PASS at `86ef719`: 333 snapshot / 644 input receipt matches; disabled 0 trace records; deliberate timeout fails and cleans up | Neutral headless window only; native completion unproven |
| Death / respawn | Real defect regression failed 10 assertions before fix; now 2,497 control / 15 lifecycle checks pass | Original passing run and genuine premature-respawn failure retained | Two runs PASS at `7e505f2`; combined focus/lifecycle confirmation PASS at `bda5af2`: 352 snapshots, held Ctrl/fire, authoritative camera reseed and fresh-click gating | Programmatic input-path milestone established; OS focus/hardware acceptance separate |
| Focus / click / pointer | Attached-window regression fails before fix, passes 7/7 after | Original focus leak and passing corrected subagent run retained | Independent combined-runtime private X11 run PASS at `5e8136d`: 76/76, 424 queue/receipt matches | Click, confinement, Escape, transition/settled focus, held-control return and fresh-click recovery pass; hardware/Wayland/human review OPEN |
| Full verifier | All 30 implemented gates pass after both runtime corrections | First attempt failed at inherited occupied PORT=4332; retained | `PORT=0` rerun passes, including new window-focus gate, live movement/fire, normal-rate results/restart and two native clients | Visual/playable gates remain separate |
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
| Meridian Exchange | Infantry combat/objective modes | Prototype deathmatch only; intentional pickups, full presentation and playable review open |
| Verdant Reliquary | Infantry modes plus campaign | Native sessions/modes, original art and routes open |
| Ember Crucible | Infantry combat/objective modes | Native sessions/modes, original art and routes open |
| Tidal Citadel | CTF, teamdeathmatch, domination, assault, team-elimination | Vehicles/objectives/native session and visual acceptance open |
| Sunscar Convoy | Payload, assault, combined-arms, teamdeathmatch, domination, VIP escort | Convoy/vehicles/objectives/native session and visual acceptance open |
| Asterion Relay | LATTICE (`cocs`, `cocs-coop`) | Native LATTICE orders/economy/traversal/objectives and art open |
| Monsoon Foundry | LATTICE (`cocs`, `cocs-coop`) | Native LATTICE orders/economy/traversal/objectives and art open |
| Ion Speedway | `puma-race` | Native driving, checkpoints/laps, race HUD and presentation open |
| Aurora Stadium | `puma-soccer` | Native driving, ball/goals/scoring and presentation open |

## Release blockers carried forward

- Original models, animations, shaders, effects, audio and visual comparison are
  incomplete; the pulse-rifle preview has no accepted completion report.
  Meridian's blank GLB preview is now traced to exported sky `BackSide` semantic
  loss; a private culling-only experiment reveals the map, not full art parity.
  A production exporter correction and environment behavior remain open.
- Bounded native death/respawn and private-X11 focus milestones now have
  independent acceptance. Intentional weapon pickup is awaiting sanitized
  evidence review; nonlethal damage/health pickup is executing in isolation.
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
