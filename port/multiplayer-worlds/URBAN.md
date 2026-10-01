# Urban multiplayer worlds — integration and verification

Two authored arenas use `godot/multiplayer_worlds/generated/{switchyard-ward,rainmarket-exchange}.json` for **source-owned** collision, floors, navigation, spawns, flags and capture zones. The authored `.blend` masters in `tools/godot-multiplayer/urban/` export art-only GLBs in `godot/multiplayer_worlds/art/`. `geometryHash` is SHA-256 of the canonical `arena` JSON; the room sends it at each round start and the Godot client rejects a mismatched authority. `port/multiplayer-worlds/generate-derivative.mjs` checks narrow substitutions in the locked server, generating separate reviewed multi-human transport under `derived/`. The shipped runtime closure includes these derivatives and exactly two urban JSON files.

| Map | Playable modes | Traversal / objective facts |
| --- | --- | --- |
| Switchyard Ward | deathmatch, teamdeathmatch, instagib, rockets, armsrace, ctf, domination, koth, uplink, holdout, assault | Four walkable roofs and ramps, 514 connected source nav nodes (90 above ground), opposed team flags, three capture sectors |
| Rainmarket Exchange | deathmatch, teamdeathmatch, instagib, rockets, armsrace, domination, koth, uplink, holdout, assault, payload | Raised arcade and ramp, 532 connected source nav nodes (24 above ground), three capture sectors and source-computed 96.5-unit payload path |

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
LP_NUM_THREADS=1 blender -b -t 1 --python tools/godot-multiplayer/urban/export.py
node port/multiplayer-worlds/generate-derivative.mjs --check
node tools/godot-package/gen_routes.mjs --check
node --test tools/godot-package/route_parity.test.mjs
```

The five non-urban recipes are tracked separately in `WORLDS.md`; their mode bindings are proposals until source-compatible terrain/overhead/vehicle and LATTICE runtime seams plus Godot peer evidence are accepted.
