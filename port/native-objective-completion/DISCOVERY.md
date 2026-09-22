# Completion scope and source plan

Base `ffa6aac0bc4a61a0b5e1721dbb4000066c22a474`; isolated branch `native-objective-completion`, worktree `/tmp/opencode/native-objective-completion`. The midpoint helpers and evidence are immutable dependencies, not replacement acceptance.

## Source read before live attempt

Read `game/payload.mjs` completely, `game/objectives.mjs:14–22`, `game/core.mjs:874–925,1182,1306–1314`, `game/destination-objective-maps.mjs:194–284`, `game/payload-layout.test.mjs`, the accepted progression helper/peer/validator and discovery/attempt/handoff records, and the original objective discovery. Read adapter/native controls and the shared session's actual `_process`, event, results and restart paths.

Payload source alone decides proximity, progress, contest, checkpoint banking, rollback and delivery. The public state includes cart/checkpoints but not the route. Default cart speed is 1.5 m/s here; rollback is 0.75 m/s, clamped to the last banked checkpoint. Source `payload-delivered` sets attacker winner and ends the match through `endMatch('objective')`; reaching the ordinary time limit without delivery is a distinct defender hold.

Read-only offline `payloadTemplate(getMap('sunscar-convoy'), {navigation:navigation(arena),floorAt,walkEdge,obstructed})` inspection established total **165.6313695176673 m**, minimum uninterrupted push **110.4209130117782 s**, cp1 distance **55.2104565058891** at **(-26.19273556, 0, 7.43166580)**, cp2 distance **110.4209130117782** at **(23.54045197, 0, -11.84681732)**, delivery **(78,0,-18)**. The route bends near (-39,4), (-36,6), (-30.64,7), (-27.86,8), (-22,6), (-18,2), (-6,-2), (6,-2), (8.4,-3.6), (14,-6), (18,-10), (30,-14), (34,-14), (39.74,-16.04). These are planning observations, never live state writes or an authoritative drawn route.

## First Payload plan

Use ordinary zero-bot host configuration with 180-second time limit, original scheduling/speeds, owned loopback server and private Xvfb. Primary uses Godot physical-key/mouse event objects via `Input.parse_input_event`; it walks the accepted west-side arch detour, then follows the actual received cart position at 1.2 m rather than cutting tight refinery corners from 3.2 m behind. This is an automated test driver, not human or hardware-input acceptance.

The opposing protocol peer follows the accepted reverse freight road, stopping near (-22,14) outside the cart radius. Once cp1 is exceeded by 3 m, primary walks 12 m sideways and defender enters. Defender remains at the cart until it has sat at the bank for two source seconds, then walks out. Primary waits three seconds from the bank observation and resumes the full push. Combined route is budgeted below 180 s with an outer deadline of 235 s. A 12-second stationary navigation blocker records the received actor/cart coordinates and screenshot. Failed attempts remain archived and failed.

## CTF pass plan (secondary; one bounded live attempt)

Source `flagPass` uses the normal E rising edge. A receiver must be a living, unmounted same-team actor without a flag within 2.5 m in 3D; nearest wins, with actor-ID tie-break. Pass emits `flag-pass {actor,to,x,z}` and switches carrier directly. It is not drop followed by pickup. Actor zero is valid both as actor and recipient. Three ordinary peers yield source-assigned teams 0/1/0. Primary takes the enemy flag on the accepted gate route; teammate waits safely short of the opposing flag, approaches carrier within the source radius, receives E pass, then follows the accepted reverse route home. Validation must correlate source event recipient to the native carried state and distinguish it from `flag-drop`/`flag-pickup` transitions. Only attempt this after Payload has reached its bounded milestone.

## Setup already executed

With `GUEST_NODE_MODULES=/home/mojo/.hermes-instances/fresh/workspace/cocs-godot-port/node_modules`, ran the inherited dependency loader and semantic exporter successfully (nine maps, source lock verified). Pinned Godot `/home/mojo/.hermes-instances/fresh/workspace/godot-toolchain/Godot_v4.5.2-stable_linux.x86_64` imported the isolated project successfully. New completion script passed `--headless --path godot --script res://tests/objectives/completion_live.gd --check-only` before live launch. An initial read-only route-inspection command imported `getMap` from the wrong module and failed; corrected it to `game/maps.mjs` before the successful inspection above. No gameplay attempt was involved in that command.
