# COCS: DESTINATIONS — Windows x64 demo

## Play

1. Download `cocs-native-windows.zip` from the GitHub release.
2. Right-click the ZIP → **Extract All**. Open the extracted `cocs-native-windows` folder.
3. Double-click **Play.cmd** for Meridian Team Deathmatch with bots.
4. Click inside the game window to engage the mouse and controls.

**Demo Menu.cmd** offers other arenas, Horde, Arms Race, the lobby, vehicles,
racing and the operator viewer. **Operator Preview.cmd** opens the static
three-model lineup. Close a game window to end that session. The console belongs
to its local server; leave it open while playing.

Requires **Windows 10/11 x64** and an **OpenGL 3.3-compatible graphics driver**.
Godot 4.5.2 and Node 22.22.0 are bundled. No editor, Node installation, npm, Git
or account is needed. Local bot matches work offline. Launch through Play.cmd,
not cocs.exe, so the local authoritative server is started and cleaned up.

## Controls

- **WASD** move, **mouse** look, **left click** fire
- **Space** jump, **Shift** sprint, **Ctrl** crouch
- **R** reload, **1–9 / 0 / wheel** change weapon
- **E** interact, **F** mobility (Horde uses its own source controls below)
- **Tab** scores, **Escape** release mouse; the match keeps running
- **Enter** restart after results, then release keys and click to resume

Horde: **Q** power, **X** mobility, **F** melee, **G** grenade, **RMB** ADS,
**Z / MMB** alternate fire. Vehicles: **Enter** engage, **E** mount/exit,
**WASD** drive and **Space** brake tap. Sports restart uses **F5**.

## More maps and modes

From a terminal opened in the extracted folder:

```bat
Play.cmd --play --map=verdant-reliquary --mode=instagib
Play.cmd --experience=zones --map=meridian-exchange --mode=domination
Play.cmd --experience=zones --map=verdant-reliquary --mode=koth
Play.cmd --experience=sports --map=aurora-stadium
Play.cmd --experience=objectives --map=tidal-citadel
Play.cmd --experience=objectives --map=sunscar-convoy
Play.cmd --experience=lattice --map=asterion-relay
Play.cmd --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
Play.cmd --help
```

All nine maps and ten experience routes are retained. Lobby defaults to an owned
loopback server, usable by clients on this computer. A separately hosted reachable
server can be selected with `--experience=lobby --endpoint=ws://HOST:PORT`.

## Candidate models and demo status

This demo enables the recovered procedural operator candidate in the shared
infantry presentation: three geometry variants and palettes for all nine IDs.
The viewer shows all three; normal gameplay character selection is source-driven.
Geometry is static, with no walk cycle or skeletal animation. Distant identity
readability and render cost remain work in progress. The package manifest records
`operator_models` and the exact staging-only preload change; source defaults still
use baseline operators. Custom renderers in other modes may use their own models.

Campaign is deferred. Full Horde progression and full Arms Race ladder completion
are still under development. The existing combat setup/strategy popup issue can
be avoided with the direct-start presets. At small resolutions, release Tab if
the Horde scoreboard covers the health/ammo panels.

This is a development prerelease. The source asset-rights audit remains unresolved;
the package does not establish new rights to the original assets. Godot, Node and
ws notices are included under `licenses/` and `runtime/node_modules/ws/LICENSE`.

## Diagnostics and provenance

`Play.cmd --smoke` runs a headless normal-rate combat network check and exits.
It checks loading, snapshots, movement, firing and server cleanup, not graphics,
audio or human usability. Report a launch error together with console output.

`manifest.json` records source and port commits, every packaged file's SHA256,
source module closure, adapter hashes, bundled Node provenance, official Godot
checksums and the staged model override. The adjacent ZIP `.sha256` verifies the
download. Native Windows CI results and known limits are linked from the release.

## Rebuild on Linux

```sh
python3 tools/godot-package/build.py --target windows --operator-models candidate \
  --state /tmp/opencode/cocs-windows-build \
  --archive-directory /path/to/pinned/godot-archives
```

The archive directory is optional and must contain the verified `editor.zip` and
`templates.tpz`. Generated binaries stay outside Git and are attached to a GitHub
release; source, build tooling and verification reports are committed.
