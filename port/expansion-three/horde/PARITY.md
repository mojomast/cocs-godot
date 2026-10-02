# Current implementation audit

Read actual implementations before changing presentation:

- Three.js UI: `app/game-ui/singleplayer-hud.tsx` renders upgrade **names and
  descriptions** in real buttons, hold/boss bars, mission status and notices.
  `game/input.mjs` derives world motion from ordinary keyboard/aim state.
- Native: `godot/horde/model.gd`, `demo.gd`, `controls.gd`, and
  `horde_maps/blackwater_demo.gd` already supported source offers, native hotkeys,
  interaction and authority feedback. The gap was description discovery (only
  tooltips), fixed-position layout, missing lock reasons and priority selection.
- `port/native-horde/blackwater-director.mjs` is an existing local-authority
  extension, not a Three.js campaign objective chain. It requires a live grounded
  actor, E within 5m, progress within 6.5m, 5/5/12/7 seconds, waves 1/1/4/7,
  both feeders before pump and pump before valve. E arms for 900 source ticks;
  leaving range pauses progress, death clears active state, progress is retained.
  Pump/valve invoke actual source resupply. A feeder refreshes a pickup only if
  one exists within 48m. Gates are wave-clear source transactions, not station
  rewards; the HUD now makes those distinct.
- Source upgrade offers occur on cleared waves 3 and 7 in this ten-wave run;
  ordinary source `selectHordeUpgrade` accepts the actual offered choice and
  records it. The web uses this API; native uses the existing guarded wire intent.
- The reviewed native adapter adds the wave-ten Warden through `spawnGroup` and
  existing health thresholds. The source's bounded plan itself has a wave-nine
  Harbinger. The prior native fixture stopped at Warden **phase three**, before
  defeat. The new boss acceptance requires Warden death **and source victory**.
- `game/core.mjs` actor hits use the existing actor hit box/hitScale. No distinct
  Warden weak-point damage contract was found. Vehicle rear/flank weak points
  exist separately in `game/vehicles.mjs`; neither body art nor a cosmetic
  headpop death is evidence of a Warden weak-point multiplier. Recorded Warden
  damage/death here is actual existing pulse-rifle damage, not invented weak spots.

## Controller usability versus production balance

The old fixture chases nearest enemies into point-blank combat, can fire into
walls, and only sends reload in its non-station combat branch. Its newly added
upgrade hotkey remains engine-unverified. The source planner uses line of sight,
source-generated walk graphs, ordinary WASD/aim/fire/E/R/Q and offered upgrades.
Its retreats and exact aim are automated test strategy, not a shipped assist.
The native fixture adds visibility selection, stops charging visible targets
inside 24m, allows R during station defense and uses the existing Q ability.
It inherits ordinary native event sampling/epoch flow. It is a different planner
from the Node source planner; a source pass does not validate that native planner.

No actor position, health, stats, wave, gate, mission progress or objective
completion was written after setup in the source completion runs. RNG is seeded
at construction for reproducibility, with normal easy/ten-wave/900-second preset
and dt=1/60. Wall time is accelerated only in the direct-source runner. There
were no diagnostic seeded-completion runs and no core bug fix. The original
timer loss is retained. `TARGETING_FOLLOWUP.md` now records a minimal fixture
target-range fix and one same-seed/config full source victory; native victory is
still unproved. Neither outcome is evidence to rebalance production gameplay.

Core SHA-256 rechecked unchanged:
`58ff1b9c7467a53da00638f16edfd3df2e1e6fd06480ff081ad13c88fb64bdb9`.
