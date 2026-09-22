# Discovery and synthesis

Baseline 3645efdab87870d1dea1548729e2269fbc9ba8f1, isolated subagent/native-horde. Read-only audits completed before implementation. CLI delegation was unavailable (Codex/OpenCode authentication errors; Claude configured model unavailable), so audits were sequential.

## Authority audit
- game/singleplayer.mjs:331–379: initializeSinglePlayer retains actor 0, humanCount=1, botCount=0. Horde starts intermission with three lives, target fragLimit (default 10); endless opt-in.
- game/config.mjs:138 permits bounded targets 1–30; easy first wave has two husks and one spitter after rounding (singleplayer:134–162); seven-second intermission.
- singleplayer:388–408 spawns actual NPC actors. enemy-types.mjs:7 onward defines npcType, role, health, color and scale; core.mjs:1310–1314 publishes actor fields and singleplayer.
- singleplayer:527–542 advances waves only when all authoritative enemies die; awards score/resupply, then wins at target or starts intermission. Upgrades do NOT block progression.
- singleplayer:946–974 detects death count, removes one life, loses at zero, handles regen and time limit. Numeric dead is a timer, not a boolean. Winner 0 is a valid win, not false.
- singleplayer:976–993 public singleplayer contains kind,phase,elapsed,wave,waveTarget,endless,score,bestWave,summary,waveTimer,waveModifier,enemiesAlive,enemiesTotal,kills,deaths,lives,objective,message,winner,boss,bossPhase,bossPhaseName,bossPhaseTotal,upgrades (pending choice objects),upgradeWave,upgradeSelected,upgradeCount,regen plus campaign fields. No local progression is appropriate.
- singleplayer-ui.mjs:25–67/69–82 display projection; do not copy its off-by-one cleared-wave summary blindly.
- CRITICAL: server/room.mjs:983–991 explicitly rejects singleplayer modes as local-only. Shared public server MUST NOT be changed to accept Horde. game/protocol.mjs:29–51 has no Horde upgrade command.

## Native audit
- world/session.gd:231–245 clears round and capture; :297–325 applies authoritative actors/camera and death gates; :351–398 owns native input and neutralization. Subclass it, but initialize independently like objectives/demo.gd to avoid MatchSetup excluding Horde.
- net/client.gd accepts actor ID 0/JSON floats, enforces map and monotonic snapshot sequence, deduplicates events, clears round at start. Keep unchanged.
- world/presentation.gd maintains received actor IDs/removes absent actors; no prediction. Add NPC role labels to existing visual nodes; no duplicate enemies.
- ui/game_hud.gd and scoreboard.gd bind parent client signals deferred; scene composition reuses these, as well as inherited combat/audio. Horde strip must avoid shared HUD regions.

## Acceptance audit and route plan
- port/native-objective-completion/run.mjs provides normal-rate owned server, private Xvfb -nolisten tcp/-nolisten unix, bounded logs, SIGTERM/SIGKILL reaping, PID absence and compressed evidence patterns.
- tests/objectives/completion_live.gd:28–59 uses physical InputEventKey/MouseMotion via Input.parse_input_event. Follow that path, never mutate authoritative actors.
- Existing public network fixture captures are not Horde evidence. Need an explicitly local-only transport adapter around unchanged Match, stepping 1/60 at 1000/60 wall milliseconds, source parseInputEnvelope and ordinary Match.step only. This is new transport, NOT a claim the public room server supports Horde. Upgrade choices can be optional/unsupported initially because source waves never wait for them.
- For first combat attempt hold spawn, aim using real received NPC positions, fire through native mouse events; let melee approach, then approach nearest surviving ranged NPC with W/jump if needed. No seed selection, teleports or source mutation. Another map stands its ground without firing for natural death, holds a movement key across death and proves release gate. Ember startup completes three-map coverage. Two attempts/scenario maximum, 180 seconds each; failures retained.
- Release exporter must explicitly include scene/scripts and local bridge/source runtime; common launcher and package hooks remain proposed only. No aggregate acceptance claim.

## Implementation plan / files / matrix
A: godot/horde/demo.gd + demo.tscn compose session/HUD/scoreboard; model.gd projects only received Horde state; decorate received enemies with role labels.
B: port/native-horde/authority.mjs local-only one-client adapter, launcher/run.mjs, tests. Public server untouched. Default ten waves/easy; --waves=1 clearly labeled legal acceptance preset.
C: fresh-input capture requires released movement/action keys, results/restart uses existing boundary gates; HUD clears missing/stale/round state. Optional upgrades shown as unavailable (no public wire API); no endless UI.
D: godot/tests/horde offline model/adapter tests and test-only native-event driver. verify.py runs focused and relevant inherited gates; evidence correlates recipient seq/state and displayed values. Live attempts distinguish input receipt/ACK/effects. Visual review at 960x640 and 1280x800 requires image-capable tooling or remains explicitly pending.
