# COCS: DESTINATIONS — Movement, Muzzles, Horde Deaths & 24-Bot Native Matches

Windows x64 and Linux x86_64 development builds, with the original mode rules
and source commit `515daf07589150dd3241f4ae1425cc1b093912f5` retained.

## What's new

- Local infantry camera translation updates between authoritative snapshots
  without delaying mouse look or changing gameplay input. This shared path
  reaches Combat, Native Deathmatch, Domination, Horde, Arms Race, objectives
  and LATTICE world; Combined Arms infantry now uses the same bounded visual
  motion, while its vehicle camera keeps its existing frame-rate chase.
- First-person shot trails visibly begin at the animated barrel and converge
  on the source-confirmed aim ray. Third-person trails use the visible model's
  matching moving muzzle. Near-wall cosmetic paths fail closed; the source
  still decides hit, damage, collision and projectile position.
- Horde damage/death events feed the shared blood system, including the
  Nacre Engine collision geometry. NPCs fall over 0.8 seconds and their
  corpses expire; a final kill burst survives the results transition.
- The main menu offers **Diagnostics overlay (F11)** on every destination:
  frame rate, frame time, viewport, actors and available bot count. Local
  debug cheats remain opt-in and are not offered in the multiplayer lobby.
- Local Native Deathmatch supports **1–24 bots** and Vermilion Fold Domination
  supports **0–24** (25 actors with the human at 24). Ordinary source Combat
  and Zones stay within their source-supported 0–8; modes with fixed rosters
  keep their own rules. Select counts from the menu before launching.

## Owner hardware check

Download and extract the Windows or Linux archive from this prerelease. On
Windows, from **Command Prompt** in the extracted directory, run:

```bat
set COCS_BENCHMARK=1
set COCS_BENCHMARK_LEVEL=extreme
Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180
```

PowerShell equivalents: `$env:COCS_BENCHMARK='1'`,
`$env:COCS_BENCHMARK_LEVEL='extreme'`, then
`.\Play.cmd --experience=native-dm --map=prism-foundry --bots=4 --round-seconds=180`.
You can also enter a live match and press **F7**. To compare maps, replace
`prism-foundry` with `aurora-basin`, `cinder-array`, `lacuna-court`,
`vermilion-fold` and `nacre-engine`, one run at a time. Try a separate
`--bots=24` run on a map after the 4-bot baseline.

Please send each `BENCHMARK_RESULT` line, your GPU model and display resolution,
and a brief **Extreme visual/playability verdict for each map**. Include whether
movement, aiming/barrel origins and Horde blood/deaths feel correct. The local
Linux Xvfb benchmark uses llvmpipe software rendering and cannot stand in for
your hardware result.

## Verification

Native and Domination live headless smokes each reached 25 real actors with
movement and firing. The full serial native verifier passes, including the
rendered benchmark autostart/unarmed pair. Hardware FPS and hands-on visual
acceptance await your check.
