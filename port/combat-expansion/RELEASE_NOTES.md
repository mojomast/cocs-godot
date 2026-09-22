# COCS: DESTINATIONS — Domination, Horde, debug tools and the material pass

Second combat-expansion prerelease. The previous build gave you six deathmatch arenas,
the original operators, detailed weapons and the effects pass; this one adds the other
two modes, debug tools, a benchmark, and a coherent material language across every map.

## New in this build

**Domination — Vermilion Fold.** Three real capture zones (Fan, Crown, Pleat) with
west/east team spawns, capture → contest → neutralize → lose → recover, both teams
scoring, score-limit results and restart. Verified with a live socket round and rendered
captures where every zone marker matched the authority's own snapshot. Spawn-to-zone
travel is symmetric once both seats use the same loadout (0.00 s delta).

**Horde — Nacre Engine.** Waves with real enemy approaches, wave clears, upgrade offers,
**victory**, and **defeat** with lives running 3→2→1→0 and a clean restart. Peak run held
ten simultaneous enemies. Enemy reachability measured against the actual source capsule:
narrowest traversed channel 1.31 m against a 0.84 m requirement. Not yet included: boss
wave, endless mode, full ten-wave completion, upgrade *selection*.

**Debug tools (off by default).** Enable with `COCS_DEBUG=1`; an on-screen `DEBUG` badge
appears. Live: god mode (human seat only), damage multiplier, take-less-damage scale,
difficulty (bots change behaviour immediately), speed, gravity, respawn timer, unlock all
weapons, and 14 source mutators including instagib, one-shot, no-recoil, berserk, bounty
and life steal. Restart-applied: bot count and starting weapon. Debug is deliberately
unavailable in human-vs-human rooms.

**Benchmark.** A 33-second scripted run prints one pasteable line with real median/p95
frame times, draw calls, quality level and particle allocation. Run it with:

```bat
set COCS_BENCHMARK=1
Play.cmd --experience=native-dm --map=prism-foundry --bots=4
```

**Material language.** Eight named families with 22 variants now dress every playable map
and the nine original arenas by surface role, using the baked Moth assets that had gone
unused: **13/13 normals, 5/5 material LUTs, 61/64 asset keys**. Draw calls unchanged on
all 84 matched cameras and arena collision hashes identical — a render-only change.
Derived roughness/AO/detail maps are generated offline and re-derive byte-identically.

**UI fixes.** The setup surface no longer inflates to a full-screen slab or uses engine
popups; the scoreboard no longer covers the vitals or weapon panel at 960×640; the
player-count label tells the truth (`13 actors · 1 player · 12 enemies`); the legacy
oversized pickup caption is tamed.

## Still true from the previous build

Six deathmatch maps (Prism Foundry, Aurora Basin, Cinder Array, Lacuna Court, Vermilion
Fold, Nacre Engine), the imported original source operators with real third-person weapons
and solved hand grips, ten detailed and visually distinct weapons, and the full effects
stack — barrel-tip weapon effects with wall occlusion, interference shields, particle
budgets up to a million shared slots, directional damage, low health, shield break,
death/respawn feedback, material impacts, and blood spurts with death splatter that stains
floors and walls.

## Controls

- **WASD** move, **mouse** look, **LMB** fire, **RMB** aim down sights
- **Space** jump, **Shift** sprint, **Ctrl/C** crouch, **R** reload
- **Q** power, **F** melee, **G** grenade, **E** interact, **X** mobility, **Z/MMB** alt fire
- **1–9 / 0 / wheel** weapons, **Tab** scores, **Esc** release the mouse
- **Enter** restart after results, **F8** scenery detail, **F9** effects quality,
  **F10** resource metrics, **F7** benchmark
- Horde: same controls; Domination runs through `--experience=identity-zones`

## Honest limitations

- Every performance figure in this project is **Linux OpenGL Compatibility on llvmpipe
  software rendering**, not hardware-GPU acceptance. Use the benchmark on your machine.
- The new maps are stylized first-pass art: no baked lightmaps, and the baked normals are
  shallow, so bump contribution reads as dents rather than deep relief.
- Horde is playable to victory and defeat but has no boss, endless or upgrade selection.
- Campaign remains deferred; the full Arms Race ladder and broader LATTICE rounds are open.
- The source asset-rights audit remains unresolved; this package does not establish new
  rights to the original assets.

## Diagnostics

`Play.cmd --smoke` runs a headless network check. `manifest.json` records the source and
port commits, every packaged file's SHA256, the runtime closure and the feature inventory.
