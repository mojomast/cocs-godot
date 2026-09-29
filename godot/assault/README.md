# Native Assault

Scene: `res://assault/demo.tscn`. The integration lead owns launcher/routes and scoreboard wiring.

Arguments: `--endpoint=ws://HOST:PORT --map=tidal-citadel --mode=assault --bots=2 --round-seconds=60 --score-limit=3`.
Maps are restricted to `tidal-citadel` and `sunscar-convoy`; bots 0–8, seconds 60–900 (default 60), sectors 1–9. The sector count is sent as source `fragLimit`, default 3. Configuration must be echoed before start. Enter requests a source rematch after results. Setup/start time out through the shared session guard; missing live snapshots clear presentation immediately at staleness and fail after 10 seconds.

`state.gd` reads `state.objectives.kind == assault`, active/attacker/defender/breached/winner and bounded zones with id/x/y/z/radius/owner/captureTeam/progress/captureSeconds. `contested` is optional. Team 0 attacks; team 1 defends. The only world marker is the active source sector. Source snapshots own all progress and outcomes; events provide temporary notices only. No native capture timer, winner inference, or countdown extrapolation exists.

Source references (read-only): `game/config.mjs`, `game/assault.mjs`, `game/objectives.mjs`, `game/core.mjs`. Attack alone fills in six seconds, defenders alone drain at full rate, both drain at 0.6 rate, empty retains progress. Source time expiry assigns the defender winner.

## Vehicles

Source `modeRule(mode).vehicles !== false` enables the authored vehicle roster for **both** maps. This scene sends no vehicles override. Composition delegates to the shared session bridge:

- `world/session.gd` owns `vehicle_bridge` (source seat lease, input adaptation, crew visibility) and `vehicle_fleet` (five-chassis rendering). Assault calls the ordinary shared snapshot/input/focus path.
- `combined_arms/camera.gd`: `configure_map(id, map)`, `mounted(vehicle, actor, yaw, pitch, delta)`, `reset()` supplies the mounted chase camera only.

Infantry and mounted seats use shared session input. Source seat changes release held controls through its bridge; Enter/exit remain source-owned `interact`. Unlike the earlier Puma-only demo, secondary vehicle inputs are not suppressed. Full aircraft/gunner visual and control acceptance still requires the serial runtime pass.

## Verification

Static only before serial grant: `node --test port/native-assault/static.test.mjs`; GDScript grammar parse with `gdparse godot/assault/*.gd godot/tests/assault/*.gd` (gdtoolkit). This does not establish Godot type checking or runtime/render acceptance.

Deferred bounded logic suite: `godot --headless --path godot --script res://tests/assault/state_test.gd` after serial grant. Then validate host → source echo → start → live sector/HUD, both maps' vehicle entry/exit, timeout defender result, breach result, rematch, malformed state/stale/drop clearing, and shared scoreboard integration. No Godot import, source server, or rendering runs were performed by this worker.
