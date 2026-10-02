# Source-only targeting follow-up

This follow-up changes **test-controller target selection only**. Production HUD,
source authority, geometry, input TTL, difficulty, timing and balance are untouched.
No engine/Blender work. Native target-selection condition is mirrored but untested.

## Measured original bottleneck

Retained original: `source-boss-UXBKiC/`. Read-only analysis:
`trace-analysis-4ajx7S/analysis.json`, under the established evidence root.
`analyze-trace.mjs` accounts for every recorded step and actual source event.

The worst wave is **9: 304 seconds of combat**, 737 target changes, 3,078.924m
travel, only 57.55s of requested firing, and 19 Harbinger summon beats creating
38 adds. Harbinger 76 first took player damage at 747.8167s (205.3333s after wave
start), died at 757.5s, and remaining cleanup lasted another 88.9833s. The Warden
then had only 46.5s left before the unchanged 900s source limit.

| Wave | Combat seconds | Move/no-fire steps | Fire-window steps | Still/idle steps | Travel m | Target switches | Stuck 1s windows | Shots / hit shots / geometry-stopped misses |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 49.1333 | 1883 | 463 | 1023 | 461.625 | 1 | 0 | 70 / 28 / 14 |
| 2 | 8.0667 | 244 | 240 | 421 | 84.005 | 7 | 0 | 36 / 19 / 7 |
| 3 | 53.1000 | 3439 | 827 | 1 | 822.866 | 6 | 0 | 121 / 42 / 30 |
| 4 | 40.2833 | 938 | 823 | 1077 | 287.235 | 2 | 0 | 121 / 102 / 11 |
| 5 | 47.7167 | 1755 | 1108 | 421 | 521.046 | 24 | 0 | 168 / 90 / 38 |
| 6 | 104.5500 | 5999 | 2147 | 1 | 1308.343 | 38 | 0 | 314 / 254 / 34 |
| 7 | 80.6500 | 2975 | 1501 | 784 | 817.054 | 16 | 0 | 222 / 146 / 24 |
| 8 | 60.6167 | 2365 | 1272 | 421 | 613.960 | 39 | 0 | 190 / 114 / 24 |
| 9 | 304.0000 | 14785 | 3453 | 423 | 3078.924 | 737 | 3 | 521 / 336 / 83 |
| 10 | 46.5000 to loss | 2039 | 751 | 1 | 505.681 | 14 | 0 | 112 / 77 / 19 |

Step counts include the following intermission, assigned to the preceding wave:
421 steps after waves 1/2/4/5/7/8/9, 1081 after wave 3, 1874 after wave 6.
Initial wait is another 420 idle steps. Combat seconds use source wave/clear
event timestamps. Each input step is 1/60s. Repair-held steps are separately
recorded (2501/1028/740 in waves 1/4/7). Fire-window steps combine moving and
stationary requested fire; actual fire rate, spread and damage stay source-owned.
Full precision, moving/stationary partitions and coordinates are in the JSON.

“Stuck” is a conservative observable proxy: disjoint 60-step windows with >=45
movement commands but net displacement <0.25m. It includes oscillation and does
not establish a collision bug. All **12,585** `move-blocked` events say
`reason:firing`: these are grapple-admission events, **not wall collisions**.
Most wasted time is travel/route switching, not uncommanded idle or hard blockage.

Geometry-stopped misses are actual player shot endpoints meeting a source ray
obstacle within 0.02m, not all misses and not a claim about target visibility
before shooting. The original log has no complete per-step enemy/ammo snapshot,
so exact no-fire LOS/empty-ammo dwell cannot be inferred retrospectively. New
logs include read-only decision metadata for those counters.

All 1,875 player shots used the existing infinite-ammo pulse rifle; no player
weapon-switch or reload events/requests were recorded. Thus this failure does
not support an ammo/reload starvation diagnosis. Existing offered Overshield
choices (wave 3 index 3; wave 7 index 2) were accepted. Choosing a different
upgrade or weapon could be a strategy experiment, but neither is changed here.

## Concrete defect and exact reproduction

The old selector was `enemies.find(canSee) ?? enemies[0]`, while firing already
required target distance <65m. A distant enemy briefly visible through a corridor
could override a nearer occluded target, reverse the route, then lose visibility
again. Repeated reversals continually rebuilt paths without opening a fire window.

`probe-targeting.mjs` replays the retained ordinary inputs and upgrade choices
from the identical setup/RNG **only to tick 33126**, then stops. This is a focused
diagnostic replay, not another completion attempt. Result:
`target-probe-4bdlC7/probe.json`, **maximum player-position divergence 0**.

At source time **552.0999999998265**, gate mask **3**:

- Player `[x,y,z] = [-185.613847556862, 0, -64.17147040363324]`.
- Nearest enemy: mender **75**, `[-148.75055402387315, 0, 60.379256372326964]`,
  distance **129.8914390963438m**, occluded.
- Old chosen enemy: husk **67**, `[109.00962070728008, 0, -60.00019293027138]`,
  distance **294.65299524653005m**, visible.
- Recorded input: x `0.014156575838884236`, z `-0.999899790659303`, yaw
  `-1.5849533755264467`, pitch `-0.0008484554511353475`, sprint true, fire false.

Minimal fix: prefer a visible target **inside the existing 65m fire window**;
otherwise navigate toward the nearest enemy. No new priority weights, hysteresis,
boss targeting, aim changes, weapons, upgrades or source rules. Sole distant
enemies remain valid navigation targets, so the fix cannot strand cleanup.

`targeting.test.mjs` uses these exact source-map coordinates. The negative-before
run failed the expected target (`67` instead of `75`); two guard cases passed.
After the fix all three pass, including nearby-visible and sole-distant cases.
Evidence: `targeting-tests-qhqydq7t/{before,after}.log`.

## One new full attempt

The single additional bounded boss run uses the original constructor config,
seed `0x20261002`, dt=1/60, maximum 900 source seconds and accelerated wall time.
Only the target-selection condition changes gameplay controls; added decision
telemetry is read-only.

**PASS — full source mission victory**, unique attempt `source-boss-6kDcvB/`:
48,207 steps, **803.45 source seconds**, 20.13855 wall seconds, **96.55s remaining**,
91 kills, zero deaths, three lives. Its serialized constructor config is identical
to the retained loss and the seed is unchanged. Actual source `mission-won` and
`horde-summary` outcome `won` were emitted; no outcome or actor state was written.

Receipts (source seconds): south feeder 24.3667, north feeder 49.8667, upgrade
wave 3 Overshield/index 3 accepted at 124.6333, B arrival 137.6667, pump 155.1333,
C arrival 417.8333, valve 429.9833, upgrade wave 7 Overshield/index 2 accepted at
524.3333. Warden **91** arrived/phase 1 at **691.85**, phase 2 **800.30**, phase 3
**802.1667**, death to player **0**, pulse weapon **0** at **803.45**. Death receipt
position `[134.2003585163582,1,-60.14727253037196]`; final Warden HP 0/450.
`mission-won` followed in the same source step, with all ten waves cleared.

New read-only analysis: **`trace-analysis-w9unZA/analysis.json`**. (The retained
first analysis `trace-analysis-wrJIJj/` classified the terminal clear tick as an
intermission; the final analyzer correctly records zero wave-10 intermission.)

| Wave | Combat seconds | Move/no-fire steps | Fire-window steps | Still/idle steps | Travel m | Target switches | Stuck 1s windows | Shots / hit shots / geometry-stopped misses |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 50.2833 | 2074 | 341 | 1023 | 466.667 | 1 | 0 | 54 / 27 / 14 |
| 2 | 9.1167 | 264 | 283 | 421 | 92.281 | 7 | 0 | 43 / 22 / 10 |
| 3 | 44.1833 | 2933 | 500 | 1 | 666.693 | 7 | 0 | 74 / 38 / 14 |
| 4 | 52.1000 | 1539 | 925 | 1083 | 339.197 | 2 | 0 | 139 / 123 / 13 |
| 5 | 86.8833 | 4218 | 995 | 421 | 917.433 | 24 | 3 | 148 / 86 / 29 |
| 6 | 105.4833 | 5801 | 1827 | 1 | 1237.812 | 18 | 2 | 270 / 209 / 30 |
| 7 | 106.4833 | 4369 | 1657 | 784 | 936.268 | 15 | 2 | 245 / 205 / 18 |
| 8 | 67.5833 | 2954 | 1101 | 421 | 698.267 | 20 | 0 | 167 / 118 / 11 |
| 9 | 78.8833 | 3305 | 1428 | 421 | 789.667 | 26 | 0 | 211 / 157 / 18 |
| 10 | 111.6000 | 5277 | 1419 | 1 | 1209.491 | 21 | 0 | 213 / 147 / 40 |

New following-intermission counts: 421 for waves 1/2/4/5/7/8/9; 783 for wave 3;
1300 for wave 6; zero for wave 10. Initial wait remains 420. All reload pulses,
reload starts and empty-ammo step counts are **zero in every wave**. Every player
shot still uses pulse weapon 0; no weapon choices or upgrade preferences changed.
Per-wave occluded-target/out-of-range step counts are now directly logged in the
analysis JSON; they overlap and must not be added as independent delay totals.

The result is not “every wave got faster”: the repaired run reached wave 9
**63.4667s later**. It then avoided the specific wave-nine route reversal trap:
737→26 target switches; 304→78.8833 combat seconds; 3078.924→789.667m travel;
38→2 summoned adds. Harbinger first damage is now **11.2833s after wave start**
and death **18.45s after start**, without a special boss-priority rule. The
Warden arrives **161.65s earlier** overall, providing time for full wave cleanup.
Seven low-displacement movement windows remain in earlier waves; navigation is
not claimed optimal and production/human balance remains unmeasured.

Budget honored: one additional full bounded source attempt after diagnosis; no
seed changes, difficulty changes, retries, extra time or additional full attempts.
The original loss, failed regression test and all traces are retained.

**READY FOR ENGINE:** full source victory is now observed. Native/OS-focus/input
ACK receipts, actual rendered HUD inspection and walkthrough footage remain
pending the parent's exclusive-slot grant. The native fixture's mirrored range
condition has received code review only, not Godot parsing or runtime acceptance.
