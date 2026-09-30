# Biome and animation testing preview — 2026-09-30

This prerelease integrates `biome.patch` onto consolidated revision `56460829`.
Route conflicts were resolved by retaining Cinderwake and regenerating the
23-route registry. Both package verifiers now exercise the two new maps.

## Play

Windows: extract the complete ZIP, run `Play.cmd`, select Native Deathmatch,
then choose Canopy Divide or Basalt Reach. Alternatively, from a terminal in
the extracted directory:

```bat
"Native Deathmatch.cmd" --map=canopy-divide --bots=7
"Native Deathmatch.cmd" --map=basalt-reach --bots=7
```

Linux requires Node.js >=22.13.0. Extract the archive and run:

```sh
node run.mjs --experience=native-dm --map=canopy-divide --bots=7
node run.mjs --experience=native-dm --map=basalt-reach --bots=7
```

Watch other operators moving, strafing, crouching and jumping to inspect the
new third-person animation and joint-mounted armor. This is a testing preview.

## Known review findings

- Below 20 FPS, the new distance-based gait discards elapsed time; at 10 FPS
  the gait advances at half its normal rate.
- Near/medium armor adds 32 visible mesh surfaces per tested Claude instance;
  the original `visible_cost()` counter omits them. Hardware performance is
  unmeasured.
- New biome contracts were run directly; they are not yet canonical CI gates.
- The prior consolidated hosted crew and Horde-upgrade fixture failures remain
  unresolved. This preview does not claim full hosted-suite acceptance.

Both platforms are built from one committed revision with commit-bound source
and artifact manifests. Package acceptance results and download checksums are
published in the release notes.
