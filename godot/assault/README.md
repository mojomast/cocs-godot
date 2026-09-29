# Native Assault

Scene: `res://assault/demo.tscn`. The integration lead owns launcher/routes and scoreboard wiring.

Arguments: `--endpoint=ws://HOST:PORT --map=tidal-citadel --mode=assault --bots=2 --round-seconds=180 --sectors=3`.
Maps are restricted to `tidal-citadel` and `sunscar-convoy`; bots 0–8, seconds 60–900, sectors 1–9. The sector count is sent as source `fragLimit`, default 3. Configuration must be echoed before start. Enter requests a source rematch after results. Setup/start time out through the shared session guard; missing live snapshots clear presentation immediately at staleness and fail after 10 seconds.

`state.gd` reads `state.objectives.kind == assault`, active/attacker/defender/breached/winner and bounded zones with id/x/y/z/radius/owner/captureTeam/progress/captureSeconds. `contested` is optional. Team 0 attacks; team 1 defends. The only world marker is the active source sector. Source snapshots own all progress and outcomes; events provide temporary notices only. No native capture timer, winner inference, or countdown extrapolation exists.

Source references (read-only): `game/config.mjs`, `game/assault.mjs`, `game/objectives.mjs`, `game/core.mjs`. Attack alone fills in six seconds, defenders alone drain at full rate, both drain at 0.6 rate, empty retains progress. Source time expiry assigns the defender winner.

## Vehicles

Source `modeRule(mode).vehicles !== false` enables the authored vehicle roster for **both** maps. This scene sends no vehicles override. Composition reuses:

- `combined_arms/fleet.gd`: `apply_state(state, actor_id)`, `clear_round()`; Puma and secondary chassis rendering.
- `combined_arms/lease.gd`: `vehicle_for(state, actor)` for source seat matching. Its `permitted()` is **not** reusable unchanged: it hard-codes `combined-arms`. Assault uses the session lifecycle/focus/staleness gate plus a resolved vehicle lease.
- `combined_arms/controls.gd`: `accept(event, eligible, false)`, `command(yaw, pitch, eligible, is_driver)`, `release()` while mounted.
- `combined_arms/camera.gd`: `configure_map(id, map)`, `follow(vehicle, delta)`, `reset()`.

Infantry uses the shared session input/first-person path. Mounted snapshots hide seated actor meshes and use the vehicle input/chase path. Enter/exit remain source-owned `interact`; source seat changes release all held controls. Unlike the Combined Arms demo, Assault does not suppress secondary vehicle input. No shared composition API changes are required. Full aircraft/gunner visual and control acceptance still requires the serial runtime pass; these reused controls were originally acceptance-tested as a Puma slice.

## Verification

Static only before serial grant: `node --test port/native-assault/static.test.mjs`; GDScript grammar parse with `gdparse godot/assault/*.gd godot/tests/assault/*.gd` (gdtoolkit). This does not establish Godot type checking or runtime/render acceptance.

Deferred bounded logic suite: `godot --headless --path godot --script res://tests/assault/state_test.gd` after serial grant. Then validate host → source echo → start → live sector/HUD, both maps' vehicle entry/exit, timeout defender result, breach result, rematch, malformed state/stale/drop clearing, and shared scoreboard integration. No Godot import, source server, or rendering runs were performed by this worker.
