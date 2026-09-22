# Sunscar combined-arms source discovery

Base `013ad65`; isolated worktree `/tmp/opencode/combined-arms-native-013ad65`.

## Map and ordinary authority path

- `game/destination-objective-maps.mjs:198–307`: **Sunscar Convoy**, not legacy Sunscar Canyon. Its explicit modes include `combined-arms`. Bounds X ±96, Z ±60; flat authored terrain. No capability override is required.
- West team infantry candidates: `(-78,-10)`, `(-86,-28)`, `(-86,2)`, `(-76,16)`. East: `(78,-18)`, `(86,-28)`, `(86,2)`, `(78,12)`. These are authored X/Z, not forced spawn selections.
- West vehicles: Puma `sunscar-0-puma` at `(-62,0,-4)`; Titan `(-52,0,8)`; Scout `(-82,0,-44)`; Transport `(-64,0,44)`; Hornet `(-84,0,46)`. East mirrors X. West heading +π/2; east -π/2. Source simulation may subsequently change Y.
- Preplanned acceptance walking corridor: from ordinary west spawn to X=-80 at current Z, then `(-80,-10)`, `(-62,-10)`, `(-62,-6)`. Drive initially +X in the open yard, brake/reverse before the X=-30 refinery divider. The test issues native input events; this route is absent from the product adapter.
- `game/core.mjs:779`: `enterVehicle` takes the first vehicle with a source-open seat, horizontal distance **<2.4 m**, vertical distance **<2.4 m** (aircraft 3.2 m), alive/non-respawning chassis. Flag carriers cannot mount. Driver first, then available gunner, then passenger. **No team-entry lock**. Team tags are deployment/friendly-fire context, not an entry authorization. `vehicleSeatFor`/`vehicleSeatOpen` live in `game/vehicles.mjs:393–432`.
- `game/core.mjs:760–762`: source seat anchor sets actor vehicle ID and role; source `releaseVehicle` chooses the exit position and applies its own movement reset / dismount stun. Native never writes these fields.
- `game/core.mjs:1258–1259`: ordinary actor interact routes to entry or exit before driving/movement. Native must resolve both actor `vehicleId/vehicleSeat` and vehicle `driver` identity; proximity alone is not mounted state.

## Wire and vehicle controls

`godot/net/client.gd` already supports the necessary v3 full-snapshot protocol:

1. Explicit loopback endpoint; allowlisted map catalog.
2. `{type:create,name,playerName,v:3,delta:0}`.
3. `{type:host,mapId:"sunscar-convoy",config:{mode:"combined-arms",botCount:0}}` using `configure_match`, which checks the map's mode list.
4. `{type:start}` after configured lobby.
5. `{type:input,seq:N,input:{x,z,yaw,pitch,fire,jump,sprint,crouch,interact,reload,power}}`. Sequence increments only on successful queue. ACK is recipient actor high-water, not evidence every packet affected a tick.

`game/protocol.mjs:208–226` accepts these fields and clamps individual x/z to [-1,1]. `server/room.mjs:1052–1097,1263–1273` rebuilds latest continuous x/z/fire/yaw/pitch/sprint/crouch, but turns **interact and jump into rising edges for non-race matches**. This matters: **Space is a brake tap in combined arms, not a held handbrake**. The adapter preserves this source route; it does not generate periodic fake jump edges. S decelerates then reverses; releasing W coasts with source drag. Sports' held jump semantics cannot be transplanted into this room path.

`game/core.mjs:787` computes:

```
throttle = clamp(-x*sin(actorYaw) - z*cos(actorYaw), -1, 1)
steer    = clamp(-x*cos(actorYaw) + z*sin(actorYaw), -1, 1)
brake    = jump === true        // ground vehicles
boost    = sprint === true
```

The inherited sports gate provides the inverse x/z projection. A common scale fits both axes into the parser's [-1,1] limits, preserving the throttle/steer ratio when both keys are down at oblique yaw. Infantry uses existing `world/control_math.gd`. Mounted LMB routes through the same source `fire` field; gunner occupancy and source weapon heat still decide firing. Source vehicle physics, turret traverse, weapon abilities and operator modifiers remain authoritative. No throttle/steer/vehicle-position wire fields exist. No shared client modification is required.

## Recipient vehicle snapshot

`game/core.mjs:1313` sends `vehicles[]`:

```
id,kind,x,y,z,vx,vy,vz,yaw,roll,pitchBody,flight,altitude,turretYaw,
health,maxHealth,driver,gunner,passengers[],heat,overheated,respawnTimer
```

No wire speed, handbrake, boost cooldown, steer angle or deployment team is invented. HUD speed is `hypot(vx,vz)`. IDs parsed from JSON may be integral floats, including actor `0`; null and -1 are distinct. The native root copies full XYZ exactly (within Godot Vector3 floating-point representation), without ground resampling. Existing native Puma model + renderer supports this ground chassis, so it is reused read-only. Secondary procedural silhouettes are in the new owned directory, with stable per-ID lifetime and 64-vehicle roster cap. Their seats permit ordinary exit but only Puma driver control is the accepted vertical slice.

## Launch and integration API

Human standalone launch, from this checkout and on the operator's selected display:

```sh
python3 -B port/native-combined-arms/play.py --map sunscar-convoy
```

Copies project/source to `/tmp/opencode`, reuses pinned Godot 4.5.2 and primary `node_modules` read-only, generates existing locked semantic content, starts its own normal-rate port-0 loopback server, and launches:

```sh
"$GODOT_BIN" --path "$PRIVATE_PROJECT/godot" --rendering-method gl_compatibility --audio-driver Dummy res://combined_arms/demo.tscn -- --map=sunscar-convoy --endpoint=ws://127.0.0.1:PORT
```

`play.py --seconds 10..120` bounds ownership; `--endpoint` may select an explicitly approved existing server. It creates a room, not a guest join. `GODOT_BIN`/`GUEST_NODE_MODULES` may select existing pinned resources. The launcher contains no route automation.

Adapter API: `on_snapshot(frame)` consumes accepted frames; `clear_round()` releases and clears all actors/vehicles/camera identity; `on_started(frame)` grants an initial snapshot timeout budget without authority; `on_results(frame)` releases and sends neutral. It delegates sequencing, ACK validation and map substitution checks to existing PortNetwork. Disconnection needs a fresh launcher session.

### UNAPPLIED common/package hook

The integration owner may add `--experience=combined-arms` to its existing experience dispatch and select `res://combined_arms/demo.tscn`, default map `sunscar-convoy`, mode `combined-arms`. Pass the explicit endpoint and map after `--`; include `godot/combined_arms/**` in packaging. Do not broaden the global map-mode capability table. This standalone adapter hosts its own ordinary room; a future shared-session adapter can feed accepted frames and use existing `send_input` envelopes. **No changes to common launchers, package scripts, verifier, shared session, protocol or catalog have been applied.**

`UNAPPLIED-launcher-hooks.patch` contains the exact two routing-table additions for `tools/godot-dev/launch_options.mjs` and `tools/godot-package/options.mjs`. The current package builder selects tracked native files with `git ls-files godot`, excluding tests/content/cache, so the committed new directory is included automatically at the lead's next build. Help-text / launcher tests / package rebuild remain integration-owner actions. Intended post-integration commands:

```sh
node tools/godot-dev/launch.mjs --experience=combined-arms --map=sunscar-convoy
node run.mjs --experience=combined-arms --map=sunscar-convoy
```

These common/package commands are **not enabled in this branch**; use `play.py` now.

## Manual native exercise

1. Wait for live infantry HUD. Enter captures mouse and engages fresh controls. WASD walks; mouse looks; E boards within source range. LMB uses ordinary fire; Space jumps; Shift sprints.
2. Find the west Puma near `(-62,-4)`. Entering source seat releases inputs and requires fresh Enter, then fresh W/S/A/D. W accelerates, S slows/reverses, A/D steer, Shift requests boost. Mouse aims the source mounted weapon; LMB fires when source allows. Chase follows heading, independent of reverse velocity.
3. Space requests one source brake tap. Release W, or use S until slow. Esc releases all held actions. Enter must be fresh after refocus, stale snapshots, death, seat changes or actor reassignment.
4. E dismounts. Source chooses safe exit coordinates. Fresh Enter then new WASD resumes infantry; held keys from driving never carry across.

The accepted slice is Puma driver mount/motion/dismount. Additional seat control, Hornet flight, full combined-arms objective HUD, match completion/restart, combat outcomes and human camera-usability acceptance are separate work.
