# Private local Linux prototype

This package is a local prototype of the existing native scenes, with the original
Node authority. It is not a public release. Source asset redistribution rights
remain unresolved; this package does not establish or grant those rights.

## Requirements and start

- Linux x86_64 desktop with OpenGL 3.3-compatible graphics and the normal Godot
  4.5.2 Linux runtime libraries (X11/Wayland, graphics/audio system libraries).
- **Node.js >=22.13.0** available as `node`. Node is an external prerequisite.
- No Godot editor, git, npm, project checkout, network download or install step at
  play time. `runtime/node_modules/ws` is an ordinary copied directory with its MIT
  license. The server uses the Node standard library and that dependency only.

```sh
tar -xzf cocs-native-linux.tar.gz
cd cocs-native-linux
node run.mjs
```

The default opens native combat host setup. Choose a map/mode and click **Start**.
By default, sessions own a new `127.0.0.1` port allocated by the OS. Closing the
native window or Ctrl+C shuts down that owned server too. The lobby's explicit
`--endpoint` route instead uses an existing authority and never stops it. Match history
and progression are memory-only, and temporary native settings are removed on
exit. Interactive play has no harness deadline.

```sh
node run.mjs --play --map=meridian-exchange --mode=deathmatch
node run.mjs --play --map=verdant-reliquary --mode=teamdeathmatch
node run.mjs --play --map=ember-crucible --mode=rockets
node run.mjs --experience=zones --map=meridian-exchange --mode=domination
node run.mjs --experience=zones --map=verdant-reliquary --mode=koth
node run.mjs --experience=combined-arms
node run.mjs --experience=arms-race --map=meridian-exchange
node run.mjs --experience=lobby
node run.mjs --experience=lobby --endpoint=ws://127.0.0.1:PORT
node run.mjs --experience=sports --map=ion-speedway --round-target=3
node run.mjs --experience=sports --map=aurora-stadium --round-target=5
node run.mjs --experience=objectives --map=tidal-citadel
node run.mjs --experience=objectives --map=sunscar-convoy
node run.mjs --experience=lattice --map=asterion-relay --mode=cocs
node run.mjs --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
node run.mjs --help
```

LATTICE command board requires **Connect / start**; LATTICE world starts its
ordinary host directly. Combat and LATTICE world capture controls on click; Escape
releases the pointer. Scene UI describes its own controls. Unsupported map/mode
combinations and out-of-range options fail explicitly rather than falling back.
The semantic catalog retains all nine locked map identities. This is the current
procedural/semantic presentation, not a claim of complete visual/gameplay parity.

Combat setup lists supported standalone routes as **separate demos** and shows
their relaunch options. Zone modes use click-to-engage infantry controls and
Enter to restart after results. Their defaults are two bots and 60-second rounds.
Combined arms is Sunscar's zero-bot Puma slice: Enter engages, E mounts/exits,
WASD moves/drives and Space requests a brake tap. After each seat change, press
Enter and fresh movement keys. Secondary chassis are visual/exit-only previews.

Arms Race: three combat arenas, two Normal bots, ten source weapons and default
180-second rounds. Click to engage. Weapon selection follows source promotion;
number keys and wheel cannot change it. Enter restarts after results, then release
held controls and click to resume. A kill-to-promotion and timed restart are
independently verified; full ten-rung live victory remains open.

LATTICE world: **C** opens tactical commands on your existing player connection.
Select an objective and explicitly issue HOLD, or authorize one recruitment
purchase. Co-op REINFORCE costs 50 FLUX during a natural between-wave window;
expired consent requires new authorization. Close with C/Escape, release controls
and click the world to resume. Full strategy rounds remain under development.

Its backed HUD distinguishes ENGAGED, RELEASED, unfocused and stale state, with
public-node bearing/planar range and team progress. HOLD receipts do not establish
node capture. Payload similarly shows cart bearing, horizontal distance and the
source escort radius separately from route progress and banked checkpoints.
Standing in range can affect the cart even while controls are released.

## Multiplayer lobby

Use `--experience=lobby` to open the form. Host: choose one of the three combat
arenas and its supported combat mode, Create, share the printed WebSocket endpoint
and room code, then Start when guests arrive. Defaults are two bots/60-second rounds.
The owned endpoint is loopback and reachable from clients on this machine only.
For an already configured reachable authority, supply its explicit `--endpoint`.

Guest: run the lobby against that same endpoint, select Guest, the room code and
the expected host map, then Join. The authority supplies the actual match mode.
Guests cannot configure, start or restart the match. Escape releases controls and
exposes **Leave match**, returning to the form without automatically reconnecting.
Leaving a room keeps the launcher open; closing the owner window stops its server.

Joining an active match gives a **read-only spectator** with a fixed camera and
Tab scoreboard. Spectators send no gameplay inputs and stay spectators through
host restart. To request a player seat, Leave and explicitly join between rounds;
there is no automatic promotion or guarantee of an available seat.

## Direct scene invocation

For an already running compatible authority, the exported executable accepts the
same native user arguments after `--` as the source scene. This bypasses ownership
by `run.mjs`, so that external server must be stopped separately:

```sh
./cocs.x86_64 --main-pack ./cocs.pck res://lattice/world_demo.tscn -- --endpoint=ws://127.0.0.1:YOUR_PORT --map=asterion-relay --mode=cocs
```

## Package contents and checks

`cocs.x86_64` is the official Godot 4.5.2 release export runtime; `cocs.pck` contains
the native runtime scenes, scripts and generated semantic JSON. Release exports
disable GDScript `assert`, so evidence checks use explicit failures. Test fixtures,
GLB CI probes, source/editor project caches, and the editor are not in this package.

`manifest.json` records per-file SHA256s, build input and generated-resource hash
inventories, source/port commits, the 84-module server import closure, locked `ws`
integrity, and official Godot archive SHA512s. `licenses/` retains Godot notices;
`runtime/node_modules/ws/LICENSE` retains the dependency license. The adjacent
archive `.sha256` file checks the tarball; the external build result records the
manifest hash (a manifest cannot include its own hash).
