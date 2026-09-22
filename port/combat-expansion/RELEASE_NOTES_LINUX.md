# COCS: DESTINATIONS — Linux x64 prototype

The Linux build of the Domination, Horde, debug-tools and material-language
release. Extract the tarball and run `node run.mjs`; the packaged README covers
controls, every route and the full option list.

```sh
tar -xzf cocs-native-linux.tar.gz
cd cocs-native-linux
node run.mjs
```

**Requirements:** Linux x86_64, an OpenGL 3.3-compatible driver and **Node.js
>=22.13.0** on `PATH`. Node is an external prerequisite on Linux; everything else
is inside the archive. The `.tar.gz.sha256` beside the download verifies the
archive.

## New in this build

**Domination — Vermilion Fold.** Three real capture zones (Fan, Crown, Pleat) with
west/east team spawns, capture → contest → neutralize → lose → recover, both teams
scoring, score-limit results and restart. Verified with a live socket round and
rendered captures where every zone marker matched the authority's own snapshot.
Spawn-to-zone travel is symmetric once both seats use the same loadout.

**Horde — Nacre Engine.** Waves with real enemy approaches, wave clears, upgrade
offers, **victory**, and **defeat** with lives running 3→2→1→0 and a clean restart.
Peak run held ten simultaneous enemies. Enemy reachability measured against the
actual source capsule: narrowest traversed channel 1.31 m against a 0.84 m
requirement. Not yet included: boss wave, endless mode, full ten-wave completion,
upgrade *selection*.

**Debug tools (off by default).** Enable with `COCS_DEBUG=1`; an on-screen `DEBUG`
badge appears. Live: god mode (human seat only), damage multiplier, take-less-damage
scale, difficulty (bots change behaviour immediately), speed, gravity, respawn
timer, unlock all weapons, and 14 source mutators including instagib, one-shot,
no-recoil, berserk, bounty and life steal. Restart-applied: bot count and starting
weapon. Debug is deliberately unavailable in human-vs-human rooms.

**Material language.** Eight named families with 22 variants now dress every
playable map and the nine original arenas by surface role, using the baked Moth
assets that had gone unused: **13/13 normals, 5/5 material LUTs, 61/64 asset
keys**. Draw calls unchanged on all 84 matched cameras and arena collision hashes
identical — a render-only change.

**UI fixes.** The setup surface no longer inflates to a full-screen slab or uses
engine popups; the scoreboard no longer covers the vitals or weapon panel at
960×640; the player-count label tells the truth; the legacy oversized pickup
caption is tamed.

## Also included

Six deathmatch arenas (Prism Foundry, Aurora Basin, Cinder Array, Lacuna Court,
Vermilion Fold, Nacre Engine), the imported original source operators with real
third-person weapons and solved hand grips, ten detailed and visually distinct
weapons, and the full effects stack — barrel-tip weapon effects with wall
occlusion, interference shields, particle budgets up to a million shared slots,
directional damage, low health, shield break, death/respawn feedback, material
impacts, and blood spurts with death splatter that stains floors and walls.

## Benchmark

```sh
COCS_BENCHMARK=1 node run.mjs --experience=native-dm --map=prism-foundry --bots=4
```

## Honest limitations

- Every performance figure in this project is **Linux OpenGL Compatibility on
  llvmpipe software rendering**, not hardware-GPU acceptance. Use the benchmark.
- The new maps are stylized first-pass art: no baked lightmaps, and the baked
  normals are shallow, so bump contribution reads as dents rather than deep relief.
- Horde is playable to victory and defeat but has no boss, endless or upgrade
  selection.
- Campaign remains deferred; the full Arms Race ladder and broader LATTICE rounds
  are open.
- The source asset-rights audit remains unresolved; this package does not establish
  new rights to the original assets.

## Diagnostics

`node run.mjs --smoke` runs a headless combat network check. `manifest.json`
records the source and port commits, every packaged file's SHA256, the reviewed
runtime closure and the feature inventory. Hosted Linux verification downloads this
exact archive, re-hashes it and exercises the packaged routes on a fresh runner.
