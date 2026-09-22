# Objective slice discovery and implementation plan

Base: 8e91969ca0d55938c25198c34ff158dd7195be20. Worktree /tmp/opencode/cocs-native-objective-gameplay; branch subagent/native-objective-gameplay. Source simulation is unchanged.

## Contracts inspected

port/contracts/map-selection.json permits tidal-citadel/ctf and sunscar-convoy/payload. The main menu intentionally does not enable these; the standalone adapter must not change its capability checks.

Coordinates are metres, +Y up, -Z forward (port/contracts/CONTRACT.md). Source actor y is foot height. Render objective roots at the exact source x/y/z; mesh decoration may extend above that root.

CTF: game/core.mjs:466-470,874-923,1259,1310-1314. Top-level flags is an array with team 0/1 as stable identity, state at-base/carried/dropped, carrier nullable (zero valid), and x/y/z. objectives has flags/nodes but no required kind. config.mode selects CTF. teamScores is keyed by team. Actors include carryingFlag and carrySpeedMultiplier. Enemy pickup and friendly dropped-flag return occur automatically for healthy unmounted actors within <1.15 horizontal and vertical distance. Capture requires home at base, <1.3 distance/height and no living opponent in its ring. E's interact rising edge relays to nearest living eligible teammate within 2.5m in 3D, breaking ties by ID; otherwise drops, blocking this actor's repickup for one second. Carriers cannot enter vehicles or activate harness power. Source events: flag-pickup, flag-pass, flag-drop, flag-return, flag-contest, capture. A source state/event, not local proximity, establishes transitions.

Tidal's authored gate route connects (-72,0),(-54,0),(-26,0),(0,8),(26,0),(54,0),(72,0). Team spawns are near x +/-80; flags at +/-72, z0. See game/destination-objective-maps.mjs:95-143. Start via courtyard/gate road, reach opposing flag, then E and move away. A second ordinary defender peer can support return, never by writing actor coordinates.

Payload: game/payload.mjs:119-181 and game/objectives.mjs:14-22. objectives.kind=payload; objectives.payload contains position, distance, total, speed, radius, pushing, contested, delivered, checkpointsReached/checkpointCount/progress. objectives.zones provides checkpoint coordinates/IDs/owner/progress/distance; active/attacker/defender/winner sit on objectives. Runtime route is navigation-derived and is NOT serialized; authored freight-road cues are guidance, not a claim to be the exact runtime track. Team 0 attacks; team 1 defends. Living actors within radius (default 4.5) and <=5 height contribute. Attackers alone advance, both teams freeze, defenders alone roll back at half speed no earlier than the last checkpoint, nobody leaves it idle. No E press needed. Checkpoint/delivery/contest events corroborate state.

Sunscar starts route at the first attacker spawn (-78,-10), finishing at (78,-18). The freight road doglegs around refinery walls; see destination-objective-maps.mjs:198-257. Move into the live cart radius, follow it briefly, then move out. Prove displacement then idle without changing speed, respawn, damage or tick scheduling.

## Plan before gameplay implementation

1. Stable bounded renderer + pass-through compact HUD, strict finite position handling, no local outcomes. Clear on absent state/mode/round/error.
2. Standalone scene adapter inheriting session control/lifecycle behavior while owning its own initialization and explicit mode allowlist; compose existing world, actor, pickup and network modules. Require neutral released controls before fresh capture.
3. Owned normal-rate loopback launcher with deadlines and cleanup; dependency resolver reuses GUEST_NODE_MODULES read-only. No shared package changes.
4. Native synthetic regressions and bounded physical-input live attempts for both modes, private Xvfb, sanitized source/native witnesses and screenshots. Document partial coverage rather than weaken checks.

## Executed prerequisite tests

Initial command node --test game/destination-maps.test.mjs game/objective-occlusion.test.mjs game/payload.test.mjs game/payload-layout.test.mjs: exit 1 (55 passes; occlusion could not resolve three in the new worktree).

Rerun with GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules and --loader ./port/tools/native_objective_demo/dependencies.mjs: exit 0. Complete TAP retained alongside these notes. These are source/offline tests, not live native gameplay.
