# Urban multiplayer worlds — integration and verification

Two authored arenas use `godot/multiplayer_worlds/generated/{switchyard-ward,rainmarket-exchange}.json` for **source-owned** collision, floors, navigation, spawns, flags and capture zones. The authored `.blend` masters in `tools/godot-multiplayer/urban/` export art-only GLBs in `godot/multiplayer_worlds/art/`. `geometryHash` is SHA-256 of the canonical `arena` JSON; the room sends it at each round start and the Godot client rejects a mismatched authority. `port/multiplayer-worlds/generate-derivative.mjs` checks narrow substitutions in the locked server, generating separate reviewed multi-human transport under `derived/`. The shipped runtime closure includes these derivatives and exactly two urban JSON files.

| Map | Playable modes | Traversal / objective facts |
| --- | --- | --- |
| Switchyard Ward | deathmatch, teamdeathmatch, instagib, rockets, armsrace, ctf, domination, koth, uplink, holdout, assault | Four walkable roofs and ramps, 510 connected source nav nodes (90 above ground), opposed team flags, three capture sectors |
| Rainmarket Exchange | deathmatch, teamdeathmatch, instagib, rockets, armsrace, domination, koth, uplink, holdout, assault, payload | Raised arcade and ramp, 530 connected source nav nodes (24 above ground), three capture sectors and a source-computed Payload path |

These are 22 explicit map/mode pairs. `node port/multiplayer-worlds/mode-matrix.mjs` runs every pair through a two-human/two-bot source Room, checks authority hash, initialization, objective shape, and bot nav. `node port/multiplayer-worlds/urban-audit.mjs` checks source collision support, spawn/objective clearance, opposing-team separation and connectivity to all roofs. `node port/multiplayer-worlds/two-client.mjs` drives two distinct real WebSocket clients plus a late-joining spectator, observes CTF capture, Domination ownership and moving Payload, then starts a fresh round. Objective exercise sets actor coordinates **inside the test authority process**; no client-side state injection is accepted by the protocol. Logs and eight rendered views live in `/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/urban/`.

Launch from a source checkout (with the exact Godot toolchain installed):

```sh
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=switchyard-ward --mode=ctf --bots=2
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=rainmarket-exchange --mode=payload --bots=2
```

To join a second native client, keep the first authority running and use its logged room ID and endpoint:

```sh
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=switchyard-ward --mode=ctf --endpoint=ws://127.0.0.1:PORT --join-room=ROOM_ID
```

The packaged launcher uses the same `--experience`, `--map`, `--mode`, `--bots`, `--endpoint`, and `--join-room` flags with `node run.mjs`. `--endpoint` reuses an existing server; no second authority is spawned. Horde's **Blackwater Reclamation** route is distinct and remains local single-human Horde, launched with `--experience=horde --map=blackwater-reclamation --waves=1..30`.

Reproducibility:

```sh
node tools/godot-multiplayer/urban/generate.mjs
LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/export.py -- switchyard-ward
LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/export.py -- rainmarket-exchange
node tools/godot-multiplayer/urban/art-audit.mjs
LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/capture.py -- /PATH/TO/REVIEW-DIRECTORY
node port/multiplayer-worlds/generate-derivative.mjs --check
node tools/godot-package/gen_routes.mjs --check
node --test tools/godot-package/route_parity.test.mjs
```

## Urban fidelity refinement (after `ad511d9c`)

Both city maps have separate material/architectural languages. Switchyard is red brick, service steel, hazard enamel, rail ties, factory bays and four accessible equipment roofs; Rainmarket is teal/copper transit fronts, tiled shop canopies, stall awnings, a wet tram corridor and an accessible arcade. Source collision now includes 12 and 3 roof-edge guards respectively, eight back-wall counters per map, and ten true 12cm sidewalk surfaces per map. Rooftop access still follows the original supported ramps. Street drains, floor joints, scuffs, signage, window trim, shallow shelving, light fixtures and rain staining are art only; out-of-bounds skyline buildings are explicitly unreachable. An interior ceiling rib starts above player head clearance. Thin art surfaces have no fictional gameplay cover or elevated path.

Exported **GLB accessor counts**: Switchyard 30,166 triangles in 11 material batches, 2,115,668 bytes; Rainmarket 27,551 triangles in 11 batches, 1,933,948 bytes. Both are beneath the 38,000-triangle / 12-batch / 3MB GLB caps in `art-audit.mjs`; editable masters retain 2,422 and 2,226 separately named mesh parts. Hashes are `5b3cfbba7c1162257439bd9d43d06bcccf9c0479f8818d8c628222a0a7d939ed` and `1915800c641672c6403f9251d16827c45a8638473b0653cdc177fdbfe6313771`. The same audit checks that every curb center is a source floor and every roof guard is an obstructing source block on supported upper terrain. The new two-WebSocket test reran CTF capture, Domination ownership, Payload progress, late spectator and restart against these hashes.

The eight `*-blender.png` files in `/home/mojo/.tmp-on-disk/cocs-multiplayer-evidence-20261001/urban/` are **Blender CPU review views** of the committed masters with temporary authoritative terrain overlaid; `refined-audit.json`, `refined-two-client.log` and `refined-mode-matrix.json` are matching source evidence. Earlier Godot captures have the former hashes and are preserved as *before* images. Final post-refinement Godot screenshots and scene/import signoff await the exclusive engine slot after worlds and Horde. Capture from standing street/inside-door/ground-facing-roof perspectives; avoid a camera inside an authored cover block.

The five non-urban recipes are tracked separately in `WORLDS.md`. The reviewed derivative in `derived/core.mjs` resolves the new sports map before source constructor preflight; `derived/payload.mjs` stitches Breakwater's seven authored anchors with source walking edges. `build-world-catalog.mjs` converts exact overhead AABBs into non-walkable roof/underside triangles and side walls, then writes matching source/client `geometryHash` values. The Godot collision renderer consumes those same triangles and walls. Sports launches use `sports_demo.tscn`; Tern uses `lattice_demo.tscn` with source-compatible command deck and a port-scoped map/flow parser. The generated Godot scene derivatives and JS derivatives are reproducibility-gated at build time.

Additional source checkout launches:

```sh
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=breakwater-exchange --mode=payload --bots=2
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=thermal-divide --mode=ctf --bots=2
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=sirocco-circuit --mode=puma-race --round-target=3 --time-limit=180
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=copper-bowl --mode=puma-soccer --round-target=5 --time-limit=180
node tools/godot-dev/launch.mjs --experience=multiplayer-worlds --map=tern-archipelago --mode=cocs --bots=2
```

The sports target maximum is **mode-based**: 10 race laps, 15 soccer goals. The main-menu world route offers the same legal map/mode pairs with default target and timer; CLI flags expose the bounded sports overrides. `mode-matrix.mjs` executes all 43 pairs with two human seats and two source bots/vehicles. Renderer inspection captured two views each of all five additional worlds after moving the Blender masters out of Godot's import tree, so GLBs are actually imported. Godot live authority logs prove Breakwater Payload/Combined Arms, Thermal CTF, Sirocco Race, Copper Soccer, and Tern PvP/Co-op start with matching gameplay hashes. Mode-specific complete-round and two-native-client journeys remain for the world lane's next exclusive engine pass.
