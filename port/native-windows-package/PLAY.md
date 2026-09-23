# COCS: DESTINATIONS — Windows x64 demo

## Play

1. Download `cocs-native-windows.zip` from the GitHub release.
2. Right-click the ZIP → **Extract All**. Open the extracted `cocs-native-windows` folder.
3. Double-click **Play.cmd** to open the **main menu** with bots.
4. Click inside the game window to engage the mouse and controls.

**Graphics Showcase.cmd** opens the new map and effects menu (details below).
**Native Deathmatch.cmd** selects bot combat on Prism Foundry, Aurora Basin or
Cinder Array, with weapons, scoring, respawns and round restart.
**Demo Menu.cmd** offers other arenas, Horde, Arms Race, the lobby, vehicles,
racing, graphics showcases and the operator viewer. **Operator Preview.cmd** opens the static
three-model lineup. Close a game window to end that session. The console belongs
to its local server; leave it open while playing.

Requires **Windows 10/11 x64** and an **OpenGL 3.3-compatible graphics driver**.
Godot 4.5.2 and Node 22.22.0 are bundled. No editor, Node installation, npm, Git
or account is needed. Local bot matches work offline. Launch through Play.cmd,
not cocs.exe, so the local authoritative server is started and cleaned up.

## Controls

- **WASD** move, **mouse** look, **left click** fire
- **Space** jump, **Shift** sprint, **Ctrl** crouch
- **RMB** aim down sights; release to return to hip fire
- **R** reload, **1–9 / 0 / wheel** change weapon
- **E** interact, **X** mobility, **Q** power, **F** melee, **G** grenade
- **Z / MMB** alternate fire
- **Tab** scores, **Escape** release mouse; the match keeps running
- **Enter** restart after results, then release keys and click to resume
- **F8** cycle Moth scenery detail: Full → Off → Low
- **F9** cycle combat effects: Low → High → Extreme
- **F10** toggle combat-effect resource metrics

These source combat controls also apply to Horde. Arms Race keeps weapon selection
locked to the authoritative ladder while allowing ADS. Vehicles: **Enter** engage, **E** mount/exit,
**WASD** drive and **Space** brake tap. Sports restart uses **F5**.

## More maps and modes

From a terminal opened in the extracted folder:

```bat
Play.cmd --play --map=verdant-reliquary --mode=instagib
Play.cmd --experience=zones --map=meridian-exchange --mode=domination
Play.cmd --experience=zones --map=verdant-reliquary --mode=koth
Play.cmd --experience=native-dm --map=prism-foundry --bots=2 --round-seconds=180
Play.cmd --experience=native-dm --map=aurora-basin
Play.cmd --experience=native-dm --map=cinder-array
Play.cmd --experience=sports --map=aurora-stadium
Play.cmd --experience=objectives --map=tidal-citadel
Play.cmd --experience=objectives --map=sunscar-convoy
Play.cmd --experience=lattice --map=asterion-relay
Play.cmd --experience=lattice-world --map=monsoon-foundry --mode=cocs-coop
Play.cmd --help
```

All nine original maps and ten source experience routes are retained, plus five
native-only graphics routes and the three-map native Deathmatch route. Lobby defaults to an owned
loopback server, usable by clients on this computer. A separately hosted reachable
server can be selected with `--experience=lobby --endpoint=ws://HOST:PORT`.

## New native maps and effects

**Native Deathmatch.cmd** opens the combat variants of all three maps. Each match
has one local human and 1–7 bots. Choose the map in the launcher, then start the
match in the native setup screen. Close and relaunch to change maps. Source
movement, weapon damage, scoring and bot AI remain authoritative. The combat
layouts have visible architectural changes to support that mover's routes;
the original exploration versions remain available in Graphics Showcase.

Combat effects include source-state shields/armor reactions, animated barrel-tip
weapon presentation, compact pickup miniatures and world-space GPU particles.
High allocates a shared 32,768 particle slots on original arenas and 131,072 on
native arenas; Extreme explicitly raises the whole pool to 1,000,000. Allocated
or submitted slots are not a count of distinct visible particles. Use F10 to
inspect current resource metrics. The user's GPU ran the million-particle lab
smoothly; software-renderer measurements here do not establish hardware combat
performance. Reduce the setting with F9 if needed.

Double-click **Graphics Showcase.cmd** and choose:

1. **Prism Foundry:** reactor atrium, turbine hall, coolant garden, upper loop and
   observation deck. **P** photo views, **[ / ]** change view, **F1** help.
2. **Aurora Basin:** polar observatory, frozen lake circuit, ice arches and a
   raised skywalk beneath animated aurora curtains.
3. **Cinder Array:** volcanic caldera, suspended bridge, extractor gantry,
   basalt tunnel and observation deck.
4. **Particle Observatory:** four effects and **8K / 32K / 128K / 512K / 1M**
   particle settings. **1–4** presets, **+/−** count, **B** backend, **Space** pause,
   **R** reset, **V** render scale, **L** low-energy view, **F** freeflight.
5. **Moth Shader Gallery:** interference shell, energy reactor and phase prop.
   **1–3** effects, **Space** pause, **A/D or drag** orbit, **+/−** intensity,
   **[ / ]** phase amount, **R** reset.

Maps use **WASD / mouse**, **Shift** sprint, **Space** jump, **R** return to spawn,
**Escape** release, **click** recapture. They are standalone, unarmed exploration
showcases with native collision; no server or account is needed.

The particle lab starts at **32K**, using actual GPU particle simulation. Massive
counts are explicit stress experiments. The million-particle case measured about
**462 ms/frame on the Linux software renderer**; your GPU must be measured directly.
The lab displays actual counts, backend, memory estimates and median/p95 cadence.

Terminal equivalents: `Play.cmd --experience=showcase`, `--experience=aurora-basin`,
`--experience=cinder-array`, `--experience=particle-lab`, `--experience=shader-lab`.

## Candidate models and demo status

This demo uses the source-operator models in the shared infantry presentation:
three geometry variants and palettes for all nine IDs. Combat setup and lobby
provide operator/harness selection; restricted native-arena routes keep their
existing fixed loadout rules. The viewer shows all three geometry variants.
Geometry is static, with no walk cycle or skeletal animation. Distant identity
readability and render cost remain work in progress. The package manifest records
`operator_models=source-operators` and no staging-only model override. Custom
renderers in other modes may use their own models.

Horde offers can be selected with numbered buttons or matching number keys,
with server-confirmed applied/refused feedback. LATTICE shows authored map links
and advisory supply/target guidance. Campaign is deferred; natural full Horde
rounds and full Arms Race ladder completion remain outside verified acceptance.
At small resolutions, release Tab if the Horde scoreboard covers the health/ammo panels.

This is a development prerelease. The source asset-rights audit remains unresolved;
the package does not establish new rights to the original assets. Godot, Node and
ws notices are included under `licenses/` and `runtime/node_modules/ws/LICENSE`.

## Diagnostics and provenance

`Play.cmd --smoke` runs a headless normal-rate combat network check and exits.
It checks loading, snapshots, movement, firing and server cleanup, not graphics,
audio or human usability. Report a launch error together with console output.

`manifest.json` records source and port commits, every packaged file's SHA256,
source module closure, adapter hashes, bundled Node provenance, official Godot
checksums and the absence of staged model overrides. The adjacent ZIP `.sha256` verifies the
download. Native Windows CI results and known limits are linked from the release.

## Rebuild on Linux

```sh
python3 tools/godot-package/build.py --target windows --operator-models source-operators \
  --state /tmp/opencode/cocs-windows-build \
  --archive-directory /path/to/pinned/godot-archives
```

The archive directory is optional and must contain the verified `editor.zip` and
`templates.tpz`. Generated binaries stay outside Git and are attached to a GitHub
release; source, build tooling and verification reports are committed.
