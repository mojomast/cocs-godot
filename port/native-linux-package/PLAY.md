# COCS: DESTINATIONS — Linux x86_64 prototype

## Requirements

- Linux x86_64 with an **OpenGL 3.3-compatible graphics driver** (X11 or Wayland)
  and the usual Godot 4.5.2 Linux runtime libraries.
- **Node.js >= 22.13.0 available as `node`.** Node is an external prerequisite on
  Linux; it is not bundled. `runtime/node_modules/ws` is an ordinary copied
  directory with its MIT license, and the authority uses the Node standard library
  plus that one dependency.
- No Godot editor, Git, npm or account is needed, and local bot matches work
  offline.

## Start

```sh
tar -xzf cocs-native-linux.tar.gz
cd cocs-native-linux
node run.mjs
```

The default opens the **main menu**: pick a category (Play / Native / Modes /
Extras / Cheats), a route, adjust its options and press **Start**. Quitting a
match returns you to the menu; Quit in the menu exits the game. The old direct
routes still work as flags (`node run.mjs --experience=combat --setup`, etc.). Two reviewed launchers skip the setup screen:

```sh
./Domination.sh    # Vermilion Fold, 2 bots, 5 minutes, 100 points
./Cheats.sh        # the same route with the debug panel enabled (COCS_DEBUG=1)
```
 Sessions own a loopback server on an OS-assigned port; closing the game
window or pressing Ctrl+C shuts that server down too. The lobby's explicit
`--endpoint` route uses an existing authority instead and never stops it.

```sh
node run.mjs --play --map=meridian-exchange --mode=deathmatch
node run.mjs --experience=native-dm --map=prism-foundry --bots=2 --round-seconds=180
node run.mjs --experience=native-dm --map=vermilion-fold
node run.mjs --experience=identity-zones
node run.mjs --experience=horde --map=nacre-engine
node run.mjs --experience=showcase
node run.mjs --experience=lobby
node run.mjs --help
```

All nine original maps and ten source experience routes are retained, plus the
three-map original native Deathmatch family (Prism Foundry, Aurora Basin, Cinder
Array), the three identity arenas (Lacuna Court, Vermilion Fold, Nacre Engine),
five native-only graphics routes, Domination on Vermilion Fold and Horde on Nacre
Engine.

## Controls

- **WASD** move, **mouse** look, **left click** fire
- **Space** jump, **Shift** sprint, **Ctrl** crouch
- **RMB** aim down sights; release to return to hip fire
- **R** reload, **1–9 / 0 / wheel** change weapon
- **E** interact, **X** mobility, **Q** power, **F** melee, **G** grenade
- **Z / MMB** alternate fire
- **Tab** scores, **Escape** release the mouse; the match keeps running
- **Enter** restart after results, then release keys and click to resume
- **F8** cycle Moth scenery detail: Full → Off → Low
- **F9** cycle combat effects: Low → High → Extreme
- **F10** toggle combat-effect resource metrics
- **F7** run the benchmark

## Modes

**Deathmatch** (`--experience=native-dm`) has one local human and 1–7 bots on six
reviewed arenas. Source movement, weapon damage, scoring and bot AI remain
authoritative.

**Domination** (`--experience=identity-zones`) is the reviewed one-pair route:
Vermilion Fold with three authored capture zones (Fan, Crown, Pleat), contest and
neutralize behaviour, both teams scoring, score-limit results and restart. Options
are `--bots=0..7`, `--round-seconds=60..900` and `--score-limit=1..900`; any other
map, mode or out-of-range value is refused.

**Horde** (`--experience=horde --map=nacre-engine`) runs waves with real enemy
approaches, wave clears, upgrade offers, victory and defeat with lives 3→2→1→0.
Select offered upgrades with the numbered buttons or matching number keys;
the server confirms whether a choice was applied or refused. Full natural
ten-wave completion has not been acceptance-tested; boss/endless modes remain
outside this release's acceptance scope.

**Graphics Showcase** (`--experience=showcase`, `--experience=aurora-basin`,
`--experience=cinder-array`, `--experience=particle-lab`,
`--experience=shader-lab`) opens standalone unarmed exploration, including the
particle observatory with explicit 8K–1M settings and the Moth shader gallery.
**P** photo views, **1–4** particle presets, **Space** pause, **Escape** release.

## Debug tools (off by default)

Set `COCS_DEBUG=1` before starting, or pass the game's `--debug-panel` flag, and a
`DEBUG` badge appears. Live knobs: god mode (human seat only), damage multiplier,
debug-only incoming damage scale, difficulty (bots change behaviour immediately),
speed, gravity, respawn timer, unlock all weapons and 14 source mutators including
instagib, one-shot, no-recoil, berserk, bounty and life steal. Bot count and
starting weapon apply on restart. The channel is never available in
human-vs-human rooms.

## Benchmark

```sh
COCS_BENCHMARK=1 node run.mjs --experience=native-dm --map=prism-foundry --bots=4
```

One `BENCHMARK_RESULT` line reports real median/p95 frame times, draw calls,
quality level and particle allocation. All recorded project numbers are Linux
OpenGL Compatibility on the llvmpipe software renderer; run this on your own
machine for a real measurement.

## Diagnostics and provenance

`node run.mjs --smoke` runs a headless normal-rate combat network check and exits.
It checks loading, snapshots, movement, firing and server cleanup — not graphics,
audio or human usability. Report a launch problem together with the console output.

`manifest.json` records the source and port commits, every packaged file's SHA256,
the runtime closure with its reviewed adapters, official Godot checksums and the
source-operator selection (no staged model override). The adjacent `.tar.gz.sha256` verifies the
download.

This is a development prerelease. **The source asset-rights audit remains
unresolved; this package does not establish or grant new rights to the original
assets.** Godot, Node and ws notices are included under `licenses/` and
`runtime/node_modules/ws/LICENSE`.

## Rebuild

```sh
python3 tools/godot-package/build.py --target linux --operator-models source-operators \
  --state /tmp/opencode/cocs-linux-build \
  --archive-directory /path/to/pinned/godot-archives
```

The archive directory is optional and must contain the verified `editor.zip` and
`templates.tpz`. Generated binaries stay outside Git and are attached to a GitHub
release; source, build tooling and verification reports are committed.
