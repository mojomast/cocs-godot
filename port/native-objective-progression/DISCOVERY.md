# Objective progression discovery

Base: `d498479`. Isolated branch/worktree: `objective-progression`, `/tmp/opencode/objective-progression`.

Read the inherited objective `HANDOFF.md` and `DISCOVERY.md`, objective renderer/demo/original live driver, the complete shared `world/session.gd` callbacks and control path, network decoding/ownership, GameHUD/scoreboard composition, CTF source mechanics, Payload source module, destination geometry, and server room/timing paths before implementation.

## Source rules and navigation

- Only fixed catalog pairs: Tidal Citadel/CTF and Sunscar Convoy/Payload. No global menu capability change.
- `game/core.mjs:874–922`: flag pickup and friendly dropped return are automatic proximity actions. E is the normal rising-edge pass/drop. Dropping temporarily locks the dropping actor's own pickup. Capture requires one's own at-base flag and an uncontested home ring. The second peer can return its own flag without attacking the carrier.
- Tidal's authored gate route is `(-72,0),(-54,0),(-26,0),(0,8),(26,0),(54,0),(72,0)`. Primary walks it, drops, retreats toward `(62,0)`, waits for source return, picks up again and reverses the same route. Defender waits at `(72,-5)`, approaches its dropped flag, then retreats. No spawn selection or state writes.
- `game/payload.mjs:119–181`: cart pace is normal, attacker 0, defender 1, radius 4.5, opposing occupants freeze progress; attackers resume when defender leaves. Checkpoints bank progress and increase team score.
- Sunscar defender walks the authored freight road in reverse from `(78,-18)` through `(54,-18),(14,-18),(0,18),(-44,18),(-54,-10),(-78,-10)` before approaching the received cart position. After two source seconds of contest it walks 12 metres out. Primary follows source cart position, then leaves after checkpoint. Authored geometry is guidance, not a claim that it equals the source navigation-derived cart track.
- `game/config.mjs:289` accepts ordinary `timeLimit` from 60 to 900 seconds. A short legal host configuration changes only that option and zero bots; no tick-rate, damage, movement, objective speed, respawn or map mutation.
- `server/game-server.mjs:450` runs the original tick interval. Helpers call `createGameServer` without tick overrides, listen on owned loopback port 0, and use ordinary create/configure/join/start/input/restart messages. Observer wrappers only record sent/received frames.

## Lifecycle and UI design

Session remains inherited: fresh pose/watch/lifecycle/focus are required for control, actual event input goes through `_input`/`_unhandled_input`, results stop inputs, restart releases capture and clears presentation. The isolated adapter now counts and exposes results through a named callback. A bounded peer wait fits within the inherited 15-second handshake deadline.

`objectives/hud.gd` extends the existing passive GameHUD. It adds source-derived objective scalars and a progress gauge; combat health/armor/ammo, weapon selection hints and shared scoreboard are reused without shared edits. The legacy `objective_label.text` observer API retains the detailed source status. World flag labels are smaller and suppressed within 3.5 metres; cart mesh geometry yields inside the camera's near-eye volume without moving its root or altering renderer correlation data.

New-round/error clear both the source-root renderer and objective scalar model. HUD round start clears before fresh snapshots. The shared scoreboard supplies results/restart instructions. Native live verification keeps the second round uncaptured for one second, then requests fresh capture by a new physical mouse event.
