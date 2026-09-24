# COCS: DESTINATIONS — Weapon Feel, Smooth Motion & Distinct Moth Normals

A Windows x64 and Linux x86_64 development prerelease. It keeps the unified
in-game menu from `playable-menu-2026-09-23` and adds this week's combat,
presentation, movement and benchmark work.

## Download and play

- **Windows:** download `cocs-native-windows.zip`, **Extract All**, open the
  extracted `cocs-native-windows` folder and double-click **Play.cmd**.
- **Linux:** install Node.js 22.13.0 or newer, extract
  `cocs-native-linux.tar.gz`, enter `cocs-native-linux` and run `node run.mjs`.
- Godot is included. Both builds need an OpenGL 3.3-compatible driver; local
  matches with bots work offline. From the menu choose **Native → Native
  Deathmatch** for a quick match.

WASD moves, mouse looks, LMB fires, RMB aims, Z or middle mouse fires the alt
mode, F9 changes effects quality, F10 shows resource metrics, and F7 runs an
in-match benchmark. Escape releases the mouse.

## This release

- **Weapons have weight.** Ten distinct first-person silhouettes and metal
  finishes, matched by ten distinct third-person models without moving their
  muzzle or hand-grip anchors. Per-weapon recoil has a transient punch and
  controlled recovery; larger muzzle blooms, layered travelling tracers,
  smooth projectile trails and individual layered shot/launch/hit sounds make
  the arsenal read differently. ADS sightlines and pool budgets remain gated.
- **Four distinct alternate fires.** The rocket cluster shell splits into
  staggered pops; the plasma mortar has a blue finned round, smoky arc and
  heavy ground burst; the grenade mine is a low red disc with an arming blink
  and sharp proximity shockwave; the flak bomb is a vented yellow canister
  with smoky plume and fragments. Each has a separate launch/explosion voice.
  Their primary shots remain recognisable.
- **Faster projectile travel.** Source-tuned primary Rocket 36 m/s, Plasma
  46 m/s, Grenade 28 m/s; cluster 28, mortar 32, mine 15 and flak bomb 26 m/s.
  Collision and game rules still come from the locked source.
- **Persistent environmental impacts.** Confirmed hits can leave pooled
  pocks, cracks and scorches on surfaces; explosions add dust and shockwaves.
  F9 bounds mark pools to 20/44/72 for Low/High/Extreme.
- **Smooth local native movement.** The port-owned Deathmatch, Domination and
  Horde authorities now ship a full pose every 60 Hz source tick rather than
  every third tick. Measured native camera updates rose 20.2 → 60.5 Hz and
  movement steps fell 0.305 → 0.110 m in the controlled trace. This is a
  native-route cadence change; the separate locked web server is unchanged.
- **The documented benchmark now starts the native match itself.** An
  env-armed run no longer depends on the benchmark driver's fallback to leave
  the setup screen. The gate tests a complete armed run and an unarmed launch
  that stays silent; F7 still works from a live match.
- **All 13 baked Moth normals were re-baked at 64×64.** The original set had
  six near-duplicate pairs above 0.90 similarity; the new set has **zero**
  (median pair similarity 0.100, maximum 0.645). The 12 albedo-derived family
  normals remain where their texture structure is the better fit.

Visual evidence is committed in
[`docs/MOTH.md`](https://github.com/mojomast/cocs-godot/blob/main/docs/MOTH.md),
[`port/native-alt-fire/`](https://github.com/mojomast/cocs-godot/tree/main/port/native-alt-fire)
and [`port/native-world-weapon-identity/`](https://github.com/mojomast/cocs-godot/tree/main/port/native-world-weapon-identity).
The interactive [13-tile Moth comparison](http://100.125.104.79:4371/moth-rebake.html)
and [weapon/alt-fire gallery](http://100.125.104.79:4371/) are on the owner's LAN.

## Benchmark on your hardware

From a **Windows Command Prompt** in the extracted directory:

```bat
set COCS_BENCHMARK=1
set COCS_BENCHMARK_LEVEL=extreme
Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180
```

In **PowerShell**, set real environment variables instead:

```powershell
$env:COCS_BENCHMARK='1'
$env:COCS_BENCHMARK_LEVEL='extreme'
.\Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180
```

Or start a match normally and press **F7**. Please send the printed
`BENCHMARK_RESULT` line, GPU model and resolution, plus per-map Extreme verdicts.
Local development measurements use llvmpipe software rendering, not your GPU.

## Verification

The integrated tree has 176 registered gates, including the new rendered
benchmark-autostart, 105-check alt-fire, world-weapon silhouette/grip, and
Moth hash/provenance checks. The source re-bake branch passed upstream CI;
packaged Windows and Linux verification results are attached to this release
after both archives complete their hosted runs.
